import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:notex/models/note.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Private constructor
  OfflineService._internal() {
    // Enable offline persistence for Firestore
    _firestore.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Factory constructor
  factory OfflineService() {
    return _instance;
  }

  // Initialize offline capabilities
  Future<void> initialize() async {
    try {
      // Force a small fetch to ensure persistence is working
      await _firestore.collection('notes').limit(1).get();
      print('Firebase offline persistence initialized');
    } catch (e) {
      print('Error initializing Firebase offline persistence: $e');
    }
  }

  // Download a note for offline access
  Future<bool> saveNoteForOffline(Note note) async {
    try {
      // First check if we already have the note document cached
      bool isMetadataCached = await isNoteCached(note.id);

      // Perform a network fetch to ensure we have the latest version
      await _firestore.collection('notes').doc(note.id).get();

      // For the actual PDF file, we still need to download it since Firestore
      // doesn't automatically cache binary files from Storage
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final noteDirectory = Directory(
        '${documentsDirectory.path}/offline_notes',
      );
      if (!await noteDirectory.exists()) {
        await noteDirectory.create(recursive: true);
      }

      final filePath = '${noteDirectory.path}/${note.id}.pdf';
      final file = File(filePath);

      // Check if the file already exists
      if (!await file.exists()) {
        // Download the file
        final response = await http.get(Uri.parse(note.fileUrl));
        if (response.statusCode != 200) {
          return false;
        }

        await file.writeAsBytes(response.bodyBytes);
      }

      // Mark this note as available offline
      await _firestore.collection('offline_notes').doc(note.id).set({
        'noteId': note.id,
        'filePath': filePath,
        'downloadedAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      });

      return true;
    } catch (e) {
      print('Error downloading note for offline: $e');
      return false;
    }
  }

  // Check if a note is cached and available offline
  Future<bool> isNoteCached(String noteId) async {
    try {
      // Check if the document exists in the cache
      final docSnapshot = await _firestore
          .collection('notes')
          .doc(noteId)
          .get(GetOptions(source: Source.cache));

      return docSnapshot.exists;
    } catch (e) {
      // If an error occurs, the document is not in the cache
      return false;
    }
  }

  // Check if a note has been marked for offline access
  Future<bool> isNoteAvailableOffline(String noteId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Check if we have an entry in offline_notes collection
      final offlineDoc =
          await _firestore.collection('offline_notes').doc(noteId).get();

      if (offlineDoc.exists &&
          offlineDoc.data()?['userId'] == currentUser.uid) {
        // Check if the file exists
        final filePath = offlineDoc.data()?['filePath'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          return await file.exists();
        }
      }

      return false;
    } catch (e) {
      print('Error checking offline status: $e');
      return false;
    }
  }

  // Get a list of all notes marked for offline access
  Future<List<Note>> getOfflineNotes() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      // Get all notes marked as offline for this user
      final offlineDocsQuery =
          await _firestore
              .collection('offline_notes')
              .where('userId', isEqualTo: currentUser.uid)
              .get();

      List<Note> offlineNotes = [];

      for (var doc in offlineDocsQuery.docs) {
        final noteId = doc.data()['noteId'] as String;
        final filePath = doc.data()['filePath'] as String;

        // Get the note data from Firestore
        final noteDoc = await _firestore
            .collection('notes')
            .doc(noteId)
            .get(GetOptions(source: Source.cache));

        if (noteDoc.exists) {
          // Create a Note object from the Firestore data
          Map<String, dynamic> data = noteDoc.data() ?? {};

          // Create a new Note with the local file path for offline viewing
          offlineNotes.add(
            Note(
              id: noteDoc.id,
              title: data['title'] ?? '',
              courseId: data['courseId'] ?? '',
              ownerEmail: data['ownerEmail'] ?? '',
              fileUrl: filePath, // Use local file path
              fileName: data['fileName'] ?? '',
              uploadDate:
                  (data['uploadDate'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              isPublic: data['isPublic'] ?? false,
              downloads: (data['downloads'] as num?)?.toInt() ?? 0,
              averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
              tags:
                  (data['tags'] != null) ? List<String>.from(data['tags']) : [],
              isOffline: true,
            ),
          );
        }
      }

      return offlineNotes;
    } catch (e) {
      print('Error getting offline notes: $e');
      return [];
    }
  }

  // Remove a note from offline access
  Future<bool> removeFromOffline(String noteId) async {
    try {
      // Get the offline document to find the file path
      final offlineDoc =
          await _firestore.collection('offline_notes').doc(noteId).get();

      if (offlineDoc.exists) {
        final filePath = offlineDoc.data()?['filePath'] as String?;

        // Delete the local file
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }

        // Delete the offline_notes entry
        await _firestore.collection('offline_notes').doc(noteId).delete();

        return true;
      }

      return false;
    } catch (e) {
      print('Error removing offline note: $e');
      return false;
    }
  }

  // Get the local file path for an offline note
  Future<String?> getOfflineFilePath(String noteId) async {
    try {
      final offlineDoc =
          await _firestore.collection('offline_notes').doc(noteId).get();

      if (offlineDoc.exists) {
        final filePath = offlineDoc.data()?['filePath'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            return filePath;
          }
        }
      }

      return null;
    } catch (e) {
      print('Error getting offline file path: $e');
      return null;
    }
  }
}
