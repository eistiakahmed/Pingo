import base64
from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel, Field, field_validator


def validate_base64(value: str) -> str:
    """Validates that a string is strictly valid Base64."""
    try:
        decoded = base64.b64decode(value, validate=True)
        if len(decoded) == 0:
            raise ValueError("Base64 string cannot be empty")
        return value
    except Exception:
        raise ValueError("Invalid Base64 encoded string")


class EncryptedReminderDTO(BaseModel):
    id: UUID
    ciphertext: str = Field(description="Base64 encoded ciphertext")
    iv: str = Field(description="Base64 encoded IV (12 bytes)")
    auth_tag: str = Field(description="Base64 encoded auth tag (16 bytes)")
    key_version: int = Field(default=1)
    algorithm: str = Field(default="AES-256-GCM")
    due_at: Optional[datetime] = None
    is_completed: bool = False
    version: int = Field(default=1)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None

    @field_validator("ciphertext", "iv", "auth_tag")
    @classmethod
    def check_base64(cls, v: str) -> str:
        return validate_base64(v)


class EncryptedVaultDTO(BaseModel):
    id: UUID
    item_type: str
    ciphertext: str = Field(description="Base64 encoded ciphertext")
    iv: str = Field(description="Base64 encoded IV (12 bytes)")
    auth_tag: str = Field(description="Base64 encoded auth tag (16 bytes)")
    key_version: int = Field(default=1)
    algorithm: str = Field(default="AES-256-GCM")
    version: int = Field(default=1)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None

    @field_validator("ciphertext", "iv", "auth_tag")
    @classmethod
    def check_base64(cls, v: str) -> str:
        return validate_base64(v)


class SyncPushRequest(BaseModel):
    user_id: Optional[UUID] = None
    reminders: List[EncryptedReminderDTO] = Field(
        default_factory=list,
        max_length=500,
        description="List of encrypted reminders to upsert (max 500 per batch)",
    )
    vault_items: List[EncryptedVaultDTO] = Field(
        default_factory=list,
        max_length=500,
        description="List of encrypted vault items to upsert (max 500 per batch)",
    )


class SyncPushResponse(BaseModel):
    success: bool = True
    applied_count: int
    server_timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )


class SyncPullResponse(BaseModel):
    reminders: List[EncryptedReminderDTO]
    vault_items: List[EncryptedVaultDTO]
    server_timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )

