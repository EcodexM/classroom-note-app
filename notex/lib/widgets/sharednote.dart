import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/widgets/header.dart';
import 'package:notex/widgets/courses.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/services/keyboard_util.dart';
import 'package:notex/widgets/sharednote.dart';
import 'package:notex/homepage.dart';

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
        backgroundColor: Color(0xFFF2E9E5),
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                selectedIndex: 3,
                onTabSelected: _handleTabSelection,
                onSignOut: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/');
                },
                pageIndex: 3,
                showBackButton: true,
              ),
              Expanded(child: _buildSharedNotesContent()),
            ],
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
