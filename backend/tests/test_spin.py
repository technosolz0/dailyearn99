import uuid
import random
import pytest
from app.models import User, Spin, SpinAuditLog
from app.services import SpinGameService

def test_spin_game_service_basics(db_session):
    test_phone = "9876543210"
    user = db_session.query(User).filter(User.phone == test_phone).first()
    if not user:
        user = User(
            name="Basics Spin User",
            phone=test_phone,
            referral_code="BASSPIN",
            deposit_balance=500.0,
            winning_balance=0.0,
            bonus_balance=0.0
        )
        db_session.add(user)
        db_session.commit()
        db_session.refresh(user)

    user.deposit_balance = max(user.deposit_balance, 100.0)
    db_session.commit()
    
    idempotency_key = str(uuid.uuid4())
    spin = SpinGameService.execute_spin(
        db=db_session,
        user_id=user.id,
        bet_amount=10.0,
        idempotency_key=idempotency_key,
        device_id="test_device",
        ip_address="127.0.0.1"
    )
    assert spin.id is not None
    assert spin.bet_amount == 10.0
    
    spin_in_db = db_session.query(Spin).filter(Spin.id == spin.id).first()
    assert spin_in_db is not None
    
    audit_in_db = db_session.query(SpinAuditLog).filter(SpinAuditLog.user_id == user.id).order_by(SpinAuditLog.created_at.desc()).first()
    assert audit_in_db is not None


def test_spin_first_time_forced_outcome(db_session):
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
    db_session.add(user1)
    db_session.commit()
    db_session.refresh(user1)
    
    idempotency1 = str(uuid.uuid4())
    spin1 = SpinGameService.execute_spin(
        db=db_session,
        user_id=user1.id,
        bet_amount=50.0,
        idempotency_key=idempotency1,
        device_id="test_device",
        ip_address="127.0.0.1"
    )
    
    assert abs(spin1.multiplier - 1.5) < 1e-4
    assert abs(spin1.win_amount - 75.0) < 1e-4

    # Verify second spin (should NOT be forced)
    idempotency2 = str(uuid.uuid4())
    spin2 = SpinGameService.execute_spin(
        db=db_session,
        user_id=user1.id,
        bet_amount=50.0,
        idempotency_key=idempotency2,
        device_id="test_device",
        ip_address="127.0.0.1"
    )
    assert spin2.id is not None

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
    db_session.add(user2)
    db_session.commit()
    db_session.refresh(user2)
    
    idempotency3 = str(uuid.uuid4())
    spin3 = SpinGameService.execute_spin(
        db=db_session,
        user_id=user2.id,
        bet_amount=100.0,
        idempotency_key=idempotency3,
        device_id="test_device",
        ip_address="127.0.0.1"
    )
    
    assert abs(spin3.multiplier - 1.2) < 1e-4
    assert abs(spin3.win_amount - 120.0) < 1e-4
