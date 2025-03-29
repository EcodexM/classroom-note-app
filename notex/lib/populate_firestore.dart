// lib/populate_firestore.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_service.dart';

Future<void> main(dynamic DefaultFirebaseOptions) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Example: Add a user
  await FirebaseService.addUser(
    userId: 'user123',
    email: 'user@example.com',
    displayName: 'John Doe',
    profileImage: 'https://example.com/image.jpg',
  );

  // Example: Add a course
  await FirebaseService.addCourse(
    courseId: 'cs101',
    code: 'CS101',
    name: 'Intro to CS',
    department: 'Computer Science',
    instructor: 'Dr. Smith',
    noteCount: 0,
    color: '#4287f5',
    searchTerms: ['cs101', 'intro', 'computer', 'science'],
  );

  print('🔥 Database populated successfully!');
}
