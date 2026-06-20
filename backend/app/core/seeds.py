import os
import sys

# Add the parent directory of 'app' to Python path so we can run this script directly
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

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

    # Clear stale records to trigger a clean re-seed with latest multipliers
    db.query(RTPSettings).delete()
    db.commit()

    # Dynamic RTP settings matching specification
    settings = [
        RTPSettings(
            min_amount=1.0,
            max_amount=49.0,
            probability_json=json.dumps({
                "Lose": 15.0,
                "0.1x": 5.0,
                "0.2x": 5.0,
                "0.4x": 5.0,
                "0.5x": 5.0,
                "0.6x": 5.0,
                "0.8x": 5.0,
                "1x": 15.0,
                "1.1x": 10.0,
                "1.2x": 10.0,
                "1.5x": 10.0,
                "2x": 5.0,
                "3x": 3.0,
                "5x": 1.91,
                "10x": 0.07,
                "20x": 0.01,
                "30x": 0.01,
                "40x": 0.005,
                "50x": 0.002
            }),
            enabled=True
        ),
        RTPSettings(
            min_amount=50.0,
            max_amount=100.0,
            probability_json=json.dumps({
                "Lose": 30.0,
                "0.1x": 5.0,
                "0.2x": 5.0,
                "0.4x": 5.0,
                "0.5x": 5.0,
                "0.6x": 5.0,
                "0.8x": 5.0,
                "1x": 10.0,
                "1.1x": 8.0,
                "1.2x": 8.0,
                "1.5x": 6.0,
                "2x": 4.0,
                "3x": 3.0,
                "5x": 0.91,
                "10x": 0.07,
                "20x": 0.01,
                "30x": 0.01,
                "40x": 0.005,
                "50x": 0.002
            }),
            enabled=True
        ),
        RTPSettings(
            min_amount=101.0,
            max_amount=1000000.0,
            probability_json=json.dumps({
                "Lose": 50.0,
                "0.1x": 5.0,
                "0.2x": 5.0,
                "0.4x": 4.0,
                "0.5x": 4.0,
                "0.6x": 4.0,
                "0.8x": 4.0,
                "1x": 10.0,
                "1.1x": 6.0,
                "1.2x": 4.0,
                "1.5x": 2.0,
                "2x": 1.0,
                "3x": 0.7,
                "5x": 0.21,
                "10x": 0.07,
                "20x": 0.01,
                "30x": 0.01,
                "40x": 0.005,
                "50x": 0.002
            }),
            enabled=True
        )
    ]
    db.bulk_save_objects(settings)
    db.commit()


def seed_mines_settings(db: Session):
    from app.models import MinesSetting
    if db.query(MinesSetting).count() == 0:
        settings = MinesSetting(
            house_edge=0.03,
            min_bet=10.0,
            max_bet=5000.0,
            maintenance_mode=False
        )
        db.add(settings)
        db.commit()
        print("Database Seeding: Populated default Mines settings.")


