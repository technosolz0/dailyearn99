from sqlalchemy.orm import Session
from app.models import User

DEFAULT_QUESTIONS = [
    {
        "text": "Which country won the ICC Men's T20 World Cup in 2024?",
        "options": ["India", "South Africa", "Australia", "England"],
        "correct_answer_index": 0
    },
    {
        "text": "In computer networking, what does VPN stand for?",
        "options": ["Virtual Private Network", "Vector Protocol Node", "Valued Personal Network", "Virtual Packet Node"],
        "correct_answer_index": 0
    },
    {
        "text": "Which programming language is predominantly used to write Flutter apps?",
        "options": ["Swift", "Dart", "Kotlin", "Rust"],
        "correct_answer_index": 1
    },
    {
        "text": "What is the national game of India officially/historically?",
        "options": ["Cricket", "Kabaddi", "Field Hockey", "Football"],
        "correct_answer_index": 2
    },
    {
        "text": "What is the platform fee target percentage in dailyearn99?",
        "options": ["10-20%", "15-35%", "50-60%", "5%"],
        "correct_answer_index": 1
    }
]

def seed_test_users(db: Session):
    # Check if users already exist in the database
    if db.query(User).count() > 0:
        return

    test_users = [
        User(
            name="Aarav Sharma",
            first_name="Aarav",
            last_name="Sharma",
            phone="9876543210",
            email="aarav.sharma@example.com",
            referral_code="T99_AARA",
            referred_by=None,
            deposit_balance=500.0,
            winning_balance=250.0,
            bonus_balance=100.0,
            kyc_status="VERIFIED",
            is_banned=False
        ),
        User(
            name="Aditya Verma",
            first_name="Aditya",
            last_name="Verma",
            phone="9876543211",
            email="aditya.verma@example.com",
            referral_code="T99_ADIT",
            referred_by="T99_AARA",
            deposit_balance=100.0,
            winning_balance=50.0,
            bonus_balance=50.0,
            kyc_status="VERIFIED",
            is_banned=False
        ),
        User(
            name="Ananya Iyer",
            first_name="Ananya",
            last_name="Iyer",
            phone="9876543212",
            email="ananya.iyer@example.com",
            referral_code="T99_ANAN",
            referred_by="T99_AARA",
            deposit_balance=0.0,
            winning_balance=0.0,
            bonus_balance=20.0,
            kyc_status="PENDING",
            is_banned=False
        ),
        User(
            name="Vikram Malhotra",
            first_name="Vikram",
            last_name="Malhotra",
            phone="9876543213",
            email="vikram.m@example.com",
            referral_code="T99_VIKR",
            referred_by=None,
            deposit_balance=1000.0,
            winning_balance=1200.0,
            bonus_balance=300.0,
            kyc_status="VERIFIED",
            is_banned=False
        ),
        User(
            name="Rohan Gupta",
            first_name="Rohan",
            last_name="Gupta",
            phone="9876543214",
            email="rohan.g@example.com",
            referral_code="T99_ROHA",
            referred_by=None,
            deposit_balance=200.0,
            winning_balance=0.0,
            bonus_balance=10.0,
            kyc_status="VERIFIED",
            is_banned=False
        ),
        User(
            name="Diya Kapoor",
            first_name="Diya",
            last_name="Kapoor",
            phone="9876543215",
            email="diya.k@example.com",
            referral_code="T99_DIYA",
            referred_by=None,
            deposit_balance=50.0,
            winning_balance=10.0,
            bonus_balance=0.0,
            kyc_status="PENDING",
            is_banned=False
        ),
        User(
            name="Ishaan Sen",
            first_name="Ishaan",
            last_name="Sen",
            phone="9876543216",
            email="ishaan.s@example.com",
            referral_code="T99_ISHA",
            referred_by="T99_VIKR",
            deposit_balance=1500.0,
            winning_balance=450.0,
            bonus_balance=150.0,
            kyc_status="VERIFIED",
            is_banned=False
        ),
        User(
            name="Meera Nair",
            first_name="Meera",
            last_name="Nair",
            phone="9876543217",
            email="meera.n@example.com",
            referral_code="T99_MEER",
            referred_by=None,
            deposit_balance=0.0,
            winning_balance=0.0,
            bonus_balance=0.0,
            kyc_status="REJECTED",
            is_banned=False
        ),
        User(
            name="Kabir Mehta",
            first_name="Kabir",
            last_name="Mehta",
            phone="9876543218",
            email="kabir.m@example.com",
            referral_code="T99_KABI",
            referred_by=None,
            deposit_balance=350.0,
            winning_balance=75.0,
            bonus_balance=25.0,
            kyc_status="VERIFIED",
            is_banned=False
        ),
        User(
            name="Neha Sharma",
            first_name="Neha",
            last_name="Sharma",
            phone="9876543219",
            email="neha.s@example.com",
            referral_code="T99_NEHA",
            referred_by="T99_KABI",
            deposit_balance=50.0,
            winning_balance=0.0,
            bonus_balance=10.0,
            kyc_status="PENDING",
            is_banned=False
        )
    ]

    db.bulk_save_objects(test_users)
    db.commit()

def seed_rtp_settings(db: Session):
    from app.models import RTPSettings
    import json

    if db.query(RTPSettings).count() > 0:
        return

    # Dynamic RTP settings matching specification
    settings = [
        RTPSettings(
            min_amount=1.0,
            max_amount=49.0,
            probability_json=json.dumps({
                "Lose": 20.0,
                "1x": 20.0,
                "1.1x": 18.0,
                "1.2x": 15.0,
                "1.5x": 12.0,
                "2x": 8.0,
                "3x": 5.0,
                "5x": 2.0
            }),
            enabled=True
        ),
        RTPSettings(
            min_amount=50.0,
            max_amount=100.0,
            probability_json=json.dumps({
                "Lose": 45.0,
                "1x": 20.0,
                "1.1x": 15.0,
                "1.2x": 8.0,
                "1.5x": 6.0,
                "2x": 4.0,
                "3x": 1.5,
                "5x": 0.5
            }),
            enabled=True
        ),
        RTPSettings(
            min_amount=101.0,
            max_amount=1000000.0,
            probability_json=json.dumps({
                "Lose": 65.0,
                "1x": 15.0,
                "1.1x": 10.0,
                "1.2x": 5.0,
                "1.5x": 3.0,
                "2x": 1.5,
                "3x": 0.4,
                "5x": 0.1
            }),
            enabled=True
        )
    ]
    db.bulk_save_objects(settings)
    db.commit()

