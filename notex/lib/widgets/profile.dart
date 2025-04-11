import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/auth.dart';

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
      duration: Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
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
    await _animationController.reverse();
    widget.onClose();
  }

  void _signOut() async {
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
        return Stack(
          children: [
            // Backdrop
            GestureDetector(
              onTap: _closeDrawer,
              child: Container(
                width: screenSize.width,
                height: screenSize.height,
                color: Colors.black.withOpacity(0.5 * _opacityAnimation.value),
              ),
            ),

            // Profile drawer
            Positioned(
              bottom: -screenSize.height * 0.1 * _slideAnimation.value,
              right: -screenSize.width * 0.1 * _slideAnimation.value,
              child: Transform(
                alignment: Alignment.bottomRight,
                transform:
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..rotateZ(-35 * 3.14159 / 180 * _slideAnimation.value),
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: screenSize.width * 0.9,
                    height: screenSize.height * 0.6,
                    decoration: BoxDecoration(
                      color: Color(0xFF2E2E2E),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Close button
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: GestureDetector(
                              onTap: _closeDrawer,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'close',
                                    style: TextStyle(
                                      color: Colors.white,
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
                              SizedBox(height: 20),
                              Text(
                                'Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(height: 24),

                              // Profile picture
                              Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  child:
                                      FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.photoURL !=
                                              null
                                          ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              40,
                                            ),
                                            child: Image.network(
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .photoURL!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                          : Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                ),
                              ),
                              SizedBox(height: 24),

                              // User info
                              _buildInfoRow('Name', _userName),
                              SizedBox(height: 16),
                              _buildInfoRow('Email', _userEmail),
                              SizedBox(height: 16),
                              _buildPhoneRow(),

                              Spacer(),

                              // Sign out button
                              Align(
                                alignment: Alignment.bottomRight,
                                child: GestureDetector(
                                  onTap: _signOut,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.logout,
                                          color: Colors.red[300],
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sign out?',
                                          style: TextStyle(
                                            color: Colors.red[300],
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
            color: Colors.grey[400],
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
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
            color: Colors.grey[400],
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Text(
              _phoneNumber ?? 'Not added',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(width: 8),
            if (_phoneNumber == null)
              GestureDetector(
                onTap: () {
                  // Implement add phone functionality
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.deepPurple, width: 1),
                  ),
                  child: Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.deepPurple[300],
                      fontSize: 12,
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
}
