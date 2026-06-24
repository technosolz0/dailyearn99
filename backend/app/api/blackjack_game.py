import random
import json
import copy
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, BlackjackGame, BlackjackSetting, WalletTransaction
from app.schemas import BlackjackGameResponse, BlackjackStartRequest, BlackjackSettingsResponse

router = APIRouter(prefix="/blackjack", tags=["Blackjack Game"])

SUITS = ["♠", "♥", "♦", "♣"]
RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

def get_random_card():
    rank = random.choice(RANKS)
    suit = random.choice(SUITS)
    if rank in ["J", "Q", "K"]:
        val = 10
    elif rank == "A":
        val = 11
    else:
        val = int(rank)
    return {"suit": suit, "rank": rank, "value": val}

def calculate_hand_value(hand):
    val = sum(c["value"] for c in hand)
    aces = sum(1 for c in hand if c["rank"] == "A")
    while val > 21 and aces > 0:
        val -= 10
        aces -= 1
    return val

def deal_card_to_player(hand, target_outcome):
    current_val = calculate_hand_value(hand)
    for _ in range(50):
        card = get_random_card()
        temp_hand = hand + [card]
        new_val = calculate_hand_value(temp_hand)
        
        if target_outcome == "WIN":
            if new_val > 21:
                continue
            return card
        elif target_outcome == "LOSS":
            if current_val >= 12:
                if new_val > 21:
                    return card  # Player busts
                continue
            else:
                # Player under 12, try to keep them awkward (< 17)
                if new_val >= 17:
                    continue
                return card
    return get_random_card()

def deal_card_to_dealer(dealer_hand, player_max_score, target_outcome):
    for _ in range(50):
        card = get_random_card()
        temp_hand = dealer_hand + [card]
        new_val = calculate_hand_value(temp_hand)
        
        if target_outcome == "WIN":
            if new_val > 21:
                return card  # Dealer busts
            if new_val >= 17 and new_val > player_max_score:
                continue  # Avoid dealer standing with score > player
            return card
        elif target_outcome == "LOSS":
            if new_val > 21:
                continue  # Avoid busting the dealer
            if new_val >= 17 and new_val < player_max_score:
                continue  # Avoid dealer standing on a losing score
            return card
    return get_random_card()

def mask_dealer_card_if_needed(game: BlackjackGame) -> BlackjackGame:
    if game.status == "COMPLETED":
        return game
    try:
        cards = json.loads(game.dealer_hand)
        if len(cards) > 0:
            masked = [cards[0]]
            game_copy = copy.copy(game)
            game_copy.dealer_hand = json.dumps(masked)
            return game_copy
    except Exception:
        pass
    return game

def play_dealer_turn(db: Session, game: BlackjackGame, user: User):
    dealer_hand = json.loads(game.dealer_hand)
    player_hand_1 = json.loads(game.player_hand_1)
    p1_val = calculate_hand_value(player_hand_1)

    if game.hand_1_status == "BUST":
        game.status = "COMPLETED"
        game.win_amount = 0.0
        return

    while True:
        d_val = calculate_hand_value(dealer_hand)
        if game.target_outcome == "LOSS":
            if d_val >= 21:
                break
            if d_val >= 17 and d_val >= p1_val:
                break
        else:
            if d_val >= 17 and d_val <= p1_val:
                break
        card = deal_card_to_dealer(dealer_hand, p1_val, game.target_outcome)
        dealer_hand.append(card)

    game.dealer_hand = json.dumps(dealer_hand)
    d_final_val = calculate_hand_value(dealer_hand)

    win_amount = 0.0
    payout_desc = ""
    if d_final_val > 21:
        game.hand_1_status = "WON"
        win_amount = game.bet_amount * 2
        payout_desc = "Dealer Bust"
    else:
        if p1_val > d_final_val:
            game.hand_1_status = "WON"
            win_amount = game.bet_amount * 2
            payout_desc = "Player Higher Score"
        elif p1_val < d_final_val:
            game.hand_1_status = "LOST"
            win_amount = 0.0
        else:
            game.hand_1_status = "PUSH"
            win_amount = game.bet_amount
            payout_desc = "Push"

    game.status = "COMPLETED"
    game.win_amount = win_amount

    if win_amount > 0:
        locked_user = db.query(User).filter(User.id == user.id).with_for_update().first()
        locked_user.winning_balance += win_amount
        tx = WalletTransaction(
            user_id=user.id,
            type="PRIZE_WIN",
            amount=win_amount,
            status="SUCCESS",
            description=f"Prize Win: Blackjack ({payout_desc})"
        )
        db.add(tx)

