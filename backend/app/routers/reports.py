"""건강 리포트 웹 링크 공유 엔드포인트 (프리미엄 전용)."""
import logging
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.dependencies import get_current_user, get_current_tier
from app.models.user import User
from app.services.report_service import generate_health_html, generate_vet_summary_html
from app.utils.security import decode_token

logger = logging.getLogger(__name__)


def _get_user_rate_limit_key(request: Request) -> str:
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        payload = decode_token(auth_header[7:])
        if payload and payload.get("sub"):
            return f"user:{payload['sub']}"
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(key_func=_get_user_rate_limit_key)
router = APIRouter(prefix="/reports", tags=["reports"])

_SHARE_TOKEN_EXPIRE_DAYS = 7

_ERROR_HTML = """<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:-apple-system,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#F9F9F9;color:#333;}
.card{text-align:center;padding:40px;background:#fff;border-radius:16px;box-shadow:0 2px 12px rgba(0,0,0,0.08);max-width:400px;}
h1{color:#FF9A42;font-size:24pt;margin-bottom:12px;}p{color:#97928A;font-size:11pt;line-height:1.6;}</style>
</head><body><div class="card"><h1>⚠️</h1><h1>{title}</h1><p>{message}</p></div></body></html>"""


def _create_share_token(
    pet_id: UUID,
    user_id: UUID,
    report_type: str,
    lang: str,
    date_from: date | None = None,
    date_to: date | None = None,
) -> str:
    settings = get_settings()
    payload = {
        "type": "report_share",
        "pet_id": str(pet_id),
        "user_id": str(user_id),
        "report_type": report_type,
        "lang": lang,
        "exp": datetime.now(timezone.utc) + timedelta(days=_SHARE_TOKEN_EXPIRE_DAYS),
    }
    if date_from:
        payload["date_from"] = date_from.isoformat()
    if date_to:
        payload["date_to"] = date_to.isoformat()
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def _decode_share_token(token: str) -> dict:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=410, detail="expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=400, detail="invalid_token")

    if payload.get("type") != "report_share":
        raise HTTPException(status_code=400, detail="invalid_token")
    return payload


@router.post("/share/health/{pet_id}")
@limiter.limit("10/minute")
async def share_health_report(
    pet_id: UUID,
    request: Request,
    date_from: date = Query(...),
    date_to: date = Query(...),
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
):
    """건강 리포트 공유 링크 생성 (프리미엄 전용)."""
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )

    if date_to < date_from:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_to must be >= date_from",
        )
    if (date_to - date_from).days > 90:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Date range cannot exceed 90 days",
        )

    language = request.headers.get("Accept-Language", "ko").split(",")[0].split("-")[0]

    token = _create_share_token(
        pet_id=pet_id,
        user_id=current_user.id,
        report_type="health",
        lang=language,
        date_from=date_from,
        date_to=date_to,
    )

    base_url = str(request.base_url).rstrip("/")
    settings = get_settings()
    share_url = f"{base_url}{settings.api_v1_prefix}/reports/view/{token}"
    return {"share_url": share_url}


@router.post("/share/vet-summary/{pet_id}")
@limiter.limit("10/minute")
async def share_vet_summary(
    pet_id: UUID,
    request: Request,
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
):
    """병원 방문 요약 공유 링크 생성 (프리미엄 전용)."""
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )

    language = request.headers.get("Accept-Language", "ko").split(",")[0].split("-")[0]

    # 공유 시점의 날짜 범위를 토큰에 스냅샷으로 저장
    snapshot_to = date.today()
    snapshot_from = snapshot_to - timedelta(days=30)

    token = _create_share_token(
        pet_id=pet_id,
        user_id=current_user.id,
        report_type="vet_summary",
        lang=language,
        date_from=snapshot_from,
        date_to=snapshot_to,
    )

    base_url = str(request.base_url).rstrip("/")
    settings = get_settings()
    share_url = f"{base_url}{settings.api_v1_prefix}/reports/view/{token}"
    return {"share_url": share_url}


@router.get("/view/{token}", response_class=HTMLResponse)
async def view_report(
    token: str,
    db: AsyncSession = Depends(get_db),
):
    """공유 토큰으로 리포트 HTML 렌더링 (공개 접근)."""
    try:
        payload = _decode_share_token(token)
    except HTTPException as e:
        if e.detail == "expired":
            return HTMLResponse(
                content=_ERROR_HTML.format(
                    title="Link Expired",
                    message="This report link has expired. Please request a new link from the app.",
                ),
                status_code=410,
            )
        return HTMLResponse(
            content=_ERROR_HTML.format(
                title="Invalid Link",
                message="This report link is invalid or has been tampered with.",
            ),
            status_code=400,
        )

    pet_id = UUID(payload["pet_id"])
    user_id = UUID(payload["user_id"])
    report_type = payload["report_type"]
    lang = payload.get("lang", "ko")

    try:
        if report_type == "health":
            date_from = date.fromisoformat(payload["date_from"])
            date_to = date.fromisoformat(payload["date_to"])
            html = await generate_health_html(
                db=db,
                pet_id=pet_id,
                user_id=user_id,
                date_from=date_from,
                date_to=date_to,
                language=lang,
            )
        elif report_type == "vet_summary":
            # 토큰에 저장된 날짜 스냅샷 사용 (없으면 서비스에서 최근 30일 폴백)
            vet_from = date.fromisoformat(payload["date_from"]) if "date_from" in payload else None
            vet_to = date.fromisoformat(payload["date_to"]) if "date_to" in payload else None
            html = await generate_vet_summary_html(
                db=db,
                pet_id=pet_id,
                user_id=user_id,
                language=lang,
                date_from=vet_from,
                date_to=vet_to,
            )
        else:
            return HTMLResponse(
                content=_ERROR_HTML.format(
                    title="Unknown Report",
                    message="Unknown report type.",
                ),
                status_code=400,
            )
    except HTTPException:
        return HTMLResponse(
            content=_ERROR_HTML.format(
                title="Not Found",
                message="The pet data for this report could not be found.",
            ),
            status_code=404,
        )
    except Exception:
        logger.exception("Error generating report HTML")
        return HTMLResponse(
            content=_ERROR_HTML.format(
                title="Error",
                message="An error occurred while generating the report.",
            ),
            status_code=500,
        )

    return HTMLResponse(content=html)
