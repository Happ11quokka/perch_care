# 앵박사 AI 업그레이드 — 최종 통합 설계서

**작성일:** 2026-03-01
**상태:** 설계 확정
**이전 문서:** `2026-02-28-ai-upgrade-design.md` (초기 설계)
**검증 결과:** 로컬 에이전트 테스트 완료 (2,843청크, HyDE 검증)

---

## 1. 배경 및 목적

### 현재 상태
- GPT-4o-mini 기반 텍스트 전용 채팅 (앵박사 AI 백과사전)
- 응답 전체 대기 후 표시 (스트리밍 없음)
- 최대 512 토큰 (약 5줄) 응답
- 최근 7일 건강 데이터 RAG
- AI 이미지 건강체크 미구현 (백엔드 엔드포인트만 존재)

### 업그레이드 목표
앵박사를 **프리미엄 AI 서비스**로 전환하여 사용자 가치를 극대화하고, 추후 유료화 기반을 마련한다.

### 핵심 변경사항
1. **SSE 스트리밍** — ChatGPT처럼 실시간 토큰별 응답 표시
2. **멀티 모델 라우팅** — 입력 타입/언어/티어에 따라 최적 모델 자동 선택
3. **AI Vision 건강체크** — 사진 촬영으로 앵무새 건강 분석
4. **HyDE + 벡터 검색 RAG** — 크로스링구얼 지식 검색 (검증 완료)
5. **DeepSeek 중국어 보충** — 중국 조류 문화 컨텍스트 보강
6. **구조화 응답 시스템** — 문제 유형별 일관된 포맷
7. **Free/Premium 티어** — 프리미엄 코드 입력으로 30일 활성화 (MVP), 과금 시스템은 추후 설계

---

## 2. 전체 파이프라인 아키텍처

```
사용자 입력 (텍스트 or 사진)
    ↓
┌──────────────────────────────────────┐
│  ① 입력 타입 분기                     │
│  - 이미지 첨부? → Vision 파이프라인    │
│  - 텍스트만?    → 텍스트 파이프라인    │
└──────────────────────────────────────┘

═══ [텍스트 파이프라인] ═══════════════

    ↓
┌──────────────────────────────────────┐
│  ② 언어 감지                          │
│  - 중국어 → DeepSeek 보충 분석 실행    │
│  - 한국어/영어 → 직접 진행             │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ③ RAG 컨텍스트 수집 (병렬)           │
│  a) 건강 데이터 (Free: 7일 / Premium: 30일) │
│  b) HyDE 벡터 검색 (지식 DB, top 5)   │
│  c) (중국어) DeepSeek 보충 결과        │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ④ 티어별 모델 라우팅                  │
│  - Free:    GPT-4o-mini ($0.15/1M)   │
│  - Premium: GPT-4.1-nano ($0.10/1M)  │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ⑤ 구조화 응답 생성                   │
│  - 문제 유형 자동 판별                 │
│  - 유형별 포맷 적용                    │
│  - SSE 스트리밍 전송                   │
└──────────────────────────────────────┘

═══ [Vision 파이프라인] ═══════════════
    (대상: 앵무새 외형, 부위별, 배변, 먹이/사료)

    ↓
┌──────────────────────────────────────┐
│  ② 이미지 전처리                      │
│  - multipart/form-data 수신           │
│  - 메모리에서 base64 인코딩            │
│  - 서버 디스크 저장 없음 (패스스루)     │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ③ 언어 감지 + DeepSeek 보충 (중국어)  │
│  - 중국어 → 이미지 대상에 맞는          │
│    중국 현지 맥락 보충 정보 요청         │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ④ Vision RAG 컨텍스트 수집           │
│  a) 해당 반려동물 건강 데이터          │
│  b) 종별 특성 벡터 검색               │
│  c) (부위별) 해당 부위 질병 벡터 검색  │
│  d) (배변) 배변 이상 관련 질병 검색    │
│  e) (먹이) 해당 식품 영양/독성 검색    │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ⑤ GPT-4o Vision 호출                 │
│  - 분석 모드별 특화 프롬프트           │
│  - 이미지 + 건강데이터 + RAG 컨텍스트  │
│  - (중국어) DeepSeek 보충 결과 주입     │
│  - 구조화 JSON 응답 요구              │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ⑥ 결과 저장 및 반환                  │
│  - DB에 분석 결과 JSON만 저장          │
│  - LangSmith 트레이스 기록             │
│  - 이미지 자체는 미보관                │
└──────────────────────────────────────┘
```

---

## 3. 티어 시스템

| 기능 | 무료 (Free) | 프리미엄 (Premium) |
|------|------------|-------------------|
| 텍스트 AI 모델 | GPT-4o-mini | GPT-4.1-nano |
| Vision 건강체크 | X (잠금) | GPT-4o Vision |
| 응답 토큰 | 1024 | 2048 |
| SSE 스트리밍 | O | O |
| RAG 범위 | 7일 건강데이터 | 30일 + 건강이력 + 벡터검색 |
| 중국어 DeepSeek 보충 | X | O |
| 구조화 응답 | 기본 포맷 | 전체 포맷 |
| 사용 횟수 | 무제한 | 무제한 |

### 프리미엄 활성화: 코드 입력 방식 (MVP)

과금 시스템은 추후 별도 설계 예정이며, **현재 MVP 단계에서는 프리미엄 코드 입력 방식**으로 운영한다.

