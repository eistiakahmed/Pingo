from dataclasses import dataclass, field
from datetime import datetime, timezone
import hashlib
import re
import time
from typing import Any, Optional
from uuid import UUID, uuid4

from fastapi import Depends, Header, status
from app.core.exceptions import AppException
from app.core.security import get_current_user_optional
from app.models.user import User

SAFE_SESSION_RE = re.compile(r"^[A-Za-z0-9_.:@-]{3,128}$")
EPHEMERAL_TTL_SECONDS = 24 * 3600  # 24 hours


@dataclass(frozen=True)
class TenantContext:
    """Immutable tenant isolation descriptor enforced across all assistant & staging queries."""

    tenant_id: str
    is_ephemeral: bool
    authenticated_user_id: Optional[UUID] = None

    @property
    def scope_label(self) -> str:
        return "ephemeral" if self.is_ephemeral else "authenticated"

    @property
    def storage_bucket_key(self) -> str:
        return hashlib.sha256(self.tenant_id.encode("utf-8")).hexdigest()[:32]


def resolve_tenant_context(
    current_user: Optional[User],
    *,
    form_user_id: Optional[str] = None,
    header_session_id: Optional[str] = None,
) -> TenantContext:
    """Resolves a strict, non-overlapping TenantContext.

    1. Authenticated JWT User -> `user:<uuid>` (`is_ephemeral=False`).
       Client-supplied `form_user_id` cannot override an authenticated JWT identity
       (if provided and explicitly referencing a different UUID, reject with 403).
    2. Unauthenticated Caller -> `ephem:<sha256(session_token)>` (`is_ephemeral=True`).
       Segregated into an ephemeral session namespace; can NEVER collide with `user:<uuid>`.
    """
    if current_user is not None and current_user.id is not None:
        if form_user_id and form_user_id.strip():
            candidate = form_user_id.strip()
            # If caller passed a UUID that differs from their JWT sub, block cross-tenant spoofing
            try:
                supplied_uuid = UUID(candidate)
                if supplied_uuid != current_user.id:
                    raise AppException(
                        title="Tenant Mismatch",
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Authenticated user cannot act on behalf of another tenant user_id.",
                        type_url="https://api.pingo.app/errors/tenant-mismatch",
                    )
            except ValueError:
                # Allow non-UUID email matching current_user.email; reject other emails
                if "@" in candidate and candidate.lower() != current_user.email.lower():
                    raise AppException(
                        title="Tenant Mismatch",
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Authenticated user email does not match supplied tenant identifier.",
                        type_url="https://api.pingo.app/errors/tenant-mismatch",
                    )

        return TenantContext(
            tenant_id=f"user:{current_user.id}",
            is_ephemeral=False,
            authenticated_user_id=current_user.id,
        )

    raw_session = (header_session_id or form_user_id or "").strip()
    if not raw_session:
        raise AppException(
            title="Missing Session Identifier",
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unauthenticated requests must supply a valid session_id or user_id.",
            type_url="https://api.pingo.app/errors/missing-session-id",
        )

    if len(raw_session) > 128 or not SAFE_SESSION_RE.match(raw_session):
        raise AppException(
            title="Invalid Session Identifier",
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session identifier must be 3-128 safe alphanumeric characters.",
            type_url="https://api.pingo.app/errors/invalid-session-id",
        )

    digest = hashlib.sha256(f"pingo-ephemeral:{raw_session}".encode("utf-8")).hexdigest()[:40]
    return TenantContext(
        tenant_id=f"ephem:{digest}",
        is_ephemeral=True,
        authenticated_user_id=None,
    )


async def get_header_tenant_context(
    current_user: Optional[User] = Depends(get_current_user_optional),
    x_session_id: Optional[str] = Header(default=None, alias="X-Session-ID"),
) -> TenantContext:
    """FastAPI dependency for JSON endpoints using Authorization Bearer or X-Session-ID."""
    return resolve_tenant_context(
        current_user,
        header_session_id=x_session_id,
    )


@dataclass
class EphemeralRecord:
    id: str
    tenant_id: str
    kind: str  # "reminder" | "documentation" | "message"
    payload: dict[str, Any]
    created_at: float = field(default_factory=time.time)


class EphemeralTenantStore:
    """Segregated, TTL-bounded in-memory session pool for unauthenticated callers.

    Guarantees zero database pollution and zero cross-leakage between unauthenticated
    ephemeral sessions and authenticated PostgreSQL tenant profiles.
    """

    def __init__(self, ttl_seconds: int = EPHEMERAL_TTL_SECONDS) -> None:
        self._ttl = ttl_seconds
        self._buckets: dict[str, list[EphemeralRecord]] = {}

    def _prune_expired(self) -> None:
        cutoff = time.time() - self._ttl
        empty_keys = []
        for tenant_id, records in self._buckets.items():
            kept = [r for r in records if r.created_at >= cutoff]
            if kept:
                self._buckets[tenant_id] = kept
            else:
                empty_keys.append(tenant_id)
        for k in empty_keys:
            self._buckets.pop(k, None)

    def add_record(self, tenant: TenantContext, kind: str, payload: dict[str, Any]) -> str:
        if not tenant.is_ephemeral:
            raise ValueError("Authenticated tenants must persist to PostgreSQL, not EphemeralTenantStore")
        self._prune_expired()
        rec_id = str(uuid4())
        rec = EphemeralRecord(
            id=rec_id,
            tenant_id=tenant.tenant_id,
            kind=kind,
            payload={
                **payload,
                "id": rec_id,
                "tenant_id": tenant.tenant_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
        )
        self._buckets.setdefault(tenant.tenant_id, []).append(rec)
        return rec_id

    def list_records(self, tenant: TenantContext, kind: Optional[str] = None) -> list[dict[str, Any]]:
        self._prune_expired()
        if not tenant.is_ephemeral:
            return []
        items = self._buckets.get(tenant.tenant_id, [])
        return [
            dict(r.payload)
            for r in items
            if r.tenant_id == tenant.tenant_id and (kind is None or r.kind == kind)
        ]

    def auto_complete_due_reminders(self, tenant: TenantContext, now_utc: Optional[datetime] = None) -> int:
        """Enforces irreversible scheduled -> completed transitions for due ephemeral reminders."""
        self._prune_expired()
        now = now_utc or datetime.now(timezone.utc)
        transitioned = 0
        for rec in self._buckets.get(tenant.tenant_id, []):
            if rec.kind != "reminder" or rec.payload.get("state") == "completed":
                continue
            raw_due = rec.payload.get("reminder_time")
            if isinstance(raw_due, str):
                try:
                    due_dt = datetime.fromisoformat(raw_due)
                    if due_dt <= now:
                        rec.payload["state"] = "completed"
                        rec.payload["completed_at"] = now.isoformat()
                        transitioned += 1
                except ValueError:
                    pass
        return transitioned

    def clear_all_for_testing(self) -> None:
        self._buckets.clear()


ephemeral_tenant_store = EphemeralTenantStore()
