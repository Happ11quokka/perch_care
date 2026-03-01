"""
Knowledge loading script — chunks markdown files and loads them into pgvector.

Usage:
    cd backend
    python -m scripts.load_knowledge              # Load (skip existing)
    python -m scripts.load_knowledge --reset       # Truncate and reload all

    # Against Railway DB (set DATABASE_URL env var)
    DATABASE_URL=postgresql+asyncpg://... python -m scripts.load_knowledge --reset
"""
import argparse
import asyncio
import hashlib
import logging
import sys
import time
from pathlib import Path

# Add agent/ to path for chunker import
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "agent"))

from chunker import parse_markdown_into_chunks, discover_knowledge_files  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")
logger = logging.getLogger(__name__)

KNOWLEDGE_DIRS = [
    {"path": PROJECT_ROOT / "knowledge", "language": "en"},
    {"path": PROJECT_ROOT / "knowledge-zh", "language": "zh"},
]

EMBEDDING_BATCH_SIZE = 100
DB_INSERT_BATCH_SIZE = 50


async def load_knowledge(reset: bool = False) -> dict:
    """Main loading function."""
    from app.config import get_settings
    from app.database import async_session_factory
    from app.services.embedding_service import create_embeddings_batch

    get_settings()  # ensure settings are loaded

    # Step 1: Chunk all knowledge files
    logger.info("Step 1: Chunking knowledge files...")
    all_chunks: list[dict] = []
    file_count = 0

    for kdir in KNOWLEDGE_DIRS:
        knowledge_path = kdir["path"]
        language = kdir["language"]

        if not knowledge_path.exists():
            logger.warning(f"  Directory not found: {knowledge_path}")
            continue

        files = discover_knowledge_files(knowledge_path)
        logger.info(f"  {knowledge_path.name}/ — {len(files)} files (language={language})")

        for file_info in files:
            content = file_info["path"].read_text(encoding="utf-8")
            chunks = parse_markdown_into_chunks(
                content=content,
                source=file_info["source"],
                category=file_info["category"],
                language=language,
            )
            all_chunks.extend(chunks)
            file_count += 1

    if not all_chunks:
        logger.error("No chunks to load.")
        return {"status": "empty", "count": 0}

    logger.info(f"  Total: {len(all_chunks)} chunks from {file_count} files")

    # Compute content hashes for idempotent loading (language+source+content로 고유성 보장)
    for chunk in all_chunks:
        hash_input = f"{chunk['language']}:{chunk['source']}:{chunk['content']}"
        chunk["chunk_hash"] = hashlib.sha256(hash_input.encode("utf-8")).hexdigest()

    # Step 2: Reset if requested
    if reset:
        logger.info("Step 2: Resetting knowledge_chunks table...")
        async with async_session_factory() as db:
            from sqlalchemy import text
            await db.execute(text("TRUNCATE knowledge_chunks"))
            await db.commit()
        logger.info("  Table truncated.")
    else:
        logger.info("Step 2: Skipped reset (use --reset to truncate first)")

    # Step 3: Batch embed
    logger.info("Step 3: Creating embeddings...")
    start_time = time.time()

    all_embeddings: list[list[float]] = []
    for i in range(0, len(all_chunks), EMBEDDING_BATCH_SIZE):
        batch_texts = [c["content"] for c in all_chunks[i : i + EMBEDDING_BATCH_SIZE]]
        batch_embeddings = await create_embeddings_batch(batch_texts)
        all_embeddings.extend(batch_embeddings)
        done = min(i + EMBEDDING_BATCH_SIZE, len(all_chunks))
        logger.info(f"  Embedded {done}/{len(all_chunks)}")

    embed_time = time.time() - start_time
    logger.info(f"  Embedding complete in {embed_time:.1f}s")

    # Step 4: Batch insert into pgvector
    logger.info("Step 4: Inserting into database...")
    insert_start = time.time()
    inserted = 0

    async with async_session_factory() as db:
        from sqlalchemy import text

        for i in range(0, len(all_chunks), DB_INSERT_BATCH_SIZE):
            batch = all_chunks[i : i + DB_INSERT_BATCH_SIZE]
            batch_embs = all_embeddings[i : i + DB_INSERT_BATCH_SIZE]

            params_list = [
                {
                    "content": chunk["content"],
                    "embedding": str(embedding),
                    "source": chunk["source"],
                    "category": chunk["category"],
                    "language": chunk["language"],
                    "section_title": chunk["section_title"] or "",
                    "chunk_hash": chunk["chunk_hash"],
                }
                for chunk, embedding in zip(batch, batch_embs)
            ]
            await db.execute(
                text("""
                    INSERT INTO knowledge_chunks
                        (content, embedding, source, category, language,
                         section_title, chunk_hash)
                    VALUES
                        (:content, :embedding::vector, :source, :category,
                         :language, :section_title, :chunk_hash)
                    ON CONFLICT (chunk_hash) DO UPDATE SET
                        content = EXCLUDED.content,
                        embedding = EXCLUDED.embedding,
                        source = EXCLUDED.source,
                        category = EXCLUDED.category,
                        language = EXCLUDED.language,
                        section_title = EXCLUDED.section_title
                """),
                params_list,
            )
            inserted += len(params_list)

            await db.commit()
            done = min(i + DB_INSERT_BATCH_SIZE, len(all_chunks))
            logger.info(f"  Inserted {done}/{len(all_chunks)}")

    insert_time = time.time() - insert_start
    total_time = time.time() - start_time

    logger.info("")
    logger.info("Loading complete!")
    logger.info(f"  Files:          {file_count}")
    logger.info(f"  Chunks:         {len(all_chunks)}")
    logger.info(f"  Inserted/Updated: {inserted}")
    logger.info(f"  Embedding time: {embed_time:.1f}s")
    logger.info(f"  Insert time:    {insert_time:.1f}s")
    logger.info(f"  Total time:     {total_time:.1f}s")

    return {
        "status": "loaded",
        "count": len(all_chunks),
        "files": file_count,
        "embed_seconds": round(embed_time, 1),
        "insert_seconds": round(insert_time, 1),
        "total_seconds": round(total_time, 1),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load knowledge into pgvector")
    parser.add_argument("--reset", action="store_true", help="Truncate and reload all data")
    args = parser.parse_args()

    result = asyncio.run(load_knowledge(reset=args.reset))
    logger.info(f"\nResult: {result}")
