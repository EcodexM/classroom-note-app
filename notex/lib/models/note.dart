import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String title;
  final String courseId;
  final String ownerEmail;
  final String fileUrl;
  final String fileName;
  final DateTime uploadDate;
  final bool isPublic;
  final int downloads;
  final double averageRating;
  final List<String> tags;

  Note({
    required this.id,
    required this.title,
    required this.courseId,
    required this.ownerEmail,
    required this.fileUrl,
    required this.fileName,
    required this.uploadDate,
    required this.isPublic,
    this.downloads = 0,
    this.averageRating = 0.0,
    this.tags = const [],
  });

  factory Note.fromFirestore(Map<String, dynamic> data, String id) {
    return Note(
      id: id,
      title: data['title'] ?? '',
      courseId: data['courseId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      uploadDate:
          (data['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPublic: data['isPublic'] ?? false,
      downloads: data['downloads'] ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'courseId': courseId,
      'ownerEmail': ownerEmail,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'uploadDate': uploadDate,
      'isPublic': isPublic,
      'downloads': downloads,
      'averageRating': averageRating,
      'tags': tags,
    };
  }
}
