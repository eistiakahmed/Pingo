# Feature Specification: Core UI Screens & Design Tokens

## 1. Scope
This document specifies the initial user interface layout, design tokens, and components for `apps/mobile` in Phase 1.

## 2. Design Tokens
- **Typography**: Primary font family `Hind Siliguri` (Bangla & Latin numerals). Line-height factor: 1.45x for clear vowel-diacritic rendering.
- **Color Palette**:
  - Slate Blue / Deep Navy (Primary): `#1E293B`, `#0F172A`
  - Emerald Green (Success / Done action): `#10B981`
  - Amber / Coral (Urgent / Overdue alert): `#F59E0B`, `#EF4444`
  - Neutral Backgrounds: Light `#F8FAFC`, Dark `#090D16`
  - Surface Cards: `#FFFFFF` (Light), `#1E293B` (Dark)
- **Touch Targets**: Minimum 48dp, Floating Mic Action 68dp.

## 3. Screen Specifications

### 3.1 Home Screen (`features/home`)
- **Header**: Warm, humanized greeting with current date ("আজকের দিনটি সুন্দর কাটুক, ইশতিয়াক" / "Good morning").
- **Overdue Banner**: High-priority alert banner listing overdue tasks if present.
- **Today's Reminders List**: Cards showing title, time chip, category pill, and one-tap Done / Snooze swipe actions.
- **Persistent Bottom Action Bar**:
  - Quick text input field ("টাইপ করুন বা বলুন...").
  - Center elevated Floating Microphone button for single-tap voice capture.

### 3.2 Confirmation Card (`features/confirmation`)
- **Trigger**: Appears when natural language text or voice transcript is parsed.
- **Components**:
  - Extracted Title (editable with single tap).
  - Detected Date & Time chips.
  - Detected Repeat rule (e.g. Daily, Monthly) and Category.
  - Action buttons: "Edit details" (secondary) and "Confirm & Save" (primary).

### 3.3 Add / Edit Reminder Sheet (`features/reminder_editor`)
- **Trigger**: Manual '+' tap or "Edit details" from Confirmation Card.
- **Components**:
  - Full title and notes textarea.
  - Native DatePicker & TimePicker triggers.
  - Recurrence selector (None, Daily, Weekly, Monthly, Custom).
  - Priority toggle (Normal vs Important).
  - Category picker with custom color tags.

### 3.4 Voice Capture Overlay (`features/voice_capture`)
- **Trigger**: Floating Mic button tap or hold.
- **Components**:
  - Audio waveform ripple animation.
  - Real-time speech-to-text transcript area.
  - Cancel and Finish controls.

