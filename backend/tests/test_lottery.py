import pytest
from datetime import datetime, timedelta, timezone
from app.models import User, LotteryDraw, LotteryTicket, WalletTransaction
from app.services import LotteryService

def test_lottery_service(db_session):
    # 1. Create a test user or find one
    user = db_session.query(User).filter(User.phone == "7777777777").first()
    if not user:
        user = User(
            name="Lottery Tester",
            phone="7777777777",
            referral_code="LOTTOTEST",
            deposit_balance=100.0,
            winning_balance=50.0,
            bonus_balance=10.0,
            kyc_status="VERIFIED"
        )
        db_session.add(user)
        db_session.commit()
        db_session.refresh(user)

    # 2. Reset user balances for deterministic tests
    user.deposit_balance = 100.0
    user.winning_balance = 50.0
    db_session.commit()

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
    db_session.add(draw)
    db_session.commit()
    db_session.refresh(draw)

    # 4. Test Ticket Purchase (Wallet Deduction)
    initial_deposit = user.deposit_balance
    initial_winnings = user.winning_balance

    ticket = LotteryService.buy_ticket(db_session, user.id, draw.id)
    db_session.refresh(user)
    db_session.refresh(draw)

    expected_deposit = initial_deposit - draw.ticket_price
    assert abs(user.deposit_balance - expected_deposit) < 1e-4
    assert draw.joined_tickets == 1

    tx = db_session.query(WalletTransaction).filter(
        WalletTransaction.user_id == user.id,
        WalletTransaction.type == "ENTRY_FEE"
    ).order_by(WalletTransaction.created_at.desc()).first()
    assert tx is not None
    assert tx.amount == draw.ticket_price

    # 5. Test Winner Selection & Prize Credits
    draw_res = LotteryService.execute_draw(db_session, draw.id)

    db_session.refresh(draw)
    db_session.refresh(user)
    db_session.refresh(ticket)

    assert draw.status == "COMPLETED"
    assert draw.winning_number == ticket.ticket_number
    assert ticket.is_winner is True
    assert ticket.reward_amount == draw.prize_pool

    expected_winnings = initial_winnings + draw.prize_pool
    assert abs(user.winning_balance - expected_winnings) < 1e-4

    tx_win = db_session.query(WalletTransaction).filter(
        WalletTransaction.user_id == user.id,
        WalletTransaction.type == "PRIZE_WIN"
    ).order_by(WalletTransaction.created_at.desc()).first()
    assert tx_win is not None
    assert tx_win.amount == draw.prize_pool

    # 6. Test Draw Cancellation & Refunds
    cancel_draw = LotteryDraw(
        title="❌ Cancel Test Draw",
        ticket_price=20.0,
        prize_pool=200.0,
        draw_time=now + timedelta(minutes=10),
        max_tickets=5,
        joined_tickets=0,
        status="OPEN"
    )
    db_session.add(cancel_draw)
    db_session.commit()
    db_session.refresh(cancel_draw)

    user.deposit_balance = 50.0
    db_session.commit()
    
    cancel_ticket = LotteryService.buy_ticket(db_session, user.id, cancel_draw.id)
    db_session.refresh(user)
    db_session.refresh(cancel_draw)
    
    assert user.deposit_balance == 30.0

    cancel_res = LotteryService.cancel_draw(db_session, cancel_draw.id)

    db_session.refresh(cancel_draw)
    db_session.refresh(user)

    assert cancel_draw.status == "CANCELLED"
    assert user.deposit_balance == 50.0
