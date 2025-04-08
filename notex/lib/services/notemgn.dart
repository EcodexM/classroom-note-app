import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:notex/models/note.dart';

class Result<T> {
  final T? data;
  final String? error;

  Result.success(this.data) : error = null;
  Result.failure(this.error) : data = null;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

class NoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UPLOAD SECTION
  Future<Result<String>> uploadNote({
    required String title,
    required String courseId,
    required File file,
    required bool isPublic,
    required List<String> tags,
  }) async {
    try {
      // Validate inputs
      if (title.trim().isEmpty) {
        return Result.failure('Title is required');
      }

      if (!_isValidFileType(file)) {
        return Result.failure('Invalid file format. Only PDF is allowed.');
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return Result.failure('User not authenticated');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${currentUser.uid}_$timestamp.pdf';

      // Upload file to Firebase Storage
      final storageRef = _storage.ref().child('notes/$courseId/$fileName');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Prepare search terms
      final searchTerms = [
        title.trim().toLowerCase(),
        ...tags.map((tag) => tag.toLowerCase()),
      ];

      // Save note metadata to Firestore
      final noteRef = await _firestore.collection('notes').add({
        'title': title.trim(),
        'courseId': courseId,
        'ownerEmail': currentUser.email,
        'fileUrl': downloadUrl,
        'fileName': file.path.split('/').last,
        'uploadDate': FieldValue.serverTimestamp(),
        'isPublic': isPublic,
        'downloads': 0,
        'averageRating': 0.0,
        'tags': tags,
        'searchTerms': searchTerms,
      });

      // Update course note count
      await _firestore.collection('courses').doc(courseId).update({
        'noteCount': FieldValue.increment(1),
      });

      return Result.success(noteRef.id);
    } catch (e) {
      return Result.failure('Upload failed: ${e.toString()}');
    }
  }

  bool _isValidFileType(File file) {
    return file.path.toLowerCase().endsWith('.pdf');
  }

  // SEARCH AND FILTER SECTION
  Future<List<Note>> searchNotes(String query) async {
    try {
      if (query.trim().isEmpty) {
        return await getAllPublicNotes();
      }

      final querySnapshot =
          await _firestore
              .collection('notes')
              .where('searchTerms', arrayContains: query.toLowerCase())
              .where('isPublic', isEqualTo: true)
              .get();

      return querySnapshot.docs
          .map((doc) => Note.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  Future<List<Note>> filterBySubject(String subjectId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('notes')
              .where('courseId', isEqualTo: subjectId)
              .where('isPublic', isEqualTo: true)
              .get();

      return querySnapshot.docs
          .map((doc) => Note.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Filter error: $e');
      return [];
    }
  }

  Future<List<Note>> getAllPublicNotes() async {
    try {
      final querySnapshot =
          await _firestore
              .collection('notes')
              .where('isPublic', isEqualTo: true)
              .get();

      return querySnapshot.docs
          .map((doc) => Note.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Get public notes error: $e');
      return [];
    }
  }

  Future<List<Note>> getUserNotes() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final querySnapshot =
          await _firestore
              .collection('notes')
              .where('ownerEmail', isEqualTo: currentUser.email)
              .orderBy('uploadDate', descending: true)
              .get();

      List<Note> notes = [];
      for (var doc in querySnapshot.docs) {
        notes.add(Note.fromFirestore(doc.data(), doc.id));
      }

      return notes;
    } catch (e) {
      print('Get user notes error: $e');
      return [];
    }
  }

  // OFFLINE NOTES SECTION
  Future<bool> saveForOffline(Note note) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Implementation from OfflineService.saveNoteForOffline
      // ...

      return true;
    } catch (e) {
      print('Error saving note for offline: $e');
      return false;
    }
  }

  // RATING SECTION
  Future<Result<void>> rateNote(
    String noteId,
    int rating,
    String? comment,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return Result.failure('User not authenticated');
      }

      if (rating < 1 || rating > 5) {
        return Result.failure('Rating must be between 1 and 5');
      }

      // Check if user has already rated
      final existingRatingQuery =
          await _firestore
              .collection('notes')
              .doc(noteId)
              .collection('ratings')
              .where('userId', isEqualTo: currentUser.uid)
              .get();

      if (existingRatingQuery.docs.isNotEmpty) {
        return Result.failure('You have already rated this note');
      }

      // Add new rating
      await _firestore
          .collection('notes')
          .doc(noteId)
          .collection('ratings')
          .add({
            'userId': currentUser.uid,
            'rating': rating,
            'comment': comment,
            'timestamp': FieldValue.serverTimestamp(),
            'userEmail': currentUser.email,
          });

      // Recalculate average rating
      await _updateAverageRating(noteId);

      return Result.success(null);
    } catch (e) {
      return Result.failure('Rating failed: ${e.toString()}');
    }
  }

  Future<void> _updateAverageRating(String noteId) async {
    final ratingsQuery =
        await _firestore
            .collection('notes')
            .doc(noteId)
            .collection('ratings')
            .get();

    if (ratingsQuery.docs.isEmpty) return;

    final totalRating = ratingsQuery.docs.fold(
      0.0,
      (sum, doc) => sum + (doc.data()['rating'] as num).toDouble(),
    );

    final averageRating = totalRating / ratingsQuery.docs.length;

    await _firestore.collection('notes').doc(noteId).update({
      'averageRating': averageRating,
      'ratingCount': ratingsQuery.docs.length,
    });
  }

  // ACCESS REQUEST SECTION
  Future<Result<String>> requestAccess(String noteId) async {
    // Implementation from AccessRequestService.requestAccess
    // ...
    return Result.success('request_id');
  }
}
