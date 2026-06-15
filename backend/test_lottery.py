import sys
import os
from datetime import datetime, timedelta, timezone

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal, Base, engine
from app.models import User, LotteryDraw, LotteryTicket, WalletTransaction
from app.services import LotteryService

def run_tests():
    print("Initializing test database tables...")
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        print("=== Starting Lottery System Validation Tests ===")

        # 1. Create a test user or find one
        user = db.query(User).filter(User.phone == "7777777777").first()
        if not user:
            print("Creating test user...")
            user = User(
                name="Lottery Tester",
                phone="7777777777",
                referral_code="LOTTOTEST",
                deposit_balance=100.0,
                winning_balance=50.0,
                bonus_balance=10.0,
                kyc_status="VERIFIED"
            )
            db.add(user)
            db.commit()
            db.refresh(user)

        print(f"User: {user.name}, Deposit Balance: ₹{user.deposit_balance}, Winning: ₹{user.winning_balance}")

        # 2. Reset user balances for deterministic tests
        user.deposit_balance = 100.0
        user.winning_balance = 50.0
        db.commit()

        # 3. Create a test Lottery Draw
        now = datetime.now(timezone.utc)
        draw = LotteryDraw(
            title="🎯 Lotto Test Draw",
            ticket_price=30.0,
            prize_pool=500.0,
            draw_time=now + timedelta(minutes=5),
            max_tickets=10,
            joined_tickets=0,
            status="OPEN"
        )
        db.add(draw)
        db.commit()
        db.refresh(draw)
        print(f"Created Draw: {draw.title}, Price: ₹{draw.ticket_price}, Pool: ₹{draw.prize_pool}, Max: {draw.max_tickets}")

        # 4. Test Ticket Purchase (Wallet Deduction)
        print("\n--- Testing Ticket Purchase ---")
        initial_deposit = user.deposit_balance
        initial_winnings = user.winning_balance

        ticket = LotteryService.buy_ticket(db, user.id, draw.id)
        db.refresh(user)
        db.refresh(draw)

        print(f"Purchased Ticket: {ticket.ticket_number}")
        print(f"User Balance after purchase: Deposit: ₹{user.deposit_balance}, Winning: ₹{user.winning_balance}")
        print(f"Draw slots: {draw.joined_tickets}/{draw.max_tickets}")

        # Assert correct deduction
        expected_deposit = initial_deposit - draw.ticket_price
        assert abs(user.deposit_balance - expected_deposit) < 1e-4, f"Expected deposit balance to be {expected_deposit}, got {user.deposit_balance}"
        assert draw.joined_tickets == 1, "Expected joined tickets count to be 1"

        # Verify transaction logs
        tx = db.query(WalletTransaction).filter(
            WalletTransaction.user_id == user.id,
            WalletTransaction.type == "ENTRY_FEE"
        ).order_by(WalletTransaction.created_at.desc()).first()
        assert tx is not None, "Transaction record not found"
        assert tx.amount == draw.ticket_price, "Incorrect transaction amount recorded"
        print("SUCCESS: Ticket purchase & wallet deduction verified!")

        # 5. Test Winner Selection & Prize Credits
        print("\n--- Testing Winner Drawing ---")
        draw_res = LotteryService.execute_draw(db, draw.id)
        print(f"Draw output: {draw_res}")

        db.refresh(draw)
        db.refresh(user)
        db.refresh(ticket)

        assert draw.status == "COMPLETED", "Draw status should be COMPLETED"
        assert draw.winning_number == ticket.ticket_number, "Winning ticket number mismatch"
        assert ticket.is_winner is True, "Ticket should be marked as winner"
        assert ticket.reward_amount == draw.prize_pool, "Reward amount mismatch"

        # Winner balance should be updated
        expected_winnings = initial_winnings + draw.prize_pool
        assert abs(user.winning_balance - expected_winnings) < 1e-4, f"Expected winner winnings balance to be {expected_winnings}, got {user.winning_balance}"

        # Verify winning transaction log
        tx_win = db.query(WalletTransaction).filter(
            WalletTransaction.user_id == user.id,
            WalletTransaction.type == "PRIZE_WIN"
        ).order_by(WalletTransaction.created_at.desc()).first()
        assert tx_win is not None, "Winning transaction log not found"
        assert tx_win.amount == draw.prize_pool, "Incorrect prize pool amount logged"
        print("SUCCESS: Winner selection & prize distribution verified!")

        # 6. Test Draw Cancellation & Refunds
        print("\n--- Testing Draw Cancellation & Refunds ---")
        # Create another draw
        cancel_draw = LotteryDraw(
            title="❌ Cancel Test Draw",
            ticket_price=20.0,
            prize_pool=200.0,
            draw_time=now + timedelta(minutes=10),
            max_tickets=5,
            joined_tickets=0,
            status="OPEN"
        )
        db.add(cancel_draw)
        db.commit()
        db.refresh(cancel_draw)

        # Buy ticket for this new draw
        user.deposit_balance = 50.0
        db.commit()
        
        cancel_ticket = LotteryService.buy_ticket(db, user.id, cancel_draw.id)
        db.refresh(user)
        db.refresh(cancel_draw)
        
        print(f"Purchased ticket for cancel test: {cancel_ticket.ticket_number}, Deposit balance: ₹{user.deposit_balance}")
        assert user.deposit_balance == 30.0, "Expected balance to decrease by 20"

        # Cancel the draw
        cancel_res = LotteryService.cancel_draw(db, cancel_draw.id)
        print(f"Cancel output: {cancel_res}")

        db.refresh(cancel_draw)
        db.refresh(user)

        assert cancel_draw.status == "CANCELLED", "Draw status should be CANCELLED"
        # User balance should be refunded
        assert user.deposit_balance == 50.0, f"Expected balance to be refunded back to 50, got {user.deposit_balance}"
        print("SUCCESS: Draw cancellation & user refunds verified!")

        # Clean up database test records
        print("\nCleaning up test records...")
        db.query(WalletTransaction).filter(WalletTransaction.user_id == user.id).delete()
        db.query(LotteryTicket).filter(LotteryTicket.user_id == user.id).delete()
        db.query(LotteryDraw).filter(LotteryDraw.id.in_([draw.id, cancel_draw.id])).delete()
        db.query(User).filter(User.id == user.id).delete()
        db.commit()
        print("Cleanup completed successfully.")
        print("\n=== ALL LOTTERY SYSTEM TESTS PASSED SUCCESSFULLY! ===")

    except AssertionError as e:
        print(f"\nTEST ASSERTION FAILURE: {e}")
        import traceback
        traceback.print_exc()
    except Exception as e:
        print(f"\nTEST ERROR OCCURRED: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    run_tests()
