// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:notex/firebase_service.dart';
// import 'package:notex/home_page.dart';
// import 'package:notex/login.dart';

// class RegisterPage extends StatefulWidget {
//   @override
//   _RegisterPageState createState() => _RegisterPageState();
// }

// class _RegisterPageState extends State<RegisterPage>
//     with SingleTickerProviderStateMixin {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController confirmPasswordController =
//       TextEditingController();

//   bool isLoading = false;

//   late AnimationController _animationController;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _fadeAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _animationController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 600),
//     );

//     _slideAnimation = Tween<Offset>(
//       begin: Offset(0.2, 0), // subtle slide like a note
//       end: Offset.zero,
//     ).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
//     );

//     _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
//     );

//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     emailController.dispose();
//     passwordController.dispose();
//     confirmPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> register() async {
//     if (passwordController.text != confirmPasswordController.text) {
//       _showError('Passwords do not match');
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final userCredential = await FirebaseAuth.instance
//           .createUserWithEmailAndPassword(
//             email: emailController.text.trim(),
//             password: passwordController.text.trim(),
//           );

//       final user = userCredential.user;
//       if (user != null) {
//         await FirebaseService.addUser(
//           userId: user.uid,
//           email: user.email ?? '',
//           displayName: user.displayName,
//           profileImage: user.photoURL,
//         );
//       }

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => HomePage()),
//       );
//     } on FirebaseAuthException catch (e) {
//       _showError(e.message ?? 'An unknown error occurred');
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   void _showError(String message) {
//     showDialog(
//       context: context,
//       builder:
//           (_) => AlertDialog(
//             title: Text('Error'),
//             content: Text(message),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('OK'),
//               ),
//             ],
//           ),
//     );
//   }

//   Widget _buildTextField({
//     required String label,
//     required TextEditingController controller,
//     bool obscure = false,
//   }) {
//     return TextField(
//       controller: controller,
//       obscureText: obscure,
//       style: TextStyle(color: Color(0xFF333333)),
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: TextStyle(
//           color: Color(0xFF6B4EFF),
//           fontFamily: 'KoPubBatang',
//         ),
//         filled: true,
//         fillColor: Colors.white,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: BorderSide(color: Color(0xFF6B4EFF), width: 2),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFF6B4EFF), width: 2),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isWide = MediaQuery.of(context).size.width > 800;

//     return Scaffold(
//       backgroundColor: Color(0xFFF2E9E5),
//       body: Row(
//         children: [
//           Expanded(
//             flex: 1,
//             child: SlideTransition(
//               position: _slideAnimation,
//               child: FadeTransition(
//                 opacity: _fadeAnimation,
//                 child: Center(
//                   child: SingleChildScrollView(
//                     padding: EdgeInsets.symmetric(horizontal: 48, vertical: 30),
//                     child: ConstrainedBox(
//                       constraints: BoxConstraints(maxWidth: 400),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.edit_note,
//                             size: 40,
//                             color: Colors.deepOrange,
//                           ),
//                           SizedBox(height: 20),
//                           Text(
//                             'Create your NoteX account',
//                             style: TextStyle(
//                               fontSize: 28,
//                               fontWeight: FontWeight.bold,
//                               fontFamily: 'KoPubBatang',
//                             ),
//                           ),
//                           SizedBox(height: 10),
//                           Text(
//                             'Start sharing and exploring notes with your peers.',
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                               fontSize: 14,
//                               fontFamily: 'KoPubBatang',
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                           SizedBox(height: 24),
//                           _buildTextField(
//                             label: 'Email',
//                             controller: emailController,
//                           ),
//                           SizedBox(height: 16),
//                           _buildTextField(
//                             label: 'Password',
//                             controller: passwordController,
//                             obscure: true,
//                           ),
//                           SizedBox(height: 16),
//                           _buildTextField(
//                             label: 'Confirm Password',
//                             controller: confirmPasswordController,
//                             obscure: true,
//                           ),
//                           SizedBox(height: 30),
//                           ElevatedButton(
//                             onPressed: isLoading ? null : register,
//                             child:
//                                 isLoading
//                                     ? CircularProgressIndicator(
//                                       color: Colors.white,
//                                       strokeWidth: 2,
//                                     )
//                                     : Text(
//                                       'Register',
//                                       style: TextStyle(
//                                         fontFamily: 'KoPubBatang',
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.deepOrange,
//                               foregroundColor: Colors.white,
//                               minimumSize: Size(double.infinity, 50),
//                             ),
//                           ),
//                           SizedBox(height: 20),
//                           GestureDetector(
//                             onTap: () {
//                               Navigator.pushReplacement(
//                                 context,
//                                 PageRouteBuilder(
//                                   transitionDuration: Duration(
//                                     milliseconds: 500,
//                                   ),
//                                   transitionsBuilder: (
//                                     context,
//                                     animation,
//                                     _,
//                                     child,
//                                   ) {
//                                     final offset = Tween<Offset>(
//                                       begin: Offset(-0.2, 0),
//                                       end: Offset.zero,
//                                     ).animate(animation);
//                                     final fade = Tween<double>(
//                                       begin: 0,
//                                       end: 1,
//                                     ).animate(animation);

//                                     return SlideTransition(
//                                       position: offset,
//                                       child: FadeTransition(
//                                         opacity: fade,
//                                         child: child,
//                                       ),
//                                     );
//                                   },
//                                   pageBuilder: (context, _, __) => LoginPage(),
//                                 ),
//                               );
//                             },
//                             child: Text(
//                               'Already have an account? Sign In',
//                               style: TextStyle(
//                                 color: Colors.deepPurple,
//                                 fontWeight: FontWeight.w600,
//                                 fontFamily: 'KoPubBatang',
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           if (isWide)
//             Expanded(
//               flex: 1,
//               child: Container(
//                 margin: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Color(0xFFFBE4DF),
//                   borderRadius: BorderRadius.circular(30),
//                   image: DecorationImage(
//                     image: AssetImage('images/login.jpg'),
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
