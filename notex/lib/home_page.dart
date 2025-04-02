import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/auth.dart';
import 'package:notex/course_notes.dart';
import 'package:notex/MyNotes/mynote.dart';
// import 'package:notex/screens/shared_notes_screen.dart'; Assuming you have this screen
import 'package:notex/login.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State variables
  bool _showNotification = false;
  String _userName = "";
  String _currentTime = "";
  Timer? _timer;
  int _selectedTab = 0;

  // Constants for the safe margin area - this defines the content boundary
  final double horizontalMargin = 60.0;
  final double topMargin = 40.0;
  final double bottomMargin = 40.0;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _updateTime();

    // Update time every minute
    _timer = Timer.periodic(Duration(seconds: 60), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        _userName =
            currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            "USER";
      });
    }
  }

  void _toggleNotifications() {
    setState(() {
      _showNotification = !_showNotification;
    });
  }

  void _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => AuthPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _refreshPage() {
    // Implement your refresh logic here
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Refreshing...')));

    // Re-fetch user data or other necessary information
    _loadUserName();
    _updateTime();
  }

  void _navigateToPage(int index) {
    setState(() {
      _selectedTab = index;
    });

    switch (index) {
      case 1:
        // Navigate to Courses
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CoursesPage()),
        );
        break;
      case 2:
        // Navigate to Notes
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MyNotesPage()),
        );
        break;
      case 3:
        // Navigate to Shared with me
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SharedNotesScreen()),
        );
        break;
    }
  }

  // Helper method to determine screen size
  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 800;
  }

  bool _isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 800 &&
        MediaQuery.of(context).size.width < 1200;
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  // Helper method for responsive text sizes
  double _getResponsiveTextSize(BuildContext context, double baseSize) {
    if (_isLargeScreen(context)) {
      return baseSize;
    } else if (_isMediumScreen(context)) {
      return baseSize * 0.7;
    } else {
      return baseSize * 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = _isSmallScreen(context);
    final isMediumScreen = _isMediumScreen(context);

    // Define the content area (respecting margins)
    final contentWidth = screenWidth - (horizontalMargin * 2);
    final contentHeight = screenHeight - topMargin - bottomMargin;

    return Scaffold(
      backgroundColor: Color(0xFFF2E9E5), // Lavender background
      body: Stack(
        children: [
          // This container is for illustration purposes - it will be positioned outside the safe margins
          // Top-right illustration space
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              // You can add your illustrations here later
              // Example: child: Image.asset('assets/top_right_illustration.png'),
            ),
          ),

          // Bottom-left illustration space
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              width: 120,
              height: 120,
              // You can add your illustrations here later
              // Example: child: Image.asset('assets/bottom_left_illustration.png'),
            ),
          ),

          // The main content container - this is where all your main content should stay
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalMargin,
              topMargin,
              horizontalMargin,
              bottomMargin,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with navigation - always stays within margins
                Container(
                  height: isSmallScreen ? 60 : 80,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 24,
                    vertical: isSmallScreen ? 8 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        // App logo / refresh button
                        InkWell(
                          onTap: _refreshPage,
                          child: Container(
                            height: isSmallScreen ? 30 : 50,
                            width: isSmallScreen ? 30 : 50,
                            decoration: BoxDecoration(
                              color: Color(0xFFFFC085),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),

                        // App name - hide on small screens
                        if (screenWidth > 900)
                          Text(
                            ' NOTEX',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 18 : 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                              fontFamily: 'porterssans',
                            ),
                          ),

                        // Navigation Tabs - Scrollable on small screens or wrap
                        Expanded(
                          child:
                              isSmallScreen
                                  ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildNavButton("Courses", 1),
                                        SizedBox(width: 7),
                                        _buildNavButton("Notes", 2),
                                        SizedBox(width: 7),
                                        _buildNavButton("Shared With Me", 3),
                                      ],
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildNavButton("Courses", 1),
                                      SizedBox(width: 18),
                                      _buildNavButton("Notes", 2),
                                      SizedBox(width: 18),
                                      _buildNavButton("Shared With Me", 3),
                                    ],
                                  ),
                        ),

                        // Clock - hide on small screens
                        if (screenWidth > 750)
                          Text(
                            _currentTime,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 18,
                              color: Color(0xFF333333),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Oswald',
                            ),
                          ),

                        SizedBox(width: isSmallScreen ? 8 : 16),

                        // Profile Avatar - always visible but smaller on small screens
                        GestureDetector(
                          onTap: _handleSignOut,
                          child: Container(
                            width: isSmallScreen ? 24 : 30,
                            height: isSmallScreen ? 24 : 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child:
                                currentUser?.photoURL != null
                                    ? Image.network(
                                      currentUser!.photoURL!,
                                      fit: BoxFit.cover,
                                    )
                                    : Center(
                                      child: Text(
                                        _userName.isNotEmpty
                                            ? _userName[0].toUpperCase()
                                            : "U",
                                        style: TextStyle(
                                          color: Color(0xFF333333),
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Oswald',
                                          fontSize: isSmallScreen ? 10 : 12,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main greeting section
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 40),
                        // Profile image - responsive size
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

                        // Greeting text - responsive font sizes
                        Text(
                          'HELLO,',
                          style: TextStyle(
                            fontSize: _getResponsiveTextSize(context, 80),
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

                        ShaderMask(
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                              ).createShader(
                                Rect.fromLTWH(
                                  0,
                                  0,
                                  bounds.width,
                                  bounds.height,
                                ),
                              ),
                          child: Text(
                            'ARKA',
                            style: TextStyle(
                              fontSize: _getResponsiveTextSize(context, 120),
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0096C7),
                              fontFamily: 'KoPubBatang',
                            ),
                          ),
                        ),
                        Text(
                          'All your notes\nin one place.',
                          style: TextStyle(
                            fontSize: _getResponsiveTextSize(context, 75),
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
        ],
      ),
    );
  }

  // Helper method to build navigation buttons
  Widget _buildNavButton(String title, int index) {
    final isSelected = _selectedTab == index;
    final isSmallScreen = _isSmallScreen(context);

    return InkWell(
      onTap: () => _navigateToPage(index),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Color(0xFFFFC085).withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Color(0xFFFF8C42) : Colors.transparent,
            width: 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Color(0xFFFFC085).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: isSmallScreen ? 15 : 18,
            color:
                isSelected
                    ? Color.fromARGB(255, 46, 44, 56)
                    : Color(0xFF333333),
            fontFamily: 'KoPubBatang',
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// You will need to create these navigation target pages if they don't exist
class CoursesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Courses')),
      body: Center(child: Text('Courses page')),
    );
  }
}

class SharedNotesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shared With Me')),
      body: Center(child: Text('Shared notes page')),
    );
  }
}
