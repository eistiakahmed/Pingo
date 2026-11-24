import asyncio
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import logging
import mimetypes
from pathlib import Path
import re
import time
from typing import Any, Optional
from uuid import uuid4

from fastapi import UploadFile, status
from app.core.exceptions import AppException
from app.core.tenant import TenantContext

logger = logging.getLogger(__name__)

MAX_ATTACHMENT_BYTES = 15 * 1024 * 1024  # 15 MB per staged attachment
STAGING_TTL_SECONDS = 30 * 60  # 30 minutes uncommitted composer preview TTL
MAX_STAGED_PER_TENANT = 10

ALLOWED_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".pdf",
    ".txt",
    ".md",
    ".csv",
    ".json",
    ".doc",
    ".docx",
}

STAGED_ROOT_DIR = Path(__file__).resolve().parent.parent / "static" / "staged"
COMMITTED_ATTACHMENTS_DIR = Path(__file__).resolve().parent.parent / "static" / "attachments"


def _sanitize_filename(filename: str) -> str:
    base = Path(filename or "attachment.bin").name
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", base).strip("._")
    return cleaned[:120] or "attachment.bin"


@dataclass
class StagedAttachmentItem:
    staging_id: str
    tenant_id: str
    is_ephemeral: bool
    filename: str
    mime_type: str
    size_bytes: int
    sha256: str
    staged_path: Path
    created_at_epoch: float
    expires_at: datetime

    def to_preview_dict(self) -> dict[str, Any]:
        return {
            "staging_id": self.staging_id,
            "filename": self.filename,
            "mime_type": self.mime_type,
            "size_bytes": self.size_bytes,
            "sha256": self.sha256,
            "state": "staged_uncommitted",
            "expires_at": self.expires_at.isoformat(),
        }

    def to_committed_meta(self, committed_url: Optional[str] = None) -> dict[str, Any]:
        return {
            "staging_id": self.staging_id,
            "filename": self.filename,
            "mime_type": self.mime_type,
            "size_bytes": self.size_bytes,
            "sha256": self.sha256,
            "url": committed_url,
        }


