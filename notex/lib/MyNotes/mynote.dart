import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/services/offline_service.dart';
import 'package:notex/widgets/header.dart';
import 'package:notex/models/note.dart';
import 'package:notex/services/notemgn.dart';
import 'package:notex/widgets/courses.dart';
import 'package:notex/widgets/sharednote.dart';
import 'package:notex/homepage.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:notex/widgets/search.dart';

class MyNotesPage extends StatefulWidget {
  const MyNotesPage({Key? key}) : super(key: key);

  @override
  _MyNotesPageState createState() => _MyNotesPageState();
}

class _MyNotesPageState extends State<MyNotesPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  String _searchQuery = '';

  // Animation controllers for the color palette
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  bool _isColorPaletteVisible = false;

  // Color palette
  final List<Color> _noteColors = [
    Color(0xFFE57373), // Red
    Color(0xFFFFB74D), // Orange
    Color(0xFFFFF176), // Yellow
    Color(0xFFAED581), // Light Green
    Color(0xFF4FC3F7), // Light Blue
    Color(0xFF9575CD), // Purple
    Color(0xFFF06292), // Pink
    Color(0xFF4DB6AC), // Teal
    Color(0xFFFFD54F), // Amber
    Color(0xFFE0E0E0), // Grey
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees in turns (1/8 of a full rotation)
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleColorPalette() {
    setState(() {
      _isColorPaletteVisible = !_isColorPaletteVisible;
      if (_isColorPaletteVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _selectColor(Color color) {
    _toggleColorPalette(); // Close the color palette

    // Open the note creation dialog with the selected color
    _showAddNoteDialog(color);
  }

  // Show a popup dialog for adding a new note
  void _showAddNoteDialog(Color selectedColor) {
    final TextEditingController _titleController = TextEditingController();
    final TextEditingController _tagController = TextEditingController();
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    bool _isPublic = true;
    String? _selectedCourseId;
    String? _selectedFileName;
    File? _selectedFile;
    List<String> _tags = [];
    List<Map<String, dynamic>> _courses = [];
    bool _isUploading = false;
    double _uploadProgress = 0.0;

    // Convert Color to hex string for storage
    String colorHex = '#${selectedColor.value.toRadixString(16).substring(2)}';

    // Load courses for the dropdown
    Future<List<Map<String, dynamic>>> _loadCourses() async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return [];

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

        return courses; // Return the list of courses
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading courses: $error')),
        );
        return [];
      }
    }

    // Pick a PDF file
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

    // Add a tag
    void _addTag() {
      final tag = _tagController.text.trim();
      if (tag.isNotEmpty && !_tags.contains(tag)) {
        setState(() {
          _tags.add(tag);
          _tagController.clear();
        });
      }
    }

    // Remove a tag
    void _removeTag(String tag) {
      setState(() {
        _tags.remove(tag);
      });
    }

    // Upload the note to Firebase
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
        final noteRef = await FirebaseFirestore.instance
            .collection('notes')
            .add({
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
              'color': colorHex, // Store the selected color
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

        Navigator.pop(context); // Close the dialog
        _loadNotes(); // Refresh the notes list
      } catch (error) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading note: $error')));
      }
    }

    // Load courses first, then show the dialog
    _loadCourses().then((courses) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                insetPadding: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: 800,
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  color: selectedColor,
                  child:
                      _isUploading
                          ? _buildUploadingState(_uploadProgress)
                          : _buildNoteForm(
                            context,
                            _titleController,
                            _tagController,
                            _formKey,
                            setState,
                            selectedColor,
                            _isPublic,
                            (value) {
                              setState(() {
                                _isPublic = value;
                              });
                            },
                            _selectedCourseId,
                            (value) {
                              setState(() {
                                _selectedCourseId = value;
                              });
                            },
                            _pickFile,
                            _selectedFileName,
                            _addTag,
                            _removeTag,
                            _tags,
                            _uploadNote,
                            courses,
                          ),
                ),
              );
            },
          );
        },
      );
    });
  }

  // Widget for the uploading state
  Widget _buildUploadingState(double progress) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
          SizedBox(height: 16),
          Text(
            'Uploading... ${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Widget for the note form
  Widget _buildNoteForm(
    BuildContext context,
    TextEditingController titleController,
    TextEditingController tagController,
    GlobalKey<FormState> formKey,
    StateSetter setState,
    Color backgroundColor,
    bool isPublic,
    Function(bool) onPublicChanged,
    String? selectedCourseId,
    Function(String?) onCourseChanged,
    Function() onPickFile,
    String? selectedFileName,
    Function() onAddTag,
    Function(String) onRemoveTag,
    List<String> tags,
    Function() onUpload,
    List<Map<String, dynamic>> courses,
  ) {
    final formattedDate = DateFormat.yMMMd().format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with note creation date and close button
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _darkenColor(backgroundColor, 0.1),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Note',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Form content with scrolling
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Note Details section
                  Text(
                    'Note Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 16),

                  // Title field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.title, color: Colors.grey),
                        hintText: 'Title',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
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
                      value: selectedCourseId,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.school, color: Colors.grey),
                        hintText: 'Course',
                        border: InputBorder.none,
                      ),
                      items:
                          courses.map((course) {
                            return DropdownMenuItem<String>(
                              value: course['id'],
                              child: Text(
                                '${course['code']} - ${course['name']}',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                            );
                          }).toList(),
                      onChanged: onCourseChanged,
                      icon: Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      hint: Text('Course'),
                    ),
                  ),
                  SizedBox(height: 12),

                  // File selection
                  InkWell(
                    onTap: onPickFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFileName != null
                                ? Icons.insert_drive_file
                                : Icons.upload_file,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedFileName ?? 'Select PDF file',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color:
                                    selectedFileName != null
                                        ? Colors.black87
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (selectedFileName == null) ...[
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
                  Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
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
                            controller: tagController,
                            decoration: InputDecoration(
                              hintText:
                                  'Add tags (e.g., midterm, lecture, etc.)',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            onSubmitted: (_) => onAddTag(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: onAddTag,
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
                        tags.map((tag) {
                          return Chip(
                            label: Text(
                              tag,
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                            deleteIcon: Icon(Icons.close, size: 18),
                            onDeleted: () => onRemoveTag(tag),
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
                          value: isPublic,
                          onChanged: onPublicChanged,
                          activeColor: Colors.deepPurple,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Upload button
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _darkenColor(backgroundColor, 0.1),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: ElevatedButton(
            onPressed: onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
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
    );
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final noteService = NoteService();
      final notes = await noteService.getUserNotes();

      // Convert to the existing format
      List<Map<String, dynamic>> noteMaps = [];
      for (var note in notes) {
        final courseDoc =
            await FirebaseFirestore.instance
                .collection('courses')
                .doc(note.courseId)
                .get();

        String courseCode = 'Unknown';
        String courseName = 'Unknown Course';

        if (courseDoc.exists) {
          courseCode = courseDoc.data()?['code'] ?? 'Unknown';
          courseName = courseDoc.data()?['name'] ?? 'Unknown Course';
        }

        // Fetch the color from Firestore
        DocumentSnapshot noteSnapshot =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(note.id)
                .get();

        String noteColor = '#FFF0F0'; // Default color
        if (noteSnapshot.exists) {
          final data = noteSnapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('color')) {
            noteColor = data['color'];
          }
        }

        noteMaps.add({
          'id': note.id,
          'title': note.title,
          'courseId': note.courseId,
          'courseCode': courseCode,
          'courseName': courseName,
          'ownerEmail': note.ownerEmail,
          'fileUrl': note.fileUrl,
          'fileName': note.fileName,
          'uploadDate': note.uploadDate,
          'downloads': note.downloads,
          'averageRating': note.averageRating,
          'isPublic': note.isPublic,
          'tags': note.tags,
          'color': noteColor,
        });
      }

      if (mounted) {
        setState(() {
          _notes = noteMaps;
          _filteredNotes = noteMaps;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading notes: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Test Case 2.1 - Handle search
  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();

      if (_searchQuery.isEmpty) {
        _filteredNotes = _notes;
      } else {
        // Filter notes based on search query
        _filteredNotes =
            _notes.where((note) {
              return note['title'].toLowerCase().contains(_searchQuery) ||
                  note['courseCode'].toLowerCase().contains(_searchQuery) ||
                  note['courseName'].toLowerCase().contains(_searchQuery) ||
                  (note['tags'] != null &&
                      note['tags'].any(
                        (tag) => tag.toLowerCase().contains(_searchQuery),
                      ));
            }).toList();
      }
    });
  }

  // Test Case 2.2 & 2.3 - Handle filter and sort
  void _handleFilter(String filterOptions) {
    // Parse the filter options
    final Map<String, dynamic> options = _parseFilterOptions(filterOptions);

    setState(() {
      List<Map<String, dynamic>> filtered = List.from(_notes);

      // Apply subject filter if selected
      final String subject = options['subject'] ?? '';
      if (subject.isNotEmpty) {
        filtered =
            filtered.where((note) {
              return note['courseName'].toLowerCase().contains(
                subject.toLowerCase(),
              );
            }).toList();
      }

      // Apply sorting if selected
      final String sort = options['sort'] ?? '';
      if (sort.isNotEmpty) {
        switch (sort) {
          case 'latest':
            filtered.sort((a, b) => b['uploadDate'].compareTo(a['uploadDate']));
            break;
          case 'oldest':
            filtered.sort((a, b) => a['uploadDate'].compareTo(b['uploadDate']));
            break;
          case 'highest_rating':
            filtered.sort(
              (a, b) => b['averageRating'].compareTo(a['averageRating']),
            );
            break;
          case 'most_downloaded':
            filtered.sort((a, b) => b['downloads'].compareTo(a['downloads']));
            break;
        }
      }

      // Apply search query if any
      if (_searchQuery.isNotEmpty) {
        filtered =
            filtered.where((note) {
              return note['title'].toLowerCase().contains(_searchQuery) ||
                  note['courseCode'].toLowerCase().contains(_searchQuery) ||
                  note['courseName'].toLowerCase().contains(_searchQuery) ||
                  (note['tags'] != null &&
                      note['tags'].any(
                        (tag) => tag.toLowerCase().contains(_searchQuery),
                      ));
            }).toList();
      }

      _filteredNotes = filtered;
    });
  }

  Map<String, dynamic> _parseFilterOptions(String filterOptionsString) {
    // Simple parsing of the filter options string
    final Map<String, dynamic> options = {};

    // Extract subject
    final subjectMatch = RegExp(
      r"subject: ([^,}]+)",
    ).firstMatch(filterOptionsString);
    if (subjectMatch != null && subjectMatch.group(1) != null) {
      options['subject'] = subjectMatch.group(1)!.trim();
    }

    // Extract sort
    final sortMatch = RegExp(r"sort: ([^,}]+)").firstMatch(filterOptionsString);
    if (sortMatch != null && sortMatch.group(1) != null) {
      options['sort'] = sortMatch.group(1)!.trim();
    }

    return options;
  }

  Future<void> _viewNote(Map<String, dynamic> note) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PDFViewerPage(
                pdfUrl: note['fileUrl'],
                noteTitle: note['title'],
                noteId: note['id'],
                courseId: note['courseId'],
                courseCode: note['courseCode'],
                isPublic: note['isPublic'],
              ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening note: $error')));
    }
  }

  Future<void> _makeAvailableOffline(Map<String, dynamic> note) async {
    final offlineService = OfflineService();
    final isAvailable = await offlineService.isNoteAvailableOffline(note['id']);

    if (isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Note already available offline')));
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Downloading',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: const Color(0xFFFF8C42)),
                SizedBox(height: 16),
                Text(
                  'Saving note for offline access...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );

    // Create Note model from the map
    final noteModel = Note(
      id: note['id'],
      title: note['title'],
      courseId: note['courseId'],
      ownerEmail: note['ownerEmail'],
      fileUrl: note['fileUrl'],
      fileName: note['fileName'],
      uploadDate: note['uploadDate'],
      isPublic: note['isPublic'],
      downloads: note['downloads'],
      averageRating: note['averageRating'],
      tags: note['tags'],
    );

    final success = await offlineService.saveNoteForOffline(noteModel);

    // Close dialog
    if (mounted) Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Note saved for offline access',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download note',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Custom back navigation logic
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        // Use dark background color for margins
        backgroundColor: Color(0xFF2E2E2E),
        body: Container(
          // Add margin around the content
          margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.018),
          decoration: BoxDecoration(
            color: Color(0xFFF2E9E5), // Main content background
            borderRadius: BorderRadius.circular(24), // Rounded corners
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with logo and navigation
                  _buildHeader(),

                  // Search widget
                  SearchWidget(
                    onSearch: _handleSearch,
                    onFilter: _handleFilter,
                    hintText: 'Search your notes...',
                  ),

                  // Main content with notes in a grid
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF8C42),
                              ),
                            )
                            : _filteredNotes.isEmpty
                            ? _buildEmptyState()
                            : _buildNotesGrid(),
                  ),
                ],
              ),

              // Color palette and add button
              Positioned(
                right: 16,
                bottom: 16,
                child: _buildColorPaletteAndAddButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            },
          ),
          SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Color(0xFFFFB74D),
            child: Icon(Icons.menu_book, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text(
            'NOTEX',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'porterssans',
              color: Colors.black87,
            ),
          ),
          Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => CoursesPage()),
                  );
                },
                child: Text(
                  'Courses',
                  style: TextStyle(
                    color: Colors.black54,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Already on notes page
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Color(0xFFFF8C42)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                child: Text(
                  'Notes',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => SharedNotesScreen()),
                  );
                },
                child: Text(
                  'Shared With Me',
                  style: TextStyle(
                    color: Colors.black54,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
          Text(
            DateFormat.Hm().format(DateTime.now()),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_outlined, size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'No notes found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first note using the + button',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return _buildNoteCard(note);
      },
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    // Convert stored hex color string to Color object
    final Color cardColor = _getColorFromHex(note['color'] ?? '#FFF0F0');

    return GestureDetector(
      onTap: () => _viewNote(note),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with overflow control
                  Text(
                    note['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Date
                  Text(
                    _formatDate(note['uploadDate']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Spacer(),
                  // Course info with overflow control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          note['courseCode'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        note['isPublic'] ? 'Public' : 'Private',
                        style: TextStyle(
                          fontSize: 12,
                          color: note['isPublic'] ? Colors.green : Colors.red,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Offline button in a consistent position
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.offline_bolt_outlined),
                onPressed: () => _makeAvailableOffline(note),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPaletteAndAddButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color palette (visible only when activated)
        AnimatedOpacity(
          opacity: _isColorPaletteVisible ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height:
                _isColorPaletteVisible
                    ? 400
                    : 0, // Increased height for vertical stack
            width: 50,
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_noteColors.length, (index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 100 + (index * 30)),
                  transform: Matrix4.translationValues(
                    0,
                    _isColorPaletteVisible
                        ? 0
                        : 50.0 * (_noteColors.length - index),
                    0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: GestureDetector(
                      onTap: () => _selectColor(_noteColors[index]),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _noteColors[index],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        SizedBox(height: 16),

        // Add button with rotation animation
        FloatingActionButton(
          onPressed: _toggleColorPalette,
          backgroundColor: Color(0xFF9575CD), // Purple color
          elevation: 6,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: Icon(Icons.add, color: Colors.white, size: 30),
              );
            },
          ),
        ),
      ],
    );
  }

  // Convert hex color string to Color
  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  // Helper function to darken a color
  Color _darkenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  // Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return DateFormat.yMMMd().format(date);
  }
}
