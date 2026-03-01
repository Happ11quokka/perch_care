import json
import time
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse
from slowapi import Limiter
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db, async_session_factory
from app.dependencies import get_current_user, get_current_tier
from app.models.user import User
from app.models.ai_encyclopedia_log import AiEncyclopediaLog
from app.schemas.ai import AiEncyclopediaRequest, AiEncyclopediaResponse
from app.services import ai_service
from app.utils.security import decode_token

logger = logging.getLogger(__name__)


def _get_user_rate_limit_key(request: Request) -> str:
    """JWT에서 사용자 ID 추출하여 rate limit 키로 사용. 실패 시 IP fallback."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        payload = decode_token(auth_header[7:])
        if payload and payload.get("sub"):
            return f"user:{payload['sub']}"
    from slowapi.util import get_remote_address
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(key_func=_get_user_rate_limit_key)
router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/encyclopedia", response_model=AiEncyclopediaResponse)
async def encyclopedia(
    body: AiEncyclopediaRequest,
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    start = time.monotonic()
    model, _ = ai_service._select_model(tier)

    answer = await ai_service.ask(
        db=db,
        query=body.query,
        history=body.history,
        tier=tier,
        pet_id=body.pet_id,
        pet_profile_context=body.pet_profile_context,
        temperature=body.temperature,
        max_tokens=body.max_tokens,
        user_id=current_user.id,
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
        model=model,
        tokens_used=None,
    )
    db.add(log_entry)

    return AiEncyclopediaResponse(answer=answer)


@router.post("/encyclopedia/stream")
@limiter.limit("20/minute")
async def encyclopedia_stream(
    body: AiEncyclopediaRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """SSE 스트리밍으로 AI 백과사전 응답을 실시간 전송한다."""
    start_time = time.monotonic()
    model, _ = ai_service._select_model(tier)

    pet_uuid = None
    if body.pet_id:
        try:
            pet_uuid = UUID(body.pet_id)
        except (ValueError, AttributeError):
            pass

    # P1: 스트리밍 시작 전 DB 조회(RAG) 완료 후 시스템 메시지 사전 구성
    rag_context = await ai_service._build_rag_context(db, body.pet_id, user_id=current_user.id)
    system_message = ai_service._build_system_message(rag_context, body.pet_profile_context)

    # 캡처한 값들 — 제너레이터 내부에서 DB 불필요
    user_id = current_user.id
    query_text = body.query
    history = body.history
    temperature = body.temperature
    max_tokens = body.max_tokens

    async def event_generator():
        accumulated = []
        try:
            async for token in ai_service.ask_stream_with_message(
                system_message=system_message,
                query=query_text,
                history=history,
                tier=tier,
                temperature=temperature,
                max_tokens=max_tokens,
            ):
                accumulated.append(token)
                yield f"data: {json.dumps({'token': token}, ensure_ascii=False)}\n\n"

            # P2: done 이벤트는 스트림 완료 후 즉시 전송
            yield f"data: {json.dumps({'done': True})}\n\n"

        except Exception as e:
            logger.error(f"AI stream error: {e}", exc_info=True)
            yield f"data: {json.dumps({'error': '답변 생성 중 오류가 발생했습니다.'}, ensure_ascii=False)}\n\n"
        finally:
            # P1: 로그 기록은 별도 세션에서 수행 (스트리밍 세션과 분리)
            elapsed_ms = int((time.monotonic() - start_time) * 1000)
            full_response = "".join(accumulated)
            try:
                async with async_session_factory() as log_session:
                    log_entry = AiEncyclopediaLog(
                        user_id=user_id,
                        pet_id=pet_uuid,
                        query_length=len(query_text),
                        response_length=len(full_response),
                        response_time_ms=elapsed_ms,
                        model=model,
                        tokens_used=None,
                    )
                    log_session.add(log_entry)
                    await log_session.commit()
            except Exception as log_err:
                logger.error(f"AI stream log save failed: {log_err}", exc_info=True)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
