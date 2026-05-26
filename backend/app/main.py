from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
import os

from app.core.config import settings
from app.core.database import engine, Base, get_db
from app.models import Contest
from app.api import auth, contests, wallet, referral, admin
from app.websocket import manager

# Create database tables
Base.metadata.create_all(bind=engine)

def migrate_database():
    from sqlalchemy import text
    with engine.begin() as conn:
        columns = [
            ("bank_account_number", "VARCHAR"),
            ("bank_ifsc_code", "VARCHAR"),
            ("bank_account_holder_name", "VARCHAR"),
            ("bank_name", "VARCHAR"),
        ]
        for col_name, col_type in columns:
            try:
                conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
                print(f"Schema Migration: Added column '{col_name}' to users table.")
            except Exception:
                # Ignore error (column already exists)
                pass

migrate_database()

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Set up CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.core.seeds import seed_test_users

# Seed initial mock contests on startup
@app.on_event("startup")
def startup_event():
    db = next(get_db())
    try:
        # Seed test users
        seed_test_users(db)
        
        if db.query(Contest).count() == 0:
            now = datetime.now()
            contests = [
                Contest(
                    title="⚔️ Mega Quiz Championship",
                    entry_fee=30.0,
                    total_slots=1000,
                    joined_slots=0,
                    prize_pool=30000.0,
                    start_time=now + timedelta(hours=2),
                    status="UPCOMING"
                ),
                Contest(
                    title="🔥 Super Challenger Battle",
                    entry_fee=100.0,
                    total_slots=50,
                    joined_slots=0,
                    prize_pool=5000.0,
                    start_time=now + timedelta(minutes=30),
                    status="UPCOMING"
                ),
                Contest(
                    title="⚡ Blitz Fast Trivia",
                    entry_fee=10.0,
                    total_slots=10,
                    joined_slots=0,
                    prize_pool=100.0,
                    start_time=now + timedelta(minutes=5),
                    status="UPCOMING"
                ),
                Contest(
                    title="💎 Diamond High-Stakes Quiz",
                    entry_fee=500.0,
                    total_slots=20,
                    joined_slots=0,
                    prize_pool=10000.0,
                    start_time=now + timedelta(days=1),
                    status="UPCOMING"
                )
            ]
            db.bulk_save_objects(contests)
            db.commit()
    finally:
        db.close()

# Include API Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(contests.router, prefix=settings.API_V1_STR)
app.include_router(wallet.router, prefix=settings.API_V1_STR)
app.include_router(referral.router, prefix=settings.API_V1_STR)
app.include_router(admin.router, prefix=settings.API_V1_STR)

# Realtime Leaderboard WebSocket endpoint
@app.websocket("/ws/leaderboard/{contest_id}")
async def websocket_endpoint(websocket: WebSocket, contest_id: int):
    await manager.connect(websocket, contest_id)
    try:
        # Keep connection open and listen for messages (if any)
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, contest_id)
    except Exception:
        manager.disconnect(websocket, contest_id)

# Redirect root to admin dashboard
@app.get("/")
def read_root():
    return RedirectResponse(url="/admin/index.html")

# Serve Admin Static HTML Panel
app.mount("/admin", StaticFiles(directory="app/static"), name="static")
