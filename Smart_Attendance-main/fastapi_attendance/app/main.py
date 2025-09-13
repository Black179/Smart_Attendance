from fastapi import FastAPI
from .routers.enroll import router as enroll_router
from .routers.attendance import router as attendance_router
from .routers.upload import router as upload_router
from .routers.od_requests import router as od_requests_router
from .routers.bus_sync import router as bus_sync_router
from .routers.auth import router as auth_router
from .db.session import Base, engine

app = FastAPI(title="Attendance API", version="1.0.0")

# Ensure tables are created
Base.metadata.create_all(bind=engine)

app.include_router(auth_router)
app.include_router(enroll_router)
app.include_router(attendance_router)
app.include_router(upload_router)
app.include_router(od_requests_router)
app.include_router(bus_sync_router)
