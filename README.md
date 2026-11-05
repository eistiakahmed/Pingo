# 🔔 Pingo

> ***Say it. Type it. Never forget it.***  
> Your smart memory assistant for reminders, voice notes, and important documents.

[![Pingo Monorepo CI](https://github.com/eistiakahmed/Pingo/actions/workflows/ci.yml/badge.svg)](https://github.com/eistiakahmed/Pingo/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-Android%20%7C%20iOS-02569B?logo=flutter)](https://flutter.dev)
[![Architecture: Monorepo](https://img.shields.io/badge/Architecture-DokaanDigit--Style%20Monorepo-4F46E5)](docs/architecture/monorepo_structure.md)

---

## 📖 Overview

**Pingo** is a human-centric mobile memory assistant engineered to eliminate the friction of traditional reminder apps. Instead of tapping through complex multi-step forms, users capture reminders in **under 5 seconds** through natural speech, typed text, or document photos.

Built **offline-first**, **private-by-default**, and bilingual from Day 1 (**English, Bengali, and Romanized Banglish**).

---

## ⚡ The Four Core Pillars

1. **🔔 Punctual & Resilient Notifications:**
   - 100% offline local scheduling using exact system alarms.
   - Boot receiver persistence ensures reminders fire even after device restart.
   - Custom battery optimization guidance for aggressive vendor Android flavors (Xiaomi, Samsung, Oppo).
   - Rich lock-screen notification actions: **Done**, **Snooze (10m, 1h, tomorrow)**.

2. **💬 Message-to-Reminder (Natural NLP):**
   - Natural language input in Bangla, English, or mixed script (*"Kal bikel 5tay mayer sathe doctor"*).
   - Instant extraction of task title, date, time, and recurrence rule.
   - Interactive **Confirmation Card** allowing one-tap verification before saving.

3. **🎙️ Voice-to-Reminder:**
   - Single-tap floating mic capture with live audio waveform and real-time transcription.
   - Editable transcript safeguards against noisy environments.

4. **📁 Encrypted Document Vault & OCR:**
   - Biometric/PIN-protected vault for passports, IDs, licenses, and prescriptions.
   - On-device OCR detects expiry dates and automatically schedules advance alerts (90d, 30d, 7d).
   - Natural language document retrieval (*"Show my driving license"*).

---

## 🏛️ Monorepo Structure

Pingo follows a DokaanDigit-style monorepo architecture:

```
Pingo/
├── 🔔 Pingo.md                           # Master Product & Technical Plan
├── docs/                                 # Architectural specifications & ADRs
│   ├── architecture/                     # Monorepo and branching guidelines
│   ├── features/                         # UI specifications & component contracts
│   ├── references/                       # API payloads & AI extraction contracts
│   └── specs/                            # Non-functional requirements & metrics
├── apps/
│   ├── mobile/                           # Flutter mobile client (Android & iOS)
│   │   ├── assets/                       # Fonts (Hind Siliguri), icons, images
│   │   └── lib/                          # Clean Architecture (Core, Features, Shared)
│   ├── server/                           # Backend AI gateway & sync services
│   └── web/                              # Web companion & landing app
├── packages/
│   ├── shared_models/                    # Cross-platform Dart domain models
│   └── shared_types/                     # Shared TypeScript schemas & DTOs
└── scripts/                              # CI/CD and developer utility scripts
```

---

## 🌿 Branching Strategy & Development Workflow

To ensure code stability and zero regression:
- **`main`**: Production-ready code only. Direct commits blocked. Merges via approved PRs from `develop`.
- **`develop`**: Central integration branch for ongoing work.
- **`feature/<name>`**: Feature branches (e.g., `feature/home-screen-ui`).
- **`fix/<name>`**: Bug fixes (e.g., `fix/snooze-action-crash`).

All commits must follow **Conventional Commits**:
- `feat(scope): ...`
- `fix(scope): ...`
- `ui(scope): ...`
- `docs(scope): ...`

See [`docs/architecture/branching_strategy.md`](docs/architecture/branching_strategy.md) and [`CONTRIBUTING.md`](CONTRIBUTING.md) for details.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.19+ recommended)
- Android Studio / Xcode
- Git

### Running the Mobile Client
```bash
# Navigate to mobile application
cd apps/mobile

# Install Flutter dependencies
flutter pub get

# Run on connected device or simulator
flutter run
```

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
