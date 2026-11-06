from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


def derive_key_pbkdf2(
    passphrase: str,
    salt: bytes,
    iterations: int = 100_000,
    key_length: int = 32,
) -> bytes:
    """
    Derives a cryptographically strong 256-bit symmetric key from a passphrase and salt.
    """
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=key_length,
        salt=salt,
        iterations=iterations,
    )
    return kdf.derive(passphrase.encode("utf-8"))
