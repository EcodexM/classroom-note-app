import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingSummaryWidget extends StatefulWidget {
  final String noteId;

  RatingSummaryWidget({required this.noteId});

  @override
  _RatingSummaryWidgetState createState() => _RatingSummaryWidgetState();
}

class _RatingSummaryWidgetState extends State<RatingSummaryWidget> {
  bool _isLoading = true;
  double _averageRating = 0.0;
  double _averageAccuracy = 0.0;
  double _averageQuality = 0.0;
  double _averageClarity = 0.0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    try {
      final noteDoc =
          await FirebaseFirestore.instance
              .collection('notes')
              .doc(widget.noteId)
              .get();

      if (noteDoc.exists) {
        setState(() {
          _averageRating =
              (noteDoc.data()?['averageRating'] as num?)?.toDouble() ?? 0.0;
          _averageAccuracy =
              (noteDoc.data()?['averageAccuracy'] as num?)?.toDouble() ?? 0.0;
          _averageQuality =
              (noteDoc.data()?['averageQuality'] as num?)?.toDouble() ?? 0.0;
          _averageClarity =
              (noteDoc.data()?['averageClarity'] as num?)?.toDouble() ?? 0.0;
          _reviewCount = (noteDoc.data()?['reviewCount'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading ratings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_reviewCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Text(
            'No reviews yet',
            style: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      _averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                Text(
                  '$_reviewCount ${_reviewCount == 1 ? 'review' : 'reviews'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildRatingBar('Accuracy', _averageAccuracy),
            SizedBox(height: 4),
            _buildRatingBar('Quality', _averageQuality),
            SizedBox(height: 4),
            _buildRatingBar('Clarity', _averageClarity),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double rating) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: rating / 5,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getRatingColor(rating),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.amber;
    if (rating >= 2) return Colors.orange;
    return Colors.red;
  }
}
