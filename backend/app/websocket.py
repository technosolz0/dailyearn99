from fastapi import WebSocket
from typing import Dict, List
import json

class ConnectionManager:
    def __init__(self):
        # Format: {contest_id: [WebSocket]}
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, contest_id: int):
        await websocket.accept()
        if contest_id not in self.active_connections:
            self.active_connections[contest_id] = []
        self.active_connections[contest_id].append(websocket)

    def disconnect(self, websocket: WebSocket, contest_id: int):
        if contest_id in self.active_connections:
            if websocket in self.active_connections[contest_id]:
                self.active_connections[contest_id].remove(websocket)
            if not self.active_connections[contest_id]:
                del self.active_connections[contest_id]

    async def broadcast_leaderboard(self, contest_id: int, leaderboard: List[dict]):
        if contest_id in self.active_connections:
            message = json.dumps({
                "type": "leaderboard_update",
                "contest_id": contest_id,
                "data": leaderboard
            })
            for connection in self.active_connections[contest_id]:
                try:
                    await connection.send_text(message)
                except Exception:
                    # Connection might be closed, we will clean it up on disconnect
                    pass

manager = ConnectionManager()


import threading
from datetime import datetime, timezone
from sqlalchemy.orm import Session

class PuzzleLeaderboardManager:
    def __init__(self):
        self._lock = threading.Lock()
        # Format: {contest_id: {user_id: (score, duration, timestamp, name)}}
        self._scores: Dict[int, Dict[int, tuple]] = {}

    def update_score(self, contest_id: int, user_id: int, name: str, score: int, duration: float):
        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            
            existing = self._scores[contest_id].get(user_id)
            # Update if no score, or new score is higher, or same score but shorter completion time
            if not existing or score > existing[0] or (score == existing[0] and duration < existing[1]):
                self._scores[contest_id][user_id] = (score, duration, datetime.now(timezone.utc), name)

    def get_leaderboard(self, contest_id: int) -> List[dict]:
        with self._lock:
            if contest_id not in self._scores:
                return []
            
            # Sort: highest score desc, shortest completion seconds asc, earliest timestamp asc
            sorted_players = sorted(
                self._scores[contest_id].items(),
                key=lambda x: (-x[1][0], x[1][1], x[1][2])
            )
            
            leaderboard = []
            for rank, (u_id, (score, duration, _, name)) in enumerate(sorted_players, start=1):
                leaderboard.append({
                    "user_id": u_id,
                    "name": name,
                    "score": score,
                    "rank": rank,
                    "completion_seconds": duration
                })
            return leaderboard

    def load_from_db(self, db: Session, contest_id: int):
        from app.models import ImagePuzzleAttempt, User
        attempts = (
            db.query(ImagePuzzleAttempt)
            .join(User)
            .filter(ImagePuzzleAttempt.contest_id == contest_id)
            .filter(ImagePuzzleAttempt.status == "VERIFIED")
            .all()
        )
        with self._lock:
            self._scores[contest_id] = {}
            for att in attempts:
                name = att.user.name or att.user.phone
                self._scores[contest_id][att.user_id] = (att.score, att.completion_seconds, att.submitted_at, name)


class PuzzleConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, contest_id: int):
        await websocket.accept()
        if contest_id not in self.active_connections:
            self.active_connections[contest_id] = []
        self.active_connections[contest_id].append(websocket)

    def disconnect(self, websocket: WebSocket, contest_id: int):
        if contest_id in self.active_connections:
            if websocket in self.active_connections[contest_id]:
                self.active_connections[contest_id].remove(websocket)
            if not self.active_connections[contest_id]:
                del self.active_connections[contest_id]

    async def broadcast_leaderboard(self, contest_id: int, leaderboard: List[dict]):
        if contest_id in self.active_connections:
            message = json.dumps({
                "type": "leaderboard_update",
                "contest_id": contest_id,
                "data": leaderboard
            })
            for connection in self.active_connections[contest_id]:
                try:
                    await connection.send_text(message)
                except Exception:
                    pass

puzzle_ws_manager = PuzzleConnectionManager()
puzzle_leaderboard_manager = PuzzleLeaderboardManager()


class WordConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, contest_id: int):
        await websocket.accept()
        if contest_id not in self.active_connections:
            self.active_connections[contest_id] = []
        self.active_connections[contest_id].append(websocket)

    def disconnect(self, websocket: WebSocket, contest_id: int):
        if contest_id in self.active_connections:
            if websocket in self.active_connections[contest_id]:
                self.active_connections[contest_id].remove(websocket)
            if not self.active_connections[contest_id]:
                del self.active_connections[contest_id]

    async def broadcast_leaderboard(self, contest_id: int, leaderboard: List[dict]):
        if contest_id in self.active_connections:
            message = json.dumps({
                "type": "leaderboard_update",
                "contest_id": contest_id,
                "data": leaderboard
            })
            for connection in self.active_connections[contest_id]:
                try:
                    await connection.send_text(message)
                except Exception:
                    pass

word_ws_manager = WordConnectionManager()


class FruitLeaderboardManager:
    def __init__(self):
        # Format: {contest_id: {user_id: (score, max_combo, miss_count, submitted_at, name)}}
        self._scores: Dict[int, Dict[int, tuple]] = {}
        self._lock = threading.Lock()

    def update_score(self, contest_id: int, user_id: int, name: str, score: int, max_combo: int, miss_count: int, submitted_at: datetime):
        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            
            existing = self._scores[contest_id].get(user_id)
            is_better = False
            if not existing:
                is_better = True
            else:
                ext_score, ext_combo, ext_misses, ext_time, _ = existing
                # Check tie-breaker conditions
                if score > ext_score:
                    is_better = True
                elif score == ext_score:
                    if max_combo > ext_combo:
                        is_better = True
                    elif max_combo == ext_combo:
                        if miss_count < ext_misses:
                            is_better = True
                        elif miss_count == ext_misses:
                            is_better = submitted_at < ext_time

            if is_better:
                self._scores[contest_id][user_id] = (score, max_combo, miss_count, submitted_at, name)

    def get_leaderboard(self, contest_id: int) -> List[dict]:
        with self._lock:
            if contest_id not in self._scores:
                return []
            
            # Sort: score DESC, max_combo DESC, miss_count ASC, submitted_at ASC
            sorted_players = sorted(
                self._scores[contest_id].items(),
                key=lambda x: (-x[1][0], -x[1][1], x[1][2], x[1][3])
            )
            
            leaderboard = []
            for rank, (u_id, (score, combo, misses, _, name)) in enumerate(sorted_players, start=1):
                leaderboard.append({
                    "user_id": u_id,
                    "name": name,
                    "score": score,
                    "max_combo": combo,
                    "miss_count": misses,
                    "rank": rank
                })
            return leaderboard

    def load_from_db(self, db: Session, contest_id: int):
        from app.models import FruitScore, User
        scores = (
            db.query(FruitScore)
            .join(User)
            .filter(FruitScore.contest_id == contest_id)
            .filter(FruitScore.is_verified == True)
            .all()
        )
        with self._lock:
            self._scores[contest_id] = {}
            for s in scores:
                name = s.user.name or s.user.phone
                self._scores[contest_id][s.user_id] = (
                    s.score,
                    s.max_combo,
                    s.miss_count,
                    s.created_at,
                    name
                )


class FruitConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, contest_id: int):
        await websocket.accept()
        if contest_id not in self.active_connections:
            self.active_connections[contest_id] = []
        self.active_connections[contest_id].append(websocket)

    def disconnect(self, websocket: WebSocket, contest_id: int):
        if contest_id in self.active_connections:
            if websocket in self.active_connections[contest_id]:
                self.active_connections[contest_id].remove(websocket)
            if not self.active_connections[contest_id]:
                del self.active_connections[contest_id]

    async def broadcast_leaderboard(self, contest_id: int, leaderboard: List[dict]):
        if contest_id in self.active_connections:
            message = json.dumps({
                "type": "leaderboard_update",
                "contest_id": contest_id,
                "data": leaderboard
            })
            for connection in self.active_connections[contest_id]:
                try:
                    await connection.send_text(message)
                except Exception:
                    pass


fruit_ws_manager = FruitConnectionManager()
fruit_leaderboard_manager = FruitLeaderboardManager()



