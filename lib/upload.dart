import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:notex/MyNotes/addnote.dart' as addnote;
import 'package:notex/MyNotes/mynote.dart';
import 'package:notex/home_page.dart';

class UploadPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return addnote.AddNotePage();
  }
}
