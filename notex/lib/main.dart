import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:notex/auth.dart';
import 'package:notex/firebase_options.dart';
import 'package:notex/services/offline_service.dart';
import 'package:notex/auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the correct options
  await Firebase.initializeApp(options: firebaseOptions);

  // Initialize offline service
  final offlineService = OfflineService();
  await offlineService.initialize();

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
      home: AuthPage(),
    );
  }
}
