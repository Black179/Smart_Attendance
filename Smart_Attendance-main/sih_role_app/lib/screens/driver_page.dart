import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  // BLE Scanner variables
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  bool _isBluetoothOn = false;
  Timer? _scanTimer;
  
  // Student data collection
  Map<String, StudentBLEData> _collectedStudents = {};
  List<StudentBLEData> _studentList = [];
  
  // UI state
  bool _isLoading = false;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;
  bool _isOnline = true;
  
  // Offline storage
  static const String _offlineDataKey = 'driver_ble_data';

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    _loadOfflineData();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    try {
      _adapterState = await FlutterBluePlus.adapterState.first;
      setState(() {
        _isBluetoothOn = _adapterState == BluetoothAdapterState.on;
      });
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }

  Future<void> _loadOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineData = prefs.getString(_offlineDataKey);
      if (offlineData != null) {
        final List<dynamic> dataList = jsonDecode(offlineData);
        setState(() {
          _collectedStudents = {};
          for (var data in dataList) {
            final studentData = StudentBLEData.fromJson(data);
            _collectedStudents[studentData.rollNumber] = studentData;
          }
          _updateStudentList();
        });
        _showStatus('Loaded ${_collectedStudents.length} offline records', Colors.blue);
      }
    } catch (e) {
      print('Error loading offline data: $e');
    }
  }

  Future<void> _saveOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataList = _collectedStudents.values.map((e) => e.toJson()).toList();
      await prefs.setString(_offlineDataKey, jsonEncode(dataList));
    } catch (e) {
      print('Error saving offline data: $e');
    }
  }

  void _startBLEScanning() {
    if (!_isBluetoothOn) {
      _showStatus('Bluetooth is not enabled', Colors.red);
      return;
    }

    setState(() {
      _isScanning = true;
    });

    // Start scanning for BLE devices
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 0));
    
    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        _processScanResult(result);
      }
    });

    _showStatus('BLE scanning started', Colors.green);
  }

  void _stopBLEScanning() {
    FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
    });
    _showStatus('BLE scanning stopped', Colors.orange);
  }

  void _processScanResult(ScanResult result) {
    try {
      // Look for student roll number in advertisement data
      final advertisementData = result.advertisementData;
      final serviceData = advertisementData.serviceData;
      
      // Check if this is a student device (simulated for demo)
      // In real implementation, you would check for specific service UUIDs
      if (result.device.platformName.isNotEmpty) {
        final deviceName = result.device.platformName;
        
        // Simulate extracting roll number from device name or service data
        // For demo, we'll use a pattern like "Student_12345"
        if (deviceName.startsWith('Student_') || deviceName.contains('Roll')) {
          final rollNumber = _extractRollNumber(deviceName);
          if (rollNumber.isNotEmpty) {
            _addStudentData(rollNumber, result);
          }
        }
      }
    } catch (e) {
      print('Error processing scan result: $e');
    }
  }

  String _extractRollNumber(String deviceName) {
    // Extract roll number from device name
    // This is a demo implementation - in real scenario, you'd parse BLE service data
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(deviceName);
    return match?.group(1) ?? '';
  }

  void _addStudentData(String rollNumber, ScanResult result) {
    final now = DateTime.now();
    final studentData = StudentBLEData(
      rollNumber: rollNumber,
      deviceName: result.device.platformName,
      deviceId: result.device.remoteId.toString(),
      timestamp: now,
      rssi: result.rssi,
      isOnline: _isOnline,
    );

    setState(() {
      _collectedStudents[rollNumber] = studentData;
      _updateStudentList();
    });

    // Save to offline storage
    _saveOfflineData();
    
    _showStatus('Student $rollNumber detected', Colors.green);
  }

  void _updateStudentList() {
    _studentList = _collectedStudents.values.toList();
    _studentList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _syncToBackend() async {
    if (_collectedStudents.isEmpty) {
      _showStatus('No student data to sync', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final syncData = {
        'driver_id': 'DRIVER_001', // In real app, this would be actual driver ID
        'bus_route': 'Route_A', // In real app, this would be actual route
        'timestamp': DateTime.now().toIso8601String(),
        'students': _collectedStudents.values.map((e) => e.toJson()).toList(),
      };

      final response = await http.post(
        Uri.parse('http://localhost:8000/bus_sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(syncData),
      );

      if (response.statusCode == 200) {
        // Clear offline data after successful sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_offlineDataKey);
        
        setState(() {
          _collectedStudents.clear();
          _studentList.clear();
        });
        
        _showStatus('Data synced successfully! ${_collectedStudents.length} students', Colors.green);
      } else {
        _showStatus('Sync failed: ${response.body}', Colors.red);
      }
    } catch (e) {
      _showStatus('Network error: $e', Colors.red);
      setState(() {
        _isOnline = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearCollectedData() {
    setState(() {
      _collectedStudents.clear();
      _studentList.clear();
    });
    _saveOfflineData();
    _showStatus('Collected data cleared', Colors.orange);
  }

  void _showStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver BLE Scanner'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
            onPressed: _isScanning ? _stopBLEScanning : _startBLEScanning,
            tooltip: _isScanning ? 'Stop Scanning' : 'Start Scanning',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status and Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bluetooth: ${_isBluetoothOn ? "ON" : "OFF"}',
                            style: TextStyle(
                              color: _isBluetoothOn ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Scanning: ${_isScanning ? "ACTIVE" : "STOPPED"}'),
                          Text('Students Detected: ${_collectedStudents.length}'),
                          Text('Connection: ${_isOnline ? "ONLINE" : "OFFLINE"}'),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _syncToBackend,
                          icon: _isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync),
                          label: const Text('Sync'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _clearCollectedData,
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_statusMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      border: Border.all(color: _statusColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          
          // Student List
          Expanded(
            child: _studentList.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No students detected yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start scanning to detect student BLE broadcasts',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _studentList.length,
                    itemBuilder: (context, index) {
                      final student = _studentList[index];
                      return _buildStudentCard(student);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(StudentBLEData student) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: student.isOnline ? Colors.green : Colors.orange,
          child: Text(
            student.rollNumber.substring(0, 1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text('Roll: ${student.rollNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device: ${student.deviceName}'),
            Text('Signal: ${student.rssi} dBm'),
            Text('Time: ${_formatTime(student.timestamp)}'),
            if (!student.isOnline)
              const Text('OFFLINE', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Icon(
          student.isOnline ? Icons.wifi : Icons.wifi_off,
          color: student.isOnline ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class StudentBLEData {
  final String rollNumber;
  final String deviceName;
  final String deviceId;
  final DateTime timestamp;
  final int rssi;
  final bool isOnline;

  StudentBLEData({
    required this.rollNumber,
    required this.deviceName,
    required this.deviceId,
    required this.timestamp,
    required this.rssi,
    required this.isOnline,
  });

  Map<String, dynamic> toJson() {
    return {
      'roll_number': rollNumber,
      'device_name': deviceName,
      'device_id': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'rssi': rssi,
      'is_online': isOnline,
    };
  }

  factory StudentBLEData.fromJson(Map<String, dynamic> json) {
    return StudentBLEData(
      rollNumber: json['roll_number'],
      deviceName: json['device_name'],
      deviceId: json['device_id'],
      timestamp: DateTime.parse(json['timestamp']),
      rssi: json['rssi'],
      isOnline: json['is_online'],
    );
  }
}
