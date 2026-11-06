from datetime import datetime
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

router = APIRouter()


@router.post(
    "/push",
    response_model=SyncPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Push encrypted client reminders and vault items delta",
    tags=["Sync"],
)
async def push_sync(
    request: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyncPushResponse:
    """Batch upserts client-encrypted reminders and vault items for authenticated user."""
    request.user_id = current_user.id
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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyncPullResponse:
    """Returns encrypted reminders and vault items updated since the given timestamp for authenticated user."""
    return await SyncService.pull_delta(db=db, user_id=current_user.id, since=since)
