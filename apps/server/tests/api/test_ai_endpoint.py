from unittest.mock import AsyncMock, patch
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app


@pytest.mark.asyncio
async def test_parse_reminder_bengali_success():
    mock_parsed_data = {
        "title": "ডাক্তারের কাছে যাওয়া",
        "due_at": "2026-11-07T11:00:00Z",
        "category": "MEDICINE",
        "priority": "HIGH",
        "confidence": 0.98,
    }

    with patch(
        "app.services.ai_service.AIService.parse_reminder",
        new_callable=AsyncMock,
    ) as mock_service:
        mock_service.return_value = mock_parsed_data

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            response = await ac.post(
                "/api/v1/ai/parse-reminder",
                json={
                    "text": "কাল বিকাল ৫টায় ডাক্তারের কাছে যেতে হবে",
                    "timezone": "Asia/Dhaka",
                    "reference_date": "2026-11-06T15:00:00Z",
                },
            )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["title"] == "ডাক্তারের কাছে যাওয়া"
        assert data["data"]["category"] == "MEDICINE"
        assert data["data"]["priority"] == "HIGH"
        assert data["data"]["confidence"] == 0.98


@pytest.mark.asyncio
async def test_parse_reminder_missing_api_key_returns_503():
    with patch(
        "app.services.ai_service.AIService.parse_reminder",
        side_effect=RuntimeError("GEMINI_API_KEY is not configured"),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            response = await ac.post(
                "/api/v1/ai/parse-reminder",
                json={"text": "Doctor appointment", "timezone": "UTC"},
            )
        assert response.status_code == 503
        data = response.json()
        assert data["title"] == "AI Service Unavailable"
