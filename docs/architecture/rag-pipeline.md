# RAG Pipeline — HyDE + pgvector

> 앵박사 백과사전·비전 분석의 **RAG 컨텍스트 수집 파이프라인**. LLM 라우팅·SSE 응답은 [hybrid-llm-pipeline.md](hybrid-llm-pipeline.md) 참조.
>
> **갱신** — 2026-05-14

---

## Key Contributions

### 설명

HyDE 가상 문서 → 임베딩 → pgvector HNSW 검색 → Re-ranking → top-5 컨텍스트 주입의 production-grade RAG 파이프라인을 구축했다. EN 2,306 / ZH 537 chunk가 하나의 vector space에 공존해 사용자 언어와 무관하게 양쪽 지식을 동시 검색하며, 유사도 로깅으로 KB 커버리지 격차를 운영 단에서 추적한다.

### 사용 기술 스택

| 구성 요소 | 기술 | 핵심 파라미터 |
|-----------|------|-------------|
| 벡터 DB | PostgreSQL **pgvector** + HNSW | 코사인 거리, top_k=5, min_sim=0.3 |
| 임베딩 | OpenAI **text-embedding-3-large** | 3,072 dim |
| HyDE 생성 | **gpt-4o-mini** | temp=0.0, 150-300 words |
| Re-ranking | 임베딩 0.8 + 키워드 0.2 blending | 외부 API 없음 |
| 청킹 | H2/H3 섹션 기반 분할 | 100-1,500 chars |
| 비동기 | async/await + AsyncSession | DB 세션 분리 |

### 설계 디자인

각 구성 요소를 **왜 이 기술로 결정했는지**, 검토한 대안과 함께 정리한다.

#### pgvector — 벡터 데이터베이스

```mermaid
flowchart LR
    subgraph 선택["pgvector"]
        PG["PostgreSQL 확장<br/>+ HNSW 인덱스"]
    end

    subgraph 이유["선택 근거"]
        R1["기존 PostgreSQL 인프라<br/>그대로 사용 (추가 비용 $0)"]
        R2["SQL JOIN으로<br/>사용자·펫 데이터 통합"]
        R3["2,843 chunk 규모에<br/>분산 처리 불필요"]
    end

    subgraph 제외["검토 후 제외"]
        A1["ChromaDB → 로컬 전용,<br/>production 부적합"]
        A2["Pinecone·Qdrant → 관리형 비용<br/>$25-70/mo + 외부 hop"]
        A3["GraphRAG·Neo4j → 초기 $50-200<br/>+ multi-hop 비중 낮아 ROI 부족"]
    end

    PG --> R1 & R2 & R3

    classDef sel fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px
    classDef reason fill:#FFF8E7,stroke:#FF9A42
    classDef alt fill:#FFEBEE,stroke:#C62828
    class PG sel
    class R1,R2,R3 reason
    class A1,A2,A3 alt
```

이미 Railway에서 PostgreSQL을 운영하고 있었다. pgvector 확장만 켜면 별도 서비스 없이 벡터 검색이 가능하고, KB 규모(2,843 chunk)에 전용 벡터 DB의 분산 처리는 과하다. ChromaDB는 Phase 2 로컬 벤치마크용으로 쓴 뒤 Phase 4에서 pgvector로 전환했고, GraphRAG는 단일 hop 위주인 현 질의 패턴에 비용 대비 효과가 낮아 보류했다.

#### text-embedding-3-large — 임베딩 모델

```mermaid
flowchart LR
    subgraph 선택["text-embedding-3-large (3,072 dim)"]
        L["크로스링구얼 유사도<br/>small 대비 +12-18%"]
    end

    subgraph 제외["제외"]
        S["small (1,536 dim)<br/>→ 다국어 정확도 부족"]
        OS["오픈소스 (e5 등)<br/>→ GPU 필요 + 다국어 열위"]
    end

    classDef sel fill:#FFE4B5,stroke:#FF9A42,stroke-width:2px
    classDef alt fill:#F5F5F5,stroke:#999
    class L sel
    class S,OS alt
```

수의학 전문 용어(약품명·종명·증상어)의 세밀한 의미 구분이 필요하다. `large`는 `small` 대비 ko/zh → EN KB 검색 유사도가 12-18% 높았고, 전량 임베딩 비용은 ~$0.35로 합리적이다. 오픈소스 모델은 GPU 인프라가 필요하고 다국어 성능이 떨어져 제외했다.

#### gpt-4o-mini — HyDE 가상 문서 생성

HyDE 가상 문서는 사용자에게 노출되지 않는 **검색용 중간 산출물**이다. 최종 답변은 메인 모델이 별도 생성하므로, HyDE에는 속도·비용이 우선이다. gpt-4o 대비 3-4x 빠르고 1/30 비용이면서 영문 수의학 참고 문서 생성에 충분한 품질을 보였다. temp=0.0으로 동일 질문에 대한 검색 일관성도 확보했다.

