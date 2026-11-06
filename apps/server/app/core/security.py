from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID
import jwt
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher
from fastapi import Depends, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import get_settings
from app.core.exceptions import AppException
from app.db.session import get_db
from app.models.user import User

settings = get_settings()

password_hash = PasswordHash((Argon2Hasher(),))
security_bearer = HTTPBearer(auto_error=False)

ALGORITHM = "HS256"
DEFAULT_ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days


def hash_password(password: str) -> str:
    """Hashes a password using Argon2id."""
    return password_hash.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plain password against an Argon2id hash."""
    return password_hash.verify(plain_password, hashed_password)


def create_access_token(
    user_id: UUID,
    email: str,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Generates an HMAC-SHA256 JWT access token."""
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=DEFAULT_ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode = {
        "sub": str(user_id),
        "email": email,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> dict:
    """Decodes and validates a JWT access token."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise AppException(
            title="Token Expired",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has expired. Please log in again.",
            type_url="https://api.pingo.app/errors/token-expired",
        )
    except jwt.InvalidTokenError:
        raise AppException(
            title="Invalid Credentials",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate authentication credentials.",
            type_url="https://api.pingo.app/errors/invalid-token",
        )


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    FastAPI dependency that enforces JWT authentication.
    Returns the authenticated User model from the database.
    """
    if not credentials or not credentials.credentials:
        raise AppException(
            title="Unauthorized",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer authentication token in Authorization header.",
            type_url="https://api.pingo.app/errors/unauthorized",
        )

    payload = decode_access_token(credentials.credentials)
    user_id_str: Optional[str] = payload.get("sub")
    if not user_id_str:
        raise AppException(
            title="Invalid Token",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token subject missing.",
            type_url="https://api.pingo.app/errors/invalid-token",
        )

    try:
        user_uuid = UUID(user_id_str)
    except ValueError:
        raise AppException(
            title="Invalid Token",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Malformed user ID in token.",
            type_url="https://api.pingo.app/errors/invalid-token",
        )

    stmt = select(User).where(User.id == user_uuid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise AppException(
            title="User Not Found",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User corresponding to this token no longer exists.",
            type_url="https://api.pingo.app/errors/user-not-found",
        )

    return user

