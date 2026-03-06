from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.breed_standard import BreedStandard
from app.schemas.breed_standard import BreedStandardListItem, WeightRangeInfo


async def get_all_breeds(db: AsyncSession, locale: str = 'en') -> list[BreedStandardListItem]:
    """Get all active breeds with localized display names."""
    result = await db.execute(
        select(BreedStandard)
        .where(BreedStandard.is_active == True)
        .order_by(BreedStandard.species_category, BreedStandard.breed_name_en)
    )
    breeds = result.scalars().all()
    return [
        BreedStandardListItem(
            id=b.id,
            display_name=_get_localized_name(b, locale),
            species_category=b.species_category,
            breed_variant=b.breed_variant,
            weight_min_g=b.weight_min_g,
            weight_ideal_min_g=b.weight_ideal_min_g,
            weight_ideal_max_g=b.weight_ideal_max_g,
            weight_max_g=b.weight_max_g,
        )
        for b in breeds
    ]


async def get_breed_by_id(db: AsyncSession, breed_id: UUID) -> BreedStandard | None:
    result = await db.execute(select(BreedStandard).where(BreedStandard.id == breed_id))
    return result.scalar_one_or_none()


async def get_breed_by_id_localized(db: AsyncSession, breed_id: UUID, locale: str = 'en') -> BreedStandardListItem | None:
    """Get single breed with localized display name (same shape as list endpoint)."""
    breed = await get_breed_by_id(db, breed_id)
    if breed is None:
        return None
    return BreedStandardListItem(
        id=breed.id,
        display_name=_get_localized_name(breed, locale),
        species_category=breed.species_category,
        breed_variant=breed.breed_variant,
        weight_min_g=breed.weight_min_g,
        weight_ideal_min_g=breed.weight_ideal_min_g,
        weight_ideal_max_g=breed.weight_ideal_max_g,
        weight_max_g=breed.weight_max_g,
    )


def _get_localized_name(breed: BreedStandard, locale: str) -> str:
    locale_map = {
        'ko': breed.breed_name_ko,
        'zh': breed.breed_name_zh,
        'en': breed.breed_name_en,
    }
    name = locale_map.get(locale, breed.breed_name_en)
    if breed.breed_variant:
        return f"{name} ({breed.breed_variant})"
    return name


def calculate_absolute_weight_score(current_weight: float, breed: BreedStandard) -> float:
    """
    Calculate weight score (0-60) based on breed standard ranges.
    - In ideal range: 60 points
    - Between min/ideal_min or ideal_max/max: linearly reduced
    - Outside min/max: 0 points
    """
    if current_weight < breed.weight_min_g or current_weight > breed.weight_max_g:
        return 0.0

    if breed.weight_ideal_min_g <= current_weight <= breed.weight_ideal_max_g:
        return 60.0

    if current_weight < breed.weight_ideal_min_g:
        span = breed.weight_ideal_min_g - breed.weight_min_g
        if span <= 0:
            return 0.0
        ratio = (current_weight - breed.weight_min_g) / span
        return 60.0 * ratio

    # above ideal, below max
    span = breed.weight_max_g - breed.weight_ideal_max_g
    if span <= 0:
        return 0.0
    ratio = (breed.weight_max_g - current_weight) / span
    return 60.0 * ratio


def get_weight_position(current_weight: float, breed: BreedStandard) -> WeightRangeInfo:
    """Return weight range info with position and percentage."""
    total_range = breed.weight_max_g - breed.weight_min_g
    if total_range <= 0:
        pct = 50.0
    elif current_weight < breed.weight_min_g:
        pct = 0.0
    elif current_weight > breed.weight_max_g:
        pct = 100.0
    else:
        pct = (current_weight - breed.weight_min_g) / total_range * 100

    if current_weight < breed.weight_min_g:
        position = "below_min"
    elif current_weight < breed.weight_ideal_min_g:
        position = "below_ideal"
    elif current_weight <= breed.weight_ideal_max_g:
        position = "in_ideal"
    elif current_weight <= breed.weight_max_g:
        position = "above_ideal"
    else:
        position = "above_max"

    return WeightRangeInfo(
        min_g=breed.weight_min_g,
        ideal_min_g=breed.weight_ideal_min_g,
        ideal_max_g=breed.weight_ideal_max_g,
        max_g=breed.weight_max_g,
        current_position=position,
        current_percentage=round(pct, 1),
    )
