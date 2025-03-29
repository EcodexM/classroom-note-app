import 'package:flutter/material.dart';

class PublicNotesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.public, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Public Notes',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Find and download notes from other students'),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.search),
            label: Text('Browse Notes'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Browse functionality coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}
