# Specification: Pingo Executive Action Stream (Non-Chatbot Studio UI)

## 1. Product Vision & Rationale
Generic chatbots rely on speech balloons, conversational filler ("I have done that for you"), and messaging bubbles. Pingo is an **Executive Memory & Document Studio**:
- **Zero Chat Bubbles**: Removes chat balloons, message tails, and chit-chat.
- **Direct Deliverable Cards**: Every voice note or text prompt immediately renders as an interactive, production-grade deliverable card:
  - ⏰ **Smart Reminder Card** (Time, priority, category, direct edit).
  - 📄 **Structured Document Card** (Title, summary, key bullet points, tags, share/export).
  - 💡 **Captured Memory Capsule** (Indexed context, instant recall).
- **Session-Based Ergonomics**:
  - Starts fresh on launch with a serene hero studio canvas.
  - Dynamically populates with action deliverables during the session.
  - Top `+` button clears the workspace for a new session.
  - Document Vault icon (`📁`) grants one-tap access to all saved documents.

---

## 2. Visual Architecture

```
┌────────────────────────────────────────────────────────┐
│  Pingo                                   [ 📁 ]  [ + ] │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ⏰ REMINDER                        Tomorrow 5 PM │  │
│  │ Doctor appointment with Mom                      │  │
│  │ Square Hospital • Personal                       │  │
│  │ [ ✏️ Edit Time ]   [ 🔔 Alarm Active ]            │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 📄 DOCUMENT                     Work & Projects  │  │
│  │ Q4 Sprint Deliverables & Notes                   │  │
│  │ • Sprint velocity locked for mobile MVP release  │  │
│  │ • Figma design tokens approved for Flutter       │  │
│  │ [ 📄 View Doc ]   [ ↗ Share ]                    │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ 📎 ]  Capture a thought, task, or note...  [🎙️]│  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

