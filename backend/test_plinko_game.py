import os
import sys
import json

# Setup sys path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.models import User, PlinkoGame, PlinkoSetting, PlinkoMultiplier, PlinkoRTP, WalletTransaction
from app.services import PlinkoGameService


def run_tests():
    print("----------------------------------------")
    print("Starting Plinko Game Service Unit Tests...")
    print("----------------------------------------")

    # Create tables
    Base.metadata.create_all(bind=engine)

    db: Session = SessionLocal()

    try:
        # 1. Setup Test User
        print("[TEST] Setting up test user...")
        test_phone = "9988998899"
        user = db.query(User).filter(User.phone == test_phone).first()
        if user:
            # reset balance
            user.deposit_balance = 500.0
            user.winning_balance = 0.0
            user.bonus_balance = 0.0
            user.is_banned = False
            user.kyc_status = "VERIFIED"
        else:
            user = User(
                name="Test Plinko User",
                phone=test_phone,
                referral_code="T99_PLNK",
                deposit_balance=500.0,
                winning_balance=0.0,
                bonus_balance=0.0,
                kyc_status="VERIFIED",
                is_banned=False
            )
            db.add(user)
        db.commit()
        db.refresh(user)
        user_id = user.id
        print(f"Test user ID: {user_id}. Starting Deposit: ₹{user.deposit_balance}")

        # 2. Setup Plinko Setting
        print("[TEST] Setting up Plinko settings...")
        settings = db.query(PlinkoSetting).first()
        if not settings:
            settings = PlinkoSetting(
                min_bet=10.0,
                max_bet=1000.0,
                maintenance_mode=False
            )
            db.add(settings)
        else:
            settings.min_bet = 10.0
            settings.max_bet = 1000.0
            settings.maintenance_mode = False
        db.commit()

        # Clean old Plinko games
        db.query(PlinkoGame).filter(PlinkoGame.user_id == user_id).delete()
        db.commit()

        # 3. Test Plinko Play with Default Multipliers
        print("[TEST] Playing standard Plinko (R=10, Medium)...")
        bet_amount = 50.0
        rows = 10
        mode = "medium"
        
        # Verify first-play works
        game = PlinkoGameService.play_plinko(db, user_id, bet_amount, rows, mode)
        assert game.id is not None
        assert game.rows == rows
        assert game.mode == mode
        assert game.bet_amount == bet_amount
        path = json.loads(game.path)
        assert len(path) == rows
        assert sum(path) == game.final_bucket
        print(f"   -> Plinko game created with ID: {game.id}. Path: {path}. Landing bucket: {game.final_bucket}")
        
        # Verify balance deduction: 500 - 50 = 450
        db.refresh(user)
        expected_deposit = 450.0
        assert abs(user.deposit_balance - expected_deposit) < 0.01, f"Expected 450.0, got {user.deposit_balance}"
        
        # Verify winnings match bet * multiplier
        expected_winnings = bet_amount * game.multiplier
        assert abs(user.winning_balance - expected_winnings) < 0.01
        print(f"   -> Winnings payout matched exactly: ₹{user.winning_balance} (Multiplier: {game.multiplier}x)")

        # 4. Test Plinko Multiplier Override
        print("[TEST] Overriding multipliers for Row 10 Medium...")
        custom_mults = [1.0, 1.0, 1.0, 1.0, 1.0, 50.0, 1.0, 1.0, 1.0, 1.0, 1.0] # 50x in center
        override = db.query(PlinkoMultiplier).filter(
            PlinkoMultiplier.rows == 10,
            PlinkoMultiplier.mode == "medium"
        ).first()
        if not override:
            override = PlinkoMultiplier(rows=10, mode="medium")
            db.add(override)
        override.multipliers_json = json.dumps(custom_mults)
        db.commit()

        # Play Plinko again and check if it uses custom multipliers
        game = PlinkoGameService.play_plinko(db, user_id, bet_amount, rows, mode)
        assert game.multiplier == custom_mults[game.final_bucket]
        print(f"   -> Custom multiplier override applied: landed on bucket {game.final_bucket} with multiplier {game.multiplier}x")

        # 5. Test Plinko RTP override (forcing path landing)
        print("[TEST] Overriding RTP probability weights (forcing center landing)...")
        # For Row 10, bucket 5 (center) gets 100% probability
        prob_override = {str(i): 0.0 for i in range(11)}
        prob_override["5"] = 100.0
        
        rtp = db.query(PlinkoRTP).filter(
            PlinkoRTP.min_amount <= bet_amount,
            PlinkoRTP.max_amount >= bet_amount,
            PlinkoRTP.rows == 10,
            PlinkoRTP.mode == "medium"
        ).first()
        if not rtp:
            rtp = PlinkoRTP(
                min_amount=1.0,
                max_amount=1000.0,
                rows=10,
                mode="medium"
            )
            db.add(rtp)
        rtp.probability_json = json.dumps(prob_override)
        rtp.enabled = True
        db.commit()

        # Play Plinko again - should land EXACTLY on bucket 5
        game = PlinkoGameService.play_plinko(db, user_id, bet_amount, rows, mode)
        assert game.final_bucket == 5
        assert game.multiplier == 50.0 # From our custom multipliers override
        assert game.win_amount == bet_amount * 50.0
        print(f"   -> RTP override successfully forced landing on bucket 5! Multiplier: {game.multiplier}x. Win Amount: ₹{game.win_amount}")

        # Clean overrides to keep DB clean
        db.delete(override)
        db.delete(rtp)
        db.commit()

        print("----------------------------------------")
        print("ALL PLINKO TESTS PASSED SUCCESSFULLY!")
        print("----------------------------------------")

    except AssertionError as e:
        print(f"\n[ERROR] Test assertion failed: {e}")
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    run_tests()
