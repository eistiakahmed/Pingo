# Pingo Backend API Gateway & Sync Service

High-performance, asynchronous cloud companion service for Pingo, powered by **Python 3.12+**, **FastAPI**, **Google Gemini 2.0 Flash**, and **SQLAlchemy 2.0 Async (PostgreSQL)**.

---

## 1. Architectural Highlights

- **Zero-Knowledge Core**: All user reminders, notes, and vault items are encrypted on the mobile client via **AES-256-GCM** before synchronization. The database persists only cryptographic envelopes (`ciphertext`, `iv`, `auth_tag`, `key_version`, `algorithm`).
- **AI Natural Language Gateway**: Uses Google Gemini API (`gemini-2.0-flash`) in structured JSON schema mode to parse reminders from English, Bengali (বাংলা), and Banglish.
- **RFC 7807 Problem Details**: Centralized, typed exception handlers producing standard error responses across all endpoints.
- **Auto-generated OpenAPI & Swagger**: Interactive documentation available at `/docs` and `/redoc`.

---

## 2. Directory Structure

```
apps/server/
├── app/
│   ├── main.py                  # ASGI entry point, middlewares, and exception handlers
│   ├── core/
│   │   ├── config.py            # Pydantic Settings (.env schema validation)
│   │   ├── exceptions.py        # RFC 7807 error models
│   │   └── middleware.py        # CORS & Security headers
│   ├── db/
│   │   ├── base.py              # DeclarativeBase
│   │   └── session.py           # Async engine & sessionmaker (asyncpg)
│   ├── models/                  # SQLAlchemy 2.0 Async models (User, EncryptedReminder, EncryptedVaultItem)
│   ├── schemas/                 # Pydantic models (AI schemas, Sync DTOs)
│   ├── services/                # Gemini AI Service & Zero-Knowledge Sync Service
│   └── api/v1/                  # Endpoints (/health, /ai, /sync)
├── tests/                       # Pytest test suite (100% pass)
├── requirements.txt             # Locked dependencies
└── pyproject.toml
```

---

## 3. Getting Started

### Prerequisites
- Python 3.12+
- PostgreSQL (or dockerized Postgres)

### Installation
```bash
# 1. Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Fill in GEMINI_API_KEY and DATABASE_URL
```

### Running the Development Server
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
- Swagger UI: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

### Running Tests
```bash
pytest -v
```
