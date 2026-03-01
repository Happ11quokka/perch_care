"""
Embedding service — OpenAI text-embedding-3-large + HyDE hypothetical document generation.

Reuses proven HyDE prompt from agent/vector_store.py.
"""
import logging

from openai import AsyncOpenAI

from app.config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()

_openai_client = AsyncOpenAI(api_key=settings.openai_api_key)

# Proven HyDE prompt — identical to agent/vector_store.py
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


async def create_embedding(text: str) -> list[float]:
    """Create a single embedding vector using text-embedding-3-large."""
    response = await _openai_client.embeddings.create(
        model=settings.embedding_model,
        input=text,
    )
    return response.data[0].embedding


async def create_embeddings_batch(texts: list[str]) -> list[list[float]]:
    """Create embeddings for a batch of texts (max 2048 per call)."""
    response = await _openai_client.embeddings.create(
        model=settings.embedding_model,
        input=texts,
    )
    sorted_data = sorted(response.data, key=lambda x: x.index)
    return [d.embedding for d in sorted_data]


async def generate_hypothetical_document(query: str) -> str:
    """HyDE: Generate a hypothetical English reference document for the query.

    Used to improve cross-lingual vector search accuracy.
    Falls back to original query on failure.
    """
    try:
        response = await _openai_client.chat.completions.create(
            model=settings.hyde_model,
            messages=[
                {"role": "user", "content": HYDE_PROMPT.format(query=query)},
            ],
            temperature=0.0,
            max_tokens=400,
        )
        result = response.choices[0].message.content
        return result if result else query
    except Exception as e:
        logger.warning(f"HyDE generation failed, falling back to original query: {e}")
        return query
