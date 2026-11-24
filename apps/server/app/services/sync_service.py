from datetime import datetime, timezone
from typing import Optional
from uuid import UUID
from zoneinfo import ZoneInfo
from sqlalchemy import case, select
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


def normalize_due_at(dt: Optional[datetime]) -> Optional[datetime]:
    """Ensures due_at timestamp is strictly in UTC, localizing naive client timestamps from Asia/Dhaka."""
    if not dt:
        return None
    if dt.tzinfo is None:
        try:
            return dt.replace(tzinfo=ZoneInfo("Asia/Dhaka")).astimezone(timezone.utc)
        except Exception:
            return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


class SyncService:
    @classmethod
    async def apply_push(
        cls, db: AsyncSession, request: SyncPushRequest
    ) -> SyncPushResponse:
        if request.user_id is None:
            raise ValueError("Strict tenant isolation violation: SyncPushRequest.user_id is required.")

        applied_count = 0
        now = datetime.now(timezone.utc)

        # 1. Atomic Bulk Upsert Reminders — Strictly Tenant-Scoped + Irreversible Auto-Completion
        if request.reminders:
            reminder_values = []
            for r in request.reminders:
                norm_due = normalize_due_at(r.due_at)
                due_reached = bool(norm_due and norm_due <= now)
                # Zero-Touch Auto-Completion: any reminder whose due condition is met transitions irreversibly to completed
                auto_completed = r.is_completed or due_reached
                reminder_values.append(
                    {
                        "id": r.id,
                        "user_id": request.user_id,
                        "ciphertext": r.ciphertext,
                        "iv": r.iv,
                        "auth_tag": r.auth_tag,
                        "key_version": r.key_version,
                        "algorithm": r.algorithm,
                        "due_at": norm_due,
                        "is_completed": auto_completed,
                        "version": r.version,
                        "created_at": r.created_at or now,
                        "updated_at": now,
                        # Manual delete deprecated: ignore client deleted_at tombstones on active/completed reminders
                        "deleted_at": None,
                        "notification_sent": auto_completed,
                    }
                )

            stmt = pg_insert(EncryptedReminder).values(reminder_values)
            stmt = stmt.on_conflict_do_update(
                index_elements=[EncryptedReminder.id],
                set_={
                    # Once completed, ciphertext and due_at are immutable; manual edits/deletes are ignored
                    "ciphertext": case(
                        (EncryptedReminder.is_completed.is_(True), EncryptedReminder.ciphertext),
                        else_=stmt.excluded.ciphertext,
                    ),
                    "iv": case(
                        (EncryptedReminder.is_completed.is_(True), EncryptedReminder.iv),
                        else_=stmt.excluded.iv,
                    ),
                    "auth_tag": case(
                        (EncryptedReminder.is_completed.is_(True), EncryptedReminder.auth_tag),
                        else_=stmt.excluded.auth_tag,
                    ),
                    "due_at": case(
                        (EncryptedReminder.is_completed.is_(True), EncryptedReminder.due_at),
                        else_=stmt.excluded.due_at,
                    ),
                    # Strictly monotonic irreversible completion: True can NEVER revert to False
                    "is_completed": (
                        EncryptedReminder.is_completed | stmt.excluded.is_completed
                    ),
                    "notification_sent": (
                        EncryptedReminder.notification_sent
                        | EncryptedReminder.is_completed
                        | stmt.excluded.is_completed
                    ),
                    "version": stmt.excluded.version,
                    "updated_at": now,
                },
                # Strict tenant isolation: never allow Tenant A to overwrite Tenant B's reminder UUID!
                where=(
                    (EncryptedReminder.user_id == request.user_id)
                    & (stmt.excluded.version >= EncryptedReminder.version)
                ),
            )
            await db.execute(stmt)
            applied_count += len(request.reminders)

        # 2. Atomic Bulk Upsert Vault Items — Strictly Tenant-Scoped
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
                is_completed=r.is_completed or bool(r.due_at and r.due_at <= now),
                version=r.version,
                created_at=r.created_at,
                updated_at=r.updated_at,
                deleted_at=r.deleted_at,
            )
            for r in r_result.scalars().all()
        ]

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
