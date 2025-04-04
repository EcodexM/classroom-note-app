import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

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
  int _hoveredIndex = -1;

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFC085),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    onPressed: () {},
                    constraints: const BoxConstraints(maxWidth: 40),
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
    final bool isHovered = _hoveredIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 550;

    final String displayText =
        title == "Shared With Me" && isSmallScreen ? "Shared" : title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit: (_) => setState(() => _hoveredIndex = -1),
        child: InkWell(
          onTap: () => widget.onTabSelected(index),
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color:
                  (!isSmallScreen && (isSelected || isHovered))
                      ? const Color(0xFFE97451)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              boxShadow:
                  (!isSmallScreen && (isSelected || isHovered))
                      ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                      : [],
            ),
            transform:
                (!isSmallScreen && (isSelected || isHovered))
                    ? (Matrix4.identity()..scale(1.05))
                    : Matrix4.identity(),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    (isSelected || isHovered)
                        ? FontWeight.bold
                        : FontWeight.w600,
                color:
                    (!isSmallScreen && (isSelected || isHovered))
                        ? Colors.white
                        : Colors.black87,
                fontFamily: 'KoPubBatang',
              ),
              child: Text(displayText),
            ),
          ),
        ),
      ),
    );
  }
}
