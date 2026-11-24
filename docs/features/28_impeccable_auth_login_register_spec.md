# Feature Spec: Pingo English-Only App, Auto-Saved Reminders & Home Usage Dashboard (`/ponytail`)

## 1. Core Decisions
1. **Auto-Saved Reminders (Zero Manual Confirmation Friction)**:
   - When the user types or speaks a reminder (or taps a quick chip), `_handleCreateIntent` in `PingoChatNotifier` **immediately saves the reminder and schedules the native system alarm** (`isPendingConfirmation: false`).
   - The chat reply card displays `● Saved automatically` with the tabular due timestamp (`5:30 PM · 24 Nov`) and a 1-tap **`Undo`** button that calls `discardReminder(msg.id)` to remove the reminder and cancel its alarm if needed.
2. **English-Only App Interface**:
   - Default language in `PingoChatState` is locked to `'en'` (`Locale('en', 'US')` in `PingoApp`).
   - Removed all Bangla/English switcher pills and menu toggles across `PingoLoginScreen`, `PingoSignupScreen`, and `PingoHomeScreen`.
3. **Home Usage & Task Progress Dashboard -> Chat Interface Flow**:
   - **Stage 1 (Home Dashboard)**: Displays date & greeting, Cloud Sync indicator, 3-Metric App Usage & Task Progress card (`Upcoming`, `Overdue`, `Completed` + progress bar), interactive today's/upcoming tasks list, and quick action pills.
   - **Stage 2 (Chat Interface)**: Opens automatically when typing, speaking, tapping a quick action, or tapping `Chat`, with a `←` back button in the top bar to return to the Home Dashboard.
