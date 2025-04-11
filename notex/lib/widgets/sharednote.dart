import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/widgets/header.dart';
import 'package:notex/widgets/courses.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/services/keyboard_util.dart';
import 'package:notex/homepage.dart';
import 'package:notex/widgets/profile.dart';

class SharedNotesScreen extends StatefulWidget {
  @override
  _SharedNotesScreenState createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> {
  List<dynamic> _sharedNotes = []; // Will store shared notes later
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSharedNotes();
  }

  Future<void> _fetchSharedNotes() async {
    // TODO: Implement fetching shared notes from Firestore
    setState(() {
      _isLoading = false;
    });
  }

  // Add the missing _showProfileDrawer method
  void _showProfileDrawer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ProfileDrawer",
      pageBuilder: (context, animation1, animation2) {
        return ProfileDrawer(
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
      transitionDuration: Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  // This method was incomplete/misplaced - removing the existing partial definition
  void _handleProfileAction(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Profile Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text('View Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile screen
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Add this method to handle tab selection
  void _handleTabSelection(int index) {
    if (index != 3) {
      // Not the current Shared With Me tab
      switch (index) {
        case 0: // Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage()),
          );
          break;
        case 1: // Courses
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => CoursesPage()),
          );
          break;
        case 2: // Notes
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MyNotesPage()),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double margin = screenWidth * 0.018;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFF2E2E2E),
        body: Container(
          margin: EdgeInsets.all(margin),
          decoration: BoxDecoration(
            color: Color(0xFFF2E9E5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            child: Column(
              children: [
                AppHeader(
                  selectedIndex: 3,
                  onTabSelected: _handleTabSelection,
                  onProfileMenuTap: () => _showProfileDrawer(context),
                  pageIndex: 3,
                  showBackButton: true,
                ),
                Expanded(child: _buildSharedNotesContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedNotesContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFFF8C42)));
    }

    if (_sharedNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_shared, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No shared notes yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Notes shared with you will appear here',
              style: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
            ),
          ],
        ),
      );
    }

    // TODO: Implement shared notes list view
    return ListView.builder(
      itemCount: _sharedNotes.length,
      itemBuilder: (context, index) {
        // Placeholder for shared notes list item
        return ListTile(title: Text('Shared Note ${index + 1}'));
      },
    );
  }
}
