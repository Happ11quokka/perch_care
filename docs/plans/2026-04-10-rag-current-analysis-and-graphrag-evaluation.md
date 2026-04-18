# perch_care RAG 시스템 분석 & Graph-RAG 업그레이드 타당성 보고서

**작성일:** 2026-04-10
**작성자:** Claude Code (분석)
**대상 시스템:** perch_care 앵박사 AI 백과사전 / Vision 건강체크
**상태:** 분석/검토용 — 구현 결정 전 단계

---

## TL;DR (결론 요약)

> **결론: 현 시점(2026-04)에서는 Graph-RAG 전면 전환을 권장하지 않는다.**
> 대신 **현행 HyDE + pgvector 시스템을 유지**하되, **선택적 하이브리드 보강**(Apache AGE 또는 경량 관계 인덱스)을 장기 과제로 검토한다.

**핵심 근거 (3줄):**
1. **KB 규모가 작다** (300개 MD / 1.6MB / ~2,843 청크) — Graph-RAG의 비용/복잡도 증가를 정당화할 만큼의 "multi-hop 질문"이 구조적으로 발생하지 않는다.
2. **현 시스템은 이미 성숙**하다 — HyDE cross-lingual, TTL 기반 graceful degradation, keyword re-ranking, 병렬 RAG, LangSmith 트레이싱까지 production-grade로 구현됨.
3. **재인덱싱 비용 부담** — Microsoft GraphRAG 표준 파이프라인은 1M 토큰당 $20–50, 전체 KB 재처리 시 수십만 원대 선결 비용 발생 + 운영 복잡도 2배 증가.

---

## 1. 현재 RAG 시스템 분석

### 1.1 아키텍처 개요

```
User Query
    │
    ├─ ① 언어 감지 (Korean/English/Chinese, 빈도 기반)
    │
    ├─ ② 병렬 I/O (asyncio.gather)
    │       ├─ search_knowledge()          ← Vector RAG (pgvector)
    │       ├─ _build_rag_context()        ← 개인 건강 데이터 (DB)
    │       └─ get_chinese_supplement()    ← DeepSeek 문화 보충 (중국어만)
    │
    ├─ ③ HyDE Flow (search_knowledge 내부)
    │       ├─ HYDE_PROMPT → gpt-4o-mini (가상 문서 생성, 영문)
    │       ├─ text-embedding-3-large (3072-dim)
    │       ├─ pgvector cosine search (top_k=5, min_sim=0.3)
    │       └─ Keyword overlap re-ranking (80% sim + 20% overlap)
    │
    ├─ ④ format_knowledge_context() — 시스템 프롬프트 주입
    │
    └─ ⑤ LLM 호출 (gpt-4o-mini / gpt-4.1-nano) + LangSmith 트레이싱
```

### 1.2 핵심 파일 매트릭스

| 파일 | 역할 | LOC |
|------|------|-----|
| `backend/app/services/vector_search_service.py` | HyDE + pgvector 코사인 검색, TTL 재확인, keyword re-ranking | 215 |
| `backend/app/services/embedding_service.py` | OpenAI text-embedding-3-large + HyDE 가상 문서 생성 | 70 |
| `backend/app/services/ai_service.py` | 오케스트레이션 (백과사전 + Vision) | 1,253 |
| `backend/app/models/knowledge_chunk.py` | `KnowledgeChunk` ORM (별도 `VectorBase`) | 26 |
| `backend/scripts/load_knowledge.py` | 청킹 → 배치 임베딩 → pgvector 인서트 (idempotent) | 186 |
| `agent/chunker.py` | 마크다운 H2/H3 기반 섹션 청커 (100–1500자) | 193 |

### 1.3 Knowledge Base 통계 (실측)

| 지표 | 값 |
|------|---|
| 총 마크다운 파일 | **300개** (EN: 239, ZH: 61) |
| 총 원본 크기 | **1.69 MB** |
| 총 라인 수 | 25,454 |
| 예상 청크 수 | ~2,843 (최종 설계서 기록) |
| 임베딩 모델 | `text-embedding-3-large` (3072-dim) |
| 저장 형태 | pgvector `Vector(3072)`, `knowledge_chunks` 테이블 (별도 DB) |
| 카테고리 | diseases(~100), nutrition(~50), species(~35), behavior(~50) + ZH culture/legal/market |

