import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/login.dart';

class AppDrawer extends StatefulWidget {
  final Function(int) onTabSwitch;

  AppDrawer({required this.onTabSwitch});

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  int _totalUploads = 0;
  int _totalDownloads = 0;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Count uploads
      final uploadsQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('ownerEmail', isEqualTo: currentUser.email)
              .get();

      // Count downloads
      final downloadsQuery =
          await FirebaseFirestore.instance
              .collection('downloads')
              .where('userEmail', isEqualTo: currentUser.email)
              .get();

      setState(() {
        _totalUploads = uploadsQuery.docs.length;
        _totalDownloads = downloadsQuery.docs.length;
      });
    } catch (error) {
      print('Error loading user stats: $error');
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                AuthManager.handleLogout(context);
              },
              child: Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: Colors.deepPurple),
                ),
                SizedBox(height: 8),
                Text(
                  currentUser?.email ?? 'User',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.note, color: Colors.deepPurple),
            title: Text('My Notes'),
            onTap: () {
              Navigator.pop(context);
              widget.onTabSwitch(0);
            },
          ),
          ListTile(
            leading: Icon(Icons.school, color: Colors.deepPurple),
            title: Text('Courses'),
            onTap: () {
              Navigator.pop(context);
              widget.onTabSwitch(1);
            },
          ),
          ListTile(
            leading: Icon(Icons.public, color: Colors.deepPurple),
            title: Text('Public Notes'),
            onTap: () {
              Navigator.pop(context);
              widget.onTabSwitch(2);
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.upload, color: Colors.grey),
            title: Text('Total Uploads: $_totalUploads'),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.download, color: Colors.grey),
            title: Text('Total Downloads: $_totalDownloads'),
            onTap: () {},
          ),
          Spacer(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }
}
