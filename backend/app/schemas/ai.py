from pydantic import BaseModel, Field


class AiEncyclopediaRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=2000)
    history: list[dict[str, str]] = Field(default_factory=list)
    pet_id: str | None = None
    temperature: float = Field(default=0.2, ge=0.0, le=2.0)
    max_tokens: int = Field(default=512, ge=1, le=4096)
    pet_profile_context: str | None = None


class AiEncyclopediaResponse(BaseModel):
    answer: str
