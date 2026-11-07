# Feature Specification: Mobile API Integration & Zero-Knowledge Sync

## 1. Overview & Objective
This specification formalizes the mobile client-to-backend API integration for Pingo, connecting the Flutter frontend (`apps/mobile`) to the FastAPI backend Gateway (`apps/server`) with end-to-end zero-knowledge encryption, authenticated session management, and automated test coverage.

---

## 2. Architecture & Networking Layer

### 2.1 API Configuration & Discovery (`ApiConfig`)
- **Android Emulator**: `http://10.0.2.2:8000`
- **iOS Simulator / Desktop / Web**: `http://127.0.0.1:8000`
- **Dynamic Override**: Reads `PINGO_API_URL` environment variable at compile/runtime.

### 2.2 Network Client (`ApiClient`)
- Centralized HTTP client wrapping `http.Client`.
- Automatically attaches `Authorization: Bearer <token>` when authenticated.
- Enforces `Content-Type: application/json; charset=utf-8` and decodes payloads via `utf8.decode(response.bodyBytes)` to guarantee lossless bilingual Bengali/Banglish parsing.
- 15-second network timeout with automatic fallback to typed `ApiException`.

### 2.3 Error Handling & RFC 7807 Problem Details
The client maps backend RFC 7807 responses to `ApiException`:
- `statusCode`: HTTP status code (e.g., 401, 409, 422, 429).
- `title`: Problem title (e.g., `Authentication Failed`, `Rate Limit Exceeded`).
- `detail`: User-friendly descriptive error message.
- `typeUrl`: Reference documentation URI.

---

## 3. Endpoints & Data Contracts

| Method | Endpoint | Auth | Purpose |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | None | Gateway health verification |
| `POST` | `/api/v1/auth/register` | None (Rate Limited) | Creates account with client-generated 16-byte salt |
| `POST` | `/api/v1/auth/login` | None (Rate Limited) | Constant-time Argon2id credential verification; returns JWT |
| `GET` | `/api/v1/auth/me` | Bearer JWT | Returns current authenticated profile and salt |
| `POST` | `/api/v1/ai/parse-reminder` | None (Rate Limited) | Converts natural language utterance into structured JSON |
| `POST` | `/api/v1/sync/push` | Bearer JWT | Atomic bulk upsert for client-encrypted reminders & vault items |
| `GET` | `/api/v1/sync/pull` | Bearer JWT | Delta query retrieving items updated since `since` timestamp |

---

## 4. State Management (Flutter Riverpod)

- **`apiClientProvider`**: Singleton HTTP client lifecycle manager.
- **`authApiServiceProvider`**: Gateway authentication operations.
- **`syncApiServiceProvider`**: Zero-Knowledge delta synchronization service.
- **`aiApiServiceProvider`**: Natural language parser service.
- **`authProvider`**: `StateNotifier<AuthState>` managing authentication state, active session, and error banners in `PingoLoginScreen` and `PingoSignupScreen`.
- **`homeReminderProvider`**: Manages local reminder list with `pushToServer()` and `pullFromServer()` methods.

---

## 5. Automated Verification & Testing Matrix

- **Unit Tests**:
  - `apps/mobile/test/network/api_client_test.dart`: Request serialization, Bearer auth, timeouts, RFC 7807 errors.
  - `apps/mobile/test/auth/auth_api_service_test.dart`: Register, login, profile fetch, health check.
  - `apps/mobile/test/sync/sync_api_service_test.dart`: Push & pull delta synchronization.
  - `apps/mobile/test/ai/ai_api_service_test.dart`: Bilingual Bengali text parsing.
- **Live Integration Tests**:
  - `apps/mobile/test/integration/live_api_integration_test.dart`: End-to-end user lifecycle and sync against live Docker container on `127.0.0.1:8000`.
- **Backend Tests**:
  - `apps/server/tests/`: 19 tests verifying auth, rate limiting, and atomic upsert.

