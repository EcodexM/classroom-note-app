import 'package:flutter/material.dart';
import 'package:notex/MyNotes/mynotes.dart';
import 'package:notex/public_notes.dart';
import 'package:notex/MyNotes/shared_with_me.dart';
import 'package:notex/upload.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  static final List<Widget> _widgetOptions = <Widget>[
    MyNotesPage(),
    PublicNotesPage(),
    UploadPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: 'Search...',
            suffixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Welcome to NoteX',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _widgetOptions.elementAt(_selectedIndex)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'My Notes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.public),
            label: 'Public Notes',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'Upload'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
      ),
    );
  }
}
