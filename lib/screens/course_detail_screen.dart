import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/course_notes.dart';
import 'package:notex/models/course.dart';

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

  @override
  Widget build(BuildContext context) {
    final Color courseColor = Color(
      int.parse(widget.color.replaceAll('#', '0xFF')),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseCode, style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: courseColor,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Course header
                  Container(
                    padding: EdgeInsets.all(16),
                    color: courseColor.withOpacity(0.1),
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
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Instructor: $_instructor',
                          style: TextStyle(fontSize: 16, fontFamily: 'Poppins'),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            _infoChip(Icons.note, '$_noteCount Notes'),
                            SizedBox(width: 16),
                            _infoChip(Icons.people, '$_studentCount Students'),
                          ],
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _toggleEnrollment,
                            child: Text(
                              _isEnrolled ? 'Unenroll' : 'Enroll in Course',
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isEnrolled ? Colors.red : courseColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    labelColor: courseColor,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: courseColor,
                    tabs: [
                      Tab(
                        icon: Icon(Icons.announcement),
                        text: 'Announcements',
                      ),
                      Tab(icon: Icon(Icons.description), text: 'Recent Notes'),
                    ],
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Announcements tab
                        _announcements.isEmpty
                            ? Center(
                              child: Text(
                                'No announcements yet',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _announcements.length,
                              padding: EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final announcement = _announcements[index];
                                final date = announcement['timestamp'];

                                return Card(
                                  margin: EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
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
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  fontFamily: 'Poppins',
                                                ),
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'No notes available yet',
                                    style: TextStyle(fontFamily: 'Poppins'),
                                  ),
                                  SizedBox(height: 16),
                                  ElevatedButton(
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
                              padding: EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                if (index == _recentNotes.length) {
                                  return Center(
                                    child: TextButton(
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      note['title'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    subtitle: Text(
                                      'By: ${note['ownerEmail']} • ${date.day}/${date.month}/${date.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                      ),
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
                                              (context) => PDFViewerPage(
                                                pdfUrl: note['fileUrl'],
                                                noteTitle: note['title'],
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
