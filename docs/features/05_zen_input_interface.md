# Specification: Pingo Zero-History Zen Input Interface

## 1. Product Vision & Rationale
Users often find message bubbles, conversation logs, and capability boards cluttering their cognitive flow. Pingo's **Zen Input Interface** provides a zero-friction, distraction-free environment:
- **No Chat History**: The screen does not accumulate message bubbles or conversation logs.
- **Unified Capture Bar**:
  - `[📄 Doc Button]`: Tap to view indexed documents in the vault or attach a document for processing.
  - `[Text Input]`: A clean prompt field for typing thoughts, reminders, notes, or questions.
  - `[🎙️ Mic Button]`: Instant one-tap voice capture.
- **Ephemeral Confirmation**: When thoughts, reminders, or documents are captured, a non-intrusive floating pill confirms indexing (e.g. `✓ Saved to memory` or `✓ Document created`), and the screen immediately resets to a pristine, calm state.

---

## 2. Visual Architecture

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                                                        │
│                                                        │
│                                                        │
│                        Pingo                           │
│              Tell me anything to remember              │
│                                                        │
│                                                        │
│                                                        │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [📄 Doc]   Type a thought, task, or note...  [🎙️] │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 3. Core Components
1. **`ZenInputScreen`**: Full-screen calm canvas with optional minimal branding, responsive to light/dark themes.
2. **`ZenInputBar`**: Dock housing the Doc button, text input field, and Microphone trigger.
3. **`DocumentsVaultSheet`**: Modal bottom sheet displayed upon tapping the Doc button to review all indexed documents, summaries, and notes.
4. **`FeedbackPill`**: Ephemeral floating status indicator confirming storage in the memory vault.

