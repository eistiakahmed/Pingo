import pytest
from e2ee.kdf import derive_key_pbkdf2
from e2ee.aes_gcm import encrypt_aes_gcm, decrypt_aes_gcm
from e2ee.envelope import EncryptedEnvelope


def test_aes_gcm_roundtrip():
    salt = b"test-salt-16byte"
    key = derive_key_pbkdf2("my-secure-pin", salt)
    assert len(key) == 32

    secret_text = "ডাক্তারের প্রেসক্রিপশন ও ওষুধের রিমাইন্ডার"
    envelope = encrypt_aes_gcm(secret_text, key, key_version=1)

    assert isinstance(envelope, EncryptedEnvelope)
    assert envelope.algorithm == "AES-256-GCM"
    assert envelope.ciphertext != secret_text
    assert envelope.key_version == 1

    decrypted = decrypt_aes_gcm(envelope, key)
    assert decrypted == secret_text


def test_decrypt_with_tampered_ciphertext_fails():
    salt = b"test-salt-16byte"
    key = derive_key_pbkdf2("my-secure-pin", salt)
    envelope = encrypt_aes_gcm("Sensitive Data", key)

    # Tamper with ciphertext
    tampered_envelope = EncryptedEnvelope(
        ciphertext="dGFtcGVyZWQ=",
        iv=envelope.iv,
        auth_tag=envelope.auth_tag,
        key_version=envelope.key_version,
        algorithm=envelope.algorithm,
    )

    with pytest.raises(Exception):
        decrypt_aes_gcm(tampered_envelope, key)

