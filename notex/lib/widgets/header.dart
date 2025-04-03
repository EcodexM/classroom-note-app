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
    final bool isSmallScreen = screenWidth < 600;
    final bool isHomePage = widget.pageIndex == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // Custom back button: Display only on Notes, Shared With Me, and Courses screens
          if (widget.showBackButton && !isHomePage)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 30, minHeight: 30),
            ),

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

          // App name
          if (!isSmallScreen && !isHomePage)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'NOTEX',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'porterssans',
                  color: Colors.black87,
                ),
              ),
            ),

          const Spacer(),

          // Navigation Tabs - use a Row with SingleChildScrollView for smaller screens
          if (!isSmallScreen && !isHomePage)
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabItem("Courses", 1),
                  _buildTabItem("Notes", 2),
                  _buildTabItem("Shared With Me", 3),
                ],
              ),
            )
          else if (isSmallScreen && !isHomePage)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTabItem("Courses", 1),
                    _buildTabItem("Notes", 2),
                    _buildTabItem("Shared With Me", 3),
                  ],
                ),
              ),
            ),

          const Spacer(),

          // Time (hide if overflow risk)
          if (!isSmallScreen && !isHomePage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _currentTime,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'KoPubBatang',
                ),
              ),
            ),

          // Profile Icon
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
    );
  }

  Widget _buildTabItem(String title, int index) {
    final bool isSelected = widget.selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        onTap: () => widget.onTabSelected(index),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration:
              isSelected
                  ? BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(24),
                  )
                  : null,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
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
