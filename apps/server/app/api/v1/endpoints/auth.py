from uuid import uuid4
from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.exceptions import AppException
from app.core.rate_limit import check_auth_rate_limit
from app.core.security import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.db.session import get_db
from app.models.user import PlanTier, User
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    RegisterRequest,
    UserProfileResponse,
)

router = APIRouter()

# Static dummy hash generated at module load to prevent user enumeration via timing attacks
DUMMY_PASSWORD_HASH = hash_password("dummy-pingo-constant-time-auth-check")


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register new user with client-generated E2EE salt",
    tags=["Authentication"],
)
async def register(
    request: RegisterRequest,
    db: AsyncSession = Depends(get_db),
    _rate_limit: None = Depends(check_auth_rate_limit),
) -> AuthResponse:
    # Check if email already registered
    stmt = select(User).where(User.email == request.email)
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    if existing:
        raise AppException(
            title="Email Already Registered",
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email address already exists.",
            type_url="https://api.pingo.app/errors/email-exists",
        )

    # Hash password with Argon2id
    hashed = hash_password(request.password)

    new_user = User(
        id=uuid4(),
        email=request.email,
        password_hash=hashed,
        client_salt=request.client_salt,
        plan_tier=PlanTier.FREE,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    token = create_access_token(user_id=new_user.id, email=new_user.email)

    return AuthResponse(
        access_token=token,
        token_type="bearer",
        user_id=new_user.id,
        email=new_user.email,
        client_salt=new_user.client_salt,
    )


@router.post(
    "/login",
    response_model=AuthResponse,
    status_code=status.HTTP_200_OK,
    summary="Authenticate user and receive JWT access token",
    tags=["Authentication"],
)
async def login(
    request: LoginRequest,
    db: AsyncSession = Depends(get_db),
    _rate_limit: None = Depends(check_auth_rate_limit),
) -> AuthResponse:
    stmt = select(User).where(User.email == request.email)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        # Uniform timing: execute Argon2 verify against dummy hash to prevent email enumeration
        verify_password(request.password, DUMMY_PASSWORD_HASH)
        raise AppException(
            title="Authentication Failed",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            type_url="https://api.pingo.app/errors/invalid-credentials",
        )

    if not verify_password(request.password, user.password_hash):
        raise AppException(
            title="Authentication Failed",
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            type_url="https://api.pingo.app/errors/invalid-credentials",
        )

    token = create_access_token(user_id=user.id, email=user.email)

    return AuthResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        client_salt=user.client_salt,
    )


@router.get(
    "/me",
    response_model=UserProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Get authenticated user profile and salt",
    tags=["Authentication"],
)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> UserProfileResponse:
    return UserProfileResponse(
        id=current_user.id,
        email=current_user.email,
        client_salt=current_user.client_salt,
        plan_tier=current_user.plan_tier.value,
    )
