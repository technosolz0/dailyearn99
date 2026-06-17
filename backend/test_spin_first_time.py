import sys
import os
import uuid
import random

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal
from app.models import User, Spin, SpinAuditLog
from app.services import SpinGameService

def run_tests():
    db = SessionLocal()
    test_users = []
    try:
        # Test Case 1: First-time user with bet amount < 100 (should win exactly 1.5x)
        phone1 = f"99{random.randint(10000000, 99999999)}"
        user1 = User(
            name="First Spin User < 100",
            phone=phone1,
            referral_code=f"REF{random.randint(1000, 9999)}",
            deposit_balance=500.0,
            winning_balance=0.0,
            bonus_balance=0.0
        )
        db.add(user1)
        db.commit()
        db.refresh(user1)
        test_users.append(user1)
        
        print(f"Created Test User 1: ID {user1.id}, Phone {user1.phone}")
        
        # Verify first spin (bet = 50.0 < 100)
        idempotency1 = str(uuid.uuid4())
        print(f"Executing first spin for User 1 with bet = 50.0...")
        spin1 = SpinGameService.execute_spin(
            db=db,
            user_id=user1.id,
            bet_amount=50.0,
            idempotency_key=idempotency1,
            device_id="test_device",
            ip_address="127.0.0.1"
        )
        
        print(f"Result - Multiplier: {spin1.multiplier}, Win: {spin1.win_amount}")
        assert abs(spin1.multiplier - 1.5) < 1e-4, f"Expected multiplier 1.5, got {spin1.multiplier}"
        assert abs(spin1.win_amount - 75.0) < 1e-4, f"Expected win amount 75.0, got {spin1.win_amount}"
        print("✅ SUCCESS: First spin for < 100 bet correctly yielded 1.5x multiplier!")

        # Verify second spin (should NOT be forced)
        idempotency2 = str(uuid.uuid4())
        print("Executing second spin for User 1 with bet = 50.0 (should use normal probability)...")
        spin2 = SpinGameService.execute_spin(
            db=db,
            user_id=user1.id,
            bet_amount=50.0,
            idempotency_key=idempotency2,
            device_id="test_device",
            ip_address="127.0.0.1"
        )
        print(f"Result - Multiplier: {spin2.multiplier}, Win: {spin2.win_amount}")
        # Not asserting the exact value, since it's random, but confirming it ran.
        print("✅ SUCCESS: Second spin completed successfully using normal RTP logic!")

        # Test Case 2: First-time user with bet amount >= 100 (should win exactly 1.2x)
        phone2 = f"99{random.randint(10000000, 99999999)}"
        user2 = User(
            name="First Spin User >= 100",
            phone=phone2,
            referral_code=f"REF{random.randint(1000, 9999)}",
            deposit_balance=500.0,
            winning_balance=0.0,
            bonus_balance=0.0
        )
        db.add(user2)
        db.commit()
        db.refresh(user2)
        test_users.append(user2)
        
        print(f"Created Test User 2: ID {user2.id}, Phone {user2.phone}")
        
        # Verify first spin (bet = 100.0 >= 100)
        idempotency3 = str(uuid.uuid4())
        print(f"Executing first spin for User 2 with bet = 100.0...")
        spin3 = SpinGameService.execute_spin(
            db=db,
            user_id=user2.id,
            bet_amount=100.0,
            idempotency_key=idempotency3,
            device_id="test_device",
            ip_address="127.0.0.1"
        )
        
        print(f"Result - Multiplier: {spin3.multiplier}, Win: {spin3.win_amount}")
        assert abs(spin3.multiplier - 1.2) < 1e-4, f"Expected multiplier 1.2, got {spin3.multiplier}"
        assert abs(spin3.win_amount - 120.0) < 1e-4, f"Expected win amount 120.0, got {spin3.win_amount}"
        print("✅ SUCCESS: First spin for >= 100 bet correctly yielded 1.2x multiplier!")

    except Exception as e:
        print(f"❌ FAILURE: Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        raise e
    finally:
        # Cleanup test data
        print("Cleaning up test users and spins...")
        for u in test_users:
            db.query(SpinAuditLog).filter(SpinAuditLog.user_id == u.id).delete()
            db.query(Spin).filter(Spin.user_id == u.id).delete()
            db.delete(u)
        db.commit()
        db.close()

if __name__ == "__main__":
    run_tests()
