import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/models/user_role.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this for environment variable management
import 'package:notex/firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use environment variable to store the Firebase API key
  final String _firebaseApiKey =
      dotenv.env['FIREBASE_API_KEY'] ?? firebaseOptions.apiKey;

  /// Sign in with Google via REST (for platforms like Windows desktop)
  Future<UserCredential?> signInWithGoogleAccessToken(
    String accessToken, {
    String role = 'student',
  }) async {
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$_firebaseApiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'postBody': 'access_token=$accessToken&providerId=google.com',
        'requestUri': 'http://localhost',
        'returnSecureToken': true,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final idToken = data['idToken'];

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _initializeUser(userCredential.user, role: role);
      return userCredential;
    } else {
      print('Google sign-in failed: ${response.body}');
      return null;
    }
  }

  /// Ensure user document exists with a default role
  Future<void> _initializeUser(User? user, {String role = 'student'}) async {
    if (user == null) return;

    print("Initializing user document for UID: ${user.uid} with role: $role");

    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    // Set a timestamp for when the document was created or last accessed
    final timestamp = FieldValue.serverTimestamp();
    final displayName = user.displayName ?? user.email?.split('@').first ?? '';

    // If document exists, update lastLogin
    if (docSnap.exists) {
      print("User document exists, updating lastLogin");
      await docRef.update({
        'lastLogin': timestamp,
        // Only update role if it's different
        if (docSnap.data()?['role'] != role) 'role': role,
      });
    } else {
      // If document doesn't exist, create it with full user data
      print("Creating new user document with role: $role");
      await docRef.set({
        'email': user.email,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'role': role,
        'createdAt': timestamp,
        'lastLogin': timestamp,
      });
    }

    // Verify document was created/updated
    final verifySnap = await docRef.get();
    if (verifySnap.exists) {
      print("User document verification: Success");
      print("Document data: ${verifySnap.data()}");
    } else {
      print("WARNING: User document verification failed");
    }
  }

  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      print("Starting registration for email: $email with role: $role");

      // First, check if the email is already registered in Firebase Auth
      try {
        // Try to sign in first to see if the account exists
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // If sign-in succeeds, the account already exists
        print("Account already exists for email: $email");
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The account already exists for that email.',
        );
      } on FirebaseAuthException catch (signInError) {
        // If sign-in fails, check if it's because the user doesn't exist
        if (signInError.code != 'wrong-password' &&
            signInError.code != 'user-not-found') {
          // If it's a different error, rethrow
          print(
            "Error during auth check: ${signInError.code} - ${signInError.message}",
          );
          throw signInError;
        }

        if (signInError.code == 'wrong-password') {
          print("Account exists but password is incorrect");
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'The account already exists for that email.',
          );
        }

        // If we reach here, the user doesn't exist, which is what we want for registration
        print("Account doesn't exist, proceeding with registration");
      }

      // Validate role before creating account
      final validRoles = ['student', 'admin', 'teacher'];
      final normalizedRole = validRoles.contains(role) ? role : 'student';
      print("Using normalized role: $normalizedRole");

      // Create a new user account
      print("Creating new user account");
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        print("User created successfully with UID: ${user.uid}");

        // Create the user document in Firestore
        print("Creating user document in Firestore");
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? email.split('@').first,
          'role': normalizedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        // Verify the document was created
        final docSnapshot =
            await _firestore.collection('users').doc(user.uid).get();
        if (docSnapshot.exists) {
          print(
            "User document created successfully with role: ${docSnapshot.data()?['role']}",
          );
        } else {
          print("WARNING: User document was not created successfully");
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth exceptions
      print("Firebase Auth Exception: ${e.code} - ${e.message}");
      rethrow; // Rethrow to be handled by the UI
    } catch (e) {
      // Handle any other unexpected errors
      print("Unexpected error during registration: $e");
      rethrow;
    }
  }

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    return _isCurrentUserRole('admin');
  }

  /// Check if current user is teacher
  Future<bool> isCurrentUserTeacher() async {
    return _isCurrentUserRole('teacher');
  }

  /// Generic role check
  Future<bool> _isCurrentUserRole(String role) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    return userDoc.exists && userDoc.data()?['role'] == role;
  }

  /// Get current user role
  Future<UserRole> getCurrentUserRole() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return UserRole.student;

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists) return UserRole.student;

    final String roleStr = userDoc.data()?['role'] ?? 'student';
    return UserRole.values.firstWhere(
      (r) => r.toString().split('.').last == roleStr,
      orElse: () => UserRole.student,
    );
  }

  /// Set user role manually (admin use)
  Future<void> setUserRole(String userId, UserRole role) async {
    await _firestore.collection('users').doc(userId).update({
      'role': role.toString().split('.').last,
    });
  }
}
