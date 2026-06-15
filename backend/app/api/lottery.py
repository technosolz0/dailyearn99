from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models import User, LotteryDraw, LotteryTicket
from app.schemas import (
    LotteryDrawResponse, LotteryTicketResponse, LotteryTicketBuyRequest
)
from app.core.security import get_current_user
from app.services import LotteryService

router = APIRouter(prefix="/lottery", tags=["lottery"])

@router.get("/draws", response_model=List[LotteryDrawResponse])
def get_lottery_draws(db: Session = Depends(get_db)):
    # Get active and recently completed draws
    return (
        db.query(LotteryDraw)
        .order_by(LotteryDraw.draw_time.desc())
        .all()
    )

@router.get("/my-tickets", response_model=List[LotteryTicketResponse])
def get_my_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tickets = (
        db.query(LotteryTicket)
        .filter(LotteryTicket.user_id == current_user.id)
        .order_by(LotteryTicket.purchase_time.desc())
        .all()
    )
    # Populate the additional fields for response schema
    response_tickets = []
    for t in tickets:
        draw = db.query(LotteryDraw).filter(LotteryDraw.id == t.draw_id).first()
        t_res = LotteryTicketResponse.model_validate(t)
        if draw:
            t_res.draw_title = draw.title
            t_res.draw_status = draw.status
        response_tickets.append(t_res)
    return response_tickets

@router.post("/buy", response_model=LotteryTicketResponse)
def buy_lottery_ticket(
    request: LotteryTicketBuyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        ticket = LotteryService.buy_ticket(db, current_user.id, request.draw_id)
        draw = db.query(LotteryDraw).filter(LotteryDraw.id == ticket.draw_id).first()
        ticket_res = LotteryTicketResponse.model_validate(ticket)
        if draw:
            ticket_res.draw_title = draw.title
            ticket_res.draw_status = draw.status
        return ticket_res
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
