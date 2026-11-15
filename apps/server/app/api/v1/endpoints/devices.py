from datetime import datetime, timezone
import logging
from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from app.core.security import get_current_user, get_current_user_optional
from app.db.session import get_db
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.device import (
    DeviceTokenRegisterRequest,
    DeviceTokenResponse,
    TestPushRequest,
    TestPushResponse,
)
from app.services.fcm_service import fcm_push_service

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


@router.post(
    "/test-push",
    response_model=TestPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Dispatch a test push notification to user device(s)",
    tags=["Devices"],
)
async def test_push_notification(
    request: TestPushRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
) -> TestPushResponse:
    """Dispatches a test high-priority FCM notification to verified device token(s)."""
    targets = []
    if request.token:
        targets.append(request.token)
    elif current_user:
        stmt = select(DeviceToken.token).where(DeviceToken.user_id == current_user.id)
        result = await db.execute(stmt)
        targets = list(result.scalars().all())
    else:
        return TestPushResponse(
            status="warning",
            message="Please provide a device token or log in with an authenticated account to test push.",
            sent_count=0,
            details=[],
        )

    if not targets:
        return TestPushResponse(
            status="warning",
            message="No device tokens found for this user. Please register a device token first.",
            sent_count=0,
            details=[],
        )

    sent_count = 0
    details = []
    for token in targets:
        success = await fcm_push_service.send_reminder_push(
            token=token,
            title=request.title,
            body=request.body,
            data={"type": "test_alert", "timestamp": datetime.now(timezone.utc).isoformat()},
        )
        if success:
            sent_count += 1
            details.append({"token": token[:15] + "...", "status": "delivered"})
        else:
            details.append({"token": token[:15] + "...", "status": "failed"})

    return TestPushResponse(
        status="success" if sent_count > 0 else "error",
        message=f"Dispatched test push to {sent_count} of {len(targets)} device(s).",
        sent_count=sent_count,
        details=details,
    )
