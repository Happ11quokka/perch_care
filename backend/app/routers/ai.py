import base64
import json
import time
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, Form, HTTPException, Request, UploadFile, File, status
from fastapi.responses import StreamingResponse
from slowapi import Limiter
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db, async_session_factory
from app.dependencies import get_current_user, get_current_tier
from app.models.user import User
from app.models.ai_encyclopedia_log import AiEncyclopediaLog
from app.models.ai_vision_log import AiVisionLog
from app.schemas.ai import AiEncyclopediaRequest, AiEncyclopediaResponse
from app.services import ai_service
from app.services.quota_service import (
    check_encyclopedia_quota,
    check_vision_access,
    check_and_reserve_encyclopedia,
    check_and_reserve_vision,
)
from sqlalchemy import delete, update
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
    model, _ = ai_service._select_model(tier)
    try:
        pet_uuid = UUID(body.pet_id) if body.pet_id else None
    except (ValueError, AttributeError):
        pet_uuid = None

    # Phase 2: 쿼터 체크 + 슬롯 예약 (advisory lock으로 동시 요청 방지)
    quota, reservation = await check_and_reserve_encyclopedia(
        db, current_user.id, tier, pet_uuid, len(body.query), model,
    )
    if not quota["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="일일 무료 사용량을 초과했습니다. 내일 다시 시도하거나 프리미엄을 구독하세요.",
        )

    start = time.monotonic()
    # AI 실패 시 트랜잭션 rollback → 예약 자동 삭제 (get_db 패턴)
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

    parsed = ai_service.parse_response_metadata(raw_answer)
    elapsed_ms = int((time.monotonic() - start) * 1000)

    if reservation:
        # Free 사용자: 예약 로그 업데이트
        reservation.response_length = len(parsed["answer"])
        reservation.response_time_ms = elapsed_ms
    else:
        # Premium 사용자: 새 로그 생성
        db.add(AiEncyclopediaLog(
            user_id=current_user.id,
            pet_id=pet_uuid,
            query_length=len(body.query),
            response_length=len(parsed["answer"]),
            response_time_ms=elapsed_ms,
            model=model,
            tokens_used=None,
        ))

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
    model, tier_max_tokens = ai_service._select_model(tier)
    effective_max_tokens = min(body.max_tokens, tier_max_tokens)

    pet_uuid = None
    if body.pet_id:
        try:
            pet_uuid = UUID(body.pet_id)
        except (ValueError, AttributeError):
            pass

    # Phase 2: 쿼터 체크 + 슬롯 예약 (별도 세션 — commit하여 동시 요청에 노출)
    reservation_id = None
    async with async_session_factory() as quota_db:
        quota, reservation = await check_and_reserve_encyclopedia(
            quota_db, current_user.id, tier, pet_uuid, len(body.query), model,
        )
        if not quota["allowed"]:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="일일 무료 사용량을 초과했습니다. 내일 다시 시도하거나 프리미엄을 구독하세요.",
            )
        if reservation:
            await quota_db.commit()  # 예약 커밋 + advisory lock 해제
            reservation_id = reservation.id

    start_time = time.monotonic()

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
                    # 안전장치: 200자 초과 시 메타태그 없는 것으로 판단하고 버퍼 플러시
                    if len(meta_buffer) > 200:
                        meta_stripped = True
                        yield f"data: {json.dumps({'token': meta_buffer}, ensure_ascii=False)}\n\n"
                        continue
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
                    if reservation_id:
                        if len(full_response) == 0:
                            # AI 실패(토큰 0개): 예약 삭제 → 쿼터 슬롯 반환
                            await log_session.execute(
                                delete(AiEncyclopediaLog)
                                .where(AiEncyclopediaLog.id == reservation_id)
                            )
                        else:
                            # Free 사용자: 예약 로그 업데이트
                            await log_session.execute(
                                update(AiEncyclopediaLog)
                                .where(AiEncyclopediaLog.id == reservation_id)
                                .values(
                                    response_length=len(full_response),
                                    response_time_ms=elapsed_ms,
                                )
                            )
                    else:
                        # Premium 사용자: 새 로그 생성
                        log_session.add(AiEncyclopediaLog(
                            user_id=user_id,
                            pet_id=pet_uuid,
                            query_length=len(query_text),
                            response_length=len(full_response),
                            response_time_ms=elapsed_ms,
                            model=model,
                            tokens_used=None,
                        ))
                    await log_session.commit()
            except Exception as log_err:
                logger.error(f"AI stream log save failed: {log_err}", exc_info=True)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.post("/vision/analyze")
