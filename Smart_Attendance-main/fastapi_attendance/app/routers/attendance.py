from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import date
from ..db.session import SessionLocal
from ..models.models import Student, Class, Attendance, Enrollment
from ..schemas.schemas import MarkAttendanceRequest, ClassAttendanceResponse, AttendanceRecord

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/mark_attendance")
def mark_attendance(req: MarkAttendanceRequest, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.name == req.student_name).first()
    clazz = db.query(Class).filter(Class.name == req.class_name).first()

    if not student or not clazz:
        raise HTTPException(status_code=404, detail="Student or Class not found. Enroll first.")

    enrolled = db.query(Enrollment).filter(Enrollment.student_id == student.id, Enrollment.class_id == clazz.id).first()
    if not enrolled:
        raise HTTPException(status_code=400, detail="Student is not enrolled in this class")

    record = db.query(Attendance).filter(
        Attendance.student_id == student.id,
        Attendance.class_id == clazz.id,
        Attendance.date == req.date,
    ).first()

    if record:
        record.status = req.status
    else:
        record = Attendance(student_id=student.id, class_id=clazz.id, date=req.date, status=req.status)
        db.add(record)

    db.commit()
    return {"message": "Attendance marked"}


@router.get("/class_attendance", response_model=ClassAttendanceResponse)
def class_attendance(class_name: str, on: date, db: Session = Depends(get_db)):
    clazz = db.query(Class).filter(Class.name == class_name).first()
    if not clazz:
        raise HTTPException(status_code=404, detail="Class not found")

    rows = db.query(Attendance, Student).join(Student, Student.id == Attendance.student_id).filter(
        Attendance.class_id == clazz.id,
        Attendance.date == on,
    ).all()

    records = [
        AttendanceRecord(
            student_name=student.name,
            class_name=class_name,
            date=att.date,
            status=att.status,
        )
        for att, student in rows
    ]

    return ClassAttendanceResponse(class_name=class_name, records=records)

@router.put("/attendance/update")
def update_attendance_status(req: MarkAttendanceRequest, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.name == req.student_name).first()
    clazz = db.query(Class).filter(Class.name == req.class_name).first()

    if not student or not clazz:
        raise HTTPException(status_code=404, detail="Student or Class not found")

    record = db.query(Attendance).filter(
        Attendance.student_id == student.id,
        Attendance.class_id == clazz.id,
        Attendance.date == req.date,
    ).first()

    if record:
        record.status = req.status
    else:
        record = Attendance(student_id=student.id, class_id=clazz.id, date=req.date, status=req.status)
        db.add(record)

    db.commit()
    return {"message": "Attendance updated successfully"}
