import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoursesPage extends StatefulWidget {
  @override
  _CoursesPageState createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _userCourses = [];

  void _addNewCourse() {
    final titleController = TextEditingController();
    final codeController = TextEditingController();
    final professorController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Course Title'),
              ),
              TextField(
                controller: codeController,
                decoration: InputDecoration(labelText: 'Course Code'),
              ),
              TextField(
                controller: professorController,
                decoration: InputDecoration(labelText: 'Professor'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentUser = _auth.currentUser;

                await FirebaseFirestore.instance.collection('courses').add({
                  'title': titleController.text.trim(),
                  'code': codeController.text.trim(),
                  'professor': professorController.text.trim(),
                  'participants': 1,
                  'rating': 0.0,
                  'createdBy': currentUser?.email ?? 'unknown',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                setState(() {
                  _userCourses.add({
                    'title': titleController.text.trim(),
                    'code': codeController.text.trim(),
                    'professor': professorController.text.trim(),
                    'participants': 1,
                    'rating': 0.0,
                  });
                });
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No courses yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Add Course'),
              onPressed: _addNewCourse,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _userCourses.length,
      itemBuilder: (context, index) {
        final course = _userCourses[index];
        return Card(
          margin: EdgeInsets.all(12),
          child: ListTile(
            title: Text(course['title']),
            subtitle: Text('${course['code']} - ${course['professor']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, size: 16),
                SizedBox(width: 4),
                Text('${course['participants']}'),
              ],
            ),
          ),
        );
      },
    );
  }
}
