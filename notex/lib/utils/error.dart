import 'package:flutter/material.dart';

class ErrorHandler {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  static String getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please try logging in.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'invalid-email':
        return 'The email address is invalid.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
