from pydantic import BaseModel, Field
from datetime import date

class EnrollRequest(BaseModel):
    student_name: str = Field(min_length=1)
    class_name: str = Field(min_length=1)

class EnrollResponse(BaseModel):
    student_id: int
    class_id: int
    message: str

class MarkAttendanceRequest(BaseModel):
    student_name: str
    class_name: str
    date: date
    status: str  # 'present' | 'absent'

class AttendanceRecord(BaseModel):
    student_name: str
    class_name: str
    date: date
    status: str

class ClassAttendanceResponse(BaseModel):
    class_name: str
    records: list[AttendanceRecord]

class ODRequestResponse(BaseModel):
    id: int
    student_name: str
    roll_number: str
    date: str
    reason: str
    file_name: str
    status: str
    message: str

class ODRequestUpdate(BaseModel):
    status: str  # 'approved' or 'rejected'

class StudentBLEDataRequest(BaseModel):
    roll_number: str
    device_name: str
    device_id: str
    timestamp: str
    rssi: int
    is_online: bool

class BusSyncRequest(BaseModel):
    driver_id: str
    bus_route: str
    timestamp: str
    students: list[StudentBLEDataRequest]

class BusSyncResponse(BaseModel):
    sync_id: int
    driver_id: str
    bus_route: str
    student_count: int
    sync_timestamp: str
    message: str

class UserCreate(BaseModel):
    username: str
    password: str
    role: str
    name: str

class UserLogin(BaseModel):
    username: str
    password: str
    role: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user_id: str
    role: str
