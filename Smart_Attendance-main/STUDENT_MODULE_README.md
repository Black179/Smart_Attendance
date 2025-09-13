# Student Module - Phase 2 Implementation

## Overview
This document describes the implementation of Phase 2 of the Smart Attendance System's Student Module, which includes student enrollment, attendance marking, face capture, and BLE heartbeat functionality.

## Features Implemented

### 1. Student Enrollment (Basic)
- **UI Components**: Name, Roll Number, and Class input fields
- **API Integration**: Calls `/enroll` endpoint
- **Validation**: Ensures all fields are filled before submission
- **Response Handling**: Shows success/error messages with student ID

### 2. Mark Attendance (Basic)
- **UI Components**: "Mark Attendance" button
- **API Integration**: POSTs to `/mark_attendance` endpoint
- **Data**: Uses student name, class name, current date, and "present" status
- **Response Handling**: Shows success/error messages

### 3. Face Capture (Demo)
- **Camera Integration**: Uses `camera` plugin for image capture
- **UI Components**: Live camera preview and capture button
- **File Upload**: Automatically uploads captured images to backend
- **Backend Endpoint**: `/upload_face` endpoint for receiving images
- **File Management**: Saves images with timestamp and student roll number

### 4. BLE Heartbeat (Demo)
- **Bluetooth Integration**: Uses `flutter_blue_plus` plugin
- **Broadcasting**: Simulates BLE signal broadcast every 5 seconds
- **Student Identification**: Uses roll number as identifier
- **Status Monitoring**: Shows Bluetooth status and last broadcast time
- **Controls**: Start/Stop BLE broadcasting buttons

## Technical Implementation

### Flutter Dependencies Added
```yaml
dependencies:
  http: ^1.1.0          # For API calls
  camera: ^0.10.5+5     # For camera functionality
  flutter_blue_plus: ^1.32.8  # For Bluetooth functionality
```

### Backend Endpoints

#### Existing Endpoints
- `POST /enroll` - Student enrollment
- `POST /mark_attendance` - Mark student attendance

#### New Endpoints
- `POST /upload_face` - Upload student face images
- `GET /list_uploads` - List uploaded files

### File Structure
```
Smart_Attendance-main/
├── sih_role_app/
│   ├── lib/
│   │   ├── main.dart
│   │   └── screens/
│   │       └── student_page.dart  # Complete student module
│   └── pubspec.yaml
├── fastapi_attendance/
│   ├── app/
│   │   ├── main.py
│   │   └── routers/
│   │       ├── enroll.py
│   │       ├── attendance.py
│   │       └── upload.py  # New upload router
│   └── uploads/  # Created automatically for file storage
└── test_api.py  # Backend testing script
```

## Testing Instructions

### 1. Start the Backend Server
```bash
cd Smart_Attendance-main/fastapi_attendance
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Run the Flutter App
```bash
cd Smart_Attendance-main/sih_role_app
flutter pub get
flutter run -d chrome
```

### 3. Test Student Enrollment
1. Open the Flutter app in Chrome
2. Click on "Student" role
3. Fill in the enrollment form:
   - Student Name: "John Doe"
   - Roll Number: "12345"
   - Class Name: "Class A"
4. Click "Enroll Student"
5. Verify success message with student ID

### 4. Test Mark Attendance
1. Ensure student is enrolled (from step 3)
2. Click "Mark Attendance" button
3. Verify success message

### 5. Test Face Capture
1. Allow camera permissions when prompted
2. Click "Capture Image" button
3. Verify image is captured and uploaded
4. Check backend logs for upload confirmation

### 6. Test BLE Heartbeat
1. Ensure Bluetooth is enabled on device
2. Enter a roll number
3. Click "Start BLE" button
4. Verify status shows "BLE broadcasting every 5 seconds"
5. Check console logs for broadcast messages every 5 seconds
6. Click "Stop BLE" to stop broadcasting

### 7. Backend API Testing
```bash
cd Smart_Attendance-main
python test_api.py
```

## Database Verification

### Check Student Enrollment
The enrollment creates records in:
- `students` table (if student doesn't exist)
- `classes` table (if class doesn't exist)
- `enrollments` table (student-class relationship)

### Check Attendance Records
The attendance marking creates records in:
- `attendance` table with student_id, class_id, date, and status

### Check File Uploads
Uploaded images are stored in:
- `uploads/` directory with naming pattern: `student_{roll}_{timestamp}_{original_filename}`

## API Request/Response Examples

### Enrollment Request
```json
POST /enroll
{
  "student_name": "John Doe",
  "class_name": "Class A"
}
```

### Enrollment Response
```json
{
  "student_id": 1,
  "class_id": 1,
  "message": "Enrolled successfully"
}
```

### Mark Attendance Request
```json
POST /mark_attendance
{
  "student_name": "John Doe",
  "class_name": "Class A",
  "date": "2024-01-15",
  "status": "present"
}
```

### Mark Attendance Response
```json
{
  "message": "Attendance marked"
}
```

## Future Enhancements

### Phase 3 Considerations
1. **TFLite Integration**: Replace dummy image upload with face embedding generation
2. **Real BLE Broadcasting**: Implement actual BLE advertisement with student roll
3. **Face Recognition**: Add face matching for attendance verification
4. **Offline Support**: Cache data for offline functionality
5. **Push Notifications**: Notify students of attendance status

### Security Improvements
1. **Authentication**: Add user authentication
2. **Data Encryption**: Encrypt sensitive data
3. **Input Validation**: Enhanced server-side validation
4. **Rate Limiting**: Prevent API abuse

## Troubleshooting

### Common Issues
1. **Camera not working**: Check browser permissions and HTTPS requirement
2. **Bluetooth not detected**: Ensure Bluetooth is enabled and supported
3. **API connection failed**: Verify backend server is running on port 8000
4. **File upload failed**: Check uploads directory permissions

### Debug Information
- Flutter app logs: Check browser console
- Backend logs: Check terminal running uvicorn
- Database: Check attendance.db file
- Uploads: Check uploads/ directory

## Conclusion
The Student Module Phase 2 implementation provides a complete foundation for student enrollment, attendance marking, face capture, and BLE heartbeat functionality. All components are working and ready for testing and further development.