**동작 방식:**
1. 관리자가 프리미엄 코드를 생성하여 사용자에게 배포
2. 사용자가 앱 설정 화면에서 프리미엄 코드를 입력
3. 유효한 코드 입력 시 → **입력일로부터 30일간 프리미엄 자동 활성화**
4. 만료 후 자동으로 Free 티어로 전환
5. 새 코드 입력 시 만료일이 갱신됨 (기존 잔여 기간 무시, 입력일 기준 30일)

**프리미엄 코드 규칙:**
- 형식: `PERCH-XXXX-XXXX` (영문 대문자 + 숫자, 8자리)
- 1회 사용 가능 (사용된 코드는 재사용 불가)
- 관리자 API 또는 DB 직접 삽입으로 생성

**보안 정책:**
- 코드 활성화 시 `SELECT ... FOR UPDATE`로 레이스 컨디션 방지
- 에러 메시지 단일화: "유효하지 않거나 이미 사용된 코드입니다" (코드 존재 여부 비노출)
- `/premium/activate` 엔드포인트 전용 rate limit: 사용자당 5회/분
- 요청 스키마에서 코드 형식 정규식 검증 (`^PERCH-[A-Z0-9]{4}-[A-Z0-9]{4}$`)
- 같은 사용자가 같은 코드로 재시도 시 멱등 성공 처리 (기존 만료일 반환)
- 만료 시 `get_user_tier` 조회 시점에 DB `tier` 컬럼도 "free"로 갱신

### 데이터 모델: `premium_codes`
```
id (UUID PK)
code (VARCHAR(20), UNIQUE, NOT NULL)  -- "PERCH-XXXX-XXXX"
is_used (BOOLEAN, DEFAULT false)
used_by (FK → users, nullable)
used_at (TIMESTAMPTZ, nullable)
created_at (TIMESTAMPTZ)
```

### 데이터 모델: `user_tiers`
```
id (UUID PK)
user_id (FK → users, UNIQUE)
tier ("free" | "premium")
premium_started_at (nullable)
premium_expires_at (nullable)
activated_code (VARCHAR(20), nullable)  -- 마지막 활성화에 사용된 코드
created_at, updated_at
```

---

## 4. 모델 라우팅 전략

### 모델 매트릭스

| 입력 타입 | 무료 (Free) | 프리미엄 (Premium) | 비용/1M tokens |
|-----------|------------|-------------------|---------------|
| 텍스트 채팅 | GPT-4o-mini | GPT-4.1-nano | $0.15 / $0.10 |
| 이미지 건강체크 | 잠금 | GPT-4o Vision | — / $2.50 |
| HyDE 가상문서 생성 | GPT-4o-mini | GPT-4o-mini | $0.15 |
| 중국어 보충 분석 | — | DeepSeek-chat | $0.14 |

### 라우팅 로직 (의사코드)

```python
def process_request(input_type, tier, language, query, image=None, mode=None):
    # ① 이미지 분기
    if input_type == "image":
        if tier != "premium":
            return ERROR("프리미엄 전용 기능")

        # 중국어 → DeepSeek 보충 (Vision에도 적용)
        deepseek_context = ""
        if language == "zh":
            deepseek_context = call_deepseek_vision(query, mode)

        # RAG 컨텍스트 (모드별)
        rag = search_knowledge(mode)  # droppings→배변질병, food→영양/독성

        return call_vision("gpt-4o", image, rag, deepseek_context, mode)

    # ② 텍스트 분기
    if input_type == "text":
        # 중국어 → DeepSeek 보충
        deepseek_context = ""
        if language == "zh" and tier == "premium":
            deepseek_context = call_deepseek(query)

        # RAG 컨텍스트
        rag = hyde_search(query)

        # 티어별 모델
        model = "gpt-4.1-nano" if tier == "premium" else "gpt-4o-mini"
        return call_chat(model, query, rag, deepseek_context)
```

### 비용 분석 (사용자 1,000명 기준)

| 항목 | 월 예상 비용 |
|------|------------|
| 텍스트 채팅 (무료 사용자 700명 × 30회) | ~$3.15 |
| 텍스트 채팅 (프리미엄 300명 × 50회) | ~$1.50 |
| HyDE 가상문서 생성 (전체) | ~$1.50 |
| Vision 건강체크 (프리미엄 300명 × 8회) | ~$9.60 |
| DeepSeek 중국어 보충 — 텍스트 (100명 × 30회) | ~$0.42 |
| DeepSeek 중국어 보충 — Vision (100명 × 8회) | ~$0.11 |
| 임베딩 (검색 시) | ~$0.10 |
| **총 예상** | **~$16.38/월** |

---

## 5. 중국어 DeepSeek 보충 로직

### 목적
중국 앵무새 문화의 고유한 맥락(중의학 기반 관리법, 중국 로컬 사료/약품, 문화적 관습 등)은 영문 지식 데이터에 부족하다. DeepSeek API로 먼저 중국 문화 맥락의 보충 분석을 생성한 뒤, 최종 앵박사 LLM에 컨텍스트로 주입한다.

### 데이터 흐름

