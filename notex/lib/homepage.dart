import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/auth.dart';
import 'package:notex/widgets/courses.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/widgets/header.dart';
import 'package:notex/services/keyboard_util.dart';
import 'package:notex/widgets/sharednote.dart';

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

  void _handleTabSelection(int index) {
    switch (index) {
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CoursesPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MyNotesPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SharedNotesScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenWidth < 600;

    final double margin = screenWidth * 0.025;

    return Scaffold(
      backgroundColor: Color(0xFF2E2E2E),
      body: Container(
        margin: EdgeInsets.all(margin), // Consistent margin
        decoration: BoxDecoration(
          color: Color(0xFFF2E9E2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                selectedIndex: 0,
                onTabSelected: _handleTabSelection,
                onSignOut: _handleSignOut,
                pageIndex: 0,
                showBackButton: false,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: margin * 2, // Consistent horizontal padding
                    vertical: margin, // Consistent vertical padding
                  ),
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
      ),
    );
  }
}
