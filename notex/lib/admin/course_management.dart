// lib/admin/course_management.dart
// NEW FILE: Course management page for admin dashboard
// Lists all courses and allows admins to edit and create courses

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CourseManagementPage extends StatefulWidget {
  @override
  _CourseManagementPageState createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _courses = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final coursesQuery =
          await FirebaseFirestore.instance.collection('courses').get();

      List<Map<String, dynamic>> courses = [];
      for (var doc in coursesQuery.docs) {
        courses.add({
          'id': doc.id,
          'code': doc.data()['code'] ?? 'Unknown',
          'name': doc.data()['name'] ?? 'Unknown Course',
          'department': doc.data()['department'] ?? '',
          'instructor': doc.data()['instructor'] ?? 'Unknown',
          'noteCount': doc.data()['noteCount'] ?? 0,
          'color': doc.data()['color'] ?? '#3F51B5',
          'institutionId': doc.data()['institutionId'], // Optional
        });
      }

      // Sort by department and code
      courses.sort((a, b) {
        final deptCompare = a['department'].compareTo(b['department']);
        if (deptCompare != 0) return deptCompare;
        return a['code'].compareTo(b['code']);
      });

      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading courses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _searchCourses(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredCourses {
    if (_searchQuery.isEmpty) return _courses;

    return _courses.where((course) {
      return course['code'].toLowerCase().contains(_searchQuery) ||
          course['name'].toLowerCase().contains(_searchQuery) ||
          course['department'].toLowerCase().contains(_searchQuery) ||
          course['instructor'].toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _editCourse(Map<String, dynamic> course) async {
    final codeController = TextEditingController(text: course['code']);
    final nameController = TextEditingController(text: course['name']);
    final departmentController = TextEditingController(
      text: course['department'],
    );
    final instructorController = TextEditingController(
      text: course['instructor'],
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Course'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(labelText: 'Course Code'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Course Name'),
                  ),
                  TextField(
                    controller: departmentController,
                    decoration: InputDecoration(labelText: 'Department'),
                  ),
                  TextField(
                    controller: instructorController,
                    decoration: InputDecoration(labelText: 'Instructor'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'code': codeController.text.trim(),
                    'name': nameController.text.trim(),
                    'department': departmentController.text.trim(),
                    'instructor': instructorController.text.trim(),
                  });
                },
                child: Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        // Calculate search terms
        final searchTerms = [
          result['code'].toLowerCase(),
          result['name'].toLowerCase(),
          result['department'].toLowerCase(),
          result['instructor'].toLowerCase(),
        ];

        // Update in Firestore
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(course['id'])
            .update({
              'code': result['code'],
              'name': result['name'],
              'department': result['department'],
              'instructor': result['instructor'],
              'searchTerms': searchTerms,
            });

        // Update in state
        setState(() {
          final index = _courses.indexWhere((c) => c['id'] == course['id']);
          if (index != -1) {
            _courses[index]['code'] = result['code'];
            _courses[index]['name'] = result['name'];
            _courses[index]['department'] = result['department'];
            _courses[index]['instructor'] = result['instructor'];
          }
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Course updated successfully')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating course: $e')));
      }
    }
  }

  Future<void> _addNewCourse() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final departmentController = TextEditingController();
    final instructorController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Course'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(labelText: 'Course Code'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Course Name'),
                  ),
                  TextField(
                    controller: departmentController,
                    decoration: InputDecoration(labelText: 'Department'),
                  ),
                  TextField(
                    controller: instructorController,
                    decoration: InputDecoration(labelText: 'Instructor'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'code': codeController.text.trim(),
                    'name': nameController.text.trim(),
                    'department': departmentController.text.trim(),
                    'instructor': instructorController.text.trim(),
                  });
                },
                child: Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        // Calculate search terms
        final searchTerms = [
          result['code'].toLowerCase(),
          result['name'].toLowerCase(),
          result['department'].toLowerCase(),
          result['instructor'].toLowerCase(),
        ];

        // Add to Firestore
        final courseRef = await FirebaseFirestore.instance
            .collection('courses')
            .add({
              'code': result['code'],
              'name': result['name'],
              'department': result['department'],
              'instructor': result['instructor'],
              'noteCount': 0,
              'color':
                  '#${(Colors.blue.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
              'searchTerms': searchTerms,
            });

        // Add to state
        setState(() {
          _courses.add({
            'id': courseRef.id,
            'code': result['code'],
            'name': result['name'],
            'department': result['department'],
            'instructor': result['instructor'],
            'noteCount': 0,
            'color': '#3F51B5',
            'institutionId': null,
          });

          // Re-sort
          _courses.sort((a, b) {
            final deptCompare = a['department'].compareTo(b['department']);
            if (deptCompare != 0) return deptCompare;
            return a['code'].compareTo(b['code']);
          });
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Course added successfully')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding course: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _searchCourses,
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _addNewCourse,
                  icon: Icon(Icons.add),
                  label: Text('Add Course'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredCourses.isEmpty
                    ? Center(
                      child: Text(
                        'No courses found',
                        style: TextStyle(fontSize: 18, fontFamily: 'Poppins'),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredCourses.length,
                      padding: EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final course = _filteredCourses[index];
                        return _buildCourseCard(course);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final color = Color(int.parse(course['color'].replaceAll('#', '0xFF')));

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            course['code'].substring(0, min(2, course['code'].length)),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${course['code']} - ${course['name']}',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Department: ${course['department']}',
              style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            ),
            Text(
              'Instructor: ${course['instructor']}',
              style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
            ),
            SizedBox(height: 4),
            Text(
              '${course['noteCount']} notes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit, color: Colors.grey[600]),
          onPressed: () => _editCourse(course),
        ),
        onTap: () => _editCourse(course),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}
