import os
import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy.orm import Session
from app.models import User

# Check if a custom service account key file exists
service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "firebase-service-account.json")

firebase_is_active = False

try:
    if os.path.exists(service_account_path):
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred)
        firebase_is_active = True
        print(f"Firebase Admin initialized successfully with service account from: {service_account_path}")
    else:
        # Check if default credential files are configured in environment
        if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
            firebase_admin.initialize_app()
            firebase_is_active = True
            print("Firebase Admin initialized successfully with GOOGLE_APPLICATION_CREDENTIALS.")
        else:
            print("No Firebase Service account JSON or credentials found.")
            print("Push notification service will run in MOCK mode (printing to server terminal).")
except Exception as e:
    print(f"Firebase Admin initialization skipped/failed: {e}")
    print("Push notification service will run in MOCK mode (printing to server terminal).")


def send_push_to_token(token: str, title: str, body: str, data: dict = None) -> bool:
    """
    Sends a push notification to a specific FCM token.
    If Firebase Admin SDK is not active, it prints a mock log to the terminal.
    """
    if not token:
        return False
    
    if not firebase_is_active:
        print(f"\n📢 [MOCK PUSH NOTIFICATION] \n   FCM Token: {token}\n   Title: {title}\n   Body: {body}\n   Data: {data}\n")
        return True
        
    try:
        # Stringify any non-string values in data (FCM data payload only accepts string values)
        fcm_data = {}
        if data:
            for k, v in data.items():
                fcm_data[str(k)] = str(v)

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=fcm_data,
            token=token,
        )
        response = messaging.send(message)
        print(f"Successfully sent FCM message: {response}")
        return True
    except Exception as e:
        print(f"Error sending FCM message: {e}")
        # Print fallback mock payload to terminal in case of credentials error
        print(f"\n📢 [MOCK PUSH NOTIFICATION FALLBACK] \n   FCM Token: {token}\n   Title: {title}\n   Body: {body}\n   Data: {data}\n")
        return False


def send_push_to_user(db: Session, user_id: int, title: str, body: str, data: dict = None) -> bool:
    """
    Sends a push notification to a specific user by querying their FCM token in the database.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if user and user.fcm_token:
        import threading
        threading.Thread(
            target=send_push_to_token,
            args=(user.fcm_token, title, body, data),
            daemon=True
        ).start()
        return True
    else:
        user_name = user.name or user.phone if user else f"ID {user_id}"
        print(f"\n⚠️ [MOCK PUSH NOTIFICATION] (User '{user_name}' has no registered FCM token)\n   Title: {title}\n   Body: {body}\n")
        return False


def send_push_to_all(db: Session, title: str, body: str, data: dict = None) -> int:
    """
    Broadcasts a push notification to all users who have an FCM token registered.
    """
    users = db.query(User).filter(User.fcm_token != None).all()
    sent_count = 0
    for user in users:
        if send_push_to_token(user.fcm_token, title, body, data):
            sent_count += 1
            
    if not users:
        print(f"\n📢 [MOCK PUSH NOTIFICATION BROADCAST] (No users have registered FCM tokens yet)\n   Title: {title}\n   Body: {body}\n")
        
    return sent_count


def send_push_to_all_background(db: Session, title: str, body: str, data: dict = None):
    """
    Broadcasts a push notification to all users who have an FCM token registered in a background thread.
    This prevents blocking the FastAPI request flow during network calls to FCM.
    """
    tokens = [u.fcm_token for u in db.query(User).filter(User.fcm_token != None).all()]
    if not tokens:
        print(f"\n📢 [MOCK PUSH NOTIFICATION BROADCAST] (No users have registered FCM tokens yet)\n   Title: {title}\n   Body: {body}\n")
        return

    import threading
    def broadcast():
        for token in tokens:
            send_push_to_token(token, title, body, data)

    threading.Thread(target=broadcast, daemon=True).start()


def send_push_to_topic(topic: str, title: str, body: str, data: dict = None) -> bool:
    """
    Sends a push notification to a specific FCM topic in a background thread.
    If Firebase Admin SDK is not active, it prints a mock log to the terminal.
    """
    if not topic:
        return False
        
    import threading
    def run_send():
        if not firebase_is_active:
            print(f"\n📢 [MOCK PUSH NOTIFICATION TOPIC] \n   Topic: {topic}\n   Title: {title}\n   Body: {body}\n   Data: {data}\n")
            return
            
        try:
            fcm_data = {}
            if data:
                for k, v in data.items():
                    fcm_data[str(k)] = str(v)

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=fcm_data,
                topic=topic,
            )
            response = messaging.send(message)
            print(f"Successfully sent FCM message to topic '{topic}': {response}")
        except Exception as e:
            print(f"Error sending FCM message to topic '{topic}': {e}")
            print(f"\n📢 [MOCK PUSH NOTIFICATION TOPIC FALLBACK] \n   Topic: {topic}\n   Title: {title}\n   Body: {body}\n   Data: {data}\n")

    threading.Thread(target=run_send, daemon=True).start()
    return True
