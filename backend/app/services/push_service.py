"""FCM push notification service using FCM HTTP v1 API directly."""
import json
import logging

import httpx
from google.oauth2 import service_account
import google.auth.transport.requests

from app.config import get_settings

logger = logging.getLogger(__name__)

_credentials = None
_project_id = None


def _get_access_token() -> str | None:
    """Obtain a fresh OAuth2 access token for FCM."""
    global _credentials, _project_id
    if _credentials is None:
        settings = get_settings()
        if not settings.firebase_credentials_json:
            logger.warning("FIREBASE_CREDENTIALS_JSON not set — push disabled")
            return None
        parsed = json.loads(settings.firebase_credentials_json)
        _project_id = parsed["project_id"]
        _credentials = service_account.Credentials.from_service_account_info(
            parsed, scopes=["https://www.googleapis.com/auth/firebase.messaging"]
        )
        logger.info(f"FCM init — project: {_project_id}, key_id: {parsed.get('private_key_id', '')[:12]}...")

    if not _credentials.valid:
        _credentials.refresh(google.auth.transport.requests.Request())
    logger.info(f"Access token acquired: {str(_credentials.token)[:20]}... valid={_credentials.valid} expiry={_credentials.expiry}")
    return _credentials.token


def _send_single(token: str, title: str, body: str, data: dict | None, access_token: str) -> tuple[bool, bool]:
    """Send to one device token. Returns (success, is_unregistered)."""
    url = f"https://fcm.googleapis.com/v1/projects/{_project_id}/messages:send"
    payload = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": data or {},
        }
    }
    headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
    logger.info(f"Sending to FCM — auth header present: {bool(headers.get('Authorization'))}, token len: {len(access_token) if access_token else 0}")
    resp = httpx.post(url, json=payload, headers=headers, timeout=10)
    if resp.status_code == 200:
        return True, False
    logger.error(f"Token {token[:20]}... FCM response body: {resp.text}")
    error = resp.json().get("error", {})
    status = error.get("status", "")
    return False, status == "NOT_FOUND" or "UNREGISTERED" in str(error)


def send_push_notification(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """Send a single FCM push notification. Returns True on success."""
    access_token = _get_access_token()
    if not access_token:
        return False
    success, _ = _send_single(token, title, body, data, access_token)
    return success


def send_push_notifications_batch(tokens: list[str], title: str, body: str, data: dict | None = None) -> tuple[int, int, list[str]]:
    """Send FCM push to multiple tokens.

    Returns (success_count, failure_count, invalid_tokens).
    """
    access_token = _get_access_token()
    if not access_token:
        return 0, len(tokens), []

    success = 0
    failure = 0
    invalid_tokens: list[str] = []

    for token in tokens:
        try:
            ok, unregistered = _send_single(token, title, body, data, access_token)
            if ok:
                success += 1
            else:
                failure += 1
                if unregistered:
                    invalid_tokens.append(token)
        except Exception:
            logger.exception(f"Failed to send push to {token[:20]}...")
            failure += 1

    return success, failure, invalid_tokens