#### Re-ranking — 임베딩 0.8 + 키워드 0.2

```mermaid
flowchart LR
    Sim["코사인 유사도 × 0.8"] --> Blend["combined_score"]
    KW["키워드 오버랩 × 0.2"] --> Blend

    subgraph 제외["제외"]
        C1["Cohere Rerank → 외부 API 비용"]
        C2["Cross-encoder → GPU 필요 + 200ms"]
    end

    classDef sel fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px
    classDef alt fill:#FFEBEE,stroke:#C62828
    class Blend sel
    class C1,C2 alt
```

수의학 도메인에서 약품명·종 이름 같은 정확 단어 일치가 임베딩 유사도만큼 중요하다. 키워드 blending은 외부 의존 0, latency ~0ms로 이 문제를 해결한다. top-5 chunk 규모에서 cross-encoder의 정밀도 이점은 미미했다.

---

## 파이프라인 흐름

```mermaid
flowchart LR
    Q["사용자 질문<br/>(다국어)"]
    HyDE["HyDE 가상 영문 문서<br/>gpt-4o-mini"]
    Emb["text-embedding-3-large<br/>3,072 dim"]
    PG[("pgvector HNSW<br/>EN 2,306 / ZH 537")]
    RR["Re-ranking<br/>0.8 + 0.2"]
    Ctx["top-5 chunk 주입<br/>(다국어 라벨)"]

    Q --> HyDE --> Emb --> PG --> RR --> Ctx
    PG -. "검색 실패" .-> Skip["graceful degradation"]

    classDef rag fill:#FFF8E7,stroke:#FF9A42
    classDef vec fill:#E8F5E9,stroke:#2E7D32
    classDef fallback fill:#FFEBEE,stroke:#C62828
    class HyDE,Emb,Ctx rag
    class PG,RR vec
    class Skip fallback
```

## HyDE 효과

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#FF9A42'}}}%%
xychart-beta
    title "HyDE 도입 전후 코사인 유사도"
    x-axis ["ko → EN KB", "zh → EN KB", "en → EN KB"]
    y-axis "유사도" 0 --> 1
    bar "Direct" [0.21, 0.19, 0.68]
    bar "HyDE" [0.85, 0.78, 0.84]
```

| 질문 언어 | Direct | HyDE | 개선폭 |
|-----------|--------|------|--------|
| ko → EN KB | 0.17-0.24 | 0.82-0.87 | **+84-108%** |
| zh → EN KB | 0.15-0.22 | 0.70-0.85 | **+20-38%** |
| en → EN KB | 0.66-0.69 | 0.80-0.88 | +16-33% |

## Ingestion 파이프라인

```mermaid
flowchart LR
    MD["마크다운 274파일<br/>EN 232 / ZH 42"]
    CH["H2/H3 섹션 청킹<br/>100-1,500 chars"]
    HS["SHA-256 해시<br/>(lang+source+content)"]
    EB["배치 임베딩<br/>100 chunk/batch"]
    DB[("pgvector upsert<br/>ON CONFLICT DO UPDATE")]

    MD --> CH --> HS --> EB --> DB

    classDef process fill:#FFF8E7,stroke:#FF9A42
    classDef db fill:#E8F5E9,stroke:#2E7D32
    class CH,HS,EB process
    class DB db
```

- 총 2,843 chunk | 임베딩 ~16.5s | `chunk_hash` 기반 증분 로드 지원

## KB 모니터링

```mermaid
flowchart LR
    Search["검색 결과"] --> Count{"결과 수"}
    Count -- "0건" --> No["KB NO RESULTS"]
    Count -- "1건+" --> Avg{"유사도 평균"}
    Avg -- "< 0.3" --> Low["KB LOW COVERAGE"]
    Avg -- ">= 0.3" --> OK["정상 주입"]

    classDef warn fill:#FFEBEE,stroke:#C62828
    classDef ok fill:#E8F5E9,stroke:#2E7D32
    class No,Low warn
    class OK ok
```

---

## 핵심 파일

| 파일 | 역할 |
|------|------|
| `backend/app/services/embedding_service.py` | text-embedding-3-large + HyDE 생성 |
| `backend/app/services/vector_search_service.py` | pgvector 검색 + Re-ranking + KB 모니터링 |
| `backend/scripts/load_knowledge.py` | 마크다운 → 청킹 → 임베딩 → pgvector 적재 |
| `backend/alembic/versions/007_add_pgvector_knowledge.py` | pgvector 확장 + HNSW 인덱스 |
| `backend/app/config.py` | 임베딩 모델·검색 파라미터 설정 |

**관련**: [hybrid-llm-pipeline.md](hybrid-llm-pipeline.md) — LLM 라우팅 / SSE 응답 / 메타 stripping
