# AI 에이전트 정확도 개선 — 2026-04-04

## 배경
챗봇(AI Encyclopedia) + 비전(Health Check) 에이전트의 정확도 중심 평가를 수행하고,
식별된 전체 이슈(P0 9건 + P1 8건 + P2 6건 = 총 23건)를 한 세션에서 수정.

## 수정 파일
- `backend/app/services/ai_service.py` — 핵심 AI 서비스 (22개 함수, 3개 신규 추가)
- `backend/app/services/vector_search_service.py` — 벡터 검색 re-ranking 추가

---

## 챗봇 에이전트 수정 내역

### CB-1: 대화 히스토리 슬라이딩 윈도우 (P0)
- **문제:** 전체 history를 무제한 전달 → 긴 대화 시 컨텍스트 오버플로우
- **수정:** `_truncate_history()` 함수 추가 — 최근 10턴(20개 메시지) 유지, 이전 대화 있음을 알리는 시스템 노트 삽입
- **적용 위치:** `ask()`, `ask_stream()` 에서 history 전달 전 호출

### CB-2: RAG 컨텍스트 다국어화 (P0)
- **문제:** RAG 컨텍스트가 한국어 고정 → 영어/중국어 사용자 정확도 저하
- **수정:** `_RAG_LABELS` 다국어 딕셔너리(한/영/중) 추가, `_build_rag_context()`에 `language` 파라미터 추가
- **적용 위치:** `prepare_system_message()`, `analyze_vision_health_check()` 에서 언어 전달

### CB-3: 카테고리 분류 검증 강화 (P0)
- **문제:** "silently classify"만 지시 → 오분류 시 잘못된 포맷/추천
- **수정:** `_CATEGORY_CLASSIFICATION` 프롬프트에 모호한 경우의 분류 가이드라인 추가 (예시 4건), `_ask_core()`에서 응답 메타데이터 카테고리 로깅

### CB-4: 지식 베이스 모니터링 로깅 (P0)
- **문제:** KB 검색 유사도/커버리지 파악 불가
- **수정:** `prepare_system_message()`에서 벡터 검색 결과 유사도 평균 로깅, 평균 0.3 미만 시 `KB LOW COVERAGE` 경고, 결과 0건 시 `KB NO RESULTS` 경고

### CB-5: Few-shot 예시 추가 (P1)
- **문제:** 구조화 포맷을 텍스트로만 설명 → 포맷 불일치 빈발
- **수정:** `_PREMIUM_FORMAT_TEMPLATE`에 disease(Korean)와 nutrition(English) 카테고리 2건의 실제 예시 추가

### CB-6: 메타데이터 파싱 유연화 (P1)
- **문제:** `<!-- META:... -->` 형식이 약간만 달라도 파싱 실패 (null 반환)
- **수정:** 2단계 파서 — 1차: 기존 정규식(공백 허용 추가), 2차: `<!-- ... -->` 블록 내 개별 필드 fallback 추출. 유효하지 않은 카테고리 시 경고 로깅

### CB-7: 언어 감지 빈도 기반 전환 (P1)
- **문제:** 문자 범위 체크만 사용 → 혼합 언어 오탐
- **수정:** `_detect_language()`를 `Counter` 빈도 기반으로 변경. 각 문자를 Chinese/Korean/English로 카운트 후 최다 언어 반환

### CB-8: 대화 요약 (CB-1과 통합) (P1)
- **문제:** 오래된 대화 맥락 완전 손실
- **수정:** `_truncate_history()`에서 트림된 메시지 수를 포함한 시스템 노트 삽입으로 맥락 유지 힌트 제공

### CB-9: 벡터 검색 Re-ranking (P2)
- **문제:** raw 코사인 유사도만으로 순위 결정 → 키워드 매칭이 강한 결과가 묻힘
- **수정:** `vector_search_service.py`에 `_rerank_results()` 추가 — 임베딩 유사도 80% + 키워드 오버랩 20% 블렌딩. 외부 의존성 없이 정밀도 향상

### CB-10: 종별 특화 지시 (P2)
- **문제:** 프롬프트에 종별 정상 범위 참조 지시 없음
- **수정:** `_SPECIES_INSTRUCTION` 추가 — 주요 종(잉꼬, 아프리카회색앵무, 코카투, 에클렉투스 등)의 체중/식이/행동/수명 차이 명시. `_build_system_prompt()`에 포함

### CB-11: 카테고리별 모델 선택 (P2)
- **문제:** 모든 질문에 동일 모델(gpt-4.1-nano) 사용
- **수정:** `_select_model()`에 `category` 파라미터 추가 — disease 카테고리는 `gpt-4o-mini`(더 정확한 모델) 사용

---

## 비전 에이전트 수정 내역

