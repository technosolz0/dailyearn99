from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
import os
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("app.main")

from app.core.config import settings
from app.core.database import engine, Base, get_db
from app.models import Contest
from app.api import auth, contests, wallet, referral, admin, spin, puzzle_game, admin_puzzle, word_game, admin_word, fruit_game, admin_fruit, notifications, arrow_game, admin_arrow, portfolio, lottery, admin_lottery, mines_game, admin_mines, plinko_game, admin_plinko, blackjack_game, admin_blackjack
from app.websocket import manager, puzzle_ws_manager, word_ws_manager, fruit_ws_manager, arrow_ws_manager

# Create database tables
from app.models import (
    User, Contest, ContestParticipant, WalletTransaction, Referral, Spin, RTPSettings, SpinAuditLog, Notification,
    Question, UserQuestionHistory, ImagePuzzleContest, ImagePuzzleGame, ImagePuzzleAttempt, ImagePuzzleLeaderboard,
    WordContest, WordQuestion, WordAttempt, WordAnswer, WordLeaderboard,
    FruitContest, FruitMatch, FruitEvent, FruitScore, FruitLeaderboard,
    ArrowContest, ArrowGame, ArrowAttempt, ArrowLeaderboard, ArrowPuzzleSeed,
    PortfolioConfig, PortfolioContactMessage, AdminBankDetail, LotteryDraw, LotteryTicket, AdminFCMToken,
    MinesGame, MinesSetting, PlinkoGame, PlinkoSetting, PlinkoMultiplier, PlinkoRTP,
    FruitSetting, FruitGame, BlackjackSetting, BlackjackGame
)  # Explicitly import to register on Base
Base.metadata.create_all(bind=engine)



# Database migrations are managed via Alembic


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Set up CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.core.seeds import seed_test_users, seed_rtp_settings, DEFAULT_QUESTIONS
import json

