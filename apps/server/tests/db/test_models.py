from uuid import uuid4
import pytest
from app.models.user import User, PlanTier
from app.models.reminder import EncryptedReminder
from app.models.vault import EncryptedVaultItem


def test_models_instantiation():
    user_id = uuid4()
    user = User(
        id=user_id,
        email="user@pingo.app",
        password_hash="argon2id$hashed",
        plan_tier=PlanTier.FREE,
        client_salt="salt128bit",
    )
    reminder = EncryptedReminder(
        id=uuid4(),
        user_id=user.id,
        ciphertext="base64ciphertext",
        iv="base64iv",
        auth_tag="base64tag",
        key_version=1,
        algorithm="AES-256-GCM",
        is_completed=False,
        version=1,
    )
    vault_item = EncryptedVaultItem(
        id=uuid4(),
        user_id=user.id,
        item_type="NOTE",
        ciphertext="base64vaultdata",
        iv="base64iv",
        auth_tag="base64tag",
        key_version=1,
        algorithm="AES-256-GCM",
        version=1,
    )

    assert user.email == "user@pingo.app"
    assert reminder.algorithm == "AES-256-GCM"
    assert reminder.is_completed is False
    assert reminder.version == 1
    assert vault_item.item_type == "NOTE"
    assert vault_item.version == 1
