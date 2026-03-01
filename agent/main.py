"""
앵박사 AI 에이전트 — FastAPI 앱 + CLI 진입점.

사용법:
  python main.py                            # FastAPI 서버 실행 (localhost:8100)
  python main.py --load                     # 지식 데이터 적재
  python main.py --load --reset             # 초기화 후 재적재
  python main.py --stats                    # 적재된 데이터 통계
  python main.py --search "feather plucking" # 벡터 검색만
  python main.py --ask "Can parrots eat avocado?" # 단일 질문
  python main.py --interactive              # 인터랙티브 채팅
  python main.py --benchmark                # 벤치마크 테스트
"""

import argparse
import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv

# .env 로드
load_dotenv(Path(__file__).parent / ".env")

# --- FastAPI 앱 ---
from fastapi import FastAPI, Query
from pydantic import BaseModel, Field

app = FastAPI(
    title="앵박사 AI Agent",
    description="앵무새 지식 RAG 파이프라인 테스트 에이전트",
    version="0.1.0",
)


class SearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=2000)
    top_k: int = Field(5, ge=1, le=20)
    category: str | None = None
    language: str | None = None


class AskRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=2000)
    history: list[dict] = Field(default_factory=list)
    model: str = "gpt-4o-mini"
    max_tokens: int = 1024
    top_k: int = 5


@app.post("/search")
def api_search(req: SearchRequest):
    """벡터 검색만 실행, 유사도 결과 반환."""
    import vector_store

    start = time.time()
    results = vector_store.search(
        query=req.query,
        top_k=req.top_k,
        category=req.category,
        language=req.language,
    )
    elapsed = time.time() - start
    return {
        "query": req.query,
        "results": results,
        "count": len(results),
        "elapsed_ms": round(elapsed * 1000, 1),
    }


@app.post("/ask")
def api_ask(req: AskRequest):
    """전체 파이프라인: 검색 → GPT 답변 + 소스."""
    import chat as chat_module

    start = time.time()
    answer, sources = chat_module.chat(
        query=req.query,
        history=req.history,
        model=req.model,
        max_tokens=req.max_tokens,
        top_k=req.top_k,
    )
    elapsed = time.time() - start
    return {
        "query": req.query,
        "answer": answer,
        "sources": [
            {"source": s["source"], "section": s["section_title"], "similarity": s["similarity"]}
            for s in sources
        ],
        "elapsed_ms": round(elapsed * 1000, 1),
    }


@app.get("/stats")
def api_stats():
    """적재된 데이터 통계."""
    import vector_store

    return vector_store.get_stats()


@app.post("/load")
def api_load(reset: bool = Query(False)):
    """지식 데이터 적재."""
    from knowledge_loader import load_knowledge

    return load_knowledge(reset=reset)


# --- CLI 모드 ---

BENCHMARK_QUERIES = [
    {"query": "My parrot is plucking its feathers", "lang": "EN", "expected": "feather plucking, FDB"},
    {"query": "Can parrots eat avocado?", "lang": "EN", "expected": "avocado, persin, toxic"},
    {"query": "What are symptoms of psittacosis?", "lang": "EN", "expected": "psittacosis, chlamydia"},
    {"query": "앵무새가 깃털을 뽑아요", "lang": "KO", "expected": "feather plucking (cross-lingual)"},
    {"query": "앵무새에게 아보카도를 줘도 되나요?", "lang": "KO", "expected": "avocado, toxic"},
    {"query": "我的鹦鹉拔自己的羽毛怎么办", "lang": "ZH", "expected": "啄羽, feather plucking"},
    {"query": "鹦鹉可以吃牛油果吗", "lang": "ZH", "expected": "avocado, toxic"},
    {"query": "虎皮鹦鹉怎么训练上手", "lang": "ZH", "expected": "上手训练, step-up"},
]


def cli_search(query: str):
    """CLI: 벡터 검색."""
    import vector_store

    print(f"\n🔍 검색: \"{query}\"\n")
    results = vector_store.search(query, top_k=5)
    if not results:
        print("검색 결과 없음.")
        return
    for i, r in enumerate(results, 1):
        print(f"  [{i}] similarity={r['similarity']:.4f}  |  {r['source']}  |  {r['section_title']}")
        # 내용 미리보기 (첫 200자)
        preview = r["content"][:200].replace("\n", " ")
        print(f"      {preview}...")
        print()


