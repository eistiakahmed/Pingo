import pytest
from app.core.config import Settings

def test_settings_load_defaults(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://pingo:secret@localhost:5432/pingo_db")
    monkeypatch.setenv("GEMINI_API_KEY", "test-gemini-key")
    settings = Settings()
    assert settings.APP_NAME == "Pingo API Gateway"
    assert settings.API_V1_PREFIX == "/api/v1"
    assert settings.DATABASE_URL == "postgresql+asyncpg://pingo:secret@localhost:5432/pingo_db"
    assert settings.GEMINI_API_KEY == "test-gemini-key"
    assert settings.PORT == 8000
