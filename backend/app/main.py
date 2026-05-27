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
from app.api import auth, contests, wallet, referral, admin, spin
from app.websocket import manager

# Create database tables
from app.models import Question, UserQuestionHistory  # Explicitly import to register on Base
Base.metadata.create_all(bind=engine)

def migrate_database():
    from sqlalchemy import text
    columns_users = [
        ("bank_account_number", "VARCHAR"),
        ("bank_ifsc_code", "VARCHAR"),
        ("bank_account_holder_name", "VARCHAR"),
        ("bank_name", "VARCHAR"),
        ("first_name", "VARCHAR"),
        ("last_name", "VARCHAR"),
    ]
    for col_name, col_type in columns_users:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
            print(f"Schema Migration: Added column '{col_name}' to users table.")
        except Exception:
            # Ignore error (column already exists)
            pass

    columns_contests = [
        ("prize_rules", "TEXT"),
        ("questions", "TEXT"),
    ]
    for col_name, col_type in columns_contests:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE contests ADD COLUMN {col_name} {col_type}"))
            print(f"Schema Migration: Added column '{col_name}' to contests table.")
        except Exception:
            # Ignore error (column already exists)
            pass

    columns_participants = [
        ("quiz_questions", "TEXT"),
    ]
    for col_name, col_type in columns_participants:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE contest_participants ADD COLUMN {col_name} {col_type}"))
            print(f"Schema Migration: Added column '{col_name}' to contest_participants table.")
        except Exception:
            # Ignore error (column already exists)
            pass

    columns_transactions = [
        ("utr", "VARCHAR UNIQUE"),
    ]
    for col_name, col_type in columns_transactions:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE wallet_transactions ADD COLUMN {col_name} {col_type}"))
            print(f"Schema Migration: Added column '{col_name}' to wallet_transactions table.")
        except Exception:
            # Ignore error (column already exists)
            pass

    columns_questions = [
        ("language", "VARCHAR DEFAULT 'en'"),
    ]
    for col_name, col_type in columns_questions:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE questions ADD COLUMN {col_name} {col_type}"))
            print(f"Schema Migration: Added column '{col_name}' to questions table.")
            try:
                with engine.begin() as conn:
                    conn.execute(text("CREATE INDEX idx_questions_language ON questions(language)"))
                print("Schema Migration: Created index on questions(language).")
            except Exception:
                pass
        except Exception:
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

from app.core.seeds import seed_test_users, seed_rtp_settings, DEFAULT_QUESTIONS
import json

# Seed initial mock contests on startup
@app.on_event("startup")
def startup_event():
    db = next(get_db())
    try:
        # Seed test users
        seed_test_users(db)
        seed_rtp_settings(db)
        
        # Seed central questions pool
        if db.query(Question).count() == 0:
            for q_data in DEFAULT_QUESTIONS:
                q = Question(
                    text=q_data["text"],
                    options=json.dumps(q_data["options"]),
                    correct_answer_index=q_data["correct_answer_index"]
                )
                db.add(q)
            db.commit()
            print("Database Seeding: Populated central questions table.")
            
        if db.query(Contest).count() == 0:
            now = datetime.now()
            default_questions_json = json.dumps(DEFAULT_QUESTIONS)
            contests = [
                Contest(
                    title="⚔️ Mega Quiz Championship",
                    entry_fee=30.0,
                    total_slots=1000,
                    joined_slots=0,
                    prize_pool=30000.0,
                    start_time=now + timedelta(hours=2),
                    status="UPCOMING",
                    questions=default_questions_json
                ),
                Contest(
                    title="🔥 Super Challenger Battle",
                    entry_fee=100.0,
                    total_slots=50,
                    joined_slots=0,
                    prize_pool=5000.0,
                    start_time=now + timedelta(minutes=30),
                    status="UPCOMING",
                    questions=default_questions_json
                ),
                Contest(
                    title="⚡ Blitz Fast Trivia",
                    entry_fee=10.0,
                    total_slots=10,
                    joined_slots=0,
                    prize_pool=100.0,
                    start_time=now + timedelta(minutes=5),
                    status="UPCOMING",
                    questions=default_questions_json
                ),
                Contest(
                    title="💎 Diamond High-Stakes Quiz",
                    entry_fee=500.0,
                    total_slots=20,
                    joined_slots=0,
                    prize_pool=10000.0,
                    start_time=now + timedelta(days=1),
                    status="UPCOMING",
                    questions=default_questions_json
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
app.include_router(spin.router, prefix=settings.API_V1_STR)
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
