import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class MyNotesPage extends StatelessWidget {
  const MyNotesPage({super.key});

  Future<List<Map<String, dynamic>>> fetchMyNotes() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final querySnapshot =
        await FirebaseFirestore.instance
            .collection('notes')
            .where('ownerEmail', isEqualTo: currentUser.email)
            .orderBy('uploadDate', descending: true)
            .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  void _openNote(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Notes", style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchMyNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data ?? [];

          if (notes.isEmpty) {
            return Center(
              child: Text(
                'No notes uploaded yet.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                elevation: 3,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Icon(Icons.picture_as_pdf, color: Colors.deepPurple),
                  title: Text(note['title'] ?? 'Untitled'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note['fileName'] != null)
                        Text(
                          "File: ${note['fileName']}",
                          style: TextStyle(fontSize: 12),
                        ),
                      Text("Course ID: ${note['courseId']}"),
                      Text("Public: ${note['isPublic'] ? 'Yes' : 'No'}"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.download, color: Colors.deepPurple),
                    onPressed: () => _openNote(note['fileUrl']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
