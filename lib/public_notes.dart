import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Displays a list of all public notes.
/// Each item shows the note fileName and owner. Tapping it opens the PDF viewer.
class PublicNotesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Public Notes'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('public_notes')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No public notes available",
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          var publicNotes = snapshot.data!.docs;
          return ListView.builder(
            itemCount: publicNotes.length,
            itemBuilder: (context, index) {
              var note = publicNotes[index];
              return ListTile(
                title: Text(note['fileName']),
                subtitle: Text('Owner: ${note['owner']}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PublicPDFViewerPage(note: note),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Displays a selected public note with its PDF, like/dislike buttons, and a comment section.
class PublicPDFViewerPage extends StatefulWidget {
  final QueryDocumentSnapshot note;

  PublicPDFViewerPage({required this.note});

  @override
  _PublicPDFViewerPageState createState() => _PublicPDFViewerPageState();
}

class _PublicPDFViewerPageState extends State<PublicPDFViewerPage> {
  late int likes;
  late int dislikes;
  late String comment;

  @override
  void initState() {
    super.initState();
    likes = widget.note['likes'] ?? 0;
    dislikes = widget.note['dislikes'] ?? 0;
    final noteData = widget.note.data() as Map<String, dynamic>?;
    comment =
        noteData != null && noteData.containsKey('comment')
            ? noteData['comment']
            : '';
  }

  /// Update likes/dislikes count in Firestore.
  void updateReaction(bool isLike) async {
    final noteRef = FirebaseFirestore.instance
        .collection('public_notes')
        .doc(widget.note.id);
    if (isLike) {
      setState(() {
        likes += 1;
      });
      await noteRef.update({'likes': likes});
    } else {
      setState(() {
        dislikes += 1;
      });
      await noteRef.update({'dislikes': dislikes});
    }
  }

  /// Update comment in Firestore.
  void updateComment(String newComment) async {
    final noteRef = FirebaseFirestore.instance
        .collection('public_notes')
        .doc(widget.note.id);
    await noteRef.update({'comment': newComment});
    setState(() {
      comment = newComment;
    });
  }

  /// Opens a dialog for the user to add or edit a comment.
  void showCommentDialog() {
    final TextEditingController commentController = TextEditingController(
      text: comment,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add/Edit Comment"),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(hintText: "Enter your comment"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String newComment = commentController.text.trim();
                updateComment(newComment);
                Navigator.pop(context);
              },
              child: Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfUrl = widget.note['fileUrl'];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note['fileName']),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(child: SfPdfViewer.network(pdfUrl)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.thumb_up, color: Colors.green),
                  onPressed: () => updateReaction(true),
                ),
                Text("$likes"),
                SizedBox(width: 20),
                IconButton(
                  icon: Icon(Icons.thumb_down, color: Colors.red),
                  onPressed: () => updateReaction(false),
                ),
                Text("$dislikes"),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    comment.isNotEmpty
                        ? "Comment: $comment"
                        : "No comment yet.",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: showCommentDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
