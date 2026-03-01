"""
GPT + RAG 컨텍스트 대화 에이전트.
"""

import os
from openai import OpenAI

import vector_store

SYSTEM_PROMPT = (
    "You are Dr. Parrot (앵박사), a board-certified avian veterinarian AI "
    "with extensive knowledge of parrot species, diseases, nutrition, and behavior.\n\n"
    "IMPORTANT: Always respond in the SAME language as the user's message. "
    "If the user writes in Korean, reply in Korean. "
    "If the user writes in Chinese, reply in Chinese. "
    "If the user writes in English, reply in English. "
    "Match the user's language exactly.\n\n"
    "Provide structured, evidence-based answers. "
    "If evidence is uncertain, recommend consulting a veterinarian."
)


def _build_knowledge_context(query: str, top_k: int = 5) -> tuple[str, list[dict]]:
    """질문과 관련된 지식을 검색하여 컨텍스트 텍스트와 소스 리스트 반환."""
    results = vector_store.search(query, top_k=top_k)
    if not results:
        return "", []

    parts = ["[Avian Care Knowledge Base]"]
    for r in results:
        source_label = (
            r["source"].replace("/", " > ").replace("-", " ").replace(".md", "")
        )
        title = r["section_title"] or "General"
        parts.append(f"\n--- {source_label} ({title}) [similarity: {r['similarity']:.2f}] ---")
        parts.append(r["content"])

    return "\n".join(parts), results


def chat(
    query: str,
    history: list[dict] | None = None,
    model: str = "gpt-4o-mini",
    max_tokens: int = 1024,
    temperature: float = 0.2,
    top_k: int = 5,
) -> tuple[str, list[dict]]:
    """RAG 컨텍스트를 활용한 GPT 대화. (응답, 소스 리스트) 반환."""
    if history is None:
        history = []

    # 지식 검색
    knowledge_context, sources = _build_knowledge_context(query, top_k=top_k)

    # 시스템 프롬프트 조합
    system_parts = [SYSTEM_PROMPT]
    if knowledge_context:
        system_parts.append(
            f"\n\n{knowledge_context}\n\n"
            "Use the knowledge base information above to provide accurate, "
            "evidence-based answers. Cite specific details from the knowledge base when relevant. "
            "Do not make up information not supported by the knowledge base."
        )

    system_message = "".join(system_parts)

    # 메시지 구성
    messages = [{"role": "system", "content": system_message}]
    for h in history:
        role = h.get("role", "user")
        content = h.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": query})

    # GPT 호출
    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    response = client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=temperature,
        max_tokens=max_tokens,
    )

    answer = response.choices[0].message.content or "답변을 생성하지 못했습니다."
    return answer, sources
