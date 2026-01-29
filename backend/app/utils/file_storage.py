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


def delete_upload_file(file_url: str) -> bool:
    if file_url.startswith("/uploads/"):
        file_path = os.path.join(settings.upload_dir, file_url.lstrip("/uploads/"))
        if os.path.exists(file_path):
            os.remove(file_path)
            return True
    return False
