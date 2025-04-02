// lib/models/content_report.dart
// NEW FILE: Model for content reports
// Used to track and manage reports of inappropriate content

class ContentReport {
  final String id;
  final String noteId;
  final String reporterEmail;
  final String reason;
  final DateTime reportDate;
  final String status; // pending, dismissed, warned, removed

  ContentReport({
    required this.id,
    required this.noteId,
    required this.reporterEmail,
    required this.reason,
    required this.reportDate,
    required this.status,
  });

  factory ContentReport.fromFirestore(Map<String, dynamic> data, String id) {
    return ContentReport(
      id: id,
      noteId: data['noteId'] ?? '',
      reporterEmail: data['reporterEmail'] ?? 'Anonymous',
      reason: data['reason'] ?? 'No reason provided',
      reportDate: data['reportDate']?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'noteId': noteId,
      'reporterEmail': reporterEmail,
      'reason': reason,
      'reportDate': reportDate,
      'status': status,
    };
  }
}
