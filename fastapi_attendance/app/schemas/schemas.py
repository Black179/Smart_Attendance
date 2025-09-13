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
