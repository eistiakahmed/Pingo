from functools import lru_cache
from typing import List, Union
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    APP_NAME: str = "Pingo API Gateway"
    APP_ENV: str = "development"
    PORT: int = 8000
    HOST: str = "0.0.0.0"
    API_V1_PREFIX: str = "/api/v1"

    # Database
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://pingo:secret@localhost:5432/pingo_db",
        description="Async PostgreSQL connection string with asyncpg",
    )
    ECHO_SQL: bool = Field(
        default=False,
        description="Whether to log SQL queries to stdout (disabled by default to prevent credential leakage)",
    )

    # AI Configuration
    AI_PROVIDER: str = Field(
        default="deepseek",
        description="Active AI Provider: 'deepseek' or 'gemini'",
    )
    DEEPSEEK_API_KEY: str = Field(
        default="",
        description="DeepSeek API key for natural language processing",
    )
    DEEPSEEK_BASE_URL: str = Field(
        default="https://api.deepseek.com",
        description="DeepSeek API Base URL",
    )
    DEEPSEEK_MODEL: str = Field(
        default="deepseek-chat",
        description="DeepSeek model name (e.g. deepseek-chat)",
    )
    GEMINI_API_KEY: str = Field(
        default="",
        description="Google Gemini API key for natural language processing",
    )

    # Security
    SECRET_KEY: str = Field(
        default="pingo-default-development-secret-key-replace-in-production-32b",
        description="Secret key for cryptographic and session verification",
    )
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v  # type: ignore[return-value]
        raise ValueError(v)


@lru_cache()
def get_settings() -> Settings:
    """Returns singleton cached instance of application settings."""
    return Settings()
