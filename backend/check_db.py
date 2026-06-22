import json
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models import User, WalletTransaction, Spin as SpinModel

DATABASE_URL = "postgresql://dailyearn_db_user:ChooseAStrongDBPasswordHere!@localhost:5432/dailyearn_db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

try:
    user = db.query(User).filter(User.id == 26).first()
    if not user:
        print("User 26 not found in DB.")
    else:
        print(f"=== User Profile (ID: 26) ===")
        print(f"Name: {user.name}")
        print(f"Phone: {user.phone}")
        print(f"Deposit Balance: {user.deposit_balance}")
        print(f"Winning Balance: {user.winning_balance}")
        print(f"Bonus Balance: {user.bonus_balance}")
        print(f"KYC Status: {user.kyc_status}")
        
        # Get all transactions
        txs = db.query(WalletTransaction).filter(WalletTransaction.user_id == 26).order_by(WalletTransaction.id.asc()).all()
        print(f"\n=== Wallet Transactions ({len(txs)}) ===")
        for tx in txs:
            print(f"#{tx.id} | Type: {tx.type} | Amount: {tx.amount} | Status: {tx.status} | Description: {tx.description} | Created: {tx.created_at}")
            
        # Get all spins
        spins = db.query(SpinModel).filter(SpinModel.user_id == 26).order_by(SpinModel.id.asc()).all()
        print(f"\n=== Spins in DB ({len(spins)}) ===")
        for s in spins:
            print(f"#{s.id} | Bet: {s.bet_amount} | Win: {s.win_amount} | Mult: {s.multiplier} | Segment: {s.wheel_segment} | Result: {s.result_type} | Created: {s.created_at}")

finally:
    db.close()
