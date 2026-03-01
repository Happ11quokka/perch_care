"""
ChromaDB 벡터 검색 래퍼 모듈.

HyDE (Hypothetical Document Embeddings) 지원:
- 사용자의 짧은 질문을 GPT로 가상 답변으로 확장한 뒤 검색
- 한국어/중국어 쿼리도 영문 가상 문서로 변환되어 크로스링구얼 문제 해결
"""

import os
from pathlib import Path

import chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction
from openai import OpenAI

CHROMA_DATA_DIR = Path(__file__).parent / "chroma_data"
COLLECTION_NAME = "parrot_knowledge"
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-large")

HYDE_PROMPT = (
    "You are an expert avian veterinarian. "
    "Given the following question about parrots or companion birds, "
    "write a detailed, factual answer as if it were an excerpt from a veterinary reference document. "
    "Include specific medical terms, species names, symptoms, treatments, or nutritional facts as relevant. "
    "IMPORTANT: Always write your answer in English, regardless of the question's language. "
    "Write 150-300 words.\n\n"
    "Question: {query}\n\n"
    "Detailed reference answer:"
)


def _get_embedding_function() -> OpenAIEmbeddingFunction:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY 환경변수가 설정되지 않았습니다.")
    return OpenAIEmbeddingFunction(
        api_key=api_key,
        model_name=EMBEDDING_MODEL,
    )


def _get_collection():
    client = chromadb.PersistentClient(path=str(CHROMA_DATA_DIR))
    return client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=_get_embedding_function(),
        metadata={"hnsw:space": "cosine"},
    )


def _generate_hypothetical_document(query: str) -> str:
    """HyDE: 사용자 질문에 대한 가상 참고 문서를 GPT로 생성."""
    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "user", "content": HYDE_PROMPT.format(query=query)},
        ],
        temperature=0.0,
        max_tokens=400,
    )
    return response.choices[0].message.content or query


def _build_where_filter(category: str | None, language: str | None) -> dict | None:
    conditions = []
    if category:
        conditions.append({"category": category})
    if language:
        conditions.append({"language": language})
    if len(conditions) == 1:
        return conditions[0]
    elif len(conditions) > 1:
        return {"$and": conditions}
    return None


def _parse_results(results) -> list[dict]:
    items = []
    if results and results["documents"] and results["documents"][0]:
        for i, doc in enumerate(results["documents"][0]):
            metadata = results["metadatas"][0][i] if results["metadatas"] else {}
            distance = results["distances"][0][i] if results["distances"] else 0.0
            similarity = 1.0 - distance
            items.append({
                "content": doc,
                "source": metadata.get("source", ""),
                "category": metadata.get("category", ""),
                "language": metadata.get("language", ""),
                "section_title": metadata.get("section_title", ""),
                "similarity": round(similarity, 4),
            })
    return items


def search(
    query: str,
    top_k: int = 5,
    category: str | None = None,
    language: str | None = None,
    use_hyde: bool = True,
) -> list[dict]:
    """질문과 유사한 지식 청크를 코사인 유사도로 검색.

    use_hyde=True: HyDE로 가상 문서 생성 후 검색 (정확도 높음, +1초 지연)
    use_hyde=False: 원본 쿼리 그대로 검색 (빠름)
    """
    collection = _get_collection()
    where_filter = _build_where_filter(category, language)

    if use_hyde:
        # HyDE: 가상 문서 생성 → 그 문서로 검색
        hypothetical_doc = _generate_hypothetical_document(query)
        results = collection.query(
            query_texts=[hypothetical_doc],
            n_results=top_k,
            where=where_filter,
        )
    else:
        results = collection.query(
            query_texts=[query],
            n_results=top_k,
            where=where_filter,
        )

    return _parse_results(results)


def get_stats() -> dict:
    """적재된 데이터 통계."""
    client = chromadb.PersistentClient(path=str(CHROMA_DATA_DIR))
    try:
        collection = client.get_collection(
            name=COLLECTION_NAME,
            embedding_function=_get_embedding_function(),
        )
    except ValueError:
        return {"total": 0, "by_category": {}, "by_language": {}}

    total = collection.count()
    if total == 0:
        return {"total": 0, "by_category": {}, "by_language": {}}

    # 전체 메타데이터 조회하여 통계 집계
    all_data = collection.get(include=["metadatas"])
    by_category = {}
    by_language = {}
    for meta in all_data["metadatas"]:
        cat = meta.get("category", "unknown")
        lang = meta.get("language", "unknown")
        by_category[cat] = by_category.get(cat, 0) + 1
        by_language[lang] = by_language.get(lang, 0) + 1

    return {
        "total": total,
        "by_category": dict(sorted(by_category.items())),
        "by_language": dict(sorted(by_language.items())),
    }
