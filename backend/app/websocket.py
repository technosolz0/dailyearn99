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


class PuzzleLeaderboardManager:
    def __init__(self):
        self._lock = threading.Lock()
        self._scores: Dict[int, Dict[int, tuple]] = {}

    def _calculate_redis_score(self, score: int, duration: float, submitted_at: datetime) -> float:
        dur_val = min(max(0.0, float(duration)), 99999.0)
        dur_factor = (100000.0 - dur_val) / 100000.0
        ts_val = max(0.0, float(submitted_at.timestamp()) - 1700000000.0)
        ts_factor = (1000000000.0 - ts_val) / 1000000000.0
        return float(score) + (dur_factor / 10.0) + (ts_factor / 100000000000.0)

    def update_score(self, contest_id: int, user_id: int, name: str, score: int, duration: float):
        now = datetime.now(timezone.utc)
        if redis_is_active:
            try:
                zset_key = f"leaderboard:puzzle:{contest_id}"
                meta_key = f"leaderboard:puzzle:{contest_id}:meta"
                redis_score = self._calculate_redis_score(score, duration, now)
                
                redis_client_sync.zadd(zset_key, {str(user_id): redis_score})
                redis_client_sync.hset(meta_key, str(user_id), json.dumps({
                    "name": name,
                    "score": score,
                    "duration": duration,
                    "submitted_at": now.isoformat()
                }))
                redis_client_sync.expire(zset_key, 86400)
                redis_client_sync.expire(meta_key, 86400)
                return
            except Exception as e:
                print(f"Redis PuzzleLeaderboard update failed: {e}")
                
        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            existing = self._scores[contest_id].get(user_id)
            if not existing or score > existing[0] or (score == existing[0] and duration < existing[1]):
                self._scores[contest_id][user_id] = (score, duration, now, name)

    def get_leaderboard(self, contest_id: int) -> List[dict]:
        if redis_is_active:
            try:
                zset_key = f"leaderboard:puzzle:{contest_id}"
                meta_key = f"leaderboard:puzzle:{contest_id}:meta"
                
                raw_members = redis_client_sync.zrevrange(zset_key, 0, 99, withscores=True)
                if raw_members:
                    user_ids = [m[0] for m in raw_members]
                    metadata_list = redis_client_sync.hmget(meta_key, user_ids)
                    leaderboard = []
                    for rank, (user_id, _), meta_str in zip(range(1, len(raw_members)+1), raw_members, metadata_list):
                        if meta_str:
                            meta = json.loads(meta_str)
                            leaderboard.append({
                                "user_id": int(user_id),
                                "name": meta["name"],
                                "score": meta["score"],
                                "rank": rank,
                                "completion_seconds": meta["duration"]
                            })
                    return leaderboard
            except Exception as e:
                print(f"Redis PuzzleLeaderboard read failed: {e}")

        with self._lock:
            if contest_id not in self._scores:
                return []
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
        if redis_is_active:
            try:
                zset_key = f"leaderboard:puzzle:{contest_id}"
                meta_key = f"leaderboard:puzzle:{contest_id}:meta"
                redis_client_sync.delete(zset_key, meta_key)
                
                pipeline = redis_client_sync.pipeline()
                for att in attempts:
                    name = att.user.name or att.user.phone
                    redis_score = self._calculate_redis_score(att.score, att.completion_seconds, att.submitted_at)
                    pipeline.zadd(zset_key, {str(att.user_id): redis_score})
                    pipeline.hset(meta_key, str(att.user_id), json.dumps({
                        "name": name,
                        "score": att.score,
                        "duration": att.completion_seconds,
                        "submitted_at": att.submitted_at.isoformat()
                    }))
                pipeline.expire(zset_key, 86400)
                pipeline.expire(meta_key, 86400)
                pipeline.execute()
                return
            except Exception as e:
                print(f"Redis PuzzleLeaderboard db load failed: {e}")

        with self._lock:
            self._scores[contest_id] = {}
            for att in attempts:
                name = att.user.name or att.user.phone
                self._scores[contest_id][att.user_id] = (att.score, att.completion_seconds, att.submitted_at, name)


puzzle_leaderboard_manager = PuzzleLeaderboardManager()


