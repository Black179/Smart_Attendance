from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..db.session import SessionLocal, engine, Base
from ..models.models import Student, Class, Enrollment
from ..schemas.schemas import EnrollRequest, EnrollResponse

router = APIRouter()

# Ensure tables exist
Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/enroll", response_model=EnrollResponse)
def enroll(req: EnrollRequest, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.name == req.student_name).first()
    if not student:
        student = Student(name=req.student_name)
        db.add(student)
        db.flush()

    clazz = db.query(Class).filter(Class.name == req.class_name).first()
    if not clazz:
        clazz = Class(name=req.class_name)
        db.add(clazz)
        db.flush()

    existing = db.query(Enrollment).filter(
        Enrollment.student_id == student.id,
        Enrollment.class_id == clazz.id,
    ).first()
    if existing:
        db.commit()
        return EnrollResponse(student_id=student.id, class_id=clazz.id, message="Already enrolled")

    enrollment = Enrollment(student_id=student.id, class_id=clazz.id)
    db.add(enrollment)
    db.commit()
    return EnrollResponse(student_id=student.id, class_id=clazz.id, message="Enrolled successfully")
