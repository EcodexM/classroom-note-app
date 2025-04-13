import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/services/coursesvs.dart';
import 'package:notex/homepage.dart';
import 'package:notex/widgets/sharednote.dart';
import 'package:notex/widgets/search.dart';
import 'package:intl/intl.dart';
import 'package:notex/course_notes.dart';

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
  bool _showAddCourseDialog = false;
  String _debugInfo = ''; // Added for debugging

  // Text controllers for adding a course
  final TextEditingController _courseTitleController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _professorController = TextEditingController();

  // List of educational image URLs
  final List<String> _educationalImages = [
    'https://unsplash.com/photos/people-sitting-on-chair-in-front-of-computer-YRMWVcdyhmI',
    'https://unsplash.com/photos/photo-of-brown-wooden-bookshelf-xrbbXIXAWY0',
    'https://unsplash.com/photos/brown-concrete-palace-under-blue-sky-at-daytime-d6ebY-faOO0',
    'https://unsplash.com/photos/web-designer-working-on-website-ux-app-development-VbVJy_IQrBE',
    'https://unsplash.com/photos/education-concept-old-books-and-eye-glasses-on-blackboard-background-Sk9JF1KDz6M',
    'https://unsplash.com/photos/a-group-of-people-in-a-room-with-a-projector-screen-1-aA2Fadydc',
    'https://unsplash.com/photos/a-group-of-people-sitting-in-chairs-in-a-room-7hxOWrk-8RI',
    'https://unsplash.com/photos/white-and-brown-wooden-conference-table-vfRkE_9wuPo',
    'https://unsplash.com/photos/shallow-focus-photography-of-books-lUaaKCUANVI',
    'https://unsplash.com/photos/w-T1VDxb6io',
    'https://unsplash.com/photos/book-lot-on-table-9BoqXzEeQqM',
    'https://unsplash.com/photos/lab-glassware-science-laboratory-research-and-development-concept-LdwPILe8Tlc',
    'https://unsplash.com/photos/a-pair-of-scissors-a-ruler-and-a-ruler-on-a-table-Wq5hLAR8SOw',
    'https://unsplash.com/photos/a-wooden-table-topped-with-a-palette-of-paint-vpflEzQ8-HM',
    'https://unsplash.com/photos/colosseum-in-rome-italy-long-exposure-shot-the-rome-colosseum-was-built-in-the-time-of-ancient-rome-in-the-city-center-it-is-the-main-travel-destination-and-tourist-attraction-of-italy-FWFTOJTRih8',
  ];

  // Accent colors for courses
  final List<Color> _accentColors = [
    Color(0xFFFF9E80), // Deep Orange accent
    Color(0xFFFF80AB), // Pink accent
    Color(0xFFEA80FC), // Purple accent
    Color(0xFFB388FF), // Deep Purple accent
    Color(0xFF8C9EFF), // Indigo accent
    Color(0xFF82B1FF), // Blue accent
    Color(0xFF80D8FF), // Light Blue accent
    Color(0xFF84FFFF), // Cyan accent
    Color(0xFFA7FFEB), // Teal accent
    Color(0xFFB9F6CA), // Green accent
  ];

  @override
  void initState() {
    super.initState();
    _loadUserCourses();
    // Added for debugging
  }

  @override
  void dispose() {
    _courseTitleController.dispose();
    _courseCodeController.dispose();
    _professorController.dispose();
    super.dispose();
  }

  // Load enrolled courses for the current user
  Future<void> _loadUserCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _debugInfo += "No user found when loading courses\n";
        });
        return;
      }

      // *** DIRECT FIRESTORE ACCESS INSTEAD OF USING SERVICE ***
      // This bypasses the service to check if we can get courses directly

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

      List<Map<String, dynamic>> courseMaps = [];

      for (var courseId in enrolledCourseIds) {
        final courseDoc =
            await FirebaseFirestore.instance
                .collection('courses')
                .doc(courseId)
                .get();

        if (courseDoc.exists) {
          // Assign a consistent color based on course ID
          final Color accentColor =
              _accentColors[courseDoc.id.hashCode % _accentColors.length];

          courseMaps.add({
            'id': courseDoc.id,
            'code': courseDoc.data()?['code'] ?? 'Unknown Code',
            'name': courseDoc.data()?['name'] ?? 'Unnamed Course',
            'instructor': courseDoc.data()?['instructor'] ?? 'Unknown',
            'department': courseDoc.data()?['department'] ?? '',
            'noteCount': courseDoc.data()?['noteCount'] ?? 0,
            'color': courseDoc.data()?['color'] ?? '#FFFFFF',
            'accentColor': accentColor,
            'imageUrl': _getRandomEducationalImage(),
          });
        }
      }

      setState(() {
        _userCourses = courseMaps;
        _filteredCourses = courseMaps;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading courses: $e');
      _debugInfo += "Error loading courses: $e\n";
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get a random educational image URL
  String _getRandomEducationalImage() {
    return _educationalImages[DateTime.now().millisecondsSinceEpoch %
        _educationalImages.length];
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

  Future<void> _addCourse() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Validate inputs
    if (_courseTitleController.text.trim().isEmpty ||
        _courseCodeController.text.trim().isEmpty ||
        _professorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showAddCourseDialog = false;
    });

    try {
      // Generate search terms
      final searchTerms = [
        _courseTitleController.text.trim().toLowerCase(),
        _courseCodeController.text.trim().toLowerCase(),
        _professorController.text.trim().toLowerCase(),
      ];

      // Generate a random color for the new course
      final randomColor =
          _accentColors[DateTime.now().millisecondsSinceEpoch %
              _accentColors.length];
      final colorHex = '#${randomColor.value.toRadixString(16).substring(2)}';

      // Add course to Firestore
      final courseRef = await FirebaseFirestore.instance
          .collection('courses')
          .add({
            'name': _courseTitleController.text.trim(),
            'code': _courseCodeController.text.trim(),
            'instructor': _professorController.text.trim(),
            'department': '',
            'noteCount': 0,
            'color': colorHex,
            'searchTerms': searchTerms,
            'createdBy': currentUser.email ?? 'unknown',
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Manually check that the course was created
      final newCourseDoc =
          await FirebaseFirestore.instance
              .collection('courses')
              .doc(courseRef.id)
              .get();

      if (newCourseDoc.exists) {
      } else {}

      // Enroll the user in the new course
      final enrollmentRef = await FirebaseFirestore.instance
          .collection('course_enrollments')
          .add({
            'courseId': courseRef.id,
            'studentEmail': currentUser.email,
            'enrollmentDate': FieldValue.serverTimestamp(),
          });

      // Manually check that the enrollment was created
      final newEnrollmentDoc =
          await FirebaseFirestore.instance
              .collection('course_enrollments')
              .doc(enrollmentRef.id)
              .get();

      if (newEnrollmentDoc.exists) {
      } else {}

      // Wait a bit before refreshing to ensure Firestore has propagated changes
      await Future.delayed(Duration(seconds: 1));

      // Refresh courses list
      await _loadUserCourses();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _debugInfo += "Error adding course: $e\n";
      print("Error adding course: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_showAddCourseDialog) {
          setState(() {
            _showAddCourseDialog = false;
          });
          return false;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        return false;
      },
      child: Stack(
        children: [
          // Main screen
          Scaffold(
            backgroundColor: Color(0xFF2E2E2E), // Dark background for margin
            body: Container(
              margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.018),
              decoration: BoxDecoration(
                color: Color(
                  0xFFFAF3F0,
                ), // Light cream background matching Image 1
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Custom header matching the design in the image
                  _buildHeader(),

                  // Search widget
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: _handleSearch,
                        decoration: InputDecoration(
                          hintText: 'Search courses...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                          suffixIcon: Icon(Icons.tune, color: Colors.grey),
                        ),
                      ),
                    ),
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

                  // Debug info - comment out or remove in production
                  if (_debugInfo.isNotEmpty)
                    Container(
                      height: 100,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _debugInfo,
                          style: TextStyle(color: Colors.green, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton:
                _filteredCourses.isNotEmpty
                    ? Padding(
                      padding: const EdgeInsets.only(bottom: 32.0, right: 24.0),
                      child: FloatingActionButton(
                        onPressed: () {
                          setState(() {
                            _showAddCourseDialog = true;
                          });
                        },
                        backgroundColor: Color.fromARGB(255, 83, 183, 58),
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    )
                    : null,
          ),

          // Add Course Dialog (shown as an overlay when _showAddCourseDialog is true)
          if (_showAddCourseDialog)
            Material(
              type: MaterialType.transparency,
              child: Center(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      decoration: BoxDecoration(
                        color: Color(
                          0xFFFCE4EC,
                        ), // Light pink background from Image 2
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Text(
                            'ADD NEW COURSE',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20),

                          // Course Title - matching Image 2
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: TextField(
                                controller: _courseTitleController,
                                decoration: InputDecoration(
                                  hintText: 'Course Title',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),

                          // Course Code - matching Image 2
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: TextField(
                                controller: _courseCodeController,
                                decoration: InputDecoration(
                                  hintText: 'Course Code',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),

                          // Professor - matching Image 2
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: TextField(
                                controller: _professorController,
                                decoration: InputDecoration(
                                  hintText: 'Professor',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),

                          // Buttons row - matching Image 2
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Cancel button
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showAddCourseDialog = false;
                                  });
                                },
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),

                              // Add Course button
                              Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF673AB7), // Deep Purple
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _addCourse,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'Add Course',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'porterssans',
            ),
          ),
          Spacer(),
          // Navigation buttons
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFE17B37), // Orange button (Courses)
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Courses',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => MyNotesPage()),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Notes',
                style: TextStyle(color: Colors.black54, fontFamily: 'Poppins'),
              ),
            ),
          ),
          SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => SharedNotesScreen()),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Shared With Me',
                style: TextStyle(color: Colors.black54, fontFamily: 'Poppins'),
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            DateFormat('HH:mm').format(DateTime.now()),
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
          Icon(Icons.school, size: 80, color: Colors.grey),
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
          SizedBox(height: 24),
          // Add Course button - matching Image 1
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add Course'),
            onPressed: () {
              setState(() {
                _showAddCourseDialog = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50), // Green matching Image 1
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12, top: 16, bottom: 60),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive column count
          int crossAxisCount = 6; // default
          double width = constraints.maxWidth;

          if (width < 500) {
            crossAxisCount = 3; // Mobile (portrait)
          } else if (width < 900) {
            crossAxisCount = 4; // Tablets or medium screen
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: _filteredCourses.length,
            itemBuilder: (context, index) {
              final course = _filteredCourses[index];
              return _buildCourseCard(course);
            },
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return GestureDetector(
      onTap: () {
        // Navigate to course notes page
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
        ).then((_) {
          // Refresh courses after returning from notes page
          _loadUserCourses();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image at the top (matching Image 3)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                height: 150,
                child: Image.network(
                  course['imageUrl'] ?? _getRandomEducationalImage(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(height: 150, color: Colors.grey[200]);
                  },
                ),
              ),
            ),
            // Course details at the bottom (matching Image 3)
            Expanded(
              child: Container(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      course['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      course['instructor'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      course['code'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
