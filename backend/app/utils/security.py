from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from jose.utils import base64url_decode
import bcrypt
import httpx
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers
from cryptography.hazmat.backends import default_backend
from app.config import get_settings

settings = get_settings()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))


def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {"sub": user_id, "exp": expire, "iat": datetime.now(timezone.utc), "type": "access"}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    payload = {"sub": user_id, "exp": expire, "iat": datetime.now(timezone.utc), "type": "refresh"}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        return payload
    except JWTError:
        return None


def verify_kakao_access_token(token: str) -> dict | None:
    """Verify Kakao access token by calling Kakao user info API.

    Returns dict with 'sub' (user id) and 'email' on success, None on failure.
    """
    try:
        resp = httpx.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        if resp.status_code != 200:
            return None
        data = resp.json()
        user_id = str(data.get("id", ""))
        if not user_id:
            return None
        email = None
        kakao_account = data.get("kakao_account")
        if kakao_account and kakao_account.get("has_email"):
            email = kakao_account.get("email")
        return {"sub": user_id, "email": email}
    except Exception:
        return None


def _get_apple_public_key(kid: str):
    """Fetch Apple's public keys and return the matching RSA public key."""
    resp = httpx.get("https://appleid.apple.com/auth/keys", timeout=10)
    resp.raise_for_status()
    keys = resp.json().get("keys", [])
    for key_data in keys:
        if key_data["kid"] == kid:
            n = int.from_bytes(base64url_decode(key_data["n"]), "big")
            e = int.from_bytes(base64url_decode(key_data["e"]), "big")
            return RSAPublicNumbers(e, n).public_key(default_backend())
    return None


def verify_apple_id_token(token: str) -> dict | None:
    """Verify Apple ID token and return user info (sub, email).

    Returns dict with 'sub' (Apple user id) and 'email' on success, None on failure.
    """
    try:
        headers = jwt.get_unverified_header(token)
        kid = headers.get("kid")
        if not kid:
            return None

        public_key = _get_apple_public_key(kid)
        if not public_key:
            return None

        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=settings.apple_client_id,
            issuer="https://appleid.apple.com",
        )

        sub = payload.get("sub")
        if not sub:
            return None

        return {"sub": sub, "email": payload.get("email")}
    except Exception:
        return None


def verify_google_id_token(token: str) -> dict | None:
    """Verify Google ID token and return user info (sub, email, etc.)."""
    try:
        idinfo = google_id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            audience=settings.google_client_id,
        )
        return idinfo
    except Exception:
        return None
