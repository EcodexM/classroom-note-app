import 'package:flutter/material.dart';
import 'package:notex/models/note.dart';
import 'package:notex/services/notemgn.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final Function(Note) onTap;
  final bool showOfflineButton;

  const NoteCard({
    Key? key,
    required this.note,
    required this.onTap,
    this.showOfflineButton = true,
  }) : super(key: key);

  @override
  _NoteCardState createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  final NoteService _noteService = NoteService();
  bool _isAvailableOffline = false;
  bool _isCheckingOffline = true;

  @override
  void initState() {
    super.initState();
    if (widget.showOfflineButton) {
      _checkOfflineStatus();
    } else {
      _isCheckingOffline = false;
    }
  }

  Future<void> _checkOfflineStatus() async {
    // Check offline status implementation
    // ...
    setState(() {
      _isCheckingOffline = false;
    });
  }

  Color _getPastelColor(String seed) {
    // Get pastel color implementation
    // ...
    return Colors.blue[50]!;
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor = _getPastelColor(widget.note.courseId);

    return GestureDetector(
      onTap: () => widget.onTap(widget.note),
      child: Card(
        color: cardColor,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.note.title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 16),
                  SizedBox(width: 4),
                  Text(
                    widget.note.averageRating.toStringAsFixed(1),
                    style: TextStyle(fontSize: 12),
                  ),
                  Spacer(),
                  if (widget.showOfflineButton && !_isCheckingOffline)
                    Icon(
                      _isAvailableOffline
                          ? Icons.offline_pin
                          : Icons.offline_bolt,
                      color: _isAvailableOffline ? Colors.green : Colors.grey,
                      size: 16,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
