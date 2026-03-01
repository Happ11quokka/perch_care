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

    raw_answer = await ai_service.ask(
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

    # 메타데이터 파싱 (category/severity/vet_recommended 추출)
    parsed = ai_service.parse_response_metadata(raw_answer)

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
        response_length=len(parsed["answer"]),
        response_time_ms=elapsed_ms,
        model=model,
        tokens_used=None,
    )
    db.add(log_entry)

    return AiEncyclopediaResponse(
        answer=parsed["answer"],
        category=parsed["category"],
        severity=parsed["severity"],
        vet_recommended=parsed["vet_recommended"],
    )


@router.post("/encyclopedia/stream")
@limiter.limit("20/minute")
async def encyclopedia_stream(
    body: AiEncyclopediaRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
):
    """SSE 스트리밍으로 AI 백과사전 응답을 실시간 전송한다."""
    start_time = time.monotonic()
    model, tier_max_tokens = ai_service._select_model(tier)
    effective_max_tokens = min(body.max_tokens, tier_max_tokens)

    pet_uuid = None
    if body.pet_id:
        try:
            pet_uuid = UUID(body.pet_id)
        except (ValueError, AttributeError):
            pass

    # 짧은 세션으로 사전 조회 후 즉시 반환 (스트리밍 중 커넥션 점유 방지)
    async with async_session_factory() as prefetch_db:
        system_message = await ai_service.prepare_system_message(
            db=prefetch_db,
            query=body.query,
            pet_id=body.pet_id,
            pet_profile_context=body.pet_profile_context,
            user_id=current_user.id,
            tier=tier,
        )

    # 캡처한 값들 — 제너레이터 내부에서 DB 불필요
    user_id = current_user.id
    query_text = body.query
    history = body.history
    temperature = body.temperature

    async def event_generator():
        accumulated = []
        meta_stripped = False
        meta_buffer = ""
        try:
            async for token in ai_service.ask_stream_with_message(
                system_message=system_message,
                query=query_text,
                history=history,
                model=model,
                temperature=temperature,
                effective_max_tokens=effective_max_tokens,
            ):
                accumulated.append(token)
                # 메타데이터 태그가 응답 첫 부분에 포함 — 클라이언트에 보내지 않음
                if not meta_stripped:
                    meta_buffer += token
                    if "-->" in meta_buffer:
                        # 메타 태그 종료: 태그 이후 텍스트만 전송
                        meta_stripped = True
                        remainder = meta_buffer.split("-->", 1)[1].lstrip("\n")
                        if remainder:
                            yield f"data: {json.dumps({'token': remainder}, ensure_ascii=False)}\n\n"
                    continue
                yield f"data: {json.dumps({'token': token}, ensure_ascii=False)}\n\n"

            # 전체 응답에서 메타데이터 파싱
            full_raw = "".join(accumulated)
            parsed = ai_service.parse_response_metadata(full_raw)

            # P2: done 이벤트에 메타데이터 포함
            done_payload = {"done": True}
            if parsed["category"]:
                done_payload["category"] = parsed["category"]
            if parsed["severity"]:
                done_payload["severity"] = parsed["severity"]
            if parsed["vet_recommended"] is not None:
                done_payload["vet_recommended"] = parsed["vet_recommended"]
            yield f"data: {json.dumps(done_payload, ensure_ascii=False)}\n\n"

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
