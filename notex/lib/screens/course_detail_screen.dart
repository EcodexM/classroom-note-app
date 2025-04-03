import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/course_notes.dart';
import 'package:notex/models/course.dart';
import 'package:notex/widgets/header.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseName;
  final String color;

  CourseDetailScreen({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.color,
  });

  @override
  _CourseDetailScreenState createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isEnrolled = false;
  int _noteCount = 0;
  int _studentCount = 0;
  String _instructor = "";
  List<Map<String, dynamic>> _recentNotes = [];
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCourseDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get course details
      final courseDoc =
          await FirebaseFirestore.instance
              .collection('courses')
              .doc(widget.courseId)
              .get();

      if (courseDoc.exists) {
        setState(() {
          _noteCount = courseDoc.data()?['noteCount'] ?? 0;
          _instructor = courseDoc.data()?['instructor'] ?? 'Unknown Instructor';
        });
      }

      // Check if user is enrolled
      final enrollmentDoc =
          await FirebaseFirestore.instance
              .collection('course_enrollments')
              .where('courseId', isEqualTo: widget.courseId)
              .where('studentEmail', isEqualTo: currentUser.email)
              .limit(1)
              .get();

      setState(() {
        _isEnrolled = enrollmentDoc.docs.isNotEmpty;
      });

      // Get student count
      final studentCountDoc =
          await FirebaseFirestore.instance
              .collection('course_enrollments')
              .where('courseId', isEqualTo: widget.courseId)
              .count()
              .get();

      setState(() {
        _studentCount = studentCountDoc.count!;
      });

      // Get recent notes
      final recentNotesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('courseId', isEqualTo: widget.courseId)
              .where('isPublic', isEqualTo: true)
              .orderBy('uploadDate', descending: true)
              .limit(5)
              .get();

      List<Map<String, dynamic>> recentNotes = [];

      for (var doc in recentNotesQuery.docs) {
        recentNotes.add({
          'id': doc.id,
          'title': doc.data()['title'] ?? 'Untitled Note',
          'ownerEmail': doc.data()['ownerEmail'] ?? 'Unknown',
          'uploadDate': doc.data()['uploadDate']?.toDate() ?? DateTime.now(),
          'fileUrl': doc.data()['fileUrl'] ?? '',
          'downloads': doc.data()['downloads'] ?? 0,
        });
      }

      // Get announcements
      final announcementsQuery =
          await FirebaseFirestore.instance
              .collection('course_announcements')
              .where('courseId', isEqualTo: widget.courseId)
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();

      List<Map<String, dynamic>> announcements = [];

      for (var doc in announcementsQuery.docs) {
        announcements.add({
          'id': doc.id,
          'title': doc.data()['title'] ?? 'Announcement',
          'message': doc.data()['message'] ?? '',
          'timestamp': doc.data()['timestamp']?.toDate() ?? DateTime.now(),
        });
      }

      setState(() {
        _recentNotes = recentNotes;
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading course details: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleEnrollment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      if (_isEnrolled) {
        // Unenroll
        final enrollmentQuery =
            await FirebaseFirestore.instance
                .collection('course_enrollments')
                .where('courseId', isEqualTo: widget.courseId)
                .where('studentEmail', isEqualTo: currentUser.email)
                .get();

        for (var doc in enrollmentQuery.docs) {
          await doc.reference.delete();
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unenrolled from course')));
      } else {
        // Enroll
        await FirebaseFirestore.instance.collection('course_enrollments').add({
          'courseId': widget.courseId,
          'studentEmail': currentUser.email,
          'enrollmentDate': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Enrolled in course')));
      }

      // Refresh course details
      _loadCourseDetails();
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating enrollment: $error')),
      );
    }
  }

  // Handler for tab selection in the header
  void _handleTabSelection(int index) {
    // Navigate based on index
    if (index != 1) {
      // Not the current tab (courses)
      Navigator.pop(context); // First go back to avoid stacking

      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/home');
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
    final Color courseColor = Color(
      int.parse(widget.color.replaceAll('#', '0xFF')),
    );

    return Scaffold(
      backgroundColor: Color(0xFFF2E9E5), // Consistent background color
      body: SafeArea(
        child: Column(
          children: [
            // Use the existing AppHeader with consistent positioning
            AppHeader(
              selectedIndex: 1, // Courses tab is selected
              pageIndex: 1, // Current page index
              onTabSelected: _handleTabSelection,
              onSignOut: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              showBackButton: true, // Show back button for detail screens
            ),

            // Main content with proper padding to avoid overflow
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        child: Column(
                          children: [
                            // Course header with consistent margins
                            Container(
                              margin: EdgeInsets.fromLTRB(24, 0, 24, 16),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: courseColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.courseName,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                    // Handle text overflow
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Instructor: $_instructor',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _infoChip(
                                        Icons.note,
                                        '$_noteCount Notes',
                                      ),
                                      SizedBox(width: 16),
                                      _infoChip(
                                        Icons.people,
                                        '$_studentCount Students',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _toggleEnrollment,
                                      child: Text(
                                        _isEnrolled
                                            ? 'Unenroll'
                                            : 'Enroll in Course',
                                        style: TextStyle(fontFamily: 'Poppins'),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            _isEnrolled
                                                ? Colors.red
                                                : courseColor,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Tab bar with consistent styling and margins
                            Container(
                              height: 50,
                              margin: EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TabBar(
                                controller: _tabController,
                                labelColor: courseColor,
                                unselectedLabelColor: Colors.grey[600],
                                indicatorColor: courseColor,
                                indicatorSize: TabBarIndicatorSize.label,
                                tabs: [
                                  Tab(text: 'Announcements'),
                                  Tab(text: 'Recent Notes'),
                                ],
                              ),
                            ),

                            SizedBox(height: 16),

                            // Tab content with consistent margins
                            Container(
                              height:
                                  MediaQuery.of(context).size.height *
                                  0.45, // Fixed height to prevent overflow
                              margin: EdgeInsets.symmetric(horizontal: 24),
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Announcements tab
                                  _announcements.isEmpty
                                      ? Center(
                                        child: Text(
                                          'No announcements yet',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      )
                                      : ListView.builder(
                                        itemCount: _announcements.length,
                                        padding:
                                            EdgeInsets
                                                .zero, // Use container margin instead
                                        itemBuilder: (context, index) {
                                          final announcement =
                                              _announcements[index];
                                          final date =
                                              announcement['timestamp'];

                                          return Card(
                                            margin: EdgeInsets.only(bottom: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                16.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.announcement,
                                                        color: courseColor,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          announcement['title'],
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 18,
                                                            fontFamily:
                                                                'Poppins',
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    announcement['message'],
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                    ),
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    '${date.day}/${date.month}/${date.year}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                  // Recent notes tab
                                  _recentNotes.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'No notes available yet',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => CourseNotesPage(
                                                          courseId:
                                                              widget.courseId,
                                                          courseName:
                                                              widget.courseName,
                                                          courseCode:
                                                              widget.courseCode,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Text('View All Notes'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: courseColor,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : ListView.builder(
                                        itemCount:
                                            _recentNotes.length +
                                            1, // +1 for "View all" button
                                        padding:
                                            EdgeInsets
                                                .zero, // Use container margin instead
                                        itemBuilder: (context, index) {
                                          if (index == _recentNotes.length) {
                                            return Center(
                                              child: TextButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (
                                                            context,
                                                          ) => CourseNotesPage(
                                                            courseId:
                                                                widget.courseId,
                                                            courseName:
                                                                widget
                                                                    .courseName,
                                                            courseCode:
                                                                widget
                                                                    .courseCode,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  'View All Notes',
                                                  style: TextStyle(
                                                    color: courseColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          final note = _recentNotes[index];
                                          final date = note['uploadDate'];

                                          return Card(
                                            margin: EdgeInsets.only(bottom: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: ListTile(
                                              title: Text(
                                                note['title'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Poppins',
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: Text(
                                                'By: ${note['ownerEmail']} • ${date.day}/${date.month}/${date.year}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'Poppins',
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              trailing: Text(
                                                '${note['downloads']} downloads',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => PDFViewerPage(
                                                          pdfUrl:
                                                              note['fileUrl'],
                                                          noteTitle:
                                                              note['title'],
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CourseNotesPage(
                    courseId: widget.courseId,
                    courseName: widget.courseName,
                    courseCode: widget.courseCode,
                  ),
            ),
          );
        },
        icon: Icon(Icons.note),
        label: Text('View Notes', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: courseColor,
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.deepPurple),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
        ],
      ),
    );
  }
}
