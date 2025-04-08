import 'package:flutter/material.dart';
import 'package:notex/homepage.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/MyNotes/addnote.dart';
import 'package:notex/services/offline_service.dart';
import 'package:notex/widgets/header.dart'; // Import the modified AppHeader
import 'package:notex/models/note.dart';
import 'package:notex/services/keyboard_util.dart';
import 'package:notex/services/notemgn.dart';
import 'package:notex/widgets/courses.dart';
import 'package:notex/widgets/sharednote.dart';

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

  // Handler for tab selection in the header
  void _handleTabSelection(int index) {
    switch (index) {
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CoursesPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MyNotesPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SharedNotesScreen()),
        );
        break;
    }
  }

  // Handler for profile icon tap
  void _handleProfileAction() {
    // Show profile menu or sign out dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Profile Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text('View Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile screen
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final noteService = NoteService();
      final notes = await noteService.getUserNotes();

      // Convert to the existing format
      List<Map<String, dynamic>> noteMaps = [];
      for (var note in notes) {
        final courseDoc =
            await FirebaseFirestore.instance
                .collection('courses')
                .doc(note.courseId)
                .get();

        String courseCode = 'Unknown';
        String courseName = 'Unknown Course';

        if (courseDoc.exists) {
          courseCode = courseDoc.data()?['code'] ?? 'Unknown';
          courseName = courseDoc.data()?['name'] ?? 'Unknown Course';
        }

        noteMaps.add({
          'id': note.id,
          'title': note.title,
          'courseId': note.courseId,
          'courseCode': courseCode,
          'courseName': courseName,
          'ownerEmail': note.ownerEmail,
          'fileUrl': note.fileUrl,
          'fileName': note.fileName,
          'uploadDate': note.uploadDate,
          'downloads': note.downloads,
          'averageRating': note.averageRating,
          'isPublic': note.isPublic,
          'tags': note.tags,
        });
      }

      if (mounted) {
        setState(() {
          _notes = noteMaps;
          _filteredNotes = noteMaps;
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
        backgroundColor: Color(0xFFF2E9E5), // Consistent background color
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use the consistent AppHeader
              AppHeader(
                selectedIndex: 2, // Notes tab is selected
                onTabSelected: _handleTabSelection,
                onProfileMenuTap: _handleProfileAction,
                pageIndex: 2,
                showBackButton: false, // No back button on main screens
              ),

              // Search bar with consistent styling
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
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
                              fontFamily: 'Poppins',
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
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

              // Main content with notes in a grid
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
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add your first note using the + button',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        )
                        : GridView.builder(
                          padding: const EdgeInsets.all(
                            16,
                          ), // Consistent padding
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio:
                                    0.9, // Slightly taller cards for better content display
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
        // Floating action button with a consistent look
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
      ),
    );
  }

  // Helper method to build a note card with consistent styling
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
                  const SizedBox(height: 8),
                  const Spacer(),
                  // Course info with overflow control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          note['courseCode'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        note['isPublic'] ? 'Public' : 'Private',
                        style: TextStyle(
                          fontSize: 12,
                          color: note['isPublic'] ? Colors.green : Colors.red,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Offline button in a consistent position
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

  // Helper method to get a pastel color based on the course code
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
