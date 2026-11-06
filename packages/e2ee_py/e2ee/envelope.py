from pydantic import BaseModel, Field


class EncryptedEnvelope(BaseModel):
    """Zero-knowledge cryptographic envelope storing AES-256-GCM encrypted payload."""

    ciphertext: str = Field(description="Base64-encoded encrypted data")
    iv: str = Field(description="Base64-encoded 12-byte initialization vector")
    auth_tag: str = Field(description="Base64-encoded 16-byte GCM authentication tag")
    key_version: int = Field(default=1, description="Key version index")
    algorithm: str = Field(default="AES-256-GCM", description="Cryptographic cipher used")
