import 'package:flutter/material.dart';
import 'package:notex/MyNotes/mynotes.dart';
import 'package:notex/public_notes.dart';
import 'package:notex/upload.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Track the currently selected page
  int _selectedIndex = 0;

  // The pages that match our menu options
  static final List<Widget> _widgetOptions = <Widget>[
    MyNotesPage(),
    PublicNotesPage(),
    UploadPage(),
  ];

  // When a menu item is tapped, set the current page and close the drawer
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Closes the drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with a leading menu (hamburger) icon
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(Icons.menu, color: Colors.black),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        centerTitle: true,
        title: Text(
          'NoteX',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // Drawer for navigation
      drawer: Drawer(
        child: Column(
          children: [
            // Optional: Add a styled header
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Center(
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.note),
              title: Text('My Notes'),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: Icon(Icons.public),
              title: Text('Public Notes'),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: Icon(Icons.upload),
              title: Text('Upload'),
              onTap: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
      // Body: Search bar on top, then the selected page's content
      body: Column(
        children: <Widget>[
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          // Display the selected page
          Expanded(child: _widgetOptions.elementAt(_selectedIndex)),
        ],
      ),
    );
  }
}
