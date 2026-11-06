from uuid import uuid4
import pytest
from pydantic import ValidationError
from app.schemas.sync import EncryptedReminderDTO, SyncPushRequest


def test_valid_encrypted_envelope_dto():
    dto = EncryptedReminderDTO(
        id=uuid4(),
        ciphertext="ZXhhbXBsZWNpcGhlcnRleHQ=",
        iv="MDEyMzQ1Njc4OWFi",
        auth_tag="YWJjZGVmZ2hpamtsbW5vcA==",
        key_version=1,
        version=1,
    )
    assert dto.algorithm == "AES-256-GCM"
    assert dto.is_completed is False


def test_invalid_base64_ciphertext_rejected():
    with pytest.raises(ValidationError):
        EncryptedReminderDTO(
            id=uuid4(),
            ciphertext="not-valid-base64!@#$%",
            iv="MDEyMzQ1Njc4OWFi",
            auth_tag="YWJjZGVmZ2hpamtsbW5vcA==",
            key_version=1,
            version=1,
        )


def test_batch_size_flood_prevention():
    dto = EncryptedReminderDTO(
        id=uuid4(),
        ciphertext="ZXhhbXBsZWNpcGhlcnRleHQ=",
        iv="MDEyMzQ1Njc4OWFi",
        auth_tag="YWJjZGVmZ2hpamtsbW5vcA==",
        key_version=1,
        version=1,
    )
    # Creating 501 items exceeds max limit of 500
    with pytest.raises(ValidationError):
        SyncPushRequest(reminders=[dto] * 501, vault_items=[])

