# Specification: Clean State Architecture & Demo Data Removal

## 1. Objective
Remove all hardcoded demo, dummy, and mockup data across the Pingo mobile application. Transition all screens to dynamic, user-driven states with elegant empty states.

---

## 2. Inventory of Demo Data to Remove

### A. Home & Reminders State (`features/home/presentation/state/home_reminder_provider.dart`)
- **Current**: Preloaded with 4 hardcoded Bangla & English sample reminders (`ব্লাড প্রেশারের ওষুধ গ্রহণ`, `Doctor appointment with Mom`, `বিদ্যুৎ ও ইন্টারনেট বিল পরিশোধ`, `Q4 প্রজেক্ট ডেলিভারি রিভিউ`).
- **Target**: Initial state `reminders: []`. When empty, render a calm, pristine empty-state illustration or clean message.

### B. Vault & Document Repository (`features/vault/presentation/screens/pingo_vault_screen.dart`)
- **Current**: Hardcoded counts (`4 documents`, `6 documents`, `3 documents`, `2 documents`) and 3 mock items (`Driving license`, `Car insurance`, `Passport`).
- **Target**:
  - Category counts default to `0 documents` when empty.
  - Section `Needs attention soon`: If empty, display a clean empty card: *"No expiring documents. Everything is up to date."*
  - Documents list dynamically populated when the user saves a document via `+ Add document` or file upload.

### C. Voice Listening Screen (`features/voice_capture/presentation/screens/pingo_voice_screen.dart`)
- **Current**: Hardcoded text `'Doctor with Mom tomorrow at 5 PM'` in state and RichText.
- **Target**: Dynamic speech transcription state. Starts with `'Listening to your voice...'` placeholder, updating in real time as the user speaks or types.

### D. Conversation Flow (`features/session_chat/presentation/screens/pingo_flow_screen.dart`)
- **Current**: Hardcoded fallback values (`Doctor with Mom`, `Blood pressure medicine`, `Call the bank`, `Pay electricity bill`).
- **Target**:
  - In `AutoSaved`: Uses the exact text passed by the user (from Home input or Voice). If no prompt is provided, defaults to blank capture state.
  - In `AskAboutToday`: Dynamically queries the current list of saved reminders. If no reminders exist, shows *"You're all clear today! No tasks scheduled."*
  - In `AskQuestion`: Prompts for time clarification specifically for the user's custom task title.

### E. User Profile (`features/profile/presentation/screens/`)
- **Current**: Hardcoded `'Rahim Ahmed'`, `'rahim@email.com'`, initials `'RA'`.
- **Target**: Clean guest / account profile defaults (e.g., `'User'`, `'user@pingo.app'`, or editable blank profile fields with actual persistence).

---

## 3. Empty State Standards
- **Vault Empty State**:
  - Icon: `Icons.folder_open_rounded` (Muted)
  - Title: *"Your vault is empty"*
  - Subtitle: *"Add your passport, licenses, or receipts to keep them securely encrypted on your phone."*
- **Today's Tasks Empty State**:
  - Icon: `Icons.check_circle_outline_rounded` (Emerald)
  - Title: *"No tasks left today"*
  - Subtitle: *"Speak or type below to create a new reminder."*

