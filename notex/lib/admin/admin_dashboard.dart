import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/admin/admin_dashboard_home.dart';
import 'package:notex/admin/course_management.dart';
import 'package:notex/admin/user_management.dart';
import 'package:notex/admin/content_moderation.dart';
import 'package:notex/admin/institution_management.dart';
import 'package:notex/auth.dart';
import 'package:notex/services/auth_service.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _totalUsers = 0;
  int _totalCourses = 0;
  int _totalNotes = 0;
  int _totalInstitutions = 0;
  bool _isLoading = true;
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();

  final List<Widget> _pages = [
    AdminDashboardHome(),
    UserManagementPage(),
    CourseManagementPage(),
    ContentModerationPage(),
    InstitutionManagementPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isCurrentUserAdmin();
    if (!isAdmin) {
      // Redirect to login if not admin
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unauthorized access. Please login as admin.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthPage()),
      );
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user count
      final usersCount =
          await FirebaseFirestore.instance.collection('users').count().get();

      // Get course count
      final coursesCount =
          await FirebaseFirestore.instance.collection('courses').count().get();

      // Get notes count
      final notesCount =
          await FirebaseFirestore.instance.collection('notes').count().get();

      // Get institutions count (create this collection if implementing institution-specific structure)
      final institutionsCount =
          await FirebaseFirestore.instance
              .collection('institutions')
              .count()
              .get();

      setState(() {
        _totalUsers = usersCount.count ?? 0;
        _totalCourses = coursesCount.count ?? 0;
        _totalNotes = notesCount.count ?? 0;
        _totalInstitutions = institutionsCount.count ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admin stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: Colors.red[800],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AuthPage()),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: Colors.red[800],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Courses'),
          BottomNavigationBarItem(
            icon: Icon(Icons.content_paste),
            label: 'Content',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Institutions',
          ),
        ],
      ),
    );
  }
}
