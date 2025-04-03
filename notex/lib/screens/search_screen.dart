import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/models/course.dart';
import 'package:notex/models/note.dart';
import 'package:notex/screens/course_detail_screen.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/widgets/header.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _courseResults = [];
  List<Map<String, dynamic>> _noteResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _courseResults = [];
        _noteResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = query.toLowerCase();
    });

    try {
      // Search courses
      final coursesQuery =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('searchTerms', arrayContains: _searchQuery)
              .limit(20)
              .get();

      List<Map<String, dynamic>> courseResults = [];

      for (var doc in coursesQuery.docs) {
        courseResults.add({
          'id': doc.id,
          'code': doc.data()['code'] ?? 'Unknown',
          'name': doc.data()['name'] ?? 'Unknown Course',
          'department': doc.data()['department'] ?? '',
          'noteCount': doc.data()['noteCount'] ?? 0,
          'color': doc.data()['color'] ?? '#3F51B5',
        });
      }

      // Search notes
      final notesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('isPublic', isEqualTo: true)
              .where('searchTerms', arrayContains: _searchQuery)
              .limit(20)
              .get();

      List<Map<String, dynamic>> noteResults = [];

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

        noteResults.add({
          'id': doc.id,
          'title': doc.data()['title'] ?? 'Untitled Note',
          'courseId': courseId,
          'courseCode': courseCode,
          'courseName': courseName,
          'ownerEmail': doc.data()['ownerEmail'] ?? 'Unknown',
          'fileUrl': doc.data()['fileUrl'] ?? '',
          'uploadDate': doc.data()['uploadDate']?.toDate() ?? DateTime.now(),
          'downloads': doc.data()['downloads'] ?? 0,
          'averageRating': doc.data()['averageRating'] ?? 0.0,
          'tags': List<String>.from(doc.data()['tags'] ?? []),
        });
      }

      setState(() {
        _courseResults = courseResults;
        _noteResults = noteResults;
        _isLoading = false;
      });
    } catch (error) {
      print('Error performing search: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to handle tab selection in the header
  void _handleTabSelection(int index) {
    // Navigate based on index
    switch (index) {
      case 0: // Home
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1: // Courses
        Navigator.pushReplacementNamed(context, '/courses');
        break;
      case 2: // Notes
        Navigator.pushReplacementNamed(context, '/notes');
        break;
      case 3: // Shared With Me
        Navigator.pushReplacementNamed(context, '/shared');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2E9E5), // Consistent background color
      body: SafeArea(
        child: Column(
          children: [
            // Use the existing header with consistent positioning
            AppHeader(
              selectedIndex: 2, // Search is under Notes tab
              pageIndex: 2, // Current page index
              onTabSelected: _handleTabSelection,
              onSignOut: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              showBackButton: true, // Show back button in search screen
            ),

            // Search input with consistent margins and styling
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search courses or notes...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: _performSearch,
              ),
            ),

            // Tab bar with consistent styling
            Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.deepPurple,
                tabs: [
                  Tab(icon: Icon(Icons.school), text: 'Courses'),
                  Tab(icon: Icon(Icons.note), text: 'Notes'),
                ],
              ),
            ),

            // Tab content with proper scrolling and margins
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : Container(
                        margin: EdgeInsets.all(24),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Courses tab
                            _searchQuery.isEmpty
                                ? _buildEmptySearch('courses')
                                : _courseResults.isEmpty
                                ? _buildNoResults('courses')
                                : _buildCourseResults(),

                            // Notes tab
                            _searchQuery.isEmpty
                                ? _buildEmptySearch('notes')
                                : _noteResults.isEmpty
                                ? _buildNoResults('notes')
                                : _buildNoteResults(),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseResults() {
    return ListView.builder(
      itemCount: _courseResults.length,
      padding: EdgeInsets.zero, // Use container margins instead
      itemBuilder: (context, index) {
        final course = _courseResults[index];
        final color = Color(int.parse(course['color'].replaceAll('#', '0xFF')));

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CourseDetailScreen(
                        courseId: course['id'],
                        courseCode: course['code'],
                        courseName: course['name'],
                        color: course['color'],
                      ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        course['code'].substring(
                          0,
                          Math.min(2, course['code'].length),
                        ),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course['code'],
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          course['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (course['department'].isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            course['department'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${course['noteCount']} notes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteResults() {
    return ListView.builder(
      itemCount: _noteResults.length,
      padding: EdgeInsets.zero, // Use container margins instead
      itemBuilder: (context, index) {
        final note = _noteResults[index];
        final date = note['uploadDate'];

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PDFViewerPage(
                        pdfUrl: note['fileUrl'],
                        noteTitle: note['title'],
                      ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${note['courseCode']} - ${note['courseName']}',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'By: ${note['ownerEmail']}',
                    style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        (note['averageRating'] as double).toStringAsFixed(1),
                        style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.download, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        '${note['downloads']}',
                        style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                  if (note['tags'].isNotEmpty) ...[
                    SizedBox(height: 8),
                    Container(
                      height: 28, // Fixed height to prevent overflow
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (note['tags'] as List<String>).length,
                        itemBuilder: (context, tagIndex) {
                          final tag = (note['tags'] as List<String>)[tagIndex];
                          return Container(
                            margin: EdgeInsets.only(right: 4),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySearch(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == 'courses' ? Icons.school : Icons.note,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Search for $type',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No $type found for "$_searchQuery"',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for min function
class Math {
  static int min(int a, int b) => a < b ? a : b;
}
