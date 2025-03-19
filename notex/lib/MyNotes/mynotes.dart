import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:notex/MyNotes/pdfViewer.dart';
import 'package:notex/MyNotes/shared_with_me.dart';

class MyNotesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Notes'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('notes').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No notes available",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }
                var notes = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    var note = notes[index];
                    return ListTile(
                      title: Text("PDF Note ${index + 1}"),
                      subtitle: Text(
                        note['timestamp']?.toDate().toString() ?? "No Date",
                      ),
                      trailing: Icon(Icons.picture_as_pdf, color: Colors.red),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PDFViewerPage(pdfUrl: note['url']),
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
