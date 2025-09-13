import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> with TickerProviderStateMixin {
  final _classController = TextEditingController();
  final _dateController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;
  
  List<AttendanceRecord> _attendanceRecords = [];
  List<ODRequest> _odRequests = [];
  List<AnalyticsData> _analyticsData = [];
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _classController.dispose();
    _dateController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchClassAttendance() async {
    if (_classController.text.isEmpty || _dateController.text.isEmpty) {
      _showStatus('Please fill class name and date', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/class_attendance?class_name=${_classController.text}&on=${_dateController.text}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _attendanceRecords = (data['records'] as List)
              .map((record) => AttendanceRecord.fromJson(record))
              .toList();
        });
        _showStatus('Attendance data loaded successfully!', Colors.green);
      } else {
        _showStatus('Error: ${response.body}', Colors.red);
      }
    } catch (e) {
      _showStatus('Network error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAttendanceStatus(AttendanceRecord record, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:8000/attendance/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_name': record.studentName,
          'class_name': record.className,
          'date': record.date,
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          record.status = newStatus;
        });
        _showStatus('Attendance updated successfully!', Colors.green);
      } else {
        _showStatus('Error updating attendance: ${response.body}', Colors.red);
      }
    } catch (e) {
      _showStatus('Network error: $e', Colors.red);
    }
  }

  Future<void> _fetchODRequests() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/od_requests'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _odRequests = (data['requests'] as List)
              .map((request) => ODRequest.fromJson(request))
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching OD requests: $e');
    }
  }

  Future<void> _updateODRequestStatus(int requestId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:8000/od_requests/$requestId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _odRequests.removeWhere((req) => req.id == requestId);
        });
        _showStatus('OD request $status successfully!', Colors.green);
      } else {
        _showStatus('Error updating OD request: ${response.body}', Colors.red);
      }
    } catch (e) {
      _showStatus('Network error: $e', Colors.red);
    }
  }

  void _showStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  List<AttendanceRecord> get _presentStudents => 
      _attendanceRecords.where((record) => record.status == 'present').toList();
  
  List<AttendanceRecord> get _absentStudents => 
      _attendanceRecords.where((record) => record.status == 'absent').toList();
  
  List<AttendanceRecord> get _pendingStudents => 
      _attendanceRecords.where((record) => record.status == 'pending').toList();

  Future<void> _fetchAnalytics() async {
    if (_classController.text.isEmpty) {
      _showStatus('Please enter class name', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://localhost:8000/analytics/class/${_classController.text}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _analyticsData = (data['analytics'] as List)
              .map((item) => AnalyticsData.fromJson(item))
              .toList();
        });
        _showStatus('Analytics loaded successfully', Colors.green);
      } else {
        _showStatus('Error loading analytics', Colors.red);
      }
    } catch (e) {
      _showStatus('Network error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Attendance'),
            Tab(icon: Icon(Icons.description), text: 'OD Requests'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildODRequestsTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _classController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        _dateController.text = date.toIso8601String().split('T')[0];
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _fetchClassAttendance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Load Attendance'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Attendance Sections
          if (_attendanceRecords.isNotEmpty) ...[
            _buildAttendanceSection('Present Students', _presentStudents, Colors.green),
            const SizedBox(height: 16),
            _buildAttendanceSection('Absent Students', _absentStudents, Colors.red),
            const SizedBox(height: 16),
            _buildAttendanceSection('Pending Students', _pendingStudents, Colors.orange),
          ],
          
          // Status Message
          if (_statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                border: Border.all(color: _statusColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(String title, List<AttendanceRecord> records, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title (${records.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Text('No students in this category')
            else
              ...records.map((record) => _buildStudentCard(record, color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(AttendanceRecord record, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(record.studentName),
        subtitle: Text('Date: ${record.date}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (record.status != 'present')
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => _updateAttendanceStatus(record, 'present'),
                tooltip: 'Mark Present',
              ),
            if (record.status != 'absent')
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _updateAttendanceStatus(record, 'absent'),
                tooltip: 'Mark Absent',
              ),
          ],
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            record.status == 'present' ? Icons.check : 
            record.status == 'absent' ? Icons.close : Icons.pending,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildODRequestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'OD Requests Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _fetchODRequests,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Refresh OD Requests'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_odRequests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text('No OD requests found'),
                ),
              ),
            )
          else
            ..._odRequests.map((request) => _buildODRequestCard(request)),
          
          // Status Message
          if (_statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                border: Border.all(color: _statusColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildODRequestCard(ODRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.studentName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(request.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Roll Number: ${request.rollNumber}'),
            Text('Date: ${request.date}'),
            Text('Reason: ${request.reason}'),
            if (request.fileName.isNotEmpty)
              Text('Attachment: ${request.fileName}'),
            const SizedBox(height: 12),
            if (request.status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateODRequestStatus(request.id, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateODRequestStatus(request.id, 'rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Analytics Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _classController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _fetchAnalytics,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Load Analytics'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Analytics Charts
          if (_analyticsData.isNotEmpty) ...[
            _buildAttendanceChart(),
            const SizedBox(height: 16),
            _buildTopDefaultersList(),
          ] else if (_classController.text.isNotEmpty) ...[
            const Center(
              child: Text(
                'No analytics data available for this class',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ] else ...[
            const Center(
              child: Text(
                'Enter a class name to view analytics',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: _getAttendancePieChartData(),
                  centerSpaceRadius: 60,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getAttendancePieChartData() {
    final totalStudents = _analyticsData.length;
    final excellentStudents = _analyticsData.where((s) => s.attendancePercentage >= 90).length;
    final goodStudents = _analyticsData.where((s) => s.attendancePercentage >= 75 && s.attendancePercentage < 90).length;
    final poorStudents = _analyticsData.where((s) => s.attendancePercentage < 75).length;

    return [
      PieChartSectionData(
        color: Colors.green,
        value: excellentStudents.toDouble(),
        title: 'Excellent\n($excellentStudents)',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: goodStudents.toDouble(),
        title: 'Good\n($goodStudents)',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: poorStudents.toDouble(),
        title: 'Poor\n($poorStudents)',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(Colors.green, 'Excellent (90%+)'),
        _buildLegendItem(Colors.orange, 'Good (75-89%)'),
        _buildLegendItem(Colors.red, 'Poor (<75%)'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTopDefaultersList() {
    final defaulters = _analyticsData
        .where((s) => s.attendancePercentage < 75)
        .toList()
      ..sort((a, b) => a.attendancePercentage.compareTo(b.attendancePercentage));

    if (defaulters.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.celebration, size: 48, color: Colors.green),
              const SizedBox(height: 8),
              const Text(
                'No Defaulters!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const Text('All students have good attendance'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Defaulters (Lowest Attendance)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...defaulters.take(5).map((student) => _buildDefaulterCard(student)),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaulterCard(AnalyticsData student) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: student.attendancePercentage < 50 ? Colors.red[50] : Colors.orange[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: student.attendancePercentage < 50 ? Colors.red : Colors.orange,
          child: Text(
            student.attendancePercentage.toStringAsFixed(0),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(student.studentName),
        subtitle: Text('Roll: ${student.rollNumber}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${student.attendancePercentage.toStringAsFixed(1)}%'),
            Text('${student.presentDays}/${student.totalDays} days'),
          ],
        ),
      ),
    );
  }
}

class AttendanceRecord {
  final String studentName;
  final String className;
  final String date;
  String status;

  AttendanceRecord({
    required this.studentName,
    required this.className,
    required this.date,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      studentName: json['student_name'],
      className: json['class_name'],
      date: json['date'],
      status: json['status'],
    );
  }
}

class ODRequest {
  final int id;
  final String studentName;
  final String rollNumber;
  final String date;
  final String reason;
  final String fileName;
  final String status;

  ODRequest({
    required this.id,
    required this.studentName,
    required this.rollNumber,
    required this.date,
    required this.reason,
    required this.fileName,
    required this.status,
  });

  factory ODRequest.fromJson(Map<String, dynamic> json) {
    return ODRequest(
      id: json['id'],
      studentName: json['student_name'],
      rollNumber: json['roll_number'],
      date: json['date'],
      reason: json['reason'],
      fileName: json['file_name'] ?? '',
      status: json['status'],
    );
  }
}

class AnalyticsData {
  final String studentName;
  final String rollNumber;
  final double attendancePercentage;
  final int totalDays;
  final int presentDays;
  final int absentDays;

  AnalyticsData({
    required this.studentName,
    required this.rollNumber,
    required this.attendancePercentage,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      studentName: json['student_name'],
      rollNumber: json['roll_number'],
      attendancePercentage: json['attendance_percentage'].toDouble(),
      totalDays: json['total_days'],
      presentDays: json['present_days'],
      absentDays: json['absent_days'],
    );
  }
}
