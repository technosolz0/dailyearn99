import os
import sys
import json
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.models import User, BlackjackGame, BlackjackSetting, WalletTransaction
from app.api.blackjack_game import (
    start_blackjack,
    blackjack_hit,
    blackjack_stand,
    calculate_hand_value
)
from app.schemas import BlackjackStartRequest

# Add directory to python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def run_simulation():
    print("----------------------------------------")
    print("Starting Blackjack Game Rigging Simulation...")
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
            user.deposit_balance = 50000.0
            user.winning_balance = 0.0
            user.bonus_balance = 0.0
            user.is_banned = False
            user.kyc_status = "VERIFIED"
        else:
            user = User(
                name="Test Blackjack User",
                phone=test_phone,
                referral_code="T99_BJK",
                deposit_balance=50000.0,
                winning_balance=0.0,
                bonus_balance=0.0,
                kyc_status="VERIFIED",
                is_banned=False
            )
            db.add(user)
        db.commit()
        db.refresh(user)
        user_id = user.id
        print(f"Test user ID: {user_id}. Starting Balance: ₹{user.deposit_balance}")

        # 2. Setup Blackjack Setting
        print("[TEST] Setting up Blackjack settings...")
        settings = db.query(BlackjackSetting).first()
        if not settings:
            settings = BlackjackSetting(
                min_bet=10.0,
                max_bet=50000.0,
                winning_percentage=15.0,
                maintenance_mode=False
            )
            db.add(settings)
        else:
            settings.winning_percentage = 15.0
            settings.min_bet = 10.0
            settings.max_bet = 50000.0
            settings.maintenance_mode = False
        db.commit()

        # Clean old active games
        db.query(BlackjackGame).filter(BlackjackGame.user_id == user_id).delete()
        db.commit()

        def play_one_game(target_outcome: str):
            # Force target outcome by temporarily changing database setting or overriding the game row target
            # Start game
            req = BlackjackStartRequest(bet_amount=100.0)
            game_res = start_blackjack(req, db, user)
            
            # Since start_blackjack picks target_outcome randomly based on settings, 
            # we manually override target_outcome on the created game object to test specific outcomes.
            game = db.query(BlackjackGame).filter(BlackjackGame.id == game_res.id).first()
            game.target_outcome = target_outcome
            db.commit()
            
            # If game completed immediately (e.g. natural blackjack)
            if game.status == "COMPLETED":
                return game.win_amount, game.hand_1_status

            # Simple AI strategy: hit on < 17, stand on >= 17
            while game.status == "IN_PROGRESS":
                hand = json.loads(game.player_hand_1)
                val = calculate_hand_value(hand)
                if val < 17:
                    # hit
                    blackjack_hit({"game_id": game.id}, db, user)
                    db.refresh(game)
                else:
                    # stand
                    blackjack_stand({"game_id": game.id}, db, user)
                    db.refresh(game)
            
            return game.win_amount, game.hand_1_status

        # 3. Simulate 100 LOSS games
        print("\n[SIMULATION] Running 100 LOSS games...")
        loss_winnings = []
        loss_statuses = {}
        for i in range(100):
            # Clean old active games to avoid "active game in progress" error
            db.query(BlackjackGame).filter(BlackjackGame.user_id == user_id).delete()
            db.commit()
            
            win_amount, status = play_one_game("LOSS")
            loss_winnings.append(win_amount)
            loss_statuses[status] = loss_statuses.get(status, 0) + 1

        print(f"LOSS Outcomes: {loss_statuses}")
        print(f"Total wins (amount > 0) in LOSS target: {sum(1 for w in loss_winnings if w > 100.0)}")
        print(f"Total pushes (amount == bet) in LOSS target: {sum(1 for w in loss_winnings if w == 100.0)}")
        print(f"Total losses (amount == 0) in LOSS target: {sum(1 for w in loss_winnings if w == 0.0)}")
        
        # Verify user did not win any money
        user_wins = sum(1 for w in loss_winnings if w > 100.0)
        assert user_wins == 0, f"Expected 0 user wins under LOSS, but got {user_wins}"
        
        # 4. Simulate 100 WIN games
        print("\n[SIMULATION] Running 100 WIN games...")
        win_winnings = []
        win_statuses = {}
        for i in range(100):
            db.query(BlackjackGame).filter(BlackjackGame.user_id == user_id).delete()
            db.commit()
            
            win_amount, status = play_one_game("WIN")
            win_winnings.append(win_amount)
            win_statuses[status] = win_statuses.get(status, 0) + 1

        print(f"WIN Outcomes: {win_statuses}")
        print(f"Total wins (amount > 0) in WIN target: {sum(1 for w in win_winnings if w > 100.0)}")
        print(f"Total pushes (amount == bet) in WIN target: {sum(1 for w in win_winnings if w == 100.0)}")
        print(f"Total losses (amount == 0) in WIN target: {sum(1 for w in win_winnings if w == 0.0)}")
        
        # Verify user win rate is very high (losses should be 0 or extremely close to 0)
        user_losses = sum(1 for w in win_winnings if w == 0.0)
        assert user_losses == 0, f"Expected 0 user losses under WIN, but got {user_losses}"

        print("\n----------------------------------------")
        print("ALL SIMULATIONS COMPLETED & VERIFIED SUCCESSFULLY!")
        print("----------------------------------------")

    except AssertionError as e:
        print(f"\n[ERROR] Test assertion failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    run_simulation()
