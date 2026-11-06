# Feature Specification: Chat-First Memory & Documentation Companion

## 1. Vision & Paradigm
Pingo operates as a chat-first conversational personal memory companion. Instead of a traditional cluttered To-Do list, users interact exclusively through natural conversation (voice or text). Pingo manages reminders and schedules in the background while synthesizing structured documentation, notes, and summaries on command.

## 2. Core Experience Principles
- **Zero Interface Clutter**: No forced forms or exposed tables by default; the timeline is a clean, conversational thread.
- **Silent Background Memory**: When the user requests a reminder ("কাল বিকাল ৫টায় ডক্টর"), Pingo parses it, sets exact system alarms locally, and confirms with a humanized conversational reply and an inline Memory Capsule.
- **On-Demand Documentation Generation**: Pingo synthesizes structured notes, meeting summaries, medical records, and document vaults directly into the chat stream.
- **Natural Language Recall**: Asking *"আমার পাসপোর্টের মেয়াদ কবে?"* or *"আজকের টাস্কগুলো কী?"* triggers immediate conversational recall from local memory.

## 3. Component Architecture
- `chat_message.dart`: Polymorphic message entity supporting text, memory capsules, and generated document notes.
- `chat_screen.dart`: Main viewport with intelligent conversation stream.
- `memory_capsule_widget.dart`: Inline compact reminder card within chat.
- `document_card_widget.dart`: Rich formatted documentation note with tags and bullet points.
- `chat_input_dock.dart`: Bottom capture dock with attachment button, text bar, and voice button.

