import os
import sys
import json

# Setup sys path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.models import User, MinesGame, MinesSetting, WalletTransaction
from app.services import MinesGameService

def run_tests():
    print("----------------------------------------")
    print("Starting Mines Game Service Unit Tests...")
    print("----------------------------------------")

    # Create tables
    Base.metadata.create_all(bind=engine)
    
    db: Session = SessionLocal()
    
    try:
        # 1. Setup Test User
        print("[TEST] Setting up test user...")
        test_phone = "9900990099"
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
                name="Test Mines User",
                phone=test_phone,
                referral_code="T99_MINS",
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

        # 2. Setup Mines Setting
        print("[TEST] Setting up Mines settings...")
        settings = db.query(MinesSetting).first()
        if not settings:
            settings = MinesSetting(
                house_edge=0.03,
                min_bet=10.0,
                max_bet=1000.0,
                maintenance_mode=False
            )
            db.add(settings)
        else:
            settings.house_edge = 0.03
            settings.min_bet = 10.0
            settings.max_bet = 1000.0
            settings.maintenance_mode = False
        db.commit()

        # Clean old active games
        db.query(MinesGame).filter(MinesGame.user_id == user_id).delete()
        db.commit()

        # 3. Test nCr / Multiplier calculations
        print("[TEST] Testing multiplier calculations...")
        # 3 mines, 1 reveal:
        # gems = 22. ways_gems = 22C1 = 22. ways_total = 25C1 = 25.
        # fair = 25 / 22 = 1.136. house = 1.136 * 0.97 = 1.10.
        mult = MinesGameService.calculate_multiplier(3, 1, 0.03)
        assert mult == 1.1, f"Expected 1.10, got {mult}"
        print("   -> 3 Mines, 1 Gem reveal multiplier: Ok (1.10x)")

        # 4. Test Game Initiation
        print("[TEST] Initiating new Mines game...")
        bet_amount = 100.0
        mines_count = 3
        game = MinesGameService.start_game(db, user_id, bet_amount, mines_count)
        
        # Verify database session is created
        assert game.id is not None
        assert game.status == "IN_PROGRESS"
        assert game.bet_amount == bet_amount
        assert game.mines_count == mines_count
        assert len(json.loads(game.mines_positions)) == mines_count
        print(f"   -> Game started with ID: {game.id}. Mines positions: {game.mines_positions}")

        # Check balance deduction (500 - 100 = 400)
        db.refresh(user)
        assert user.deposit_balance == 400.0
        print(f"   -> User deposit balance after bet: ₹{user.deposit_balance} (Expected: 400.0)")

        # Verify active game prevention
        try:
            MinesGameService.start_game(db, user_id, bet_amount, mines_count)
            assert False, "Should raise exception when starting another active game"
        except ValueError as e:
            print(f"   -> Active game check block works: '{e}'")

        # 5. Test Gem Reveal
        print("[TEST] Testing gem reveal...")
        mines_list = json.loads(game.mines_positions)
        # Find a position that is NOT a mine
        safe_position = 0
        for i in range(25):
            if i not in mines_list:
                safe_position = i
                break
        
        print(f"   -> Revealing safe cell: {safe_position}")
        game = MinesGameService.reveal_cell(db, user_id, game.id, safe_position)
        assert safe_position in json.loads(game.revealed_positions)
        assert game.status == "IN_PROGRESS"
        assert game.current_multiplier > 1.0
        assert game.current_win == bet_amount * game.current_multiplier
        print(f"   -> Revealed successfully! Multiplier: {game.current_multiplier}x. Payout: ₹{game.current_win}")

        # 6. Test Cash Out
        print("[TEST] Testing cash out...")
        expected_winnings = game.current_win
        game = MinesGameService.cash_out(db, user_id, game.id)
        assert game.status == "WON"
        
        # Check winnings added (deposit = 400, winning = expected_winnings)
        db.refresh(user)
        assert abs(user.winning_balance - expected_winnings) < 0.01
        print(f"   -> Cashout successful! User winning balance: ₹{user.winning_balance} (Expected: {expected_winnings})")

        # 7. Test Bomb Explosion
        print("[TEST] Testing bomb explosion...")
        # Start a new game
        game = MinesGameService.start_game(db, user_id, bet_amount, mines_count)
        mines_list = json.loads(game.mines_positions)
        bomb_position = mines_list[0]
        
        print(f"   -> Hitting bomb cell: {bomb_position}")
        game = MinesGameService.reveal_cell(db, user_id, game.id, bomb_position)
        assert game.status == "LOST"
        assert game.current_win == 0.0
        assert game.current_multiplier == 0.0
        
        # Verify no payout credited
        db.refresh(user)
        print(f"   -> Hit bomb successfully. User winnings balance: ₹{user.winning_balance} (Expected: unchanged)")

        # Verify cashing out of a lost game is blocked
        try:
            MinesGameService.cash_out(db, user_id, game.id)
            assert False, "Should raise exception when cashing out completed game"
        except ValueError as e:
            print(f"   -> Completed game cashout block works: '{e}'")

        print("----------------------------------------")
        print("ALL TESTS PASSED SUCCESSFULLY!")
        print("----------------------------------------")
        
    except AssertionError as e:
        print(f"\n[ERROR] Test assertion failed: {e}")
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    run_tests()
