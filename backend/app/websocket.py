import json
import asyncio
import threading
from typing import Dict, List, Tuple
from datetime import datetime, timezone
from fastapi import WebSocket
from sqlalchemy.orm import Session
from app.core.redis import redis_client_async, redis_client_sync, redis_is_active

class ConnectionManager:
    def __init__(self, channel_prefix: str):
        self.active_connections: Dict[int, List[WebSocket]] = {}
        self.channel_prefix = channel_prefix
        self.pubsub_tasks: Dict[int, asyncio.Task] = {}

    async def connect(self, websocket: WebSocket, contest_id: int):
        await websocket.accept()
        if contest_id not in self.active_connections:
            self.active_connections[contest_id] = []
            if redis_is_active:
                self.pubsub_tasks[contest_id] = asyncio.create_task(
                    self._listen_to_redis_channel(contest_id)
                )
        self.active_connections[contest_id].append(websocket)

    def disconnect(self, websocket: WebSocket, contest_id: int):
        if contest_id in self.active_connections:
            if websocket in self.active_connections[contest_id]:
                self.active_connections[contest_id].remove(websocket)
            if not self.active_connections[contest_id]:
                del self.active_connections[contest_id]
                task = self.pubsub_tasks.pop(contest_id, None)
                if task:
                    task.cancel()

    async def _listen_to_redis_channel(self, contest_id: int):
        try:
            pubsub = redis_client_async.pubsub()
            channel = f"channel:{self.channel_prefix}:{contest_id}"
            await pubsub.subscribe(channel)
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = message["data"]
                    if contest_id in self.active_connections:
                        for connection in self.active_connections[contest_id]:
                            try:
                                await connection.send_text(data)
                            except Exception:
                                pass
        except asyncio.CancelledError:
            pass
        except Exception as e:
            print(f"Redis Pub/Sub channel listener error for prefix {self.channel_prefix}: {e}")

    async def broadcast_leaderboard(self, contest_id: int, leaderboard: List[dict]):
        message = json.dumps({
            "type": "leaderboard_update",
            "contest_id": contest_id,
            "data": leaderboard
        })
        if redis_is_active:
            try:
                await redis_client_async.publish(f"channel:{self.channel_prefix}:{contest_id}", message)
            except Exception as e:
                print(f"Redis Pub/Sub publish failed for prefix {self.channel_prefix}: {e}")
        else:
            if contest_id in self.active_connections:
                for connection in self.active_connections[contest_id]:
                    try:
                        await connection.send_text(message)
                    except Exception:
                        pass


# Instantiate Connection Managers
manager = ConnectionManager(channel_prefix="general")
puzzle_ws_manager = ConnectionManager(channel_prefix="puzzle")
word_ws_manager = ConnectionManager(channel_prefix="word")
fruit_ws_manager = ConnectionManager(channel_prefix="fruit")
arrow_ws_manager = ConnectionManager(channel_prefix="arrow")