**중요:** KB는 별도의 pgvector 인스턴스(`vector_database_url`)에 격리되어 있다. 메인 DB 마이그레이션(`007_add_pgvector_knowledge.py`)은 no-op이며, `main.py` lifespan에서 `VectorBase.metadata.create_all`로 생성된다.

### 1.4 구현된 고급 기법 (이미 production-grade)

| 기법 | 위치 | 설명 |
|------|------|------|
| **HyDE (Hypothetical Document Embeddings)** | `embedding_service.py:19-28, 50-69` | 쿼리를 바로 임베딩하지 않고, LLM에게 "수의학 레퍼런스 문서"를 가상 생성시킨 후 그것을 임베딩 → cross-lingual 정확도 ↑ |
| **Graceful Degradation** | `vector_search_service.py:34-69` | 벡터 DB 장애 시 빈 배열 반환, LLM은 그대로 동작. TTL 60초 기반 재확인 로직 |
| **Timeout Boundary** | `vector_search_service.py:92-101` | 15초 초과 시 `TimeoutError` 캐치 후 fallback |
| **병렬 I/O** | `ai_service.py:528-535` | `asyncio.gather` — 벡터 검색 / 건강 데이터 / DeepSeek 보충을 동시에 조회 |
| **Keyword Re-ranking (CB-9)** | `vector_search_service.py:171-194` | 임베딩 유사도 80% + 쿼리 키워드 overlap 20% 블렌딩 |
| **카테고리/언어 필터링** | `vector_search_service.py:122-138` | `WHERE category=:c AND language=:l` 동적 SQL |
| **KB 품질 모니터링 (CB-4)** | `ai_service.py:544-552` | 평균 유사도 < 0.3 시 `KB LOW COVERAGE` 경고 로깅 |
| **Idempotent 로딩** | `load_knowledge.py:84-86, 132-140` | `chunk_hash = SHA256(lang:source:content)` + `ON CONFLICT DO UPDATE` |

### 1.5 평가: "이 시스템은 잘 설계되어 있는가?"

**강점 (이미 해결된 것):**
- ✅ 크로스링구얼 검색 (HyDE가 ko/zh 쿼리를 영문 수의학 문서 스타일로 변환)
- ✅ 장애 격리 (벡터 DB가 죽어도 LLM은 동작)
- ✅ 티어링 (top_k=5 고정, 카테고리/언어 필터로 노이즈 감소)
- ✅ 관측성 (LangSmith + KB 평균 유사도 로깅)
- ✅ 비용 효율 (gpt-4o-mini / gpt-4.1-nano 라우팅)

**약점 (개선 여지):**
- ⚠️ **Multi-hop 불가** — "African Grey이 chocolate를 먹고 feather plucking이 생겼어"처럼 **종 × 독성 × 행동**이 얽힌 쿼리는 각 축마다 별도 청크를 가져올 뿐, 그들 간 관계를 명시적으로 추론하지 못함.
- ⚠️ **섹션 단위 청킹의 한계** — 청크는 "PBFD > Symptoms" 같은 단일 섹션. "이 증상이 나타나는 모든 질병"을 역방향 조회 불가.
- ⚠️ **Global/Thematic 질문 취약** — "앵무새에게 가장 흔한 5대 위험 요소"처럼 **전체 KB를 요약**해야 하는 질문은 top_k=5 벡터 검색으로 본질적으로 불가능.
- ⚠️ **중복 정보 검색** — 동일한 증상이 여러 질병 문서에 퍼져 있어, top-5가 같은 내용을 반복 포함할 가능성.

---

## 2. Graph-RAG 기초 (2026년 기준)

### 2.1 Vector RAG vs Graph-RAG 핵심 차이

