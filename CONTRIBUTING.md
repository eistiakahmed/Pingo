# Contributing to Pingo

Thank you for your interest in contributing to **Pingo**! To maintain production-grade quality, security, and consistent architecture across our monorepo, all contributors must adhere to the following standards.

---

## 1. Monorepo Workflow

Pingo uses a **DokaanDigit-style Monorepo** architecture:
- `apps/mobile`: Flutter mobile client (presentation, domain, data per feature).
- `apps/server`: Stateless AI gateway and backend services.
- `apps/web`: Web dashboard and companion tools.
- `packages/*`: Cross-platform shared logic and models.
- `docs/*`: Feature specs, ADRs, and API references.

---

## 2. Branching & PR Rules

1. Never commit directly to `main` or `develop`.
2. Branch naming convention:
   - `feature/<name>`: New feature work (e.g. `feature/home-screen-ui`).
   - `fix/<name>`: Bug fixes (e.g. `fix/alarm-reboot-receiver`).
   - `docs/<name>`: Documentation additions.
3. Commits must follow **Conventional Commits**:
   - `feat(...)`: New user-facing capability.
   - `fix(...)`: Bug fix.
   - `ui(...)`: Visual or design enhancement.
   - `docs(...)`: Documentation only.
   - `refactor(...)`: Code changes without behavior changes.
4. Every Pull Request must pass the automated GitHub CI checks (`.github/workflows/ci.yml`) before being merged.

---

## 3. Code Standards & Zero Blind Coding

- **Architecture Integrity**: Never dump business logic into UI widgets or root screen classes. Follow Clean Architecture (Presentation -> Domain -> Data).
- **Bangla Typography**: Ensure all UI elements handling Bangla use adequate line heights (1.45x) and support standard Bengali unicode and transliteration.
- **Defensive Engineering**: Strictly validate all system boundaries and API schemas. Zero hardcoded credentials or magic numbers.
