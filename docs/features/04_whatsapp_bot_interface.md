# Specification: Pingo WhatsApp-Style AI Bot Interface

## 1. Overview & Product Rationale
Based on user feedback, Pingo eschews complex dashboards, cluttered cards, and multi-tier home hubs. Instead, it adopts the familiar, high-velocity UX of a **WhatsApp / Telegram AI Assistant Bot**.

The user interacts with Pingo as they would with a contact or intelligent concierge:
- Send quick text messages or voice notes.
- Pingo instantly parses intent (Reminders, Summaries, Document generation, Recall queries).
- Structured memories and generated documents appear inline as native message capsules (similar to shared WhatsApp contacts, documents, or media cards).

---

## 2. Visual Architecture

```
┌────────────────────────────────────────────────────────┐
│  [🤖] Pingo                                      [ ⋮ ] │
│      ● online • AI Memory Assistant                    │
├────────────────────────────────────────────────────────┤
│                                                        │
│       [ 🔒 End-to-end memory vault active ]           │
│                                                        │
│                                                        │
│   [User] ──────────────────────────────────────────    │
│   "Remind me: Doctor appointment tomorrow at 5 PM"     │
│                                           10:24 AM ✓✓  │
│                                                        │
│   ─────────────────────────────────── [Pingo Bot]      │
│   "Saved to your memory! I will alert you on time."    │
│   ┌──────────────────────────────────────────────┐     │
│   │ ⏰ Doctor appointment with Mom               │     │
│   │ 📅 Tomorrow, 5:00 PM • Personal              │     │
│   └──────────────────────────────────────────────┘     │
│                                           10:24 AM     │
│                                                        │
│   [User Voice Note] ───────────────────────────────    │
│   ▶ ılılılılılılılılı 0:14                             │
│                                           10:28 AM ✓✓  │
│                                                        │
│   ─────────────────────────────────── [Pingo Bot]      │
│   "Generated document from your audio note:"           │
│   ┌──────────────────────────────────────────────┐     │
│   │ 📄 Client Meeting Summary.pdf                │     │
│   │ 3 action items extracted • Tap to preview    │     │
│   └──────────────────────────────────────────────┘     │
│                                           10:29 AM     │
│                                                        │
├────────────────────────────────────────────────────────┤
│  [ + ]   Message Pingo...                   [ 🎙️ / ➔ ] │
└────────────────────────────────────────────────────────┘
```

---

## 3. Component Hierarchy
1. **`WhatsAppHeader`**:
   - Bot Avatar with active status dot.
   - Title: `Pingo`.
   - Subtitle: `online • AI Memory Assistant`.
   - Actions: Audio voice call trigger & menu popup.
2. **`WhatsAppMessageList`**:
   - Natural scrolling reverse/forward thread.
   - User messages with subtle green tint (`#DCF8C6` / `#005C4B`) and double blue checkmarks (`✓✓`).
   - Bot messages with neutral white / dark surface.
   - Inline interactive cards for `ReminderItem` and `DocumentPayload`.
3. **`WhatsAppInputDock`**:
   - `+` icon for OCR scan, document note, or camera attachment.
   - Expanding message input with `Message Pingo...` placeholder.
   - Dynamic voice mic vs. send icon.

---

## 4. Language & Localization
- System UI: Clean, crisp **English** by default.
- User input: English, Bengali, or mixed (Banglish). Pingo processes both seamlessly.

