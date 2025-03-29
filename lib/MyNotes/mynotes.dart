import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/MyNotes/shared_with_me.dart';

class MyNotesPage extends StatefulWidget {
  @override
  _MyNotesPageState createState() => _MyNotesPageState();
}

class _MyNotesPageState extends State<MyNotesPage> {
  String searchQuery = "";

  Future<List<QueryDocumentSnapshot>> searchFiles(String query) async {
    if (query.isEmpty) return [];
    final snapshot =
        await FirebaseFirestore.instance
            .collection('notes') // Use public_notes collection
            .where('title', isGreaterThanOrEqualTo: query) // Updated field name
            .where(
              'title',
              isLessThanOrEqualTo: query + '\uf8ff',
            ) // Updated field name
            .get();
    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Notes'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<QueryDocumentSnapshot>>(
              future:
                  searchQuery.isEmpty
                      ? FirebaseFirestore.instance
                          .collection('notes')
                          .get()
                          .then((snapshot) => snapshot.docs)
                      : searchFiles(searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      "No notes available",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }
                var notes = snapshot.data!;
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    var note = notes[index];
                    return ListTile(
                      //YOU CAN SET UP NOTES NAMING FUCTIONALITY HERE
                      title: Text("Sample note 1"), // Updated field name
                      subtitle: Text(
                        note['timestamp']?.toDate().toString() ??
                            "No Date", // Updated field name
                      ),
                      trailing: Icon(Icons.picture_as_pdf, color: Colors.red),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PDFViewerPage(
                                  pdfUrl: note['url'],
                                ), // Updated field name
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SharedWithMePage()),
                );
              },
              child: Text('Inbox', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
