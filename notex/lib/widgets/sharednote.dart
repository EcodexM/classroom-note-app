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

  // Handle search
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

      // Open the PDF
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PDFViewerPage(
                pdfUrl: note['fileUrl'],
                noteTitle: note['title'],
                noteId: note['noteId'],
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
