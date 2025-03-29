import 'package:flutter/material.dart';

class NotificationsPopup extends StatelessWidget {
  final VoidCallback onClose;

  NotificationsPopup({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            ListTile(
              title: Text('New notes available'),
              subtitle: Text(
                'Sorting Algorithms notes for CS 201 are now available',
              ),
              trailing: Text('2h', style: TextStyle(color: Colors.grey)),
            ),
            Divider(height: 1),
            ListTile(
              title: Text('Your note was downloaded'),
              subtitle: Text(
                'Your Calculus notes have been downloaded 5 more times',
              ),
              trailing: Text('1d', style: TextStyle(color: Colors.grey)),
            ),
            Divider(height: 1),
            TextButton(
              child: Text('See all notifications'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notifications feature coming soon')),
                );
                onClose();
              },
            ),
          ],
        ),
      ),
    );
  }
}
