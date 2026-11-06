from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from app.schemas.ai import ParseReminderRequest, ReminderCategory, ReminderPriority
from app.services.ai_service import AIService


@pytest.mark.asyncio
async def test_ai_service_gemini_call(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "mock-key")
    from app.core import config
    config.get_settings.cache_clear()

    mock_response = MagicMock()
    mock_response.text = (
        '{"title": "Team Daily Sync", "due_at": "2026-11-07T04:00:00Z", '
        '"category": "WORK", "priority": "NORMAL", "confidence": 0.95}'
    )

    with patch("google.genai.Client") as mock_client_cls:
        mock_client = MagicMock()
        mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)
        mock_client_cls.return_value = mock_client

        req = ParseReminderRequest(
            text="Team daily sync tomorrow at 10 AM",
            timezone="Asia/Dhaka",
            reference_date=datetime(2026, 11, 6, 10, 0, 0, tzinfo=timezone.utc),
        )
        result = await AIService.parse_reminder(req)

        assert result.title == "Team Daily Sync"
        assert result.category == ReminderCategory.WORK
        assert result.priority == ReminderPriority.NORMAL
        assert result.confidence == 0.95