class FruitLeaderboardManager:
    def __init__(self):
        self._lock = threading.Lock()
        self._scores: Dict[int, Dict[int, tuple]] = {}

    def _calculate_redis_score(self, score: int, combo: int, misses: int, submitted_at: datetime) -> float:
        combo_val = min(max(0, int(combo)), 9999)
        combo_factor = combo_val / 10000.0
        miss_val = min(max(0, int(misses)), 9999)
        miss_factor = (10000.0 - miss_val) / 100000000.0
        ts_val = max(0.0, float(submitted_at.timestamp()) - 1700000000.0)
        ts_factor = (1000000000.0 - ts_val) / 1000000000.0
        return float(score) + combo_factor + miss_factor + (ts_factor / 100000000000.0)

    def update_score(self, contest_id: int, user_id: int, name: str, score: int, max_combo: int, miss_count: int, submitted_at: datetime):
        if redis_is_active:
            try:
                zset_key = f"leaderboard:fruit:{contest_id}"
                meta_key = f"leaderboard:fruit:{contest_id}:meta"
                redis_score = self._calculate_redis_score(score, max_combo, miss_count, submitted_at)
                
                redis_client_sync.zadd(zset_key, {str(user_id): redis_score})
                redis_client_sync.hset(meta_key, str(user_id), json.dumps({
                    "name": name,
                    "score": score,
                    "max_combo": max_combo,
                    "miss_count": miss_count,
                    "submitted_at": submitted_at.isoformat()
                }))
                redis_client_sync.expire(zset_key, 86400)
                redis_client_sync.expire(meta_key, 86400)
                return
            except Exception as e:
                print(f"Redis FruitLeaderboard update failed: {e}")

        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            existing = self._scores[contest_id].get(user_id)
            is_better = False
            if not existing:
                is_better = True
            else:
                ext_score, ext_combo, ext_misses, ext_time, _ = existing
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
        if redis_is_active:
            try:
                zset_key = f"leaderboard:fruit:{contest_id}"
                meta_key = f"leaderboard:fruit:{contest_id}:meta"
                
                raw_members = redis_client_sync.zrevrange(zset_key, 0, 99, withscores=True)
                if raw_members:
                    user_ids = [m[0] for m in raw_members]
                    metadata_list = redis_client_sync.hmget(meta_key, user_ids)
                    leaderboard = []
                    for rank, (user_id, _), meta_str in zip(range(1, len(raw_members)+1), raw_members, metadata_list):
                        if meta_str:
                            meta = json.loads(meta_str)
                            leaderboard.append({
                                "user_id": int(user_id),
                                "name": meta["name"],
                                "score": meta["score"],
                                "max_combo": meta["max_combo"],
                                "miss_count": meta["miss_count"],
                                "rank": rank
                            })
                    return leaderboard
            except Exception as e:
                print(f"Redis FruitLeaderboard read failed: {e}")

        with self._lock:
            if contest_id not in self._scores:
                return []
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
        if redis_is_active:
            try:
                zset_key = f"leaderboard:fruit:{contest_id}"
                meta_key = f"leaderboard:fruit:{contest_id}:meta"
                redis_client_sync.delete(zset_key, meta_key)
                
                pipeline = redis_client_sync.pipeline()
                for s in scores:
                    name = s.user.name or s.user.phone
                    redis_score = self._calculate_redis_score(s.score, s.max_combo, s.miss_count, s.created_at)
                    pipeline.zadd(zset_key, {str(s.user_id): redis_score})
                    pipeline.hset(meta_key, str(s.user_id), json.dumps({
                        "name": name,
                        "score": s.score,
                        "max_combo": s.max_combo,
                        "miss_count": s.miss_count,
                        "submitted_at": s.created_at.isoformat()
                    }))
                pipeline.expire(zset_key, 86400)
                pipeline.expire(meta_key, 86400)
                pipeline.execute()
                return
            except Exception as e:
                print(f"Redis FruitLeaderboard db load failed: {e}")

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


fruit_leaderboard_manager = FruitLeaderboardManager()


