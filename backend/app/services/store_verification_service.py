"""스토어 영수증 검증 서비스.

Apple App Store Server API v2 및 Google Play Developer API를 사용하여
구독 거래를 검증한다.
"""
import base64
import json
import logging
import time
from datetime import datetime, timezone

import httpx
import jwt as pyjwt
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account

from app.config import get_settings

logger = logging.getLogger(__name__)

# Apple API endpoints
_APPLE_PRODUCTION_URL = "https://api.storekit.itunes.apple.com"
_APPLE_SANDBOX_URL = "https://api.storekit-sandbox.itunes.apple.com"

# Google API endpoint
_GOOGLE_API_URL = "https://androidpublisher.googleapis.com/androidpublisher/v3"


class StoreVerificationError(Exception):
    """스토어 검증 실패."""

    def __init__(self, detail: str = "스토어 검증에 실패했습니다", store: str = "unknown"):
        self.detail = detail
        self.store = store
        super().__init__(detail)


def _generate_apple_jwt() -> str:
    """Apple App Store Server API 인증용 ES256 JWT 생성."""
    settings = get_settings()

    if not settings.apple_key_id or not settings.apple_issuer_id or not settings.apple_private_key:
        raise StoreVerificationError("Apple IAP 설정이 누락되었습니다", store="apple")

    # Base64로 인코딩된 .p8 키 디코딩
    private_key = base64.b64decode(settings.apple_private_key).decode("utf-8")

    now = int(time.time())
    payload = {
        "iss": settings.apple_issuer_id,
        "iat": now,
        "exp": now + 3600,  # 1시간 유효
        "aud": "appstoreconnect-v1",
        "bid": settings.apple_bundle_id,
    }
    headers = {
        "alg": "ES256",
        "kid": settings.apple_key_id,
        "typ": "JWT",
    }

    return pyjwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def _decode_apple_jws(signed_payload: str) -> dict:
    """Apple JWS signedTransactionInfo를 디코딩. 서명 검증은 Apple이 이미 수행."""
    # Apple JWS는 3파트 JWT 형식. 페이로드만 추출 (서명 검증은 Apple API 응답을 신뢰)
    parts = signed_payload.split(".")
    if len(parts) != 3:
        raise StoreVerificationError("잘못된 Apple JWS 형식입니다", store="apple")

    # Base64url 디코딩 (패딩 보정)
    payload_b64 = parts[1]
    padding = 4 - len(payload_b64) % 4
    if padding != 4:
        payload_b64 += "=" * padding

    payload_bytes = base64.urlsafe_b64decode(payload_b64)
    return json.loads(payload_bytes)


async def verify_apple_transaction(transaction_id: str) -> dict:
    """Apple App Store Server API v2로 거래 검증.

    Args:
        transaction_id: StoreKit 2 transactionId

    Returns:
        dict with keys: product_id, original_transaction_id, expires_date,
                       auto_renew_status, environment, purchased_at
    """
    token = _generate_apple_jwt()

    # Production 먼저 시도, 실패 시 Sandbox
    for base_url in [_APPLE_PRODUCTION_URL, _APPLE_SANDBOX_URL]:
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.get(
                    f"{base_url}/inApps/v1/transactions/{transaction_id}",
                    headers={"Authorization": f"Bearer {token}"},
                )

                if response.status_code == 404:
                    if base_url == _APPLE_PRODUCTION_URL:
                        logger.info("Apple production 404, trying sandbox for transaction=%s", transaction_id)
                        continue
                    raise StoreVerificationError("거래를 찾을 수 없습니다", store="apple")

                if response.status_code != 200:
                    logger.error("Apple API error: status=%d, body=%s", response.status_code, response.text[:200])
                    raise StoreVerificationError(f"Apple API 오류 ({response.status_code})", store="apple")

                data = response.json()
                signed_info = data.get("signedTransactionInfo", "")
                tx_info = _decode_apple_jws(signed_info)

                expires_ms = tx_info.get("expiresDate")
                purchased_ms = tx_info.get("purchaseDate")

                return {
                    "product_id": tx_info.get("productId", ""),
                    "original_transaction_id": tx_info.get("originalTransactionId", ""),
                    "expires_date": datetime.fromtimestamp(expires_ms / 1000, tz=timezone.utc) if expires_ms else None,
                    "auto_renew_status": tx_info.get("autoRenewStatus", 0) == 1,
                    "environment": tx_info.get("environment", "Production"),
                    "purchased_at": datetime.fromtimestamp(purchased_ms / 1000, tz=timezone.utc) if purchased_ms else None,
                }

        except StoreVerificationError:
            raise
        except httpx.HTTPError as e:
            logger.error("Apple HTTP error for transaction=%s: %s", transaction_id, str(e))
            if base_url == _APPLE_PRODUCTION_URL:
                continue
            raise StoreVerificationError("Apple 서버 연결에 실패했습니다", store="apple")
        except Exception as e:
            logger.error("Apple verification unexpected error: %s", str(e))
            raise StoreVerificationError("Apple 검증 중 오류가 발생했습니다", store="apple")

    raise StoreVerificationError("거래를 찾을 수 없습니다", store="apple")