| 축 | Vector RAG (현 perch_care) | Graph-RAG |
|----|----------------------------|-----------|
| **데이터 구조** | 독립적인 청크 임베딩 (flat) | 엔티티/관계 그래프 (node + edge) |
| **검색 방식** | 의미적 유사도 (cosine) | 그래프 순회 + 유사도 + 커뮤니티 요약 |
| **답변 강점** | "이 증상은 어떤 질병인가?" (single-hop) | "A가 B를 거쳐 C에 어떤 영향을 주나?" (multi-hop) |
| **전역 질문** | 취약 (top-k만 봄) | **강점** (community summary 계층 구조) |
| **인덱싱 비용** | O(N) — 임베딩 API 호출만 | O(N × LLM entity extraction × clustering) |
| **쿼리 비용** | 1 × embedding + 1 × LLM | 1 × LLM routing + 여러 그래프 조회 + LLM 종합 |
| **관측/설명성** | 유사도 점수만 | **명시적 관계 경로** (설명 가능) |
| **업데이트 비용** | 청크 단위 교체 (저렴) | 재-엔티티 추출 + 재-클러스터링 필요 (비쌈) |

### 2.2 Microsoft GraphRAG 파이프라인 (참고)

```
Raw Text
  │
  ├─ LLM Entity Extraction        ← Disease, Species, Symptom, Food 등 추출
  │   (prompts/entity_extraction)
  │
  ├─ LLM Relationship Extraction  ← "PBFD affects Cockatoo", "Avocado toxic to Parrot"
  │
  ├─ Community Detection (Leiden) ← 엔티티 클러스터링
  │
  ├─ LLM Community Summaries      ← 각 클러스터의 hierarchical 요약
  │   (이 단계가 가장 비쌈)
  │
  ├─ Embedding (vectors for hybrid search)
  │
  └─ Graph Storage (Parquet / Neo4j / LanceDB / ...)
```

### 2.3 비용 (2026년 시세)

- **표준 GraphRAG 인덱싱**: 1M 토큰당 **약 $20–50** (API 호출비)
  - KB 원본 1.69MB ≈ 약 42만 토큰 → **$8–21** (초기 인덱싱 1회)
  - 그러나 커뮤니티 요약 단계에서 LLM이 전체를 반복 스캔 → **실제 5–10배** 에스컬레이션 가능 (출처: Medium/GraphPraxis "Cutting GraphRAG Token Costs by 90%")
  - 예상 perch_care 초기 인덱싱: **$50–200** (보수적)
- **재인덱싱**: knowledge 추가/수정 시마다 전체/부분 재실행 필요
- **FastGraphRAG 대안**: 비용 ↓ but 그래프 품질 ↓ (요약-focused global search 용도)

### 2.4 의료/수의 도메인의 Graph-RAG 연구 (2024–2025)

| 연구 | 핵심 기여 | perch_care 적용성 |
|------|----------|---------------------|
| **MedGraphRAG** (arxiv 2408.04187) | Triple Graph Construction + U-Retrieval, 일반 LLM을 의료 fine-tune LLM 수준으로 | 높음 (개념 차용) |
| **MedSumGraph** (ScienceDirect 2025) | 구조화 KG + 다중 소스 요약 + 최적화 프롬프트 | 중간 |
| **LiteralKG** (arxiv 2309.03219) | **수의과** EMR 기반 동물 질병 진단용 KGE 모델 | 직접 관련 (하지만 EMR 기반, 문서 기반 아님) |

**의료 도메인의 공통 결론:** 그래프는 "증상 → 질병 → 치료" 같은 **명시적 인과 체인**과 **약물 상호작용** 같은 엔티티 간 관계가 필수인 영역에서 가장 유리하다.

---

## 3. perch_care에 Graph-RAG 적용 시 시뮬레이션

### 3.1 추출 가능한 엔티티/관계 (예시)

현 KB에서 자동 추출될 주요 엔티티 타입:

- **Species**: African Grey, Cockatiel, Budgerigar, ...
- **Disease**: PBFD, Psittacosis, Aspergillosis, ...
- **Symptom**: feather loss, lethargy, discharge, ...
- **Food**: avocado, chocolate, pellets, ...
- **Nutrient**: Vitamin A, Calcium, ...
- **Behavior**: feather plucking, biting, ...
- **Treatment**: quarantine, antibiotics, ...

대표 관계 (edges):

