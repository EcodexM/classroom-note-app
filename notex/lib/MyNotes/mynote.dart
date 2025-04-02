import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/home_page.dart';
import 'package:notex/MyNotes/addnote.dart';
import 'package:notex/services/offline_service.dart';
import 'package:notex/widgets/header.dart';
import 'package:notex/models/note.dart';
import 'package:intl/intl.dart';

class MyNotesPage extends StatefulWidget {
  const MyNotesPage({Key? key}) : super(key: key);

  @override
  _MyNotesPageState createState() => _MyNotesPageState();
}

class _MyNotesPageState extends State<MyNotesPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  // Handle navigation based on tab selection
  void _handleTabSelection(int index) {
    // Already on Notes page, do nothing if the Notes tab is selected
    if (index == 1) return;

    // Navigate based on index
    switch (index) {
      case 0:
        // Navigate to Courses
        Navigator.pushReplacementNamed(context, '/courses');
        break;
      case 2:
        // Navigate to Shared With Me
        Navigator.pushReplacementNamed(context, '/shared');
        break;
      default:
        // Navigate home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
    }
  }

  // Handle sign out
  void _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load all notes for the current user
      final notesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('ownerEmail', isEqualTo: currentUser.email)
              .orderBy('uploadDate', descending: true)
              .get();

      List<Map<String, dynamic>> notes = [];

      for (var doc in notesQuery.docs) {
        // Get course details for each note
        final courseId = doc.data()['courseId'] ?? '';
        String courseCode = 'Unknown';
        String courseName = 'Unknown Course';

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

        notes.add({
          'id': doc.id,
          'title': doc.data()['title'] ?? 'Untitled Note',
          'courseId': courseId,
          'courseCode': courseCode,
          'courseName': courseName,
          'ownerEmail': doc.data()['ownerEmail'] ?? 'Unknown',
          'fileUrl': doc.data()['fileUrl'] ?? '',
          'fileName': doc.data()['fileName'] ?? 'document.pdf',
          'uploadDate': doc.data()['uploadDate']?.toDate() ?? DateTime.now(),
          'downloads': doc.data()['downloads'] ?? 0,
          'averageRating': doc.data()['averageRating'] ?? 0.0,
          'isPublic': doc.data()['isPublic'] ?? false,
          'tags': List<String>.from(doc.data()['tags'] ?? []),
        });
      }

      if (mounted) {
        setState(() {
          _notes = notes;
          _filteredNotes = notes;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading notes: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _searchNotes(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();

      if (_searchQuery.isEmpty) {
        _filteredNotes = _notes;
      } else {
        _filteredNotes =
            _notes.where((note) {
              return note['title'].toLowerCase().contains(_searchQuery) ||
                  note['courseCode'].toLowerCase().contains(_searchQuery) ||
                  note['courseName'].toLowerCase().contains(_searchQuery) ||
                  note['tags'].any(
                    (tag) => tag.toLowerCase().contains(_searchQuery),
                  );
            }).toList();
      }
    });
  }

  Future<void> _viewNote(Map<String, dynamic> note) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PDFViewerPage(
                pdfUrl: note['fileUrl'],
                noteTitle: note['title'],
                noteId: note['id'],
                courseId: note['courseId'],
                courseCode: note['courseCode'],
                isPublic: note['isPublic'],
              ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening note: $error')));
    }
  }

  Future<void> _makeAvailableOffline(Map<String, dynamic> note) async {
    final offlineService = OfflineService();
    final isAvailable = await offlineService.isNoteAvailableOffline(note['id']);

    if (isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Note already available offline')));
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Downloading',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: const Color(0xFFFF8C42)),
                SizedBox(height: 16),
                Text(
                  'Saving note for offline access...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
      tags: note['tags'],
    );

    final success = await offlineService.saveNoteForOffline(noteModel);

    // Close dialog
    if (mounted) Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Note saved for offline access',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download note',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(
          0xFFFEF6ED,
        ), // Light cream background from your screenshot
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reusable header
                AppHeader(
                  selectedIndex: 2, // Notes tab is selected
                  pageIndex: 2,
                  onTabSelected: _handleTabSelection,
                  onSignOut: _handleSignOut,
                ),

                // Search bar
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _searchNotes,
                            decoration: const InputDecoration(
                              hintText: 'Search Your Notes...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                fontFamily: 'KoPubBatang',
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'KoPubBatang',
                            ),
                          ),
                        ),
                        // Filter button
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Add button
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: Color(0xFFFF8C42),
                              size: 20,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AddNotePage(
                                        preselectedCourseId: null,
                                        initialTitle: null,
                                      ),
                                ),
                              ).then((_) => _loadNotes());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main content area
                Expanded(
                  child:
                      _isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF8C42),
                            ),
                          )
                          : _filteredNotes.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_note_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No notes found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add your first note using the + button',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ],
                            ),
                          )
                          : GridView.builder(
                            padding: const EdgeInsets.only(
                              bottom: 80,
                            ), // Add padding for FAB
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1,
                                ),
                            itemCount: _filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = _filteredNotes[index];

                              return _buildNoteCard(note);
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AddNotePage(
                    preselectedCourseId: null,
                    initialTitle: null,
                  ),
            ),
          ).then((_) => _loadNotes());
        },
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    // Get a pastel color based on the course code
    final Color cardColor = _getPastelColor(note['courseCode']);

    return GestureDetector(
      onTap: () => _viewNote(note),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
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
                  Text(
                    note['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontFamily: 'sans-serif',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        note['courseCode'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      Text(
                        note['isPublic'] ? 'Public' : 'Private',
                        style: TextStyle(
                          fontSize: 12,
                          color: note['isPublic'] ? Colors.green : Colors.red,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Offline button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.offline_bolt_outlined),
                onPressed: () => _makeAvailableOffline(note),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPastelColor(String seed) {
    // A list of pastel colors that match your UI
    final List<Color> colors = [
      const Color(0xFFFFF0F0), // Pink
      const Color(0xFFF0F8FF), // Blue
      const Color(0xFFF0FFF0), // Green
      const Color(0xFFFFFFF0), // Yellow
      const Color(0xFFFFF5EA), // Orange
      const Color(0xFFF5F0FF), // Purple
      const Color(0xFFF0FFFF), // Cyan
      const Color(0xFFFFF8E1), // Amber
    ];

    // Simple hash function to get consistent colors
    int hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = (hash + seed.codeUnitAt(i)) % colors.length;
    }

    return colors[hash];
  }
}
