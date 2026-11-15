# Feature Specification: Conversational Unified Data & Document Assistant

**Document ID**: `docs/features/26_tech_minimalist_conversational_and_vault_refinement_spec.md`  
**Status**: IMPLEMENTED & COMPILING RELEASE APK  
**Primary Architect**: Principal System Architect & Lead UI/UX Engineer  
**Target Platform**: Flutter Mobile (Android & iOS)  

---

## 1. Executive Summary & Architecture

Unify all Pingo functionality into an **all-in-one conversational AI assistant**:
1. **Zero Standalone Vault Screen**: Eliminate the separate Vault screen and sub-screens. All document and data management is handled entirely inline within the conversational chat stream.
2. **Streamlined Minimal Header**: Displays only the brand and live operational status (`● Online · Ready` / `● সক্রিয় · প্রস্তুত`) with a bilingual switcher (`[ EN | বাং ]`). All external shortcuts are removed.
3. **Tech-Minimalist Canvas Background**: Subtle, low-opacity animated background featuring abstract circuits, neural AI nodes, and faint reminder motifs.
4. **Dynamic Context-Aware Suggestions**: Real-time context suggestions computed dynamically from the current hour, task workload, and locale (zero static chips).
5. **Direct Document Attachment**: Prominent document icon in the input dock allowing one-tap document attachment and encrypted storage right in the conversation.

---

## 2. Component Design & Behavioral Flows

### 2.1 Dynamic Tech Canvas (`TechCanvasBackground`)
- Ambient background layer behind the chat stream:
  - Faint orthogonal circuit paths (opacity 0.04 - 0.07).
  - Neural AI nodes with soft, slow breathing glow (opacity 0.10 - 0.15).
  - Subtle geometric reminder motifs (circular clock tick marks, calendar lines).
  - Lightweight `CustomPainter` optimized for battery and 60/120 FPS scrolling.

### 2.2 Conversational Document Management
- **Inline Document Attachment (`[📎]`)**:
  - Tapping the attachment icon triggers a streamlined inline dialog or quick-picker (e.g. Passport, NID / ID Card, Driver's License, Medical, or Custom Document).
  - Automatically saves the document into the local encrypted storage and appends an interactive document card directly into the chat flow.
- **Natural Language Document Retrieval**:
  - User can say or type: *"Show my passport"*, *"আমার এনআইডি দেখাও"*, *"List my documents"*, or *"ডকুমেন্টস"*.
  - Pingo responds directly in the conversation with high-contrast, encrypted document cards and expiry alerts.

### 2.3 Dynamic Context Engine (`ContextSuggestionService`)
- Dynamically selects 3-4 suggestions based on:
  - **Morning (06:00 - 12:00)**: "Show today's agenda", "Set 2 PM reminder", "Attach ID to Vault".
  - **Afternoon (12:00 - 17:00)**: "What's left today?", "Remind me at 6 PM", "Scan receipt/doc".
  - **Evening/Night (17:00 - 06:00)**: "Tomorrow's first task", "Review completed tasks", "Check alarms".
  - **Task State Awareness**: If tasks exist, highlights them; if zero tasks, suggests setting one.

### 2.4 Streamlined Header & Input Dock
- **Header**:
  - Pingo title with pulsing emerald indicator (`● Online · Ready`).
  - Bilingual switcher pill `[ EN | বাং ]`.
  - Session refresh icon (`[↻]`).
- **Input Dock**:
  - `[📎]` Document attachment button.
  - Text input field with dynamic context hint.
  - `[🎙]` Voice button with `HapticFeedback.mediumImpact()`.
  - `[➤]` High-contrast send button.

---

## 3. Implementation File Matrix

| File Path | Action | Description |
| :--- | :--- | :--- |
| `apps/mobile/lib/features/home/presentation/widgets/tech_canvas_background.dart` | **Create** | Subtle animated tech canvas featuring circuits, AI nodes, and reminder motifs. |
| `apps/mobile/lib/features/home/presentation/state/context_suggestion_service.dart` | **Create** | Dynamic context engine producing time-, task-, and doc-aware suggestions. |
| `apps/mobile/lib/features/home/domain/chat_message.dart` | **Modify** | Add document metadata fields (`documentTitle`, `documentCategory`, `documentExpiry`). |
| `apps/mobile/lib/features/home/presentation/widgets/chat_message_bubble.dart` | **Modify** | Render high-contrast inline encrypted document cards and reminder cards. |
| `apps/mobile/lib/features/home/presentation/state/pingo_chat_provider.dart` | **Modify** | Support inline document attachment, conversational doc queries, and reminders. |
| `apps/mobile/lib/features/home/presentation/screens/pingo_home_screen.dart` | **Modify** | Pure conversational layout, tech background, streamlined status header, and doc attachment button. |
