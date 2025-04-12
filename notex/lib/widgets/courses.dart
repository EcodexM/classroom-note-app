import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/services/coursesvs.dart';
import 'package:notex/homepage.dart';
import 'package:notex/widgets/sharednote.dart';
import 'package:notex/widgets/search.dart'; // Import the search widget
import 'package:intl/intl.dart';
import 'package:notex/course_notes.dart'; // Import the course notes page

class CoursesPage extends StatefulWidget {
  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _userCourses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
      final courseService = CourseService();
      final courses = await courseService.getUserCourses();

      List<Map<String, dynamic>> courseMaps = [];
      for (var course in courses) {
        courseMaps.add({
          'id': course.id,
          'code': course.code,
          'name': course.name,
          'instructor': course.instructor ?? 'Unknown',
          'department': course.department,
          'noteCount': course.noteCount,
          'color': course.color,
        });
      }

      setState(() {
        _userCourses = courseMaps;
        _filteredCourses = courseMaps;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading courses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle search functionality
  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();

      if (_searchQuery.isEmpty) {
        _filteredCourses = _userCourses;
      } else {
        _filteredCourses =
            _userCourses.where((course) {
              return course['code'].toLowerCase().contains(_searchQuery) ||
                  course['name'].toLowerCase().contains(_searchQuery) ||
                  course['instructor'].toLowerCase().contains(_searchQuery) ||
                  course['department'].toLowerCase().contains(_searchQuery);
            }).toList();
      }
    });
  }

  // Handle filter functionality
  void _handleFilter(String filterOptions) {
    // Parse the filter options
    final Map<String, dynamic> options = _parseFilterOptions(filterOptions);

    setState(() {
      List<Map<String, dynamic>> filtered = List.from(_userCourses);

      // Apply department filter if selected
      final String department = options['subject'] ?? '';
      if (department.isNotEmpty) {
        filtered =
            filtered.where((course) {
              return course['department'].toLowerCase().contains(
                department.toLowerCase(),
              );
            }).toList();
      }

      // Apply sorting if selected
      final String sort = options['sort'] ?? '';
      if (sort.isNotEmpty) {
        switch (sort) {
          case 'a-z':
            filtered.sort((a, b) => a['name'].compareTo(b['name']));
            break;
          case 'z-a':
            filtered.sort((a, b) => b['name'].compareTo(a['name']));
            break;
          case 'most_notes':
            filtered.sort((a, b) => b['noteCount'].compareTo(a['noteCount']));
            break;
        }
      }

      // Apply search query if any
      if (_searchQuery.isNotEmpty) {
        filtered =
            filtered.where((course) {
              return course['code'].toLowerCase().contains(_searchQuery) ||
                  course['name'].toLowerCase().contains(_searchQuery) ||
                  course['instructor'].toLowerCase().contains(_searchQuery) ||
                  course['department'].toLowerCase().contains(_searchQuery);
            }).toList();
      }

      _filteredCourses = filtered;
    });
  }

  Map<String, dynamic> _parseFilterOptions(String filterOptionsString) {
    // Simple parsing of the filter options string
    final Map<String, dynamic> options = {};

    // Extract subject/department
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFF2E2E2E), // Dark background for margin
        body: Container(
          margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.018),
          decoration: BoxDecoration(
            color: Color(0xFFF2E9E5), // Consistent background color
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Custom header matching the design in the image
              _buildHeader(),

              // Search widget
              SearchWidget(
                onSearch: _handleSearch,
                onFilter: _handleFilter,
                hintText: 'Search courses...',
              ),

              // Main content
              Expanded(
                child:
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _filteredCourses.isEmpty
                        ? _buildEmptyCourses()
                        : _buildCoursesList(),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewCourse,
          backgroundColor: Colors.deepPurple,
          child: Icon(Icons.add, color: Colors.white),
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
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  // Already on courses page
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
                  'Courses',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => MyNotesPage()),
                  );
                },
                child: Text(
                  'Notes',
                  style: TextStyle(
                    color: Colors.black54,
                    fontFamily: 'Poppins',
                  ),
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
        itemCount: _filteredCourses.length,
        itemBuilder: (context, index) {
          final course = _filteredCourses[index];
          final color = Color(
            int.parse(course['color'].replaceAll('#', '0xFF')),
          );

          return Card(
            margin: EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                // Navigate to course notes
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => CourseNotesPage(
                          courseId: course['id'],
                          courseName: course['name'],
                          courseCode: course['code'],
                        ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
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
