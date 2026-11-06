import base64
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from e2ee.envelope import EncryptedEnvelope


def encrypt_aes_gcm(
    plaintext: str,
    key: bytes,
    key_version: int = 1,
) -> EncryptedEnvelope:
    """
    Encrypts plaintext using AES-256-GCM.
    Returns EncryptedEnvelope containing base64 ciphertext, iv, and auth_tag.
    """
    if len(key) != 32:
        raise ValueError("AES-256 requires a 32-byte key")

    # Generate 12-byte (96-bit) IV as recommended for GCM
    iv = os.urandom(12)
    aesgcm = AESGCM(key)

    data_bytes = plaintext.encode("utf-8")
    # AESGCM.encrypt appends 16-byte tag to the ciphertext
    encrypted_with_tag = aesgcm.encrypt(iv, data_bytes, None)

    ciphertext_bytes = encrypted_with_tag[:-16]
    tag_bytes = encrypted_with_tag[-16:]

    return EncryptedEnvelope(
        ciphertext=base64.b64encode(ciphertext_bytes).decode("utf-8"),
        iv=base64.b64encode(iv).decode("utf-8"),
        auth_tag=base64.b64encode(tag_bytes).decode("utf-8"),
        key_version=key_version,
        algorithm="AES-256-GCM",
    )


def decrypt_aes_gcm(
    envelope: EncryptedEnvelope,
    key: bytes,
) -> str:
    """
    Decrypts an EncryptedEnvelope using AES-256-GCM.
    Verifies authentication tag and returns UTF-8 plaintext.
    """
    if len(key) != 32:
        raise ValueError("AES-256 requires a 32-byte key")

    iv = base64.b64decode(envelope.iv)
    ciphertext_bytes = base64.b64decode(envelope.ciphertext)
    tag_bytes = base64.b64decode(envelope.auth_tag)

    aesgcm = AESGCM(key)
    # Reassemble ciphertext + tag for AESGCM verification
    encrypted_with_tag = ciphertext_bytes + tag_bytes

    decrypted_bytes = aesgcm.decrypt(iv, encrypted_with_tag, None)
    return decrypted_bytes.decode("utf-8")
