import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notex/models/user_role.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this for environment variable management

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use environment variable to store the Firebase API key
  final String _firebaseApiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';

  /// Sign in with Google via REST (for platforms like Windows desktop)
  Future<UserCredential?> signInWithGoogleAccessToken(
    String accessToken,
  ) async {
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
      await _initializeUser(userCredential.user);
      return userCredential;
    } else {
      print('Google sign-in failed: ${response.body}');
      return null;
    }
  }

  /// Ensure user document exists with a default role
  Future<void> _initializeUser(User? user) async {
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      await docRef.set({
        'email': user.email,
        'name': user.displayName ?? '',
        'role': 'student', // default role
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Improved user registration method
  /// Improved user registration method
  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // First, check if the email is already registered in Firebase Auth
      try {
        // Try to sign in first to see if the account exists
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // If sign-in succeeds, the account already exists
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The account already exists for that email.',
        );
      } on FirebaseAuthException catch (signInError) {
        // If sign-in fails, check if it's because the user doesn't exist
        if (signInError.code != 'wrong-password' &&
            signInError.code != 'user-not-found') {
          // If it's a different error, rethrow
          throw signInError;
        }
      }

      // If we've reached here, the user doesn't exist or the password is wrong
      // Proceed with user creation
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Validate and set the role
        final validRoles = ['student', 'admin', 'teacher'];
        final normalizedRole = validRoles.contains(role) ? role : 'student';

        // Add user to Firestore, overwriting any existing document
        await _firestore.collection('users').doc(user.uid).set(
          {
            'email': user.email,
            'role': normalizedRole,
            'createdAt': FieldValue.serverTimestamp(),
            'displayName': user.displayName ?? email.split('@').first,
          },
          SetOptions(merge: true),
        ); // Use merge to avoid completely overwriting
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth exceptions
      if (e.code == 'email-already-in-use') {
        // Check if there's a user document with this email
        final userQuery =
            await _firestore
                .collection('users')
                .where('email', isEqualTo: email)
                .get();

        if (userQuery.docs.isEmpty) {
          // If no user document exists, attempt to create one
          try {
            final userCredential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );

            final user = userCredential.user;
            if (user != null) {
              // Validate and set the role
              final validRoles = ['student', 'admin', 'teacher'];
              final normalizedRole =
                  validRoles.contains(role) ? role : 'student';

              await _firestore.collection('users').doc(user.uid).set({
                'email': user.email,
                'role': normalizedRole,
                'createdAt': FieldValue.serverTimestamp(),
                'displayName': user.displayName ?? email.split('@').first,
              });

              return userCredential;
            }
          } catch (recreationError) {
            // If recreation fails, rethrow the original error
            rethrow;
          }
        }

        // If a user document exists, rethrow the original error
        rethrow;
      }
      rethrow;
    } catch (e) {
      // Handle any other unexpected errors
      print('Unexpected error during registration: $e');
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