def _get_google_credentials():
    """Google 서비스 계정 인증 정보 생성."""
    settings = get_settings()

    if not settings.google_service_account_json:
        raise StoreVerificationError("Google IAP 설정이 누락되었습니다", store="google")

    # Base64로 인코딩된 서비스 계정 JSON 디코딩
    sa_json = json.loads(base64.b64decode(settings.google_service_account_json))

    credentials = service_account.Credentials.from_service_account_info(
        sa_json,
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    credentials.refresh(GoogleAuthRequest())
    return credentials


async def verify_google_purchase(product_id: str, purchase_token: str) -> dict:
    """Google Play Developer API로 구독 구매 검증.

    Args:
        product_id: Google Play 상품 ID
        purchase_token: 구매 토큰

    Returns:
        dict with keys: product_id, original_transaction_id (orderId),
                       expires_date, auto_renew_status, purchased_at
    """
    settings = get_settings()
    credentials = _get_google_credentials()

    url = (
        f"{_GOOGLE_API_URL}/applications/{settings.google_package_name}"
        f"/purchases/subscriptionsv2/tokens/{purchase_token}"
    )

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.get(
                url,
                headers={"Authorization": f"Bearer {credentials.token}"},
            )

            if response.status_code == 404:
                raise StoreVerificationError("구매를 찾을 수 없습니다", store="google")

            if response.status_code != 200:
                logger.error("Google API error: status=%d, body=%s", response.status_code, response.text[:200])
                raise StoreVerificationError(f"Google API 오류 ({response.status_code})", store="google")

            data = response.json()

            # expiryTime은 RFC 3339 형식
            expiry_str = data.get("lineItems", [{}])[0].get("expiryTime")
            start_str = data.get("startTime")
            auto_renewing = data.get("lineItems", [{}])[0].get("autoRenewingPlan", {}).get("autoRenewEnabled", False)

            return {
                "product_id": product_id,
                "original_transaction_id": data.get("latestOrderId", ""),
                "expires_date": datetime.fromisoformat(expiry_str.replace("Z", "+00:00")) if expiry_str else None,
                "auto_renew_status": auto_renewing,
                "environment": "Sandbox" if data.get("testPurchase") else "Production",
                "purchased_at": datetime.fromisoformat(start_str.replace("Z", "+00:00")) if start_str else None,
            }

    except StoreVerificationError:
        raise
    except httpx.HTTPError as e:
        logger.error("Google HTTP error: %s", str(e))
        raise StoreVerificationError("Google 서버 연결에 실패했습니다", store="google")
    except Exception as e:
        logger.error("Google verification unexpected error: %s", str(e))
        raise StoreVerificationError("Google 검증 중 오류가 발생했습니다", store="google")


async def verify_store_transaction(store: str, product_id: str, transaction_id: str) -> dict:
    """통합 스토어 검증 진입점.

    Args:
        store: 'apple' 또는 'google'
        product_id: 상품 ID
        transaction_id: Apple transactionId 또는 Google purchaseToken

    Returns:
        통합 검증 결과 dict
    """
    if store == "apple":
        return await verify_apple_transaction(transaction_id)
    elif store == "google":
        return await verify_google_purchase(product_id, transaction_id)
    else:
        raise StoreVerificationError(f"지원하지 않는 스토어: {store}", store=store)
