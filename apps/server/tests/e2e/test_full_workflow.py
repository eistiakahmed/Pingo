from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4
import pytest
from httpx import ASGITransport, AsyncClient
from app.core.security import create_access_token, get_current_user
from app.db.session import get_db
from app.main import app
from app.models.user import PlanTier, User
from e2ee.aes_gcm import decrypt_aes_gcm, encrypt_aes_gcm
from e2ee.envelope import EncryptedEnvelope
from e2ee.kdf import derive_key_pbkdf2


@pytest.mark.asyncio
async def test_complete_e2e_workflow():
    user_id = uuid4()
    mock_user = User(
        id=user_id,
        email="e2e_user@pingo.app",
        password_hash="hashed_pw",
        client_salt="mock_salt_12345",
        plan_tier=PlanTier.FREE,
    )

    mock_session = AsyncMock()
    mock_session.add = MagicMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_session.execute.return_value = mock_result

    app.dependency_overrides[get_db] = lambda: mock_session
    app.dependency_overrides[get_current_user] = lambda: mock_user

    token = create_access_token(user_id=user_id, email="e2e_user@pingo.app")

    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as ac:
            # 1. Health & Root Index
            root_res = await ac.get("/")
            assert root_res.status_code == 200
            assert root_res.json()["docs"] == "/docs"

            health_res = await ac.get("/health")
            assert health_res.status_code == 200
            assert health_res.json()["status"] == "healthy"

            # 2. OpenAPI Schema Verification
            openapi_res = await ac.get("/openapi.json")
            assert openapi_res.status_code == 200
            paths = openapi_res.json()["paths"]
            assert "/health" in paths
            assert "/api/v1/auth/register" in paths
            assert "/api/v1/auth/login" in paths
            assert "/api/v1/ai/parse-reminder" in paths
            assert "/api/v1/sync/push" in paths
            assert "/api/v1/sync/pull" in paths

            # 3. Client E2EE Encryption & Server Sync Simulation
            client_passphrase = "my-secret-vault-pin"
            client_salt = b"random_salt_16_b"
            client_key = derive_key_pbkdf2(client_passphrase, client_salt)

            plain_text = "ডাক্তারের প্রেসক্রিপশন: নাপা এক্সট্রা দিনে ২ বার"
            envelope = encrypt_aes_gcm(plain_text, client_key, key_version=1)

            reminder_id = uuid4()

            # Push to server with Bearer auth
            push_payload = {
                "reminders": [
                    {
                        "id": str(reminder_id),
                        "ciphertext": envelope.ciphertext,
                        "iv": envelope.iv,
                        "auth_tag": envelope.auth_tag,
                        "key_version": envelope.key_version,
                        "algorithm": envelope.algorithm,
                        "is_completed": False,
                        "version": 1,
                    }
                ],
                "vault_items": [],
            }

            push_res = await ac.post(
                "/api/v1/sync/push",
                headers={"Authorization": f"Bearer {token}"},
                json=push_payload,
            )
            assert push_res.status_code == 200
            assert push_res.json()["success"] is True

            # Verify client can decrypt its own envelope
            reconstructed_envelope = EncryptedEnvelope(
                ciphertext=envelope.ciphertext,
                iv=envelope.iv,
                auth_tag=envelope.auth_tag,
                key_version=envelope.key_version,
                algorithm=envelope.algorithm,
            )
            decrypted = decrypt_aes_gcm(reconstructed_envelope, client_key)
            assert decrypted == plain_text
    finally:
        app.dependency_overrides.clear()