# Seed initial mock contests on startup
@app.on_event("startup")
async def startup_event():
    from app.core.redis import init_redis
    init_redis()
    from app.core.scheduler import start_lottery_scheduler
    start_lottery_scheduler()
    db = next(get_db())
    try:
        # Seed test users
        seed_test_users(db)
        seed_rtp_settings(db)
        from app.core.seeds import seed_mines_settings, seed_plinko_settings, seed_fruit_settings, seed_blackjack_settings
        seed_mines_settings(db)
        seed_plinko_settings(db)
        seed_fruit_settings(db)
        seed_blackjack_settings(db)

        
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
            now = datetime.now(timezone.utc)
            default_questions_json = json.dumps(DEFAULT_QUESTIONS)
            contests = [
                Contest(
                    title="⚔️ Mega Quiz Championship",
                    entry_fee=30.0,
                    total_slots=1000,
                    joined_slots=0,
                    prize_pool=30000.0,
                    start_time=now + timedelta(hours=2),
                    end_time=now + timedelta(hours=3),
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
                    end_time=now + timedelta(minutes=45),
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
                    end_time=now + timedelta(minutes=10),
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
                    end_time=now + timedelta(days=1, hours=2),
                    status="UPCOMING",
                    questions=default_questions_json
                )
            ]
            db.bulk_save_objects(contests)
            db.commit()

        # Seed Image Puzzle contests
        if db.query(ImagePuzzleContest).count() == 0:
            now = datetime.now(timezone.utc)
            puzzle_contests = [
                ImagePuzzleContest(
                    title="🧩 Beginner Grid Sweepstakes",
                    entry_fee=10.0,
                    total_slots=100,
                    joined_slots=0,
                    prize_pool=800.0,
                    start_time=now + timedelta(minutes=1),
                    end_time=now + timedelta(hours=2),
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 300.0},
                        {"min_rank": 2, "max_rank": 3, "prize": 150.0},
                        {"min_rank": 4, "max_rank": 10, "prize": 20.0}
                    ]),
                    image_url="https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&auto=format&fit=crop",
                    grid_size=3,
                    duration_seconds=300
                ),
                ImagePuzzleContest(
                    title="🔥 Speed Grid Championship",
                    entry_fee=50.0,
                    total_slots=50,
                    joined_slots=0,
                    prize_pool=2000.0,
                    start_time=now + timedelta(minutes=5),
                    end_time=now + timedelta(hours=3),
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 1000.0},
                        {"min_rank": 2, "max_rank": 2, "prize": 500.0},
                        {"min_rank": 3, "max_rank": 5, "prize": 166.0}
                    ]),
                    image_url="https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500&auto=format&fit=crop",
                    grid_size=4,
                    duration_seconds=180
                ),
                ImagePuzzleContest(
                    title="💎 Hardcore 5x5 Expert Arena",
                    entry_fee=200.0,
                    total_slots=10,
                    joined_slots=0,
                    prize_pool=1600.0,
                    start_time=now + timedelta(hours=1),
                    end_time=now + timedelta(hours=5),
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 1000.0},
                        {"min_rank": 2, "max_rank": 2, "prize": 600.0}
                    ]),
                    image_url="https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=500&auto=format&fit=crop",
                    grid_size=5,
                    duration_seconds=600
                )
            ]
            db.bulk_save_objects(puzzle_contests)
            db.commit()
            print("Database Seeding: Populated initial Image Puzzle contests.")

        # Seed Fruit contests
        if db.query(FruitContest).count() == 0:
            now = datetime.now(timezone.utc)
            fruit_contests = [
                FruitContest(
                    title="🍓 Small Fruit Slicing Tournament",
                    entry_fee=10.0,
                    total_slots=50,
                    joined_slots=0,
                    prize_pool=400.0,
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 150.0},
                        {"min_rank": 2, "max_rank": 3, "prize": 75.0},
                        {"min_rank": 4, "max_rank": 10, "prize": 14.0}
                    ]),
                    seed="small_seed_xyz_123",
                    duration_seconds=60,
                    start_time=now + timedelta(minutes=1),
                    end_time=now + timedelta(hours=2)
                ),
                FruitContest(
                    title="🍍 Speed Slicing Challenger",
                    entry_fee=50.0,
                    total_slots=500,
                    joined_slots=0,
                    prize_pool=20000.0,
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 5000.0},
                        {"min_rank": 2, "max_rank": 2, "prize": 3000.0},
                        {"min_rank": 3, "max_rank": 5, "prize": 1500.0},
                        {"min_rank": 6, "max_rank": 50, "prize": 166.0}
                    ]),
                    seed="medium_seed_abc_999",
                    duration_seconds=60,
                    start_time=now + timedelta(minutes=5),
                    end_time=now + timedelta(hours=3)
                ),
                FruitContest(
                    title="🍉 Mega Slices Championship",
                    entry_fee=100.0,
                    total_slots=5000,
                    joined_slots=0,
                    prize_pool=400000.0,
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 100000.0},
                        {"min_rank": 2, "max_rank": 2, "prize": 50000.0},
                        {"min_rank": 3, "max_rank": 5, "prize": 20000.0},
                        {"min_rank": 6, "max_rank": 100, "prize": 2000.0}
                    ]),
                    seed="mega_seed_watermelon_blast",
                    duration_seconds=60,
                    start_time=now + timedelta(hours=1),
                    end_time=now + timedelta(hours=5)
                )
            ]
            db.bulk_save_objects(fruit_contests)
            db.commit()
            print("Database Seeding: Populated initial Fruit contests.")

        # Seed Word Contests and Questions
        if db.query(WordContest).count() == 0:
            now = datetime.now(timezone.utc)
            word_contest = WordContest(
                title="🔤 Beginner Word Unscramble",
                entry_fee=10.0,
                total_slots=100,
                joined_slots=0,
                prize_pool=800.0,
                difficulty="EASY",
                status="UPCOMING",
                prize_rules=json.dumps([
                    {"min_rank": 1, "max_rank": 1, "prize": 300.0},
                    {"min_rank": 2, "max_rank": 3, "prize": 150.0},
                    {"min_rank": 4, "max_rank": 10, "prize": 20.0}
                ]),
                duration_seconds=120,
                start_time=now + timedelta(minutes=1),
                end_time=now + timedelta(hours=2)
            )
            db.add(word_contest)
            db.commit()
            db.refresh(word_contest)

            # Seed questions for this contest
            q1 = WordQuestion(
                contest_id=word_contest.id,
                game_type="UNSCRAMBLE",
                difficulty="EASY",
                puzzle_data=json.dumps({"scrambled": "TDAR"}),
                clues="Target programming language for Flutter.",
                correct_answer="DART",
                points_reward=100
            )
            q2 = WordQuestion(
                contest_id=word_contest.id,
                game_type="MISSING_LETTERS",
                difficulty="EASY",
                puzzle_data=json.dumps({"pattern": "D_R_"}),
                clues="Hint: D_R_.",
                correct_answer="DART",
                points_reward=100
            )
            q3 = WordQuestion(
                contest_id=word_contest.id,
                game_type="WORD_SEARCH",
                difficulty="EASY",
                puzzle_data=json.dumps({
                    "grid": [
                        ["B", "L", "O", "C"],
                        ["X", "Y", "Z", "A"],
                        ["Q", "W", "E", "R"],
                        ["A", "S", "D", "F"]
                    ]
                }),
                clues="Find the state management pattern library (BLOC) in first row.",
                correct_answer="BLOC",
                points_reward=100
            )
            db.add_all([q1, q2, q3])
            db.commit()
            print("Database Seeding: Populated initial Word contests and questions.")

        # Seed Arrow Contests
        if db.query(ArrowContest).count() == 0:
            now = datetime.now(timezone.utc)
            arrow_contests = [
                ArrowContest(
                    title="🏹 Small Arrows Sweepstakes (Easy)",
                    entry_fee=10.0,
                    total_slots=100,
                    joined_slots=0,
                    prize_pool=800.0,
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 300.0},
                        {"min_rank": 2, "max_rank": 3, "prize": 150.0},
                        {"min_rank": 4, "max_rank": 10, "prize": 20.0}
                    ]),
                    grid_size=8,
                    difficulty="EASY",
                    arrow_count=50,
                    duration_seconds=60,
                    start_time=now + timedelta(minutes=1),
                    end_time=now + timedelta(hours=2)
                ),
                ArrowContest(
                    title="🔥 Speed Arrows Championship (Medium)",
                    entry_fee=50.0,
                    total_slots=50,
                    joined_slots=0,
                    prize_pool=2000.0,
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 1000.0},
                        {"min_rank": 2, "max_rank": 2, "prize": 500.0},
                        {"min_rank": 3, "max_rank": 5, "prize": 166.0}
                    ]),
                    grid_size=10,
                    difficulty="MEDIUM",
                    arrow_count=80,
                    duration_seconds=90,
                    start_time=now + timedelta(minutes=5),
                    end_time=now + timedelta(hours=3)
                ),
                ArrowContest(
                    title="💎 Hardcore Arrow Arena (Hard)",
                    entry_fee=200.0,
                    total_slots=10,
                    joined_slots=0,
                    prize_pool=1600.0,
                    status="UPCOMING",
                    prize_rules=json.dumps([
                        {"min_rank": 1, "max_rank": 1, "prize": 1000.0},
                        {"min_rank": 2, "max_rank": 2, "prize": 600.0}
                    ]),
                    grid_size=12,
                    difficulty="HARD",
                    arrow_count=150,
                    duration_seconds=120,
                    start_time=now + timedelta(hours=1),
                    end_time=now + timedelta(hours=5)
                )
            ]
            for c in arrow_contests:
                db.add(c)
            db.commit()
            print("Database Seeding: Populated initial Arrow contests.")

        # Seed Lottery draws
        if db.query(LotteryDraw).count() == 0:
            now = datetime.now(timezone.utc)
            lottery_draws = [
                LotteryDraw(
                    title="🎟️ Daily Quick Cash Draw #102",
                    ticket_price=10.0,
                    prize_pool=1000.0,
                    draw_time=now + timedelta(hours=1),
                    max_tickets=500,
                    joined_tickets=0,
                    status="OPEN"
                ),
           
            ]
            for l in lottery_draws:
                db.add(l)
            db.commit()
            print("Database Seeding: Populated initial Lottery draws.")
    finally:
        db.close()

