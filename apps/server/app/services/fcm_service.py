import json
import logging
import os
from typing import Optional
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    HAS_FIREBASE = True
except ImportError:
    firebase_admin = None
    credentials = None
    messaging = None
    HAS_FIREBASE = False

logger = logging.getLogger(__name__)


class FcmPushService:
    _instance: Optional["FcmPushService"] = None
    _initialized: bool = False

    def __new__(cls) -> "FcmPushService":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def initialize(self) -> bool:
        """Initializes the Firebase Admin SDK singleton using service account credentials."""
        if not HAS_FIREBASE:
            logger.warning("[FcmPushService] firebase-admin package is not installed. Push notifications disabled.")
            return False

        if self._initialized:
            return True

        # Candidate credential paths
        candidate_paths = [
            os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", ""),
            os.path.join(os.path.dirname(__file__), "..", "..", "firebase-service-account.json"),
            "/app/firebase-service-account.json",
            "firebase-service-account.json",
        ]

        cred_json_str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
        cred = None

        if cred_json_str.strip():
            try:
                cred_dict = json.loads(cred_json_str)
                cred = credentials.Certificate(cred_dict)
                logger.info("[FcmPushService] Loaded credentials from FIREBASE_SERVICE_ACCOUNT_JSON env.")
            except Exception as e:
                logger.error(f"[FcmPushService] Failed parsing FIREBASE_SERVICE_ACCOUNT_JSON: {e}")

        if not cred:
            for path in candidate_paths:
                if path and os.path.exists(path):
                    try:
                        cred = credentials.Certificate(path)
                        logger.info(f"[FcmPushService] Loaded credentials from file: {path}")
                        break
                    except Exception as e:
                        logger.error(f"[FcmPushService] Failed loading credential file {path}: {e}")

        if not cred:
            logger.warning("[FcmPushService] No valid Firebase credentials found. Push notifications will be skipped.")
            return False

        try:
            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)
            self._initialized = True
            logger.info("[FcmPushService] Firebase Admin SDK initialized successfully.")
            return True
        except Exception as e:
            logger.error(f"[FcmPushService] Firebase Admin initialization failed: {e}")
            return False

    async def send_reminder_push(
        self,
        token: str,
        title: str = "Pingo",
        body: str = "You have a scheduled reminder right now.",
        data: Optional[dict] = None,
    ) -> bool:
        """Dispatches a high-priority FCM notification with custom heads-up channel."""
        if not self._initialized:
            if not self.initialize():
                return False

        try:
            string_data = {str(k): str(v) for k, v in (data or {}).items()}
            string_data.setdefault("title", title)
            string_data.setdefault("body", body)

            message = messaging.Message(
                token=token,
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=string_data,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="pingo_urgent_channel_v2",
                        default_sound=True,
                        default_vibrate_timings=True,
                        click_action="FLUTTER_NOTIFICATION_CLICK",
                    ),
                ),
            )

            response = messaging.send(message)
            logger.info(f"[FcmPushService] Push sent successfully: {response} -> Token: {token[:12]}...")
            return True
        except messaging.UnregisteredError:
            logger.warning(f"[FcmPushService] Token is unregistered / expired: {token[:12]}...")
            return False
        except Exception as e:
            logger.error(f"[FcmPushService] Failed sending push notification: {e}")
            return False


fcm_push_service = FcmPushService()