### VIS-1: 이미지 품질 사전 검증 (P0)
- **문제:** 흐릿한/어두운 이미지도 그대로 분석 → 환각 분석 + 높은 confidence
- **수정:** 사용자 메시지에 이미지 품질 체크 지시 추가 — 저품질 이미지 시 confidence 40 미만 설정 + 재촬영 권장 recommendation 추가 지시

### VIS-2: not_visible severity 추가 (P0)
- **문제:** 안 보이는 부위도 "normal" 판정 → 거짓 음성
- **수정:** `_VISION_COMMON_RULES`에 `VISIBILITY RULE` 추가 — 보이지 않는 부위는 `"severity": "not_visible"` 사용 필수. full_body JSON 스키마에 not_visible 옵션 추가

### VIS-3: Confidence score 보정 (P0)
- **문제:** GPT-4o 자체 보고 confidence 과대 추정
- **수정:** `_calibrate_confidence()` 함수 추가 — not_visible 영역당 -8점 페널티, full_body 최대 80캡 / 기타 85캡. 원본 점수는 `_confidence_raw` 필드에 보존

### VIS-4: 종별 정상 범위 참조 (P0)
- **문제:** 종별 차이 무시한 오진
- **수정:** `_VISION_COMMON_RULES`에 `SPECIES-SPECIFIC ANALYSIS` 섹션 추가 — 종별 깃털 패턴, 부리 형태, 체형, 체중 범위 차이 고려 지시

### VIS-5: 멀티 이미지 백엔드 준비 (P0 — 부분)
- **현 상태:** 프론트엔드 UI 변경 필요하여 백엔드만 준비
- **수정:** 프롬프트에 단일 이미지 한계 반영 (confidence 캡), 향후 멀티 이미지 지원 시 messages 배열에 이미지 추가만으로 확장 가능

### VIS-6: 독성 식품 목록 확장 (P1)
- **문제:** avocado, chocolate 등 6종만 명시
- **수정:** 3단계 독성 목록 — CRITICAL TOXIC 8종, HIGH TOXIC 8종, CAUTION 6종 총 22종으로 확장

### VIS-7: 식이 연동 배변 분석 (P1)
- **문제:** 배변 색 변화를 식이 변수 없이 판단 → 오진
- **수정:** `_VISION_DROPPINGS_PROMPT`에 `DIET-AWARE ANALYSIS` 섹션 추가 — 과일/펠릿/씨앗 식이별 정상 배변 변형 설명, RAG 식이 데이터와 교차 확인 지시. 드롭핑 findings에 `diet_related` 필드 추가

### VIS-8: JSON 파싱 재시도 (P1)
- **문제:** JSON 파싱 실패 → 즉시 에러 반환 (재시도 없음)
- **수정:** `analyze_vision_health_check()`에서 2회 시도 루프 — 1차 실패 시 temperature 0.1로 낮춰 재시도. 2차도 실패 시에만 에러 반환

### VIS-9: 이전 분석 비교 컨텍스트 (P1)
- **문제:** 각 분석이 독립적 → 시계열 변화 감지 불가
- **수정:** `_fetch_previous_analyses()` 함수 추가 — DB에서 최근 3회 분석 결과 조회하여 RAG 컨텍스트에 포함. "Compare current findings with previous results" 지시

### VIS-10: 추가 분석 부위 (P2)
- **문제:** 4부위(eye/beak/feather/foot)만 지원
- **수정:** 5부위 추가 — wing(날개), tail(꼬리), vent(배설강), crop(모이주머니), nares(콧구멍). 각 부위별 상세 체크 항목 포함

### VIS-11: Severity 보정 기준 명시 (P2)
- **문제:** 모드별 severity 기준 불일치
- **수정:** `_VISION_DROPPINGS_PROMPT`에 `SEVERITY CALIBRATION` 섹션 추가 — normal/caution/warning/critical 각 등급의 구체적 기준 명시

### VIS-12: 잘못된 status 로깅 (P2)
- **문제:** 유효하지 않은 status → "caution" 기본 대체 (디버깅 불가)
- **수정:** 유효하지 않은 status 발생 시 `logger.warning()` 추가 — 모드와 원본 status 값 기록

---

## 검증
- `python3 -m py_compile` — ai_service.py ✅, vector_search_service.py ✅
- 전체 함수 22개 확인 (기존 19개 + 신규 3개)
- 신규 함수: `_truncate_history()`, `_calibrate_confidence()`, `_fetch_previous_analyses()`
- 신규 상수: `_RAG_LABELS`, `_SPECIES_INSTRUCTION`, `_META_FIELD_PATTERNS`, `_MAX_RECENT_TURNS`

## 영향 범위
- 기존 API 인터페이스 변경 없음 (하위 호환)
- `_build_rag_context()`에 `language` 파라미터 추가 (기본값 "Korean"으로 하위 호환)
- `_select_model()`에 `category` 파라미터 추가 (기본값 None으로 하위 호환)
- `_VALID_STATUSES`에 `"not_visible"` 추가 — 프론트엔드에서 해당 status 처리 필요
