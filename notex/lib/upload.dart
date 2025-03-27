import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:notex/MyNotes/mynotes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/home_page.dart';

class UploadPage extends StatelessWidget {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController fileController = TextEditingController();

  Future<String?> uploadPDF(File pdfFile, String userId) async {
    try {
      Reference ref = FirebaseStorage.instance.ref().child(
        "notes/$userId/${DateTime.now().toIso8601String()}.pdf",
      );
      UploadTask uploadTask = ref.putFile(pdfFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  void upload(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User is not authenticated
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Authentication Required'),
              content: Text('Please log in to upload files.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    String userId = user.uid; // Get the actual user ID

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'], // Restrict to PDFs
    );

    if (result != null) {
      File pdfFile = File(result.files.single.path!);
      String? downloadURL = await uploadPDF(pdfFile, userId);

      if (downloadURL != null) {
        print("File uploaded successfully: $downloadURL");
        await FirebaseFirestore.instance.collection('notes').add({
          'userId': userId,
          'url': downloadURL,
          'timestamp': FieldValue.serverTimestamp(),
        });
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Upload Successful'),
                content: Text('Your file has been uploaded successfully.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                    },
                    child: Text('OK'),
                  ),
                ],
              ),
        );
      } else {
        print("File upload failed");
      }
    } else {
      print("No file selected");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Notes'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => upload(context),
                icon: Icon(Icons.add),
                label: Text('Upload PDF'),
                style: ElevatedButton.styleFrom(
                  //backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: TextStyle(fontSize: 18, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
