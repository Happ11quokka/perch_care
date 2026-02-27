"""FCM push notification service using firebase-admin SDK."""
import json
import logging

import firebase_admin
from firebase_admin import credentials, messaging

from app.config import get_settings

logger = logging.getLogger(__name__)

_initialized = False


def _ensure_initialized():
    global _initialized
    if _initialized:
        return
    settings = get_settings()
    if not settings.firebase_credentials_json:
        logger.warning("FIREBASE_CREDENTIALS_JSON not set — push notifications disabled")
        return
    cred = credentials.Certificate(json.loads(settings.firebase_credentials_json))
    firebase_admin.initialize_app(cred)
    _initialized = True


def send_push_notification(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """Send a single FCM push notification. Returns True on success."""
    _ensure_initialized()
    if not _initialized:
        return False
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        token=token,
    )
    try:
        messaging.send(message)
        return True
    except messaging.UnregisteredError:
        logger.info(f"Token unregistered: {token[:20]}...")
        return False
    except Exception:
        logger.exception(f"Failed to send push to {token[:20]}...")
        return False


def send_push_notifications_batch(tokens: list[str], title: str, body: str, data: dict | None = None) -> tuple[int, int, list[str]]:
    """Send FCM push to multiple tokens in batches of 500.

    Returns (success_count, failure_count, invalid_tokens).
    """
    _ensure_initialized()
    if not _initialized:
        return 0, len(tokens), []

    success = 0
    failure = 0
    invalid_tokens: list[str] = []

    for i in range(0, len(tokens), 500):
        batch = tokens[i:i + 500]
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            tokens=batch,
        )
        try:
            response = messaging.send_each_for_multicast(message)
            success += response.success_count
            failure += response.failure_count
            for idx, send_response in enumerate(response.responses):
                if send_response.exception and isinstance(send_response.exception, messaging.UnregisteredError):
                    invalid_tokens.append(batch[idx])
        except Exception:
            logger.exception(f"Batch send failed for {len(batch)} tokens")
            failure += len(batch)

    return success, failure, invalid_tokens
