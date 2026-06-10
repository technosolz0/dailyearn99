import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal
from app.models import User, Spin, SpinAuditLog
from app.services import SpinGameService

db = SessionLocal()
try:
    user = db.query(User).filter(User.phone == "9876543210").first()
    if not user:
        print("User 9876543210 not found. Let's create one or use the first user.")
        user = db.query(User).first()
    
    if not user:
        print("No users found at all!")
    else:
        print(f"Testing spin with User: {user.name} ({user.phone}), Deposit: {user.deposit_balance}, Winnings: {user.winning_balance}, Bonus: {user.bonus_balance}")
        
        # Give some balance just in case
        user.deposit_balance = max(user.deposit_balance, 100.0)
        db.commit()
        
        # Run execute_spin
        import uuid
        idempotency_key = str(uuid.uuid4())
        print(f"Executing spin with bet = 10, idempotency = {idempotency_key}...")
        spin = SpinGameService.execute_spin(
            db=db,
            user_id=user.id,
            bet_amount=10.0,
            idempotency_key=idempotency_key,
            device_id="test_device",
            ip_address="127.0.0.1"
        )
        print(f"Spin execution succeeded! Result: {spin.result_type}, Multiplier: {spin.multiplier}, Win amount: {spin.win_amount}")
        
        # Verify in DB
        spin_in_db = db.query(Spin).filter(Spin.id == spin.id).first()
        if spin_in_db:
            print(f"SUCCESS: Spin was saved in DB! ID: {spin_in_db.id}, Bet: {spin_in_db.bet_amount}, Result: {spin_in_db.result_type}")
        else:
            print("FAILURE: Spin was NOT found in DB!")
            
        audit_in_db = db.query(SpinAuditLog).filter(SpinAuditLog.user_id == user.id).order_by(SpinAuditLog.created_at.desc()).first()
        if audit_in_db:
            print(f"SUCCESS: Audit Log was saved in DB! ID: {audit_in_db.id}")
        else:
            print("FAILURE: Audit Log was NOT found in DB!")
finally:
    db.close()
