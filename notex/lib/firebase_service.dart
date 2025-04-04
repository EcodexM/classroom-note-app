import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// USERS ///
  static Future<bool> addUser({
    required String userId,
    required String email,
    String? displayName,
    String? profileImage,
    String role = 'student',
  }) async {
    try {
      print("Starting addUser process for userId: $userId, email: $email");

      final docRef = _db.collection('users').doc(userId);

      // First check if document exists
      print("Checking if user document already exists");
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        print("User document doesn't exist, creating new document");

        // Create username from email or displayName
        final String username =
            displayName != null && displayName.isNotEmpty
                ? displayName
                : email.split('@').first;

        // Define user data
        final userData = {
          'email': email,
          'displayName': username,
          'profileImage': profileImage ?? '',
          'role': role,
          'enrollmentDate': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        print("Setting user document with data: $userData");

        // Try to create the document
        await docRef.set(userData);
        print("User document successfully created in Firestore");
        return true;
      } else {
        print("User document exists, checking if role needs updating");

        // Check if role needs to be updated
        final data = docSnap.data();
        if (data != null &&
            (!data.containsKey('role') || data['role'] != role)) {
          print("Updating user role to: $role");
          await docRef.update({
            'role': role,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
          print(
            "User document exists with correct role, updating lastLogin timestamp",
          );
          await docRef.update({'lastLogin': FieldValue.serverTimestamp()});
        }

        print("User document successfully updated");
        return true;
      }
    } catch (e) {
      print("ERROR in addUser: $e");

      // Try to get more detailed error information
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");

        // Check for permission issues
        if (e.code == 'permission-denied') {
          print("PERMISSION DENIED: Check your Firestore security rules");
        }

        // Check for offline issues
        if (e.code == 'unavailable') {
          print("NETWORK ERROR: Device may be offline");
        }
      }

      // Re-throw to let calling code handle it if needed
      return false;
    }
  }

  /// COURSES ///
  static Future<void> addCourse({
    required String courseId,
    required String code,
    required String name,
    required String department,
    required String instructor,
    required int noteCount,
    required String color,
    required List<String> searchTerms,
  }) async {
    await _db.collection('courses').doc(courseId).set({
      'code': code,
      'name': name,
      'department': department,
      'instructor': instructor,
      'noteCount': noteCount,
      'color': color,
      'searchTerms': searchTerms,
    });
  }

  /// COURSE ENROLLMENTS ///
  static Future<void> enrollCourse({
    required String enrollmentId,
    required String courseId,
    required String studentEmail,
  }) async {
    await _db.collection('course_enrollments').doc(enrollmentId).set({
      'courseId': courseId,
      'studentEmail': studentEmail,
      'enrollmentDate': FieldValue.serverTimestamp(),
    });
  }

  /// NOTES ///
  static Future<void> addNote({
    required String noteId,
    required String title,
    required String courseId,
    required String ownerEmail,
    required String fileUrl,
    required String fileName,
    required bool isPublic,
    required List<String> tags,
    required List<String> searchTerms,
  }) async {
    await _db.collection('notes').doc(noteId).set({
      'title': title,
      'courseId': courseId,
      'ownerEmail': ownerEmail,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'uploadDate': FieldValue.serverTimestamp(),
      'isPublic': isPublic,
      'downloads': 0,
      'averageRating': 0,
      'tags': tags,
      'searchTerms': searchTerms,
    });
  }

  static Future<String?> getUserRole(String userId) async {
    DocumentSnapshot userDoc = await _db.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('role')) {
        return data['role'];
      }
    }
    return null; // Or handle as unauthenticated or unauthorized
  }

  /// Add Ratings subcollection under Note
  static Future<void> rateNote({
    required String noteId,
    required String userId,
    required int rating,
    required String userEmail,
  }) async {
    await _db
        .collection('notes')
        .doc(noteId)
        .collection('ratings')
        .doc(userId)
        .set({
          'rating': rating,
          'userEmail': userEmail,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  /// Add Comments subcollection under Note
  static Future<void> commentOnNote({
    required String noteId,
    required String commentId,
    required String authorEmail,
    required String text,
  }) async {
    await _db
        .collection('notes')
        .doc(noteId)
        .collection('comments')
        .doc(commentId)
        .set({
          'authorEmail': authorEmail,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  /// SHARED NOTES ///
  static Future<void> shareNote({
    required String sharedNoteId,
    required String recipient,
    required String noteTitle,
    required String fileUrl,
    required String sender,
  }) async {
    await _db.collection('shared_notes').doc(sharedNoteId).set({
      'recipient': recipient,
      'noteTitle': noteTitle,
      'fileUrl': fileUrl,
      'sender': sender,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  /// COURSE ANNOUNCEMENTS ///
  static Future<void> addCourseAnnouncement({
    required String announcementId,
    required String courseId,
    required String title,
    required String message,
  }) async {
    await _db.collection('course_announcements').doc(announcementId).set({
      'courseId': courseId,
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// COURSE UPDATES ///
  static Future<void> addCourseUpdate({
    required String updateId,
    required String courseId,
    required String message,
  }) async {
    await _db.collection('course_updates').doc(updateId).set({
      'courseId': courseId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  /// FILE UPLOAD ///
  static Future<String?> uploadNoteFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      final ref = FirebaseStorage.instance.ref('notes/$fileName');
      await ref.putData(fileBytes);
      return await ref.getDownloadURL();
    }
    return null;
  }
}
