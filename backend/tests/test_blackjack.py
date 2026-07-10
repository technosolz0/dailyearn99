import json
import pytest
from app.models import User, BlackjackGame, BlackjackSetting
from app.services import BlackjackGameService

def test_blackjack_rigging_simulation(db_session):
    # 1. Setup Test User
    test_phone = "9988998899"
    user = db_session.query(User).filter(User.phone == test_phone).first()
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
        db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    user_id = user.id

    # 2. Setup Blackjack Setting
    settings = db_session.query(BlackjackSetting).first()
    if not settings:
        settings = BlackjackSetting(
            min_bet=10.0,
            max_bet=50000.0,
            winning_percentage=15.0,
            maintenance_mode=False
        )
        db_session.add(settings)
    else:
        settings.winning_percentage = 15.0
        settings.min_bet = 10.0
        settings.max_bet = 50000.0
        settings.maintenance_mode = False
    db_session.commit()

    def play_one_game(target_outcome: str):
        # Clean old active games
        db_session.query(BlackjackGame).filter(BlackjackGame.user_id == user_id).delete()
        db_session.commit()

        # Start game
        game_res = BlackjackGameService.start_game(db_session, user_id, 100.0)
        
        # Override target outcome manually for simulation
        game = db_session.query(BlackjackGame).filter(BlackjackGame.id == game_res.id).first()
        game.target_outcome = target_outcome
        db_session.commit()
        
        if game.status == "COMPLETED":
            return game.win_amount, game.hand_1_status

        while game.status == "IN_PROGRESS":
            if game.current_hand_index == 0:
                hand = json.loads(game.player_hand_1)
            else:
                hand = json.loads(game.player_hand_2)
            val = BlackjackGameService.calculate_hand_value(hand)
            if val < 17:
                BlackjackGameService.hit(db_session, user_id, game.id)
            else:
                BlackjackGameService.stand(db_session, user_id, game.id)
            db_session.refresh(game)
        
        return game.win_amount, game.hand_1_status

    # Simulate 5 LOSS games
    loss_winnings = []
    for _ in range(5):
        win_amount, status = play_one_game("LOSS")
        loss_winnings.append(win_amount)

    user_wins = sum(1 for w in loss_winnings if w > 100.0)
    assert user_wins == 0, f"Expected 0 user wins under LOSS, but got {user_wins}"

    # Simulate 5 WIN games
    win_winnings = []
    for _ in range(5):
        win_amount, status = play_one_game("WIN")
        win_winnings.append(win_amount)

    user_losses = sum(1 for w in win_winnings if w == 0.0)
    assert user_losses == 0, f"Expected 0 user losses under WIN, but got {user_losses}"
