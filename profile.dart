import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/auth.dart';
import 'dart:math' as math;

class ProfileDrawer extends StatefulWidget {
  final Function onClose;

  const ProfileDrawer({Key? key, required this.onClose}) : super(key: key);

  @override
  _ProfileDrawerState createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;
  bool _isClosing = false;

  // User details
  String _userEmail = 'Loading...';
  String _userName = 'Loading...';
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();

    // Load user data
    _loadUserData();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: math.pi / 10, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    // Start the animation
    _animationController.forward();
  }

  void _loadUserData() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _userEmail = currentUser.email ?? 'No email provided';
        _userName =
            currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            'User';
        _phoneNumber = currentUser.phoneNumber;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeDrawer() async {
    setState(() {
      _isClosing = true;
    });

    await _animationController.reverse();
    widget.onClose();
  }

  void _signOut() async {
    setState(() {
      _isClosing = true;
    });

    await _animationController.reverse();
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => AuthPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective effect
                    ..translate(
                      0.0,
                      screenSize.height * _slideAnimation.value,
                    ) // Slide up
                    ..rotateX(
                      _rotationAnimation.value,
                    ), // Rotate for angle effect
              child: Container(
                width: screenSize.width,
                height: screenSize.height,
                color: Color(0xFF1C1C1C), // Matte black
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Close button - made to look like the one in the reference image
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: GestureDetector(
                            onTap: _closeDrawer,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'close',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Profile content
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 60,
                            ), // Extra space for the close button
                            // Profile header with gold underline
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFBDB76B),
                                    width: 2.0,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 40),

                            // Profile picture with X
                            Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[800],
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    CustomPaint(
                                      size: Size(100, 100),
                                      painter: CrossPainter(),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 40),

                            // User info section - centered with angle effect green lines
                            Stack(
                              children: [
                                // Green diagonal lines for the angle effect
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: DiagonalLinesPainter(),
                                  ),
                                ),

                                // User info container
                                Container(
                                  width: screenSize.width * 0.9,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: screenSize.width * 0.05,
                                  ),
                                  padding: EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRow('Name', _userName),
                                      SizedBox(height: 24),
                                      _buildInfoRow('Email', _userEmail),
                                      SizedBox(height: 24),
                                      _buildPhoneRow(),

                                      SizedBox(height: 24),

                                      // Divider
                                      Divider(
                                        color: Colors.white.withOpacity(0.1),
                                        thickness: 1,
                                      ),
                                      SizedBox(height: 16),

                                      // Settings options
                                      _buildSettingsButton(
                                        'Account Settings',
                                        Icons.settings,
                                        () {
                                          // Implement account settings functionality
                                        },
                                      ),

                                      SizedBox(height: 16),

                                      _buildSettingsButton(
                                        'Notification Preferences',
                                        Icons.notifications_outlined,
                                        () {
                                          // Implement notification settings
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            Spacer(),

                            // Sign out button
                            Stack(
                              children: [
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: GestureDetector(
                                    onTap: _signOut,
                                    child: Container(
                                      width: screenSize.width * 0.9,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: screenSize.width * 0.05,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF331111),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.logout_rounded,
                                              color: Color(0xFFBDB76B),
                                              size: 20,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Sign out',
                                              style: TextStyle(
                                                color: Color(
                                                  0xFFBDB76B,
                                                ), // Gold color
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFFBDB76B), // Gold color for labels
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone',
          style: TextStyle(
            color: Color(0xFFBDB76B), // Gold color for labels
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Text(
              _phoneNumber ?? 'Not added',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(width: 12),
            if (_phoneNumber == null)
              GestureDetector(
                onTap: () {
                  // Implement add phone functionality
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple, width: 1),
                  ),
                  child: Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.deepPurple[300],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: Color(0xFFBDB76B), // Gold color
            size: 22,
          ),
          SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
          Spacer(),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.5),
            size: 22,
          ),
        ],
      ),
    );
  }
}

// Custom painter for the X in the profile picture
class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    // Draw X
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.3),
      Offset(size.width * 0.7, size.height * 0.7),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.3),
      Offset(size.width * 0.3, size.height * 0.7),
      paint,
    );

    // Draw circle
    final circlePaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.4,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for diagonal lines
class DiagonalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    // Draw diagonal lines at an angle similar to reference
    final spacing = size.width / 5;

    for (int i = -2; i < 7; i++) {
      final startX = spacing * i;
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(startX + size.width * 0.7, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
