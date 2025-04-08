import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:notex/services/notemgn.dart';
import 'package:notex/widgets/loading.dart';

class AddNotePage extends StatefulWidget {
  final String? preselectedCourseId;
  final String? initialTitle;

  AddNotePage({this.preselectedCourseId, this.initialTitle});

  @override
  _AddNotePageState createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  TextEditingController _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPublic = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _selectedCourseId;
  String? _selectedFileName;
  File? _selectedFile;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.preselectedCourseId;
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get enrolled courses
      final enrollmentsQuery =
          await FirebaseFirestore.instance
              .collection('course_enrollments')
              .where('studentEmail', isEqualTo: currentUser.email)
              .get();

      final enrolledCourseIds =
          enrollmentsQuery.docs
              .map((doc) => doc.data()['courseId'] as String)
              .toList();

      // Fetch course details
      List<Map<String, dynamic>> courses = [];

      for (var courseId in enrolledCourseIds) {
        final courseDoc =
            await FirebaseFirestore.instance
                .collection('courses')
                .doc(courseId)
                .get();

        if (courseDoc.exists) {
          courses.add({
            'id': courseDoc.id,
            'code': courseDoc.data()?['code'] ?? 'Unknown',
            'name': courseDoc.data()?['name'] ?? 'Unknown Course',
          });
        }
      }

      setState(() {
        _courses = courses;
      });
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading courses: $error')));
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _selectedFileName = result.files.single.name;
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _uploadNote() async {
    if (_formKey.currentState!.validate() &&
        _selectedFile != null &&
        _selectedCourseId != null) {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      try {
        final noteService = NoteService();
        final result = await noteService.uploadNote(
          title: _titleController.text.trim(),
          courseId: _selectedCourseId!,
          file: _selectedFile!,
          isPublic: _isPublic,
          tags: _tags,
        );

        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note uploaded successfully!')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${result.error}')));
        }
      } catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading note: $error')));
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Note', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
      ),
      body:
          _isUploading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Note Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'Enter a descriptive title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCourseId,
                        decoration: InputDecoration(
                          labelText: 'Course',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.school),
                        ),
                        items:
                            _courses.map((course) {
                              return DropdownMenuItem<String>(
                                value: course['id'],
                                child: Text(
                                  '${course['code']} - ${course['name']}',
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCourseId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a course';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      InkWell(
                        onTap: _pickFile,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.upload_file, color: Colors.deepPurple),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _selectedFileName ?? 'Select PDF file',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color:
                                        _selectedFileName != null
                                            ? Colors.black
                                            : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedFile == null) ...[
                        SizedBox(height: 8),
                        Text(
                          'Please select a PDF file',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      Text(
                        'Tags',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tagController,
                              decoration: InputDecoration(
                                hintText:
                                    'Add tags (e.g., midterm, lecture, etc.)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addTag,
                            child: Icon(Icons.add),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _tags.map((tag) {
                              return Chip(
                                label: Text(tag),
                                deleteIcon: Icon(Icons.close, size: 18),
                                onDeleted: () => _removeTag(tag),
                                backgroundColor: Colors.deepPurple[50],
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          'Make this note public',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        subtitle: Text(
                          'Public notes are visible to all students in the course',
                          style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                        ),
                        value: _isPublic,
                        activeColor: Colors.deepPurple,
                        onChanged: (value) {
                          setState(() {
                            _isPublic = value;
                          });
                        },
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: LoadingButton(
                          isLoading: _isUploading,
                          onPressed: _uploadNote,
                          child: Text(
                            'Upload Note',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          backgroundColor: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
