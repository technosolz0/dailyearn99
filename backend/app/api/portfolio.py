from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core.security import get_current_admin
from app.models import PortfolioConfig, PortfolioContactMessage, AdminBankDetail
from app.schemas import (
    PortfolioConfigResponse, PortfolioConfigUpdate,
    PortfolioContactMessageCreate, PortfolioContactMessageResponse,
    AdminBankDetailCreate, AdminBankDetailUpdate, AdminBankDetailResponse
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
            web_app_link="https://web.dailyearn99.in/",
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
        if not config.web_app_link:
            config.web_app_link = "https://web.dailyearn99.in/"
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
    
    # Send push notification to Admin
    try:
        from app.core.notifications import send_push_to_admin
        send_push_to_admin(
            db=db,
            title="✉️ Portfolio Contact Form",
            body=f"New contact form submission from {request.name} ({request.email}).",
            data={"event": "contact_submission", "contact_id": str(msg.id)}
        )
    except Exception as e:
        print(f"Failed to send portfolio contact message push to admin: {e}")
        
    return {"message": "Message submitted successfully", "id": msg.id}

@admin_router.put("/config", response_model=PortfolioConfigResponse)
def update_portfolio_config(request: PortfolioConfigUpdate, db: Session = Depends(get_db)):
    config = get_or_create_config(db)
    config.contact_email = request.contact_email
    config.contact_phone = request.contact_phone
    config.contact_address = request.contact_address
    config.office_hours = request.office_hours
    config.apk_link = request.apk_link
    config.web_app_link = request.web_app_link
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

# Admin Bank Details CRUD
@admin_router.get("/bank-details", response_model=List[AdminBankDetailResponse])
def get_admin_bank_details(db: Session = Depends(get_db)):
    return db.query(AdminBankDetail).order_by(AdminBankDetail.created_at.desc()).all()

@admin_router.post("/bank-details", response_model=AdminBankDetailResponse)
def create_admin_bank_detail(request: AdminBankDetailCreate, db: Session = Depends(get_db)):
    if request.is_default:
        db.query(AdminBankDetail).update({AdminBankDetail.is_default: False})
        db.commit()
        
    detail = AdminBankDetail(
        bank_name=request.bank_name.strip(),
        account_holder_name=request.account_holder_name.strip(),
        account_number=request.account_number.strip(),
        ifsc_code=request.ifsc_code.strip().upper(),
        upi_id=request.upi_id.strip() if request.upi_id else None,
        is_default=request.is_default,
        target_user_ids=request.target_user_ids.strip() if request.target_user_ids else None
    )
    db.add(detail)
    db.commit()
    db.refresh(detail)
    return detail

@admin_router.put("/bank-details/{id}", response_model=AdminBankDetailResponse)
def update_admin_bank_detail(id: int, request: AdminBankDetailUpdate, db: Session = Depends(get_db)):
    detail = db.query(AdminBankDetail).filter(AdminBankDetail.id == id).first()
    if not detail:
        raise HTTPException(status_code=404, detail="Bank detail not found")
        
    if request.is_default:
        db.query(AdminBankDetail).filter(AdminBankDetail.id != id).update({AdminBankDetail.is_default: False})
        db.commit()
        
    detail.bank_name = request.bank_name.strip()
    detail.account_holder_name = request.account_holder_name.strip()
    detail.account_number = request.account_number.strip()
    detail.ifsc_code = request.ifsc_code.strip().upper()
    detail.upi_id = request.upi_id.strip() if request.upi_id else None
    detail.is_default = request.is_default
    detail.target_user_ids = request.target_user_ids.strip() if request.target_user_ids else None
    
    db.commit()
    db.refresh(detail)
    return detail

@admin_router.delete("/bank-details/{id}")
def delete_admin_bank_detail(id: int, db: Session = Depends(get_db)):
    detail = db.query(AdminBankDetail).filter(AdminBankDetail.id == id).first()
    if not detail:
        raise HTTPException(status_code=404, detail="Bank detail not found")
    db.delete(detail)
    db.commit()
    return {"message": "Bank detail deleted successfully"}
