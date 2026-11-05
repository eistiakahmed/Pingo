# Pingo Monorepo Architecture Specification

## Overview
This repository uses a production-ready Monorepo architecture inspired by DokaanDigit standards, strictly separating client applications, backend services, shared libraries, and documentation.

```
Pingo/
├── 🔔 Pingo.md                           # Master Product & Technical Document
├── docs/                                  # Specifications, decisions, ADRs
│   ├── architecture/
│   │   └── monorepo_structure.md
│   ├── features/
│   │   └── 01_ui_core_screens.md
│   └── specs/
├── apps/
│   ├── mobile/                            # Flutter Mobile Application (Android/iOS)
│   │   ├── assets/                        # Fonts, Icons, Images
│   │   └── lib/
│   │       ├── core/                      # Global theme, typography, routing, constants
│   │       ├── features/                  # Domain-driven feature modules
│   │       │   ├── home/
│   │       │   ├── confirmation/
│   │       │   ├── reminder_editor/
│   │       │   ├── voice_capture/
│   │       │   ├── calendar/
│   │       │   ├── vault/
│   │       │   └── settings/
│   │       └── shared/                    # Reusable UI components & widgets
│   ├── server/                            # Backend API / AI processing proxy
│   │   └── src/
│   │       ├── config/
│   │       ├── controllers/
│   │       ├── middlewares/
│   │       ├── modules/
│   │       ├── routes/
│   │       └── services/
│   └── web/                               # Web Companion / Landing App
│       └── src/
│           ├── components/
│           ├── hooks/
│           ├── pages/
│           └── styles/
├── packages/
│   ├── shared_models/                     # Shared Dart/Flutter models & entities
│   └── shared_types/                      # Shared JSON Schemas & TypeScript interfaces
└── scripts/                               # Monorepo tooling and build scripts
```

## Layer Responsibilities
- **`apps/mobile`**: Main client with offline-first Flutter application following Clean Architecture (Presentation, Domain, Data per feature).
- **`apps/server`**: Lightweight stateless API proxying AI requests, parsing fallback, and cloud sync.
- **`apps/web`**: Web management and marketing interface.
- **`packages/*`**: Shared business logic, schemas, and contracts to prevent duplication.

