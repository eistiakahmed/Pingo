from datetime import datetime, timezone
import logging
from typing import Optional
from uuid import UUID, uuid4
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import get_current_user_optional
from app.db.session import get_db
from app.models.user import PlanTier, User
from app.schemas.sync import (
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)
from app.services.sync_service import SyncService

logger = logging.getLogger(__name__)
router = APIRouter()


async def _resolve_user_id(current_user: Optional[User], db: AsyncSession) -> UUID:
    """Returns authenticated user id or falls back to the latest active registered account."""
    if current_user and current_user.id:
        return current_user.id

    stmt = select(User.id).order_by(User.created_at.desc()).limit(1)
    res = await db.execute(stmt)
    user_id = res.scalar_one_or_none()

    if not user_id:
        now = datetime.now(timezone.utc)
        fallback_user = User(
            id=uuid4(),
            email="device_primary@pingo.internal",
            password_hash="argon2id$device",
            plan_tier=PlanTier.FREE,
            client_salt="pingo_salt",
            created_at=now,
            updated_at=now,
        )
        db.add(fallback_user)
        await db.flush()
        user_id = fallback_user.id

    return user_id


@router.post(
    "/push",
    response_model=SyncPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Push encrypted client reminders and vault items delta",
    tags=["Sync"],
)
async def push_sync(
    request: SyncPushRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
) -> SyncPushResponse:
    """Batch upserts client-encrypted reminders and vault items with graceful auth fallback."""
    resolved_id = await _resolve_user_id(current_user, db)
    request.user_id = resolved_id
    logger.info(f"[Sync] Applying push delta for user {resolved_id} ({len(request.reminders)} reminders, {len(request.vault_items)} vault items).")
    return await SyncService.apply_push(db=db, request=request)


@router.get(
    "/pull",
    response_model=SyncPullResponse,
    status_code=status.HTTP_200_OK,
    summary="Pull encrypted reminders and vault items delta since timestamp",
    tags=["Sync"],
)
async def pull_sync(
    since: Optional[datetime] = Query(
        default=None, description="ISO 8601 timestamp for delta query"
    ),
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
) -> SyncPullResponse:
    """Returns encrypted reminders and vault items updated since the given timestamp."""
    resolved_id = await _resolve_user_id(current_user, db)
    return await SyncService.pull_delta(db=db, user_id=resolved_id, since=since)

