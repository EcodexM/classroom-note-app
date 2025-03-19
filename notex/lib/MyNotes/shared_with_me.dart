import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharedWithMePage extends StatelessWidget {
  void acceptSharedNote(BuildContext context, String noteId) async {
    await FirebaseFirestore.instance
        .collection('shared_notes')
        .doc(noteId)
        .update({'accepted': true});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Note accepted successfully!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Shared With Me",
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('shared_notes')
                .where(
                  'account',
                  isEqualTo: FirebaseAuth.instance.currentUser?.email,
                )
                .where('accepted', isEqualTo: false)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No shared notes available",
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          var sharedNotes = snapshot.data!.docs;
          return ListView.builder(
            itemCount: sharedNotes.length,
            itemBuilder: (context, index) {
              var note = sharedNotes[index];
              return ListTile(
                title: Text(note['fileName']),
                subtitle: Text('Shared by: ${note['owner']}'),
                trailing: ElevatedButton(
                  onPressed: () => acceptSharedNote(context, note.id),
                  child: Text('Accept'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BlankPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Note Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Text('Note Details Page', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
