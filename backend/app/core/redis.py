import redis
# pyrefly: ignore [missing-import]
import redis.asyncio as aioredis
import os
from app.core.config import settings

# Redis URLs
REDIS_URL = settings.REDIS_URL

# Async client (for WebSocket ConnectionManagers)
redis_client_async: aioredis.Redis = None
# Sync client (for LeaderboardManagers)
redis_client_sync: redis.Redis = None
redis_is_active: bool = False

def init_redis():
    global redis_client_async, redis_client_sync, redis_is_active
    try:
        # Sync client setup and verification
        redis_client_sync = redis.Redis.from_url(REDIS_URL, decode_responses=True)
        redis_client_sync.ping()
        
        # Async client setup
        redis_client_async = aioredis.Redis.from_url(REDIS_URL, decode_responses=True)
        
        redis_is_active = True
        print(f"Redis Connection Established (Sync & Async): {REDIS_URL}")
    except Exception as e:
        redis_is_active = False
        redis_client_sync = None
        redis_client_async = None
        print(f"Redis connection failed: {e}")
        print("FastAPI will run WebSockets and Leaderboards in IN-MEMORY FALLBACK mode.")
