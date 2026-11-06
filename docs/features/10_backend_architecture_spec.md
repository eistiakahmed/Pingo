# Specification: Pingo Backend AI Gateway & Sync Service (FastAPI)

## 1. Executive Summary & Purpose
The Pingo Backend Service (`apps/server`) serves as the secure, high-performance cloud companion for the Pingo mobile app. Following the **Offline-First**, **AI-Native**, and **Private-by-Default (Zero-Knowledge)** principles:
- Secrets (Gemini API keys, database credentials) are strictly kept on the server and never exposed to the client.
- Provides low-latency NLP parsing for English, Bangla, and Banglish input into structured reminder JSON via Google Gemini API.
- Provides encrypted zero-knowledge cloud sync and backup for authenticated user reminders and document metadata (`ciphertext`, `iv`, `authTag`, `keyVersion`).
- Generates automatic interactive OpenAPI documentation (`/docs`) accessible for frontend integration and client schema generation.

---

## 2. Technology Stack & Architectural Standards
- **Runtime & Language**: Python 3.12+ with strict type hints (`mypy` / `pyright` compliant).
- **Web Framework**: **FastAPI** with ASGI runner (`uvicorn`).
- **Validation & Serialization**: **Pydantic v2** (`pydantic-settings` for `.env` config, `BaseModel` for schemas).
- **ORM & Database**: **SQLAlchemy 2.0 (Async)** targeting PostgreSQL with `asyncpg`, managed by **Alembic** migrations. Includes explicit foreign keys, composite indexes, audit timestamps (`created_at`, `updated_at`, `deleted_at`), and ACID compliance.
- **AI Integration**: Google Gemini API via official `google-genai` Python SDK with structured JSON output schema mode.
- **Security & Ops**:
  - CORS middleware with strict origin whitelist.
  - Rate limiting (slowapi / redis-ready) for DDoS / brute-force protection.
  - Centralized RFC 7807 Problem Details exception handlers.
  - Non-root execution and Docker containerization readiness.

---

## 3. Database Schema Models (SQLAlchemy 2.0 Async)

```python
import enum
from datetime import datetime
from uuid import UUID, uuid4
from sqlalchemy import String, Text, Boolean, Integer, DateTime, ForeignKey, Index, Enum
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase):
    pass

class PlanTier(str, enum.Enum):
    FREE = "FREE"
    PRO = "PRO"

class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    plan_tier: Mapped[PlanTier] = mapped_column(Enum(PlanTier), default=PlanTier.FREE, nullable=False)
    client_salt: Mapped[str] = mapped_column(String(128), nullable=False) # For client-side E2EE derivation
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    reminders: Mapped[list["EncryptedReminder"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    vault_items: Mapped[list["EncryptedVaultItem"]] = relationship(back_populates="user", cascade="all, delete-orphan")

class EncryptedReminder(Base):
    __tablename__ = "encrypted_reminders"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Zero-Knowledge Cryptographic Envelope
    ciphertext: Mapped[str] = mapped_column(Text, nullable=False)
    iv: Mapped[str] = mapped_column(String(64), nullable=False)
    auth_tag: Mapped[str] = mapped_column(String(64), nullable=False)
    key_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    algorithm: Mapped[str] = mapped_column(String(32), default="AES-256-GCM", nullable=False)

    # Server-known query metadata for Push Notifications only (No text!)
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True) # Soft delete for sync

    user: Mapped["User"] = relationship(back_populates="reminders")

    __table_args__ = (
        Index("ix_encrypted_reminders_user_updated", "user_id", "updated_at"),
        Index("ix_encrypted_reminders_due_active", "due_at", "is_completed"),
    )

class EncryptedVaultItem(Base):
    __tablename__ = "encrypted_vault_items"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    item_type: Mapped[str] = mapped_column(String(32), nullable=False) # NOTE, CARD, PASSWORD, DOCUMENT

    # Zero-Knowledge Cryptographic Envelope
    ciphertext: Mapped[str] = mapped_column(Text, nullable=False)
    iv: Mapped[str] = mapped_column(String(64), nullable=False)
    auth_tag: Mapped[str] = mapped_column(String(64), nullable=False)
    key_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    algorithm: Mapped[str] = mapped_column(String(32), default="AES-256-GCM", nullable=False)

    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped["User"] = relationship(back_populates="vault_items")

    __table_args__ = (
        Index("ix_encrypted_vault_user_updated", "user_id", "updated_at"),
    )
```

---

## 4. API Endpoints Specification

### 4.1 System & Health
- `GET /health` -> `{"status": "healthy", "service": "pingo-backend", "version": "1.0.0"}`

### 4.2 AI Gateway Module (`/api/v1/ai`)
- `POST /api/v1/ai/parse-reminder`
  - **Request Body (Pydantic)**:
    ```json
    {
      "text": "কাল সকাল ৯টায় ডেন্টিস্টের কাছে যেতে হবে",
      "timezone": "Asia/Dhaka",
      "reference_date": "2026-11-06T15:00:00Z"
    }
    ```
  - **Gemini System Instruction**:
    - Extract title, due date/time (ISO 8601 UTC based on user timezone and relative words like "কাল", "পরশু", "tomorrow", "next Monday"), category (`GENERAL`, `MEDICINE`, `BILL`, `WORK`, `PERSONAL`, `BIRTHDAY`), priority (`NORMAL`, `HIGH`, `URGENT`), and confidence score (0.0 - 1.0).
  - **Response Body (`200 OK`)**:
    ```json
    {
      "success": true,
      "data": {
        "title": "Dentist Appointment",
        "due_at": "2026-11-07T03:00:00Z",
        "category": "MEDICINE",
        "priority": "HIGH",
        "confidence": 0.95
      }
    }
    ```

### 4.3 Zero-Knowledge Sync Module (`/api/v1/sync`)
- `POST /api/v1/sync/push`
  - Accepts batch of encrypted reminders and vault items with client versioning.
  - Server performs upsert based on `(user_id, id)`. Resolves conflict using Last-Write-Wins based on client `updated_at` / version.
- `GET /api/v1/sync/pull?since={ISO_TIMESTAMP}`
  - Returns delta of items modified or soft-deleted after `since`.

---

## 5. Security & Privacy Guarantees
1. **Zero-Knowledge Core**: Server has zero decryption keys. Decryption is strictly client-side.
2. **Key Security**: Gemini API keys never leak into logs or client responses.
3. **Strict Validation**: All endpoints reject unrecognized fields or invalid types with RFC 7807 problem details.