```
(PBFD) --[affects]--> (Cockatoo, Sulphur-crested)
(PBFD) --[causes]--> (feather loss)
(PBFD) --[causes]--> (beak deformity)
(feather plucking) --[cause]--> (Vitamin A deficiency)
(Avocado) --[toxic_to]--> (All Parrots)
(African Grey) --[needs]--> (Calcium supplementation)
```

### 3.2 Graph-RAG이 현 시스템보다 더 잘 답할 질문

| 쿼리 예시 | 현재 RAG | Graph-RAG |
|-----------|----------|-----------|
| "우리 회색앵무가 발 털 뽑기를 시작했어요. 무엇 때문일까요?" | ✅ 잘 답함 (feather-plucking.md, african-grey-diet.md top-5 검색) | ✅ 잘 답함 + 이유를 **경로로 설명** |
| "독성 음식 한 입 먹었어요" | ✅ top-5로 해당 음식 검색 | ✅ 동일 |
| **"앵무새 건강 체크할 때 꼭 봐야 하는 5가지 신호는?"** | ❌ top-5 벡터 검색으론 종합 불가 | ✅ community summary가 이를 위해 설계됨 |
| **"feather plucking을 일으킬 수 있는 모든 원인을 나열해줘"** | ⚠️ 부분적 (일부 문서만 검색) | ✅ 그래프 순회로 완전 열거 가능 |
| **"이 종은 어떤 질병에 취약하고, 그 질병들은 어떻게 전염되나?"** | ❌ 2-hop 불가 | ✅ multi-hop 강점 |

### 3.3 Graph-RAG이 더 **못 할** 수 있는 것

- **단순 FAQ / 응급 처치** — "화상은 어떻게?"처럼 단일 문서 섹션이 답인 경우, Graph-RAG은 오히려 과잉.
- **개인화 (건강 데이터 RAG)** — `_build_rag_context()`가 DB에서 가져오는 펫별 데이터는 그래프화 이득 없음.
- **Vision 검색 쿼리** — 하드코딩된 부위별 쿼리 (`_VISION_SEARCH_QUERIES`)는 이미 카테고리 필터로 충분.

---

## 4. 장단점 비교 매트릭스

### 4.1 Graph-RAG 장점

| 장점 | perch_care 기준 체감도 | 비고 |
|------|-------------------------|------|
| Multi-hop reasoning | 🟡 중간 | 일부 고급 질문만 해당 |
| Global/thematic 요약 | 🟢 높음 | "앵무새 전반" 질문이 많음 |
| 설명 가능성 (경로 제시) | 🟢 높음 | 수의학 신뢰도 ↑ |
| Hallucination 감소 | 🟡 중간 | HyDE로 이미 많이 완화됨 |
| RAGAS 정확도 향상 | 🟡 중간 | 벤치마크상 5~35% 개선 보고 |
| 엔티티 카탈로그 부산물 | 🟢 높음 | 종/질병/증상 DB 자동 구축 |

### 4.2 Graph-RAG 단점

