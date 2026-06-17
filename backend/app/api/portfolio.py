from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core.security import get_current_admin
from app.models import PortfolioConfig, PortfolioContactMessage
from app.schemas import (
    PortfolioConfigResponse, PortfolioConfigUpdate,
    PortfolioContactMessageCreate, PortfolioContactMessageResponse
)

public_router = APIRouter(prefix="/portfolio", tags=["Portfolio Public"])
admin_router = APIRouter(prefix="/admin/portfolio", tags=["Portfolio Admin"], dependencies=[Depends(get_current_admin)])

def get_or_create_config(db: Session) -> PortfolioConfig:
    config = db.query(PortfolioConfig).first()
    if not config:
        config = PortfolioConfig(
            contact_email="support@dailyearn99.in",
            contact_phone="+91 99999 99999",
            contact_address="DailyEarn 99 Tech Labs Pvt Ltd, Connaught Place, New Delhi, India - 110001",
            office_hours="Monday - Sunday, 24 Hours Active Online Support",
            apk_link="https://api.dailyearn99.in/static/dailyearn99.apk",
            telegram_link="https://t.me/dailyearn99",
            instagram_link="https://instagram.com/dailyearn99",
            referral_code="DAILYEARN99",
            add_amount_method="UPI",
            admin_upi_id="merchant@upi",
            admin_bank_holder="DailyEarn Admin",
            admin_bank_name="HDFC Bank",
            admin_bank_account="50100123456789",
            admin_bank_ifsc="HDFC0000123"
        )
        db.add(config)
        db.commit()
        db.refresh(config)
    else:
        # Defensive check: if new fields are null on existing record, populate them with defaults
        updated = False
        if not config.add_amount_method:
            config.add_amount_method = "UPI"
            updated = True
        if not config.admin_upi_id:
            config.admin_upi_id = "merchant@upi"
            updated = True
        if not config.admin_bank_holder:
            config.admin_bank_holder = "DailyEarn Admin"
            updated = True
        if not config.admin_bank_name:
            config.admin_bank_name = "HDFC Bank"
            updated = True
        if not config.admin_bank_account:
            config.admin_bank_account = "50100123456789"
            updated = True
        if not config.admin_bank_ifsc:
            config.admin_bank_ifsc = "HDFC0000123"
            updated = True
        if updated:
            db.commit()
            db.refresh(config)
    return config

@public_router.get("/config", response_model=PortfolioConfigResponse)
def get_portfolio_config(db: Session = Depends(get_db)):
    return get_or_create_config(db)

@public_router.post("/contact", status_code=status.HTTP_201_CREATED)
def submit_contact_message(request: PortfolioContactMessageCreate, db: Session = Depends(get_db)):
    msg = PortfolioContactMessage(
        name=request.name.strip(),
        email=request.email.strip(),
        subject=request.subject.strip(),
        message=request.message.strip()
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return {"message": "Message submitted successfully", "id": msg.id}

@admin_router.put("/config", response_model=PortfolioConfigResponse)
def update_portfolio_config(request: PortfolioConfigUpdate, db: Session = Depends(get_db)):
    config = get_or_create_config(db)
    config.contact_email = request.contact_email
    config.contact_phone = request.contact_phone
    config.contact_address = request.contact_address
    config.office_hours = request.office_hours
    config.apk_link = request.apk_link
    config.telegram_link = request.telegram_link
    config.instagram_link = request.instagram_link
    config.referral_code = request.referral_code
    config.add_amount_method = request.add_amount_method
    config.admin_upi_id = request.admin_upi_id
    config.admin_bank_holder = request.admin_bank_holder
    config.admin_bank_name = request.admin_bank_name
    config.admin_bank_account = request.admin_bank_account
    config.admin_bank_ifsc = request.admin_bank_ifsc
    db.commit()
    db.refresh(config)
    return config

@admin_router.get("/contacts", response_model=List[PortfolioContactMessageResponse])
def get_contact_messages(db: Session = Depends(get_db)):
    return db.query(PortfolioContactMessage).order_by(PortfolioContactMessage.created_at.desc()).all()

@admin_router.delete("/contacts/{id}")
def delete_contact_message(id: int, db: Session = Depends(get_db)):
    msg = db.query(PortfolioContactMessage).filter(PortfolioContactMessage.id == id).first()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found")
    db.delete(msg)
    db.commit()
    return {"message": "Message deleted successfully"}
