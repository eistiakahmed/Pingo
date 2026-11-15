from datetime import datetime, timezone
import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import get_current_user
from app.db.session import get_db
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.device import DeviceTokenRegisterRequest, DeviceTokenResponse

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/register-token",
    response_model=DeviceTokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Register or update user FCM device token",
    tags=["Devices"],
)
async def register_device_token(
    request: DeviceTokenRegisterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DeviceTokenResponse:
    """Registers an active Firebase Cloud Messaging (FCM) device token for push notification dispatch."""
    now = datetime.now(timezone.utc)

    # Check if token already exists
    stmt = select(DeviceToken).where(DeviceToken.token == request.token)
    result = await db.execute(stmt)
    existing_token = result.scalar_one_or_none()

    if existing_token:
        # Re-assign or update timestamp
        existing_token.user_id = current_user.id
        existing_token.platform = request.platform
        existing_token.updated_at = now
    else:
        new_token = DeviceToken(
            user_id=current_user.id,
            token=request.token,
            platform=request.platform,
            created_at=now,
            updated_at=now,
        )
        db.add(new_token)

    await db.commit()
    logger.info(f"[Devices] Successfully registered FCM token for user {current_user.id} ({request.platform}).")

    return DeviceTokenResponse(
        status="success",
        message="Device token registered successfully",
    )