# Include API Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(contests.router, prefix=settings.API_V1_STR)
app.include_router(wallet.router, prefix=settings.API_V1_STR)
app.include_router(referral.router, prefix=settings.API_V1_STR)
app.include_router(spin.router, prefix=settings.API_V1_STR)
app.include_router(admin.public_router, prefix=settings.API_V1_STR)
app.include_router(admin.router, prefix=settings.API_V1_STR)
app.include_router(portfolio.public_router, prefix=settings.API_V1_STR)
app.include_router(portfolio.admin_router, prefix=settings.API_V1_STR)
app.include_router(lottery.router, prefix=settings.API_V1_STR)
app.include_router(admin_lottery.router, prefix=settings.API_V1_STR)

app.include_router(puzzle_game.router, prefix=settings.API_V1_STR)
app.include_router(admin_puzzle.router, prefix=settings.API_V1_STR)
app.include_router(word_game.router, prefix=settings.API_V1_STR)
app.include_router(admin_word.router, prefix=settings.API_V1_STR)
app.include_router(fruit_game.router, prefix=settings.API_V1_STR)
app.include_router(admin_fruit.router, prefix=settings.API_V1_STR)
app.include_router(arrow_game.router, prefix=settings.API_V1_STR)
app.include_router(admin_arrow.router, prefix=settings.API_V1_STR)
app.include_router(notifications.router, prefix=settings.API_V1_STR)
app.include_router(mines_game.router, prefix=settings.API_V1_STR)
app.include_router(admin_mines.router, prefix=settings.API_V1_STR)
app.include_router(plinko_game.router, prefix=settings.API_V1_STR)
app.include_router(admin_plinko.router, prefix=settings.API_V1_STR)
app.include_router(blackjack_game.router, prefix=settings.API_V1_STR)
app.include_router(admin_blackjack.router, prefix=settings.API_V1_STR)

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

