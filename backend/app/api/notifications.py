from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc
import json
from typing import List

from app.core.database import get_db
from app.models import User, Notification
from app.core.security import get_current_user
from app.schemas import NotificationResponse

router = APIRouter(prefix="/notifications", tags=["notifications"])

@router.get("", response_model=List[NotificationResponse])
def get_my_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Fetches all notifications for the active user, including direct notifications
    and broadcasts (user_id is NULL). Sorted by newest first.
    """
    notifications = (
        db.query(Notification)
        .filter(or_(Notification.user_id == current_user.id, Notification.user_id == None))
        .order_by(desc(Notification.created_at))
        .all()
    )
    
    result = []
    for n in notifications:
        try:
            data_val = json.loads(n.data_json) if n.data_json else None
        except Exception:
            data_val = {"raw": n.data_json}

        result.append({
            "id": n.id,
            "title": n.title,
            "body": n.body,
            "data": data_val,
            "is_read": n.is_read,
            "created_at": n.created_at
        })
    return result


@router.post("/{notification_id}/read")
def mark_notification_as_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Marks a specific notification as read.
    """
    n = db.query(Notification).filter(Notification.id == notification_id).first()
    if not n:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found."
        )
    
    # Ensure this notification belongs to the active user or is broadcast
    if n.user_id is not None and n.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied."
        )

    n.is_read = True
    db.commit()
    return {"message": "Notification marked as read successfully."}
