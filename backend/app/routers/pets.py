from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.pet import PetCreate, PetUpdate, PetResponse
from app.services import pet_service

router = APIRouter(prefix="/pets", tags=["pets"])


@router.get("/", response_model=list[PetResponse])
async def list_pets(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.get_my_pets(db, current_user.id)


@router.get("/active", response_model=PetResponse | None)
async def get_active_pet(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.get_active_pet(db, current_user.id)


@router.get("/{pet_id}", response_model=PetResponse)
async def get_pet(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.get_pet_by_id(db, pet_id, current_user.id)


@router.post("/", response_model=PetResponse, status_code=201)
async def create_pet(
    request: PetCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.create_pet(db, current_user.id, request)


@router.put("/{pet_id}", response_model=PetResponse)
async def update_pet(
    pet_id: UUID,
    request: PetUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.update_pet(db, pet_id, current_user.id, request)


@router.delete("/{pet_id}", status_code=204)
async def delete_pet(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await pet_service.delete_pet(db, pet_id, current_user.id)


@router.put("/{pet_id}/activate", response_model=PetResponse)
async def activate_pet(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.set_active_pet(db, pet_id, current_user.id)
