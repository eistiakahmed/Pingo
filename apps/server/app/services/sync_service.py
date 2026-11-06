from datetime import datetime, timezone
from typing import Optional
from uuid import UUID
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.reminder import EncryptedReminder
from app.models.vault import EncryptedVaultItem
from app.schemas.sync import (
    EncryptedReminderDTO,
    EncryptedVaultDTO,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)


class SyncService:
    @classmethod
    async def apply_push(
        cls, db: AsyncSession, request: SyncPushRequest
    ) -> SyncPushResponse:
        applied_count = 0
        now = datetime.now(timezone.utc)

        # 1. Atomic Bulk Upsert Reminders with Last-Write-Wins
        if request.reminders:
            reminder_values = [
                {
                    "id": r.id,
                    "user_id": request.user_id,
                    "ciphertext": r.ciphertext,
                    "iv": r.iv,
                    "auth_tag": r.auth_tag,
                    "key_version": r.key_version,
                    "algorithm": r.algorithm,
                    "due_at": r.due_at,
                    "is_completed": r.is_completed,
                    "version": r.version,
                    "created_at": r.created_at or now,
                    "updated_at": now,
                    "deleted_at": r.deleted_at,
                }
                for r in request.reminders
            ]

            stmt = pg_insert(EncryptedReminder).values(reminder_values)
            stmt = stmt.on_conflict_do_update(
                index_elements=[EncryptedReminder.id],
                set_={
                    "ciphertext": stmt.excluded.ciphertext,
                    "iv": stmt.excluded.iv,
                    "auth_tag": stmt.excluded.auth_tag,
                    "key_version": stmt.excluded.key_version,
                    "algorithm": stmt.excluded.algorithm,
                    "due_at": stmt.excluded.due_at,
                    "is_completed": stmt.excluded.is_completed,
                    "version": stmt.excluded.version,
                    "updated_at": now,
                    "deleted_at": stmt.excluded.deleted_at,
                },
                where=(
                    (EncryptedReminder.user_id == request.user_id)
                    & (stmt.excluded.version >= EncryptedReminder.version)
                ),
            )
            await db.execute(stmt)
            applied_count += len(request.reminders)

        # 2. Atomic Bulk Upsert Vault Items with Last-Write-Wins
        if request.vault_items:
            vault_values = [
                {
                    "id": v.id,
                    "user_id": request.user_id,
                    "item_type": v.item_type,
                    "ciphertext": v.ciphertext,
                    "iv": v.iv,
                    "auth_tag": v.auth_tag,
                    "key_version": v.key_version,
                    "algorithm": v.algorithm,
                    "version": v.version,
                    "created_at": v.created_at or now,
                    "updated_at": now,
                    "deleted_at": v.deleted_at,
                }
                for v in request.vault_items
            ]

            v_stmt = pg_insert(EncryptedVaultItem).values(vault_values)
            v_stmt = v_stmt.on_conflict_do_update(
                index_elements=[EncryptedVaultItem.id],
                set_={
                    "item_type": v_stmt.excluded.item_type,
                    "ciphertext": v_stmt.excluded.ciphertext,
                    "iv": v_stmt.excluded.iv,
                    "auth_tag": v_stmt.excluded.auth_tag,
                    "key_version": v_stmt.excluded.key_version,
                    "algorithm": v_stmt.excluded.algorithm,
                    "version": v_stmt.excluded.version,
                    "updated_at": now,
                    "deleted_at": v_stmt.excluded.deleted_at,
                },
                where=(
                    (EncryptedVaultItem.user_id == request.user_id)
                    & (v_stmt.excluded.version >= EncryptedVaultItem.version)
                ),
            )
            await db.execute(v_stmt)
            applied_count += len(request.vault_items)

        await db.commit()

        return SyncPushResponse(
            success=True,
            applied_count=applied_count,
            server_timestamp=now,
        )

    @classmethod
    async def pull_delta(
        cls, db: AsyncSession, user_id: UUID, since: Optional[datetime] = None
    ) -> SyncPullResponse:
        now = datetime.now(timezone.utc)

        # Query reminders
        r_query = select(EncryptedReminder).where(
            EncryptedReminder.user_id == user_id
        )
        if since:
            r_query = r_query.where(EncryptedReminder.updated_at > since)

        r_result = await db.execute(r_query)
        reminders = [
            EncryptedReminderDTO(
                id=r.id,
                ciphertext=r.ciphertext,
                iv=r.iv,
                auth_tag=r.auth_tag,
                key_version=r.key_version,
                algorithm=r.algorithm,
                due_at=r.due_at,
                is_completed=r.is_completed,
                version=r.version,
                created_at=r.created_at,
                updated_at=r.updated_at,
                deleted_at=r.deleted_at,
            )
            for r in r_result.scalars().all()
        ]

        # Query vault items
        v_query = select(EncryptedVaultItem).where(
            EncryptedVaultItem.user_id == user_id
        )
        if since:
            v_query = v_query.where(EncryptedVaultItem.updated_at > since)

        v_result = await db.execute(v_query)
        vault_items = [
            EncryptedVaultDTO(
                id=v.id,
                item_type=v.item_type,
                ciphertext=v.ciphertext,
                iv=v.iv,
                auth_tag=v.auth_tag,
                key_version=v.key_version,
                algorithm=v.algorithm,
                version=v.version,
                created_at=v.created_at,
                updated_at=v.updated_at,
                deleted_at=v.deleted_at,
            )
            for v in v_result.scalars().all()
        ]

        return SyncPullResponse(
            reminders=reminders,
            vault_items=vault_items,
            server_timestamp=now,
        )