```
중국어 사용자 질문: "鹦鹉感冒了可以喝板蓝根吗"
    ↓
┌─────────────────────────────────────────┐
│  DeepSeek API 호출 (deepseek-chat)       │
│                                          │
│  프롬프트:                                │
│  "你是一位熟悉中国宠物鸟文化的鸟类专家。    │
│   针对以下问题，补充中国特有的文化背景、     │
│   常用方法、本地产品信息等。                │
│   注意：仅提供补充信息，不做最终诊断。"      │
│                                          │
│  → 보충 결과:                             │
│  "板蓝根是中国常用的中药抗病毒制剂...       │
│   在中国鸟友圈中常被用于...                 │
│   但需注意鸟类肝脏代谢能力有限..."          │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│  앵박사 최종 LLM (GPT-4.1-nano)          │
│                                          │
│  컨텍스트 조합:                           │
│  [1] 시스템 프롬프트                       │
│  [2] 건강 데이터 RAG                      │
│  [3] HyDE 벡터 검색 결과                  │
│  [4] DeepSeek 중국 문화 보충 ← 추가!      │
│  [5] 사용자 질문                          │
│                                          │
│  → 최종 답변 (중국어):                     │
│  "板蓝根虽然在中国鸟友中有使用先例...       │
│   但根据现代鸟类医学研究..."               │
└─────────────────────────────────────────┘
```

### DeepSeek 설정

| 항목 | 값 |
|------|------|
| 모델 | deepseek-chat (V3) |
| API 엔드포인트 | `https://api.deepseek.com/v1/chat/completions` |
| 비용 | $0.14/1M input, $0.28/1M output |
| max_tokens | 500 |
| temperature | 0.3 |
| 용도 | 보충 컨텍스트 생성 (최종 답변 아님) |

### DeepSeek 프롬프트

```
你是一位熟悉中国宠物鸟饲养文化的鸟类专家。

针对以下用户问题，请提供中国特有的补充背景信息，包括但不限于：
- 中国鸟友圈的常见做法和经验
- 中国市场上可获得的相关产品（药品、饲料、器具等）
- 中医/传统方法在鸟类护理中的应用（如有）
- 中国特有的鸟类品种或饲养习惯

重要：你只提供补充信息，不做最终医学诊断。最终判断将由主AI完成。
回答控制在200-400字。

用户问题：{query}
```

---

## 6. AI Vision 건강체크

### 분석 대상

Vision 건강체크는 앵무새 자체뿐만 아니라 **배변, 먹이(사료)** 사진도 분석할 수 있다.

| 대상 | 설명 | 분석 항목 |
|------|------|----------|
| 앵무새 전체 외형 | 사진 1장으로 전반적 건강 판단 | 깃털/자세/눈/부리/발/체형 |
| 앵무새 부위별 | 특정 부위 근접 촬영 | 부위별 특화 분석 |
| 배변 (droppings) | 배변 사진으로 건강 상태 추정 | 색상/질감/수분함량/요산/비정상 포함물 |
| 먹이/사료 (food) | 현재 급여 중인 사료/간식 사진 | 성분 식별/영양 적절성/위험 식품 여부 |

### 분석 모드

**전체 외형 (full_body):**
- 사진 1장으로 전반적 건강 상태 판단
- 분석 항목: 깃털 상태, 자세/균형, 눈 상태, 부리 상태, 발/발톱, 전체 체형

**부위별 (part_specific):**
- 사용자가 부위 선택 후 근접 촬영
- 지원 부위: 눈(eye), 부리(beak), 깃털(feather), 발(foot)

**배변 분석 (droppings):**
- 배변 사진으로 건강 이상 징후 판별
- 분석: 정상 3요소(변/요산/소변) 비율, 색상 이상, 소화되지 않은 씨앗, 혈변, 수양성 변 등

**먹이 분석 (food):**
- 현재 급여 중인 사료/과일/채소/간식 사진
- 분석: 식별된 식품명, 안전 여부, 영양 가치, 위험 식품 경고, 권장 급여량

### Vision 파이프라인

```
사용자: 사진 업로드 (+ 분석 모드 선택)
    ↓
┌──────────────────────────────────────┐
│  ① 이미지 전처리                      │
│  - multipart/form-data 수신           │
│  - 메모리에서 base64 인코딩            │
│  - 서버 디스크 저장 없음 (패스스루)     │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ② 언어 감지 + DeepSeek 보충 (중국어)  │
│  - 중국어 사용자 → DeepSeek 호출       │
│  - 이미지 대상(배변/먹이)에 대한        │
│    중국 현지 제품/관습 보충 정보         │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ③ RAG 컨텍스트 수집                  │
│  - 해당 반려동물 건강 데이터           │
│  - (full_body) 종별 특성 벡터검색      │
│  - (part_specific) 해당 부위 질병 검색  │
│  - (droppings) 배변 이상 관련 질병 검색 │
│  - (food) 해당 식품 영양/독성 검색      │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ④ GPT-4o Vision 호출                 │
│  - 분석 모드별 특화 프롬프트           │
│  - 이미지 + 건강데이터 + RAG 컨텍스트  │
│  - (중국어) DeepSeek 보충 결과 주입     │
│  - 구조화 JSON 응답 요구              │
└──────────────────────────────────────┘
    ↓
┌──────────────────────────────────────┐
│  ⑤ 결과 저장 및 반환                  │
│  - DB에 분석 결과 JSON만 저장          │
│  - LangSmith 트레이스 기록             │
│  - 이미지 자체는 미보관                │
└──────────────────────────────────────┘
```

### Vision 응답 구조 (JSON)

**전체 외형 / 부위별 분석:**
```json
{
  "mode": "full_body",
  "findings": [
    {
      "area": "feather",
      "observation": "흉부 깃털이 불규칙하게 빠져있으며 피부 노출 부위가 관찰됩니다",
      "severity": "warning",
      "possible_causes": ["깃털 뽑기 행동(FDB)", "영양 결핍", "피부 감염"]
    },
    {
      "area": "posture",
      "observation": "자세와 균형은 정상 범위입니다",
      "severity": "normal",
      "possible_causes": []
    }
  ],
  "overall_status": "warning",
  "confidence_score": 78.5,
  "recommendations": ["깃털 뽑기가 최근 시작된 것인지 확인해주세요"],
  "vet_visit_needed": true,
  "vet_reason": "피부 노출 부위에 발적이 있어 감염 가능성 확인이 필요합니다"
}
```

