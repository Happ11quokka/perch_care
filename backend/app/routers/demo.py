"""웹 데모(perch.ai.kr) 공개 엔드포인트.

JWT 대신 X-Demo-Key 공유 시크릿(perch_web 서버만 보유)으로 인증하고,
IP별·글로벌 일일 쿼터(demo_quota_service)로 비용 폭주를 방지한다.
클라이언트 IP는 프록시가 X-Demo-Client-IP 헤더로 전달 (키 인증된 요청만 신뢰).
"""

import base64
import json
import logging
import re
import uuid
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Request, UploadFile, status
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import async_session_factory, get_db
from app.models.demo_usage_log import DemoUsageLog
from app.services import ai_service
from app.services.demo_bhi_service import calculate_demo_bhi
from app.services.demo_quota_service import check_and_reserve

logger = logging.getLogger(__name__)


async def verify_demo_key(
    x_demo_key: str = Header(..., alias="X-Demo-Key"),
) -> None:
    """데모 API 키 검증. X-Demo-Key 헤더 필수 (dependencies.verify_admin_api_key 패턴)."""
    settings = get_settings()
    if not settings.demo_api_key:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Demo API not configured")
    if x_demo_key != settings.demo_api_key:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid demo API key")


def _demo_rate_limit_key(request: Request) -> str:
    """X-Demo-Client-IP 헤더(프록시가 전달) 우선, 없으면 원격 주소 (Vercel 단일 IP 문제 회피)."""
    client_ip = request.headers.get("X-Demo-Client-IP")
    if client_ip:
        return f"demo:{client_ip}"
    return f"demo:{get_remote_address(request)}"


def _get_client_ip(request: Request) -> str:
    """쿼터 집계용 클라이언트 IP. 프록시 헤더 우선."""
    return request.headers.get("X-Demo-Client-IP") or get_remote_address(request)


limiter = Limiter(key_func=_demo_rate_limit_key)
router = APIRouter(prefix="/demo", tags=["demo"])

# 샘플 펫 프로필 (C3 — 챗봇 컨텍스트 주입용, 데모 요청의 language로 선택)
_SAMPLE_PET_PROFILES = {
    "ko": (
        "참고용 샘플 펫 프로필 (웹 데모): 이름 콩이, 종 사랑앵무(budgerigar), "
        "나이 1년 6개월(adult), 최근 체중 32g, 목표 사료 10g/일, 목표 음수 6ml/일."
    ),
    "en": (
        "Reference sample pet profile (web demo): name Kongi, species budgerigar, "
        "age 1 year 6 months (adult), recent weight 32g, food target 10g/day, water target 6ml/day."
    ),
    "zh": (
        "参考用示例宠物档案（网页演示）：名字 Kongi，种类 虎皮鹦鹉（budgerigar），"
        "年龄 1 岁 6 个月（adult），最近体重 32g，目标饲料 10g/日，目标饮水 6ml/日。"
    ),
}

_DEMO_HISTORY_MAX = 20


def _quota_exceeded_response(quota: dict) -> JSONResponse:
    """쿼터 소진 429 응답 (C1 공통 포맷)."""
    return JSONResponse(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        content={"detail": {"code": quota["reason"], "limit": quota["limit"], "remaining": 0}},
    )


class DemoChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(..., min_length=1, max_length=2000)


class DemoChatRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=1000)
    history: list[DemoChatMessage] = Field(default_factory=list, max_length=_DEMO_HISTORY_MAX)
    language: Literal["ko", "en", "zh"] = "ko"


