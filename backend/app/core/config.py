import os
from dotenv import load_dotenv

# Load environment variables from .env file using its absolute path
# This ensures it loads successfully regardless of uvicorn's working directory
backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
env_path = os.path.join(backend_dir, ".env")
load_dotenv(dotenv_path=env_path)

class Settings:
    PROJECT_NAME: str = "target99"
    API_V1_STR: str = "/api"
    SECRET_KEY: str = os.getenv("SECRET_KEY", "target99_super_secret_signing_key_for_jwt_tokens_2026")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60  # 1 hour
    
    # Database path (defaults to local SQLite if not configured)
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./db.sqlite3")
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)
    
    # URL-encode password if it contains special characters
    if DATABASE_URL.startswith("postgresql"):
        from urllib.parse import urlparse, urlunparse, quote_plus
        try:
            # Check if password is already percent-encoded
            parsed = urlparse(DATABASE_URL)
            if parsed.password:
                # quote_plus encodes special characters, but we only apply it if it hasn't been encoded yet
                if "%" not in parsed.password:
                    encoded_password = quote_plus(parsed.password)
                    new_netloc = parsed.username or ""
                    if encoded_password:
                        new_netloc += f":{encoded_password}"
                    new_netloc += f"@{parsed.hostname}"
                    if parsed.port:
                        new_netloc += f":{parsed.port}"
                    DATABASE_URL = urlunparse(parsed._replace(netloc=new_netloc))
        except Exception as e:
            print(f"Warning: Failed to parse/encode DATABASE_URL password: {e}")
            
    # Admin credentials
    ADMIN_USERNAME: str = os.getenv("ADMIN_USERNAME", "admin")
    ADMIN_PASSWORD: str = os.getenv("ADMIN_PASSWORD", "admin99")
    
    # Razorpay Keys
    RAZORPAY_KEY_ID: str = os.getenv("RAZORPAY_KEY_ID", "rzp_test_mockkey12345")
    RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "mocksecret12345")
    
    # Redis Configuration
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
settings = Settings()