def seed_plinko_settings(db: Session):
    from app.models import PlinkoSetting, PlinkoMultiplier
    import json

    # 1. Seed global plinko settings if none exist
    if db.query(PlinkoSetting).count() == 0:
        settings = PlinkoSetting(
            min_bet=10.0,
            max_bet=5000.0,
            maintenance_mode=False
        )
        db.add(settings)
        db.commit()
        print("Database Seeding: Populated default Plinko settings.")

    # 2. Seed default Plinko multipliers if none exist
    if db.query(PlinkoMultiplier).count() == 0:
        # Default multipliers matching Low, Medium, High risk for Rows 8 to 16
        multipliers_by_row_mode = {
            8: {
                "low": [5.6, 1.6, 1.1, 1.0, 0.5, 1.0, 1.1, 1.6, 5.6],
                "medium": [13.0, 3.0, 1.3, 0.7, 0.4, 0.7, 1.3, 3.0, 13.0],
                "high": [29.0, 4.0, 1.5, 0.3, 0.2, 0.3, 1.5, 4.0, 29.0]
            },
            9: {
                "low": [5.6, 2.0, 1.6, 1.0, 0.7, 0.7, 1.0, 1.6, 2.0, 5.6],
                "medium": [18.0, 4.0, 1.6, 0.9, 0.5, 0.5, 0.9, 1.6, 4.0, 18.0],
                "high": [43.0, 7.0, 2.0, 0.6, 0.2, 0.2, 0.6, 2.0, 7.0, 43.0]
            },
            10: {
                "low": [16, 9, 2, 1.4, 1.1, 1, 1.1, 1.4, 2, 9, 16],
                "medium": [22, 5, 2, 1.4, 0.6, 0.4, 0.6, 1.4, 2, 5, 22],
                "high": [110, 15, 4, 1.8, 0.7, 0.3, 0.7, 1.8, 4, 15, 110]
            },
            11: {
                "low": [24, 10, 3, 1.8, 1.2, 1, 1, 1.2, 1.8, 3, 10, 24],
                "medium": [33, 8, 3, 1.6, 0.7, 0.5, 0.5, 0.7, 1.6, 3, 8, 33],
                "high": [170, 24, 8.1, 2, 0.7, 0.2, 0.2, 0.7, 2, 8.1, 24, 170]
            },
            12: {
                "low": [33, 11, 4, 2, 1.3, 1.1, 1, 1.1, 1.3, 2, 4, 11, 33],
                "medium": [50, 11, 4, 2, 1.1, 0.6, 0.3, 0.6, 1.1, 2, 4, 11, 50],
                "high": [260, 33, 11, 4, 2, 0.5, 0.2, 0.5, 2, 4, 11, 33, 260]
            },
            13: {
                "low": [43, 13, 6, 3, 1.3, 1.2, 1, 1, 1.2, 1.3, 3, 6, 13, 43],
                "medium": [76, 14, 6, 3, 1.3, 0.7, 0.4, 0.4, 0.7, 1.3, 3, 6, 14, 76],
                "high": [420, 56, 18, 6, 3, 1, 0.2, 0.2, 1, 3, 6, 18, 56, 420]
            },
            14: {
                "low": [56, 18, 8, 3.8, 2, 1.2, 1, 1, 1, 1.2, 2, 3.8, 8, 18, 56],
                "medium": [110, 18, 8, 3.8, 1.5, 1, 0.5, 0.2, 0.5, 1, 1.5, 3.8, 8, 18, 110],
                "high": [620, 83, 27, 8, 3, 1.3, 0.5, 0.2, 0.5, 1.3, 3, 8, 27, 83, 620]
            },
            15: {
                "low": [79, 24, 10, 4.8, 2.5, 1.5, 1, 1, 1, 1, 1.5, 2.5, 4.8, 10, 24, 79],
                "medium": [180, 29, 11, 5, 2, 1.1, 0.6, 0.3, 0.3, 0.6, 1.1, 2, 5, 11, 29, 180],
                "high": [1000, 130, 37, 11, 4, 1.5, 1, 0.5, 0.5, 1, 1.5, 4, 11, 37, 130, 1000]
            },
            16: {
                "low": [110, 33, 12, 6, 3, 1.8, 1.2, 1, 1, 1, 1.2, 1.8, 3, 6, 12, 33, 110],
                "medium": [260, 43, 15, 6, 3, 1.5, 1, 0.5, 0.3, 0.5, 1, 1.5, 3, 6, 15, 43, 260],
                "high": [1000, 130, 43, 14, 5, 2, 1.3, 0.5, 0.2, 0.5, 1.3, 2, 5, 14, 43, 130, 1000]
            }
        }
        for rows, modes in multipliers_by_row_mode.items():
            for mode, m_list in modes.items():
                m = PlinkoMultiplier(
                    rows=rows,
                    mode=mode,
                    multipliers_json=json.dumps(m_list)
                )
                db.add(m)
        db.commit()
        print("Database Seeding: Populated default Plinko multipliers.")


if __name__ == "__main__":
    from app.core.database import SessionLocal
    db = SessionLocal()
    try:
        print("Starting manual database seeding...")
        print("Seeding test users...")
        seed_test_users(db)
        print("Seeding RTP settings...")
        seed_rtp_settings(db)
        print("Seeding Mines settings...")
        seed_mines_settings(db)
        print("Seeding Plinko settings...")
        seed_plinko_settings(db)
        print("Database seeding completed successfully!")
    except Exception as e:
        print(f"Error during database seeding: {e}")
    finally:
        db.close()