**배변 분석:**
```json
{
  "mode": "droppings",
  "findings": [
    {
      "component": "feces",
      "color": "dark_green",
      "texture": "formed",
      "status": "normal"
    },
    {
      "component": "urates",
      "color": "yellow_green",
      "texture": "chalky",
      "status": "warning"
    },
    {
      "component": "urine",
      "amount": "excessive",
      "status": "caution"
    }
  ],
  "overall_status": "warning",
  "confidence_score": 72.0,
  "possible_conditions": ["간 기능 이상 가능성 (요산 변색)", "수분 과다 섭취 또는 신장 문제"],
  "recommendations": ["24시간 배변 변화를 관찰해주세요", "식이에 변화가 있었는지 확인해주세요"],
  "vet_visit_needed": true,
  "vet_reason": "요산 변색이 48시간 이상 지속되면 간/신장 검사가 필요합니다"
}
```

**먹이 분석:**
```json
{
  "mode": "food",
  "identified_items": [
    {
      "name": "해바라기씨",
      "safety": "caution",
      "note": "지방 함량이 높아 간식으로만 소량 급여"
    },
    {
      "name": "사과 조각",
      "safety": "safe",
      "note": "씨앗은 제거해야 함 (시안화물 포함)"
    },
    {
      "name": "아보카도",
      "safety": "toxic",
      "note": "퍼신(persin) 함유, 절대 급여 금지"
    }
  ],
  "overall_diet_assessment": "warning",
  "nutrition_balance": "지방 과다, 비타민A 부족 가능성",
  "recommendations": [
    "아보카도를 즉시 제거해주세요 — 앵무새에게 치명적입니다",
    "펠렛 사료 비율을 60-70%로 높여주세요",
    "당근, 브로콜리 등 비타민A 풍부한 채소를 추가해주세요"
  ],
  "vet_visit_needed": false
}
```

### Vision 프롬프트 전략

**full_body 프롬프트:**
- 6개 항목(깃털/자세/눈/부리/발/체형) 순서대로 체크
- 각 항목에 normal/caution/warning/critical severity 부여
- 해당 종(species) 특성 고려 (RAG에서 종별 문서 주입)

**part_specific 프롬프트:**
- 선택된 부위에 집중된 전문 분석
- eye → 분비물/부종/동공 반응/각막 상태
- beak → 대칭/색상/질감/과성장
- feather → 밀도/윤기/변색/손상 패턴
- foot → 발바닥 상태/발톱 길이/부종/범블풋

**droppings 프롬프트:**
- 3요소 분석: 변(feces, 녹/갈색), 요산(urates, 흰색), 소변(urine, 투명)
- 비율/색상/질감 기반 이상 징후 판별
- 혈변, 미소화 씨앗, 수양성 변, 요산 변색(황/녹) 등
- 최근 식이 변화 고려 (건강 데이터 RAG에서 주입)

**food 프롬프트:**
- 사진에서 식품/사료 종류 식별
- 각 식품별 안전 등급: 안전(safe), 주의(caution), 금지(toxic)
- 금지 식품 즉시 경고 (아보카도, 초콜릿, 카페인, 양파 등)
- 영양 균형 평가 및 개선 제안

### Vision + DeepSeek 보충 (중국어)

중국어 사용자의 Vision 분석 시, DeepSeek로 이미지 대상에 대한 중국 현지 맥락을 보충한다.

**DeepSeek Vision 보충 프롬프트:**
```
你是一位熟悉中国宠物鸟饲养文化的鸟类专家。

用户上传了一张关于"{analysis_mode}"的照片。
针对这个分析类型，请补充中国特有的背景信息：

- 如果是排便(droppings)：中国鸟友判断排便健康的经验方法
- 如果是食物(food)：中国市场常见的鸟粮品牌、本地食材的安全性
- 如果是鸟的外观：中国常见品种的特征差异、本地常见疾病

重要：你只提供补充信息，不做最终诊断。
回答控制在150-300字。
```

### 이미지 처리: 패스스루 전략

이미지를 서버에 영구 저장하지 않고, 메모리에서 바로 OpenAI Vision API로 전송한 뒤 **분석 결과 텍스트만 DB에 저장**.

| 항목 | 패스스루 (선택) | 서버 저장 |
|------|----------------|----------|
| 서버 저장 비용 | **$0** | ~$1-2/월 (1,000명) |
| 개발자 이미지 확인 | LangSmith 트레이스 | 서버에서 직접 |
| 사용자 과거 사진 열람 | X (결과 텍스트만) | O |
| 개인정보 리스크 | **낮음** | 이미지 보관 관리 필요 |

> **향후 확장:** 사용자 이미지 열람 필요 시 Cloudflare R2 전환 (~$0.24/월, 1,000명 기준)

### Vision 비용 분석

| 항목 | 비용 |
|------|------|
| 이미지 1장 분석 (GPT-4o, ~1500 tokens) | ~$0.004 |
| 프리미엄 사용자 월 8회 | ~$0.032/사용자/월 |
| 1,000명 프리미엄 기준 | ~$32/월 |

### 화면 플로우

