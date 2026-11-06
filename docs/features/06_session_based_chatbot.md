# Specification: Pingo Session-Based Chatbot & Sleek Upload Dock

## 1. Overview & Problem Definition
The previous prototype exhibited two UX friction points:
1. **Unwanted Text Label**: The capture bar displayed a text button (`Docs`) instead of a modern document upload icon.
2. **Awkward Nested Borders**: The text field had a harsh internal blue focus outline and cramped padding.
3. **Session Behavior**: Users expect modern AI chatbot ergonomics (akin to ChatGPT / Perplexity / Claude):
   - Every launch or new chat session opens into a **pristine, empty state** (no past chat clutter).
   - Once the user types or speaks, the active session streams the immediate conversation thread.
   - A dedicated `+` (New Chat) icon instantly clears the session back to the clean prompt state.

---

## 2. Visual Architecture

### State A: Fresh Session (App Launch or New Chat)
```
┌────────────────────────────────────────────────────────┐
│  Pingo                                   [ 📁 ]  [ + ] │
│                                                        │
│                                                        │
│                        ╭────╮                          │
│                        │ 🌟 │                          │
│                        ╰────╯                          │
│                What's on your mind?                    │
│           Ask, schedule, or create documents           │
│                                                        │
│                                                        │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ 📎 ]  Ask, remember, or draft anything...  [🎙️]│  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### State B: Active Session (Prompt Submitted)
```
┌────────────────────────────────────────────────────────┐
│  Pingo                                   [ 📁 ]  [ + ] │
├────────────────────────────────────────────────────────┤
│                                                        │
│   [User] ──────────────────────────────────────────    │
│   "Remind me: Doctor appointment tomorrow at 5 PM"     │
│                                                        │
│   ─────────────────────────────────── [Pingo Bot]      │
│   "Saved! I've scheduled your reminder."               │
│   ┌──────────────────────────────────────────────┐     │
│   │ ⏰ Doctor appointment • Tomorrow at 5:00 PM  │     │
│   └──────────────────────────────────────────────┘     │
│                                                        │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ 📎 ]  Type a message...                    [🎙️]│  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 3. Component Architecture
1. **`SleekInputDock`**:
   - Single clean capsule without internal harsh borders.
   - Left: `attach_file_rounded` icon for document/file upload.
   - Center: Borderless clean text input with smooth expansion.
   - Right: Circular button dynamically toggling between voice mic (🎙️) and submit arrow (↑).
2. **`SessionChatScreen`**:
   - State: `List<ChatMessage> currentSessionMessages` (initially empty).
   - If empty: Shows peaceful ambient hero center ("What's on your mind?").
   - If non-empty: Seamlessly switches to active conversation thread.
   - Top right: `+` (New Chat) which clears current session with smooth transition, and `📁` (Vault) to access document records.

