# RAG 검색률 측정 보고서 — 앵박사 & 비전 분석

**측정일**: 2026-05-14
**대상 기간**: 최근 30일 (2026-04-14 ~ 2026-05-14), 일부 지표는 전체 기간
**측정자**: Claude (Railway CLI + production Postgres 직접 조회)
**환경**: Railway project `superb-kindness`, environment `production`, service `perch_care`

---

## 한 줄 결론

| 지표 | 앵박사 (Encyclopedia) | 비전 분석 (Vision) |
|------|----------------------|-------------------|
| **사용량 (30일)** | 75건 | 62건 |
| **검색 호출률 (Coverage)** | ~100% (코드상 항상 호출) | ~100% (코드상 항상 호출) |
| **검색 성공률 (avg_sim ≥ 0.3)** | **98.7%** (74/75) | **측정 불가** (KB 로깅 없음) |
| **검색 품질 분포** | **측정 불가** (INFO 로그 미수집) | **측정 불가** |
| **응답시간 평균** | 7.5초 (p95 17.6초) | 14.9초 (p95 20.6초) |

핵심 메시지:
- **앵박사 검색 성공률은 매우 높음** — 90일간 retrieval 실패는 단 1건(중국어 모호 쿼리 "还是没找到")
- **비전 분석은 RAG 품질 관측이 사실상 불가능** — 코드에 KB 모니터링 로깅 자체가 없음
- 두 기능 모두 **개별 similarity 분포는 측정 불가** — application INFO 로그가 root logger 디폴트(WARNING)에 막혀 stdout 미전송. Phase B 보강 필수.

---

## 1. 측정 방법

### 1.1 데이터 소스

| 소스 | 용도 | 접근 방법 |
|------|------|----------|
| Postgres (`superb-kindness/Postgres`) | 사용량, 응답시간, Vision 신뢰도/모드/상태 분포 | `psql $DATABASE_PUBLIC_URL` |
| Postgres (`pgVector-Railway`) | 지식베이스(KB) 구성 통계 | `psql $DATABASE_PUBLIC_URL` |
| Railway logs (perch_care service) | RAG 실패/타임아웃 카운트 | `railway logs --filter ... --since 30d --json` |

### 1.2 재현 가능 자산

- **SQL 묶음**: [`scripts/rag_metrics.sql`](../../scripts/rag_metrics.sql) — 7개 쿼리, `psql -f`로 재실행
- **로그 파싱 스크립트**: [`scripts/parse_kb_search_logs.py`](../../scripts/parse_kb_search_logs.py) — 현재는 입력 로그가 비어 있으나 Phase B 후 사용 가능
- **SQL 결과 덤프**: `/tmp/perch_rag_audit/sql_results.txt`

---

## 2. 사용량 / 빈도

### 2.1 전체 합계

| 기간 | Encyclopedia | Vision |
|------|-------------|--------|
| 7일 | 15 | 17 |
| 30일 | 75 | 62 |
| 전체 (DB 시작 이래) | 238 | 64 |
| 데이터 시작일 | 2026-02-27 | 2026-04-04 |

Encyclopedia는 ~2.5개월간 누적, Vision은 ~1개월. Vision은 출시 후 빠르게 따라잡는 중.

### 2.2 Encyclopedia 일별 추이 (최근 30일, 발생일만)

```
2026-04-25 ████████████████ 14
2026-04-26 ███████████████  13
2026-05-13 ███████          7
2026-04-18 ████             4
2026-04-22 ████             4
2026-04-24 ███              3
2026-04-29 ███              3
2026-05-05 ███              3
2026-05-07 ███              3
2026-05-10 ███              3
…
```

4월 25-26일 피크(14+13=27건), 그 외에는 일평균 3건 이하. **사용 빈도는 낮으나 spike형**.

### 2.3 Vision 모드/부위별 분포 (30일)

| 모드 | 부위 | 호출 | 평균 신뢰도 | 평균 응답시간 |
|------|-----|------|-----------|-------------|
| `full_body` | — | 33 (53%) | 76.0 | 16.1초 |
| `droppings` | — | 16 (26%) | 77.2 | 13.9초 |
| `food` | — | 6 (10%) | 59.2 | 12.9초 |
| `part_specific` | eye | 4 | 53.0 | 11.8초 |
| `part_specific` | foot | 2 | 60.5 | 15.7초 |
| `part_specific` | feather | 1 | 85.0 | 11.8초 |

