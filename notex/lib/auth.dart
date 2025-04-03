import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:notex/admin/admin_dashboard_home.dart';
import 'package:notex/firebase_service.dart';
import 'package:notex/home_page.dart';
import 'package:notex/services/auth_service.dart';
import 'package:notex/admin/admin_dashboard_home.dart'; // Import your admin dashboard page

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _loginButtonFocusNode = FocusNode();

  bool isLoading = false;
  bool rememberMe = false;
  bool isLogin = true; // Controls which form is showing
  bool isAdminLogin = false;

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
        reverseCurve: Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(1.5, 0),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _loginButtonFocusNode.dispose();

    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (isLogin) {
      login();
    } else {
      register(isAdminLogin ? 'admin' : 'student');
    }
  }

  // Toggle between login and register forms with animation
  void _toggleForm() async {
    if (isLogin) {
      // Switching to register
      await _animationController.forward();
      setState(() {
        isLogin = false;
      });
      await _animationController.reverse();
    } else {
      // Switching to login
      await _animationController.forward();
      setState(() {
        isLogin = true;
      });
      await _animationController.reverse();
    }
  }

  Future<void> loginWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
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
          displayName: user.email?.split('@').first,
          profileImage: user.photoURL,
          role: 'student',
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

  Future<void> login() async {
    setState(() => isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );
      final user = userCredential.user;

      if (user != null) {
        // Retrieve the user's role from Firestore to determine the correct dashboard
        String? userRole = await FirebaseService.getUserRole(
          user.uid,
        ); // Ensure this method is correctly implemented in FirebaseService

        if (isAdminLogin && userRole == 'admin') {
          // Redirect to the Admin Dashboard if the user is an admin and is logging in from the admin page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AdminDashboardHome()),
          );
        } else if (!isAdminLogin && userRole == 'student') {
          // Redirect to the Student Dashboard if the user is a student and is logging from the student page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(),
            ), // Ensure you have a StudentDashboard page
          );
        } else {
          // If the role doesn't match the login type or the role is undefined, show an error
          FirebaseAuth.instance
              .signOut(); // Optionally sign out the user to force a re-login
          _showError(
            "Access Denied: You are not authorized to access this section.",
          );
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> register(String role) async {
    // Added role parameter to specify the user's role at registration
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
        // Assign role during registration
        await FirebaseService.addUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          profileImage: user.photoURL,
          role: role, // Pass the role to the addUser function
        );

        // Redirect users to the appropriate dashboard based on the role
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardHome(),
            ), // Redirect to the Admin Dashboard
          );
        } else if (role == 'student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(),
            ), // Redirect to the Student Dashboard
          );
        } else {
          _showError("Invalid role specified. Registration failed.");
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'An unknown error occurred');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      focusNode: focusNode,
      textInputAction: textInputAction ?? TextInputAction.next,
      onSubmitted: (_) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        } else {
          onSubmitted?.call();
        }
      },
      style: TextStyle(color: Color(0xFF333333)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color:
              isLogin
                  ? const Color.fromARGB(255, 17, 17, 16)
                  : Color.fromARGB(255, 20, 20, 20),
          fontFamily: 'KoPubBatang',
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color:
                isLogin
                    ? Color.fromARGB(255, 17, 17, 16)
                    : Color.fromARGB(255, 20, 20, 20),
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color:
                isLogin
                    ? Color.fromARGB(255, 17, 17, 16)
                    : Color.fromARGB(255, 20, 20, 20),
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF2E9E5),
      body: screenWidth < 800 ? _buildCompactAuth() : _buildWideAuth(),
    );
  }

  Widget _buildWideAuth() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: 50, horizontal: 100),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _opacityAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: isLogin ? _loginForm() : _registerForm(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Stack(
            children: [
              Container(
                margin: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFF2E9E5),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              Container(
                margin: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  image: DecorationImage(
                    image: AssetImage('images/login.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAuth() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 350),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _opacityAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: isLogin ? _loginForm() : _registerForm(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.book,
              color: const Color.fromARGB(255, 63, 62, 61),
              size: 30,
            ),
            SizedBox(width: 8),
            Text(
              'NoteX',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'KoPubBatang',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 40),
        Text(
          'Welcome ${isAdminLogin ? 'Administrator' : 'Back'}!',
          style: TextStyle(
            fontSize: 48,
            fontFamily: 'KoPubBatang',
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          isAdminLogin
              ? 'Create. Organize. Educate.'
              : 'Ready to be organized?',
          style: TextStyle(
            fontSize: 20,
            color: Colors.grey.shade600,
            fontFamily: 'KoPubBatang',
          ),
        ),
        SizedBox(height: 30),
        ElevatedButton.icon(
          icon: Icon(Icons.g_mobiledata),
          label: Text(
            'Continue with Google',
            style: TextStyle(
              fontFamily: 'KoPubBatang',
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: loginWithGoogle,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 50),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'OR',
                style: TextStyle(color: Colors.grey, fontFamily: 'KoPubBatang'),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        SizedBox(height: 20),
        _buildTextField(
          label: 'Email',
          controller: emailController,
          focusNode: _emailFocusNode,
          nextFocusNode: _passwordFocusNode,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: 15),
        _buildTextField(
          label: 'Password',
          controller: passwordController,
          obscure: true,
          focusNode: _passwordFocusNode,
          nextFocusNode: _loginButtonFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: _handleSubmit,
        ),
        SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            bool isNarrow = constraints.maxWidth < 360;

            if (isNarrow) {
              // Stack vertically on narrow screens
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: (val) {
                          setState(() => rememberMe = val ?? false);
                        },
                      ),
                      Text(
                        'Remember me',
                        style: TextStyle(
                          fontFamily: 'KoPubBatang',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontFamily: 'KoPubBatang',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Show in one row for wider screens
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: (val) {
                          setState(() => rememberMe = val ?? false);
                        },
                      ),
                      Text(
                        'Remember me',
                        style: TextStyle(
                          fontFamily: 'KoPubBatang',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontFamily: 'KoPubBatang',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
        SizedBox(height: 30),
        ElevatedButton(
          focusNode: _loginButtonFocusNode,
          onPressed: isLoading ? null : login,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 50),
            backgroundColor: const Color.fromARGB(255, 63, 62, 61),
            foregroundColor: Colors.white,
          ),
          child:
              isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                    'Sign In',
                    style: TextStyle(
                      fontFamily: 'KoPubBatang',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                fontFamily: 'KoPubBatang',
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: _toggleForm,
              child: Text(
                'Register',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'KoPubBatang',
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 80),
        Align(
          alignment: Alignment.bottomLeft,
          child: TextButton(
            onPressed: () {
              setState(() {
                isAdminLogin = !isAdminLogin;
              });
            },
            child: Text(
              isAdminLogin ? 'Are you a student?' : 'Are you an administrator?',
              style: TextStyle(
                fontFamily: 'KoPubBatang',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _registerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.edit_note,
          size: 40,
          color: const Color.fromARGB(255, 70, 70, 70),
        ),
        SizedBox(height: 50),
        Text(
          'Create your NoteX account.',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.bold,
            fontFamily: 'KoPubBatang',
          ),
        ),
        SizedBox(height: 10),
        Text(
          isAdminLogin
              ? 'Create. Organize. Educate.'
              : 'Start sharing and exploring notes with your peers.',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 18,
            fontFamily: 'KoPubBatang',
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),
        _buildTextField(
          label: 'Email',
          controller: emailController,
          focusNode: _emailFocusNode,
          nextFocusNode: _passwordFocusNode,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: 16),
        _buildTextField(
          label: 'Password',
          controller: passwordController,
          obscure: true,
          focusNode: _passwordFocusNode,
          nextFocusNode: _confirmPasswordFocusNode,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: 16),
        _buildTextField(
          label: 'Confirm Password',
          controller: confirmPasswordController,
          obscure: true,
          focusNode: _confirmPasswordFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: _handleSubmit,
        ),
        SizedBox(height: 30),
        ElevatedButton(
          focusNode: _loginButtonFocusNode,
          onPressed:
              isLoading
                  ? null
                  : () => register(isAdminLogin ? 'admin' : 'student'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 70, 70, 70),
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 50),
          ),
          child:
              isLoading
                  ? CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                  : Text(
                    'Register',
                    style: TextStyle(
                      fontFamily: 'KoPubBatang',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(fontFamily: 'KoPubBatang'),
            ),
            GestureDetector(
              onTap: _toggleForm,
              child: Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'KoPubBatang',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
