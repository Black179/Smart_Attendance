import requests

BASE_URL = "http://127.0.0.1:8000"

# 1️⃣ Enroll a student
enroll_data = {"student_name": "Alice", "class_name": "Math"}
enroll_response = requests.post(f"{BASE_URL}/enroll", json=enroll_data)
print("Enroll Response:", enroll_response.json())

# 2️⃣ Mark attendance
attendance_data = {
    "student_name": "Alice",
    "class_name": "Math",
    "date": "2025-09-12",
    "status": "present"
}
attendance_response = requests.post(f"{BASE_URL}/mark_attendance", json=attendance_data)
print("Mark Attendance Response:", attendance_response.json())

# 3️⃣ Get class attendance
params = {"class_name": "Math", "on": "2025-09-12"}
class_attendance_response = requests.get(f"{BASE_URL}/class_attendance", params=params)
print("Class Attendance Response:", class_attendance_response.json())
