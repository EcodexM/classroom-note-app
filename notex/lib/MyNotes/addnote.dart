import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class AddNotePage extends StatefulWidget {
  final String? preselectedCourseId;
  final String? initialTitle;
  final Color? selectedColor;

  AddNotePage({
    this.preselectedCourseId,
    this.initialTitle,
    this.selectedColor,
  });

  @override
  _AddNotePageState createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage>
    with SingleTickerProviderStateMixin {
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
  Color _selectedColor = Colors.white;
  String _selectedColorHex = "#FFFFFF";

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.preselectedCourseId;
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.selectedColor != null) {
      _selectedColor = widget.selectedColor!;
      _selectedColorHex =
          '#${_selectedColor.value.toRadixString(16).substring(2)}';
    }
    _loadCourses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
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
        // If a course is not preselected and we have courses, select the first one
        if (_selectedCourseId == null && _courses.isNotEmpty) {
          _selectedCourseId = _courses[0]['id'];
        }
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

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileExtension = path.extension(file.path).toLowerCase();

      // Test Case 1.3 - Validate file format
      if (fileExtension != '.pdf') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid file format. Only PDF files are allowed.'),
          ),
        );
        return;
      }

      setState(() {
        _selectedFile = file;
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
    // Test Case 1.2 - Validate title
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Title is required')));
      return;
    }

    // Validate course selection
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a course')));
      return;
    }

    // Test Case 1.3 - Validate file selection
    if (_selectedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a PDF file')));
      return;
    }

    // Validate file format again
    final fileExtension = path.extension(_selectedFile!.path).toLowerCase();
    if (fileExtension != '.pdf') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid file format. Only PDF is allowed.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${currentUser.uid}_$timestamp.pdf';

      // Upload file to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'notes/$_selectedCourseId/$fileName',
      );

      // Track upload progress
      final uploadTask = storageRef.putFile(_selectedFile!);
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for upload to complete
      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      // Prepare search terms
      final searchTerms = [
        _titleController.text.trim().toLowerCase(),
        ..._tags.map((tag) => tag.toLowerCase()),
      ];

      // Create note metadata in Firestore
      final noteRef = await FirebaseFirestore.instance.collection('notes').add({
        'title': _titleController.text.trim(),
        'courseId': _selectedCourseId,
        'ownerEmail': currentUser.email,
        'fileUrl': downloadUrl,
        'fileName': _selectedFileName,
        'uploadDate': FieldValue.serverTimestamp(),
        'isPublic': _isPublic, // Test Case 1.4 - Privacy setting
        'downloads': 0,
        'averageRating': 0.0,
        'tags': _tags,
        'searchTerms': searchTerms,
        'color': _selectedColorHex, // Store the selected color
      });

      // Update course note count
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedCourseId)
          .update({'noteCount': FieldValue.increment(1)});

      // Test Case 1.1 - Success message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload successful')));

      Navigator.pop(context, true); // Return true to indicate success
    } catch (error) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading note: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _selectedColor,
      appBar: AppBar(
        backgroundColor: _selectedColor,
        elevation: 0,
        title: Text(
          'Add New Note',
          style: TextStyle(
            color: _isDarkColor(_selectedColor) ? Colors.white : Colors.black,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _isDarkColor(_selectedColor) ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isUploading ? _buildUploadingState() : _buildNoteForm(),
    );
  }

  Widget _buildUploadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
          SizedBox(height: 16),
          Text(
            'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: _isDarkColor(_selectedColor) ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note Details section
            _buildSectionLabel('Note Details'),
            SizedBox(height: 16),

            // Title field
            _buildInputField(
              prefixIcon: Icons.title,
              hintText: 'Title',
              controller: _titleController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            SizedBox(height: 12),

            // Course dropdown
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonFormField<String>(
                value: _selectedCourseId,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.school, color: Colors.grey),
                  hintText: 'Course',
                  border: InputBorder.none,
                ),
                items:
                    _courses.map((course) {
                      return DropdownMenuItem<String>(
                        value: course['id'],
                        child: Text(
                          '${course['code']} - ${course['name']}',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCourseId = value;
                  });
                },
                icon: Icon(Icons.arrow_drop_down),
                isExpanded: true,
                hint: Text('Course'),
              ),
            ),
            SizedBox(height: 12),

            // File selection
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedFileName != null
                          ? Icons.insert_drive_file
                          : Icons.upload_file,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFileName ?? 'Select PDF file',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color:
                              _selectedFileName != null
                                  ? Colors.black87
                                  : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_selectedFile == null) ...[
              SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text(
                  'Please select a PDF file',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],

            SizedBox(height: 24),

            // Tags section
            _buildSectionLabel('Tags'),
            SizedBox(height: 16),

            // Tag input
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        hintText: 'Add tags (e.g., midterm, lecture, etc.)',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _addTag,
                    icon: Icon(Icons.add, color: Colors.white),
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(),
                    iconSize: 24,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _tags.map((tag) {
                    return Chip(
                      label: Text(tag, style: TextStyle(fontFamily: 'Poppins')),
                      deleteIcon: Icon(Icons.close, size: 18),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: Colors.white,
                    );
                  }).toList(),
            ),

            SizedBox(height: 24),

            // Public/Private toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Make this note public',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        'Public notes are visible to all students in the course',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                    activeColor: Colors.deepPurple,
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Upload button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _uploadNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Upload Note',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
        color: _isDarkColor(_selectedColor) ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildInputField({
    required IconData prefixIcon,
    required String hintText,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, color: Colors.grey),
          hintText: hintText,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Helper function to determine if a color is dark
  bool _isDarkColor(Color color) {
    // Convert color to grayscale and check if it's dark
    double luminance =
        0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;
    return luminance < 128;
  }
}
