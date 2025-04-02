import 'package:flutter/material.dart';
import 'package:notex/services/offline_service.dart';
import 'package:notex/models/note.dart';
import 'package:notex/MyNotes/pdfViewer.dart';

class OfflineNotesScreen extends StatefulWidget {
  @override
  _OfflineNotesScreenState createState() => _OfflineNotesScreenState();
}

class _OfflineNotesScreenState extends State<OfflineNotesScreen> {
  final OfflineService _offlineService = OfflineService();
  List<Note> _offlineNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfflineNotes();
  }

  Future<void> _loadOfflineNotes() async {
    setState(() {
      _isLoading = true;
    });

    final notes = await _offlineService.getOfflineNotes();

    setState(() {
      _offlineNotes = notes;
      _isLoading = false;
    });
  }

  Future<void> _removeFromOffline(Note note) async {
    final success = await _offlineService.removeFromOffline(note.id);
    if (success) {
      setState(() {
        _offlineNotes.removeWhere((n) => n.id == note.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note removed from offline storage')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing note from offline storage')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offline Notes', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _offlineNotes.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No offline notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Download notes to access them offline',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _offlineNotes.length,
                padding: EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final note = _offlineNotes[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.description,
                        color: Colors.deepPurple,
                      ),
                      title: Text(
                        note.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      subtitle: Text(
                        'By: ${note.ownerEmail}',
                        style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeFromOffline(note),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PDFViewerPage(
                                  pdfUrl: note.fileUrl,
                                  noteTitle: note.title,
                                  isOfflineFile: true,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}
