import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_rfc7807_validation_error_format():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Request non-existent or invalid payload
        response = await ac.post("/api/v1/invalid", json={"not": "valid"})
    assert response.status_code in (404, 422)
    data = response.json()
    assert "title" in data
    assert "status" in data