def cli_ask(query: str):
    """CLI: 단일 질문."""
    import chat as chat_module

    print(f"\n💬 질문: \"{query}\"\n")
    start = time.time()
    answer, sources = chat_module.chat(query)
    elapsed = time.time() - start

    print(f"🦜 앵박사:\n{answer}\n")
    if sources:
        print(f"📚 참조 소스 ({len(sources)}건):")
        for s in sources:
            print(f"  - {s['source']} ({s['section_title']}) [similarity: {s['similarity']:.2f}]")
    print(f"\n⏱  {elapsed:.1f}초")


def cli_interactive():
    """CLI: 인터랙티브 채팅."""
    import chat as chat_module

    print("\n🦜 앵박사 AI 에이전트 (인터랙티브 모드)")
    print("   질문을 입력하세요. 종료하려면 'quit' 또는 'exit'을 입력하세요.\n")

    history = []
    while True:
        try:
            query = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n종료합니다.")
            break

        if not query:
            continue
        if query.lower() in ("quit", "exit", "q"):
            print("종료합니다.")
            break

        start = time.time()
        answer, sources = chat_module.chat(query, history=history)
        elapsed = time.time() - start

        print(f"\n🦜 앵박사:\n{answer}\n")
        if sources:
            print(f"📚 참조 ({len(sources)}건):", end=" ")
            for s in sources[:3]:
                print(f"[{s['source']}]", end=" ")
            print()
        print(f"⏱  {elapsed:.1f}초\n")

        history.append({"role": "user", "content": query})
        history.append({"role": "assistant", "content": answer})
        # 히스토리 최대 10개 유지
        if len(history) > 20:
            history = history[-20:]


def cli_benchmark():
    """CLI: 벤치마크 테스트."""
    import vector_store
    import chat as chat_module

    print("\n📊 벤치마크 테스트 시작\n")
    print("=" * 80)

    for i, bq in enumerate(BENCHMARK_QUERIES, 1):
        query = bq["query"]
        lang = bq["lang"]
        expected = bq["expected"]

        print(f"\n[{i}/{len(BENCHMARK_QUERIES)}] ({lang}) \"{query}\"")
        print(f"  기대: {expected}")

        # 검색 결과
        results = vector_store.search(query, top_k=3)
        if results:
            print(f"  검색 결과:")
            for j, r in enumerate(results, 1):
                print(f"    [{j}] sim={r['similarity']:.3f} | {r['source']} | {r['section_title']}")
        else:
            print(f"  검색 결과: 없음 ❌")

        # GPT 답변
        start = time.time()
        answer, _ = chat_module.chat(query, top_k=3)
        elapsed = time.time() - start
        preview = answer[:150].replace("\n", " ")
        print(f"  답변 ({elapsed:.1f}s): {preview}...")
        print("-" * 80)

    print("\n벤치마크 완료!")


def cli_stats():
    """CLI: 통계 출력."""
    import vector_store

    stats = vector_store.get_stats()
    print(f"\n📊 Knowledge Base 통계")
    print(f"  총 청크: {stats['total']}개\n")

    if stats["by_category"]:
        print("  카테고리별:")
        for cat, count in stats["by_category"].items():
            print(f"    {cat}: {count}개")

    if stats["by_language"]:
        print("\n  언어별:")
        for lang, count in stats["by_language"].items():
            print(f"    {lang}: {count}개")
    print()


def main():
    parser = argparse.ArgumentParser(description="앵박사 AI 에이전트")
    parser.add_argument("--load", action="store_true", help="지식 데이터 적재")
    parser.add_argument("--reset", action="store_true", help="적재 시 기존 데이터 삭제")
    parser.add_argument("--stats", action="store_true", help="적재된 데이터 통계")
    parser.add_argument("--search", type=str, help="벡터 검색 실행")
    parser.add_argument("--ask", type=str, help="단일 질문")
    parser.add_argument("--interactive", action="store_true", help="인터랙티브 채팅")
    parser.add_argument("--benchmark", action="store_true", help="벤치마크 테스트")
    parser.add_argument("--port", type=int, default=8100, help="FastAPI 포트 (기본: 8100)")

    args = parser.parse_args()

    if args.load:
        from knowledge_loader import load_knowledge
        load_knowledge(reset=args.reset)
    elif args.stats:
        cli_stats()
    elif args.search:
        cli_search(args.search)
    elif args.ask:
        cli_ask(args.ask)
    elif args.interactive:
        cli_interactive()
    elif args.benchmark:
        cli_benchmark()
    else:
        # FastAPI 서버 실행
        import uvicorn
        print(f"\n🦜 앵박사 AI 에이전트 서버 시작")
        print(f"   http://localhost:{args.port}")
        print(f"   Swagger UI: http://localhost:{args.port}/docs\n")
        uvicorn.run(app, host="0.0.0.0", port=args.port)


if __name__ == "__main__":
    main()
