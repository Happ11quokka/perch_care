import json
import time
import logging
from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, get_current_tier
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
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    start = time.monotonic()

    answer = await ai_service.ask(
        db=db,
        query=body.query,
        history=body.history,
        tier=tier,
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

    model_used = "gpt-4.1-nano" if tier == "premium" else ai_service.MODEL
    log_entry = AiEncyclopediaLog(
        user_id=current_user.id,
        pet_id=pet_uuid,
        query_length=len(body.query),
        response_length=len(answer),
        response_time_ms=elapsed_ms,
        model=model_used,
        tokens_used=None,
    )
    db.add(log_entry)

    return AiEncyclopediaResponse(answer=answer)


@router.post("/encyclopedia/stream")
async def encyclopedia_stream(
    body: AiEncyclopediaRequest,
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """SSE 스트리밍으로 AI 백과사전 응답을 실시간 전송한다."""
    start_time = time.monotonic()

    pet_uuid = None
    if body.pet_id:
        try:
            pet_uuid = UUID(body.pet_id)
        except (ValueError, AttributeError):
            pass

    async def event_generator():
        accumulated = []
        model_used = "gpt-4.1-nano" if tier == "premium" else ai_service.MODEL
        try:
            async for token in ai_service.ask_stream(
                db=db,
                query=body.query,
                history=body.history,
                tier=tier,
                pet_id=body.pet_id,
                pet_profile_context=body.pet_profile_context,
                temperature=body.temperature,
                max_tokens=body.max_tokens,
            ):
                accumulated.append(token)
                yield f"data: {json.dumps({'token': token}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'done': True})}\n\n"

            # 스트림 완료 후 로그 기록
            elapsed_ms = int((time.monotonic() - start_time) * 1000)
            full_response = "".join(accumulated)
            log_entry = AiEncyclopediaLog(
                user_id=current_user.id,
                pet_id=pet_uuid,
                query_length=len(body.query),
                response_length=len(full_response),
                response_time_ms=elapsed_ms,
                model=model_used,
                tokens_used=None,
            )
            db.add(log_entry)
            await db.commit()
        except Exception as e:
            logger.error(f"AI stream error: {e}", exc_info=True)
            yield f"data: {json.dumps({'error': '답변 생성 중 오류가 발생했습니다.'}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