`full_body`(전신)이 압도적. `food`와 `part_specific eye`/`foot`는 신뢰도가 50-60대로 낮은 편.

### 2.4 사용자 분포 (30일, Top 5)

| user_id (앞 8자리) | enc | vis | 합계 |
|------------------|-----|-----|------|
| `2d0796bd…` | 3 | 11 | 14 |
| `18e9bd8e…` | 7 | 3 | 10 |
| `30ae2ba7…` | 10 | 0 | 10 |
| `9828da58…` | 5 | 1 | 6 |
| `c9cef3fa…` | 0 | 5 | 5 |

상위 사용자 1명이 비전 11건. 분포는 비교적 평탄(heavy user 1-2명).

---

## 3. 검색 호출률 (Coverage)

### 3.1 정의

`Coverage = (RAG retrieval 호출 수) / (전체 AI 요청 수)`

### 3.2 결과

**Encyclopedia: ~100% (이론값)**
- `ai_service.py:513-558` `prepare_system_message()` 가 ask 진입마다 무조건 `search_knowledge()` 호출
- 분기 없음 — 코드상 100%
- **실측은 불가** (이유: 정상 KB search는 INFO로 로깅되어 stdout 미전송 — 4.2 참조)

**Vision: ~100% (이론값)**
- `ai_service.py:1131` `analyze_vision_health_check()` 가 매 호출마다 `search_knowledge(_get_vision_search_query(mode, part))` 실행
- 분기 없음
- **실측은 불가** (Vision은 KB 로깅 자체가 코드에 없음)

### 3.3 신뢰도 평가

Coverage = 100% 추정은 코드 검토 기반. 실증을 위해선 **Phase B의 로깅 보강 후 logs/DB에서 직접 카운트** 필요.

---

## 4. 검색 성공률 (Hit Rate)

### 4.1 측정 가능한 한 가지 — Encyclopedia만, threshold=0.3

`ai_service.py:548-552`:
```python
logger.info("KB search: ... avg_similarity=%.3f", ..., avg_score)  # INFO — 미전송
if avg_score < 0.3:
    logger.warning("KB LOW COVERAGE: ...", ...)                     # WARNING — 전송됨
elif not knowledge_results:
    logger.warning("KB NO RESULTS: ...", ...)                       # WARNING — 전송됨
```

WARNING은 stdout으로 잡힘. `railway logs --filter '"KB NO RESULTS"' --since 90d` 결과:

| 패턴 | 90일간 카운트 |
|------|-------------|
| `KB NO RESULTS` | **1** |
| `KB LOW COVERAGE` (avg_sim < 0.3) | **0** |
| `Vector search timed out` | 4 |
| `Vector search failed` | 0 |

### 4.2 계산

**Encyclopedia Hit Rate (avg_sim ≥ 0.3, 최근 30일):**
- 분모: 75건 (Postgres `ai_encyclopedia_logs` 30일)
- retrieval 완전 실패: 1건 (90일 합산. 30일로 잘라도 1건 — `2026-04-26`)
- `avg_sim < 0.3`인 케이스: 0건
- **Hit Rate ≈ 74/75 = 98.7%**

실패한 1건의 쿼리: `'还是没找到'` (중국어, "아직 못 찾았어"). 자연어 follow-up 질문이라 KB 검색용 쿼리로 부적합.

### 4.3 측정 불가능한 것

- **0.5 / 0.6 / 0.7 threshold 기준 hit rate**: INFO 로그 미수집 → 개별 avg_sim 값 알 수 없음
- **Vision의 hit rate**: 코드에 KB 모니터링 로깅 자체가 없음 (전체 vision retrieval에 대해 0건의 메트릭)

---

## 5. 검색 품질 분포

### 5.1 직접 측정 결과

**측정 불가**. 사유:
- 개별 검색의 `top_k`, `avg_similarity` 분포는 INFO 로그(`KB search: ...`)에서만 추출 가능
- 해당 INFO 로그가 stdout으로 전송되지 않음 (4.2)
- DB 테이블(`ai_encyclopedia_logs`, `ai_vision_logs`)에 retrieval 메타데이터 컬럼 없음

### 5.2 간접 추정 (Vision 신뢰도 분포)

Vision의 `confidence_score`는 retrieval 품질이 아니라 **LLM의 분석 자신감**이지만, 보조 지표로 참조:

