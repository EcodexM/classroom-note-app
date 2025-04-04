import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AppHeader extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;
  final VoidCallback? onSignOut;
  final VoidCallback? onProfileMenuTap;
  final bool showBackButton;
  final int pageIndex;

  const AppHeader({
    Key? key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onSignOut,
    this.onProfileMenuTap,
    this.showBackButton = false,
    required this.pageIndex,
  }) : super(key: key);

  @override
  _AppHeaderState createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String _currentTime = "";
  Timer? _timer;
  bool _hasNotifications = true;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 550;
    final bool isLargeScreen = screenWidth >= 900;
    final bool isHomePage = widget.pageIndex == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // App icon and name in a row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFC085),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),

              // App name - Hide on smaller screens
              if (!isSmallScreen)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    ' NOTEX',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'porterssans',
                      color: Colors.black87,
                    ),
                  ),
                ),
            ],
          ),

          // Expanded container for centered navigation tabs
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTabItem("Courses", 1),
                    _buildTabItem("Notes", 2),
                    _buildTabItem("Shared With Me", 3),
                  ],
                ),
              ),
            ),
          ),

          // Right-side elements in a row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification bell icon
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    onPressed: () {
                      // Show notifications panel
                    },
                    constraints: BoxConstraints(maxWidth: 40),
                    padding: EdgeInsets.zero,
                  ),
                  if (_hasNotifications)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),

              if (isLargeScreen)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _currentTime,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'KoPubBatang',
                    ),
                  ),
                ),

              GestureDetector(
                onTap: widget.onProfileMenuTap ?? widget.onSignOut,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                  ),
                  child: Center(
                    child:
                        FirebaseAuth.instance.currentUser?.photoURL != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                FirebaseAuth.instance.currentUser!.photoURL!,
                                fit: BoxFit.cover,
                              ),
                            )
                            : const Icon(
                              Icons.person,
                              size: 18,
                              color: Colors.black54,
                            ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final bool isSelected = widget.selectedIndex == index;

    final String displayText =
        title == "Shared With Me" && MediaQuery.of(context).size.width < 550
            ? "Shared"
            : title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => widget.onTabSelected(index),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration:
              isSelected
                  ? BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(24),
                  )
                  : null,
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFFFF8C42) : Colors.black87,
              fontFamily: 'KoPubBatang',
            ),
          ),
        ),
      ),
    );
  }
}
