# Specification: Pingo Final UI Design System

## 1. Overview
This specification documents the complete implementation of Pingo's final UI design system, grounded directly in the 13 reference screens from `Pingo UI Redesign-png`:
1. **Home Screen (`1. Home.png`)**: Pristine hero greeting, animated pulsing voice trigger, 
suggestion chips, and bottom input dock.
2. **Auto Saved Flow (`2. Auto saved.png`)**: Conversation session showing purple user bubbles and clean, structured white Pingo cards with `✓ Saved automatically`, timestamps, and `Undo this change`.
3. **Ask About Today (`3. Ask about today.png`)**: Interactive checklist card showing remaining tasks with circular status toggles and strikethroughs.
4. **Voice Recording Screen (`4. Voice.png`)**: Dedicated listening overlay with language toggle (`English + বাংলা`), animated concentric soundwave/ripple rings, live speech transcription, and controls (`Cancel`, `Stop`, `Type`).
5. **Login Screen (`5. Log in.png`)**: Clean phone/email login with Google sign-in and guest option.
6. **Sign Up Screen (`6. Sign up.png`)**: Account creation with language preference selector (`English`, `বাংলা`, `Both`).
7. **Profile Screen (`7. Profile.png`)**: Account details, subscription tier badge, toggles for morning reminder, daily summary, app lock, and cloud backup.
8. **Permissions Onboarding (`8. Permissions.png`)**: Clear 3-step permission grants for Notifications, Microphone, and Background execution.
9. **Vault Screen (`11. Vault.png`)**: Document storage categorized into `Identity`, `Finance`, `Health`, and `Education` with expiry alert cards and search.
10. **Add Document (`12. Add document.png`)**: Visual document scanner preview with expiration date extraction and reminder schedule selectors (90, 30, 7 days before).
11. **Document View (`13. Document.png`)**: Detailed document overview with reminder intervals and action buttons.
12. **Ask a Question Flow (`10. Ask a question.png`)**: Clarification card when reminder time is omitted with quick selection chips (`Morning, 9:00 AM`, `Afternoon, 2:00 PM`, etc.).

---

## 2. Design Tokens & Styling Guide
- **Primary Brand Color**: `#544DE8` (Electric Iris)
- **Background Color**: `#F9FAFC` (Porcelain canvas)
- **Card Background**: `#FFFFFF`
- **Card Border**: `#ECEFF4` (Width 1.2)
- **Border Radius**:
  - Cards: `22px`
  - Pill buttons / chips: `24px` to `30px`
  - Floating buttons: Circular (`56px` diameter)
- **Text Primary**: `#111827` (Deep Slate)
- **Text Secondary**: `#6B7280` (Muted Gray)
- **Success / Done**: `#10B981` (Emerald)
- **Urgent / Stop**: `#EF4444` (Coral Red)
- **Warning / Expiry**: `#F59E0B` (Amber)

---

## 3. Screen Routing & Navigation Architecture
```
              ┌─────────────────────────────┐
              │      1. PingoHomeScreen     │
              └──────────────┬──────────────┘
                             │
     ┌───────────────────────┼───────────────────────┐
     ▼                       ▼                       ▼
┌──────────────┐    ┌─────────────────┐    ┌──────────────────┐
│4. VoiceScreen│    │ 2/3/10. Flow    │    │ 11. VaultScreen  │
└──────────────┘    └─────────────────┘    └────────┬─────────┘
                                                    │
                                           ┌────────┴────────┐
                                           ▼                 ▼
                                    ┌──────────────┐  ┌──────────────┐
                                    │12. AddDoc    │  │13. DocView   │
                                    └──────────────┘  └──────────────┘
```
