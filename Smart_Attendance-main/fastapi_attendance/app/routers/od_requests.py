from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.orm import Session
from datetime import date
from ..db.session import SessionLocal
from ..models.models import ODRequest
from ..schemas.schemas import ODRequestResponse, ODRequestUpdate
import os

router = APIRouter()

# Create od_uploads directory if it doesn't exist
OD_UPLOAD_DIR = "od_uploads"
if not os.path.exists(OD_UPLOAD_DIR):
    os.makedirs(OD_UPLOAD_DIR)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/od_requests", response_model=ODRequestResponse)
async def create_od_request(
    student_name: str = Form(...),
    roll_number: str = Form(...),
    date: str = Form(...),
    reason: str = Form(...),
    file: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    try:
        # Save uploaded file if provided
        file_name = ""
        if file and file.filename:
            file_name = f"od_{roll_number}_{date}_{file.filename}"
            file_path = os.path.join(OD_UPLOAD_DIR, file_name)
            
            with open(file_path, "wb") as buffer:
                content = await file.read()
                buffer.write(content)
        
        # Create OD request record
        od_request = ODRequest(
            student_name=student_name,
            roll_number=roll_number,
            date=date,
            reason=reason,
            file_name=file_name,
            status="pending"
        )
        
        db.add(od_request)
        db.commit()
        db.refresh(od_request)
        
        return ODRequestResponse(
            id=od_request.id,
            student_name=od_request.student_name,
            roll_number=od_request.roll_number,
            date=od_request.date,
            reason=od_request.reason,
            file_name=od_request.file_name,
            status=od_request.status,
            message="OD request submitted successfully"
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create OD request: {str(e)}")

@router.get("/od_requests")
async def get_od_requests(db: Session = Depends(get_db)):
    try:
        requests = db.query(ODRequest).all()
        return {
            "requests": [
                {
                    "id": req.id,
                    "student_name": req.student_name,
                    "roll_number": req.roll_number,
                    "date": req.date,
                    "reason": req.reason,
                    "file_name": req.file_name,
                    "status": req.status
                }
                for req in requests
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch OD requests: {str(e)}")

@router.put("/od_requests/{request_id}")
async def update_od_request_status(
    request_id: int,
    update_data: ODRequestUpdate,
    db: Session = Depends(get_db)
):
    try:
        od_request = db.query(ODRequest).filter(ODRequest.id == request_id).first()
        
        if not od_request:
            raise HTTPException(status_code=404, detail="OD request not found")
        
        od_request.status = update_data.status
        db.commit()
        
        return {
            "message": f"OD request {update_data.status} successfully",
            "request_id": request_id,
            "status": update_data.status
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update OD request: {str(e)}")

@router.get("/od_requests/{request_id}")
async def get_od_request(request_id: int, db: Session = Depends(get_db)):
    try:
        od_request = db.query(ODRequest).filter(ODRequest.id == request_id).first()
        
        if not od_request:
            raise HTTPException(status_code=404, detail="OD request not found")
        
        return {
            "id": od_request.id,
            "student_name": od_request.student_name,
            "roll_number": od_request.roll_number,
            "date": od_request.date,
            "reason": od_request.reason,
            "file_name": od_request.file_name,
            "status": od_request.status
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch OD request: {str(e)}")


