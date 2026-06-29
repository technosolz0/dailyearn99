import time
import threading
from datetime import datetime, timedelta, timezone
from app.core.database import SessionLocal
from app.models import LotteryDraw
from app.services import LotteryService
import traceback

def lottery_scheduler_loop():
    print("Lottery Scheduler: Started background loop.", flush=True)
    ist_tz = timezone(timedelta(hours=5, minutes=30))
    
    while True:
        try:
            now_ist = datetime.now(ist_tz)
            now_utc = datetime.now(timezone.utc)
            
            db = SessionLocal()
            try:
                # ----------------------------------------------------
                # Task 1: Auto-create 5 lotteries at 1:00 AM everyday
                # ----------------------------------------------------
                # If current IST hour is >= 1:
                # The target draw date is tomorrow (D+1) at 12:00 AM (00:00:00) IST.
                # In UTC, that is D+1 00:00:00 IST - 5.5 hours = D at 18:30:00 UTC.
                if now_ist.hour >= 1:
                    target_draw_ist = datetime(now_ist.year, now_ist.month, now_ist.day) + timedelta(days=1)
                    target_draw_utc = target_draw_ist - timedelta(hours=5, minutes=30)
                    naive_target_draw_utc = target_draw_utc.replace(tzinfo=None)
                    
                    # We check if these 5 lotteries already exist for this draw time.
                    configs = [
                        {"title_prefix": "🎟️ Daily Bumper ₹50K (₹50)", "price": 50.0, "prize": 50000.0},
                        {"title_prefix": "💥 Daily Bumper ₹100K (₹100)", "price": 100.0, "prize": 100000.0},
                        {"title_prefix": "💎 Daily Bumper ₹200K (₹200)", "price": 200.0, "prize": 200000.0},
                        {"title_prefix": "🔥 Daily Bumper ₹500K (₹500)", "price": 500.0, "prize": 500000.0},
                        {"title_prefix": "👑 Daily Bumper ₹1M (₹1000)", "price": 1000.0, "prize": 1000000.0},
                    ]
                    
                    draw_date_str = target_draw_ist.strftime("%d/%m/%Y")
                    
                    for cfg in configs:
                        full_title = f"{cfg['title_prefix']} [{draw_date_str}]"
                        exists = db.query(LotteryDraw).filter(
                            LotteryDraw.draw_time == naive_target_draw_utc,
                            LotteryDraw.title == full_title
                        ).first()
                        
                        if not exists:
                            new_draw = LotteryDraw(
                                title=full_title,
                                ticket_price=cfg["price"],
                                prize_pool=cfg["prize"],
                                draw_time=naive_target_draw_utc,
                                max_tickets=10000000,
                                win_percentage=0.0,
                                joined_tickets=0,
                                status="OPEN"
                            )
                            db.add(new_draw)
                            print(f"Lottery Scheduler: Creating draw '{full_title}' for draw time {naive_target_draw_utc} UTC", flush=True)
                            
                            try:
                                db.commit()
                                db.refresh(new_draw)
                                from app.core.notifications import send_push_to_all_background
                                send_push_to_all_background(
                                    db,
                                    title="🎟️ New Daily Bumper Draw!",
                                    body=f"Join '{new_draw.title}' now! Ticket price: ₹{new_draw.ticket_price:.2f}. Win pool: ₹{new_draw.prize_pool:.2f}!",
                                    data={"type": "lottery_created", "draw_id": str(new_draw.id)}
                                )
                            except Exception as ne:
                                print(f"Lottery Scheduler: Failed to send notification/commit for '{full_title}': {ne}", flush=True)
                    db.commit()
                
                # ----------------------------------------------------
                # Task 2: Auto-draw any OPEN lottery draw whose draw_time has passed
                # ----------------------------------------------------
                naive_now_utc = now_utc.replace(tzinfo=None)
                due_draws = db.query(LotteryDraw).filter(
                    LotteryDraw.status == "OPEN",
                    LotteryDraw.draw_time <= naive_now_utc
                ).all()
                
                for draw in due_draws:
                    print(f"Lottery Scheduler: Automatically executing draw for '{draw.title}' (ID: {draw.id})", flush=True)
                    res = LotteryService.execute_draw(db, draw.id)
                    print(f"Lottery Scheduler: Draw result for '{draw.title}': {res}", flush=True)
                    
            except Exception as e:
                db.rollback()
                print("Lottery Scheduler Database Transaction Error:", flush=True)
                traceback.print_exc()
            finally:
                db.close()
                
        except Exception as e:
            print("Lottery Scheduler Core Loop Error:", flush=True)
            traceback.print_exc()
            
        time.sleep(30)

def start_lottery_scheduler():
    t = threading.Thread(target=lottery_scheduler_loop, daemon=True)
    t.start()
