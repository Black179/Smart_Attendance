from fastapi import FastAPI
from .routers.enroll import router as enroll_router
from .routers.attendance import router as attendance_router
from .db.session import Base, engine

app = FastAPI(title="Attendance API", version="1.0.0")

# Ensure tables are created
Base.metadata.create_all(bind=engine)

app.include_router(enroll_router)
app.include_router(attendance_router)
