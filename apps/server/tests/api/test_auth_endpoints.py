from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4
import pytest
from httpx import ASGITransport, AsyncClient
from app.core.rate_limit import auth_rate_limiter
from app.core.security import hash_password
from app.db.session import get_db
from app.main import app
from app.models.user import PlanTier, User


@pytest.mark.asyncio
async def test_auth_register_and_login_flow():
    user_id = uuid4()
    mock_db = AsyncMock()
    # First select returns None (no existing email)
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_db
    auth_rate_limiter.clients.clear()

    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            # 1. Register
            reg_res = await ac.post(
                "/api/v1/auth/register",
                json={
                    "email": "newuser@pingo.app",
                    "password": "StrongPassword123!",
                    "client_salt": "random_client_salt_123456",
                },
            )
            assert reg_res.status_code == 201
            reg_data = reg_res.json()
            assert "access_token" in reg_data
            assert reg_data["email"] == "newuser@pingo.app"
            assert reg_data["client_salt"] == "random_client_salt_123456"

            token = reg_data["access_token"]

            # Mock user found for login
            existing_user = User(
                id=user_id,
                email="newuser@pingo.app",
                password_hash=hash_password("StrongPassword123!"),
                client_salt="random_client_salt_123456",
                plan_tier=PlanTier.FREE,
            )
            mock_login_result = MagicMock()
            mock_login_result.scalar_one_or_none.return_value = existing_user
            mock_db.execute.return_value = mock_login_result

            # 2. Login
            login_res = await ac.post(
                "/api/v1/auth/login",
                json={
                    "email": "newuser@pingo.app",
                    "password": "StrongPassword123!",
                },
            )
            assert login_res.status_code == 200
            assert "access_token" in login_res.json()

            # 3. Get profile /me
            me_res = await ac.get(
                "/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert me_res.status_code == 200
            me_data = me_res.json()
            assert me_data["email"] == "newuser@pingo.app"
            assert me_data["plan_tier"] == "FREE"
    finally:
        app.dependency_overrides.clear()
        auth_rate_limiter.clients.clear()


@pytest.mark.asyncio
async def test_auth_login_nonexistent_user_returns_401():
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_db
    auth_rate_limiter.clients.clear()

    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            res = await ac.post(
                "/api/v1/auth/login",
                json={
                    "email": "nonexistent@pingo.app",
                    "password": "RandomPassword123!",
                },
            )
            assert res.status_code == 401
            assert res.json()["detail"] == "Incorrect email or password."
    finally:
        app.dependency_overrides.clear()
        auth_rate_limiter.clients.clear()


@pytest.mark.asyncio
async def test_auth_rate_limiting_triggered():
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    async def override_db():
        yield mock_db

    app.dependency_overrides[get_db] = override_db
    auth_rate_limiter.clients.clear()

    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            # auth_rate_limiter limit is 10/min
            for _ in range(10):
                res = await ac.post(
                    "/api/v1/auth/login",
                    json={
                        "email": "attempt@pingo.app",
                        "password": "WrongPassword123!",
                    },
                )
                assert res.status_code == 401

            # 11th request should trigger 429
            rate_limited_res = await ac.post(
                "/api/v1/auth/login",
                json={
                    "email": "attempt@pingo.app",
                    "password": "WrongPassword123!",
                },
            )
            assert rate_limited_res.status_code == 429
            assert rate_limited_res.json()["title"] == "Rate Limit Exceeded"
    finally:
        app.dependency_overrides.clear()
        auth_rate_limiter.clients.clear()
