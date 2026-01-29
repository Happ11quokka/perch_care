from pydantic import BaseModel
from datetime import date, datetime
from uuid import UUID


class PetCreate(BaseModel):
    name: str
    species: str
    breed: str | None = None
    birth_date: date | None = None
    gender: str | None = None
    growth_stage: str | None = None
    profile_image_url: str | None = None


class PetUpdate(BaseModel):
    name: str | None = None
    species: str | None = None
    breed: str | None = None
    birth_date: date | None = None
    gender: str | None = None
    growth_stage: str | None = None
    profile_image_url: str | None = None
    is_active: bool | None = None


class PetResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    species: str
    breed: str | None = None
    birth_date: date | None = None
    gender: str | None = None
    growth_stage: str | None = None
    profile_image_url: str | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
