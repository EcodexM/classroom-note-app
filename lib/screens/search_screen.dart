import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/models/course.dart';
import 'package:notex/models/note.dart';
import 'package:notex/screens/course_detail_screen.dart';
import 'package:notex/MyNotes/pdfViewer.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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
              ),
              onSubmitted: _performSearch,
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.deepPurple,
            tabs: [
              Tab(icon: Icon(Icons.school), text: 'Courses'),
              Tab(icon: Icon(Icons.note), text: 'Notes'),
            ],
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        // Courses tab
                        _searchQuery.isEmpty
                            ? _buildEmptySearch('courses')
                            : _courseResults.isEmpty
                            ? _buildNoResults('courses')
                            : ListView.builder(
                              itemCount: _courseResults.length,
                              padding: EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final course = _courseResults[index];
                                final color = Color(
                                  int.parse(
                                    course['color'].replaceAll('#', '0xFF'),
                                  ),
                                );

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
                                                course['code'].substring(0, 2),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  course['code'],
                                                  style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                Text(
                                                  course['name'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                if (course['department']
                                                    .isNotEmpty) ...[
                                                  SizedBox(height: 4),
                                                  Text(
                                                    course['department'],
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                      fontFamily: 'Poppins',
                                                    ),
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
                            ),

                        // Notes tab
                        _searchQuery.isEmpty
                            ? _buildEmptySearch('notes')
                            : _noteResults.isEmpty
                            ? _buildNoResults('notes')
                            : ListView.builder(
                              itemCount: _noteResults.length,
                              padding: EdgeInsets.all(16),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  note['title'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    fontFamily: 'Poppins',
                                                  ),
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
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'By: ${note['ownerEmail']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.star,
                                                size: 16,
                                                color: Colors.amber,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                (note['averageRating']
                                                        as double)
                                                    .toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              SizedBox(width: 16),
                                              Icon(
                                                Icons.download,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '${note['downloads']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (note['tags'].isNotEmpty) ...[
                                            SizedBox(height: 8),
                                            Wrap(
                                              spacing: 4,
                                              children:
                                                  (note['tags'] as List<String>).map((
                                                    tag,
                                                  ) {
                                                    return Chip(
                                                      label: Text(
                                                        tag,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontFamily: 'Poppins',
                                                        ),
                                                      ),
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      padding: EdgeInsets.zero,
                                                      labelPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 0,
                                                          ),
                                                      backgroundColor:
                                                          Colors.grey[200],
                                                    );
                                                  }).toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
          ),
        ],
      ),
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
