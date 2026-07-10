import json
import pytest
from app.models import User, PlinkoGame, PlinkoSetting, PlinkoMultiplier, PlinkoRTP
from app.services import PlinkoGameService

def test_plinko_game_service(db_session):
    # 1. Setup Test User
    test_phone = "9988998899"
    user = db_session.query(User).filter(User.phone == test_phone).first()
    if user:
        user.deposit_balance = 500.0
        user.winning_balance = 0.0
        user.bonus_balance = 0.0
        user.is_banned = False
        user.kyc_status = "VERIFIED"
        user.plinko_bet_count = 6
    else:
        user = User(
            name="Test Plinko User",
            phone=test_phone,
            referral_code="T99_PLNK",
            deposit_balance=500.0,
            winning_balance=0.0,
            bonus_balance=0.0,
            kyc_status="VERIFIED",
            is_banned=False,
            plinko_bet_count=6
        )
        db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    user_id = user.id

    # 2. Setup Plinko Setting
    settings = db_session.query(PlinkoSetting).first()
    if not settings:
        settings = PlinkoSetting(
            min_bet=10.0,
            max_bet=1000.0,
            maintenance_mode=False
        )
        db_session.add(settings)
    else:
        settings.min_bet = 10.0
        settings.max_bet = 1000.0
        settings.maintenance_mode = False
    db_session.commit()

    # Clean old Plinko games
    db_session.query(PlinkoGame).filter(PlinkoGame.user_id == user_id).delete()
    db_session.commit()

    # 3. Test Plinko Play with Default Multipliers
    bet_amount = 50.0
    rows = 10
    mode = "medium"
    
    # We need to make sure the start user plinko_bet_count is 6 so it uses standard probability path simulation
    user.plinko_bet_count = 6
    db_session.commit()

    game = PlinkoGameService.play_plinko(db_session, user_id, bet_amount, rows, mode)
    assert game.id is not None
    assert game.rows == rows
    assert game.mode == mode
    assert game.bet_amount == bet_amount
    path = json.loads(game.path)
    assert len(path) == rows
    assert sum(path) == game.final_bucket
    
    # Verify balance deduction
    db_session.refresh(user)
    assert abs(user.deposit_balance + user.winning_balance - 500.0) < 0.01

    # 4. Test Plinko Multiplier Override
    custom_mults = [1.0, 1.0, 1.0, 1.0, 1.0, 50.0, 1.0, 1.0, 1.0, 1.0, 1.0] # 50x in center
    override = db_session.query(PlinkoMultiplier).filter(
        PlinkoMultiplier.rows == 10,
        PlinkoMultiplier.mode == "medium"
    ).first()
    if not override:
        override = PlinkoMultiplier(rows=10, mode="medium")
        db_session.add(override)
    override.multipliers_json = json.dumps(custom_mults)
    db_session.commit()

    # Play Plinko again and check if it uses custom multipliers
    game = PlinkoGameService.play_plinko(db_session, user_id, bet_amount, rows, mode)
    assert game.multiplier == custom_mults[game.final_bucket]

    # 5. Test Plinko RTP override (forcing path landing)
    prob_override = {str(i): 0.0 for i in range(11)}
    prob_override["5"] = 100.0
    
    rtp = db_session.query(PlinkoRTP).filter(
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
        db_session.add(rtp)
    rtp.probability_json = json.dumps(prob_override)
    rtp.enabled = True
    db_session.commit()

    game = PlinkoGameService.play_plinko(db_session, user_id, bet_amount, rows, mode)
    assert game.final_bucket == 5
    assert game.multiplier == 50.0 # From our custom multipliers override
    assert game.win_amount == bet_amount * 50.0
