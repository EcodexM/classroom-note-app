import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PDFViewerPage extends StatefulWidget {
  final String pdfUrl;
  final bool isPublic; // Initial state for public/private toggle

  PDFViewerPage({required this.pdfUrl, this.isPublic = true});

  @override
  _PDFViewerPageState createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  late bool isPublic;

  @override
  void initState() {
    super.initState();
    isPublic = widget.isPublic;
  }

  void togglePrivacy() async {
    setState(() {
      isPublic = !isPublic;
    });

    String currentUser = FirebaseAuth.instance.currentUser?.email ?? 'Unknown';

    if (isPublic) {
      // Add note to public_notes collection
      await FirebaseFirestore.instance.collection('public_notes').add({
        'owner': currentUser,
        'fileUrl': widget.pdfUrl,
        'fileName': 'Sample Note', // Replace with actual file name
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'dislikes': 0,
      });
    } else {
      // Remove note from public_notes collection
      var snapshot =
          await FirebaseFirestore.instance
              .collection('public_notes')
              .where('fileUrl', isEqualTo: widget.pdfUrl)
              .where('owner', isEqualTo: currentUser)
              .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    print("Visibility set to: ${isPublic ? 'Public' : 'Private'}");
  }

  void sharePDF(BuildContext context) {
    final TextEditingController accountController = TextEditingController();
    final TextEditingController fileNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Share PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: accountController,
                decoration: InputDecoration(
                  labelText: 'Account to send to',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: fileNameController,
                decoration: InputDecoration(
                  labelText: 'File Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String account = accountController.text.trim();
                String fileName = fileNameController.text.trim();

                if (account.isNotEmpty && fileName.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('shared_notes')
                      .add({
                        'account': account,
                        'fileName': fileName,
                        'fileUrl': widget.pdfUrl,
                        'owner':
                            FirebaseAuth.instance.currentUser?.email ??
                            'Unknown',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('File shared successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill in all fields.')),
                  );
                }
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Viewer'),
        backgroundColor: Colors.deepPurple,
        actions: [
          /// Public/Private Toggle Button (Left)
          IconButton(
            icon: Icon(
              isPublic ? Icons.public : Icons.lock,
              color: Colors.black, // Change icon color to black
            ),
            iconSize: 30.0, // Increase icon size
            tooltip: isPublic ? "Set to Private" : "Set to Public",
            onPressed: togglePrivacy,
          ),

          // Share Button (Right)
          IconButton(
            icon: Icon(
              Icons.share,
              color: Colors.black, // Change icon color to black
            ),
            iconSize: 30.0, // Increase icon size
            tooltip: "Share PDF",
            onPressed: () => sharePDF(context),
          ),
        ],
      ),
      body: SfPdfViewer.network(widget.pdfUrl),
    );
  }
}
