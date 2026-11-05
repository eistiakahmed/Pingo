# Git Branching & Release Strategy

This repository enforces a structured GitFlow-adapted branching model designed for clean monorepo development and zero regression.

## 1. Branch Hierarchy

```
main (Production releases only)
  ▲
  │ (Release tags / merge commits)
develop (Integration & staging)
  ▲
  ├── feature/mobile-home-screen
  ├── feature/confirmation-card
  ├── fix/exact-alarm-crash
  └── chore/ci-setup
```

### 1.1 Protected Branches
- **`main`**: Represents production-ready, stable releases. Direct pushes are blocked. Merges occur only via PR from `develop` with all CI checks green.
- **`develop`**: The primary integration branch where all feature and fix PRs land.

### 1.2 Working Branches
- **`feature/<context>`**: New features, UI enhancements, or architecture additions (e.g. `feature/voice-overlay`, `feature/sqlite-storage`).
- **`fix/<bug-description>`**: Bug fixes (e.g. `fix/snooze-notification-timer`).
- **`docs/<doc-subject>`**: Documentation additions and specifications (e.g. `docs/api-specs`).
- **`refactor/<scope>`**: Code refactoring without behavioral alterations.

---

## 2. Commit Message Standard (Conventional Commits)

Every commit must adhere strictly to the Conventional Commits specification:

```
<type>(<scope>): <short description in present tense>

[optional body explaining motivation and architectural tradeoffs]

[optional footer(s) like Closes #12]
```

### Allowed Types:
- `feat`: New feature or user capability.
- `fix`: Bug fix.
- `ui`: Visual styling, layout, typography, or animation adjustment.
- `docs`: Documentation changes only.
- `refactor`: Code change that neither fixes a bug nor adds a feature.
- `test`: Adding or correcting tests.
- `chore`: Tooling, build pipeline, or dependency updates.

### Examples:
- `feat(mobile): implement home greeting header and quick input bar`
- `ui(theme): configure Hind Siliguri typography with 1.45 line height`
- `fix(scheduler): handle boot receiver exact alarm rescheduling on Android 14`