@router.post("/chat/stream")
@limiter.limit("10/minute")
async def demo_chat_stream(
    body: DemoChatRequest,
    request: Request,
    _: None = Depends(verify_demo_key),
):
    """웹 데모용 앵박사 SSE 스트리밍. 샘플 펫 프로필(콩이)을 컨텍스트로 주입한다."""
    client_ip = _get_client_ip(request)

    # 쿼터 체크 + 슬롯 예약 (별도 세션 — commit하여 동시 요청에 노출)
    async with async_session_factory() as quota_db:
        quota = await check_and_reserve(quota_db, client_ip, "chat")
        if not quota["allowed"]:
            return _quota_exceeded_response(quota)
        await quota_db.commit()  # 예약 커밋 + advisory lock 해제

    model, tier_max_tokens = ai_service._select_model("free")
    effective_max_tokens = min(1024, tier_max_tokens)

    # 짧은 세션으로 사전 조회 후 즉시 반환 (스트리밍 중 커넥션 점유 방지)
    async with async_session_factory() as prefetch_db:
        system_message = await ai_service.prepare_system_message(
            db=prefetch_db,
            query=body.query,
            pet_id=None,
            pet_profile_context=_SAMPLE_PET_PROFILES[body.language],
            user_id=None,
            tier="free",
        )

    # 캡처한 값들 — 제너레이터 내부에서 DB 불필요
    query_text = body.query
    history = [{"role": m.role, "content": m.content} for m in body.history[-_DEMO_HISTORY_MAX:]]
    quota_payload = {"remaining": quota["remaining"], "limit": quota["limit"]}
    reservation_id = quota["reservation_id"]

    async def event_generator():
        # 첫 이벤트: 남은 쿼터 (C1)
        yield f"data: {json.dumps({'quota': quota_payload}, ensure_ascii=False)}\n\n"

        accumulated = []
        meta_stripped = False
        meta_buffer = ""
        try:
            async for token in ai_service.ask_stream_with_message(
                system_message=system_message,
                query=query_text,
                history=history,
                model=model,
                temperature=0.2,
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

            # 스트림이 짧게 끝나 META 버퍼가 플러시되지 않은 경우 잔여 텍스트 전송
            if not meta_stripped and meta_buffer:
                flushed = ai_service.parse_response_metadata(meta_buffer)["answer"]
                # 헬퍼가 처리 못 한 META 태그 잔여물 제거 (완결 태그 + 미종결 prefix)
                flushed = re.sub(r"<!--\s*META:[^>]*-->", "", flushed)
                flushed = re.sub(r"<!--\s*META:.*\Z", "", flushed, flags=re.DOTALL).strip()
                if flushed:
                    yield f"data: {json.dumps({'token': flushed}, ensure_ascii=False)}\n\n"

            # 전체 응답에서 메타데이터 파싱
            full_raw = "".join(accumulated)
            parsed = ai_service.parse_response_metadata(full_raw)

            done_payload = {"done": True}
            if parsed["category"]:
                done_payload["category"] = parsed["category"]
            if parsed["severity"]:
                done_payload["severity"] = parsed["severity"]
            if parsed["vet_recommended"] is not None:
                done_payload["vet_recommended"] = parsed["vet_recommended"]
            yield f"data: {json.dumps(done_payload, ensure_ascii=False)}\n\n"

        except Exception as e:
            logger.error(f"Demo chat stream error: {e}", exc_info=True)
            yield f"data: {json.dumps({'error': '답변 생성 중 오류가 발생했습니다.'}, ensure_ascii=False)}\n\n"
        finally:
            # AI 실패·빈 응답(토큰 0개) 시 예약 삭제 → 쿼터 슬롯 반환 (ai.py 스트리밍 패턴)
            if not accumulated:
                try:
                    async with async_session_factory() as s:
                        await s.execute(delete(DemoUsageLog).where(DemoUsageLog.id == reservation_id))
                        await s.commit()
                except Exception as refund_err:
                    logger.error(f"Demo chat quota refund failed: {refund_err}", exc_info=True)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
_DEMO_VISION_MODES = {"full_body", "droppings", "food"}
_VISION_SEVERITIES = {"normal", "caution", "warning", "critical", "not_visible"}


_DIET_RELATED_NOTES = {
    "ko": "식이와 관련된 변화일 수 있어요.",
    "en": "May be diet-related.",
    "zh": "可能与饮食有关。",
}


def normalize_droppings_result(result: dict, language: str = "ko") -> dict:
    """droppings 모드 결과를 웹 클라이언트 계약 형태로 정규화한다.

    Vision 프롬프트(_VISION_DROPPINGS_PROMPT)는 finding을
    {component, color, texture, status, diet_related} + 최상위 possible_conditions[]로
    반환하지만, 웹 클라이언트는 {area, observation, severity, possible_causes}를
    렌더링한다. 이미 계약 형태인 finding은 그대로 둔다.
    """
    findings = result.get("findings")
    if not isinstance(findings, list):
        return result

    possible_conditions = result.get("possible_conditions", [])
    normalized = []
    for f in findings:
        if not isinstance(f, dict) or "component" not in f:
            normalized.append(f)  # 이미 계약 형태(또는 비정형) — 그대로 유지
            continue
        observation = ", ".join(p for p in [f.get("color"), f.get("texture")] if p)
        if f.get("diet_related"):
            note = _DIET_RELATED_NOTES.get(language, _DIET_RELATED_NOTES["en"])
            observation = f"{observation}. {note}" if observation else note
        severity = f.get("status", "not_visible")
        if severity not in _VISION_SEVERITIES:
            severity = "caution"
        normalized.append({
            "area": f["component"],
            "observation": observation,
            "severity": severity,
            "possible_causes": possible_conditions,
        })
    result["findings"] = normalized
    return result


@router.post("/vision/analyze")
@limiter.limit("5/minute")
async def demo_vision_analyze(
    request: Request,
    mode: str = Form(...),
    notes: str | None = Form(None),
    language: Literal["ko", "en", "zh"] | None = Form(None),
    image: UploadFile = File(...),
    _: None = Depends(verify_demo_key),
):
    """웹 데모용 Vision 분석. 이미지·결과를 저장하지 않고 DemoUsageLog만 기록한다."""
    settings = get_settings()

    # 입력 검증을 쿼터 체크 전에 수행 (불필요한 잠금 방지)
    if mode not in _DEMO_VISION_MODES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"지원하지 않는 분석 모드입니다. {', '.join(sorted(_DEMO_VISION_MODES))}만 허용됩니다",
        )

    if notes and len(notes) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="메모는 500자를 초과할 수 없습니다",
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

    # 매직 바이트 검증 (Content-Type 위조 방지)
    is_jpeg = image_bytes.startswith(b"\xff\xd8\xff")
    is_png = image_bytes.startswith(b"\x89PNG\r\n\x1a\n")
    is_webp = image_bytes[0:4] == b"RIFF" and image_bytes[8:12] == b"WEBP"
    if not (is_jpeg or is_png or is_webp):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"지원하지 않는 이미지 형식입니다. {', '.join(_ALLOWED_MIME_TYPES)}만 허용됩니다",
        )

    # 쿼터 체크 + 슬롯 예약 (짧은 세션 — AI 호출 동안 커넥션·advisory lock 점유 방지)
    async with async_session_factory() as quota_db:
        quota = await check_and_reserve(quota_db, _get_client_ip(request), "vision")
        if not quota["allowed"]:
            return _quota_exceeded_response(quota)
        await quota_db.commit()  # 예약 커밋 + advisory lock 해제

    image_base64 = base64.b64encode(image_bytes).decode("utf-8")

    # pet_id=None이라 RAG·이전 분석 조회가 모두 건너뛰어짐 — user_id는 더미값(행 기록 없음)
    try:
        async with async_session_factory() as ai_db:
            result = await ai_service.analyze_vision_health_check(
                db=ai_db,
                pet_id=None,
                user_id=uuid.UUID(int=0),
                image_base64=image_base64,
                mime_type=content_type,
                mode=mode,
                part=None,
                notes=notes,
                tier="free",
                language=language,
            )
    except Exception as e:
        logger.error("Demo vision analysis failed: %s", e, exc_info=True)
        # AI 실패: 예약 삭제 → 쿼터 슬롯 반환
        try:
            async with async_session_factory() as refund_db:
                await refund_db.execute(
                    delete(DemoUsageLog).where(DemoUsageLog.id == quota["reservation_id"])
                )
                await refund_db.commit()
        except Exception as refund_err:
            logger.error("Demo vision quota refund failed: %s", refund_err, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="이미지 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
        )

    if mode == "droppings":
        result = normalize_droppings_result(result, language=language or "ko")

    return {"result": result, "quota": {"remaining": quota["remaining"], "limit": quota["limit"]}}