```
[홈 화면] AI 건강체크 카드 탭
    ↓
[건강체크 메인] 분석 대상 선택:
  ┌─────────────────────────────┐
  │  🦜 전체 외형  │  🔍 부위별   │
  │  💩 배변 분석  │  🍎 먹이 분석 │
  └─────────────────────────────┘
    ↓ (무료 사용자: 프리미엄 안내 팝업)
    ↓ (부위별 선택 시: 부위 선택 화면)
[카메라 화면] 촬영 또는 갤러리 선택
    ↓
[분석 중] 로딩 애니메이션 (3-8초)
    ↓
[결과 화면] 상태 배지 + 발견사항 카드 + 추천사항
```

---

## 7. 벡터 검색 RAG (검증 완료)

### 로컬 에이전트 테스트 결과

| 항목 | 초기 설계 | 테스트 후 확정 |
|------|----------|--------------|
| 임베딩 모델 | text-embedding-3-small (1536d) | **text-embedding-3-large** (3072d) |
| 청킹 전략 | 500자 고정, 문장 경계 | **마크다운 H2/H3 섹션 기반** |
| 검색 기법 | 단순 임베딩 매칭 | **HyDE** (가상 문서 생성 후 검색) |
| 한국어 크로스링구얼 | 미해결 (0.17~0.24) | **HyDE로 해결** (0.82~0.87) |
| 평균 유사도 | 미검증 | **0.70~0.87 달성** |
| 지식 데이터 | 미확보 | **274파일 → 2,843청크** |

### 벤치마크 결과

| 쿼리 | 언어 | 이전 (small, 직접검색) | 이후 (large + HyDE) |
|------|------|----------------------|---------------------|
| "feather plucking" | EN | 0.747 | **0.808** |
| "Can parrots eat avocado?" | EN | 0.724 | **0.868** |
| "symptoms of psittacosis" | EN | 0.672 | **0.818** |
| "앵무새가 깃털을 뽑아요" | KO | 0.240 | **0.825** |
| "앵무새에게 아보카도를 줘도 되나요?" | KO | 0.170 | **0.870** |
| "我的鹦鹉拔自己的羽毛怎么办" | ZH | 0.604 | **0.740** |
| "鹦鹉可以吃牛油果吗" | ZH | 0.742 | **0.856** |
| "虎皮鹦鹉怎么训练上手" | ZH | 0.600 | **0.708** |

### HyDE (Hypothetical Document Embeddings) 원리

```
사용자 질문: "앵무새가 깃털을 뽑아요"
    ↓
GPT-4o-mini로 가상 문서 생성 (영문):
"Feather plucking, also known as feather destructive behavior (FDB),
 is a common behavioral issue in captive psittacine birds..."
    ↓
가상 문서를 임베딩하여 벡터 검색
    ↓
영문 지식 문서와 높은 유사도 매칭 (0.825)
```

**HyDE의 핵심 가치:**
- 짧은 질문 → 상세한 문서로 확장하여 검색 정확도 향상
- 한국어/중국어 질문을 영문 가상 문서로 변환 → 크로스링구얼 문제 해결
- 추가 비용: GPT-4o-mini 1회 호출 (~$0.0001/쿼리), 추가 지연: ~1초

### 청킹 전략 (확정)

