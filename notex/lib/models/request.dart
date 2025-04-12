import 'package:cloud_firestore/cloud_firestore.dart';

class AccessRequest {
  final String id;
  final String noteId;
  final String noteTitle;
  final String ownerEmail;
  final String requesterEmail;
  final DateTime requestDate;
  final String status; // 'pending', 'approved', 'denied', 'cancelled'
  final String? message;

  AccessRequest({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.ownerEmail,
    required this.requesterEmail,
    required this.requestDate,
    required this.status,
    this.message,
  });

  factory AccessRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return AccessRequest(
      id: id,
      noteId: data['noteId'] ?? '',
      noteTitle: data['noteTitle'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      requesterEmail: data['requesterEmail'] ?? '',
      requestDate:
          (data['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      message: data['message'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'noteId': noteId,
      'noteTitle': noteTitle,
      'ownerEmail': ownerEmail,
      'requesterEmail': requesterEmail,
      'requestDate': requestDate,
      'status': status,
      'message': message,
    };
  }
}
