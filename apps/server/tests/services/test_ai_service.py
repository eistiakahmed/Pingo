from datetime import datetime, timezone
import json
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from app.core.exceptions import AppException
from app.schemas.ai import ParseReminderRequest, ReminderCategory, ReminderPriority
from app.services.ai_service import AIService


@pytest.mark.asyncio
async def test_ai_service_deepseek_call(monkeypatch):
    monkeypatch.setenv("AI_PROVIDER", "deepseek")
    monkeypatch.setenv("DEEPSEEK_API_KEY", "mock-deepseek-key")
    from app.core import config
    config.get_settings.cache_clear()

    mock_json_content = json.dumps({
        "title": "ডাক্তারের প্রেসক্রিপশন ও ওষুধ কেনা",
        "due_at": "2026-11-08T04:00:00Z",
        "category": "MEDICINE",
        "priority": "HIGH",
        "confidence": 0.98,
    })

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "choices": [
            {
                "message": {
                    "content": mock_json_content,
                }
            }
        ]
    }

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_resp

        req = ParseReminderRequest(
            text="কাল সকাল ১০টায় ডাক্তারের প্রেসক্রিপশন অনুযায়ী ওষুধ কিনতে হবে",
            timezone="Asia/Dhaka",
            reference_date=datetime(2026, 11, 7, 4, 0, 0, tzinfo=timezone.utc),
        )

        result = await AIService.parse_reminder(req)

        assert result.title == "ডাক্তারের প্রেসক্রিপশন ও ওষুধ কেনা"
        assert result.category == ReminderCategory.MEDICINE
        assert result.priority == ReminderPriority.HIGH
        assert result.confidence == 0.98
        assert mock_post.called


@pytest.mark.asyncio
async def test_ai_service_deepseek_missing_api_key_raises_app_exception(monkeypatch):
    monkeypatch.setenv("AI_PROVIDER", "deepseek")
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    from app.core import config
    config.get_settings.cache_clear()

    req = ParseReminderRequest(text="Meeting tomorrow at 3pm", timezone="UTC")
    with pytest.raises(AppException) as exc_info:
        await AIService.parse_reminder(req)

    assert exc_info.value.status_code == 503
    assert "DEEPSEEK_API_KEY is not configured" in exc_info.value.detail


@pytest.mark.asyncio
async def test_ai_service_gemini_call(monkeypatch):
    monkeypatch.setenv("AI_PROVIDER", "gemini")
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