class WordLeaderboardManager:
    def __init__(self):
        self._lock = threading.Lock()
        # Format: {contest_id: {user_id: (score, completion_time, user_name)}}
        self._scores: Dict[int, Dict[int, tuple]] = {}

    def _calculate_redis_score(self, score: int, completion_time: float, submitted_at: datetime) -> float:
        comp_val = min(max(0.0, float(completion_time or 0.0)), 99999.0)
        comp_factor = (100000.0 - comp_val) / 100000.0
        ts_val = max(0.0, float(submitted_at.timestamp()) - 1700000000.0)
        ts_factor = (1000000000.0 - ts_val) / 1000000000.0
        return float(score) + (comp_factor / 10.0) + (ts_factor / 100000000000.0)

    def update_score(self, contest_id: int, user_id: int, name: str, score: int, completion_time: float, submitted_at: datetime = None):
        if submitted_at is None:
            submitted_at = datetime.now(timezone.utc)
        if redis_is_active:
            try:
                zset_key = f"leaderboard:word:{contest_id}"
                meta_key = f"leaderboard:word:{contest_id}:meta"
                redis_score = self._calculate_redis_score(score, completion_time, submitted_at)
                
                redis_client_sync.zadd(zset_key, {str(user_id): redis_score})
                redis_client_sync.hset(meta_key, str(user_id), json.dumps({
                    "name": name,
                    "score": score,
                    "completion_time": completion_time or 0.0,
                    "submitted_at": submitted_at.isoformat()
                }))
                redis_client_sync.expire(zset_key, 86400)
                redis_client_sync.expire(meta_key, 86400)
                return
            except Exception as e:
                print(f"Redis WordLeaderboard update failed: {e}")

        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            existing = self._scores[contest_id].get(user_id)
            if not existing or score > existing[0] or (score == existing[0] and (completion_time or 0.0) < existing[1]):
                self._scores[contest_id][user_id] = (score, completion_time or 0.0, name)

    def get_leaderboard(self, contest_id: int) -> List[dict]:
        if redis_is_active:
            try:
                zset_key = f"leaderboard:word:{contest_id}"
                meta_key = f"leaderboard:word:{contest_id}:meta"
                
                raw_members = redis_client_sync.zrevrange(zset_key, 0, 99, withscores=True)
                if raw_members:
                    user_ids = [m[0] for m in raw_members]
                    metadata_list = redis_client_sync.hmget(meta_key, user_ids)
                    leaderboard = []
                    for rank, (user_id, _), meta_str in zip(range(1, len(raw_members)+1), raw_members, metadata_list):
                        if meta_str:
                            meta = json.loads(meta_str)
                            leaderboard.append({
                                "user_id": int(user_id),
                                "name": meta["name"],
                                "score": meta["score"],
                                "completion_time_seconds": meta["completion_time"],
                                "rank": rank
                            })
                    return leaderboard
            except Exception as e:
                print(f"Redis WordLeaderboard read failed: {e}")

        with self._lock:
            if contest_id not in self._scores:
                return []
            sorted_players = sorted(
                self._scores[contest_id].items(),
                key=lambda x: (-x[1][0], x[1][1])
            )
            leaderboard = []
            for rank, (u_id, (score, comp_time, name)) in enumerate(sorted_players, start=1):
                leaderboard.append({
                    "user_id": u_id,
                    "name": name,
                    "score": score,
                    "completion_time_seconds": comp_time,
                    "rank": rank
                })
            return leaderboard

    def load_from_db(self, db: Session, contest_id: int):
        from app.models import WordAttempt, User
        attempts = (
            db.query(WordAttempt)
            .join(User, WordAttempt.user_id == User.id)
            .filter(WordAttempt.contest_id == contest_id, WordAttempt.status == "SUBMITTED")
            .all()
        )
        if redis_is_active:
            try:
                zset_key = f"leaderboard:word:{contest_id}"
                meta_key = f"leaderboard:word:{contest_id}:meta"
                redis_client_sync.delete(zset_key, meta_key)
                
                pipeline = redis_client_sync.pipeline()
                for att in attempts:
                    name = att.user.name or att.user.phone
                    sub_at = att.submitted_at or att.created_at or datetime.now(timezone.utc)
                    redis_score = self._calculate_redis_score(att.total_score, att.completion_time_seconds, sub_at)
                    pipeline.zadd(zset_key, {str(att.user_id): redis_score})
                    pipeline.hset(meta_key, str(att.user_id), json.dumps({
                        "name": name,
                        "score": att.total_score,
                        "completion_time": att.completion_time_seconds or 0.0,
                        "submitted_at": sub_at.isoformat()
                    }))
                pipeline.expire(zset_key, 86400)
                pipeline.expire(meta_key, 86400)
                pipeline.execute()
                return
            except Exception as e:
                print(f"Redis WordLeaderboard db load failed: {e}")

        with self._lock:
            self._scores[contest_id] = {}
            for att in attempts:
                name = att.user.name or att.user.phone
                self._scores[contest_id][att.user_id] = (
                    att.total_score,
                    att.completion_time_seconds or 0.0,
                    name
                )