class AttachmentStagingService:
    """Concurrency-safe, tenant-isolated attachment inbox staging manager.

    - Stages uploaded files/images into an uncommitted composer preview state without
      auto-sending any message.
    - Guarantees strict tenant scoping: Tenant A can never inspect, claim, or commit
      Tenant B's `staging_id`.
    - Supports two-phase atomic commit (`claim_for_bundle` -> `finalize_commit` or `rollback_claim`)
      so a failed LLM/DB transaction leaves staged items intact rather than losing user files.
    """

    def __init__(self) -> None:
        self._items: dict[str, StagedAttachmentItem] = {}
        self._in_flight: set[str] = set()
        self._tenant_locks: dict[str, asyncio.Lock] = {}
        self._global_lock = asyncio.Lock()

    async def _get_tenant_lock(self, tenant_id: str) -> asyncio.Lock:
        async with self._global_lock:
            lock = self._tenant_locks.get(tenant_id)
            if lock is None:
                lock = asyncio.Lock()
                self._tenant_locks[tenant_id] = lock
            return lock

    def sweep_expired_sync(self) -> int:
        now_ts = time.time()
        expired_ids = [
            sid
            for sid, item in self._items.items()
            if sid not in self._in_flight and (now_ts - item.created_at_epoch) > STAGING_TTL_SECONDS
        ]
        for sid in expired_ids:
            item = self._items.pop(sid, None)
            if item and item.staged_path.exists():
                try:
                    item.staged_path.unlink(missing_ok=True)
                except OSError:
                    pass
        return len(expired_ids)

    async def stage_upload(
        self,
        *,
        tenant: TenantContext,
        upload: UploadFile,
    ) -> StagedAttachmentItem:
        self.sweep_expired_sync()
        raw_name = _sanitize_filename(upload.filename or "attachment")
        ext = Path(raw_name).suffix.lower()
        if ext not in ALLOWED_EXTENSIONS:
            raise AppException(
                title="Unsupported Attachment Type",
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"Attachment extension '{ext or 'unknown'}' is not permitted.",
                type_url="https://api.pingo.app/errors/unsupported-attachment",
            )

        data = await upload.read()
        if not data:
            raise AppException(
                title="Empty Attachment",
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded attachment file cannot be empty.",
                type_url="https://api.pingo.app/errors/empty-attachment",
            )
        if len(data) > MAX_ATTACHMENT_BYTES:
            raise AppException(
                title="Attachment Too Large",
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Attachment exceeds the 15 MB limit.",
                type_url="https://api.pingo.app/errors/attachment-too-large",
            )

        guessed_mime, _ = mimetypes.guess_type(raw_name)
        mime_type = (upload.content_type or guessed_mime or "application/octet-stream").strip()
        sha256_hex = hashlib.sha256(data).hexdigest()

        t_lock = await self._get_tenant_lock(tenant.tenant_id)
        async with t_lock:
            active_for_tenant = [
                it for it in self._items.values() if it.tenant_id == tenant.tenant_id
            ]
            if len(active_for_tenant) >= MAX_STAGED_PER_TENANT:
                raise AppException(
                    title="Staging Inbox Full",
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Maximum of {MAX_STAGED_PER_TENANT} uncommitted staged attachments reached.",
                    type_url="https://api.pingo.app/errors/staging-limit",
                )

            staging_id = uuid4().hex
            tenant_dir = STAGED_ROOT_DIR / tenant.storage_bucket_key
            tenant_dir.mkdir(parents=True, exist_ok=True)
            staged_path = tenant_dir / f"{staging_id}_{raw_name}"
            staged_path.write_bytes(data)

            now_epoch = time.time()
            expires_at = datetime.now(timezone.utc) + timedelta(seconds=STAGING_TTL_SECONDS)

            item = StagedAttachmentItem(
                staging_id=staging_id,
                tenant_id=tenant.tenant_id,
                is_ephemeral=tenant.is_ephemeral,
                filename=raw_name,
                mime_type=mime_type,
                size_bytes=len(data),
                sha256=sha256_hex,
                staged_path=staged_path,
                created_at_epoch=now_epoch,
                expires_at=expires_at,
            )
            self._items[staging_id] = item
            return item

    async def list_staged_for_tenant(self, tenant: TenantContext) -> list[StagedAttachmentItem]:
        self.sweep_expired_sync()
        t_lock = await self._get_tenant_lock(tenant.tenant_id)
        async with t_lock:
            return [
                it
                for sid, it in self._items.items()
                if it.tenant_id == tenant.tenant_id and sid not in self._in_flight
            ]

    async def claim_for_bundle(
        self,
        *,
        tenant: TenantContext,
        staging_ids: Optional[list[str]] = None,
    ) -> list[StagedAttachmentItem]:
        """Atomically locks staged items belonging strictly to `tenant` for a bundled message send."""
        self.sweep_expired_sync()
        t_lock = await self._get_tenant_lock(tenant.tenant_id)
        async with t_lock:
            if staging_ids is not None and len(staging_ids) > 0:
                claimed: list[StagedAttachmentItem] = []
                for sid in staging_ids:
                    clean_sid = sid.strip()
                    if not clean_sid:
                        continue
                    item = self._items.get(clean_sid)
                    if item is None or item.tenant_id != tenant.tenant_id:
                        raise AppException(
                            title="Staged Attachment Not Found",
                            status_code=status.HTTP_404_NOT_FOUND,
                            detail=f"Staged attachment '{clean_sid}' was not found in your session.",
                            type_url="https://api.pingo.app/errors/staged-attachment-not-found",
                        )
                    if clean_sid in self._in_flight:
                        raise AppException(
                            title="Attachment Already In Flight",
                            status_code=status.HTTP_409_CONFLICT,
                            detail=f"Staged attachment '{clean_sid}' is already being committed.",
                            type_url="https://api.pingo.app/errors/staged-attachment-conflict",
                        )
                    claimed.append(item)
                for it in claimed:
                    self._in_flight.add(it.staging_id)
                return claimed

            # Default inbox behavior: bundle all currently staged attachments for this tenant
            auto_claimed = [
                it
                for sid, it in self._items.items()
                if it.tenant_id == tenant.tenant_id and sid not in self._in_flight
            ]
            for it in auto_claimed:
                self._in_flight.add(it.staging_id)
            return auto_claimed

    async def finalize_commit(
        self,
        *,
        tenant: TenantContext,
        claimed_items: list[StagedAttachmentItem],
    ) -> list[dict[str, Any]]:
        """Promotes claimed staged files after DB transaction succeeds (or cleans ephemeral staged files)."""
        committed_meta: list[dict[str, Any]] = []
        t_lock = await self._get_tenant_lock(tenant.tenant_id)
        async with t_lock:
            for it in claimed_items:
                self._in_flight.discard(it.staging_id)
                self._items.pop(it.staging_id, None)
                committed_url: Optional[str] = None
                try:
                    if not tenant.is_ephemeral and it.staged_path.exists():
                        dest_dir = COMMITTED_ATTACHMENTS_DIR / tenant.storage_bucket_key
                        dest_dir.mkdir(parents=True, exist_ok=True)
                        dest_name = f"{it.staging_id}_{it.filename}"
                        dest_path = dest_dir / dest_name
                        it.staged_path.replace(dest_path)
                        committed_url = f"/static/attachments/{tenant.storage_bucket_key}/{dest_name}"
                    elif it.staged_path.exists():
                        # Ephemeral session: clean up staged file from disk on commit
                        it.staged_path.unlink(missing_ok=True)
                except OSError as exc:
                    logger.warning("[StagingService] File finalize warning: %s", exc)
                committed_meta.append(it.to_committed_meta(committed_url=committed_url))
        return committed_meta

    async def rollback_claim(
        self,
        *,
        tenant: TenantContext,
        claimed_items: list[StagedAttachmentItem],
    ) -> None:
        """Releases in-flight locks if downstream LLM or DB transaction fails, preserving staged preview."""
        t_lock = await self._get_tenant_lock(tenant.tenant_id)
        async with t_lock:
            for it in claimed_items:
                self._in_flight.discard(it.staging_id)

    def clear_all_for_testing(self) -> None:
        for it in self._items.values():
            try:
                if it.staged_path.exists():
                    it.staged_path.unlink(missing_ok=True)
            except OSError:
                pass
        self._items.clear()
        self._in_flight.clear()


attachment_staging_service = AttachmentStagingService()
