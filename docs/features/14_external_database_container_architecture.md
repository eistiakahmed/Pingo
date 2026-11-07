# 14. External Database Container Architecture & Network Isolation

## Architectural Context
Pingo previously ran with an embedded single-tenant PostgreSQL container (`pingo-postgres`) on port 5433. To streamline resources and align with multi-service infrastructure while maintaining bank-grade isolation and zero-knowledge guarantees, `pingo-api` was transitioned to connect to an external PostgreSQL 16 container (`dd-postgres`).

---

## 1. Security & Isolation Model

### A. Network Segregation (Docker Internal Network)
- **Network Name**: `dokaandigit-full-monorepo_default`
- **Internal DNS Alias**: `dd-postgres`
- **Port Exposure**: `pingo-api` communicates with `dd-postgres` directly over the internal Docker network on port `5432`. No database ports need to be exposed to public or non-containerized hosts.

### B. User & Database Separation
- **Dedicated User**: `pingo_user`
- **Dedicated Database**: `pingo_db`
- **Access Boundary**:
  - `pingo_user` owns `pingo_db` and has exclusive privileges over it.
  - Cross-database access is prohibited by PostgreSQL role constraints.

### C. Zero-Knowledge Cryptographic Invariant
- Even though the physical database engine is shared at the container level with other projects, zero plaintext reminder or vault data is ever sent to or stored in `pingo_db`.
- All reminders and vault items are encrypted client-side using `AES-256-GCM` before synchronization. The database only ever receives base64-encoded `ciphertext`, `iv`, and `auth_tag`.

---

## 2. Infrastructure Changes

### `docker-compose.yml`
```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: pingo-api
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      APP_ENV: "development"
      PORT: 8000
      HOST: "0.0.0.0"
      DATABASE_URL: "${DATABASE_URL:-postgresql+asyncpg://pingo_user:pingo_password@dd-postgres:5432/pingo_db}"
      AI_PROVIDER: "${AI_PROVIDER:-deepseek}"
      DEEPSEEK_API_KEY: "${DEEPSEEK_API_KEY:-}"
      GEMINI_API_KEY: "${GEMINI_API_KEY:-}"
      SECRET_KEY: "${SECRET_KEY:-pingo-development-secret-key-at-least-32-chars-long}"
    volumes:
      - ./apps/server/app:/app/app
      - ./apps/server/alembic:/app/alembic
    networks:
      - dokaandigit_net
    command: >
      sh -c "alembic upgrade head &&
             uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --reload-dir app"

networks:
  dokaandigit_net:
    external: true
    name: dokaandigit-full-monorepo_default
```

---

## 3. Schema & Migrations
Upon container startup, Alembic automatically checks and executes outstanding migrations:
- **Migration ID**: `001_initial_schema`
- **Tables Provisioned**:
  - `alembic_version`
  - `users`
  - `encrypted_reminders`
  - `encrypted_vault_items`

---

## 4. Verification Suite
1. **Pytest Suite (`apps/server/tests/`)**: 21 passed (100%).
2. **Mobile Flutter Suite (`apps/mobile/test/`)**: 12 passed (100%), including `live_api_integration_test.dart` asserting against `http://127.0.0.1:8000`.
3. **Physical Container Verification**: Direct query verification in `dd-postgres` confirming row persistence in `users` and `encrypted_reminders`.
