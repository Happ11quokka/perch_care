from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.ai import AiEncyclopediaRequest, AiEncyclopediaResponse
from app.services import ai_service

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/encyclopedia", response_model=AiEncyclopediaResponse)
async def encyclopedia(
    body: AiEncyclopediaRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    answer = await ai_service.ask(
        db=db,
        query=body.query,
        history=body.history,
        pet_id=body.pet_id,
        pet_profile_context=body.pet_profile_context,
        temperature=body.temperature,
        max_tokens=body.max_tokens,
    )
    return AiEncyclopediaResponse(answer=answer)
