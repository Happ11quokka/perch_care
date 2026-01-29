from uuid import UUID
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.models.pet import Pet
from app.schemas.pet import PetCreate, PetUpdate


async def get_my_pets(db: AsyncSession, user_id: UUID) -> list[Pet]:
    result = await db.execute(
        select(Pet).where(Pet.user_id == user_id).order_by(Pet.created_at.desc())
    )
    return list(result.scalars().all())


async def get_active_pet(db: AsyncSession, user_id: UUID) -> Pet | None:
    result = await db.execute(
        select(Pet).where(Pet.user_id == user_id, Pet.is_active == True)
    )
    return result.scalar_one_or_none()


async def get_pet_by_id(db: AsyncSession, pet_id: UUID, user_id: UUID) -> Pet:
    result = await db.execute(select(Pet).where(Pet.id == pet_id, Pet.user_id == user_id))
    pet = result.scalar_one_or_none()
    if not pet:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pet not found")
    return pet


async def create_pet(db: AsyncSession, user_id: UUID, data: PetCreate) -> Pet:
    # Deactivate existing active pets
    await db.execute(
        update(Pet).where(Pet.user_id == user_id, Pet.is_active == True).values(is_active=False)
    )
    pet = Pet(user_id=user_id, **data.model_dump())
    db.add(pet)
    await db.flush()
    return pet


async def update_pet(db: AsyncSession, pet_id: UUID, user_id: UUID, data: PetUpdate) -> Pet:
    pet = await get_pet_by_id(db, pet_id, user_id)
    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(pet, key, value)
    await db.flush()
    return pet


async def delete_pet(db: AsyncSession, pet_id: UUID, user_id: UUID) -> None:
    pet = await get_pet_by_id(db, pet_id, user_id)
    await db.delete(pet)
    await db.flush()


async def set_active_pet(db: AsyncSession, pet_id: UUID, user_id: UUID) -> Pet:
    # Deactivate all
    await db.execute(
        update(Pet).where(Pet.user_id == user_id, Pet.is_active == True).values(is_active=False)
    )
    pet = await get_pet_by_id(db, pet_id, user_id)
    pet.is_active = True
    await db.flush()
    return pet