@limiter.limit("10/minute")
async def analyze_vision_no_pet(
    request: Request,
    mode: str = Form(...),
    part: str | None = Form(None),
    notes: str | None = Form(None),
    language: str | None = Form(None),
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """펫 없이 Vision 분석 (food 모드 전용). DB 저장 없이 결과만 반환."""
    settings = get_settings()

    # 입력 검증을 쿼터 체크 전에 수행 (불필요한 잠금 방지)
    if mode != "food":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="펫 없이는 food 모드만 사용할 수 있습니다",
        )

    content_type = image.content_type or ""
    if content_type not in _ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"지원하지 않는 이미지 형식입니다. {', '.join(_ALLOWED_MIME_TYPES)}만 허용됩니다",
        )

    image_bytes = await image.read()
    if len(image_bytes) > settings.max_upload_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"이미지 크기가 {settings.max_upload_size // (1024 * 1024)}MB를 초과합니다",
        )
    if len(image_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="빈 이미지 파일입니다",
        )

    # Phase 2: Vision 쿼터 체크 + 슬롯 예약 (advisory lock으로 동시 요청 방지)
    vis, reservation = await check_and_reserve_vision(
        db, current_user.id, tier, None, mode, part, len(image_bytes),
    )
    if not vis["allowed"]:
        raise HTTPException(status_code=403, detail="프리미엄 전용 기능입니다")

    image_base64 = base64.b64encode(image_bytes).decode("utf-8")

    start_time = time.monotonic()
    # AI 실패 시 HTTPException → get_db rollback → 예약 자동 삭제
    try:
        result = await ai_service.analyze_vision_health_check(
            db=db,
            pet_id=None,
            user_id=current_user.id,
            image_base64=image_base64,
            mime_type=content_type,
            mode=mode,
            part=part,
            notes=notes,
            tier=tier,
            language=language,
        )
    except Exception as e:
        logger.error("Vision analysis (no pet) failed: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="이미지 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
        )

    # Vision 사용 로그 업데이트/생성
    elapsed_ms = int((time.monotonic() - start_time) * 1000)
    confidence = None
    overall_status = None
    if isinstance(result, dict):
        cs = result.get("confidence_score")
        confidence = float(cs) if isinstance(cs, (int, float)) else None
        overall_status = result.get("overall_status")

    if reservation:
        # Free 사용자: 예약 로그 업데이트
        reservation.response_time_ms = elapsed_ms
        reservation.confidence_score = confidence
        reservation.overall_status = overall_status
    else:
        # Premium 사용자: 새 로그 생성
        db.add(AiVisionLog(
            user_id=current_user.id,
            pet_id=None,
            mode=mode,
            part=part,
            image_size_bytes=len(image_bytes),
            response_time_ms=elapsed_ms,
            model="gpt-4o",
            tier=tier,
            confidence_score=confidence,
            overall_status=overall_status,
        ))

    return {"result": result}


@router.get("/quota")
async def get_ai_quota(
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """현재 사용자의 AI 기능 쿼터를 조회한다."""
    enc = await check_encyclopedia_quota(db, current_user.id, tier)
    vis = await check_vision_access(db, current_user.id, tier)
    return {
        "ai_encyclopedia": {
            "daily_limit": enc["daily_limit"],
            "daily_used": enc["daily_used"],
            "remaining": enc["remaining"],
        },
        "vision_trial_remaining": vis["trial_remaining"],
    }
