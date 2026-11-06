from uuid import UUID
from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    email: str = Field(
        pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
        description="User email address",
    )
    password: str = Field(
        min_length=8, description="User password, minimum 8 characters"
    )
    client_salt: str = Field(
        min_length=16,
        description="Client-generated salt for local E2EE key derivation",
    )


class LoginRequest(BaseModel):
    email: str = Field(
        pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
        description="User email address",
    )
    password: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: UUID
    email: str
    client_salt: str


class UserProfileResponse(BaseModel):
    id: UUID
    email: str
    client_salt: str
    plan_tier: str
