import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notex/models/course.dart';
import 'package:flutter/material.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Course>> getUserCourses() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Get user's enrolled courses
      final enrollmentsQuery =
          await _firestore
              .collection('course_enrollments')
              .where('studentEmail', isEqualTo: currentUser.email)
              .get();

      final enrolledCourseIds =
          enrollmentsQuery.docs
              .map((doc) => doc.data()['courseId'] as String)
              .toList();

      List<Course> courses = [];

      for (var courseId in enrolledCourseIds) {
        final courseDoc =
            await _firestore.collection('courses').doc(courseId).get();

        if (courseDoc.exists) {
          courses.add(Course.fromFirestore(courseDoc.data()!, courseDoc.id));
        }
      }

      return courses;
    } catch (e) {
      print('Error loading courses: $e');
      return [];
    }
  }

  Future<String?> addCourse(String name, String code, String instructor) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Generate search terms
      final searchTerms = [
        name.trim().toLowerCase(),
        code.trim().toLowerCase(),
        instructor.trim().toLowerCase(),
      ];

      // Add course to Firestore
      final courseRef = await _firestore.collection('courses').add({
        'name': name.trim(),
        'code': code.trim(),
        'instructor': instructor.trim(),
        'department': '',
        'noteCount': 0,
        'color':
            '#${(Colors.blue.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'searchTerms': searchTerms,
        'createdBy': currentUser.email ?? 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Enroll the user in the new course
      await _firestore.collection('course_enrollments').add({
        'courseId': courseRef.id,
        'studentEmail': currentUser.email,
        'enrollmentDate': FieldValue.serverTimestamp(),
      });

      return courseRef.id;
    } catch (e) {
      print('Error adding course: $e');
      return null;
    }
  }
}
