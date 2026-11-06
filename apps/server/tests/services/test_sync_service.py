from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4
import pytest
from app.models.reminder import EncryptedReminder
from app.schemas.sync import EncryptedReminderDTO, EncryptedVaultDTO, SyncPushRequest
from app.services.sync_service import SyncService


@pytest.mark.asyncio
async def test_sync_service_applies_push_atomic_upsert():
    user_id = uuid4()
    reminder_id = uuid4()
    vault_id = uuid4()

    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_db.commit = AsyncMock()

    r_dto = EncryptedReminderDTO(
        id=reminder_id,
        ciphertext="bmV3X2NpcGhlcnRleHQ=",
        iv="bmV3X2l2XzEyYg==",
        auth_tag="bmV3X3RhZ18xNmJ5dGU=",
        key_version=1,
        version=2,
    )
    v_dto = EncryptedVaultDTO(
        id=vault_id,
        item_type="note",
        ciphertext="dmF1bHRfY2lwaGVydGV4dA==",
        iv="dmF1bHRfaXZfMTJieXRlcw==",
        auth_tag="dmF1bHRfdGFnXzE2Ynl0ZQ==",
        key_version=1,
        version=1,
    )

    req = SyncPushRequest(
        user_id=user_id,
        reminders=[r_dto],
        vault_items=[v_dto],
    )

    response = await SyncService.apply_push(db=mock_db, request=req)

    assert response.success is True
    assert response.applied_count == 2
    # Verify both reminders and vault items were executed in bulk upsert statements
    assert mock_db.execute.call_count == 2
    assert mock_db.commit.call_count == 1
