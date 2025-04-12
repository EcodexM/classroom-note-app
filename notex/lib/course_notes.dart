import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/MyNotes/addnote.dart';
import 'package:notex/MyNotes/addnote.dart' as addnote;
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/models/course.dart';
import 'package:notex/models/note.dart';
import 'package:notex/services/offline_service.dart';
import 'package:intl/intl.dart';
import 'MyNotes/mynote.dart';
import 'MyNotes/mynote.dart' as addnote;

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
  List<Note> _publicNotes = [];
  List<Note> _myNotes = [];
  String _searchQuery = '';

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

      // Load public notes for this course
      final publicNotesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('courseId', isEqualTo: widget.courseId)
              .where('isPublic', isEqualTo: true)
              .orderBy('uploadDate', descending: true)
              .get();

      final publicNotes =
          publicNotesQuery.docs
              .map((doc) => Note.fromFirestore(doc.data(), doc.id))
              .toList();

      // Load user's notes for this course
      final myNotesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where('courseId', isEqualTo: widget.courseId)
              .where('ownerEmail', isEqualTo: currentUser.email)
              .orderBy('uploadDate', descending: true)
              .get();

      final myNotes =
          myNotesQuery.docs
              .map((doc) => Note.fromFirestore(doc.data(), doc.id))
              .toList();

      setState(() {
        _publicNotes = publicNotes;
        _myNotes = myNotes;
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

  List<Note> _getFilteredNotes(List<Note> notes) {
    if (_searchQuery.isEmpty) return notes;

    return notes.where((note) {
      return note.title.toLowerCase().contains(_searchQuery) ||
          note.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  Future<void> _makeNoteAvailableOffline(Note note) async {
    final offlineService = OfflineService();
    final isAvailable = await offlineService.isNoteAvailableOffline(note.id);

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

    final success = await offlineService.saveNoteForOffline(note);

    // Close dialog
    Navigator.pop(context);

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

  Future<void> _rateNote(Note note, double rating) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Add or update user rating
      await FirebaseFirestore.instance
          .collection('notes')
          .doc(note.id)
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
              .doc(note.id)
              .collection('ratings')
              .get();

      double sum = 0;
      int count = ratingsQuery.docs.length;

      for (var doc in ratingsQuery.docs) {
        sum += (doc.data()['rating'] as num).toDouble();
      }

      double newAverage = count > 0 ? sum / count : 0;

      // Update average rating in note document
      await FirebaseFirestore.instance.collection('notes').doc(note.id).update({
        'averageRating': newAverage,
      });

      // Refresh notes
      _loadNotes();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rating note: $error')));
    }
  }

  Future<void> _downloadNote(Note note) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Increment downloads
      await FirebaseFirestore.instance.collection('notes').doc(note.id).update({
        'downloads': FieldValue.increment(1),
      });

      // Track download in a separate collection
      await FirebaseFirestore.instance.collection('downloads').add({
        'userEmail': currentUser.email,
        'noteId': note.id,
        'downloadedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PDFViewerPage(
                pdfUrl: note.fileUrl,
                noteTitle: note.title,
                isPublic: note.isPublic,
                noteId: note.id,
                courseId: widget.courseId,
                courseCode: widget.courseCode,
              ),
        ),
      );

      // Refresh notes
      _loadNotes();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error downloading note: $error')));
    }
  }

  Future<void> _requestNote() async {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Request a Note'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Note Title',
                    hintText: 'e.g. Lecture 1 Notes',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a title')),
                    );
                    return;
                  }

                  try {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) return;

                    await FirebaseFirestore.instance
                        .collection('note_requests')
                        .add({
                          'courseId': widget.courseId,
                          'title': title,
                          'requestedBy': currentUser.email,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Note request submitted!')),
                    );
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error requesting note: $error')),
                    );
                  }
                },
                child: Text('Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _viewNoteRequests() async {
    try {
      final requestsQuery =
          await FirebaseFirestore.instance
              .collection('note_requests')
              .where('courseId', isEqualTo: widget.courseId)
              .orderBy('createdAt', descending: true)
              .get();

      List<Map<String, dynamic>> requests = [];
      for (var doc in requestsQuery.docs) {
        requests.add({
          'id': doc.id,
          'title': doc.data()['title'] ?? 'Untitled',
          'requestedBy': doc.data()['requestedBy'] ?? 'Unknown',
          'createdAt': doc.data()['createdAt']?.toDate() ?? DateTime.now(),
        });
      }

      if (requests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No note requests for this course')),
        );
        return;
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Note Requests'),
              content: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return ListTile(
                      title: Text(request['title']),
                      subtitle: Text('By: ${request['requestedBy']}'),
                      trailing: Text(
                        DateFormat('MM/dd/yy').format(request['createdAt']),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => addnote.AddNotePage(
                                  preselectedCourseId: widget.courseId,
                                  initialTitle: request['title'],
                                ),
                          ),
                        ).then((_) {
                          _loadNotes();
                          // Delete the request after fulfilling
                          FirebaseFirestore.instance
                              .collection('note_requests')
                              .doc(request['id'])
                              .delete();
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading note requests: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.courseCode} - Notes',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.public), text: 'Public Notes'),
            Tab(icon: Icon(Icons.person), text: 'My Notes'),
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
                // Public Notes Tab
                _buildNotesTab(_getFilteredNotes(_publicNotes)),

                // My Notes Tab
                _buildNotesTab(_getFilteredNotes(_myNotes)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _viewNoteRequests,
            backgroundColor: Colors.amber,
            heroTag: 'viewRequests',
            child: Icon(Icons.list_alt, color: Colors.white),
            mini: true,
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _requestNote,
            backgroundColor: Colors.deepPurple,
            heroTag: 'requestNote',
            child: Icon(Icons.notification_add, color: Colors.white),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => addnote.AddNotePage(
                        preselectedCourseId: widget.courseId,
                        initialTitle: null,
                      ),
                ),
              ).then((_) => _loadNotes());
            },
            backgroundColor: Colors.deepPurple,
            heroTag: 'addNote',
            child: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab(List<Note> notes) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notes found',
              style: TextStyle(fontSize: 18, fontFamily: 'Poppins'),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add a note',
              style: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notes.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final note = notes[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(
              note.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By: ${note.ownerEmail}',
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      note.averageRating.toStringAsFixed(1),
                      style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.star_border, size: 16),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text('Rate this Note'),
                                content: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    return IconButton(
                                      icon: Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 32,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _rateNote(note, (index + 1).toDouble());
                                      },
                                    );
                                  }),
                                ),
                              ),
                        );
                      },
                    ),
                    Spacer(),
                    Icon(Icons.download, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      '${note.downloads}',
                      style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
                if (note.tags.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children:
                        note.tags.map((tag) {
                          return Chip(
                            label: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            labelPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            backgroundColor: Colors.grey[200],
                          );
                        }).toList(),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<bool>(
                  future: OfflineService().isNoteAvailableOffline(note.id),
                  builder: (context, snapshot) {
                    final isAvailable = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        isAvailable ? Icons.offline_pin : Icons.offline_bolt,
                        color: isAvailable ? Colors.green : Colors.grey,
                      ),
                      onPressed: () => _makeNoteAvailableOffline(note),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.download, color: Colors.deepPurple),
                  onPressed: () => _downloadNote(note),
                ),
              ],
            ),
            onTap: () => _downloadNote(note),
          ),
        );
      },
    );
  }
}
