import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:notex/login.dart';
import 'package:notex/home_page.dart';
import 'package:notex/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteX',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Poppins',
      ),
      home: LoginPage(),
    );
  }
}
