import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/widgets/header.dart';
import 'package:notex/widgets/courses.dart';
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/widgets/search.dart'; // Import the search widget
import 'package:notex/homepage.dart';
import 'package:intl/intl.dart';

class SharedNotesScreen extends StatefulWidget {
  @override
  _SharedNotesScreenState createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> {
  List<Map<String, dynamic>> _sharedNotes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSharedNotes();
  }

  Future<void> _fetchSharedNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch notes shared with the current user
      final sharedNotesQuery =
          await FirebaseFirestore.instance
              .collection('shared_notes')
              .where('recipient', isEqualTo: currentUser.email)
              .orderBy('timestamp', descending: true)
              .get();

      List<Map<String, dynamic>> sharedNotesMaps = [];
      for (var doc in sharedNotesQuery.docs) {
        final data = doc.data();

        // Get note details if noteId is available
        String color = '#FFF0F0'; // Default color
        String courseId = '';
        String courseCode = '';
        String courseName = '';

        if (data.containsKey('noteId') && data['noteId'] != null) {
          final noteDoc =
              await FirebaseFirestore.instance
                  .collection('notes')
                  .doc(data['noteId'])
                  .get();

          if (noteDoc.exists) {
            final noteData = noteDoc.data();
            if (noteData != null) {
              courseId = noteData['courseId'] ?? '';
              color = noteData['color'] ?? '#FFF0F0';

              // Get course info
              if (courseId.isNotEmpty) {
                final courseDoc =
                    await FirebaseFirestore.instance
                        .collection('courses')
                        .doc(courseId)
                        .get();

                if (courseDoc.exists) {
                  courseCode = courseDoc.data()?['code'] ?? 'Unknown';
                  courseName = courseDoc.data()?['name'] ?? 'Unknown Course';
                }
              }
            }
          }
        }

        sharedNotesMaps.add({
          'id': doc.id,
          'noteId': data['noteId'] ?? '',
          'title': data['noteTitle'] ?? 'Shared Note',
          'sender': data['sender'] ?? 'Unknown',
          'fileUrl': data['fileUrl'] ?? '',
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'isRead': data['isRead'] ?? false,
          'color': color,
          'courseId': courseId,
          'courseCode': courseCode,
          'courseName': courseName,
        });
      }

