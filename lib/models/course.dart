class Course {
  final String id;
  final String code;
  final String name;
  final String department;
  final int noteCount;
  final String color;
  final bool isEnrolled;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.noteCount,
    required this.color,
    this.isEnrolled = false,
  });

  // Convert a Firebase document to a Course object
  factory Course.fromFirestore(Map<String, dynamic> data, String id) {
    return Course(
      id: id,
      code: data['code'] ?? '',
      name: data['name'] ?? '',
      department: data['department'] ?? '',
      noteCount: data['noteCount'] ?? 0,
      color: data['color'] ?? '#3F51B5',
      isEnrolled: data['isEnrolled'] ?? false,
    );
  }

  // Convert a Course object to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'department': department,
      'noteCount': noteCount,
      'color': color,
      'isEnrolled': isEnrolled,
    };
  }
}
