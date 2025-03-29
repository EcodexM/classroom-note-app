import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:notex/login.dart';
import 'package:notex/home_page.dart';
import 'package:notex/firebase_service.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;

  Future<void> register() async {
    if (passwordController.text != confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final user = userCredential.user;
      if (user != null) {
        await FirebaseService.addUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          profileImage: user.photoURL,
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'An unknown error occurred');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> signUpWithGoogle() async {
    setState(() => isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() => isLoading = false);
        return; // user canceled
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user != null) {
        await FirebaseService.addUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          profileImage: user.photoURL,
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: Color(0xFF333333),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon
                Icon(Icons.person_add_alt, size: 48, color: Colors.white),
                SizedBox(height: 24),

                // Title
                Text(
                  'Create your NoteX account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Start sharing and exploring notes with your peers.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),

                // Google button
                ElevatedButton.icon(
                  onPressed: isLoading ? null : signUpWithGoogle,
                  icon: Icon(Icons.login, color: Colors.black87),
                  label: Text(
                    'Continue With Google',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    disabledForegroundColor: Colors.grey[700],
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // OR Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[700])),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or sign up with email',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[700])),
                  ],
                ),
                SizedBox(height: 16),

                _buildField(
                  controller: emailController,
                  hint: "Email",
                  icon: Icons.email,
                ),
                SizedBox(height: 16),
                _buildField(
                  controller: passwordController,
                  hint: "Password",
                  icon: Icons.lock,
                  obscure: true,
                ),
                SizedBox(height: 16),
                _buildField(
                  controller: confirmPasswordController,
                  hint: "Confirm Password",
                  icon: Icons.lock_outline,
                  obscure: true,
                ),
                SizedBox(height: 24),

                // Register Button
                ElevatedButton(
                  onPressed: isLoading ? null : register,
                  child:
                      isLoading
                          ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                          : Text('Register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                GestureDetector(
                  onTap:
                      () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => LoginPage()),
                      ),
                  child: Text(
                    'Already have an account? Sign in',
                    style: TextStyle(
                      color: Colors.deepPurple[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
