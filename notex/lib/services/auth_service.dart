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
