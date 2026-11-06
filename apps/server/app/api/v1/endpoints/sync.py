from datetime import datetime
from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
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
    db: AsyncSession = Depends(get_db),
) -> SyncPushResponse:
    """Batch upserts client-encrypted reminders and vault items without plaintext."""
    return await SyncService.apply_push(db=db, request=request)


@router.get(
    "/pull",
    response_model=SyncPullResponse,
    status_code=status.HTTP_200_OK,
    summary="Pull encrypted reminders and vault items delta since timestamp",
    tags=["Sync"],
)
async def pull_sync(
    user_id: UUID = Query(description="Authenticated user UUID"),
    since: Optional[datetime] = Query(
        default=None, description="ISO 8601 timestamp for delta query"
    ),
    db: AsyncSession = Depends(get_db),
) -> SyncPullResponse:
    """Returns encrypted reminders and vault items updated since the given timestamp."""
    return await SyncService.pull_delta(db=db, user_id=user_id, since=since)