class LeaderboardManager:
    def __init__(self, game_type: str):
        self.game_type = game_type
        self._lock = threading.Lock()
        # Storage: {contest_id: {user_id: dict}}
        self._scores: Dict[int, Dict[int, dict]] = {}

    def _calculate_redis_score(self, score: int, duration: float, submitted_at: datetime, max_combo: int = 0, miss_count: int = 0) -> float:
        if self.game_type == "fruit":
            combo_val = min(max(0, int(max_combo)), 9999)
            combo_factor = combo_val / 10000.0
            miss_val = min(max(0, int(miss_count)), 9999)
            miss_factor = (10000.0 - miss_val) / 100000000.0
            ts_val = max(0.0, float(submitted_at.timestamp()) - 1700000000.0)
            ts_factor = (1000000000.0 - ts_val) / 1000000000.0
            return float(score) + combo_factor + miss_factor + (ts_factor / 100000000000.0)
        else:
            dur_val = min(max(0.0, float(duration)), 99999.0)
            dur_factor = (100000.0 - dur_val) / 100000.0
            ts_val = max(0.0, float(submitted_at.timestamp()) - 1700000000.0)
            ts_factor = (1000000000.0 - ts_val) / 1000000000.0
            return float(score) + (dur_factor / 10.0) + (ts_factor / 100000000000.0)

    def update_score(self, contest_id: int, user_id: int, name: str, score: int, duration: float = 0.0, max_combo: int = 0, miss_count: int = 0, submitted_at: datetime = None):
        if submitted_at is None:
            submitted_at = datetime.now(timezone.utc)
        if redis_is_active:
            try:
                zset_key = f"leaderboard:{self.game_type}:{contest_id}"
                meta_key = f"leaderboard:{self.game_type}:{contest_id}:meta"
                redis_score = self._calculate_redis_score(score, duration, submitted_at, max_combo, miss_count)
                
                redis_client_sync.zadd(zset_key, {str(user_id): redis_score})
                meta_data = {
                    "name": name,
                    "score": score,
                    "submitted_at": submitted_at.isoformat()
                }
                if self.game_type == "fruit":
                    meta_data["max_combo"] = max_combo
                    meta_data["miss_count"] = miss_count
                else:
                    meta_data["duration"] = duration
                
                redis_client_sync.hset(meta_key, str(user_id), json.dumps(meta_data))
                redis_client_sync.expire(zset_key, 86400)
                redis_client_sync.expire(meta_key, 86400)
                return
            except Exception as e:
                print(f"Redis {self.game_type} Leaderboard update failed: {e}")
                
        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            existing = self._scores[contest_id].get(user_id)
            is_better = False
            if not existing:
                is_better = True
            else:
                if self.game_type == "fruit":
                    if score > existing["score"]:
                        is_better = True
                    elif score == existing["score"]:
                        if max_combo > existing["max_combo"]:
                            is_better = True
                        elif max_combo == existing["max_combo"]:
                            if miss_count < existing["miss_count"]:
                                is_better = True
                            elif miss_count == existing["miss_count"]:
                                is_better = submitted_at < existing["submitted_at"]
                else:
                    if score > existing["score"]:
                        is_better = True
                    elif score == existing["score"]:
                        if duration < existing["duration"]:
                            is_better = True
                        elif duration == existing["duration"]:
                            if "submitted_at" in existing:
                                is_better = submitted_at < existing["submitted_at"]
                            else:
                                is_better = True
            if is_better:
                self._scores[contest_id][user_id] = {
                    "score": score,
                    "duration": duration,
                    "max_combo": max_combo,
                    "miss_count": miss_count,
                    "submitted_at": submitted_at,
                    "name": name
                }

    def get_leaderboard(self, contest_id: int) -> List[dict]:
        if redis_is_active:
            try:
                zset_key = f"leaderboard:{self.game_type}:{contest_id}"
                meta_key = f"leaderboard:{self.game_type}:{contest_id}:meta"
                
                raw_members = redis_client_sync.zrevrange(zset_key, 0, 99, withscores=True)
                if raw_members:
                    user_ids = [m[0] for m in raw_members]
                    metadata_list = redis_client_sync.hmget(meta_key, user_ids)
                    leaderboard = []
                    for rank, (user_id, _), meta_str in zip(range(1, len(raw_members)+1), raw_members, metadata_list):
                        if meta_str:
                            meta = json.loads(meta_str)
                            item = {
                                "user_id": int(user_id),
                                "name": meta["name"],
                                "score": meta["score"],
                                "rank": rank
                            }
                            if self.game_type == "fruit":
                                item["max_combo"] = meta.get("max_combo", 0)
                                item["miss_count"] = meta.get("miss_count", 0)
                            elif self.game_type == "word":
                                item["completion_time_seconds"] = meta.get("duration", 0.0)
                            else:
                                item["completion_seconds"] = meta.get("duration", 0.0)
                            leaderboard.append(item)
                    return leaderboard
            except Exception as e:
                print(f"Redis {self.game_type} Leaderboard read failed: {e}")

        with self._lock:
            if contest_id not in self._scores:
                return []
            
            if self.game_type == "fruit":
                sorted_players = sorted(
                    self._scores[contest_id].items(),
                    key=lambda x: (-x[1]["score"], -x[1]["max_combo"], x[1]["miss_count"], x[1]["submitted_at"])
                )
            elif self.game_type == "word":
                sorted_players = sorted(
                    self._scores[contest_id].items(),
                    key=lambda x: (-x[1]["score"], x[1]["duration"])
                )
            else:
                sorted_players = sorted(
                    self._scores[contest_id].items(),
                    key=lambda x: (-x[1]["score"], x[1]["duration"], x[1].get("submitted_at", datetime.min))
                )
                
            leaderboard = []
            for rank, (u_id, val) in enumerate(sorted_players, start=1):
                item = {
                    "user_id": u_id,
                    "name": val["name"],
                    "score": val["score"],
                    "rank": rank
                }
                if self.game_type == "fruit":
                    item["max_combo"] = val["max_combo"]
                    item["miss_count"] = val["miss_count"]
                elif self.game_type == "word":
                    item["completion_time_seconds"] = val["duration"]
                else:
                    item["completion_seconds"] = val["duration"]
                leaderboard.append(item)
            return leaderboard

    def load_from_db(self, db: Session, contest_id: int):
        from app.models import User
        attempts = []
        if self.game_type == "puzzle":
            from app.models import ImagePuzzleAttempt
            attempts = (
                db.query(ImagePuzzleAttempt)
                .join(User)
                .filter(ImagePuzzleAttempt.contest_id == contest_id)
                .filter(ImagePuzzleAttempt.status == "VERIFIED")
                .all()
            )
        elif self.game_type == "word":
            from app.models import WordAttempt
            attempts = (
                db.query(WordAttempt)
                .join(User)
                .filter(WordAttempt.contest_id == contest_id, WordAttempt.status == "SUBMITTED")
                .all()
            )
        elif self.game_type == "arrow":
            from app.models import ArrowAttempt
            attempts = (
                db.query(ArrowAttempt)
                .join(User)
                .filter(ArrowAttempt.contest_id == contest_id)
                .filter(ArrowAttempt.status == "VERIFIED")
                .all()
            )
        elif self.game_type == "fruit":
            from app.models import FruitScore
            attempts = (
                db.query(FruitScore)
                .join(User)
                .filter(FruitScore.contest_id == contest_id)
                .filter(FruitScore.is_verified == True)
                .all()
            )

        if redis_is_active:
            try:
                zset_key = f"leaderboard:{self.game_type}:{contest_id}"
                meta_key = f"leaderboard:{self.game_type}:{contest_id}:meta"
                redis_client_sync.delete(zset_key, meta_key)
                
                pipeline = redis_client_sync.pipeline()
                for att in attempts:
                    name = att.user.name or att.user.phone
                    if self.game_type == "fruit":
                        sub_at = att.created_at
                        score_val = att.score
                        duration_val = 0.0
                        combo_val = att.max_combo
                        miss_val = att.miss_count
                    elif self.game_type == "word":
                        sub_at = att.submitted_at or att.created_at or datetime.now(timezone.utc)
                        score_val = att.total_score
                        duration_val = att.completion_time_seconds or 0.0
                        combo_val = 0
                        miss_val = 0
                    elif self.game_type == "puzzle":
                        sub_at = att.submitted_at
                        score_val = att.score
                        duration_val = att.completion_seconds
                        combo_val = 0
                        miss_val = 0
                    elif self.game_type == "arrow":
                        sub_at = att.submitted_at
                        score_val = att.score
                        duration_val = att.completion_seconds
                        combo_val = 0
                        miss_val = 0
                        
                    redis_score = self._calculate_redis_score(score_val, duration_val, sub_at, combo_val, miss_val)
                    pipeline.zadd(zset_key, {str(att.user_id): redis_score})
                    
                    meta_data = {
                        "name": name,
                        "score": score_val,
                        "submitted_at": sub_at.isoformat()
                    }
                    if self.game_type == "fruit":
                        meta_data["max_combo"] = combo_val
                        meta_data["miss_count"] = miss_val
                    else:
                        meta_data["duration"] = duration_val
                        
                    pipeline.hset(meta_key, str(att.user_id), json.dumps(meta_data))
                pipeline.expire(zset_key, 86400)
                pipeline.expire(meta_key, 86400)
                pipeline.execute()
                return
            except Exception as e:
                print(f"Redis {self.game_type} Leaderboard db load failed: {e}")

        with self._lock:
            self._scores[contest_id] = {}
            for att in attempts:
                name = att.user.name or att.user.phone
                if self.game_type == "fruit":
                    sub_at = att.created_at
                    score_val = att.score
                    duration_val = 0.0
                    combo_val = att.max_combo
                    miss_val = att.miss_count
                elif self.game_type == "word":
                    sub_at = att.submitted_at or att.created_at or datetime.now(timezone.utc)
                    score_val = att.total_score
                    duration_val = att.completion_time_seconds or 0.0
                    combo_val = 0
                    miss_val = 0
                else: # puzzle, arrow
                    sub_at = att.submitted_at
                    score_val = att.score
                    duration_val = att.completion_seconds
                    combo_val = 0
                    miss_val = 0
                    
                self._scores[contest_id][att.user_id] = {
                    "score": score_val,
                    "duration": duration_val,
                    "max_combo": combo_val,
                    "miss_count": miss_val,
                    "submitted_at": sub_at,
                    "name": name
                }


puzzle_leaderboard_manager = LeaderboardManager("puzzle")
fruit_leaderboard_manager = LeaderboardManager("fruit")
word_leaderboard_manager = LeaderboardManager("word")
arrow_leaderboard_manager = LeaderboardManager("arrow")

