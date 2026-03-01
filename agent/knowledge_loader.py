"""
knowledge 마크다운 파일을 청킹하여 ChromaDB에 적재하는 모듈.
"""

import os
import time
from pathlib import Path

import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

from chunker import parse_markdown_into_chunks, discover_knowledge_files

# 프로젝트 루트 (agent/ 의 상위)
PROJECT_ROOT = Path(__file__).parent.parent
CHROMA_DATA_DIR = Path(__file__).parent / "chroma_data"
COLLECTION_NAME = "parrot_knowledge"

KNOWLEDGE_DIRS = [
    {"path": PROJECT_ROOT / "knowledge", "language": "en"},
    {"path": PROJECT_ROOT / "knowledge-zh", "language": "zh"},
]


def get_embedding_function() -> OpenAIEmbeddingFunction:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY 환경변수가 설정되지 않았습니다.")
    return OpenAIEmbeddingFunction(
        api_key=api_key,
        model_name="text-embedding-3-large",
    )


def get_chroma_client() -> chromadb.PersistentClient:
    return chromadb.PersistentClient(path=str(CHROMA_DATA_DIR))


def get_collection(client: chromadb.PersistentClient, embedding_fn=None):
    if embedding_fn is None:
        embedding_fn = get_embedding_function()
    return client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=embedding_fn,
        metadata={"hnsw:space": "cosine"},
    )


def load_knowledge(reset: bool = False) -> dict:
    """knowledge 디렉토리의 모든 마크다운 파일을 청킹하여 ChromaDB에 적재."""
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent / ".env")

    client = get_chroma_client()
    embedding_fn = get_embedding_function()

    if reset:
        try:
            client.delete_collection(COLLECTION_NAME)
            print("기존 컬렉션 삭제 완료.")
        except ValueError:
            pass

    collection = get_collection(client, embedding_fn)

    # 기존 데이터 확인
    existing_count = collection.count()
    if existing_count > 0 and not reset:
        print(f"이미 {existing_count}개 청크가 적재되어 있습니다. --reset 옵션으로 재적재하세요.")
        return {"status": "already_loaded", "count": existing_count}

    all_chunks = []
    file_count = 0
    stats = {"by_category": {}, "by_language": {"en": 0, "zh": 0}}

    for kdir in KNOWLEDGE_DIRS:
        knowledge_path = kdir["path"]
        language = kdir["language"]

        if not knowledge_path.exists():
            print(f"경고: {knowledge_path} 디렉토리가 없습니다. 스킵.")
            continue

        files = discover_knowledge_files(knowledge_path)
        print(f"\n📂 {knowledge_path.name}/ — {len(files)}개 파일 발견 (language={language})")

        for file_info in files:
            content = file_info["path"].read_text(encoding="utf-8")
            chunks = parse_markdown_into_chunks(
                content=content,
                source=file_info["source"],
                category=file_info["category"],
                language=language,
            )

            for chunk in chunks:
                all_chunks.append(chunk)
                cat = chunk["category"]
                stats["by_category"][cat] = stats["by_category"].get(cat, 0) + 1
                stats["by_language"][language] += 1

            file_count += 1
            if file_count % 50 == 0:
                print(f"  ... {file_count}개 파일 처리 완료")

    if not all_chunks:
        print("적재할 청크가 없습니다.")
        return {"status": "empty", "count": 0}

    # ChromaDB에 배치 삽입 (ChromaDB가 자동으로 임베딩 생성)
    print(f"\n총 {len(all_chunks)}개 청크를 ChromaDB에 적재 중...")
    start_time = time.time()

    batch_size = 100
    for i in range(0, len(all_chunks), batch_size):
        batch = all_chunks[i : i + batch_size]
        ids = [f"chunk_{i + j}" for j in range(len(batch))]
        documents = [c["content"] for c in batch]
        metadatas = [
            {
                "source": c["source"],
                "category": c["category"],
                "language": c["language"],
                "section_title": c["section_title"] or "",
            }
            for c in batch
        ]
        collection.add(ids=ids, documents=documents, metadatas=metadatas)
        print(f"  ... {min(i + batch_size, len(all_chunks))}/{len(all_chunks)} 적재 완료")

    elapsed = time.time() - start_time
    print(f"\n적재 완료! ({elapsed:.1f}초)")
    print(f"  파일: {file_count}개")
    print(f"  청크: {len(all_chunks)}개")
    print(f"\n카테고리별:")
    for cat, count in sorted(stats["by_category"].items()):
        print(f"  {cat}: {count}개")
    print(f"\n언어별:")
    for lang, count in stats["by_language"].items():
        print(f"  {lang}: {count}개")

    return {
        "status": "loaded",
        "count": len(all_chunks),
        "files": file_count,
        "stats": stats,
        "elapsed_seconds": elapsed,
    }


if __name__ == "__main__":
    import sys
    reset = "--reset" in sys.argv
    load_knowledge(reset=reset)