class DemoBhiRequest(BaseModel):
    growth_stage: Literal["adult", "post_growth", "rapid_growth"]
    weight_today_g: float = Field(..., gt=0)
    weight_baseline_g: float | None = None
    food_total_g: float = Field(..., ge=0)
    food_target_g: float = Field(..., ge=0)
    water_total_ml: float = Field(..., ge=0)
    water_target_ml: float = Field(..., ge=0)


@router.post("/bhi/calculate")
@limiter.limit("30/minute")
async def demo_bhi_calculate(
    body: DemoBhiRequest,
    request: Request,
    _: None = Depends(verify_demo_key),
    db: AsyncSession = Depends(get_db),
):
    """웹 데모용 BHI 계산. 입력값만으로 앱과 동일 공식을 적용한다 (DB 기록 조회 없음)."""
    quota = await check_and_reserve(db, _get_client_ip(request), "bhi")
    if not quota["allowed"]:
        return _quota_exceeded_response(quota)

    result = calculate_demo_bhi(
        growth_stage=body.growth_stage,
        weight_today_g=body.weight_today_g,
        weight_baseline_g=body.weight_baseline_g,
        food_total_g=body.food_total_g,
        food_target_g=body.food_target_g,
        water_total_ml=body.water_total_ml,
        water_target_ml=body.water_target_ml,
    )

    return {**result, "quota": {"remaining": quota["remaining"], "limit": quota["limit"]}}
