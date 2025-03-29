import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/widgets/app_drawer.dart';
import 'package:notex/widgets/notifications.dart';
import 'package:notex/screens/search_screen.dart';
import 'package:notex/course_notes.dart';
import 'package:notex/screens/course_detail_screen.dart';
import 'package:notex/login.dart';
import 'package:notex/widgets/stat_card.dart';
import 'package:notex/models/course.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showNotification = false;
  List<Course> _userCourses = [];
  List<Map<String, dynamic>> _notifications = [];
  int _totalUploads = 0;
  int _totalDownloads = 0;
  bool _isLoading = false;
  int _currentTabIndex = 1; // Default to "Courses" tab

  @override
  void initState() {
    super.initState();
    _loadUserCourses();
    _loadUserStats();
    _loadNotifications();
  }

  Future<void> _loadUserCourses() async {
    setState(() {
      _isLoading = true;
    });

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
      List<Course> courses = [];
      for (var courseId in enrolledCourseIds) {
        final courseDoc =
            await FirebaseFirestore.instance
                .collection('courses')
                .doc(courseId)
                .get();

        if (courseDoc.exists) {
          courses.add(Course.fromFirestore(courseDoc.data()!, courseDoc.id));
        }
      }

      setState(() {
        _userCourses = courses;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading courses: $error');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading courses: $error')));
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Count uploads
      final uploadsQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('ownerEmail', isEqualTo: currentUser.email)
              .get();

      // Count downloads
      final downloadsQuery =
          await FirebaseFirestore.instance
              .collection('downloads')
              .where('userEmail', isEqualTo: currentUser.email)
              .get();

      setState(() {
        _totalUploads = uploadsQuery.docs.length;
        _totalDownloads = downloadsQuery.docs.length;
      });
    } catch (error) {
      print('Error loading user stats: $error');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final notificationsQuery =
          await FirebaseFirestore.instance
              .collection('notifications')
              .where('userEmail', isEqualTo: currentUser.email)
              .orderBy('createdAt', descending: true)
              .get();

      setState(() {
        _notifications =
            notificationsQuery.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
      });
    } catch (error) {
      print('Error loading notifications: $error');
    }
  }

  void _navigateToCourseDetail(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CourseDetailScreen(
              courseId: course.id,
              courseCode: course.code,
              courseName: course.name,
              color: course.color,
            ),
      ),
    );
  }

  void _enrollInCourse() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final departmentController = TextEditingController();
    final instructorController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Enroll in a Course'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Course Code',
                    hintText: 'e.g. CS 101',
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Course Name',
                    hintText: 'e.g. Introduction to Computer Science',
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    hintText: 'e.g. Computer Science',
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: instructorController,
                  decoration: InputDecoration(
                    labelText: 'Instructor',
                    hintText: 'e.g. Dr. Smith',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final code = codeController.text.trim();
                  final name = nameController.text.trim();
                  final department = departmentController.text.trim();
                  final instructor = instructorController.text.trim();

                  if (code.isEmpty ||
                      name.isEmpty ||
                      department.isEmpty ||
                      instructor.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please fill in all fields')),
                    );
                    return;
                  }

                  try {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) return;

                    // Check if course exists, if not create it
                    final courseQuery =
                        await FirebaseFirestore.instance
                            .collection('courses')
                            .where('code', isEqualTo: code)
                            .get();

                    String courseId;
                    if (courseQuery.docs.isEmpty) {
                      final searchTerms = [
                        code.toLowerCase(),
                        name.toLowerCase(),
                        department.toLowerCase(),
                        instructor.toLowerCase(),
                      ];
                      final courseRef = await FirebaseFirestore.instance
                          .collection('courses')
                          .add({
                            'code': code,
                            'name': name,
                            'department': department,
                            'instructor': instructor,
                            'noteCount': 0,
                            'color':
                                '#${(Colors.blue.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
                            'searchTerms': searchTerms,
                          });
                      courseId = courseRef.id;
                    } else {
                      courseId = courseQuery.docs.first.id;
                    }

                    // Enroll the user
                    await FirebaseFirestore.instance
                        .collection('course_enrollments')
                        .add({
                          'courseId': courseId,
                          'studentEmail': currentUser.email,
                          'enrollmentDate': FieldValue.serverTimestamp(),
                        });

                    Navigator.pop(context);
                    _loadUserCourses(); // Refresh the course list
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Enrolled successfully!')),
                    );
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error enrolling: $error')),
                    );
                  }
                },
                child: Text('Enroll'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  void _onTabSwitch(int index) {
    setState(() {
      _currentTabIndex = index;
    });

    // Navigate based on the selected tab
    if (index == 0) {
      // My Notes (handled by CourseNotesPage in each course)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select a course to view your notes')),
      );
    } else if (index == 1) {
      // Courses (already on this page)
    } else if (index == 2) {
      // Public Notes (handled by SearchScreen)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SearchScreen()),
      );
    }
  }

  Widget _buildHomePage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to NoteX',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your one-stop platform for sharing class notes',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),

            TextField(
              decoration: InputDecoration(
                hintText: 'Search courses or notes...',
                prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
                suffixIcon: Icon(Icons.filter_list, color: Colors.deepPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchScreen()),
                );
              },
            ),
            SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'My Courses',
                    value: _userCourses.length.toString(),
                    icon: Icons.school,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'My Notes',
                    value: _totalUploads.toString(),
                    icon: Icons.note,
                    color: Colors.green,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Downloads',
                    value: _totalDownloads.toString(),
                    icon: Icons.download,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            Text(
              'My Courses',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _userCourses.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No courses yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Enroll in a course to start sharing notes',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                      : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _userCourses.length,
                        itemBuilder: (context, index) {
                          final course = _userCourses[index];
                          return GestureDetector(
                            onTap: () => _navigateToCourseDetail(course),
                            child: Card(
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.deepPurple.shade100,
                                      Colors.white,
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            course.code,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.deepPurple,
                                            ),
                                          ),
                                          Icon(
                                            Icons.book,
                                            color: Colors.deepPurple,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        course.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Spacer(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.note,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '${course.noteCount} notes',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NoteX', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showNotification = !_showNotification;
                  });
                },
              ),
              if (_notifications.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${_notifications.length}',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: AppDrawer(onTabSwitch: _onTabSwitch),
      body: Stack(
        children: [
          _buildHomePage(),
          if (_showNotification)
            NotificationsPopup(
              onClose: () {
                setState(() {
                  _showNotification = false;
                });
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _enrollInCourse,
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Enroll in a Course',
      ),
    );
  }
}
