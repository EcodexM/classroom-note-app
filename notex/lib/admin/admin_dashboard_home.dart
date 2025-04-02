import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminDashboardHome extends StatefulWidget {
  @override
  _AdminDashboardHomeState createState() => _AdminDashboardHomeState();
}

class _AdminDashboardHomeState extends State<AdminDashboardHome> {
  int _totalUsers = 0;
  int _totalCourses = 0;
  int _totalNotes = 0;
  int _totalInstitutions = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;
  Map<String, int> _notesPerDay = {};
  Map<String, int> _usersPerDay = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get counts
      final usersCount =
          await FirebaseFirestore.instance.collection('users').count().get();
      final coursesCount =
          await FirebaseFirestore.instance.collection('courses').count().get();
      final notesCount =
          await FirebaseFirestore.instance.collection('notes').count().get();
      final institutionsCount =
          await FirebaseFirestore.instance
              .collection('institutions')
              .count()
              .get();

      // Get recent activities (downloads, uploads, registrations)
      final recentDownloads =
          await FirebaseFirestore.instance
              .collection('downloads')
              .orderBy('downloadedAt', descending: true)
              .limit(5)
              .get();

      final recentUploads =
          await FirebaseFirestore.instance
              .collection('notes')
              .orderBy('uploadDate', descending: true)
              .limit(5)
              .get();

      final recentUsers =
          await FirebaseFirestore.instance
              .collection('users')
              .orderBy('enrollmentDate', descending: true)
              .limit(5)
              .get();

      // Combine activities
      List<Map<String, dynamic>> activities = [];

      for (var doc in recentDownloads.docs) {
        activities.add({
          'type': 'download',
          'userEmail': doc.data()['userEmail'] ?? 'Unknown',
          'timestamp': doc.data()['downloadedAt']?.toDate() ?? DateTime.now(),
          'noteId': doc.data()['noteId'] ?? '',
        });
      }

      for (var doc in recentUploads.docs) {
        activities.add({
          'type': 'upload',
          'userEmail': doc.data()['ownerEmail'] ?? 'Unknown',
          'timestamp': doc.data()['uploadDate']?.toDate() ?? DateTime.now(),
          'title': doc.data()['title'] ?? 'Untitled Note',
        });
      }

      for (var doc in recentUsers.docs) {
        activities.add({
          'type': 'registration',
          'userEmail': doc.data()['email'] ?? 'Unknown',
          'timestamp': doc.data()['enrollmentDate']?.toDate() ?? DateTime.now(),
        });
      }

      // Sort by timestamp
      activities.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      activities = activities.take(10).toList();

      // Get notes per day (last 7 days)
      Map<String, int> notesPerDay = {};
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('MM/dd').format(date);
        notesPerDay[dateStr] = 0;
      }

      final lastWeekNotesQuery =
          await FirebaseFirestore.instance
              .collection('notes')
              .where(
                'uploadDate',
                isGreaterThan: now.subtract(Duration(days: 7)),
              )
              .get();

      for (var doc in lastWeekNotesQuery.docs) {
        final uploadDate = (doc.data()['uploadDate'] as Timestamp).toDate();
        final dateStr = DateFormat('MM/dd').format(uploadDate);
        notesPerDay[dateStr] = (notesPerDay[dateStr] ?? 0) + 1;
      }

      // Get users per day (last 7 days)
      Map<String, int> usersPerDay = {};
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('MM/dd').format(date);
        usersPerDay[dateStr] = 0;
      }

      final lastWeekUsersQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where(
                'enrollmentDate',
                isGreaterThan: now.subtract(Duration(days: 7)),
              )
              .get();

      for (var doc in lastWeekUsersQuery.docs) {
        final enrollmentDate =
            (doc.data()['enrollmentDate'] as Timestamp).toDate();
        final dateStr = DateFormat('MM/dd').format(enrollmentDate);
        usersPerDay[dateStr] = (usersPerDay[dateStr] ?? 0) + 1;
      }

      setState(() {
        _totalUsers = usersCount.count ?? 0;
        _totalCourses = coursesCount.count ?? 0;
        _totalNotes = notesCount.count ?? 0;
        _totalInstitutions = institutionsCount.count ?? 0;
        _recentActivities = activities;
        _notesPerDay = notesPerDay;
        _usersPerDay = usersPerDay;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 16),

              // Stats cards
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard(
                    'Total Users',
                    _totalUsers,
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Total Notes',
                    _totalNotes,
                    Icons.note,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Total Courses',
                    _totalCourses,
                    Icons.school,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Institutions',
                    _totalInstitutions,
                    Icons.business,
                    Colors.purple,
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Charts section
              Text(
                'Activity Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 16),

              // Notes uploaded chart
              Container(
                height: 200,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes Uploaded (Last 7 Days)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY:
                              _notesPerDay.values.isEmpty
                                  ? 10
                                  : (_notesPerDay.values.reduce(
                                        (a, b) => a > b ? a : b,
                                      ) *
                                      1.2),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() <
                                          _notesPerDay.keys.length) {
                                    return Text(
                                      _notesPerDay.keys.elementAt(
                                        value.toInt(),
                                      ),
                                      style: TextStyle(fontSize: 10),
                                    );
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(
                            _notesPerDay.length,
                            (index) => BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY:
                                      _notesPerDay.values
                                          .elementAt(index)
                                          .toDouble(),
                                  color: Colors.green,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // New users chart
              Container(
                height: 200,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Users (Last 7 Days)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY:
                              _usersPerDay.values.isEmpty
                                  ? 10
                                  : (_usersPerDay.values.reduce(
                                        (a, b) => a > b ? a : b,
                                      ) *
                                      1.2),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() <
                                          _usersPerDay.keys.length) {
                                    return Text(
                                      _usersPerDay.keys.elementAt(
                                        value.toInt(),
                                      ),
                                      style: TextStyle(fontSize: 10),
                                    );
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(
                            _usersPerDay.length,
                            (index) => BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY:
                                      _usersPerDay.values
                                          .elementAt(index)
                                          .toDouble(),
                                  color: Colors.blue,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Recent activities
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 16),

              _recentActivities.isEmpty
                  ? Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No recent activities',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _recentActivities.length,
                    itemBuilder: (context, index) {
                      final activity = _recentActivities[index];
                      return _buildActivityItem(activity);
                    },
                  ),
            ],
          ),
        );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 30),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    IconData icon;
    Color color;
    String title;

    switch (activity['type']) {
      case 'download':
        icon = Icons.download;
        color = Colors.blue;
        title = '${activity['userEmail']} downloaded a note';
        break;
      case 'upload':
        icon = Icons.upload;
        color = Colors.green;
        title = '${activity['userEmail']} uploaded "${activity['title']}"';
        break;
      case 'registration':
        icon = Icons.person_add;
        color = Colors.purple;
        title = '${activity['userEmail']} joined NoteX';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        title = 'Unknown activity';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        subtitle: Text(
          DateFormat('MMM dd, yyyy - hh:mm a').format(activity['timestamp']),
          style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
        ),
      ),
    );
  }
}
