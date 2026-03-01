from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql+asyncpg://perchcare:perchcare@localhost:5432/perchcare"

    # JWT
    jwt_secret: str = "change-this-secret-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    # OAuth
    google_client_id: str = ""
    apple_client_id: str = ""
    kakao_client_id: str = ""
    kakao_client_secret: str = ""

    # SMTP
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""

    # File upload
    upload_dir: str = "uploads"
    max_upload_size: int = 10 * 1024 * 1024  # 10MB

    # OpenAI
    openai_api_key: str = ""

    # Embedding / Vector Search
    embedding_model: str = "text-embedding-3-large"
    hyde_model: str = "gpt-4o-mini"
    vector_search_top_k: int = 5
    vector_search_min_similarity: float = 0.3

    # LangSmith
    langsmith_api_key: str = ""
    langsmith_project: str = "perch-care"

    # Firebase (FCM push notifications)
    firebase_credentials_json: str = ""

    # Server
    api_v1_prefix: str = "/api/v1"
    cors_origins: list[str] = ["*"]

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