# Realtime Puzzle Leaderboard WebSocket endpoint
@app.websocket("/ws/puzzle/leaderboard/{contest_id}")
async def puzzle_websocket_endpoint(websocket: WebSocket, contest_id: int):
    await puzzle_ws_manager.connect(websocket, contest_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        puzzle_ws_manager.disconnect(websocket, contest_id)
    except Exception:
        puzzle_ws_manager.disconnect(websocket, contest_id)

# Realtime Word Leaderboard WebSocket endpoint
@app.websocket("/ws/word/leaderboard/{contest_id}")
async def word_websocket_endpoint(websocket: WebSocket, contest_id: int):
    await word_ws_manager.connect(websocket, contest_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        word_ws_manager.disconnect(websocket, contest_id)
    except Exception:
        word_ws_manager.disconnect(websocket, contest_id)

# Realtime Fruit Leaderboard WebSocket endpoint
@app.websocket("/ws/fruit/leaderboard/{contest_id}")
async def fruit_websocket_endpoint(websocket: WebSocket, contest_id: int):
    await fruit_ws_manager.connect(websocket, contest_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        fruit_ws_manager.disconnect(websocket, contest_id)
    except Exception:
        fruit_ws_manager.disconnect(websocket, contest_id)

# Realtime Arrow Leaderboard WebSocket endpoint
@app.websocket("/ws/arrow/leaderboard/{contest_id}")
async def arrow_websocket_endpoint(websocket: WebSocket, contest_id: int):
    await arrow_ws_manager.connect(websocket, contest_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        arrow_ws_manager.disconnect(websocket, contest_id)
    except Exception:
        arrow_ws_manager.disconnect(websocket, contest_id)

# Redirect root to admin dashboard
@app.get("/")
def read_root():
    return RedirectResponse(url="/admin/index.html")

# Serve Admin Static HTML Panel
app.mount("/admin", StaticFiles(directory="app/static"), name="static")
