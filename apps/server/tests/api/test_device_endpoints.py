from unittest.mock import AsyncMock
from uuid import uuid4
import pytest
from httpx import ASGITransport, AsyncClient
from app.core.security import get_current_user
from app.db.session import get_db
from app.main import app
from app.models.user import PlanTier, User


@pytest.fixture
def mock_authenticated_user():
    user = User(
        id=uuid4(),
        email="device_user@pingo.app",
        password_hash="argon2id$hashed",
        plan_tier=PlanTier.FREE,
        client_salt="mock_salt_12345",
    )

    async def override_db():
        mock_session = AsyncMock()
        # Mock execute returning no existing token
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result
        yield mock_session

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = override_db
    yield user
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_register_device_token_success(mock_authenticated_user):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        response = await ac.post(
            "/api/v1/devices/register-token",
            headers={"Authorization": "Bearer fake-token"},
            json={
                "token": "eX_dummy_fcm_token_1234567890",
                "platform": "android",
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["message"] == "Device token registered successfully"