def resolve_split_payouts(db: Session, game: BlackjackGame, user: User):
    player_hand_1 = json.loads(game.player_hand_1)
    player_hand_2 = json.loads(game.player_hand_2)
    dealer_hand = json.loads(game.dealer_hand)

    p1_val = calculate_hand_value(player_hand_1)
    p2_val = calculate_hand_value(player_hand_2)

    if game.hand_1_status == "BUST" and game.hand_2_status == "BUST":
        game.status = "COMPLETED"
        game.win_amount = 0.0
        return

    valid_scores = []
    if game.hand_1_status != "BUST":
        valid_scores.append(p1_val)
    if game.hand_2_status != "BUST":
        valid_scores.append(p2_val)
    max_player_score = max(valid_scores) if valid_scores else 0

    while True:
        d_val = calculate_hand_value(dealer_hand)
        if game.target_outcome == "LOSS":
            if d_val >= 21:
                break
            if d_val >= 17 and d_val >= max_player_score:
                break
        else:
            if d_val >= 17 and d_val <= max_player_score:
                break
        card = deal_card_to_dealer(dealer_hand, max_player_score, game.target_outcome)
        dealer_hand.append(card)

    game.dealer_hand = json.dumps(dealer_hand)
    d_final_val = calculate_hand_value(dealer_hand)

    win_1 = 0.0
    if game.hand_1_status != "BUST":
        if d_final_val > 21:
            game.hand_1_status = "WON"
            win_1 = game.bet_amount * 2
        elif p1_val > d_final_val:
            game.hand_1_status = "WON"
            win_1 = game.bet_amount * 2
        elif p1_val < d_final_val:
            game.hand_1_status = "LOST"
            win_1 = 0.0
        else:
            game.hand_1_status = "PUSH"
            win_1 = game.bet_amount

    win_2 = 0.0
    if game.hand_2_status != "BUST":
        if d_final_val > 21:
            game.hand_2_status = "WON"
            win_2 = game.split_bet_amount * 2
        elif p2_val > d_final_val:
            game.hand_2_status = "WON"
            win_2 = game.split_bet_amount * 2
        elif p2_val < d_final_val:
            game.hand_2_status = "LOST"
            win_2 = 0.0
        else:
            game.hand_2_status = "PUSH"
            win_2 = game.split_bet_amount

    game.status = "COMPLETED"
    total_win = win_1 + win_2
    game.win_amount = total_win

    if total_win > 0:
        locked_user = db.query(User).filter(User.id == user.id).with_for_update().first()
        locked_user.winning_balance += total_win
        tx = WalletTransaction(
            user_id=user.id,
            type="PRIZE_WIN",
            amount=total_win,
            status="SUCCESS",
            description=f"Prize Win: Blackjack Split (H1: {game.hand_1_status}, H2: {game.hand_2_status})"
        )
        db.add(tx)