      setState(() {
        _sharedNotes = sharedNotesMaps;
        _filteredNotes = sharedNotesMaps;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching shared notes: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle search functionality
  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();

      if (_searchQuery.isEmpty) {
        _filteredNotes = _sharedNotes;
      } else {
        _filteredNotes =
            _sharedNotes.where((note) {
              return note['title'].toLowerCase().contains(_searchQuery) ||
                  note['sender'].toLowerCase().contains(_searchQuery) ||
                  note['courseCode'].toLowerCase().contains(_searchQuery) ||
                  note['courseName'].toLowerCase().contains(_searchQuery);
            }).toList();
      }
    });
  }

  // Handle filter and sort
  void _handleFilter(String filterOptions) {
    // Parse the filter options
    final Map<String, dynamic> options = _parseFilterOptions(filterOptions);

    setState(() {
      List<Map<String, dynamic>> filtered = List.from(_sharedNotes);

      // Apply sender filter if selected
      final String sender = options['subject'] ?? '';
      if (sender.isNotEmpty) {
        filtered =
            filtered.where((note) {
              return note['sender'].toLowerCase().contains(
                sender.toLowerCase(),
              );
            }).toList();
      }

      // Apply sorting if selected
      final String sort = options['sort'] ?? '';
      if (sort.isNotEmpty) {
        switch (sort) {
          case 'latest':
            filtered.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
            break;
          case 'oldest':
            filtered.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
            break;
          case 'unread_first':
            filtered.sort(
              (a, b) => (a['isRead'] ? 1 : 0) - (b['isRead'] ? 1 : 0),
            );
            break;
        }
      }

      // Apply search query if any
      if (_searchQuery.isNotEmpty) {
        filtered =
            filtered.where((note) {
              return note['title'].toLowerCase().contains(_searchQuery) ||
                  note['sender'].toLowerCase().contains(_searchQuery) ||
                  note['courseCode'].toLowerCase().contains(_searchQuery) ||
                  note['courseName'].toLowerCase().contains(_searchQuery);
            }).toList();
      }

      _filteredNotes = filtered;
    });
  }

  Map<String, dynamic> _parseFilterOptions(String filterOptionsString) {
    // Simple parsing of the filter options string
    final Map<String, dynamic> options = {};

    // Extract subject/sender
    final subjectMatch = RegExp(
      r"subject: ([^,}]+)",
    ).firstMatch(filterOptionsString);
    if (subjectMatch != null && subjectMatch.group(1) != null) {
      options['subject'] = subjectMatch.group(1)!.trim();
    }

    // Extract sort
    final sortMatch = RegExp(r"sort: ([^,}]+)").firstMatch(filterOptionsString);
    if (sortMatch != null && sortMatch.group(1) != null) {
      options['sort'] = sortMatch.group(1)!.trim();
    }

    return options;
  }

  void _viewSharedNote(Map<String, dynamic> note) async {
    try {
      // Mark as read if not already
      if (!note['isRead']) {
        await FirebaseFirestore.instance
            .collection('shared_notes')
            .doc(note['id'])
            .update({'isRead': true});

        // Update local state
        setState(() {
          final index = _sharedNotes.indexWhere(
            (item) => item['id'] == note['id'],
          );
          if (index != -1) {
            _sharedNotes[index]['isRead'] = true;
          }

          final filteredIndex = _filteredNotes.indexWhere(
            (item) => item['id'] == note['id'],
          );
          if (filteredIndex != -1) {
            _filteredNotes[filteredIndex]['isRead'] = true;
          }
        });
      }

      // Open the PDF with comments
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => NotePDFViewerWithComments(
                noteId: note['noteId'],
                pdfUrl: note['fileUrl'],
                noteTitle: note['title'],
                courseId: note['courseId'],
                courseCode: note['courseCode'],
                isPublic: true, // Shared notes are accessible
              ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening shared note: $error')),
      );
    }
  }

  void _requestNoteAccess(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Request Note Access'),
            content: Text('Do you want to request access to this note?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Implement access request logic
                  try {
                    await FirebaseFirestore.instance
                        .collection('note_requests')
                        .add({
                          'noteId': note['noteId'],
                          'requesterEmail':
                              FirebaseAuth.instance.currentUser?.email,
                          'ownerEmail': note['sender'],
                          'status': 'pending',
                          'requestedAt': FieldValue.serverTimestamp(),
                        });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Access request sent!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send request')),
                    );
                  }
                },
                child: Text('Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Custom back navigation logic
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        backgroundColor: Color(0xFF2E2E2E), // Dark background for margins
        body: Container(
          margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.018),
          decoration: BoxDecoration(
            color: Color(0xFFF2E9E5), // Consistent background color
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Custom header matching the design in the image
              _buildHeader(),

              // Search widget
              SearchWidget(
                onSearch: _handleSearch,
                onFilter: _handleFilter,
                hintText: 'Search shared notes...',
              ),

              // Main content
              Expanded(
                child:
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _filteredNotes.isEmpty
                        ? _buildEmptyState()
                        : _buildSharedNotesList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            },
          ),
          SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Color(0xFFFFB74D),
            child: Icon(Icons.menu_book, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text(
            'NOTEX',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => CoursesPage()),
                  );
                },
                child: Text(
                  'Courses',
                  style: TextStyle(
                    color: Colors.black54,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => MyNotesPage()),
                  );
                },
                child: Text(
                  'Notes',
                  style: TextStyle(
                    color: Colors.black54,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Already on Shared With Me page
                },
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Color(0xFFFF8C42)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                child: Text(
                  'Shared With Me',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
          Text(
            DateFormat.Hm().format(DateTime.now()),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_shared, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No shared notes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Notes shared with you will appear here',
            style: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedNotesList() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: _filteredNotes.length,
        itemBuilder: (context, index) {
          final note = _filteredNotes[index];
          final Color cardColor = _getColorFromHex(note['color'] ?? '#FFF0F0');

          return GestureDetector(
            onTap: () => _viewSharedNote(note),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with overflow control
                        Text(
                          note['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        // Sender
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey[700],
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'From: ${note['sender']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        // Date
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[700],
                            ),
                            SizedBox(width: 4),
                            Text(
                              _formatDate(note['timestamp']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        Spacer(),
                        // Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Comment icon
                            IconButton(
                              icon: Icon(Icons.comment_outlined, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              onPressed: () => _viewSharedNote(note),
                            ),
                            // Request access button
                            IconButton(
                              icon: Icon(Icons.lock_open_outlined, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              onPressed: () => _requestNoteAccess(note),
                            ),
                          ],
                        ),
                        // Course code if available
                        if (note['courseCode'] != null &&
                            note['courseCode'].isNotEmpty)
                          Text(
                            note['courseCode'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                              fontFamily: 'Poppins',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Unread indicator
                  if (!note['isRead'])
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Convert hex color string to Color
  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  // Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return DateFormat.yMMMd().format(date);
  }
}

// New Widget for PDF Viewer with Instagram-style Comments
class NotePDFViewerWithComments extends StatefulWidget {
  final String pdfUrl;
  final String noteTitle;
  final String noteId;
  final String courseId;
  final String courseCode;
  final bool isPublic;

  NotePDFViewerWithComments({
    required this.pdfUrl,
    required this.noteTitle,
    required this.noteId,
    this.courseId = '',
    this.courseCode = '',
    this.isPublic = true,
  });

  @override
  _NotePDFViewerWithCommentsState createState() =>
      _NotePDFViewerWithCommentsState();
}

class _NotePDFViewerWithCommentsState extends State<NotePDFViewerWithComments> {
  bool _showComments = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main PDF viewer
          PDFViewerPage(
            pdfUrl: widget.pdfUrl,
            noteTitle: widget.noteTitle,
            noteId: widget.noteId,
            courseId: widget.courseId,
            courseCode: widget.courseCode,
            isPublic: widget.isPublic,
          ),

          // Comment section toggle button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _showComments = !_showComments;
                });
              },
              backgroundColor: Colors.deepPurple,
              child: Icon(
                _showComments ? Icons.close : Icons.comment,
                color: Colors.white,
              ),
            ),
          ),

          // Instagram-style comment section
          if (_showComments)
            InstagramStyleComments(
              noteId: widget.noteId,
              onClose: () {
                setState(() {
                  _showComments = false;
                });
              },
            ),
        ],
      ),
    );
  }
}

