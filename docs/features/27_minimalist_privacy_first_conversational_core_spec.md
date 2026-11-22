# Feature Specification: Minimalist Privacy-First Conversational Core

**Document ID**: `docs/features/27_minimalist_privacy_first_conversational_core_spec.md`  
**Version**: `3.0.0` (UNSLOP 9-PASS HOROLOGICAL LEDGER EDITION)  
**Primary Architect**: Principal System Architect & Lead UI/UX Engineer  
**Target Platform**: Flutter Mobile (Android & iOS) & Web APK Portal  

---

## 0. Unslop 5-Line Craft Direction

- **Product**: A bilingual (Bangla & English) personal memory assistant that turns quick voice notes, messages, and documents into exact, confirmed phone alarms.
- **Character**: Quiet, exact, tactile.
- **World**: Late-night desk ledger and precision pocket timepiece — matte ink surfaces (`#07080D` to `#1A1E28`), crisp paper-white typography (`#EEF0F5`), hairline borders (`#222734`), and one signal-amber accent (`#E5A93C`).
- **Moments**: The inline **Horological Alarm Ticket** (confirmation slip inside chat bubbles with tabular time figures and tactile schedule/discard controls) and the **Encrypted Document Slip**.
- **Signature**: A 6px semantic status dot (amber `#E5A93C` while pending confirmation, sage `#4CC38A` once scheduled, crimson `#E5484D` when overdue) paired with a tabular timestamp (`HH:MM · DD MMM`), alongside the headphone-penguin brand icon across Android adaptive mipmaps (`ic_launcher`, `ic_launcher_round`, `ic_launcher_foreground`), the top bar (`32×32px`), and the download portal.

## 1. Executive Summary & Core Architectural Invariants

Pingo operates as a minimalist, privacy-first memory and reminder assistant with zero intrusive branding, clean operational status, natural voice interaction, mandatory confirmation gates, and integrated native document handling:

1. **Fully Adaptive Theme & Ambient Tech Canvas**:
   - Seamlessly switches between Light Mode (`#F8FAFC` base, subtle slate circuits `#64748B`) and Dark Mode (`#080B11` base, cyan circuits `#38BDF8`) following system brightness.
   - Abstract orthogonal traces, pulsing AI neural nodes, and faint 12-hour dial tick motifs with zero mascot/cartoon branding.
2. **Minimalist Header Control**:
   - Stripped of all branding titles ("Pingo", "Pingo AI") and refresh buttons.
   - Displays strictly the functional status dot (`● Online — Ready` / `● সক্রিয় — প্রস্তুত`) on the left and an unobtrusive high-contrast toggle (`[ EN | বাং ]`) on the right.
3. **WhatsApp-Style Hold-to-Speak with Manual Review**:
   - Users hold the microphone button to speak with tactile haptic feedback (`HapticFeedback.mediumImpact()`).
   - Releasing the button finalizes transcription and populates the text field for **manual review**, allowing the user to inspect, edit, or clear the transcript before dispatching.
   - The send button remains conditionally hidden, becoming active only after text is typed or transcribed.
4. **Mandatory Confirmation Steps for Reminders (Zero False Alarms)**:
   - Automatic background alarm scheduling is strictly prohibited without explicit user sign-off.
   - When temporal intent is detected, Pingo generates a proposed reminder card with `[ Confirm & Schedule ]` / `[ নিশ্চিত করুন ]` and `[ Discard ]` / `[ বাতিল ]` action controls.
   - Exact alarms are registered and synced only upon user confirmation.
5. **Strict Background Suspension & Anti-Spam Protocol**:
   - Audio listeners, speech-to-text engines, and UI timers are immediately suspended and cancelled when the app transitions to `AppLifecycleState.paused` or `detached`.
   - Prevents background battery drain, phantom notifications, and repeated alert loops.
6. **Native File Picker Document Architecture**:
   - Attachment button (`[📎]`) invokes the **native platform file picker** (documents, PDFs, scans), eliminating preset menus.
   - Attached documents render as interactive, high-contrast cards in the chat history with an inline button: `[ 🔔 Set Expiry Alert ]` / `[ 🔔 মেয়াদ এলার্ট সেট করুন ]`.
7. **Chunked Streaming & Memory Window Management**:
   - Input utterances are processed in discrete, token-efficient chunks, distinguishing standard commentary ("thanks", "hello") from reminder requests.
   - The in-memory chat thread is capped at 40 messages with transparent local disk archiving to ensure steady 60/120 FPS performance.

---

## 2. Technical & Functional Architecture

### 2.1 Adaptive Tech Canvas (`TechCanvasBackground`)
- Color adaptation:
  - **Dark Mode**: `#080B11` canvas with `#38BDF8` circuit paths (alpha 0.05) and `#10B981` node pulses (alpha 0.20).
  - **Light Mode**: `#F8FAFC` canvas with `#64748B` circuit paths (alpha 0.07) and `#0284C7` node pulses (alpha 0.18).
- Renders orthogonal traces, micro AI nodes, and faint 12-hour clock dial ticks.

### 2.2 Native Document Picker & Interactive Card
- **File Picker Integration**: Uses `file_picker` package to invoke native Android/iOS document selection.
- **Interactive Document Card (`chat_message_bubble.dart`)**:
  - Displays file name, extension/size badge, encryption label (`AES-256 (Local)`).
  - Interactive Expiry Alert button: Tapping opens a date picker and schedules a reminder upon user confirmation.

### 2.3 Hold-to-Speak & Review Workflow
- **Gesture Interaction**:
  - `onLongPressStart`: Haptic vibration (`mediumImpact`), activates hardware `SpeechToText.listen()`, displays live recording indicator in the dock.
  - `onLongPressEnd`: Haptic vibration (`lightImpact`), stops listening, places transcribed text in `_inputController` for review.
- **Intent Filter (Commentary vs Reminder)**:
  - Evaluates temporal tokens (e.g. "at 5 PM", "tomorrow", "কাল", "রাত ৮টায়", "reminder", "schedule").
  - General conversational remarks (e.g. "hello", "thanks", "how are you") receive natural assistant replies without creating spurious reminders.

---

## 3. Implementation File Matrix

| File Path | Action | Description |
| :--- | :--- | :--- |
| `apps/mobile/pubspec.yaml` | **Modify** | Add `file_picker: ^8.0.0` dependency. |
| `apps/mobile/lib/features/home/presentation/widgets/tech_canvas_background.dart` | **Modify** | Fully adaptive light/dark mode canvas with circuits, nodes, and dial ticks. |
| `apps/mobile/lib/features/home/domain/chat_message.dart` | **Modify** | Add document file path, file size, pending confirmation state, and expiry alert fields. |
| `apps/mobile/lib/features/home/presentation/widgets/chat_message_bubble.dart` | **Modify** | Adaptive light/dark styling with interactive `Confirm & Schedule` and `Set Expiry Alert` actions. |
| `apps/mobile/lib/features/home/presentation/state/pingo_chat_provider.dart` | **Modify** | Mandatory confirmation pipeline, discrete chunk filtering (commentary vs reminder), and background suspension hooks. |
| `apps/mobile/lib/features/home/presentation/screens/pingo_home_screen.dart` | **Modify** | Minimal header (status only + EN/বাং), native file picker trigger, WhatsApp-style hold-to-speak with review, and conditionally hidden send button. |