@router.post("/start", response_model=BlackjackGameResponse)
def start_blackjack(payload: BlackjackStartRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    settings = db.query(BlackjackSetting).first()
    if not settings:
        settings = BlackjackSetting()
        db.add(settings)
        db.commit()
        db.refresh(settings)

    if settings.maintenance_mode:
        raise HTTPException(status_code=400, detail="Blackjack is currently under maintenance.")

    if payload.bet_amount < settings.min_bet or payload.bet_amount > settings.max_bet:
        raise HTTPException(status_code=400, detail=f"Bet amount must be between ₹{settings.min_bet} and ₹{settings.max_bet}")

    active = db.query(BlackjackGame).filter(BlackjackGame.user_id == current_user.id, BlackjackGame.status == "IN_PROGRESS").first()
    if active:
        raise HTTPException(status_code=400, detail="You already have an active game in progress.")

    locked_user = db.query(User).filter(User.id == current_user.id).with_for_update().first()
    bonus_limit = payload.bet_amount * 0.20
    bonus_to_deduct = min(locked_user.bonus_balance, bonus_limit)
    remaining_fee = payload.bet_amount - bonus_to_deduct

    deposit_to_deduct = min(locked_user.deposit_balance, remaining_fee)
    winnings_to_deduct = remaining_fee - deposit_to_deduct

    if winnings_to_deduct > locked_user.winning_balance:
        raise HTTPException(status_code=400, detail="Insufficient wallet balance for this bet.")

    locked_user.bonus_balance -= bonus_to_deduct
    locked_user.deposit_balance -= deposit_to_deduct
    locked_user.winning_balance -= winnings_to_deduct

    tx = WalletTransaction(
        user_id=current_user.id,
        type="ENTRY_FEE",
        amount=payload.bet_amount,
        status="SUCCESS",
        description="Entry Fee: Blackjack Game"
    )
    db.add(tx)

    roll = random.uniform(0.0, 100.0)
    target_outcome = "WIN" if roll < settings.winning_percentage else "LOSS"

    player_hand = []
    dealer_hand = []

    # Player hand is always completely random, except we exclude a natural blackjack (21)
    for _ in range(10):
        p_hand = [get_random_card(), get_random_card()]
        if calculate_hand_value(p_hand) == 21:
            continue
        player_hand = p_hand
        break
    if not player_hand:
        player_hand = [get_random_card(), get_random_card()]

    # Dealer hand
    if target_outcome == "LOSS":
        # Dealer hand close to 21 (>= 19), but not exactly 21 to prevent instant completion
        for _ in range(10):
            d_hand = [get_random_card(), get_random_card()]
            d_val = calculate_hand_value(d_hand)
            if 19 <= d_val <= 20:
                dealer_hand = d_hand
                break
        if not dealer_hand:
            for _ in range(10):
                d_hand = [get_random_card(), get_random_card()]
                if calculate_hand_value(d_hand) != 21:
                    dealer_hand = d_hand
                    break
            if not dealer_hand:
                dealer_hand = [get_random_card(), get_random_card()]
    else:
        # Dealer hand is completely random, except we exclude a natural blackjack (21)
        # and ensure the dealer does not start with a winning hand >= 17 to guarantee player wins.
        player_val = calculate_hand_value(player_hand)
        for _ in range(50):
            d_hand = [get_random_card(), get_random_card()]
            d_val = calculate_hand_value(d_hand)
            if d_val == 21:
                continue
            if d_val >= 17 and d_val > player_val:
                continue
            dealer_hand = d_hand
            break
        if not dealer_hand:
            dealer_hand = [get_random_card(), get_random_card()]

    player_val = calculate_hand_value(player_hand)
    dealer_val = calculate_hand_value(dealer_hand)

    hand_1_status = "IN_PROGRESS"
    status_str = "IN_PROGRESS"
    win_amount = 0.0

    if player_val == 21:
        if dealer_val == 21:
            hand_1_status = "PUSH"
            status_str = "COMPLETED"
            win_amount = payload.bet_amount
        else:
            hand_1_status = "BLACKJACK"
            status_str = "COMPLETED"
            win_amount = payload.bet_amount * 2.5
    elif dealer_val == 21:
        hand_1_status = "LOST"
        status_str = "COMPLETED"
        win_amount = 0.0

    game = BlackjackGame(
        user_id=current_user.id,
        bet_amount=payload.bet_amount,
        is_split=False,
        split_bet_amount=0.0,
        player_hand_1=json.dumps(player_hand),
        player_hand_2=json.dumps([]),
        dealer_hand=json.dumps(dealer_hand),
        current_hand_index=0,
        hand_1_status=hand_1_status,
        hand_2_status="IN_PROGRESS",
        status=status_str,
        win_amount=win_amount,
        target_outcome=target_outcome
    )
    db.add(game)
    db.commit()
    db.refresh(game)

    if status_str == "COMPLETED" and win_amount > 0:
        locked_user.winning_balance += win_amount
        tx_win = WalletTransaction(
            user_id=current_user.id,
            type="PRIZE_WIN",
            amount=win_amount,
            status="SUCCESS",
            description=f"Prize Win: Blackjack ({hand_1_status})"
        )
        db.add(tx_win)
        db.commit()

    res_game = mask_dealer_card_if_needed(game)
    res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
    return res_game

@router.post("/hit", response_model=BlackjackGameResponse)
def blackjack_hit(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")

    game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == current_user.id).with_for_update().first()
    if not game:
        raise HTTPException(status_code=404, detail="Game session not found.")
    if game.status != "IN_PROGRESS":
        raise HTTPException(status_code=400, detail="Game already completed.")

    if game.current_hand_index == 0:
        hand = json.loads(game.player_hand_1)
    else:
        hand = json.loads(game.player_hand_2)

    card = deal_card_to_player(hand, game.target_outcome)
    hand.append(card)
    val = calculate_hand_value(hand)

    if game.current_hand_index == 0:
        game.player_hand_1 = json.dumps(hand)
        if val > 21:
            game.hand_1_status = "BUST"
            if not game.is_split:
                game.status = "COMPLETED"
                game.win_amount = 0.0
            else:
                game.current_hand_index = 1
    else:
        game.player_hand_2 = json.dumps(hand)
        if val > 21:
            game.hand_2_status = "BUST"
            game.status = "COMPLETED"
            resolve_split_payouts(db, game, current_user)

    db.commit()
    db.refresh(game)

    locked_user = db.query(User).filter(User.id == current_user.id).first()
    res_game = mask_dealer_card_if_needed(game)
    res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
    return res_game

@router.post("/stand", response_model=BlackjackGameResponse)
def blackjack_stand(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")

    game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == current_user.id).with_for_update().first()
    if not game:
        raise HTTPException(status_code=404, detail="Game session not found.")
    if game.status != "IN_PROGRESS":
        raise HTTPException(status_code=400, detail="Game already completed.")

    if game.current_hand_index == 0:
        game.hand_1_status = "STAND"
        if game.is_split:
            game.current_hand_index = 1
        else:
            play_dealer_turn(db, game, current_user)
    else:
        game.hand_2_status = "STAND"
        resolve_split_payouts(db, game, current_user)

    db.commit()
    db.refresh(game)

    locked_user = db.query(User).filter(User.id == current_user.id).first()
    res_game = mask_dealer_card_if_needed(game)
    res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
    return res_game

@router.post("/double", response_model=BlackjackGameResponse)
def blackjack_double(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")

    game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == current_user.id).with_for_update().first()
    if not game:
        raise HTTPException(status_code=404, detail="Game session not found.")
    if game.status != "IN_PROGRESS":
        raise HTTPException(status_code=400, detail="Game already completed.")

    bet_to_deduct = game.bet_amount
    locked_user = db.query(User).filter(User.id == current_user.id).with_for_update().first()

    bonus_limit = bet_to_deduct * 0.20
    bonus_to_deduct = min(locked_user.bonus_balance, bonus_limit)
    remaining_fee = bet_to_deduct - bonus_to_deduct

    deposit_to_deduct = min(locked_user.deposit_balance, remaining_fee)
    winnings_to_deduct = remaining_fee - deposit_to_deduct

    if winnings_to_deduct > locked_user.winning_balance:
        raise HTTPException(status_code=400, detail="Insufficient balance to double down.")

    locked_user.bonus_balance -= bonus_to_deduct
    locked_user.deposit_balance -= deposit_to_deduct
    locked_user.winning_balance -= winnings_to_deduct

    tx = WalletTransaction(
        user_id=current_user.id,
        type="ENTRY_FEE",
        amount=bet_to_deduct,
        status="SUCCESS",
        description="Entry Fee: Blackjack Double Down"
    )
    db.add(tx)

    if game.current_hand_index == 0:
        game.bet_amount *= 2
        hand = json.loads(game.player_hand_1)
    else:
        game.split_bet_amount = game.bet_amount * 2
        hand = json.loads(game.player_hand_2)

    card = deal_card_to_player(hand, game.target_outcome)
    hand.append(card)
    val = calculate_hand_value(hand)

    if game.current_hand_index == 0:
        game.player_hand_1 = json.dumps(hand)
        if val > 21:
            game.hand_1_status = "BUST"
            if not game.is_split:
                game.status = "COMPLETED"
                game.win_amount = 0.0
            else:
                game.current_hand_index = 1
        else:
            game.hand_1_status = "STAND"
            if game.is_split:
                game.current_hand_index = 1
            else:
                play_dealer_turn(db, game, current_user)
    else:
        game.player_hand_2 = json.dumps(hand)
        if val > 21:
            game.hand_2_status = "BUST"
        else:
            game.hand_2_status = "STAND"
        game.status = "COMPLETED"
        resolve_split_payouts(db, game, current_user)

    db.commit()
    db.refresh(game)

    res_game = mask_dealer_card_if_needed(game)
    res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
    return res_game

@router.post("/split", response_model=BlackjackGameResponse)
def blackjack_split(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")

    game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == current_user.id).with_for_update().first()
    if not game:
        raise HTTPException(status_code=404, detail="Game session not found.")
    if game.status != "IN_PROGRESS":
        raise HTTPException(status_code=400, detail="Game already completed.")
    if game.is_split:
        raise HTTPException(status_code=400, detail="Hand is already split.")

    player_hand = json.loads(game.player_hand_1)
    if len(player_hand) != 2:
        raise HTTPException(status_code=400, detail="Can only split on first two cards.")

    c1 = player_hand[0]
    c2 = player_hand[1]
    if c1["value"] != c2["value"] and c1["rank"] != c2["rank"]:
        raise HTTPException(status_code=400, detail="Cards must be of equal value or rank to split.")

    bet_to_deduct = game.bet_amount
    locked_user = db.query(User).filter(User.id == current_user.id).with_for_update().first()

    bonus_limit = bet_to_deduct * 0.20
    bonus_to_deduct = min(locked_user.bonus_balance, bonus_limit)
    remaining_fee = bet_to_deduct - bonus_to_deduct

    deposit_to_deduct = min(locked_user.deposit_balance, remaining_fee)
    winnings_to_deduct = remaining_fee - deposit_to_deduct

    if winnings_to_deduct > locked_user.winning_balance:
        raise HTTPException(status_code=400, detail="Insufficient balance to split.")

    locked_user.bonus_balance -= bonus_to_deduct
    locked_user.deposit_balance -= deposit_to_deduct
    locked_user.winning_balance -= winnings_to_deduct

    tx = WalletTransaction(
        user_id=current_user.id,
        type="ENTRY_FEE",
        amount=bet_to_deduct,
        status="SUCCESS",
        description="Entry Fee: Blackjack Split"
    )
    db.add(tx)

    hand1 = [c1]
    hand2 = [c2]

    hand1.append(deal_card_to_player(hand1, game.target_outcome))
    hand2.append(deal_card_to_player(hand2, game.target_outcome))

    game.is_split = True
    game.split_bet_amount = game.bet_amount
    game.player_hand_1 = json.dumps(hand1)
    game.player_hand_2 = json.dumps(hand2)
    game.current_hand_index = 0

    db.commit()
    db.refresh(game)

    res_game = mask_dealer_card_if_needed(game)
    res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
    return res_game

@router.get("/active", response_model=Optional[BlackjackGameResponse])
def get_active_blackjack(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game = db.query(BlackjackGame).filter(BlackjackGame.user_id == current_user.id, BlackjackGame.status == "IN_PROGRESS").first()
    if game:
        locked_user = db.query(User).filter(User.id == current_user.id).first()
        res_game = mask_dealer_card_if_needed(game)
        res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return res_game
    return None

@router.get("/history", response_model=List[BlackjackGameResponse])
def get_blackjack_history(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    games = db.query(BlackjackGame).filter(BlackjackGame.user_id == current_user.id).order_by(BlackjackGame.created_at.desc()).limit(20).all()
    return games

@router.get("/settings", response_model=BlackjackSettingsResponse)
def get_blackjack_settings(db: Session = Depends(get_db)):
    settings = db.query(BlackjackSetting).first()
    if not settings:
        settings = BlackjackSetting()
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings
