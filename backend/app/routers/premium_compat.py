"""구버전 앱 호환용 임시 스텁 — 구앱 소멸 후 제거.

이번 브랜치에서 premium 라우터/스키마 전체가 삭제됐지만, 배포된 구버전 앱은 시작 시
`GET /premium/tier`를 호출하고 모든 에러(404 포함)를 "잠금" 상태로 처리한다
(구앱 `_loadPremiumStatus`의 catch가 `_isLocked=true`를 설정 → 건강체크 카드 잠김 +
홈 건강요약 사라짐). 신버전 클라이언트는 premium 기능 자체가 제거되어 이 엔드포인트를
호출하지 않는다.

여기서는 구 응답 스키마(`TierResponse`)와 동일한 형태만 복원한다. premium 기능이
완전히 제거됐으므로 tier는 항상 "free"로 고정하고, activate/verify/restore 등
나머지 premium 엔드포인트는 복원하지 않는다. quota는 실제 사용량을 반영해 구앱의
쿼터 표시가 서버 강제 한도(quota_service)와 어긋나지 않도록 한다.
"""

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services.quota_service import check_encyclopedia_quota, check_vision_access

router = APIRouter(prefix="/premium", tags=["premium-compat"])


class _QuotaBlock(BaseModel):
    monthly_limit: int
    monthly_used: int
    remaining: int


class _QuotaInfo(BaseModel):
    ai_encyclopedia: _QuotaBlock
    vision: _QuotaBlock


class TierCompatResponse(BaseModel):
    tier: str = "free"
    premium_expires_at: datetime | None = None
    source: str | None = None
    store_product_id: str | None = None
    auto_renew_status: bool | None = None
    quota: _QuotaInfo


@router.get("/tier", response_model=TierCompatResponse)
async def get_tier_compat(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> TierCompatResponse:
    """구버전 앱 호환: 항상 free tier + 실제 월간 사용량을 반환한다."""
    enc = await check_encyclopedia_quota(db, user_id)
    vis = await check_vision_access(db, user_id)
    return TierCompatResponse(
        quota=_QuotaInfo(
            ai_encyclopedia=_QuotaBlock(
                monthly_limit=enc["monthly_limit"],
                monthly_used=enc["monthly_used"],
                remaining=enc["remaining"],
            ),
            vision=_QuotaBlock(
                monthly_limit=vis["monthly_limit"],
                monthly_used=vis["monthly_used"],
                remaining=vis["remaining"],
            ),
        ),
    )
