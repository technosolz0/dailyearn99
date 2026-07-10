import json
import pytest
from app.models import User, MinesGame, MinesSetting
from app.services import MinesGameService

def test_mines_game_service(db_session):
    # 1. Setup Test User
    test_phone = "9900990099"
    user = db_session.query(User).filter(User.phone == test_phone).first()
    if user:
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
        db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    user_id = user.id

    # 2. Setup Mines Setting
    settings = db_session.query(MinesSetting).first()
    if not settings:
        settings = MinesSetting(
            house_edge=0.03,
            min_bet=10.0,
            max_bet=1000.0,
            maintenance_mode=False
        )
        db_session.add(settings)
    else:
        settings.house_edge = 0.03
        settings.min_bet = 10.0
        settings.max_bet = 1000.0
        settings.maintenance_mode = False
    db_session.commit()

    # Clean old active games
    db_session.query(MinesGame).filter(MinesGame.user_id == user_id).delete()
    db_session.commit()

    # 3. Test nCr / Multiplier calculations
    mult = MinesGameService.calculate_multiplier(3, 1, 0.03)
    assert mult == 1.1

    # 4. Test Game Initiation
    bet_amount = 100.0
    mines_count = 3
    game = MinesGameService.start_game(db_session, user_id, bet_amount, mines_count)
    
    assert game.id is not None
    assert game.status == "IN_PROGRESS"
    assert game.bet_amount == bet_amount
    assert game.mines_count == mines_count
    assert len(json.loads(game.mines_positions)) == mines_count

    # Check balance deduction (500 - 100 = 400)
    db_session.refresh(user)
    assert user.deposit_balance == 400.0

    # Verify active game prevention
    with pytest.raises(ValueError):
        MinesGameService.start_game(db_session, user_id, bet_amount, mines_count)

    # 5. Test Gem Reveal
    mines_list = json.loads(game.mines_positions)
    # Find a position that is NOT a mine
    safe_position = 0
    for i in range(25):
        if i not in mines_list:
            safe_position = i
            break
    
    game = MinesGameService.reveal_cell(db_session, user_id, game.id, safe_position)
    assert safe_position in json.loads(game.revealed_positions)
    assert game.status == "IN_PROGRESS"
    assert game.current_multiplier > 1.0
    assert game.current_win == bet_amount * game.current_multiplier

    # 6. Test Cash Out
    expected_winnings = game.current_win
    game = MinesGameService.cash_out(db_session, user_id, game.id)
    assert game.status == "WON"
    
    db_session.refresh(user)
    assert abs(user.winning_balance - expected_winnings) < 0.01

    # 7. Test Bomb Explosion
    game = MinesGameService.start_game(db_session, user_id, bet_amount, mines_count)
    mines_list = json.loads(game.mines_positions)
    bomb_position = mines_list[0]
    
    game = MinesGameService.reveal_cell(db_session, user_id, game.id, bomb_position)
    assert game.status == "LOST"
    assert game.current_win == 0.0
    assert game.current_multiplier == 0.0
    
    db_session.refresh(user)

    # Verify cashing out of a lost game is blocked
    with pytest.raises(ValueError):
        MinesGameService.cash_out(db_session, user_id, game.id)
