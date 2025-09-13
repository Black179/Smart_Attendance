import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../services/offline_service.dart';
import '../services/tflite_service.dart';
import '../services/auth_service.dart';

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _classController = TextEditingController();
  final _odReasonController = TextEditingController();
  final _odDateController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = '';
  Color _statusColor = Colors.grey;
  
  // Camera variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  
  // BLE variables
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isBluetoothOn = false;
  Timer? _bleTimer;
  String _bleStatus = 'BLE not started';
  
  // OD Request variables
  String _odFileName = '';
  File? _odFile;
  
  // Face embedding variables
  String faceEmbedding = '';
  String faceImagePath = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeBluetooth();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _classController.dispose();
    _odReasonController.dispose();
    _odDateController.dispose();
    _cameraController?.dispose();
    _bleTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
        );
        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
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

  Future<void> _enrollStudent() async {
    if (_nameController.text.isEmpty || _rollController.text.isEmpty || _classController.text.isEmpty) {
      _showStatus('Please fill all fields', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate face embedding if image is captured
      String faceEmbedding = '';
      String faceImagePath = '';
      
      if (_capturedImage != null) {
        faceImagePath = _capturedImage!.path;
        final embedding = await TFLiteService.generateFaceEmbedding(faceImagePath);
        faceEmbedding = TFLiteService.embeddingToString(embedding);
      }

      final enrollmentData = {
        'student_name': _nameController.text,
        'roll_number': _rollController.text,
        'class_name': _classController.text,
        'face_embedding': faceEmbedding,
      };

      // Check if online
      final isOnline = await OfflineService.isOnline();
      
      if (isOnline) {
        // Try online enrollment
        final headers = await AuthService.getAuthHeaders();
        final response = await http.post(
          Uri.parse('http://localhost:8000/enroll'),
          headers: {
            'Content-Type': 'application/json',
            ...headers,
          },
          body: jsonEncode(enrollmentData),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _showStatus('${data['message']} (Student ID: ${data['student_id']})', Colors.green);
          // Clear form
          _nameController.clear();
          _rollController.clear();
          _classController.clear();
          _capturedImage = null;
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } else {
        throw Exception('No internet connection');
      }
    } catch (e) {
      // Save to offline storage
      await OfflineService.saveEnrollmentOffline(
        studentName: _nameController.text,
        rollNumber: _rollController.text,
        className: _classController.text,
        faceEmbedding: faceEmbedding,
        faceImagePath: faceImagePath,
      );
      
      _showStatus('Saved offline - will sync when online', Colors.orange);
      // Clear form
      _nameController.clear();
      _rollController.clear();
      _classController.clear();
      _capturedImage = null;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAttendance() async {
    if (_nameController.text.isEmpty || _classController.text.isEmpty) {
      _showStatus('Please fill name and class fields', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final attendanceData = {
        'student_name': _nameController.text,
        'class_name': _classController.text,
        'date': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD format
        'status': 'present',
      };

      // Check if online
      final isOnline = await OfflineService.isOnline();
      
      if (isOnline) {
        // Try online attendance marking
        final headers = await AuthService.getAuthHeaders();
        final response = await http.post(
          Uri.parse('http://localhost:8000/mark_attendance'),
          headers: {
            'Content-Type': 'application/json',
            ...headers,
          },
          body: jsonEncode(attendanceData),
        );

        if (response.statusCode == 200) {
          _showStatus('Attendance marked successfully!', Colors.green);
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } else {
        throw Exception('No internet connection');
      }
    } catch (e) {
      // Save to offline storage
      await OfflineService.saveAttendanceOffline(
        studentName: _nameController.text,
        rollNumber: _rollController.text,
        className: _classController.text,
        date: DateTime.now().toIso8601String().split('T')[0],
        status: 'present',
      );
      
      _showStatus('Saved offline - will sync when online', Colors.orange);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showStatus('Camera not initialized', Colors.red);
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = image;
      });
      _showStatus('Image captured successfully!', Colors.green);
      
      // Upload dummy image to backend (for demo)
      await _uploadImage(image);
    } catch (e) {
      _showStatus('Error capturing image: $e', Colors.red);
    }
  }

  Future<void> _uploadImage(XFile image) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8000/upload_face'), // This endpoint needs to be created
      );
      
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        image.path,
        filename: 'student_${_rollController.text}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      
      request.fields['student_roll'] = _rollController.text;
      
      final response = await request.send();
      
      if (response.statusCode == 200) {
        _showStatus('Image uploaded successfully!', Colors.green);
      } else {
        _showStatus('Image upload failed', Colors.orange);
      }
    } catch (e) {
      _showStatus('Image upload error: $e', Colors.orange);
    }
  }

  void _startBLEHeartbeat() {
    if (!_isBluetoothOn) {
      _showStatus('Bluetooth is not enabled', Colors.red);
      return;
    }

    if (_rollController.text.isEmpty) {
      _showStatus('Please enter roll number for BLE', Colors.red);
      return;
    }

    _bleTimer?.cancel();
    _bleTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _broadcastBLE();
    });
    
    setState(() {
      _bleStatus = 'BLE broadcasting every 5 seconds';
    });
    _showStatus('BLE heartbeat started', Colors.green);
  }

  void _stopBLEHeartbeat() {
    _bleTimer?.cancel();
    setState(() {
      _bleStatus = 'BLE stopped';
    });
    _showStatus('BLE heartbeat stopped', Colors.orange);
  }

  Future<void> _broadcastBLE() async {
    try {
      // For demo purposes, we'll simulate BLE broadcasting
      // In a real implementation, you would use FlutterBluePlus to advertise
      print('BLE Broadcast: Student Roll ${_rollController.text} - ${DateTime.now()}');
      setState(() {
        _bleStatus = 'Last broadcast: ${DateTime.now().toString().substring(11, 19)}';
      });
    } catch (e) {
      print('BLE broadcast error: $e');
    }
  }

  Future<void> _selectODFile() async {
    // For demo purposes, we'll simulate file selection
    // In a real app, you would use file_picker plugin
    setState(() {
      _odFileName = 'medical_certificate.pdf';
      _odFile = File('/path/to/simulated/file.pdf');
    });
    _showStatus('File selected: $_odFileName', Colors.blue);
  }

  Future<void> _submitODRequest() async {
    if (_nameController.text.isEmpty || _rollController.text.isEmpty || 
        _odReasonController.text.isEmpty || _odDateController.text.isEmpty) {
      _showStatus('Please fill all required fields', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8000/od_requests'),
      );
      
      request.fields['student_name'] = _nameController.text;
      request.fields['roll_number'] = _rollController.text;
      request.fields['date'] = _odDateController.text;
      request.fields['reason'] = _odReasonController.text;
      
      if (_odFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          _odFile!.path,
          filename: _odFileName,
        ));
      }
      
      final response = await request.send();
      
      if (response.statusCode == 200) {
        _showStatus('OD request submitted successfully!', Colors.green);
        // Clear form
        _odReasonController.clear();
        _odDateController.clear();
        setState(() {
          _odFileName = '';
          _odFile = null;
        });
      } else {
        _showStatus('Error submitting OD request', Colors.red);
      }
    } catch (e) {
      _showStatus('Network error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  Future<void> _syncOfflineData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await OfflineService.syncAllData();
      _showStatus('Offline data synced successfully!', Colors.green);
    } catch (e) {
      _showStatus('Sync failed: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearOfflineData() async {
    try {
      await OfflineService.clearSyncedData();
      _showStatus('Offline data cleared!', Colors.orange);
    } catch (e) {
      _showStatus('Clear failed: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Module'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Enrollment Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Enrollment',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Student Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rollController,
                      decoration: const InputDecoration(
                        labelText: 'Roll Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        onPressed: _isLoading ? null : _enrollStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Enroll Student'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Mark Attendance Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mark Attendance',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _markAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Mark Attendance'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Camera Capture Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Face Capture',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_isCameraInitialized && _cameraController != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('Camera not available'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _captureImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Capture Image'),
                      ),
                    ),
                    if (_capturedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Captured: ${_capturedImage!.name}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // BLE Heartbeat Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BLE Heartbeat',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bluetooth Status: ${_isBluetoothOn ? "ON" : "OFF"}',
                      style: TextStyle(
                        color: _isBluetoothOn ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Status: $_bleStatus'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _startBLEHeartbeat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Start BLE'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _stopBLEHeartbeat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Stop BLE'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Offline Sync Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offline Sync',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<int>(
                      future: Future.value(OfflineService.getOfflineDataCount()),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Text('Pending offline data: $count items');
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _syncOfflineData,
                            icon: const Icon(Icons.sync),
                            label: const Text('Sync Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _clearOfflineData,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // OD Request Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OD Request',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _odReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for OD',
                        border: OutlineInputBorder(),
                        hintText: 'Enter reason for On Duty request',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _odDateController,
                      decoration: const InputDecoration(
                        labelText: 'OD Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) {
                          _odDateController.text = date.toIso8601String().split('T')[0];
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectODFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_odFileName.isEmpty ? 'Select File' : _odFileName),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitODRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Submit OD'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
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
      ),
    );
  }
}
