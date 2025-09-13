from sqlalchemy import Column, Integer, String, ForeignKey, Date, UniqueConstraint, Boolean
from sqlalchemy.orm import relationship
from ..db.session import Base

class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False, index=True)

    enrollments = relationship("Enrollment", back_populates="student")

class Class(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False, index=True)

    enrollments = relationship("Enrollment", back_populates="clazz")

class Enrollment(Base):
    __tablename__ = "enrollments"
    __table_args__ = (UniqueConstraint("student_id", "class_id", name="uq_student_class"),)

    id = Column(Integer, primary_key=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)

    student = relationship("Student", back_populates="enrollments")
    clazz = relationship("Class", back_populates="enrollments")

class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (UniqueConstraint("student_id", "class_id", "date", name="uq_attendance"),)

    id = Column(Integer, primary_key=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    date = Column(Date, nullable=False)
    status = Column(String, nullable=False)  # 'present' or 'absent'

class ODRequest(Base):
    __tablename__ = "od_requests"

    id = Column(Integer, primary_key=True, index=True)
    student_name = Column(String, nullable=False)
    roll_number = Column(String, nullable=False)
    date = Column(String, nullable=False)  # Date for which OD is requested
    reason = Column(String, nullable=False)
    file_name = Column(String, nullable=True)  # Name of uploaded file
    status = Column(String, nullable=False, default="pending")  # 'pending', 'approved', 'rejected'

class BusSync(Base):
    __tablename__ = "bus_sync"

    id = Column(Integer, primary_key=True, index=True)
    driver_id = Column(String, nullable=False)
    bus_route = Column(String, nullable=False)
    sync_timestamp = Column(String, nullable=False)  # ISO timestamp
    student_count = Column(Integer, nullable=False)
    student_data = Column(String, nullable=True)  # JSON string of student data

class StudentBLEData(Base):
    __tablename__ = "student_ble_data"

    id = Column(Integer, primary_key=True, index=True)
    roll_number = Column(String, nullable=False)
    device_name = Column(String, nullable=False)
    device_id = Column(String, nullable=False)
    timestamp = Column(String, nullable=False)  # ISO timestamp
    rssi = Column(Integer, nullable=False)
    is_online = Column(String, nullable=False)  # 'true' or 'false' as string
    bus_sync_id = Column(Integer, nullable=True)  # Foreign key to bus_sync

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(String, nullable=False)  # 'student', 'teacher', 'driver'
    name = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
