// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:notex/firebase_service.dart';
// import 'package:notex/home_page.dart';
// import 'package:notex/admin/admin_login.dart';
// import 'package:notex/register.dart';

// class LoginPage extends StatefulWidget {
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   bool isLoading = false;
//   bool rememberMe = false;

//   Future<void> loginWithGoogle() async {
//     setState(() => isLoading = true);
//     try {
//       final googleUser = await GoogleSignIn().signIn();
//       if (googleUser == null) return;

//       final googleAuth = await googleUser.authentication;
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       final userCredential = await FirebaseAuth.instance.signInWithCredential(
//         credential,
//       );
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
//     } catch (e) {
//       print(e);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> login() async {
//     setState(() => isLoading = true);
//     try {
//       await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: emailController.text.trim(),
//         password: passwordController.text.trim(),
//       );
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => HomePage()),
//       );
//     } catch (e) {
//       print(e);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     return Scaffold(
//       backgroundColor: Color(0xFFF2E9E5),
//       body: screenWidth < 800 ? _buildCompactLogin() : _buildWideLogin(),
//     );
//   }

//   Widget _buildWideLogin() {
//     return Row(
//       children: [
//         Expanded(
//           flex: 1,
//           child: Center(
//             child: SingleChildScrollView(
//               padding: EdgeInsets.symmetric(vertical: 50, horizontal: 100),
//               child: ConstrainedBox(
//                 constraints: BoxConstraints(maxWidth: 400),
//                 child: _loginForm(),
//               ),
//             ),
//           ),
//         ),
//         Expanded(
//           flex: 1,
//           child: Stack(
//             children: [
//               Container(
//                 margin: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Color(0xFFF2E9E5),
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//               ),
//               Container(
//                 margin: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(30),
//                   image: DecorationImage(
//                     image: AssetImage('images/login.jpg'),
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildCompactLogin() {
//     return Center(
//       child: SingleChildScrollView(
//         padding: EdgeInsets.all(24),
//         child: ConstrainedBox(
//           constraints: BoxConstraints(maxWidth: 350),
//           child: _loginForm(),
//         ),
//       ),
//     );
//   }

//   Widget _loginForm() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(Icons.book, color: Colors.deepOrange, size: 30),
//             SizedBox(width: 8),
//             Text(
//               'NoteX',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontFamily: 'KoPubBatang',
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 40),
//         Text(
//           'Welcome Back!',
//           style: TextStyle(
//             fontSize: 48,
//             fontFamily: 'KoPubBatang',
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 8),
//         Text(
//           'Ready to be organized?',
//           style: TextStyle(
//             fontSize: 20,
//             color: Colors.grey.shade600,
//             fontFamily: 'KoPubBatang',
//           ),
//         ),
//         SizedBox(height: 30),
//         ElevatedButton.icon(
//           icon: Icon(Icons.g_mobiledata),
//           label: Text(
//             'Continue with Google',
//             style: TextStyle(
//               fontFamily: 'KoPubBatang',
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           onPressed: loginWithGoogle,
//           style: ElevatedButton.styleFrom(
//             minimumSize: Size(double.infinity, 50),
//             backgroundColor: Colors.white,
//             foregroundColor: Colors.black,
//           ),
//         ),
//         SizedBox(height: 20),
//         Row(
//           children: [
//             Expanded(child: Divider()),
//             Padding(
//               padding: EdgeInsets.symmetric(horizontal: 10),
//               child: Text(
//                 'OR',
//                 style: TextStyle(color: Colors.grey, fontFamily: 'KoPubBatang'),
//               ),
//             ),
//             Expanded(child: Divider()),
//           ],
//         ),
//         SizedBox(height: 20),
//         TextField(
//           controller: emailController,
//           decoration: InputDecoration(
//             border: OutlineInputBorder(),
//             labelText: 'Email',
//           ),
//         ),
//         SizedBox(height: 15),
//         TextField(
//           controller: passwordController,
//           obscureText: true,
//           decoration: InputDecoration(
//             border: OutlineInputBorder(),
//             labelText: 'Password',
//           ),
//         ),
//         SizedBox(height: 10),
//         LayoutBuilder(
//           builder: (context, constraints) {
//             bool isNarrow = constraints.maxWidth < 360;

//             if (isNarrow) {
//               // Stack vertically on narrow screens
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Checkbox(
//                         value: rememberMe,
//                         onChanged: (val) {
//                           setState(() => rememberMe = val ?? false);
//                         },
//                       ),
//                       Text(
//                         'Remember me',
//                         style: TextStyle(
//                           fontFamily: 'KoPubBatang',
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: TextButton(
//                       onPressed: () {},
//                       child: Text(
//                         'Forgot Password?',
//                         style: TextStyle(
//                           fontFamily: 'KoPubBatang',
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             } else {
//               // Show in one row for wider screens
//               return Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Row(
//                     children: [
//                       Checkbox(
//                         value: rememberMe,
//                         onChanged: (val) {
//                           setState(() => rememberMe = val ?? false);
//                         },
//                       ),
//                       Text(
//                         'Remember me',
//                         style: TextStyle(
//                           fontFamily: 'KoPubBatang',
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                   TextButton(
//                     onPressed: () {},
//                     child: Text(
//                       'Forgot Password?',
//                       style: TextStyle(
//                         fontFamily: 'KoPubBatang',
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             }
//           },
//         ),

//         SizedBox(height: 30),
//         ElevatedButton(
//           onPressed: login,
//           style: ElevatedButton.styleFrom(
//             minimumSize: Size(double.infinity, 50),
//             backgroundColor: Colors.deepOrange,
//             foregroundColor: Colors.white,
//           ),
//           child:
//               isLoading
//                   ? CircularProgressIndicator(color: Colors.white)
//                   : Text(
//                     'Sign In',
//                     style: TextStyle(
//                       fontFamily: 'KoPubBatang',
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//         ),
//         SizedBox(height: 10),
//         ElevatedButton(
//           onPressed:
//               () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => RegisterPage()),
//               ),
//           style: ElevatedButton.styleFrom(
//             minimumSize: Size(double.infinity, 50),
//             backgroundColor: Colors.white,
//             foregroundColor: Colors.deepOrange,
//           ),
//           child: Text(
//             'Register',
//             style: TextStyle(
//               fontFamily: 'KoPubBatang',
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//         SizedBox(height: 30),
//         Align(
//           alignment: Alignment.bottomLeft,
//           child: TextButton(
//             onPressed:
//                 () => Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => AdminLoginPage()),
//                 ),
//             child: Text(
//               'Are you an administrator?',
//               style: TextStyle(
//                 fontFamily: 'KoPubBatang',
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
