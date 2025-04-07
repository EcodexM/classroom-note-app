import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:notex/auth.dart';
import 'package:notex/firebase_options.dart';
import 'package:notex/services/offline_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "keys.env");
  } catch (e) {
    print('Error loading keys.env file: $e');
  }
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 0, 0),
        ),
        fontFamily: 'Poppins',
      ),
      home: AuthPage(),
    );
  }
}
