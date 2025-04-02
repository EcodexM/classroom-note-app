// lib/admin/institution_management.dart
// NEW FILE: Institution management page
// This implements the institution-specific structure requirement

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InstitutionManagementPage extends StatefulWidget {
  @override
  _InstitutionManagementPageState createState() =>
      _InstitutionManagementPageState();
}

class _InstitutionManagementPageState extends State<InstitutionManagementPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _institutions = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final institutionsQuery =
          await FirebaseFirestore.instance.collection('institutions').get();

      List<Map<String, dynamic>> institutions = [];
      for (var doc in institutionsQuery.docs) {
        institutions.add({
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unknown',
          'location': doc.data()['location'] ?? '',
          'website': doc.data()['website'] ?? '',
          'logo': doc.data()['logo'],
          'courseCount': doc.data()['courseCount'] ?? 0,
          'studentCount': doc.data()['studentCount'] ?? 0,
        });
      }

      setState(() {
        _institutions = institutions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading institutions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _searchInstitutions(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredInstitutions {
    if (_searchQuery.isEmpty) return _institutions;

    return _institutions.where((institution) {
      return institution['name'].toLowerCase().contains(_searchQuery) ||
          institution['location'].toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _addInstitution() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final websiteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Institution'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Institution Name'),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(labelText: 'Location'),
                  ),
                  TextField(
                    controller: websiteController,
                    decoration: InputDecoration(labelText: 'Website URL'),
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
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'website': websiteController.text.trim(),
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
        // Add to Firestore
        final institutionRef = await FirebaseFirestore.instance
            .collection('institutions')
            .add({
              'name': result['name'],
              'location': result['location'],
              'website': result['website'],
              'courseCount': 0,
              'studentCount': 0,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Add to state
        setState(() {
          _institutions.add({
            'id': institutionRef.id,
            'name': result['name'],
            'location': result['location'],
            'website': result['website'],
            'logo': null,
            'courseCount': 0,
            'studentCount': 0,
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Institution added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding institution: $e')));
      }
    }
  }

  Future<void> _editInstitution(Map<String, dynamic> institution) async {
    final nameController = TextEditingController(text: institution['name']);
    final locationController = TextEditingController(
      text: institution['location'],
    );
    final websiteController = TextEditingController(
      text: institution['website'],
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Institution'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Institution Name'),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(labelText: 'Location'),
                  ),
                  TextField(
                    controller: websiteController,
                    decoration: InputDecoration(labelText: 'Website URL'),
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
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'website': websiteController.text.trim(),
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
        // Update in Firestore
        await FirebaseFirestore.instance
            .collection('institutions')
            .doc(institution['id'])
            .update({
              'name': result['name'],
              'location': result['location'],
              'website': result['website'],
            });

        // Update in state
        setState(() {
          final index = _institutions.indexWhere(
            (i) => i['id'] == institution['id'],
          );
          if (index != -1) {
            _institutions[index]['name'] = result['name'];
            _institutions[index]['location'] = result['location'];
            _institutions[index]['website'] = result['website'];
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Institution updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating institution: $e')),
        );
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
                    onChanged: _searchInstitutions,
                    decoration: InputDecoration(
                      hintText: 'Search institutions...',
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
                  onPressed: _addInstitution,
                  icon: Icon(Icons.add),
                  label: Text('Add Institution'),
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
                    : _filteredInstitutions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No institutions found',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first institution to get started',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredInstitutions.length,
                      padding: EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final institution = _filteredInstitutions[index];
                        return _buildInstitutionCard(institution);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionCard(Map<String, dynamic> institution) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      institution['logo'] != null
                          ? Image.network(institution['logo'])
                          : Center(
                            child: Text(
                              institution['name']
                                  .substring(
                                    0,
                                    min(2, institution['name'].length),
                                  )
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        institution['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (institution['location'].isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          institution['location'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                      if (institution['website'].isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          institution['website'],
                          style: TextStyle(
                            color: Colors.blue,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _editInstitution(institution),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Courses', institution['courseCount']),
                _buildStat('Students', institution['studentCount']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red[800],
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
        ),
      ],
    );
  }

  int min(int a, int b) => a < b ? a : b;
}
