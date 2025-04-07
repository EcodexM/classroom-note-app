import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/auth.dart';
import 'package:notex/widgets/courses.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/widgets/header.dart';
import 'package:notex/services/keyboard_util.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showNotification = false;
  String _userName = "";
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _userName =
            currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            "USER";
      });
    }
  }

  void _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => AuthPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _navigateToPage(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CoursesPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MyNotesPage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SharedNotesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Color(0xFF2E2E2E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Container(
              width: constraints.maxWidth * 0.95,
              height: constraints.maxHeight * 0.95,
              decoration: BoxDecoration(
                color: Color(0xFFF2E9E2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  AppHeader(
                    selectedIndex: 0,
                    onTabSelected: _navigateToPage,
                    onSignOut: _handleSignOut,
                    pageIndex: 0,
                    showBackButton: false,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'CREATE.\nORGANISE.\nEDUCATE.',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 40 : 80,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2E2E2E),
                                    fontFamily: 'Boldonse',
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'All your notes in one place.',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E2E2E),
                                  fontFamily: 'Boldonse',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class SharedNotesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2E2E2E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Container(
              width: constraints.maxWidth * 0.95,
              height: constraints.maxHeight * 0.95,
              decoration: BoxDecoration(
                color: Color(0xFFF2E9E5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  AppHeader(
                    selectedIndex: 3,
                    pageIndex: 3,
                    onTabSelected: (index) {
                      if (index != 3) {
                        Navigator.pop(context);
                        switch (index) {
                          case 0:
                            Navigator.pushReplacementNamed(context, '/');
                            break;
                          case 1:
                            Navigator.pushReplacementNamed(context, '/courses');
                            break;
                          case 2:
                            Navigator.pushReplacementNamed(context, '/notes');
                            break;
                        }
                      }
                    },
                    onSignOut: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    showBackButton: true,
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_shared,
                            size: 80,
                            color: Colors.grey[400],
                          ),
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
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
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
}
