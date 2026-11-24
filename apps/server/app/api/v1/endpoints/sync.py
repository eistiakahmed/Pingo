from datetime import datetime
import logging
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.sync import (
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)
from app.services.sync_service import SyncService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/push",
    response_model=SyncPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Push encrypted client reminders and vault items delta (Strictly Authenticated Tenant)",
    tags=["Sync"],
)
async def push_sync(
    request: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyncPushResponse:
    """Batch upserts client-encrypted reminders and vault items scoped strictly to `current_user.id`."""
    request.user_id = current_user.id
    logger.info(
        "[Sync] Applying tenant-isolated push delta for user %s (%d reminders, %d vault items).",
        current_user.id,
        len(request.reminders),
        len(request.vault_items),
    )
    return await SyncService.apply_push(db=db, request=request)


@router.get(
    "/pull",
    response_model=SyncPullResponse,
    status_code=status.HTTP_200_OK,
    summary="Pull encrypted reminders and vault items delta since timestamp (Strictly Authenticated Tenant)",
    tags=["Sync"],
)
async def pull_sync(
    since: Optional[datetime] = Query(
        default=None, description="ISO 8601 timestamp for delta query"
    ),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyncPullResponse:
    """Returns encrypted reminders and vault items scoped strictly to `current_user.id`."""
    return await SyncService.pull_delta(db=db, user_id=current_user.id, since=since)
