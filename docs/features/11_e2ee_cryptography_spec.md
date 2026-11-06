# Specification: Pingo End-to-End Encryption (E2EE) Architecture

## 1. Zero-Knowledge Security Principle
Every user text, note, reminder title, and vault document in Pingo must be **End-to-End Encrypted (E2EE)**. 

- **Zero-Knowledge**: The cloud server and database store only encrypted ciphertext, initialization vectors (IV), and authentication tags. 
- **Keys Never Leave the Device**: Encryption keys are derived locally on the user's phone from their secure credentials (biometrics / PIN / master passphrase) using Argon2id / PBKDF2 with high iteration counts.
- **Data at Rest & in Transit**: Even if the cloud database is breached, no human, database admin, or third party can read a single word of the user's reminders or documents.

---

## 2. Monorepo E2EE Architecture & Directory Layout

```
Pingo/
├── packages/
│   └── e2ee/                            # Dedicated Cross-Platform E2EE Crypto Engine
│       ├── package.json
│       ├── tsconfig.json
│       └── src/
│           ├── index.ts                 # Public crypto API
│           ├── ciphers/
│           │   └── aes_gcm.ts           # AES-256-GCM authenticated encryption
│           ├── kdf/
│           │   └── key_derivation.ts    # PBKDF2 / Argon2 key derivation
│           └── types/
│               └── encrypted_payload.ts # Standard E2EE payload schema
├── apps/
│   ├── mobile/
│   │   └── lib/core/crypto/
│   │       ├── e2ee_service.dart        # Flutter on-device AES-256-GCM cipher
│   │       └── secure_key_storage.dart  # Android Keystore / iOS Keychain binding
│   └── server/
│       └── src/modules/e2ee/
│           ├── e2ee.model.ts            # Zero-knowledge encrypted envelope schema
│           └── e2ee.validator.ts        # Ciphertext format & auth-tag validation
```

---

## 3. Cryptographic Primitives & Specifications

| Dimension | Standard Specification |
| :--- | :--- |
| **Symmetric Cipher** | **AES-256-GCM** (Galois/Counter Mode with 128-bit authentication tag) |
| **Key Derivation (KDF)** | **PBKDF2-HMAC-SHA256** (100,000+ iterations) / **Argon2id** |
| **Nonce / IV** | 96-bit (12 bytes) cryptographically secure random bytes per item (Never reused) |
| **Salt** | 128-bit (16 bytes) CSPRNG salt generated per user account |
| **Integrity / MAC** | Poly1305 / GCM 16-byte Authentication Tag (Detects any tampering) |

---

## 4. Encrypted Data Schema (The Encrypted Envelope)

Every single word, task, title, or note stored in the database or sent over sync uses this immutable structure:

```json
{
  "ciphertext": "pL9x2fV+kM8sN...",
  "iv": "7hY3kLm90Pq1",
  "authTag": "bX9zK2lQ...",
  "keyVersion": 1,
  "algorithm": "AES-256-GCM"
}
```

- When the mobile app saves a reminder:
  1. Plaintext: `"Doctor with Mom tomorrow at 5 PM"`
  2. Device encrypts with local MEK: `Ciphertext = Encrypt(Plaintext, MEK, IV)`
  3. Device saves ciphertext locally and syncs only the encrypted envelope to the server.
  4. Server stores `ciphertext` in PostgreSQL. Server has **zero ability** to decrypt it.
  5. When reading, only the user's authenticated phone with the matching local key can decrypt it.

