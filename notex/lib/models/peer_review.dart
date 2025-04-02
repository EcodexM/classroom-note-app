class PeerReview {
  final String id;
  final String noteId;
  final String reviewerId;
  final String reviewerEmail;
  final double rating; // 1-5 stars overall
  final double accuracyRating; // 1-5 stars for accuracy
  final double qualityRating; // 1-5 stars for quality
  final double clarityRating; // 1-5 stars for clarity
  final String comment;
  final DateTime reviewDate;
  final bool
  isVerified; // Whether the review is from a verified student/teacher

  PeerReview({
    required this.id,
    required this.noteId,
    required this.reviewerId,
    required this.reviewerEmail,
    required this.rating,
    required this.accuracyRating,
    required this.qualityRating,
    required this.clarityRating,
    required this.comment,
    required this.reviewDate,
    required this.isVerified,
  });

  factory PeerReview.fromFirestore(Map<String, dynamic> data, String id) {
    return PeerReview(
      id: id,
      noteId: data['noteId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reviewerEmail: data['reviewerEmail'] ?? 'Anonymous',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      accuracyRating: (data['accuracyRating'] as num?)?.toDouble() ?? 0.0,
      qualityRating: (data['qualityRating'] as num?)?.toDouble() ?? 0.0,
      clarityRating: (data['clarityRating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] ?? '',
      reviewDate: data['reviewDate']?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'noteId': noteId,
      'reviewerId': reviewerId,
      'reviewerEmail': reviewerEmail,
      'rating': rating,
      'accuracyRating': accuracyRating,
      'qualityRating': qualityRating,
      'clarityRating': clarityRating,
      'comment': comment,
      'reviewDate': reviewDate,
      'isVerified': isVerified,
    };
  }
}
