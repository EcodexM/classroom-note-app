import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddNotePage extends StatelessWidget {
  final _firestore = FirebaseFirestore.instance;
  String title = '';
  String content = '';

  AddNotePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Note')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                title = value;
              },
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              onChanged: (value) {
                content = value;
              },
              decoration: InputDecoration(labelText: 'Content'),
            ),
            ElevatedButton(
              onPressed: () {
                _firestore.collection('notes').add({
                  'title': title,
                  'content': content,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              },
              child: Text('Add Note'),
            ),
          ],
        ),
      ),
    );
  }
}
