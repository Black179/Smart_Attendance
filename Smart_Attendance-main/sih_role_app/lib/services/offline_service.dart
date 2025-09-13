import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/hive_models.dart';

class OfflineService {
  static const String _attendanceBox = 'attendance_box';
  static const String _odRequestBox = 'od_request_box';
  static const String _enrollmentBox = 'enrollment_box';
  
  static late Box<OfflineAttendance> _attendanceBoxInstance;
  static late Box<OfflineODRequest> _odRequestBoxInstance;
  static late Box<OfflineEnrollment> _enrollmentBoxInstance;

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Open boxes
    _attendanceBoxInstance = await Hive.openBox<OfflineAttendance>(_attendanceBox);
    _odRequestBoxInstance = await Hive.openBox<OfflineODRequest>(_odRequestBox);
    _enrollmentBoxInstance = await Hive.openBox<OfflineEnrollment>(_enrollmentBox);
  }

  // Attendance methods
  static Future<void> saveAttendanceOffline({
    required String studentName,
    required String rollNumber,
    required String className,
    required String date,
    required String status,
  }) async {
    final attendance = OfflineAttendance(
      studentName: studentName,
      rollNumber: rollNumber,
      className: className,
      date: date,
      status: status,
      timestamp: DateTime.now(),
    );
    
    await _attendanceBoxInstance.add(attendance);
  }

  static List<OfflineAttendance> getUnsyncedAttendance() {
    return _attendanceBoxInstance.values
        .where((attendance) => !attendance.synced)
        .toList();
  }

  static Future<void> markAttendanceSynced(String key) async {
    final attendance = _attendanceBoxInstance.get(key);
    if (attendance != null) {
      attendance.synced = true;
      await attendance.save();
    }
  }

  // OD Request methods
  static Future<void> saveODRequestOffline({
    required String studentName,
    required String rollNumber,
    required String date,
    required String reason,
    required String fileName,
    required String filePath,
  }) async {
    final odRequest = OfflineODRequest(
      studentName: studentName,
      rollNumber: rollNumber,
      date: date,
      reason: reason,
      fileName: fileName,
      filePath: filePath,
      timestamp: DateTime.now(),
    );
    
    await _odRequestBoxInstance.add(odRequest);
  }

  static List<OfflineODRequest> getUnsyncedODRequests() {
    return _odRequestBoxInstance.values
        .where((request) => !request.synced)
        .toList();
  }

  static Future<void> markODRequestSynced(String key) async {
    final request = _odRequestBoxInstance.get(key);
    if (request != null) {
      request.synced = true;
      await request.save();
    }
  }

  // Enrollment methods
  static Future<void> saveEnrollmentOffline({
    required String studentName,
    required String rollNumber,
    required String className,
    required String faceEmbedding,
    required String faceImagePath,
  }) async {
    final enrollment = OfflineEnrollment(
      studentName: studentName,
      rollNumber: rollNumber,
      className: className,
      faceEmbedding: faceEmbedding,
      faceImagePath: faceImagePath,
      timestamp: DateTime.now(),
    );
    
    await _enrollmentBoxInstance.add(enrollment);
  }

  static List<OfflineEnrollment> getUnsyncedEnrollments() {
    return _enrollmentBoxInstance.values
        .where((enrollment) => !enrollment.synced)
        .toList();
  }

  static Future<void> markEnrollmentSynced(String key) async {
    final enrollment = _enrollmentBoxInstance.get(key);
    if (enrollment != null) {
      enrollment.synced = true;
      await enrollment.save();
    }
  }

  // Sync methods
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  static Future<void> syncAllData() async {
    if (!await isOnline()) return;

    await _syncAttendance();
    await _syncODRequests();
    await _syncEnrollments();
  }

  static Future<void> _syncAttendance() async {
    final unsyncedAttendance = getUnsyncedAttendance();
    
    for (final attendance in unsyncedAttendance) {
      try {
        final response = await http.post(
          Uri.parse('http://localhost:8000/mark_attendance'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(attendance.toJson()),
        );

        if (response.statusCode == 200) {
          await markAttendanceSynced(attendance.key.toString());
        }
      } catch (e) {
        print('Error syncing attendance: $e');
      }
    }
  }

  static Future<void> _syncODRequests() async {
    final unsyncedRequests = getUnsyncedODRequests();
    
    for (final request in unsyncedRequests) {
      try {
        final multipartRequest = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:8000/od_requests'),
        );

        multipartRequest.fields['student_name'] = request.studentName;
        multipartRequest.fields['roll_number'] = request.rollNumber;
        multipartRequest.fields['date'] = request.date;
        multipartRequest.fields['reason'] = request.reason;

        if (request.filePath.isNotEmpty) {
          multipartRequest.files.add(await http.MultipartFile.fromPath(
            'file',
            request.filePath,
            filename: request.fileName,
          ));
        }

        final response = await multipartRequest.send();

        if (response.statusCode == 200) {
          await markODRequestSynced(request.key.toString());
        }
      } catch (e) {
        print('Error syncing OD request: $e');
      }
    }
  }

  static Future<void> _syncEnrollments() async {
    final unsyncedEnrollments = getUnsyncedEnrollments();
    
    for (final enrollment in unsyncedEnrollments) {
      try {
        final response = await http.post(
          Uri.parse('http://localhost:8000/enroll'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(enrollment.toJson()),
        );

        if (response.statusCode == 200) {
          await markEnrollmentSynced(enrollment.key.toString());
        }
      } catch (e) {
        print('Error syncing enrollment: $e');
      }
    }
  }

  // Cleanup methods
  static Future<void> clearSyncedData() async {
    // Remove synced attendance records older than 7 days
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    
    final attendanceToDelete = _attendanceBoxInstance.values
        .where((attendance) => 
            attendance.synced && attendance.timestamp.isBefore(cutoffDate))
        .map((attendance) => attendance.key)
        .toList();
    
    for (final key in attendanceToDelete) {
      await _attendanceBoxInstance.delete(key);
    }
  }

  static int getOfflineDataCount() {
    return _attendanceBoxInstance.values
        .where((attendance) => !attendance.synced)
        .length +
        _odRequestBoxInstance.values
        .where((request) => !request.synced)
        .length +
        _enrollmentBoxInstance.values
        .where((enrollment) => !enrollment.synced)
        .length;
  }
}