| 단점 | perch_care 기준 심각도 | 비고 |
|------|-------------------------|------|
| **인덱싱 비용** | 🔴 높음 | 초기 $50–200 + 재인덱싱 반복 부담 |
| **운영 복잡도** | 🔴 높음 | Neo4j/LanceDB 추가 인프라, 백업/복구 2배 |
| **Latency 증가** | 🟡 중간 | 그래프 순회 + LLM 종합 → 응답 지연 ~2–3배 |
| **업데이트 느림** | 🟠 중상 | knowledge/*.md 편집 후 재처리 시간 길어짐 |
| **과엔지니어링 위험** | 🔴 높음 | 현 질문 분포가 대부분 single-hop |
| **엔티티 추출 품질** | 🟡 중간 | 수의학 용어를 LLM이 오인 시 그래프 오염 |
| **학습 곡선** | 🟠 중상 | 팀에 그래프 DB/Cypher 운영 경험 필요 |

### 4.3 비용·이득 계산

**가정:** 월 AI 호출 10,000회, knowledge 업데이트 월 2–4회.

| 항목 | 현행 Vector RAG | Graph-RAG 전환 |
|------|-----------------|----------------|
| 초기 인덱싱 | $1–3 (text-embedding-3-large, 1회) | **$50–200** (+ 매 업데이트마다 재실행) |
| 월 쿼리 비용 (RAG 부분만) | ~$5–15 (HyDE LLM + embedding) | ~$15–40 (routing + 그래프 LLM 호출) |
| 인프라 (월) | pgvector 추가 없음 (기존 Railway PG) | Neo4j AuraDB Free 또는 +$65/월 (Pro) |
| 운영 부담 | 낮음 (한 스키마) | 그래프 DB 모니터링 + Cypher 튜닝 |
| 개발 공수 (1회성) | 0 (이미 완성) | **2–4주** (스키마 설계 + 마이그레이션 + A/B) |

**BEP 판단:** 단순 비용만 보면 월 40,000 쿼리 이상부터 정당화 가능. 현 perch_care 트래픽 수준에선 **유지가 합리적**.

---

## 5. 업그레이드 필요성 판단

### 5.1 "지금 업그레이드해야 하는가?" — 답: **아니오**

**근거 1: 현 시스템의 성숙도가 이미 높다**
- HyDE, 키워드 re-ranking, graceful degradation, 병렬 I/O, TTL 재확인, LangSmith 트레이싱 — production 수준.
- 이는 "Graph-RAG로 바꾸지 않으면 안 되는" 수준의 결함이 없다는 뜻.

**근거 2: 질문 분포가 그래프를 요구하지 않는다**
- AI 백과사전의 주된 사용은: (a) 건강 이상 증상 질의, (b) 음식 안전성 문의, (c) 종별 특성 — **대부분 single-hop**.
- Vision 건강체크는 정해진 부위/모드별 쿼리로 이미 최적화되어 있음.

**근거 3: ROI가 나오지 않는다**
- 수의학 KB 규모(1.7MB)는 Graph-RAG의 sweet spot(10MB+)에 한참 못 미침.
- Microsoft GraphRAG의 설계 철학은 **"수백~수천 개 문서를 교차 분석"**하는 시나리오 — perch_care는 그 목적이 아님.

**근거 4: 사업 리스크**
- 앱스토어 리젝 대응 중(premiumEnabled 플래그), 모네타이제이션 전면 수정 중.
- 이 시점에 핵심 AI 파이프라인을 재구축하는 것은 **개발 리소스 낭비** 및 **회귀 버그** 위험.

### 5.2 "언젠가" 업그레이드가 필요한 신호

아래 중 **2개 이상**이 관찰되면 재검토할 가치가 있다:

1. **KB LOW COVERAGE 로그가 월 5% 이상**: `ai_service.py:550`의 경고 로그가 빈발하면 현 검색 자체의 한계.
2. **Multi-hop 질문 비율 증가**: LangSmith 트레이스를 분석해 "여러 주제가 얽힌" 사용자 쿼리 비율이 30%+.
3. **KB 규모 10MB 이상**: 문서 수가 800+로 확장될 때.
4. **"전체를 요약해줘" 유형 질문의 재증가**: 홈 피드/대시보드에 AI 요약 기능을 추가할 때.
5. **수의사 협업 콘텐츠 유입**: 외부 전문가가 인과관계를 명시한 구조화 문서를 공급할 때.
6. **정확도 KPI 미달**: RAGAS나 내부 QA에서 Faithfulness < 0.75 지속.

---

## 6. 권장 로드맵 (단계적 접근)

### Phase 0 — **현행 유지 + 관측 강화** (권장, 즉시)

**목표:** 업그레이드 판단 근거가 될 데이터 수집.

- [ ] LangSmith 트레이스에 "multi-hop 여부" 태그 추가 (LLM이 자체 분류)
- [ ] `KB LOW COVERAGE` 로그를 Slack/Sentry로 알림 연동
- [ ] 주간 KB 평균 유사도 리포트 (이미 있는 `avg_similarity` 활용)
- [ ] 사용자 피드백 버튼 추가 — "이 답변이 도움이 되었나요?" (Faithfulness 프록시)

**비용:** 0원. **기간:** 1주. **리스크:** 없음.

### Phase 1 — **현 RAG 최적화** (선택적, 1–2개월 내)

**목표:** Graph 없이 정확도 5–15% 개선.

- [ ] **Query Expansion**: HyDE + Multi-query (쿼리 3개 파생해 union 검색)
- [ ] **Contextual Compression**: top-5 중 관련 없는 부분 LLM 필터링
- [ ] **Reciprocal Rank Fusion (RRF)**: keyword BM25 + vector + HyDE 결과 병합
- [ ] **메타데이터 스키마 확장**: 각 청크에 `species[]`, `disease[]`, `severity` 태그 추가 (LLM 자동 분류)
- [ ] **카테고리별 prompt hinting**: 시스템 프롬프트가 현 청크들의 카테고리 분포를 명시

**비용:** 엔지니어 10–15일. **효과:** 중. **리스크:** 낮음.

### Phase 2 — **경량 하이브리드** (조건부, 3–6개월 후)

**조건:** Phase 0 관측에서 multi-hop 질문이 30%+ 확인될 경우에만.

**옵션 A: Apache AGE (PostgreSQL 내장 그래프)** ⭐ 추천
- 현 PostgreSQL에 그래프 기능 추가 → **별도 DB 불필요**
- pgvector와 동일 인스턴스에서 조인 가능
- 운영 복잡도 최소

**옵션 B: Neo4j AuraDB**
- 성숙한 Cypher 생태계
- 무료 티어 (200k 노드, 400k 관계) 활용 가능
- 별도 백업/모니터링 필요

**구현 범위 (최소):**
- 엔티티 추출은 **수동 또는 반자동** (LLM으로 초안 → 수의사 검수 → 그래프 저장)
- 쿼리 라우터: "multi-hop detected" 시에만 그래프 사용, 아니면 기존 vector 경로
- **전면 GraphRAG 파이프라인 도입 아님** — 현 시스템을 보강하는 형태

**비용:** 엔지니어 3–4주 + AuraDB 무료/Free 인프라. **리스크:** 중.

### Phase 3 — **Full GraphRAG** (사실상 비권장)

**조건:** Phase 2에서 그래프 질의가 전체 트래픽의 40%+이고, KB 규모가 3배 이상 성장했을 때.

**비용:** $200+ 초기 인덱싱 + 월 $100+ 인프라 + 엔지니어 1–2개월. **리스크:** 높음.

---

## 7. 실천적 결론

### 7.1 지금 당장 해야 할 것

1. **아무것도 하지 말 것** — 현 시스템은 문제를 일으키고 있지 않다.
2. **관측 강화만** (Phase 0): 업그레이드 결정에 필요한 데이터를 모으기 시작.
3. **Phase 1 최적화**는 다른 사업 우선순위(앱스토어 재심사, 모네타이제이션)가 끝난 후 검토.

### 7.2 "Graph-RAG 업그레이드"가 잘못된 프레이밍인 이유

사용자/이해관계자가 "Graph-RAG가 최신이니까 업그레이드하자"라고 요청할 수 있으나, 이는 **수단/목적 전도**이다.

올바른 질문은:
- "어떤 질문에 우리 AI가 못 답하고 있는가?"
- "사용자가 실제로 불만인 부분은 무엇인가?"
- "KPI(Faithfulness, CSAT, Retention)가 현 시스템 탓에 낮은가?"

이 질문들에 **정량적 답이 없으면** 어떤 RAG 아키텍처 변경도 정당화되지 않는다.

### 7.3 수용 가능한 대안 (만약 "뭔가 해야 한다면")

1. **Knowledge Base 자체를 확장**이 가장 ROI 높다.
   - 수의사 검증된 한국/중국 현지 소스 추가
   - 긴급 상황 플로우차트 문서 추가
   - 사용자 피드백 기반 "KB 구멍" 메우기
2. **메타데이터 태깅** — 청크에 `affected_species[]`, `severity_level`, `requires_vet` 등 구조화 필드 추가 후 SQL 필터링. 그래프의 80% 이득을 10%의 복잡도로 얻음.

---

## 8. 참고 자료

### 8.1 현 구현 관련 파일

- [vector_search_service.py](../../backend/app/services/vector_search_service.py) — HyDE + pgvector 검색
- [embedding_service.py](../../backend/app/services/embedding_service.py) — 임베딩 + HyDE 프롬프트
- [ai_service.py](../../backend/app/services/ai_service.py) — 오케스트레이션 (1253 LOC)
- [knowledge_chunk.py](../../backend/app/models/knowledge_chunk.py) — KB 스키마
- [load_knowledge.py](../../backend/scripts/load_knowledge.py) — 인덱싱 스크립트
- [chunker.py](../../agent/chunker.py) — 마크다운 섹션 청커
- [2026-03-01-ai-upgrade-final-design.md](./2026-03-01-ai-upgrade-final-design.md) — 이전 AI 업그레이드 설계서
- [../development-logs/2026-03-07-ai-service-architecture.md](../development-logs/2026-03-07-ai-service-architecture.md) — 운영 아키텍처 문서

### 8.2 외부 참고 (2026년 4월 기준)

**Graph-RAG 개요 / 비교:**
- [GraphRAG vs. Vector RAG — Meilisearch Blog](https://www.meilisearch.com/blog/graph-rag-vs-vector-rag)
- [Graph RAG vs. Vector RAG — Medium/AK (2026-03)](https://medium.com/@ajaysrinivasan87/graph-rag-vs-vector-rag-choosing-the-right-architecture-for-enterprise-use-cases-f3f6205f959f)
- [GraphRAG vs RAG: Which Builds Better AI Search in 2026? — AIThinkerLab](https://aithinkerlab.com/graphrag-vs-rag-the-ultimate-guide-to-building-reasoning-ai-search-in-2026/)
- [GraphRAG Implementation Guide 2026 — PreMAI Blog](https://blog.premai.io/graphrag-implementation-guide-entity-extraction-query-routing-when-it-beats-vector-rag-2026/)
- [Vector vs Graph RAG for Agent Memory — MachineLearningMastery](https://machinelearningmastery.com/vector-databases-vs-graph-rag-for-agent-memory-when-to-use-which/)
- [Graph RAG in 2026: What Actually Works — Graph Praxis](https://medium.com/graph-praxis/graph-rag-in-2026-a-practitioners-guide-to-what-actually-works-dca4962e7517)

**비용 분석:**
- [Cutting GraphRAG Token Costs by 90% in Production — Graph Praxis (2026-03)](https://medium.com/graph-praxis/cutting-graphrag-token-costs-by-90-in-production-5885b3ffaef0)
- [Microsoft GraphRAG — Official Docs (Indexing Methods)](https://github.com/microsoft/graphrag/blob/main/docs/index/methods.md)

**의료/수의 도메인:**
- [Medical Graph RAG — arxiv 2408.04187](https://arxiv.org/abs/2408.04187)
- [MedGraphRAG on GitHub](https://github.com/SuperMedIntel/Medical-Graph-RAG)
- [MedSumGraph — ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0933365725002465)
- [LiteralKG — 동물 질병 진단용 KGE (arxiv 2309.03219)](https://arxiv.org/abs/2309.03219)
- [Mayo Clinic Platform — Knowledge Graphs in Healthcare](https://www.mayoclinicplatform.org/2023/12/21/knowledge-graphs-can-move-healthcare-into-the-future/)

**하이브리드 아키텍처:**
- [Apache AGE on PostgreSQL — LinkedIn](https://www.linkedin.com/pulse/apache-age-bridging-relational-databases-graphs-frank-wk5he)
- [Neo4j GraphRAG Python Guide](https://neo4j.com/docs/neo4j-graphrag-python/current/user_guide_rag.html)
- [Building a Hybrid RAG Agent with Neo4j + Milvus — HackerNoon](https://hackernoon.com/building-a-hybrid-rag-agent-with-neo4j-graphs-and-milvus-vector-search)
- [GraphRAG with Qdrant and Neo4j — Qdrant Docs](https://qdrant.tech/documentation/examples/graphrag-qdrant-neo4j/)

---

**문서 끝.** 이 문서는 **결정 문서가 아닌 분석 문서**입니다. 실제 업그레이드 여부는 Phase 0 관측 데이터가 모인 후 재검토해야 합니다.
