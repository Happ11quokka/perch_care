from uuid import UUID
from datetime import datetime, timezone
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.models.ai_chat_session import AiChatSession
from app.models.ai_chat_message import AiChatMessage


async def create_session(
    db: AsyncSession,
    user_id: UUID,
    pet_id: UUID | None,
    first_message: str,
) -> AiChatSession:
    """새 채팅 세션을 생성하고 첫 번째 사용자 메시지를 추가한다."""
    now = datetime.now(timezone.utc)
    title = first_message[:50]

    session = AiChatSession(
        user_id=user_id,
        pet_id=pet_id,
        title=title,
        started_at=now,
        last_message_at=now,
        message_count=1,
    )
    db.add(session)
    await db.flush()

    message = AiChatMessage(
        session_id=session.id,
        role="user",
        content=first_message,
    )
    db.add(message)
    await db.flush()

    return session


async def get_user_sessions(
    db: AsyncSession,
    user_id: UUID,
    limit: int = 50,
) -> list[AiChatSession]:
    """사용자의 채팅 세션 목록을 최근순으로 반환한다."""
    result = await db.execute(
        select(AiChatSession)
        .where(AiChatSession.user_id == user_id)
        .order_by(AiChatSession.last_message_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def get_session_by_id(
    db: AsyncSession,
    session_id: UUID,
    user_id: UUID,
) -> AiChatSession:
    """세션 ID로 조회하며 소유권을 검증한다."""
    result = await db.execute(
        select(AiChatSession).where(
            AiChatSession.id == session_id,
            AiChatSession.user_id == user_id,
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat session not found",
        )
    return session


async def get_session_messages(
    db: AsyncSession,
    session_id: UUID,
    user_id: UUID,
    limit: int = 200,
) -> list[AiChatMessage]:
    """세션의 메시지를 시간순으로 반환한다. 소유권 검증 포함."""
    await get_session_by_id(db, session_id, user_id)

    result = await db.execute(
        select(AiChatMessage)
        .where(AiChatMessage.session_id == session_id)
        .order_by(AiChatMessage.created_at.asc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def add_message(
    db: AsyncSession,
    session_id: UUID,
    user_id: UUID,
    role: str,
    content: str,
    metadata: dict | None = None,
) -> AiChatMessage:
    """세션에 메시지를 추가하고 세션 정보를 갱신한다."""
    session = await get_session_by_id(db, session_id, user_id)

    message = AiChatMessage(
        session_id=session_id,
        role=role,
        content=content,
        metadata_=metadata,
    )
    db.add(message)

    session.last_message_at = datetime.now(timezone.utc)
    session.message_count += 1

    await db.flush()
    return message


async def delete_session(
    db: AsyncSession,
    session_id: UUID,
    user_id: UUID,
) -> None:
    """세션을 삭제한다. 소유권 검증 포함."""
    session = await get_session_by_id(db, session_id, user_id)
    await db.delete(session)
