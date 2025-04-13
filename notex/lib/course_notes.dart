import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/MyNotes/addnote.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/models/note.dart';
import 'package:notex/services/offline_service.dart';
import 'package:intl/intl.dart';

class CourseNotesPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String courseCode;

  CourseNotesPage({
    required this.courseId,
    required this.courseName,
    required this.courseCode,
  });

  @override
  _CourseNotesPageState createState() => _CourseNotesPageState();
}

class _CourseNotesPageState extends State<CourseNotesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _userNotes = [];
  List<Map<String, dynamic>> _instructorNotes = [];
  String _searchQuery = '';

  // Accent colors for note cards
  final List<Color> _accentColors = [
    Color(0xFFFF9E80), // Deep Orange accent
    Color(0xFFFF80AB), // Pink accent
    Color(0xFFEA80FC), // Purple accent
    Color(0xFFB388FF), // Deep Purple accent
    Color(0xFF8C9EFF), // Indigo accent
    Color(0xFF82B1FF), // Blue accent
    Color(0xFF80D8FF), // Light Blue accent
    Color(0xFF84FFFF), // Cyan accent
    Color(0xFFA7FFEB), // Teal accent
    Color(0xFFB9F6CA), // Green accent
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load user's notes for this course
      final userNotesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('courseId', isEqualTo: widget.courseId)
              .where('ownerEmail', isEqualTo: currentUser.email)
              .orderBy('uploadDate', descending: true)
              .get();

      // Load instructor/admin notes for this course (public notes not made by the current user)
      final instructorNotesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('courseId', isEqualTo: widget.courseId)
              .where('isPublic', isEqualTo: true)
              .orderBy('uploadDate', descending: true)
              .get();

      // Process user notes
      List<Map<String, dynamic>> userNotes = [];
      for (var doc in userNotesQuery.docs) {
        final data = doc.data();
        final randomAccentColor =
            _accentColors[doc.id.hashCode % _accentColors.length];

        userNotes.add({
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Note',
          'courseId': data['courseId'] ?? '',
          'ownerEmail': data['ownerEmail'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'fileName': data['fileName'] ?? '',
          'uploadDate': data['uploadDate']?.toDate() ?? DateTime.now(),
          'isPublic': data['isPublic'] ?? false,
          'downloads': data['downloads'] ?? 0,
          'averageRating': data['averageRating'] ?? 0.0,
          'tags': List<String>.from(data['tags'] ?? []),
          'accentColor': randomAccentColor,
        });
      }

      // Process instructor notes
      List<Map<String, dynamic>> instructorNotes = [];
      for (var doc in instructorNotesQuery.docs) {
        // Skip user's own notes in the instructor tab
        if (doc.data()['ownerEmail'] == currentUser.email) continue;

        final data = doc.data();
        final randomAccentColor =
            _accentColors[doc.id.hashCode % _accentColors.length];

        instructorNotes.add({
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Note',
          'courseId': data['courseId'] ?? '',
          'ownerEmail': data['ownerEmail'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'fileName': data['fileName'] ?? '',
          'uploadDate': data['uploadDate']?.toDate() ?? DateTime.now(),
          'isPublic': data['isPublic'] ?? false,
          'downloads': data['downloads'] ?? 0,
          'averageRating': data['averageRating'] ?? 0.0,
          'tags': List<String>.from(data['tags'] ?? []),
          'accentColor': randomAccentColor,
        });
      }

      setState(() {
        _userNotes = userNotes;
        _instructorNotes = instructorNotes;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading notes: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _searchNotes(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Map<String, dynamic>> _getFilteredNotes(
    List<Map<String, dynamic>> notes,
  ) {
    if (_searchQuery.isEmpty) return notes;

    return notes.where((note) {
      return note['title'].toLowerCase().contains(_searchQuery) ||
          note['ownerEmail'].toLowerCase().contains(_searchQuery) ||
          note['tags'].any((tag) => tag.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  Future<void> _makeNoteAvailableOffline(Map<String, dynamic> note) async {
    final offlineService = OfflineService();
    final isAvailable = await offlineService.isNoteAvailableOffline(note['id']);

    if (isAvailable) {
      // Already available offline
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Note already available offline')));
      return;
    }

    // Show download progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Downloading'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Downloading for offline access...'),
              ],
            ),
          ),
    );

    // Create Note model from the map
    final noteModel = Note(
      id: note['id'],
      title: note['title'],
      courseId: note['courseId'],
      ownerEmail: note['ownerEmail'],
      fileUrl: note['fileUrl'],
      fileName: note['fileName'],
      uploadDate: note['uploadDate'],
      isPublic: note['isPublic'],
      downloads: note['downloads'],
      averageRating: note['averageRating'],
      tags: List<String>.from(note['tags']),
    );

    final success = await offlineService.saveNoteForOffline(noteModel);

    // Close dialog
    if (mounted) Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Note saved for offline access')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to download note')));
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
                          'noteId': note['id'],
                          'requesterEmail':
                              FirebaseAuth.instance.currentUser?.email,
                          'ownerEmail': note['ownerEmail'],
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.courseCode} - ${widget.courseName}',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.person), text: 'My Notes'),
            Tab(icon: Icon(Icons.school), text: 'Instructor Notes'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _searchNotes,
              decoration: InputDecoration(
                hintText: 'Search notes by title or tag...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // My Notes Tab
                _buildNotesGrid(_getFilteredNotes(_userNotes)),

                // Instructor Notes Tab
                _buildNotesGrid(_getFilteredNotes(_instructorNotes)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add note page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AddNotePage(
                    preselectedCourseId: widget.courseId,
                    initialTitle: null,
                  ),
            ),
          ).then((_) => _loadNotes());
        },
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildNotesGrid(List<Map<String, dynamic>> notes) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No notes found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first note using the + button',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Two notes per row
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, // Adjust based on your design
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return _buildNoteCard(note);
        },
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    return GestureDetector(
      onTap: () {
        // Navigate to PDF viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PDFViewerPage(
                  pdfUrl: note['fileUrl'],
                  noteTitle: note['title'],
                  noteId: note['id'],
                  courseId: note['courseId'],
                  courseCode: widget.courseCode,
                  isPublic: note['isPublic'],
                ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: note['accentColor'], // The accent color from the note
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Heading area
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                note['title'],
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Content area
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'By: ${note['ownerEmail'].split('@')[0]}',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'PDF Document',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer area with date
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date
                  Text(
                    DateFormat('dd MMM, yyyy').format(note['uploadDate']),
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),

                  // Download/Offline button
                  IconButton(
                    icon: Icon(Icons.download_outlined, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () => _makeNoteAvailableOffline(note),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
