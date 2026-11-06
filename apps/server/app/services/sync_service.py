from datetime import datetime, timezone
from typing import Optional
from uuid import UUID
from sqlalchemy import select
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

        # 1. Process Reminders
        for r_dto in request.reminders:
            stmt = select(EncryptedReminder).where(
                EncryptedReminder.user_id == request.user_id,
                EncryptedReminder.id == r_dto.id,
            )
            result = await db.execute(stmt)
            existing = result.scalar_one_or_none()

            if existing:
                # Last-Write-Wins: only apply if incoming version >= existing version
                if r_dto.version >= existing.version:
                    existing.ciphertext = r_dto.ciphertext
                    existing.iv = r_dto.iv
                    existing.auth_tag = r_dto.auth_tag
                    existing.key_version = r_dto.key_version
                    existing.algorithm = r_dto.algorithm
                    existing.due_at = r_dto.due_at
                    existing.is_completed = r_dto.is_completed
                    existing.version = r_dto.version
                    existing.updated_at = now
                    existing.deleted_at = r_dto.deleted_at
                    applied_count += 1
            else:
                new_reminder = EncryptedReminder(
                    id=r_dto.id,
                    user_id=request.user_id,
                    ciphertext=r_dto.ciphertext,
                    iv=r_dto.iv,
                    auth_tag=r_dto.auth_tag,
                    key_version=r_dto.key_version,
                    algorithm=r_dto.algorithm,
                    due_at=r_dto.due_at,
                    is_completed=r_dto.is_completed,
                    version=r_dto.version,
                    created_at=r_dto.created_at or now,
                    updated_at=now,
                    deleted_at=r_dto.deleted_at,
                )
                db.add(new_reminder)
                applied_count += 1

        # 2. Process Vault Items
        for v_dto in request.vault_items:
            stmt = select(EncryptedVaultItem).where(
                EncryptedVaultItem.user_id == request.user_id,
                EncryptedVaultItem.id == v_dto.id,
            )
            result = await db.execute(stmt)
            existing_vault = result.scalar_one_or_none()

            if existing_vault:
                if v_dto.version >= existing_vault.version:
                    existing_vault.item_type = v_dto.item_type
                    existing_vault.ciphertext = v_dto.ciphertext
                    existing_vault.iv = v_dto.iv
                    existing_vault.auth_tag = v_dto.auth_tag
                    existing_vault.key_version = v_dto.key_version
                    existing_vault.algorithm = v_dto.algorithm
                    existing_vault.version = v_dto.version
                    existing_vault.updated_at = now
                    existing_vault.deleted_at = v_dto.deleted_at
                    applied_count += 1
            else:
                new_vault = EncryptedVaultItem(
                    id=v_dto.id,
                    user_id=request.user_id,
                    item_type=v_dto.item_type,
                    ciphertext=v_dto.ciphertext,
                    iv=v_dto.iv,
                    auth_tag=v_dto.auth_tag,
                    key_version=v_dto.key_version,
                    algorithm=v_dto.algorithm,
                    version=v_dto.version,
                    created_at=v_dto.created_at or now,
                    updated_at=now,
                    deleted_at=v_dto.deleted_at,
                )
                db.add(new_vault)
                applied_count += 1

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