```
80–90 점수 ████████████████████████████████████████████ 45건 (70%)
70–80      █████                                         5건 (8%)
60–70      ██                                            2건 (3%)
50–60      █                                             1건 (2%)
40–50      ██                                            2건 (3%)
30–40      █████                                         5건 (8%)
20–30      █                                             1건 (2%)
10–20      █                                             1건 (2%)
```

대부분 80-90 범위(70%)지만 30-40 범위에 5건(8%)이 있어 일부 케이스에서 분석 자신감 낮음. 이게 retrieval 부족 때문인지, 이미지 품질 때문인지 현재 데이터로는 분리 불가.

---

## 6. 응답시간 분포

### 6.1 Encyclopedia (전체 238건)

| 통계 | 값 |
|------|-----|
| min | 0 ms (이상치 — 캐시 hit 또는 에러) |
| p50 (median) | 5,031 ms |
| **avg** | **7,536 ms** |
| p95 | 17,628 ms |
| p99 | 19,587 ms |
| max | 22,380 ms |

### 6.2 Vision (전체 64건)

| 통계 | 값 |
|------|-----|
| min | 8,691 ms |
| p50 | 14,021 ms |
| **avg** | **14,883 ms** |
| p95 | 20,581 ms |
| p99 | 23,193 ms |
| max | 24,001 ms |

Vision이 Encyclopedia 대비 **약 2배 느림** (이미지 처리 + Vision 모델). Vision p95가 20초를 넘는 점은 UX 관점에서 주목.

---

## 7. 지식 베이스 (KB) 구성

`pgVector-Railway` Postgres → `knowledge_chunks` 테이블 (1개 테이블만 존재):

| 항목 | 값 |
|------|-----|
| 총 chunks | **2,946** |
| 고유 sources | 287 |
| 고유 categories | 10 |
| 고유 languages | 2 |

**언어별:**
- en: 2,333 chunks (79%)
- zh: 613 chunks (21%)
- **ko: 0 chunks** — 한국어는 HyDE를 통해 영어로 변환 후 검색

**카테고리별 (Top 10):**
| 카테고리 | chunks |
|---------|--------|
| diseases | 853 |
| behavior | 637 |
| nutrition | 543 |
| species | 474 |
| health | 148 |
| care | 96 |
| legal | 56 |
| culture | 47 |
| training | 47 |
| market | 45 |

질병/행동/영양 3카테고리가 전체의 69%를 차지.

---

## 8. 데이터 한계 명시

### 8.1 Application INFO 로그가 stdout으로 안 감

**원인**: `backend/app/main.py`에 `logging.basicConfig(level=logging.INFO)` 호출 없음. Python root logger 디폴트 WARNING으로 동작 → `logger.info(...)`는 핸들러에 도달하지 못함.

**영향**:
- `KB search: query=... top_k=... avg_similarity=...` 로그 (`ai_service.py:548`) 전체 손실
- 개별 retrieval의 quality/quantity 메트릭 측정 불가
- WARNING 레벨인 `KB LOW COVERAGE`, `KB NO RESULTS`만 잡힘 (성공 케이스는 안 잡힘)

### 8.2 Vision pipeline에 KB 모니터링 로깅 없음

`ai_service.py:1131-1149`의 vision RAG 호출부에 `logger.info("KB search: ...")` 같은 호출이 없음. Encyclopedia에만 있음. Vision의 retrieval 품질은 어떤 로깅으로도 회수 불가.

### 8.3 Railway logs 보존 기간

Railway logs는 플랜에 따라 보존 기간 제한. `--since 90d` 까지는 회수되었으나 이전 데이터는 손실. 본 보고서의 "전체 기간" 카운트는 Postgres 기반(영구 보존), 로그 기반 카운트는 90일 윈도우 내.

### 8.4 쿼리 텍스트 미저장

Postgres `ai_encyclopedia_logs`는 `query_length`(int)만 저장하고 실제 쿼리 텍스트 미저장. 어떤 토픽이 자주 묻는지 / 잘 안 잡히는지 분석 불가.

### 8.5 비교 가능성

표본 수가 작음 (Encyclopedia 30일 75건, Vision 62건). 통계적 유의성 한계 있음.

---

## 9. Phase B — 측정 인프라 보강 권장사항 (별도 PR 제안)

