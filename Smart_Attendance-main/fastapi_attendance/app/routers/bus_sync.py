from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from ..db.session import SessionLocal
from ..models.models import BusSync, StudentBLEData
from ..schemas.schemas import BusSyncRequest, BusSyncResponse
import json

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/bus_sync", response_model=BusSyncResponse)
async def sync_bus_data(sync_data: BusSyncRequest, db: Session = Depends(get_db)):
    try:
        # Create bus sync record
        bus_sync = BusSync(
            driver_id=sync_data.driver_id,
            bus_route=sync_data.bus_route,
            sync_timestamp=datetime.fromisoformat(sync_data.timestamp.replace('Z', '+00:00')),
            student_count=len(sync_data.students),
            student_data=json.dumps([student.dict() for student in sync_data.students])
        )
        
        db.add(bus_sync)
        db.commit()
        db.refresh(bus_sync)
        
        # Process individual student BLE data
        for student_data in sync_data.students:
            student_ble = StudentBLEData(
                roll_number=student_data.roll_number,
                device_name=student_data.device_name,
                device_id=student_data.device_id,
                timestamp=datetime.fromisoformat(student_data.timestamp.replace('Z', '+00:00')),
                rssi=student_data.rssi,
                is_online=student_data.is_online,
                bus_sync_id=bus_sync.id
            )
            db.add(student_ble)
        
        db.commit()
        
        return BusSyncResponse(
            sync_id=bus_sync.id,
            driver_id=bus_sync.driver_id,
            bus_route=bus_sync.bus_route,
            student_count=bus_sync.student_count,
            sync_timestamp=bus_sync.sync_timestamp,
            message="Bus data synced successfully"
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to sync bus data: {str(e)}")

@router.get("/bus_sync")
async def get_bus_sync_history(db: Session = Depends(get_db)):
    try:
        sync_records = db.query(BusSync).order_by(BusSync.sync_timestamp.desc()).limit(50).all()
        
        return {
            "sync_records": [
                {
                    "id": record.id,
                    "driver_id": record.driver_id,
                    "bus_route": record.bus_route,
                    "student_count": record.student_count,
                    "sync_timestamp": record.sync_timestamp.isoformat(),
                }
                for record in sync_records
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch bus sync history: {str(e)}")

@router.get("/bus_sync/{sync_id}/students")
async def get_sync_students(sync_id: int, db: Session = Depends(get_db)):
    try:
        students = db.query(StudentBLEData).filter(StudentBLEData.bus_sync_id == sync_id).all()
        
        return {
            "sync_id": sync_id,
            "students": [
                {
                    "roll_number": student.roll_number,
                    "device_name": student.device_name,
                    "device_id": student.device_id,
                    "timestamp": student.timestamp.isoformat(),
                    "rssi": student.rssi,
                    "is_online": student.is_online,
                }
                for student in students
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch sync students: {str(e)}")


