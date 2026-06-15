from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models import User, LotteryDraw
from app.schemas import (
    LotteryDrawCreate, LotteryDrawResponse
)
from app.core.security import get_current_admin
from app.services import LotteryService

router = APIRouter(
    prefix="/admin/lottery",
    tags=["admin-lottery"],
    dependencies=[Depends(get_current_admin)]
)

@router.get("/draws", response_model=List[LotteryDrawResponse])
def admin_get_lottery_draws(db: Session = Depends(get_db)):
    return (
        db.query(LotteryDraw)
        .order_by(LotteryDraw.draw_time.desc())
        .all()
    )

@router.post("/draws", response_model=LotteryDrawResponse)
def admin_create_lottery_draw(
    request: LotteryDrawCreate,
    db: Session = Depends(get_db)
):
    draw = LotteryDraw(
        title=request.title,
        ticket_price=request.ticket_price,
        prize_pool=request.prize_pool,
        draw_time=request.draw_time,
        max_tickets=request.max_tickets,
        joined_tickets=0,
        status="OPEN"
    )
    db.add(draw)
    db.commit()
    db.refresh(draw)
    
    # Broadcast push notification about new lottery to all users
    try:
        from app.core.notifications import send_push_to_all_background
        send_push_to_all_background(
            db,
            title="🎟️ New Lucky Draw Open!",
            body=f"Join '{draw.title}' now! Tickets are just ₹{draw.ticket_price:.2f}. Prize pool: ₹{draw.prize_pool:.2f}!",
            data={"type": "lottery_created", "draw_id": str(draw.id)}
        )
    except Exception as e:
        print(f"Failed to send background notification for lottery: {e}")
        
    return draw

@router.post("/draws/{id}/draw")
def admin_execute_lottery_draw(
    id: int,
    db: Session = Depends(get_db)
):
    res = LotteryService.execute_draw(db, id)
    if "error" in res:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res["error"]
        )
    return res

@router.delete("/draws/{id}")
def admin_cancel_lottery_draw(
    id: int,
    db: Session = Depends(get_db)
):
    res = LotteryService.cancel_draw(db, id)
    if "error" in res:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res["error"]
        )
    return res
