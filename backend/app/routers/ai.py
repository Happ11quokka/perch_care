import time
import logging
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.ai_encyclopedia_log import AiEncyclopediaLog
from app.schemas.ai import AiEncyclopediaRequest, AiEncyclopediaResponse
from app.services import ai_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/encyclopedia", response_model=AiEncyclopediaResponse)
async def encyclopedia(
    body: AiEncyclopediaRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    start = time.monotonic()

    answer = await ai_service.ask(
        db=db,
        query=body.query,
        history=body.history,
        pet_id=body.pet_id,
        pet_profile_context=body.pet_profile_context,
        temperature=body.temperature,
        max_tokens=body.max_tokens,
    )

    elapsed_ms = int((time.monotonic() - start) * 1000)

    # Log metadata to DB
    try:
        pet_uuid = UUID(body.pet_id) if body.pet_id else None
    except (ValueError, AttributeError):
        pet_uuid = None

    log_entry = AiEncyclopediaLog(
        user_id=current_user.id,
        pet_id=pet_uuid,
        query_length=len(body.query),
        response_length=len(answer),
        response_time_ms=elapsed_ms,
        model=ai_service.MODEL,
        tokens_used=None,
    )
    db.add(log_entry)

    return AiEncyclopediaResponse(answer=answer)