word_leaderboard_manager = WordLeaderboardManager()


class ArrowLeaderboardManager:
    def __init__(self):
        self._lock = threading.Lock()
        self._scores: Dict[int, Dict[int, tuple]] = {}

    def _calculate_redis_score(self, score: int, duration: float, submitted_at: datetime) -> float:
        dur_val = min(max(0.0, float(duration)), 99999.0)
        dur_factor = (100000.0 - dur_val) / 100000.0
        ts_val = max(0.0, float(submitted_at.timestamp()) - 1700000000.0)
        ts_factor = (1000000000.0 - ts_val) / 1000000000.0
        return float(score) + (dur_factor / 10.0) + (ts_factor / 100000000000.0)

    def update_score(self, contest_id: int, user_id: int, name: str, score: int, duration: float):
        now = datetime.now(timezone.utc)
        if redis_is_active:
            try:
                zset_key = f"leaderboard:arrow:{contest_id}"
                meta_key = f"leaderboard:arrow:{contest_id}:meta"
                redis_score = self._calculate_redis_score(score, duration, now)
                
                redis_client_sync.zadd(zset_key, {str(user_id): redis_score})
                redis_client_sync.hset(meta_key, str(user_id), json.dumps({
                    "name": name,
                    "score": score,
                    "duration": duration,
                    "submitted_at": now.isoformat()
                }))
                redis_client_sync.expire(zset_key, 86400)
                redis_client_sync.expire(meta_key, 86400)
                return
            except Exception as e:
                print(f"Redis ArrowLeaderboard update failed: {e}")
                
        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            existing = self._scores[contest_id].get(user_id)
            if not existing or score > existing[0] or (score == existing[0] and duration < existing[1]):
                self._scores[contest_id][user_id] = (score, duration, now, name)

    def get_leaderboard(self, contest_id: int) -> List[dict]:
        if redis_is_active:
            try:
                zset_key = f"leaderboard:arrow:{contest_id}"
                meta_key = f"leaderboard:arrow:{contest_id}:meta"
                
                raw_members = redis_client_sync.zrevrange(zset_key, 0, 99, withscores=True)
                if raw_members:
                    user_ids = [m[0] for m in raw_members]
                    metadata_list = redis_client_sync.hmget(meta_key, user_ids)
                    leaderboard = []
                    for rank, (user_id, _), meta_str in zip(range(1, len(raw_members)+1), raw_members, metadata_list):
                        if meta_str:
                            meta = json.loads(meta_str)
                            leaderboard.append({
                                "user_id": int(user_id),
                                "name": meta["name"],
                                "score": meta["score"],
                                "rank": rank,
                                "completion_seconds": meta["duration"]
                            })
                    return leaderboard
            except Exception as e:
                print(f"Redis ArrowLeaderboard read failed: {e}")

        with self._lock:
            if contest_id not in self._scores:
                return []
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
        from app.models import ArrowAttempt, User
        attempts = (
            db.query(ArrowAttempt)
            .join(User)
            .filter(ArrowAttempt.contest_id == contest_id)
            .filter(ArrowAttempt.status == "VERIFIED")
            .all()
        )
        if redis_is_active:
            try:
                zset_key = f"leaderboard:arrow:{contest_id}"
                meta_key = f"leaderboard:arrow:{contest_id}:meta"
                redis_client_sync.delete(zset_key, meta_key)
                
                pipeline = redis_client_sync.pipeline()
                for att in attempts:
                    name = att.user.name or att.user.phone
                    redis_score = self._calculate_redis_score(att.score, att.completion_seconds, att.submitted_at)
                    pipeline.zadd(zset_key, {str(att.user_id): redis_score})
                    pipeline.hset(meta_key, str(att.user_id), json.dumps({
                        "name": name,
                        "score": att.score,
                        "duration": att.completion_seconds,
                        "submitted_at": att.submitted_at.isoformat()
                    }))
                pipeline.expire(zset_key, 86400)
                pipeline.expire(meta_key, 86400)
                pipeline.execute()
                return
            except Exception as e:
                print(f"Redis ArrowLeaderboard db load failed: {e}")

        with self._lock:
            self._scores[contest_id] = {}
            for att in attempts:
                name = att.user.name or att.user.phone
                self._scores[contest_id][att.user_id] = (att.score, att.completion_seconds, att.submitted_at, name)


arrow_leaderboard_manager = ArrowLeaderboardManager()

