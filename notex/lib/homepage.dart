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
    final currentUser = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenWidth < 600;

    // Define consistent padding values based on header
    final double horizontalPadding = 50.0; // Same as header horizontal margin
    final double topPadding = 40.0; // Same as header vertical margin
    final double bottomPadding = topPadding * 2; // Twice the top padding

    return WillPopScope(
      onWillPop: () async {
        // Handle escape key or back button press
        return false; // Return false to prevent default back behavior
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          // Check for Escape key press
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            // Handle escape key press
            print('Escape key pressed');
            // Go back to the previous page
            Navigator.of(context).maybePop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: Color(
            0xFFF2E9E5,
          ), // Maintain consistent background color
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding, // Left padding
                0, // No top padding since the header has its own margin
                horizontalPadding, // Right padding
                bottomPadding, // Bottom padding
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Left-align all content
                children: [
                  // Use the updated header with consistent positioning
                  AppHeader(
                    selectedIndex: 0,
                    onTabSelected: _navigateToPage,
                    onSignOut: _handleSignOut,
                    pageIndex: 0, // This is the home page
                    showBackButton: false, // No back button on home page
                  ),

                  // Main content container
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: topPadding),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // Left-align all content
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center, // Vertically center in available space
                        children: [
                          // Profile image
                          Container(
                            margin: EdgeInsets.only(
                              bottom: isSmallScreen ? 20 : 40,
                            ),
                            width: isSmallScreen ? 120 : 180,
                            height: isSmallScreen ? 120 : 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(),
                              image: DecorationImage(
                                image: AssetImage('images/arka.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // Greeting text
                          Text(
                            'HELLO,',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 40 : 80,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E2E2E),
                              fontFamily: 'KoPubBatang',
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFC085).withOpacity(0.1),
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),

                          // Username with gradient
                          ShaderMask(
                            shaderCallback:
                                (bounds) => LinearGradient(
                                  colors: [
                                    Color(0xFF00C6FF),
                                    Color(0xFF0072FF),
                                  ],
                                ).createShader(
                                  Rect.fromLTWH(
                                    0,
                                    0,
                                    bounds.width,
                                    bounds.height,
                                  ),
                                ),
                            child: Text(
                              _userName.toUpperCase(),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 60 : 120,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0096C7),
                                fontFamily: 'KoPubBatang',
                              ),
                              // Handle overflow for long usernames
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Tagline with responsive font size
                          Text(
                            'All your notes\nin one place.',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 38 : 75,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6D6D6D),
                              fontFamily: 'KoPubBatang',
                              fontStyle: FontStyle.italic,
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
        ),
      ),
    );
  }
}

// Shared Notes Screen placeholder implementation
class SharedNotesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2E9E5),
      body: SafeArea(
        child: Column(
          children: [
            // Use the consistent header
            AppHeader(
              selectedIndex: 3, // Shared With Me tab
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

            // Content for Shared Notes
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
  }
}
