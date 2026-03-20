import os
import uuid
import aiofiles
from fastapi import UploadFile
from app.config import get_settings

settings = get_settings()


async def save_upload_file(file: UploadFile, user_id: str, sub_dir: str = "health-check-images") -> str:
    dir_path = os.path.join(settings.upload_dir, sub_dir, user_id)
    os.makedirs(dir_path, exist_ok=True)

    ext = os.path.splitext(file.filename)[1] if file.filename else ".jpg"
    filename = f"{uuid.uuid4()}{ext}"
    file_path = os.path.join(dir_path, filename)

    async with aiofiles.open(file_path, "wb") as f:
        content = await file.read()
        if len(content) > settings.max_upload_size:
            raise ValueError(f"File size exceeds {settings.max_upload_size} bytes")
        await f.write(content)

    return f"/uploads/{sub_dir}/{user_id}/{filename}"


async def save_image_bytes(
    image_bytes: bytes,
    user_id: str,
    ext: str = ".jpg",
    sub_dir: str = "health-check-images",
) -> str:
    """Raw bytes를 직접 디스크에 저장한다 (analyze에서 이미 read()한 bytes용)."""
    dir_path = os.path.join(settings.upload_dir, sub_dir, user_id)
    os.makedirs(dir_path, exist_ok=True)

    filename = f"{uuid.uuid4()}{ext}"
    file_path = os.path.join(dir_path, filename)

    async with aiofiles.open(file_path, "wb") as f:
        await f.write(image_bytes)

    return f"/uploads/{sub_dir}/{user_id}/{filename}"


def delete_upload_file(file_url: str) -> bool:
    """업로드 파일을 URL 경로로 삭제한다.

    Returns True if deleted, False if URL invalid or file missing.
    Raises on I/O errors (permission, etc.) so caller can decide retry.
    """
    if not file_url.startswith("/uploads/"):
        return False
    relative_path = file_url.removeprefix("/uploads/")
    file_path = os.path.join(settings.upload_dir, relative_path)
    if not os.path.exists(file_path):
        return False
    os.remove(file_path)
    return True
