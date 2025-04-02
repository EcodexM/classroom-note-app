// Continuing lib/admin/content_moderation.dart
// This completes the missing functions for the content moderation page
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:notex/MyNotes/pdfViewer.dart';

class ContentModerationPage extends StatefulWidget {
  @override
  _ContentModerationPageState createState() => _ContentModerationPageState();
}

class _ContentModerationPageState extends State<ContentModerationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportedNotes = [];
  List<Map<String, dynamic>> _recentNotes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load reported notes (create this collection if implementing reporting functionality)
      final reportsQuery =
          await FirebaseFirestore.instance
              .collection('content_reports')
              .orderBy('reportDate', descending: true)
              .get();

      List<Map<String, dynamic>> reportedNotes = [];
      Map<String, List<Map<String, dynamic>>> reportsByNoteId = {};

      // Group reports by noteId
      for (var doc in reportsQuery.docs) {
        final reportData = {
          'id': doc.id,
          'noteId': doc.data()['noteId'] ?? '',
          'reporterEmail': doc.data()['reporterEmail'] ?? 'Anonymous',
          'reason': doc.data()['reason'] ?? 'No reason provided',
          'reportDate': doc.data()['reportDate']?.toDate() ?? DateTime.now(),
          'status': doc.data()['status'] ?? 'pending',
        };

        if (!reportsByNoteId.containsKey(reportData['noteId'])) {
          reportsByNoteId[reportData['noteId']] = [];
        }

        reportsByNoteId[reportData['noteId']]!.add(reportData);
      }

      // Get note details for each reported note
      for (var noteId in reportsByNoteId.keys) {
        final noteDoc =
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(noteId)
                .get();

        if (noteDoc.exists) {
          final noteData = noteDoc.data() ?? {};

          // Get course details
          String courseCode = 'Unknown';
          String courseName = 'Unknown Course';

          if (noteData['courseId'] != null) {
            final courseDoc =
                await FirebaseFirestore.instance
                    .collection('courses')
                    .doc(noteData['courseId'])
                    .get();

            if (courseDoc.exists) {
              courseCode = courseDoc.data()?['code'] ?? 'Unknown';
              courseName = courseDoc.data()?['name'] ?? 'Unknown Course';
            }
          }

          reportedNotes.add({
            'noteId': noteId,
            'title': noteData['title'] ?? 'Untitled Note',
            'ownerEmail': noteData['ownerEmail'] ?? 'Unknown',
            'uploadDate': noteData['uploadDate']?.toDate() ?? DateTime.now(),
            'fileUrl': noteData['fileUrl'] ?? '',
            'courseCode': courseCode,
            'courseName': courseName,
            'reports': reportsByNoteId[noteId] ?? [],
            'reportCount': reportsByNoteId[noteId]?.length ?? 0,
          });
        }
      }

      // Sort by report count
      reportedNotes.sort(
        (a, b) => b['reportCount'].compareTo(a['reportCount']),
      );

      // Load recent notes
      final recentNotesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .orderBy('uploadDate', descending: true)
              .limit(20)
              .get();

      List<Map<String, dynamic>> recentNotes = [];
      for (var doc in recentNotesQuery.docs) {
        final noteData = doc.data();

        // Get course details
        String courseCode = 'Unknown';
        String courseName = 'Unknown Course';

        if (noteData['courseId'] != null) {
          final courseDoc =
              await FirebaseFirestore.instance
                  .collection('courses')
                  .doc(noteData['courseId'])
                  .get();

          if (courseDoc.exists) {
            courseCode = courseDoc.data()?['code'] ?? 'Unknown';
            courseName = courseDoc.data()?['name'] ?? 'Unknown Course';
          }
        }

        recentNotes.add({
          'id': doc.id,
          'title': noteData['title'] ?? 'Untitled Note',
          'ownerEmail': noteData['ownerEmail'] ?? 'Unknown',
          'uploadDate': noteData['uploadDate']?.toDate() ?? DateTime.now(),
          'fileUrl': noteData['fileUrl'] ?? '',
          'courseCode': courseCode,
          'courseName': courseName,
          'isPublic': noteData['isPublic'] ?? false,
          'downloads': noteData['downloads'] ?? 0,
          'averageRating': noteData['averageRating'] ?? 0.0,
        });
      }

      setState(() {
        _reportedNotes = reportedNotes;
        _recentNotes = recentNotes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading content moderation data: $e');
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

  List<Map<String, dynamic>> get _filteredReportedNotes {
    if (_searchQuery.isEmpty) return _reportedNotes;

    return _reportedNotes.where((note) {
      return note['title'].toLowerCase().contains(_searchQuery) ||
          note['ownerEmail'].toLowerCase().contains(_searchQuery) ||
          note['courseCode'].toLowerCase().contains(_searchQuery) ||
          note['courseName'].toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredRecentNotes {
    if (_searchQuery.isEmpty) return _recentNotes;

    return _recentNotes.where((note) {
      return note['title'].toLowerCase().contains(_searchQuery) ||
          note['ownerEmail'].toLowerCase().contains(_searchQuery) ||
          note['courseCode'].toLowerCase().contains(_searchQuery) ||
          note['courseName'].toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _viewNote(String fileUrl, String title) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerPage(pdfUrl: fileUrl, noteTitle: title),
      ),
    );
  }

  Future<void> _moderateNote(Map<String, dynamic> note) async {
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Moderate ${note['title']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Course: ${note['courseCode']} - ${note['courseName']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text('Uploaded by: ${note['ownerEmail']}'),
                SizedBox(height: 8),
                Text('Reports:'),
                ...note['reports']
                    .map<Widget>(
                      (report) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text(
                          '• ${report['reason']} - by ${report['reporterEmail']}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                SizedBox(height: 16),
                Text('Select moderation action:'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'dismiss'),
                child: Text('Dismiss Reports'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'warning'),
                child: Text('Send Warning'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'remove'),
                child: Text('Remove Note'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        switch (result) {
          case 'dismiss':
            // Mark all reports as dismissed
            for (var report in note['reports']) {
              await FirebaseFirestore.instance
                  .collection('content_reports')
                  .doc(report['id'])
                  .update({'status': 'dismissed'});
            }

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Reports dismissed')));
            break;

          case 'warning':
            // Mark reports as warned
            for (var report in note['reports']) {
              await FirebaseFirestore.instance
                  .collection('content_reports')
                  .doc(report['id'])
                  .update({'status': 'warned'});
            }

            // Send warning notification to owner
            await FirebaseFirestore.instance.collection('notifications').add({
              'userEmail': note['ownerEmail'],
              'message':
                  'Your note "${note['title']}" has been reported for inappropriate content. Please review our content guidelines.',
              'createdAt': FieldValue.serverTimestamp(),
              'type': 'warning',
            });

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Warning sent to user')));
            break;

          case 'remove':
            // Mark reports as resolved
            for (var report in note['reports']) {
              await FirebaseFirestore.instance
                  .collection('content_reports')
                  .doc(report['id'])
                  .update({'status': 'removed'});
            }

            // Remove note
            await FirebaseFirestore.instance
                .collection('notes')
                .doc(note['noteId'])
                .update({'isPublic': false, 'isRemoved': true});

            // Send notification to owner
            await FirebaseFirestore.instance.collection('notifications').add({
              'userEmail': note['ownerEmail'],
              'message':
                  'Your note "${note['title']}" has been removed for violating our content guidelines.',
              'createdAt': FieldValue.serverTimestamp(),
              'type': 'removal',
            });

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Note removed')));
            break;
        }

        // Refresh data
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moderating note: $e')));
      }
    }
  }

  Future<void> _reportNote(Map<String, dynamic> note) async {
    // Simulate reporting a note for admin testing
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Report Note'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Note: ${note['title']}'),
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason for Report',
                    hintText: 'Please describe why you are reporting this note',
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
                child: Text('Submit Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Add report
        await FirebaseFirestore.instance.collection('content_reports').add({
          'noteId': note['id'],
          'reporterEmail':
              'admin@example.com', // Use admin email for simulation
          'reason': result,
          'reportDate': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report submitted for testing')));

        // Refresh data
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _searchNotes,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.red[800],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.red[800],
            tabs: [Tab(text: 'Reported Content'), Tab(text: 'Recent Notes')],
          ),

          // Tab content
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        // Reported content tab
                        _filteredReportedNotes.isEmpty
                            ? Center(
                              child: Text(
                                'No reported content',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _filteredReportedNotes.length,
                              padding: EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final note = _filteredReportedNotes[index];
                                return _buildReportedNoteCard(note);
                              },
                            ),

                        // Recent notes tab
                        _filteredRecentNotes.isEmpty
                            ? Center(
                              child: Text(
                                'No notes found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _filteredRecentNotes.length,
                              padding: EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final note = _filteredRecentNotes[index];
                                return _buildRecentNoteCard(note);
                              },
                            ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportedNoteCard(Map<String, dynamic> note) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Badge(
          label: Text(note['reportCount'].toString()),
          child: Icon(Icons.flag, color: Colors.red),
        ),
        title: Text(
          note['title'],
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${note['courseCode']} - ${note['courseName']}',
              style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            ),
            Text(
              'By: ${note['ownerEmail']}',
              style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            ),
            Text(
              'Uploaded: ${DateFormat('MMM dd, yyyy').format(note['uploadDate'])}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 8),
                ...note['reports']
                    .map<Widget>(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Reported by: ${report['reporterEmail']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MM/dd/yyyy',
                                    ).format(report['reportDate']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Reason: ${report['reason']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Status: ${report['status']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(report['status']),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          () => _viewNote(note['fileUrl'], note['title']),
                      icon: Icon(Icons.visibility),
                      label: Text('View Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _moderateNote(note),
                      icon: Icon(Icons.gavel),
                      label: Text('Moderate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
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

  Widget _buildRecentNoteCard(Map<String, dynamic> note) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          note['title'],
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${note['courseCode']} - ${note['courseName']}',
              style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            ),
            Text(
              'By: ${note['ownerEmail']}',
              style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            ),
            Row(
              children: [
                Icon(Icons.download, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  '${note['downloads']}',
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                SizedBox(width: 8),
                Icon(Icons.star, size: 12, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  '${note['averageRating'].toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.blue),
              onPressed: () => _viewNote(note['fileUrl'], note['title']),
            ),
            IconButton(
              icon: Icon(Icons.flag, color: Colors.red),
              onPressed: () => _reportNote(note),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'dismissed':
        return Colors.green;
      case 'warned':
        return Colors.amber;
      case 'removed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
