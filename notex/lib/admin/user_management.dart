import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserManagementPage extends StatefulWidget {
  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usersQuery =
          await FirebaseFirestore.instance.collection('users').get();

      List<Map<String, dynamic>> users = [];
      for (var doc in usersQuery.docs) {
        users.add({
          'id': doc.id,
          'email': doc.data()['email'] ?? 'Unknown',
          'displayName': doc.data()['displayName'],
          'role': doc.data()['role'] ?? 'student',
          'enrollmentDate': doc.data()['enrollmentDate']?.toDate(),
          'profileImage': doc.data()['profileImage'],
        });
      }

      // Sort by role (admin first, then teachers, then students)
      users.sort((a, b) {
        final roleOrder = {'admin': 0, 'teacher': 1, 'student': 2};
        return (roleOrder[a['role']] ?? 2).compareTo(roleOrder[b['role']] ?? 2);
      });

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _searchUsers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;

    return _users.where((user) {
      return user['email'].toLowerCase().contains(_searchQuery) ||
          (user['displayName']?.toLowerCase() ?? '').contains(_searchQuery);
    }).toList();
  }

  Future<void> _updateUserRole(String userId, String role) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': role,
      });

      setState(() {
        final userIndex = _users.indexWhere((user) => user['id'] == userId);
        if (userIndex != -1) {
          _users[userIndex]['role'] = role;
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User role updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating user role: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search users by email or name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                    ? Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(fontSize: 18, fontFamily: 'Poppins'),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredUsers.length,
                      padding: EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _buildUserCard(user);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    Color roleColor;
    IconData roleIcon;

    switch (user['role']) {
      case 'admin':
        roleColor = Colors.red;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'teacher':
        roleColor = Colors.orange;
        roleIcon = Icons.school;
        break;
      default:
        roleColor = Colors.blue;
        roleIcon = Icons.person;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      user['profileImage'] != null
                          ? NetworkImage(user['profileImage'])
                          : null,
                  child:
                      user['profileImage'] == null ? Icon(Icons.person) : null,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['displayName'] ?? user['email'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        user['email'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 14, color: roleColor),
                      SizedBox(width: 4),
                      Text(
                        user['role'].toString().toUpperCase(),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Joined: ${user['enrollmentDate'] != null ? DateFormat('MMM dd, yyyy').format(user['enrollmentDate']) : 'Unknown'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _updateUserRole(user['id'], value),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'student',
                          child: Text('Set as Student'),
                        ),
                        PopupMenuItem(
                          value: 'teacher',
                          child: Text('Set as Teacher'),
                        ),
                        PopupMenuItem(
                          value: 'admin',
                          child: Text('Set as Admin'),
                        ),
                      ],
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Change Role'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
