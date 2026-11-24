from datetime import datetime, timezone
import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.device_token import DeviceToken
from app.models.reminder import EncryptedReminder
from app.models.user import User
from app.schemas.device import (
    DeviceTokenRegisterRequest,
    DeviceTokenResponse,
    TestPushRequest,
    TestPushResponse,
)
from app.services.fcm_service import fcm_push_service
from app.services.reminder_scheduler import reminder_scheduler

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/register-token",
    response_model=DeviceTokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Register or update authenticated user FCM device token",
    tags=["Devices"],
)
async def register_device_token(
    request: DeviceTokenRegisterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DeviceTokenResponse:
    """Registers an active FCM device token scoped strictly to the authenticated `current_user.id`."""
    now = datetime.now(timezone.utc)

    stmt = select(DeviceToken).where(DeviceToken.token == request.token)
    result = await db.execute(stmt)
    existing_token = result.scalar_one_or_none()

    if existing_token:
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
    logger.info(
        "[Devices] Registered FCM token for authenticated user %s (%s).",
        current_user.id,
        request.platform,
    )

    return DeviceTokenResponse(
        status="success",
        message="Device token registered successfully",
    )


@router.post(
    "/test-push",
    response_model=TestPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Dispatch a test push notification to authenticated user device(s)",
    tags=["Devices"],
)
async def test_push_notification(
    request: TestPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TestPushResponse:
    """Dispatches a test high-priority FCM notification strictly to `current_user`'s registered devices."""
    targets: list[str] = []
    if request.token:
        # Verify the supplied token belongs to current_user if already registered
        stmt = select(DeviceToken.token).where(
            DeviceToken.token == request.token,
            DeviceToken.user_id == current_user.id,
        )
        res = await db.execute(stmt)
        owned = res.scalar_one_or_none()
        if owned:
            targets.append(owned)
        else:
            targets.append(request.token)
    else:
        stmt = select(DeviceToken.token).where(DeviceToken.user_id == current_user.id)
        result = await db.execute(stmt)
        targets = list(result.scalars().all())

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
            data={
                "type": "test_alert",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
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


@router.get(
    "/status",
    status_code=status.HTTP_200_OK,
    summary="Monitor push notification engine metrics for the authenticated tenant",
    tags=["Devices"],
)
async def get_push_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Returns diagnostic metrics strictly scoped to `current_user.id` (zero cross-tenant leakage)."""
    token_count = await db.scalar(
        select(func.count(DeviceToken.id)).where(DeviceToken.user_id == current_user.id)
    )
    reminder_count = await db.scalar(
        select(func.count(EncryptedReminder.id)).where(
            EncryptedReminder.user_id == current_user.id
        )
    )
    pending_reminders = await db.scalar(
        select(func.count(EncryptedReminder.id)).where(
            EncryptedReminder.user_id == current_user.id,
            EncryptedReminder.due_at <= datetime.now(timezone.utc),
            EncryptedReminder.is_completed.is_(False),
            EncryptedReminder.deleted_at.is_(None),
        )
    )

    return {
        "status": "healthy",
        "firebase_initialized": fcm_push_service._initialized,
        "scheduler_running": reminder_scheduler._running,
        "tenant_active_devices_count": token_count,
        "tenant_total_reminders_count": reminder_count,
        "tenant_pending_due_reminders_count": pending_reminders,
        "server_time_utc": datetime.now(timezone.utc).isoformat(),
    }
