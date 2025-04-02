import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:notex/models/peer_review.dart';

class PeerReviewScreen extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  final String courseId;
  final String courseCode;

  PeerReviewScreen({
    required this.noteId,
    required this.noteTitle,
    required this.courseId,
    required this.courseCode,
  });

  @override
  _PeerReviewScreenState createState() => _PeerReviewScreenState();
}

class _PeerReviewScreenState extends State<PeerReviewScreen> {
  double _overallRating = 0;
  double _accuracyRating = 0;
  double _qualityRating = 0;
  double _clarityRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  bool _userHasReviewed = false;
  List<PeerReview> _existingReviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check if the user has already reviewed this note
      final userReviewQuery =
          await FirebaseFirestore.instance
              .collection('peer_reviews')
              .where('noteId', isEqualTo: widget.noteId)
              .where('reviewerId', isEqualTo: currentUser.uid)
              .get();

      if (userReviewQuery.docs.isNotEmpty) {
        final review = PeerReview.fromFirestore(
          userReviewQuery.docs.first.data(),
          userReviewQuery.docs.first.id,
        );

        setState(() {
          _userHasReviewed = true;
          _overallRating = review.rating;
          _accuracyRating = review.accuracyRating;
          _qualityRating = review.qualityRating;
          _clarityRating = review.clarityRating;
          _commentController.text = review.comment;
        });
      }

      // Get all reviews for this note
      final reviewsQuery =
          await FirebaseFirestore.instance
              .collection('peer_reviews')
              .where('noteId', isEqualTo: widget.noteId)
              .orderBy('reviewDate', descending: true)
              .get();

      List<PeerReview> reviews = [];
      for (var doc in reviewsQuery.docs) {
        reviews.add(PeerReview.fromFirestore(doc.data(), doc.id));
      }

      setState(() {
        _existingReviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_overallRating == 0 ||
        _accuracyRating == 0 ||
        _qualityRating == 0 ||
        _clarityRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide ratings in all categories')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check if user is enrolled in the course (for verified status)
      final enrollmentQuery =
          await FirebaseFirestore.instance
              .collection('course_enrollments')
              .where('courseId', isEqualTo: widget.courseId)
              .where('studentEmail', isEqualTo: currentUser.email)
              .limit(1)
              .get();

      final isVerified = enrollmentQuery.docs.isNotEmpty;

      // Check if user has already reviewed
      final existingReviewQuery =
          await FirebaseFirestore.instance
              .collection('peer_reviews')
              .where('noteId', isEqualTo: widget.noteId)
              .where('reviewerId', isEqualTo: currentUser.uid)
              .get();

      if (existingReviewQuery.docs.isNotEmpty) {
        // Update existing review
        await FirebaseFirestore.instance
            .collection('peer_reviews')
            .doc(existingReviewQuery.docs.first.id)
            .update({
              'rating': _overallRating,
              'accuracyRating': _accuracyRating,
              'qualityRating': _qualityRating,
              'clarityRating': _clarityRating,
              'comment': _commentController.text.trim(),
              'reviewDate': FieldValue.serverTimestamp(),
              'isVerified': isVerified,
            });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Your review has been updated')));
      } else {
        // Add new review
        await FirebaseFirestore.instance.collection('peer_reviews').add({
          'noteId': widget.noteId,
          'reviewerId': currentUser.uid,
          'reviewerEmail': currentUser.email,
          'rating': _overallRating,
          'accuracyRating': _accuracyRating,
          'qualityRating': _qualityRating,
          'clarityRating': _clarityRating,
          'comment': _commentController.text.trim(),
          'reviewDate': FieldValue.serverTimestamp(),
          'isVerified': isVerified,
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Thank you for your review!')));
      }

      // Update average ratings in the note document
      final allReviewsQuery =
          await FirebaseFirestore.instance
              .collection('peer_reviews')
              .where('noteId', isEqualTo: widget.noteId)
              .get();

      if (allReviewsQuery.docs.isNotEmpty) {
        double totalRating = 0;
        double totalAccuracy = 0;
        double totalQuality = 0;
        double totalClarity = 0;
        int count = allReviewsQuery.docs.length;

        for (var doc in allReviewsQuery.docs) {
          totalRating += (doc.data()['rating'] as num).toDouble();
          totalAccuracy += (doc.data()['accuracyRating'] as num).toDouble();
          totalQuality += (doc.data()['qualityRating'] as num).toDouble();
          totalClarity += (doc.data()['clarityRating'] as num).toDouble();
        }

        await FirebaseFirestore.instance
            .collection('notes')
            .doc(widget.noteId)
            .update({
              'averageRating': totalRating / count,
              'averageAccuracy': totalAccuracy / count,
              'averageQuality': totalQuality / count,
              'averageClarity': totalClarity / count,
              'reviewCount': count,
            });
      }

      // Refresh reviews
      _loadReviews();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Peer Review', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.deepPurple,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.noteTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      'Course: ${widget.courseCode}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 24),

                    // Review form
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userHasReviewed
                                  ? 'Update Your Review'
                                  : 'Add Your Review',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 16),

                            // Overall Rating
                            Text(
                              'Overall Rating',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                return IconButton(
                                  icon: Icon(
                                    index < _overallRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _overallRating = index + 1;
                                    });
                                  },
                                );
                              }),
                            ),

                            // Accuracy Rating
                            Text(
                              'Accuracy',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              'How accurate and factually correct is the content?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                return IconButton(
                                  icon: Icon(
                                    index < _accuracyRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _accuracyRating = index + 1;
                                    });
                                  },
                                );
                              }),
                            ),

                            // Quality Rating
                            Text(
                              'Quality',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              'How well-written and comprehensive is the content?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                return IconButton(
                                  icon: Icon(
                                    index < _qualityRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _qualityRating = index + 1;
                                    });
                                  },
                                );
                              }),
                            ),

                            // Clarity Rating
                            Text(
                              'Clarity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              'How clear and easy to understand is the content?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                return IconButton(
                                  icon: Icon(
                                    index < _clarityRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _clarityRating = index + 1;
                                    });
                                  },
                                );
                              }),
                            ),

                            SizedBox(height: 16),

                            // Comment
                            TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                labelText: 'Comment (optional)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),

                            SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitReview,
                                child: Text(
                                  _userHasReviewed
                                      ? 'Update Review'
                                      : 'Submit Review',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Existing reviews
                    Text(
                      'Peer Reviews (${_existingReviews.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 8),

                    _existingReviews.isEmpty
                        ? Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No reviews yet. Be the first to review!',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _existingReviews.length,
                          itemBuilder: (context, index) {
                            return _buildReviewCard(_existingReviews[index]);
                          },
                        ),
                  ],
                ),
              ),
    );
  }

  Widget _buildReviewCard(PeerReview review) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isUserReview =
        currentUser != null && review.reviewerId == currentUser.uid;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      isUserReview ? 'Your Review' : review.reviewerEmail,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (review.isVerified) ...[
                      SizedBox(width: 4),
                      Tooltip(
                        message: 'Verified Student/Teacher',
                        child: Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(review.reviewDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  '${review.rating.toStringAsFixed(1)} Overall',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                _buildMiniRating('Accuracy', review.accuracyRating),
                SizedBox(width: 16),
                _buildMiniRating('Quality', review.qualityRating),
                SizedBox(width: 16),
                _buildMiniRating('Clarity', review.clarityRating),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(review.comment, style: TextStyle(fontFamily: 'Poppins')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniRating(String label, double rating) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontFamily: 'Poppins',
          ),
        ),
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
}