| 규칙 | 내용 |
|------|------|
| 분할 기준 | H2 (##) 헤더 기준 섹션 분리 |
| 서브 섹션 | H3 (###) 각각 별도 청크 |
| 컨텍스트 보존 | 문서 제목(H1) + 섹션 헤더를 청크 앞에 붙임 |
| References 제외 | URL은 임베딩에 부적합 |
| 스킵 파일 | `_index.md`, `README.md` |
| 대형 청크 분할 | 1500자 초과 시 `\n\n` 기준 서브 분할 |
| 최소 크기 | 100자 미만 청크 스킵 |

### 프로덕션 적용: pgvector

로컬 테스트(ChromaDB)에서 검증된 설정을 프로덕션(pgvector)에 적용:

```
knowledge_chunks 테이블:
├── id (UUID PK)
├── content (TEXT, NOT NULL)
├── embedding (VECTOR(3072))          -- text-embedding-3-large
├── source (VARCHAR)
├── category (VARCHAR)
├── language (VARCHAR)                -- "en" | "zh"
├── section_title (VARCHAR)
├── metadata (JSONB)
└── created_at (TIMESTAMPTZ)
```

**Docker 이미지:** `pgvector/pgvector:pg16` (기존 `postgres:16-alpine` 교체)

---

## 8. 구조화 응답 시스템

### 문제 유형별 응답 포맷

사용자 질문을 자동 분류하여 유형별 일관된 포맷으로 응답한다.

**① 질병/증상 (disease)**
```
🔍 가능한 원인
- 원인 1 (가능성 높음)
- 원인 2

⚠️ 응급도: [일반 / 주의 / 긴급]

🏠 홈케어
- 즉시 할 수 있는 조치 1
- 조치 2

(위험 시에만)
🏥 병원 방문이 필요한 경우
- 구체적 조건
```

**② 영양/식이 (nutrition)**
```
✅ 안전 여부: [안전 / 주의 / 금지]

📊 영양 정보
- 해당 식품의 영양 특성

📋 급여 방법
- 권장량, 빈도, 주의사항
```

**③ 행동/훈련 (behavior)**
```
💡 원인 분석
- 해당 행동의 원인

📝 단계별 방법
1. 단계 1
2. 단계 2
3. 단계 3

⚠️ 주의사항
- 하지 말아야 할 것
```

**④ 종 정보 (species)**
```
📋 기본 정보
- 학명, 수명, 크기, 원산지

🏠 관리 포인트
- 핵심 관리 사항

💡 팁
- 해당 종 특화 팁
```

**⑤ Vision 건강체크 결과 (health_check)**
```
📊 전체 상태: [정상 / 주의 / 경고]
신뢰도: XX%

🔎 관찰 소견
- [부위] 소견 내용 (severity)

📋 관리 권장사항
- 권장사항 1
- 권장사항 2

(위험 시에만)
🏥 병원 방문 권장
- 구체적 사유
```

### 유형 분류 방법

시스템 프롬프트에 유형 판별 지시를 포함:

```
Classify the user's question into one of these categories:
- disease: symptoms, illness, injury, emergency
- nutrition: food safety, diet, supplements
- behavior: training, habits, behavioral issues
- species: breed info, characteristics, lifespan
- general: other topics

Then respond using the structured format for that category.
```

---

## 9. 의사 권유 정책

### 기존 문제
현재 시스템 프롬프트에 "If evidence is uncertain, recommend consulting a veterinarian"가 있어 거의 모든 답변에 의사 진료를 권하고 있음. 이는 사용자 경험을 저하시킨다.

### 새로운 정책

**의사 권유를 넣는 조건 (이 경우에만):**
- severity가 warning 또는 critical인 경우
- 출혈, 호흡곤란, 경련, 의식 저하 등 응급 증상
- 48시간 이상 지속되는 비정상 증상
- 사진 분석에서 감염/종양 의심 소견

**의사 권유를 넣지 않는 경우:**
- 일반 영양/식이 질문 ("아보카도 먹여도 돼요?")
- 행동/훈련 질문 ("어떻게 손에 올리나요?")
- 종 정보 질문 ("코카티엘 수명이 얼마나 되나요?")
- severity가 normal 또는 caution인 관찰 결과

### 시스템 프롬프트 반영

```
VETERINARY RECOMMENDATION POLICY:
- Do NOT recommend veterinary visits for general nutrition, behavior,
  training, or species information questions.
- Only recommend a vet visit when there are genuine warning signs:
  active bleeding, breathing difficulty, seizures, loss of consciousness,
  suspected infection, tumors, or symptoms persisting 48+ hours.
- For mild concerns (severity: caution), suggest monitoring and home care
  first, with "consult a vet if symptoms worsen" as a secondary note.
- Never add a generic "consult a veterinarian" disclaimer to every response.
```

---

## 10. SSE 스트리밍 아키텍처

### 데이터 흐름
```
[Flutter] POST /ai/encyclopedia/stream
    ↓
[FastAPI] StreamingResponse (text/event-stream)
    ↓
[OpenAI] stream=True → async for chunk
    ↓
[SSE] data: {"token": "앵"}\n\n
      data: {"token": "무"}\n\n
      ...
      data: {"done": true, "sources": [...]}\n\n
    ↓
[Flutter] http.Client.send() → response.stream
    ↓
[UI] setState() per token → 실시간 텍스트 업데이트
```

### SSE 이벤트 포맷
```
data: {"token": "text_chunk"}\n\n           // 토큰 전달
data: {"done": true, "sources": [...]}\n\n  // 스트림 완료 + 참조 소스
data: {"error": "error_message"}\n\n        // 에러 발생 시
```

### Fallback 전략
SSE 실패 시 → 기존 `POST /ai/encyclopedia` (동기) 엔드포인트로 자동 전환

---

## 11. RAG 컨텍스트 (구조화 데이터)

### 무료 (현행 유지)
- 최근 7일 체중, 사료, 음수량

### 프리미엄 (확장)
- 최근 30일 체중/사료/음수량
- 최근 AI 건강체크 결과 (최대 5건)
- BHI 점수 이력
- daily_records (기분, 활동 수준)
- 반려동물 성장 단계 정보

---

## 12. 배포 전략: Railway 환경 분리

### 환경 구성

| 환경 | 브랜치 | 용도 |
|------|--------|------|
| **Production** | `main` | 실 서비스 |
| **Staging** | `dev` | 개발/테스트 |

### Railway Environments 설정

Railway는 [Environments 기능](https://docs.railway.com/guides/environments)으로 독립된 Staging 환경을 지원:

- Staging 환경 생성 시 모든 서비스/설정이 복제됨
- 별도 DB 인스턴스 자동 생성 (프로덕션 데이터 영향 없음)
- `dev` 브랜치에 연결하여 push 시 자동 배포
- PR 환경도 자동 생성/정리 지원

### 배포 흐름

```
[개발] dev 브랜치에서 작업
    ↓
[Staging] Railway staging 환경 자동 배포
    ↓
[테스트] staging 서버에서 검증
    ↓
[PR] dev → main PR 생성
    ↓
[Production] main 머지 시 프로덕션 자동 배포
```

### 환경별 설정

```yaml
# Staging
API_BASE_URL: https://staging-perchcare.up.railway.app
OPENAI_API_KEY: (동일)
DEEPSEEK_API_KEY: (동일)
DATABASE_URL: (staging 별도 DB)

# Production
API_BASE_URL: https://perchcare.up.railway.app
OPENAI_API_KEY: (동일)
DEEPSEEK_API_KEY: (동일)
DATABASE_URL: (production DB)
```

---

## 13. 구현 순서

| Phase | 내용 | 새 파일 | 수정 파일 |
|-------|------|---------|----------|
| 0 | Railway staging 환경 설정 | 0 | 1 |
| 1 | DB + Tier 시스템 | 4 | 4 |
| 2 | 백엔드 SSE 스트리밍 | 0 | 3 |
| 3 | 프론트엔드 SSE 스트리밍 | 1 | 3 |
| 4 | pgvector + HyDE 벡터 검색 RAG | 4 | 3 |
| 5 | 지식 데이터 적재 (확정된 청킹 전략) | 1 | 0 |
| 6 | DeepSeek 중국어 보충 모듈 | 1 | 1 |
| 7 | 구조화 응답 + 의사 권유 정책 | 0 | 2 |
| 8 | 모델 라우팅 (티어별 모델 분기) | 0 | 2 |
| 9 | 백엔드 Vision API | 1 | 3 |
| 10 | 프론트엔드 건강체크 화면 | 4 | 6 |
| 11 | 통합 테스트 + 마무리 | 0 | 3 |
| **합계** | | **16+** | **31** |

---

## 14. 기술 결정 사항 (최종)

| 결정 | 선택 | 이유 |
|------|------|------|
| 텍스트 모델 (무료) | GPT-4o-mini | 저비용, 기존 검증 |
| 텍스트 모델 (프리미엄) | GPT-4.1-nano | 최저 비용($0.10/1M)이면서 최신 세대 |
| Vision 모델 | GPT-4o | Vision 분석 최고 품질 |
| 중국어 보충 | DeepSeek-chat | 중국어 특화, 초저비용($0.14/1M) |
| HyDE 모델 | GPT-4o-mini | 가상 문서 생성용, 저비용 |
| 임베딩 모델 | text-embedding-3-large | 3072d, 테스트에서 유의미한 성능 향상 확인 |
| 벡터DB (프로덕션) | pgvector | 별도 인프라 불필요, Railway 지원 |
| 벡터DB (테스트) | ChromaDB | 로컬 테스트 완료, 검증용 |
| 청킹 전략 | 마크다운 H2/H3 섹션 기반 | 의미 단위 보존, 테스트 검증 완료 |
| 검색 기법 | HyDE + 코사인 유사도 | 크로스링구얼 해결, 0.70~0.87 달성 |
| 스트리밍 방식 | SSE | 단방향, FastAPI 네이티브 |
| 이미지 처리 | 패스스루 (미저장) | 비용 $0, LangSmith 확인 가능 |
| 배포 전략 | Railway Environments | staging/production 분리, 자동 배포 |
| 의사 권유 | 위험 시에만 | 사용자 경험 개선 |

---

## 15. 장애 대응 및 Fallback 정책

### 외부 API 장애 시 처리

| API | 장애 시 동작 | 사유 |
|-----|------------|------|
| OpenAI (텍스트/Vision) | 3회 재시도 → 실패 시 에러 반환 | 핵심 서비스, 대체 불가 |
| DeepSeek (중국어 보충) | **무시하고 계속 진행** | 보충 정보일 뿐, 없어도 답변 가능 |
| OpenAI Embedding (HyDE) | HyDE 비활성화 → 원본 쿼리로 검색 | 검색 품질 저하되나 서비스 유지 |
| pgvector (벡터 검색) | 벡터 검색 스킵 → 건강 데이터 RAG만 사용 | 지식 없이도 기본 답변 가능 |

### Timeout 설정

| 호출 | Timeout | 비고 |
|------|---------|------|
| HyDE 가상문서 생성 | 5초 | 초과 시 원본 쿼리로 fallback |
| DeepSeek 보충 분석 | 5초 | 초과 시 스킵 |
| 벡터 검색 | 3초 | 초과 시 RAG 없이 진행 |
| 텍스트 LLM 응답 | 30초 | SSE 스트리밍이므로 첫 토큰 기준 |
| Vision 분석 | 30초 | 이미지 처리 포함 |

### 레이트 리밋 (비용 방어)

| 항목 | 무료 | 프리미엄 |
|------|------|---------|
| 텍스트 채팅 | 30회/일 | 100회/일 |
| Vision 건강체크 | — | 20회/일 |
| API 전체 | 60 req/분 (IP 기준) | 120 req/분 |

---

## 16. 입출력 검증 정책

### 이미지 입력 검증

| 항목 | 제한 |
|------|------|
| 허용 MIME 타입 | `image/jpeg`, `image/png`, `image/webp` |
| 최대 파일 크기 | 10MB |
| 최소 해상도 | 200x200px |
| 최대 해상도 | 4096x4096px |
| 악성 파일 차단 | Magic bytes 검증 (확장자만 보지 않음) |

### Vision JSON 출력 검증

Vision 모델의 JSON 응답이 스키마에 맞지 않을 경우:
1. 1회 재요청 (프롬프트에 "JSON 형식 준수" 강조)
2. 재시도 실패 시 → 비구조화 텍스트 응답으로 fallback

### 데이터 보존 정책

| 데이터 | 보존 기간 | 비고 |
|--------|----------|------|
| 건강체크 결과 JSON | 영구 (사용자 삭제 시 삭제) | 이력 조회용 |
| 채팅 히스토리 | 90일 | 컨텍스트용, 자동 정리 |
| LangSmith 트레이스 | 플랜별 (Free 14일, Plus 400일) | LangSmith 정책 따름 |
| 이미지 원본 | 미보관 | 패스스루, 메모리에서만 처리 |

---

## 17. 보안 정책

### API 키 관리

| 환경 | OpenAI Key | DeepSeek Key | 비고 |
|------|-----------|-------------|------|
| Staging | 별도 키 (usage limit 설정) | 별도 키 | 테스트 비용 제한 |
| Production | 프로덕션 전용 키 | 프로덕션 전용 키 | 모니터링 알림 설정 |

- 키는 Railway 환경변수로 관리 (코드에 하드코딩 금지)
- 90일 주기로 키 회전 권장
- OpenAI 대시보드에서 월 비용 상한(spending limit) 설정

### DeepSeek 데이터 전송 고지

- 중국어 사용자에게 "AI 분석 품질 향상을 위해 외부 AI 서비스를 활용합니다" 고지
- 개인 건강 데이터는 DeepSeek에 전송하지 않음 (질문 텍스트만 전송)
- 이미지는 DeepSeek에 전송하지 않음 (텍스트 보충만)

### LangSmith 민감정보 관리

- 시스템 프롬프트 내 API 키/환경변수 자동 마스킹
- 사용자 건강 데이터는 LangSmith에 기록되나, 접근 권한 제한 (관리자만)
- LangSmith Plus 플랜 사용 시 SOC 2 Type II 인증 환경

---

## 18. 구조화 응답 — 티어 차등 상세

### Free (기본 포맷)

- 텍스트 위주 간결한 답변
- 유형 분류 O, 기본 구조(제목 + 본문) 적용
- 소스 참조 표시 X
- 구조화 JSON 응답 X (텍스트만)

### Premium (전체 포맷)

- 유형별 전용 포맷 (섹션 8 참고) 완전 적용
- 소스 참조 표시 O (참조한 지식 문서명)
- severity 배지 표시 O
- 구조화 JSON 병행 제공 (앱에서 카드 UI 렌더링)

---

## 19. Codex 리뷰 반영 사항

Codex CLI (gpt-5.3-codex, high effort)로 설계 문서를 리뷰한 결과 주요 지적사항과 반영 상태:

| # | 지적 사항 | 심각도 | 반영 |
|---|----------|--------|------|
| 1 | DeepSeek 티어 조건 불일치 (파이프라인 vs 의사코드) | P0 | 의사코드에 "프리미엄만" 명시됨, 파이프라인 도식은 티어 분기 전 위치이므로 정상 |
| 2 | 구조화 응답 티어 차등 모호 | P0 | **섹션 18 추가하여 해결** |
| 3 | user_tiers 과금 필드 부족 | P1 | **프리미엄 코드 입력 방식으로 해결 (섹션 3)** — 코드 입력 시 30일 프리미엄 활성화, 과금 시스템은 추후 별도 설계 예정 |
| 4 | 장애 대응/Timeout 미정의 | P0 | **섹션 15 추가하여 해결** |
| 5 | Vision 비용 시나리오 혼동 | P0 | 4장: 1,000명 중 300명 프리미엄, 6장: 1,000명 전원 프리미엄 — 시나리오 차이 |
| 6 | DeepSeek 비용 과소추정 | P1 | output 포함 시 ~1.5배, 총액에 큰 영향 없음 (~$0.63 → $16.59) |
| 7 | 레이트 리밋 필요 | P0 | **섹션 15 추가하여 해결** |
| 8 | 환경별 API 키 분리 | P0 | **섹션 17 추가하여 해결** |
| 9 | LangSmith 민감정보 | P1 | **섹션 17 추가하여 해결** |
| 10 | DeepSeek 데이터 전송 고지 | P1 | **섹션 17 추가하여 해결** |
| 11 | 입력/출력 검증 누락 | P1 | **섹션 16 추가하여 해결** |
| 12 | 데이터 보존 정책 누락 | P1 | **섹션 16 추가하여 해결** |
| 13 | 모델 라우팅 Phase 순서 | P1 | 라우팅은 AI 서비스 수정 시 자연스럽게 포함, 별도 Phase 불필요 |
| 14 | 지연시간 리스크 | 참고 | HyDE/DeepSeek 병렬 호출로 완화, Timeout으로 상한 제어 |

### 2차 리뷰 (프리미엄 코드 시스템 추가 후)

Codex CLI (gpt-5.3-codex, high effort)로 프리미엄 코드 시스템 설계를 교차 리뷰한 결과:

| # | 지적 사항 | 심각도 | 반영 |
|---|----------|--------|------|
| 15 | activate_premium_code 레이스 컨디션 (SELECT → UPDATE 분리) | P0 | **SELECT ... FOR UPDATE 적용하여 해결 (구현 계획서 Task 1-2)** |
| 16 | 에러 메시지가 코드 존재 여부를 노출 (브루트포스 오라클) | P1 | **에러 메시지 단일화 + /premium/activate rate limit 5회/분 (섹션 3 보안 정책)** |
| 17 | activated_code VARCHAR → premium_codes FK 무결성 부재 | P1 | MVP에서는 VARCHAR 스냅샷 유지, 과금 시스템 도입 시 FK 전환 검토 |
| 18 | 만료 시 get_user_tier가 "free" 반환하지만 DB tier 미갱신 | P1 | **조회 시 DB tier도 "free"로 갱신하여 해결 (구현 계획서 Task 1-2)** |
| 19 | PremiumCodeRequest 정규식 검증 미정의 | P1 | **Pydantic field_validator로 PERCH-XXXX-XXXX 형식 검증 추가 (구현 계획서 Task 1-2)** |
| 20 | 같은 사용자 + 같은 코드 재시도 시 "이미 사용됨" 에러 | P2 | **멱등 성공 처리: used_by == current_user이면 기존 만료일 반환 (구현 계획서 Task 1-2)** |
| 21 | 기존 프리미엄 사용자가 새 코드 입력 시 잔여 기간 손실 UX | P2 | 코드 적용 전 확인 다이얼로그를 Flutter 화면에서 표시 (Phase 8에서 구현) |
| 22 | 설계서에 API 계약(경로/스키마/에러) 누락 | P2 | **섹션 3 보안 정책에 요약 추가** |
