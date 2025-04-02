import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/screens/peer_review_screen.dart';
import 'package:notex/widgets/rating_summary_widget.dart';
import 'dart:io';

class PDFViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String noteTitle;
  final bool isPublic;
  final bool isOfflineFile;
  final String courseId;
  final String courseCode;
  final String noteId;

  PDFViewerPage({
    required this.pdfUrl,
    required this.noteTitle,
    this.isPublic = true,
    this.isOfflineFile = false,
    this.courseId = '',
    this.courseCode = '',
    this.noteId = '',
  });

  @override
  _PDFViewerPageState createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  late bool isPublic;
  double _userRating = .0;
  bool _hasRated = false;
  List<Comment> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    isPublic = widget.isPublic;
    _loadRatingAndComments();
    if (!widget.isOfflineFile) {
      _incrementDownloadCount();
    }
  }

  Future<void> _loadRatingAndComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isOfflineFile && widget.noteId.isEmpty) {
        // For offline files without noteId, we don't load ratings/comments
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get the note document
      DocumentSnapshot? noteDoc;

      if (widget.noteId.isNotEmpty) {
        noteDoc =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(widget.noteId)
                .get();
      } else {
        // If noteId is not provided, query by URL
        final noteQuery =
            await FirebaseFirestore.instance
                .collection('notes')
                .where('fileUrl', isEqualTo: widget.pdfUrl)
                .limit(1)
                .get();

        if (noteQuery.docs.isNotEmpty) {
          noteDoc = noteQuery.docs.first;
        }
      }

      if (noteDoc != null && noteDoc.exists) {
        final currentUser = FirebaseAuth.instance.currentUser;

        // Check if user has already rated
        if (currentUser != null) {
          final ratingDoc =
              await FirebaseFirestore.instance
                  .collection('notes')
                  .doc(noteDoc.id)
                  .collection('ratings')
                  .doc(currentUser.uid)
                  .get();

          if (ratingDoc.exists) {
            setState(() {
              _userRating =
                  (ratingDoc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
              _hasRated = true;
            });
          }
        }

        // Get comments
        final commentsQuery =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(noteDoc.id)
                .collection('comments')
                .orderBy('timestamp', descending: true)
                .get();

        setState(() {
          _comments =
              commentsQuery.docs
                  .map(
                    (doc) => Comment(
                      id: doc.id,
                      authorEmail: doc.data()['authorEmail'] ?? '',
                      text: doc.data()['text'] ?? '',
                      timestamp:
                          doc.data()['timestamp']?.toDate() ?? DateTime.now(),
                    ),
                  )
                  .toList();
        });
      }
    } catch (error) {
      print('Error loading ratings and comments: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _incrementDownloadCount() async {
    if (widget.isOfflineFile) return; // Don't increment for offline files

    try {
      DocumentSnapshot? noteDoc;

      if (widget.noteId.isNotEmpty) {
        noteDoc =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(widget.noteId)
                .get();
      } else {
        // Query by URL if noteId is not provided
        final noteQuery =
            await FirebaseFirestore.instance
                .collection('notes')
                .where('fileUrl', isEqualTo: widget.pdfUrl)
                .limit(1)
                .get();

        if (noteQuery.docs.isNotEmpty) {
          noteDoc = noteQuery.docs.first;
        }
      }

      if (noteDoc != null && noteDoc.exists) {
        // Increment the downloads counter
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(noteDoc.id)
            .update({'downloads': FieldValue.increment(1)});
      }
    } catch (error) {
      print('Error incrementing download count: $error');
    }
  }

  Future<void> _submitRating(double rating) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      DocumentSnapshot? noteDoc;

      if (widget.noteId.isNotEmpty) {
        noteDoc =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(widget.noteId)
                .get();
      } else {
        final noteQuery =
            await FirebaseFirestore.instance
                .collection('notes')
                .where('fileUrl', isEqualTo: widget.pdfUrl)
                .limit(1)
                .get();

        if (noteQuery.docs.isNotEmpty) {
          noteDoc = noteQuery.docs.first;
        }
      }

      if (noteDoc != null && noteDoc.exists) {
        // Add or update user rating
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(noteDoc.id)
            .collection('ratings')
            .doc(currentUser.uid)
            .set({
              'rating': rating,
              'userEmail': currentUser.email,
              'timestamp': FieldValue.serverTimestamp(),
            });

        // Calculate new average rating
        final ratingsQuery =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(noteDoc.id)
                .collection('ratings')
                .get();

        double sum = 0;
        int count = ratingsQuery.docs.length;

        for (var doc in ratingsQuery.docs) {
          sum += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
        }

        double newAverage = count > 0 ? sum / count : 0;

        // Update average rating in note document
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(noteDoc.id)
            .update({'averageRating': newAverage});

        setState(() {
          _userRating = rating;
          _hasRated = true;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Thank you for your rating!')));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $error')),
      );
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      DocumentSnapshot? noteDoc;

      if (widget.noteId.isNotEmpty) {
        noteDoc =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(widget.noteId)
                .get();
      } else {
        final noteQuery =
            await FirebaseFirestore.instance
                .collection('notes')
                .where('fileUrl', isEqualTo: widget.pdfUrl)
                .limit(1)
                .get();

        if (noteQuery.docs.isNotEmpty) {
          noteDoc = noteQuery.docs.first;
        }
      }

      if (noteDoc != null && noteDoc.exists) {
        // Add comment
        final commentRef = await FirebaseFirestore.instance
            .collection('notes')
            .doc(noteDoc.id)
            .collection('comments')
            .add({
              'authorEmail': currentUser.email,
              'text': _commentController.text.trim(),
              'timestamp': FieldValue.serverTimestamp(),
            });

        setState(() {
          _comments.insert(
            0,
            Comment(
              id: commentRef.id,
              authorEmail: currentUser.email ?? '',
              text: _commentController.text.trim(),
              timestamp: DateTime.now(),
            ),
          );
          _commentController.clear();
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Comment added!')));
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding comment: $error')));
    }
  }

  void togglePrivacy() async {
    if (widget.isOfflineFile) return; // Can't toggle privacy for offline files

    setState(() {
      isPublic = !isPublic;
    });

    String currentUser = FirebaseAuth.instance.currentUser?.email ?? 'Unknown';

    try {
      DocumentSnapshot? noteDoc;

      if (widget.noteId.isNotEmpty) {
        noteDoc =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(widget.noteId)
                .get();
      } else {
        final noteQuery =
            await FirebaseFirestore.instance
                .collection('notes')
                .where('fileUrl', isEqualTo: widget.pdfUrl)
                .limit(1)
                .get();

        if (noteQuery.docs.isNotEmpty) {
          noteDoc = noteQuery.docs.first;
        }
      }

      if (noteDoc != null && noteDoc.exists) {
        // Update public status
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(noteDoc.id)
            .update({'isPublic': isPublic});

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Note visibility updated!')));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating note visibility: $error')),
      );
    }
  }

  void sharePDF(BuildContext context) {
    if (widget.isOfflineFile) return; // Can't share offline files

    final TextEditingController accountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Share PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: accountController,
                decoration: InputDecoration(
                  labelText: 'Email to share with',
                  hintText: 'Enter recipient email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                String recipientEmail = accountController.text.trim();
                if (recipientEmail.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('shared_notes')
                        .add({
                          'recipient': recipientEmail,
                          'noteTitle': widget.noteTitle,
                          'fileUrl': widget.pdfUrl,
                          'sender':
                              FirebaseAuth.instance.currentUser?.email ??
                              'Unknown',
                          'timestamp': FieldValue.serverTimestamp(),
                          'isRead': false,
                          'noteId': widget.noteId,
                        });

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Note shared successfully!')),
                    );
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error sharing note: $error')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a recipient email')),
                  );
                }
              },
              child: Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reportContent(BuildContext context) async {
    if (widget.isOfflineFile) return; // Can't report offline files

    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Report Inappropriate Content'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Please describe why you are reporting this note:'),
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(context, reasonController.text.trim()),
                child: Text('Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // Find note ID if not provided
        String noteId = widget.noteId;
        if (noteId.isEmpty) {
          final noteQuery =
              await FirebaseFirestore.instance
                  .collection('notes')
                  .where('fileUrl', isEqualTo: widget.pdfUrl)
                  .limit(1)
                  .get();

          if (noteQuery.docs.isNotEmpty) {
            noteId = noteQuery.docs.first.id;
          } else {
            throw Exception('Could not find note to report');
          }
        }

        // Add report to Firestore
        await FirebaseFirestore.instance.collection('content_reports').add({
          'noteId': noteId,
          'reporterEmail': currentUser.email,
          'reason': result,
          'reportDate': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report submitted. Thank you!')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting report: $e')));
      }
    }
  }

  void _openPeerReview() {
    if (widget.isOfflineFile || widget.courseId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PeerReviewScreen(
              noteId:
                  widget.noteId.isNotEmpty
                      ? widget.noteId
                      : '', // Need to implement noteId lookup if empty
              noteTitle: widget.noteTitle,
              courseId: widget.courseId,
              courseCode: widget.courseCode,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteTitle, style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
        actions: [
          // Only show these buttons for online files
          if (!widget.isOfflineFile) ...[
            IconButton(
              icon: Icon(isPublic ? Icons.public : Icons.lock),
              tooltip: isPublic ? "Set to Private" : "Set to Public",
              onPressed: togglePrivacy,
            ),
            IconButton(
              icon: Icon(Icons.share),
              tooltip: "Share PDF",
              onPressed: () => sharePDF(context),
            ),
          ],
          // Add Peer Review button
          if (!widget.isOfflineFile && widget.courseId.isNotEmpty)
            IconButton(
              icon: Icon(Icons.rate_review),
              tooltip: "Peer Review",
              onPressed: _openPeerReview,
            ),
          // Add Report button
          if (!widget.isOfflineFile)
            IconButton(
              icon: Icon(Icons.flag),
              tooltip: "Report",
              onPressed: () => _reportContent(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // PDF Viewer section
          Expanded(
            flex: 3,
            child:
                widget.isOfflineFile
                    ? SfPdfViewer.file(File(widget.pdfUrl))
                    : SfPdfViewer.network(widget.pdfUrl),
          ),

          // Only show ratings and comments for online files
          if (!widget.isOfflineFile)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add Rating Summary Widget if not an offline file
                  if (widget.noteId.isNotEmpty)
                    RatingSummaryWidget(noteId: widget.noteId),

                  Text(
                    'Rate this note:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _userRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed:
                            _hasRated ? null : () => _submitRating(index + 1),
                      );
                    }),
                  ),
                  Divider(),
                  Text(
                    'Comments:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 150,
                    child:
                        _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : _comments.isEmpty
                            ? Center(
                              child: Text(
                                'No comments yet. Be the first to comment!',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                return ListTile(
                                  title: Text(
                                    comment.authorEmail,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  subtitle: Text(
                                    comment.text,
                                    style: TextStyle(fontFamily: 'Poppins'),
                                  ),
                                  trailing: Text(
                                    '${comment.timestamp.day}/${comment.timestamp.month}/${comment.timestamp.year}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addComment,
                        child: Icon(Icons.send),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class Comment {
  final String id;
  final String authorEmail;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.authorEmail,
    required this.text,
    required this.timestamp,
  });
}

// Note: RatingSummaryWidget is referenced in this file but would be in:
// lib/widgets/rating_summary_widget.dart
// PeerReviewScreen is referenced but would be in:
// lib/screens/peer_review_screen.dart
