from unittest.mock import AsyncMock, patch
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
        email="auth_user@pingo.app",
        password_hash="argon2id$hashed",
        plan_tier=PlanTier.FREE,
        client_salt="mock_salt_12345",
    )
    async def override_db():
        yield AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = override_db
    yield user
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_sync_push_success(mock_authenticated_user):
    mock_push_result = {
        "success": True,
        "applied_count": 1,
        "server_timestamp": "2026-11-06T15:00:00Z",
    }

    with patch(
        "app.services.sync_service.SyncService.apply_push",
        new_callable=AsyncMock,
    ) as mock_sync:
        mock_sync.return_value = mock_push_result

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            response = await ac.post(
                "/api/v1/sync/push",
                headers={"Authorization": "Bearer fake-token"},
                json={
                    "reminders": [
                        {
                            "id": str(uuid4()),
                            "ciphertext": "ZXhhbXBsZWNpcGhlcnRleHQ=",
                            "iv": "MDEyMzQ1Njc4OWFi",
                            "auth_tag": "YWJjZGVmZ2hpamtsbW5vcA==",
                            "key_version": 1,
                            "algorithm": "AES-256-GCM",
                            "is_completed": False,
                            "version": 1,
                        }
                    ],
                    "vault_items": [],
                },
            )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["applied_count"] == 1


@pytest.mark.asyncio
async def test_sync_pull_success(mock_authenticated_user):
    mock_pull_result = {
        "reminders": [],
        "vault_items": [],
        "server_timestamp": "2026-11-06T15:00:00Z",
    }

    with patch(
        "app.services.sync_service.SyncService.pull_delta",
        new_callable=AsyncMock,
    ) as mock_pull:
        mock_pull.return_value = mock_pull_result

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            response = await ac.get(
                "/api/v1/sync/pull",
                headers={"Authorization": "Bearer fake-token"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "reminders" in data
        assert "server_timestamp" in data


@pytest.mark.asyncio
async def test_sync_unauthorized_without_token():
    app.dependency_overrides.clear()
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        response = await ac.get("/api/v1/sync/pull")
    assert response.status_code == 401
    assert response.json()["title"] == "Unauthorized"
