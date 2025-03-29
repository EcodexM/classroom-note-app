import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/models/note.dart';
import 'package:notex/widgets/notifications.dart';
import 'package:notex/screens/search_screen.dart';
import 'package:notex/course_notes.dart';
import 'package:notex/screens/course_detail_screen.dart';
import 'package:notex/login.dart';
import 'package:notex/widgets/stat_card.dart';
import 'package:notex/models/course.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // State variables
  bool _showNotification = false;
  List<Course> _userCourses = [];
  List<Map<String, dynamic>> _notifications = [];
  int _totalUploads = 0;
  int _totalDownloads = 0;
  bool _isLoading = false;
  String _userName = "";
  String _currentTime = "";
  Timer? _timer;
  bool _showRightDrawer = false;

  // Animation controller - initialize as nullable
  AnimationController? _animationController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create animation
    _animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutBack,
    );

    // Start animation
    _animationController!.forward();

    _loadUserCourses();
    _loadUserStats();
    _loadNotifications();
    _loadUserName();
    _updateTime();

    // Update time every minute
    _timer = Timer.periodic(Duration(seconds: 60), (timer) {
      _updateTime();
    });
  }

  @override
  Future<void> _downloadNote(Note note) async {
    try {
      // First show download options dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Download Options',
              style: TextStyle(
                fontFamily: 'Oswald',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose download format:',
                  style: TextStyle(fontFamily: 'Oswald'),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // PDF Option
                    ElevatedButton.icon(
                      icon: Icon(Icons.picture_as_pdf),
                      label: Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context, 'pdf');
                      },
                    ),
                    // Word Option
                    ElevatedButton.icon(
                      icon: Icon(Icons.description),
                      label: Text('Word'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context, 'word');
                      },
                    ),
                  ],
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ).then((format) async {
        if (format != null) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return;

          // Get the file reference from Firebase Storage
          String fileUrl = note.fileUrl;
          String fileFormat = format; // 'pdf' or 'word'

          // If format conversion is needed (e.g., from PDF to Word or vice versa)
          // Here we would implement the conversion logic or API call
          // For now, we'll just handle the download tracking

          // Increment downloads counter in Firestore
          await FirebaseFirestore.instance
              .collection('notes')
              .doc(note.id)
              .update({'downloads': FieldValue.increment(1)});

          // Track download in a separate collection
          await FirebaseFirestore.instance.collection('downloads').add({
            'userEmail': currentUser.email,
            'noteId': note.id,
            'downloadedAt': FieldValue.serverTimestamp(),
            'format': fileFormat,
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Downloading ${note.title} as ${fileFormat.toUpperCase()}',
              ),
            ),
          );

          // Either open the file or download it
          // For mobile: Open in viewer
          // For web: Trigger download
          if (fileFormat == 'pdf') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        PDFViewerPage(pdfUrl: fileUrl, noteTitle: note.title),
              ),
            );
          } else {
            // Launch download for Word document or handle conversion
            // This would connect to a server-side function or API to convert and return the file
            // For now we'll just show a message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Word document download initiated')),
            );
          }
        }
      });
    } catch (error) {
      print('Error handling download: $error');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error downloading file: $error')));
    }
  }

  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('HH:mm').format(DateTime.now());
    });
  }

  Future<void> _loadUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        // Get the actual name from Google account
        _userName = currentUser.displayName ?? currentUser.email ?? "";
      });
    }
  }

  Future<void> _loadUserCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final enrollmentsQuery =
          await FirebaseFirestore.instance
              .collection('course_enrollments')
              .where('studentEmail', isEqualTo: currentUser.email)
              .get();

      final enrolledCourseIds =
          enrollmentsQuery.docs
              .map((doc) => doc.data()['courseId'] as String)
              .toList();

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

      final uploadsQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('ownerEmail', isEqualTo: currentUser.email)
              .get();

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

  void _toggleNotifications() {
    setState(() {
      _showNotification = !_showNotification;
    });
  }

  void _toggleRightDrawer() {
    setState(() {
      _showRightDrawer = !_showRightDrawer;
    });
  }

  void _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _navigateToCourses() {
    // Already on courses page
  }

  void _navigateToNotes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyNotesPage()),
    );
  }

  void _navigateToSharedNotes() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Shared Notes feature coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    // Check if animation is initialized
    if (_animation == null || _animationController == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _animation!.value) * -100),
          child: Opacity(
            opacity: _animation!.value,
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(80),
                child: Container(
                  padding: EdgeInsets.only(top: 30, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 100.0),
                      child: Row(
                        children: [
                          // Logo
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.menu_book,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 24),
                          // Courses button
                          TextButton(
                            onPressed: _navigateToCourses,
                            child: Text(
                              'Courses',
                              style: TextStyle(
                                fontFamily: 'Oswald',
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(width: 24),
                          // Notes button
                          TextButton(
                            onPressed: _navigateToNotes,
                            child: Text(
                              'Notes',
                              style: TextStyle(
                                fontFamily: 'Oswald',
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(width: 24),
                          // Shared with me button
                          TextButton(
                            onPressed: _navigateToSharedNotes,
                            child: Text(
                              'Shared with me',
                              style: TextStyle(
                                fontFamily: 'Oswald',
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Spacer(),

                          // Time display in rounded rectangle
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _currentTime,
                              style: TextStyle(
                                fontFamily: 'Oswald',
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          SizedBox(width: 16),

                          // Notification Bell in circular container
                          Stack(
                            children: [
                              Container(
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.notifications,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _toggleNotifications,
                                ),
                              ),
                              if (_notifications.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 14,
                                      minHeight: 14,
                                    ),
                                    child: Text(
                                      '${_notifications.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontFamily: 'Oswald',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          SizedBox(width: 16),

                          // User Account Button - square with rounded corners
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: _toggleRightDrawer,
                              child: Container(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              body: Stack(
                children: [
                  // Main Content Area - Left and Right sections
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 100.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 32),
                                // User greeting
                                Text(
                                  'Hello!',
                                  style: TextStyle(
                                    fontFamily: 'Oswald',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'I\'m $_userName',
                                  style: TextStyle(
                                    fontFamily: 'Oswald',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 32),

                                // My Courses Container
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.orange,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'My Courses',
                                        style: TextStyle(
                                          fontFamily: 'Oswald',
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 16),

                                      // Course List
                                      _isLoading
                                          ? Center(
                                            child: CircularProgressIndicator(),
                                          )
                                          : _userCourses.isEmpty
                                          ? Center(
                                            child: Text(
                                              'No courses yet',
                                              style: TextStyle(
                                                fontFamily: 'Oswald',
                                                fontSize: 16,
                                              ),
                                            ),
                                          )
                                          : ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            itemCount: _userCourses.length,
                                            itemBuilder: (context, index) {
                                              final course =
                                                  _userCourses[index];
                                              return Card(
                                                margin: EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                color: Colors.grey[100],
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: ListTile(
                                                  title: Text(
                                                    course.code,
                                                    style: TextStyle(
                                                      fontFamily: 'Oswald',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    course.name,
                                                    style: TextStyle(
                                                      fontFamily: 'Oswald',
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.note,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        '${course.noteCount} notes',
                                                        style: TextStyle(
                                                          fontFamily: 'Oswald',
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => CourseDetailScreen(
                                                              courseId:
                                                                  course.id,
                                                              courseCode:
                                                                  course.code,
                                                              courseName:
                                                                  course.name,
                                                              color:
                                                                  course.color,
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
                          SizedBox(width: 32),
                          // Right section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 32),
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.deepPurple,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.deepPurple.withOpacity(
                                          0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NoteX: Your platform',
                                        style: TextStyle(
                                          fontFamily: 'Oswald',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'for seamless note',
                                        style: TextStyle(
                                          fontFamily: 'Oswald',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'sharing and collaboration.',
                                        style: TextStyle(
                                          fontFamily: 'Oswald',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Making education easier through collaborative study resources',
                                  style: TextStyle(
                                    fontFamily: 'Oswald',
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Notifications Popup
                  if (_showNotification)
                    Positioned(
                      top: 80,
                      right: 100,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 300,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Notifications',
                                    style: TextStyle(
                                      fontFamily: 'Oswald',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 18),
                                    onPressed: _toggleNotifications,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                  ),
                                ],
                              ),
                              Divider(),
                              _notifications.isEmpty
                                  ? Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No new notifications',
                                      style: TextStyle(fontFamily: 'Oswald'),
                                    ),
                                  )
                                  : Container(
                                    constraints: BoxConstraints(maxHeight: 300),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _notifications.length,
                                      separatorBuilder:
                                          (context, index) => Divider(),
                                      itemBuilder: (context, index) {
                                        final notification =
                                            _notifications[index];
                                        return ListTile(
                                          title: Text(
                                            notification['title'] ??
                                                'New Notification',
                                            style: TextStyle(
                                              fontFamily: 'Oswald',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Text(
                                            notification['message'] ?? '',
                                            style: TextStyle(
                                              fontFamily: 'Oswald',
                                              fontSize: 12,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                        );
                                      },
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Right Navigation Drawer
                  if (_showRightDrawer)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 300,
                      child: Material(
                        elevation: 16,
                        child: SafeArea(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: Offset(-3, 0),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Account',
                                            style: TextStyle(
                                              fontFamily: 'Oswald',
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.close),
                                            onPressed: _toggleRightDrawer,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(),
                                    ListTile(
                                      leading: Icon(
                                        Icons.person,
                                        color: Colors.deepPurple,
                                      ),
                                      title: Text(
                                        'Profile',
                                        style: TextStyle(fontFamily: 'Oswald'),
                                      ),
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Profile page coming soon',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(
                                        Icons.settings,
                                        color: Colors.deepPurple,
                                      ),
                                      title: Text(
                                        'Settings',
                                        style: TextStyle(fontFamily: 'Oswald'),
                                      ),
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Settings page coming soon',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                // Sign Out at bottom
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 16,
                                  child: Column(
                                    children: [
                                      Divider(),
                                      ListTile(
                                        leading: Icon(
                                          Icons.logout,
                                          color: Colors.red,
                                        ),
                                        title: Text(
                                          'Sign Out',
                                          style: TextStyle(
                                            fontFamily: 'Oswald',
                                            color: Colors.red,
                                          ),
                                        ),
                                        onTap: _handleSignOut,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Overlay when drawer is open
                  if (_showRightDrawer || _showNotification)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          if (_showRightDrawer) _toggleRightDrawer();
                          if (_showNotification) _toggleNotifications();
                        },
                        child: Container(color: Colors.black.withOpacity(0.4)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
