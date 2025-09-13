import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class OfflineAttendance extends HiveObject {
  @HiveField(0)
  String studentName;

  @HiveField(1)
  String rollNumber;

  @HiveField(2)
  String className;

  @HiveField(3)
  String date;

  @HiveField(4)
  String status;

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  bool synced;

  OfflineAttendance({
    required this.studentName,
    required this.rollNumber,
    required this.className,
    required this.date,
    required this.status,
    required this.timestamp,
    this.synced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_name': studentName,
      'roll_number': rollNumber,
      'class_name': className,
      'date': date,
      'status': status,
    };
  }
}

@HiveType(typeId: 1)
class OfflineODRequest extends HiveObject {
  @HiveField(0)
  String studentName;

  @HiveField(1)
  String rollNumber;

  @HiveField(2)
  String date;

  @HiveField(3)
  String reason;

  @HiveField(4)
  String fileName;

  @HiveField(5)
  String filePath;

  @HiveField(6)
  DateTime timestamp;

  @HiveField(7)
  bool synced;

  OfflineODRequest({
    required this.studentName,
    required this.rollNumber,
    required this.date,
    required this.reason,
    required this.fileName,
    required this.filePath,
    required this.timestamp,
    this.synced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_name': studentName,
      'roll_number': rollNumber,
      'date': date,
      'reason': reason,
      'file_name': fileName,
    };
  }
}

@HiveType(typeId: 2)
class OfflineEnrollment extends HiveObject {
  @HiveField(0)
  String studentName;

  @HiveField(1)
  String rollNumber;

  @HiveField(2)
  String className;

  @HiveField(3)
  String faceEmbedding;

  @HiveField(4)
  String faceImagePath;

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  bool synced;

  OfflineEnrollment({
    required this.studentName,
    required this.rollNumber,
    required this.className,
    required this.faceEmbedding,
    required this.faceImagePath,
    required this.timestamp,
    this.synced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'student_name': studentName,
      'roll_number': rollNumber,
      'class_name': className,
      'face_embedding': faceEmbedding,
    };
  }
}
