# Specification: Pingo Backend AI Gateway & Sync Service

## 1. Executive Summary & Purpose
The Pingo Backend Service (`apps/server`) serves as the secure, thin cloud companion for the Pingo mobile app. Following the **Offline-First** and **Private-by-Default** principles outlined in `🔔 Pingo.md`:
- Secrets (Gemini API keys, database credentials) are strictly kept on the server and never exposed to the client.
- Provides low-latency NLP parsing for English, Bangla, and Banglish input into structured reminder JSON.
- Provides encrypted cloud sync and backup for authenticated user reminders and document metadata.

---

## 2. Technology Stack & Architectural Standards
- **Runtime & Language**: Node.js (v22 / v20 LTS) with TypeScript (`strict: true`).
- **Web Framework**: Express.js with modular Clean Architecture (`routes/`, `controllers/`, `services/`, `middlewares/`, `config/`).
- **Validation**: **Zod** on all system boundaries (HTTP request bodies, query params, and `.env` variables).
- **ORM & Database**: **Prisma ORM** targeting PostgreSQL with explicit foreign keys, indexes, audit timestamps (`createdAt`, `updatedAt`, `deletedAt`), and migration safety.
- **AI Integration**: Google Gemini API (`@google/genai` or `@google/generative-ai`) utilizing JSON schema mode for deterministic output.
- **Security & Ops**:
  - `helmet` for HTTP security headers.
  - `cors` with explicit client origin whitelist.
  - `express-rate-limit` for DDoS / brute-force protection.
  - Centralized typed error handler with RFC 7807 Problem Details.

---

## 3. Core Database Schemas (Prisma)

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

enum PlanTier {
  FREE
  PRO
}

enum ReminderCategory {
  GENERAL
  MEDICINE
  BILL
  WORK
  PERSONAL
  BIRTHDAY
}

enum ReminderPriority {
  NORMAL
  IMPORTANT
  URGENT
}

model User {
  id            String         @id @default(uuid())
  phoneNumber   String?        @unique
  email         String?        @unique
  fullName      String?
  avatarUrl     String?
  plan          PlanTier       @default(FREE)
  createdAt     DateTime       @default(now())
  updatedAt     DateTime       @updatedAt
  deletedAt     DateTime?

  reminders     Reminder[]
  vaultItems    VaultItem[]

  @@index([email])
  @@index([phoneNumber])
}

model Reminder {
  id            String            @id @default(uuid())
  userId        String
  clientLocalId String?           // ID generated on device during offline creation
  title         String
  notes         String?
  dueAt         DateTime
  originalTz    String            @default("Asia/Dhaka")
  category      ReminderCategory  @default(GENERAL)
  priority      ReminderPriority  @default(NORMAL)
  repeatRule    String?           // e.g. "FREQ=DAILY;BYHOUR=21"
  isDone        Boolean           @default(false)
  completedAt   DateTime?
  version       Int               @default(1)
  createdAt     DateTime          @default(now())
  updatedAt     DateTime          @updatedAt
  deletedAt     DateTime?         // Soft delete for reliable two-way sync

  user          User              @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, clientLocalId])
  @@index([userId, dueAt])
  @@index([userId, isDone])
}

model VaultItem {
  id            String         @id @default(uuid())
  userId        String
  clientLocalId String?
  title         String
  category      String         // "Identity", "Finance", "Health", "Education"
  expiresAt     DateTime?
  reminderDays  Int[]          // e.g. [90, 30, 7]
  fileUrl       String?        // Encrypted blob URL
  fileHash      String?
  metadataJson  Json?
  version       Int            @default(1)
  createdAt     DateTime       @default(now())
  updatedAt     DateTime       @updatedAt
  deletedAt     DateTime?

  user          User           @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, clientLocalId])
  @@index([userId, expiresAt])
}
```

---

## 4. API Endpoint Contracts

### 4.1 AI Natural Language Reminder Extraction
- **Endpoint**: `POST /api/v1/ai/parse-reminder`
- **Request Body**:
```json
{
  "text": "Kal bikel 5tay mayer sathe doctor",
  "clientTimestamp": "2026-11-06T17:00:00.000Z",
  "timeZone": "Asia/Dhaka",
  "language": "bn-BD"
}
```
- **Response** (`200 OK`):
```json
{
  "success": true,
  "data": {
    "title": "Doctor appointment with Mom",
    "dueAt": "2026-11-07T11:00:00.000Z",
    "localTimeFormatted": "Sat, Nov 7 at 5:00 PM",
    "category": "PERSONAL",
    "priority": "IMPORTANT",
    "repeatRule": null,
    "confidence": 0.96,
    "needsClarification": false
  }
}
```

### 4.2 Document Expiry & Date Extraction
- **Endpoint**: `POST /api/v1/ai/extract-document-dates`
- **Request Body**:
```json
{
  "ocrText": "PASSPORT OF BANGLADESH ... EXPIRY DATE: 14 AUG 2029 ...",
  "documentType": "PASSPORT"
}
```
- **Response** (`200 OK`):
```json
{
  "success": true,
  "data": {
    "detectedType": "Passport",
    "category": "Identity",
    "expiryDate": "2029-08-14T00:00:00.000Z",
    "suggestedReminders": [
      { "offsetDays": 90, "targetDate": "2029-05-16T00:00:00.000Z" },
      { "offsetDays": 30, "targetDate": "2029-07-15T00:00:00.000Z" },
      { "offsetDays": 7, "targetDate": "2029-08-07T00:00:00.000Z" }
    ],
    "confidence": 0.98
  }
}
```

### 4.3 Authentication
- `POST /api/v1/auth/request-otp`: Sends 6-digit verification code.
- `POST /api/v1/auth/verify-otp`: Validates code, creates or fetches user, returns JWT.

### 4.4 Two-Way Sync
- `POST /api/v1/sync/push`: Batch upload local offline changes.
- `GET /api/v1/sync/pull?since=<timestamp>`: Fetch changes modified since last sync.

