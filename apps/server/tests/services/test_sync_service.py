from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4
import pytest
from app.models.reminder import EncryptedReminder
from app.schemas.sync import EncryptedReminderDTO, SyncPushRequest
from app.services.sync_service import SyncService


@pytest.mark.asyncio
async def test_sync_service_applies_push_with_lww():
    user_id = uuid4()
    reminder_id = uuid4()
    now = datetime.now(timezone.utc)

    # Mock existing reminder with version 1
    existing_reminder = EncryptedReminder(
        id=reminder_id,
        user_id=user_id,
        ciphertext="old_ciphertext",
        iv="old_iv",
        auth_tag="old_tag",
        key_version=1,
        version=1,
        updated_at=now,
    )

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = existing_reminder
    mock_db.execute.return_value = mock_result

    # Incoming reminder with version 2
    r_dto = EncryptedReminderDTO(
        id=reminder_id,
        ciphertext="bmV3X2NpcGhlcnRleHQ=",
        iv="bmV3X2l2XzEyYg==",
        auth_tag="bmV3X3RhZ18xNmJ5dGU=",
        key_version=1,
        version=2,
    )

    req = SyncPushRequest(
        user_id=user_id,
        reminders=[r_dto],
        vault_items=[],
    )

    response = await SyncService.apply_push(db=mock_db, request=req)

    assert response.success is True
    assert response.applied_count == 1
    assert existing_reminder.ciphertext == "bmV3X2NpcGhlcnRleHQ="
    assert existing_reminder.version == 2
