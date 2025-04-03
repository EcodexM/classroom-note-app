import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/widgets/header.dart'; // Import updated header

class CoursesPage extends StatefulWidget {
  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _userCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCourses();
  }

  // Load enrolled courses for the current user
  Future<void> _loadUserCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get user's enrolled courses
      final enrollmentsQuery =
          await FirebaseFirestore.instance
              .collection('course_enrollments')
              .where('studentEmail', isEqualTo: currentUser.email)
              .get();

      final enrolledCourseIds =
          enrollmentsQuery.docs
              .map((doc) => doc.data()['courseId'] as String)
              .toList();

      // Fetch details for each enrolled course
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
            'instructor': courseDoc.data()?['instructor'] ?? 'Unknown',
            'department': courseDoc.data()?['department'] ?? '',
            'noteCount': courseDoc.data()?['noteCount'] ?? 0,
            'color': courseDoc.data()?['color'] ?? '#3F51B5',
          });
        }
      }

      setState(() {
        _userCourses = courses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading courses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addNewCourse() {
    final titleController = TextEditingController();
    final codeController = TextEditingController();
    final professorController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Course Title'),
              ),
              TextField(
                controller: codeController,
                decoration: InputDecoration(labelText: 'Course Code'),
              ),
              TextField(
                controller: professorController,
                decoration: InputDecoration(labelText: 'Professor'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentUser = _auth.currentUser;
                if (currentUser == null) return;

                // Generate search terms
                final searchTerms = [
                  titleController.text.trim().toLowerCase(),
                  codeController.text.trim().toLowerCase(),
                  professorController.text.trim().toLowerCase(),
                ];

                // Add course to Firestore
                final courseRef = await FirebaseFirestore.instance
                    .collection('courses')
                    .add({
                      'name': titleController.text.trim(),
                      'code': codeController.text.trim(),
                      'instructor': professorController.text.trim(),
                      'department': '',
                      'noteCount': 0,
                      'color':
                          '#${(Colors.blue.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
                      'searchTerms': searchTerms,
                      'createdBy': currentUser.email ?? 'unknown',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                // Enroll the user in the new course
                await FirebaseFirestore.instance
                    .collection('course_enrollments')
                    .add({
                      'courseId': courseRef.id,
                      'studentEmail': currentUser.email,
                      'enrollmentDate': FieldValue.serverTimestamp(),
                    });

                Navigator.of(context).pop();

                // Refresh courses list
                _loadUserCourses();
              },
              child: Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
            ),
          ],
        );
      },
    );
  }

  // Function to handle tab selection
  void _handleTabSelection(int index) {
    // Navigate based on selected tab
    if (index != 1) {
      // Not the current tab (courses)
      Navigator.pop(context);

      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/');
          break;
        case 2: // Notes
          Navigator.pushReplacementNamed(context, '/notes');
          break;
        case 3: // Shared with me
          Navigator.pushReplacementNamed(context, '/shared');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2E9E5), // Consistent background color
      body: SafeArea(
        child: Column(
          children: [
            // Use updated header with consistent positioning
            AppHeader(
              selectedIndex: 1, // Courses tab
              pageIndex: 1,
              onTabSelected: _handleTabSelection,
              onSignOut: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              showBackButton: true,
            ),

            // Main content
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _userCourses.isEmpty
                      ? _buildEmptyCourses()
                      : _buildCoursesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCourse,
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyCourses() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No courses yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enroll in courses or add your own',
            style: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add Course'),
            onPressed: _addNewCourse,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: _userCourses.length,
        itemBuilder: (context, index) {
          final course = _userCourses[index];
          final color = Color(
            int.parse(course['color'].replaceAll('#', '0xFF')),
          );

          return Card(
            margin: EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Course icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        course['code'].substring(
                          0,
                          Math.min(2, course['code'].length),
                        ),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course code
                        Text(
                          course['code'],
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Course name
                        Text(
                          course['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Course instructor
                        Text(
                          'Instructor: ${course['instructor']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        // Course stats
                        Row(
                          children: [
                            _buildStat(
                              Icons.note,
                              '${course['noteCount']} notes',
                            ),
                            SizedBox(width: 16),
                            _buildStat(
                              Icons.school,
                              course['department'] ?? 'General',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

// Helper class for min function
class Math {
  static int min(int a, int b) => a < b ? a : b;
}