본 보고서의 측정 한계를 해소하기 위한 후속 작업. **본 plan에서는 실행하지 않음** — 별도 PR로 진행 권장.

### 9.1 즉시 (1줄 변경) — 효과 매우 큼

`backend/app/main.py` 상단에 다음 추가:

```python
import logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
```

→ `KB search` INFO 로그가 즉시 stdout에 흘러 `railway logs --filter '"KB search"'`로 회수 가능. `scripts/parse_kb_search_logs.py`로 hit rate(0.5/0.6/0.7), similarity 분포 즉시 산출 가능해짐.

### 9.2 Vision pipeline 동등화

`ai_service.py:1131` 부근에 Encyclopedia와 동일한 KB 모니터링 추가:

```python
if knowledge_results:
    scores = [r.get("similarity", 0) for r in knowledge_results if isinstance(r, dict)]
    avg_score = sum(scores) / len(scores) if scores else 0
    logger.info("KB search [vision]: mode=%s part=%s top_k=%d avg_similarity=%.3f",
                mode, part, len(scores), avg_score)
    if avg_score < 0.3:
        logger.warning("KB LOW COVERAGE [vision]: mode=%s avg_similarity=%.3f", mode, avg_score)
else:
    logger.warning("KB NO RESULTS [vision]: mode=%s", mode)
```

### 9.3 DB 컬럼 영속화 (장기 분석용)

`backend/alembic/versions/<new>_add_rag_metrics_columns.py`:

```sql
ALTER TABLE ai_encyclopedia_logs
  ADD COLUMN retrieval_top_k INTEGER,
  ADD COLUMN retrieval_avg_similarity FLOAT,
  ADD COLUMN retrieval_max_similarity FLOAT,
  ADD COLUMN retrieval_ms INTEGER;

ALTER TABLE ai_vision_logs
  ADD COLUMN retrieval_top_k INTEGER,
  ADD COLUMN retrieval_avg_similarity FLOAT,
  ADD COLUMN retrieval_max_similarity FLOAT,
  ADD COLUMN retrieval_ms INTEGER;
```

코드 변경:
- `backend/app/services/vector_search_service.py:72-168` `search_knowledge()` 반환값을 `(chunks, metadata: dict)`로 변경 (혹은 별도 wrapper)
- `backend/app/services/ai_service.py:622-655` (encyclopedia 로그 저장) / vision 저장부에서 신규 컬럼 set

→ Railway logs 보존 기간 의존성 완전 제거. 모든 4가지 지표를 SQL 단독으로 산출 가능.

### 9.4 우선순위

1. **9.1** (5분 작업, 효과 즉시) ← 강력 추천
2. **9.2** (15분 작업, Vision 측정 가능해짐)
3. **9.3** (1-2시간 작업, 장기 운영용)

---

## 10. 부록 — 재현 명령

### 10.1 Postgres 분석 재실행

```bash
cd /Users/imdonghyeon/perch_care
railway link --project superb-kindness --environment production --service perch_care
DATABASE_PUBLIC_URL=$(railway variables --service Postgres --kv | grep '^DATABASE_PUBLIC_URL=' | cut -d= -f2-)
psql "$DATABASE_PUBLIC_URL" -f scripts/rag_metrics.sql
```

### 10.2 KB 실패 패턴 회수

```bash
railway logs --filter '"KB NO RESULTS"' --since 90d --json
railway logs --filter '"KB LOW COVERAGE"' --since 90d --json
railway logs --filter '"Vector search timed out"' --since 90d --json
```

### 10.3 KB 구성 확인

```bash
VECTOR_URL=$(railway variables --service pgVector-Railway --kv | grep '^DATABASE_PUBLIC_URL=' | cut -d= -f2-)
psql "$VECTOR_URL" -c "SELECT language, COUNT(*) FROM knowledge_chunks GROUP BY language;"
psql "$VECTOR_URL" -c "SELECT category, COUNT(*) FROM knowledge_chunks GROUP BY category ORDER BY count DESC;"
```

### 10.4 Phase B 적용 후 (현재는 입력 0건)

```bash
mkdir -p /tmp/perch_rag_audit
railway logs --filter '"KB search"' --since 30d --json > /tmp/perch_rag_audit/kb_search.jsonl
python3 scripts/parse_kb_search_logs.py /tmp/perch_rag_audit/kb_search.jsonl
```
