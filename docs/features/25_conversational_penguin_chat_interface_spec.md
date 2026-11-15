# Feature Specification: Conversational Penguin Chat Interface

**Document ID**: `docs/features/25_conversational_penguin_chat_interface_spec.md`  
**Status**: IMPLEMENTED & COMPILING RELEASE APK  
**Primary Architect**: Principal System Architect & Lead UI/UX Engineer  
**Target Platform**: Flutter Mobile (Android & iOS)  

---

## 1. Executive Summary & Goals

Transform Pingo's primary mobile experience from a task-list/agenda dashboard into an **entirely conversational, minimalist dark-mode chat interface**.

### Core Requirements
1. **Purely Conversational Layout**: Remove all agenda lists, tabular schedules, and giant central buttons from the primary screen. The entire screen becomes a dynamic conversation feed with Pingo.
2. **Onboarding & Idle Mascot**: Display a cute animated penguin mascot ("Pingo") welcoming the user on initial launch and when the chat is empty.
3. **Gentle Mascot Pulse**: During initialization and idle states, the mascot pulses gently with breathing micro-animations, inviting voice or text input.
4. **Active Chat Aesthetics**:
   - **Rounded Message Bubbles**: User messages in soft modern gradients; Pingo messages in dark frosted glass containers.
   - **Dynamic Typing Indicator**: 3 animated bouncing dots indicating AI reasoning/parsing state.
   - **Haptic Feedback**: Tactile haptic feedback (`HapticFeedback.mediumImpact()`) on voice mic activation.
5. **State Management & History Archiving**:
   - **Sliding In-Memory Window**: Cap active rendering thread at 40 messages to maintain 60/120 FPS scrolling performance without memory inflation.
   - **Persistent Archive Store**: Automatic serialization of older threads into a local session archive vault.
   - **Fresh Thread Protocol**: Header action (`[+] New Session`) to archive the current thread safely and restore the calm mascot onboarding canvas.
6. **Bilingual Parity Protocol (English + বাংলা)**:
   - Dynamic locale binding (`bn_BD` vs `en_US`) synchronized across UI text, mascot greetings, quick-reply chips, and the hardware speech recognition engine.
   - 100% parity for greeting copy, prompt suggestions, and assistant affirmations.

---

## 2. Component & Visual Architecture

### 2.1 Color Palette (Dark Mode Penguin Aesthetic)
- **Canvas / Background**: `#080B11` (Deep Antarctic Midnight)
- **Glass / Surface**: `#111726` (Subtle Frost Glass)
- **Hairline Border**: `#1D263B` (Hairline Ice Border)
- **User Bubble Gradient**: `LinearGradient(colors: [#3B82F6, #1D4ED8])` (Electric Glacier to Deep Ocean)
- **Assistant Bubble**: `#131B2A` with `#232F48` hairline border
- **Penguin Accent (Beak/Feet)**: `#F59E0B` (Warm Amber Beak)
- **Status Indicator**: `#10B981` (Online Emerald)
- **Text Primary**: `#F8FAFC` (Snow White)
- **Text Secondary / Muted**: `#94A3B8` (Glacier Slate)

### 2.2 Animated Penguin Mascot Widget (`PenguinMascotWidget`)
- Custom vector rendering via `CustomPainter`:
  - Rounded glossy penguin body with deep charcoal/blue outline.
  - Soft snowy belly container.
  - Expressive blinking eyes with periodic blink intervals (every 3.5s).
  - Warm amber beak and soft resting flippers.
- Animated micro-interactions:
  - **Gentle Breathing / Pulse**: 2.2-second repeating ease-in-out breathing cycle scaling from `1.0` to `1.04`.
  - **Soft Ambient Halo**: Subtle radial glow pulsating behind the mascot in idle mode.

---

## 3. State Management & History Archiving Strategy

To ensure fluid 60/120 FPS performance even as user interactions scale into hundreds of messages over weeks:

1. **Active Thread Windowing**:
   - `PingoChatState` maintains an active in-memory list capped at `maxActiveMessages = 40`.
   - As messages exceed 40, the oldest items are automatically committed to the local disk archive (`chat_archive_service.dart`) and trimmed from the active rendering tree.

2. **Session Archiving Protocol**:
   - Each thread is grouped by a `sessionId` (UUID).
   - An intuitive header button (`[+] New Thread` or `Archive`) allows the user to stash the current conversation at any time.
   - Previous sessions are saved in JSON format under local storage for future memory recall without cluttering the active chat stream.

3. **Restoration & Lazy Loading**:
   - If the user scrolls to the top of the conversation, an on-demand pagination trigger loads the prior archived chunk smoothly.

---

## 4. Bilingual Parity Protocol (English + বাংলা)

The application maintains strict linguistic parity across both English and Bengali:

| Component | English (`en_US`) | Bengali (`bn_BD`) |
| :--- | :--- | :--- |
| **Mascot Title** | "Hi, I'm Pingo!" | "হাই, আমি পিঙ্গো!" |
| **Mascot Subtitle** | "Tell or text me what you need to remember." | "আপনার যা মনে রাখা প্রয়োজন, আমাকে বলুন বা লিখে জানান।" |
| **Starter Chip 1** | "Remind me to call Mom at 8 PM" | "রাত ৮টায় আম্মুকে ফোন দেওয়ার রিমাইন্ডার দাও" |
| **Starter Chip 2** | "What's on my schedule today?" | "আজকে আমার কী কী শিডিউল আছে?" |
| **Starter Chip 3** | "Test instant alert" | "নোটিফিকেশন এলার্ট চেক করো" |
| **Starter Chip 4** | "Meeting tomorrow at 10 AM" | "কাল সকাল ১০টায় মিটিং আছে" |
| **Input Hint** | "Ask or tell Pingo anything..." | "পিঙ্গোকে কিছু বলুন বা লিখুন..." |
| **Typing Notice** | "Pingo is thinking..." | "পিঙ্গো ভাবছে..." |
| **Commit Confirmation** | "All set! Reminder saved." | "ঠিক আছে! রিমাইন্ডার সেভ করা হয়েছে।" |

**Dynamic Speech Engine Binding**:
Selecting `বাংলা` switches the Speech-to-Text engine locale to `bn_BD` (or best match). Selecting `English` switches to `en_US`.

---

## 5. Implementation Plan & File Matrix

| File Path | Action | Description |
| :--- | :--- | :--- |
| `apps/mobile/lib/features/home/presentation/widgets/penguin_mascot_widget.dart` | **Create** | Animated vector penguin mascot with custom painter, breathing pulse, and eye blink animations. |
| `apps/mobile/lib/features/home/presentation/widgets/typing_indicator_widget.dart` | **Create** | 3-dot staggered bouncing dynamic typing indicator. |
| `apps/mobile/lib/features/home/presentation/widgets/chat_message_bubble.dart` | **Create** | Soft gradient and frosted glass message bubbles with action callbacks and embedded reminder cards. |
| `apps/mobile/lib/features/home/domain/chat_message.dart` | **Create** | Immutable chat message model with serialization and metadata. |
| `apps/mobile/lib/features/home/presentation/state/chat_archive_service.dart` | **Create** | Lightweight local history archiver with active window management. |
| `apps/mobile/lib/features/home/presentation/state/pingo_chat_provider.dart` | **Create** | Riverpod notifier orchestrating active chat, archiving, bilingual state, and AI parsing handoff. |
| `apps/mobile/lib/features/home/presentation/screens/pingo_home_screen.dart` | **Overhaul** | Transform home screen into a 100% conversational chat interface. |

---

## 6. Verification Strategy

1. **Static Analysis**: `flutter analyze lib/` with zero errors.
2. **Release Build**: `flutter build apk --release` with `--dart-define=PINGO_API_URL=http://98.84.163.177`.
3. **Conversational Verification**:
   - Mascot gentle breathing pulse & eye blinking on empty state.
   - Bilingual parity toggle (`[ EN | বাং ]`) immediately updating mascot greeting, chips, and speech recognition locale.
   - Message bubbles rendering with soft gradients and frosted glass.
   - Haptic vibration firing on microphone tap.
   - Dynamic 3-dot typing indicator animating during AI processing.
   - Archiving older messages when thread grows or when starting a new session.
   - Automatic reminder creation, background synchronization, and exact alarms.