// Instagram-style Comment Section
class InstagramStyleComments extends StatefulWidget {
  final String noteId;
  final VoidCallback onClose;

  InstagramStyleComments({required this.noteId, required this.onClose});

  @override
  _InstagramStyleCommentsState createState() => _InstagramStyleCommentsState();
}

class _InstagramStyleCommentsState extends State<InstagramStyleComments> {
  final TextEditingController _commentController = TextEditingController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get comments from Firestore
      final commentsSnapshot =
          await FirebaseFirestore.instance
              .collection('notes')
              .doc(widget.noteId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .get();

      // Convert to comments model
      List<CommentModel> comments = [];

      for (var doc in commentsSnapshot.docs) {
        // Get likes for this comment
        final likesSnapshot =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(widget.noteId)
                .collection('comments')
                .doc(doc.id)
                .collection('likes')
                .get();

        final currentUser = FirebaseAuth.instance.currentUser;
        bool isLikedByCurrentUser = false;

        if (currentUser != null) {
          // Check if current user has liked this comment
          final userLikeDoc =
              await FirebaseFirestore.instance
                  .collection('notes')
                  .doc(widget.noteId)
                  .collection('comments')
                  .doc(doc.id)
                  .collection('likes')
                  .doc(currentUser.uid)
                  .get();

          isLikedByCurrentUser = userLikeDoc.exists;
        }

        comments.add(
          CommentModel(
            id: doc.id,
            authorEmail: doc.data()['authorEmail'] ?? 'Unknown',
            text: doc.data()['text'] ?? '',
            timestamp: doc.data()['timestamp']?.toDate() ?? DateTime.now(),
            likeCount: likesSnapshot.docs.length,
            isLikedByCurrentUser: isLikedByCurrentUser,
          ),
        );
      }

      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading comments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to comment')),
      );
      return;
    }

    try {
      // Add the comment to Firestore
      final commentRef = await FirebaseFirestore.instance
          .collection('notes')
          .doc(widget.noteId)
          .collection('comments')
          .add({
            'text': _commentController.text.trim(),
            'authorEmail': currentUser.email,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Create a new comment model
      final newComment = CommentModel(
        id: commentRef.id,
        authorEmail: currentUser.email ?? 'Unknown',
        text: _commentController.text.trim(),
        timestamp: DateTime.now(),
        likeCount: 0,
        isLikedByCurrentUser: false,
      );

      // Update UI
      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
      });
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add comment')));
    }
  }

  Future<void> _toggleLike(CommentModel comment) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to like comments')),
      );
      return;
    }

    try {
      // Reference to the like document
      final likeRef = FirebaseFirestore.instance
          .collection('notes')
          .doc(widget.noteId)
          .collection('comments')
          .doc(comment.id)
          .collection('likes')
          .doc(currentUser.uid);

      // Check if user already liked this comment
      if (comment.isLikedByCurrentUser) {
        // Remove the like
        await likeRef.delete();

        // Update UI
        setState(() {
          final index = _comments.indexWhere((c) => c.id == comment.id);
          if (index != -1) {
            _comments[index] = _comments[index].copyWith(
              likeCount: _comments[index].likeCount - 1,
              isLikedByCurrentUser: false,
            );
          }
        });
      } else {
        // Add the like
        await likeRef.set({
          'userId': currentUser.uid,
          'userEmail': currentUser.email,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update UI
        setState(() {
          final index = _comments.indexWhere((c) => c.id == comment.id);
          if (index != -1) {
            _comments[index] = _comments[index].copyWith(
              likeCount: _comments[index].likeCount + 1,
              isLikedByCurrentUser: true,
            );
          }
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update like')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          MediaQuery.of(context).size.width *
          0.35, // Take up part of the screen for desktop
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(-5, 0),
          ),
        ],
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Comments',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: widget.onClose,
          ),
        ),
        body: Column(
          children: [
            // Comment list
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                      ? Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
            ),

            // Comment input
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // User avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade300,
                    child: Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Comment textfield
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.grey.shade500,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Post button
                  TextButton(
                    onPressed: _addComment,
                    child: Text(
                      'Post',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            child: Text(
              comment.authorEmail.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
          SizedBox(width: 12),
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name and comment text
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: _formatEmail(comment.authorEmail) + ' ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: comment.text,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                // Comment actions
                Row(
                  children: [
                    // Time
                    Text(
                      _getTimeAgo(comment.timestamp),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(width: 16),
                    // Like button
                    GestureDetector(
                      onTap: () => _toggleLike(comment),
                      child: Text(
                        'Like',
                        style: TextStyle(
                          color:
                              comment.isLikedByCurrentUser
                                  ? Colors.deepPurple
                                  : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight:
                              comment.isLikedByCurrentUser
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Reply button
                    Text(
                      'Reply',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                // Like count
                if (comment.likeCount > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.deepPurple,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${comment.likeCount}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format email to display format (remove domain)
  String _formatEmail(String email) {
    return email.split('@').first;
  }

  // Get relative time (like Instagram)
  String _getTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo';
    } else {
      return '${(difference.inDays / 365).floor()}y';
    }
  }
}

// Comment model class
class CommentModel {
  final String id;
  final String authorEmail;
  final String text;
  final DateTime timestamp;
  final int likeCount;
  final bool isLikedByCurrentUser;

  CommentModel({
    required this.id,
    required this.authorEmail,
    required this.text,
    required this.timestamp,
    required this.likeCount,
    required this.isLikedByCurrentUser,
  });

  // Create a copy with updated fields
  CommentModel copyWith({
    String? id,
    String? authorEmail,
    String? text,
    DateTime? timestamp,
    int? likeCount,
    bool? isLikedByCurrentUser,
  }) {
    return CommentModel(
      id: id ?? this.id,
      authorEmail: authorEmail ?? this.authorEmail,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      likeCount: likeCount ?? this.likeCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }
}
