# 🔔 Pingo

***Say it. Type it. Never forget it.***

**Your smart memory assistant for reminders, voice notes, and important documents**

Product and Technical Plan

|  |  |
| --- | --- |
| **Document** | End-to-end product and technical plan |
| **Version** | 1.0 |
| **Date** | November 5, 2026 |
| **Status** | Planning (no code written yet) |
| **Platforms** | Android first, then iOS |
| **Languages** | English and Bangla |
| **Prepared for** | Product Owner, Design, and Engineering |

*Confidential. This document contains product plans and is intended only for the project team.*

---

# Pingo App: Product and Technical Plan

*End-to-end planning document | Version 1.0 | November 4, 2026 | Status: Planning (no code written yet)*

## 1. Executive Summary

People forget things every day. They forget a doctor's appointment, a bill due date, a family member's birthday, the expiry date of a passport, or the simple errand they promised to run on the way home. Existing reminder apps help, but most of them demand effort at the exact moment a person is busiest: opening an app, tapping through a form, choosing a date, choosing a time, and choosing a repeat rule. Many people skip that effort and simply trust their memory, which fails.

This document describes **Smart Reminder**, a mobile application whose purpose is to remove that effort. The user simply tells the app what they need to remember, in any natural way, and the app does the rest. The user can type a sentence, speak a sentence, or upload a document. The app understands the request, creates the reminder, and notifies the user at the right time.

The product is built around four core capabilities:

1. **Reminders with reliable notifications.** The user sets a date and time, and the app delivers a notification and a visible message at that moment.
2. **Document intelligence.** The user uploads documents (ID cards, licenses, bills, certificates, prescriptions). The app stores them safely, can retrieve them on request, and creates reminders from dates found inside them, such as expiry dates.
3. **Message-to-reminder.** The user types a natural sentence such as "Doctor with Mom tomorrow at 5 PM", and the app converts it into a structured reminder.
4. **Voice-to-reminder.** The user speaks the same sentence, and the app converts speech to text and then to a structured reminder.

The long-term vision is a **personal memory assistant**: a calm, dependable companion that remembers on the user's behalf, helps the user stay organized, and gradually learns their routines.

This document covers the problem, users, scope, detailed requirements, user experience, architecture, data model, AI design, security, roadmap, testing, risks, and launch plan. It is written so that a founder, a designer, or a developer can each read it and know what to do next.

## 2. Problem Statement and Vision

### 2.1 The problem

Forgetting is not a character flaw. It is a normal result of how human memory works under daily load. A typical adult juggles work tasks, family duties, payments, health needs, and social obligations. Three specific failure patterns appear again and again:

- **The capture problem.** A thought occurs at an inconvenient moment (while driving, cooking, or in a meeting) and is gone before it is written down. Traditional apps require too many steps to capture it.
- **The timing problem.** Even when a task is written down, it is not surfaced at the moment it matters. A to-do list does not tap the user on the shoulder.
- **The document problem.** Important dates are buried inside papers and images: a passport expiry, an insurance renewal, a warranty end date, a medicine schedule. Nobody reminds the user, and the consequence is a fine, a missed trip, or a lapsed policy.

### 2.2 The vision

To be the easiest way to remember anything. The ideal interaction takes **under five seconds**: the user opens the app (or taps a home-screen shortcut), speaks one sentence, confirms with one tap, and moves on with their day, confident that the app will remind them at the right time.

### 2.3 Product principles

Every design and engineering decision should be checked against these principles:

- **Capture in seconds.** If adding a reminder takes more than a few taps, the design has failed.
- **Never miss a notification.** Reliability beats features. A reminder app that sometimes fails to notify is worse than no app at all, because it creates false confidence.
- **Understand people, not forms.** The user speaks and writes naturally. The app adapts to the user, not the reverse.
- **Confirm before committing.** AI can misunderstand. The app always shows what it understood and lets the user correct it with one tap.
- **Private by default.** Reminders and documents are personal. They are stored on the device first, protected by a lock, and shared with the cloud only with permission.
- **Works offline.** Core reminders must work without internet, because forgetting does not wait for a network connection.
- **Bilingual from day one.** The app must handle English and Bangla, including mixed sentences, because that is how real users speak.

## 3. Target Users and Personas

### 3.1 Primary audience

Adults aged 18 to 55 who use a smartphone daily and have more commitments than they can hold in memory. The first market is Bangladesh and the wider Bangla-speaking community, with English as a full second language. The product design should not prevent expansion to other languages later.

### 3.2 Personas

**Persona 1: Rahim, the busy professional (age 32).** Rahim works in an office, manages a household, and travels for work. He forgets bill deadlines and meeting follow-ups. He wants to say one sentence into his phone while walking and have it handled. He values speed above everything.

**Persona 2: Nusrat, the parent and caregiver (age 38).** Nusrat manages children's school events, vaccination dates, and her elderly mother's medicine schedule. She needs repeating reminders and a place to keep prescriptions and school documents. She values reliability and organization.

**Persona 3: Karim, the small business owner (age 45).** Karim runs a shop. He needs to remember supplier payments, license renewals, tax dates, and customer commitments. He has many documents, and expiry dates cause him real financial risk. He values the document vault and expiry alerts.

**Persona 4: Mrs. Hossain, the senior user (age 66).** She takes several medicines at fixed times and often forgets appointments. She prefers voice to typing, needs large text, and needs very simple screens. She values simplicity and loud, clear notifications.

**Persona 5: Tanvir, the student (age 21).** Tanvir tracks assignment deadlines, exam dates, and part-time work shifts. He is comfortable with technology and likes widgets and calendar views. He values low cost and a clean design.

### 3.3 What these personas tell us

The product must serve both fast power users and slow, careful users. That implies a very simple default experience with advanced options available but never forced. Large text, high contrast, voice input, and clear confirmation screens are not extras; they are central to serving personas 2 and 4.

## 4. Goals, Non-Goals, and Success Metrics

### 4.1 Goals

- Let a user create a reminder in under five seconds using voice or text.
- Deliver notifications reliably on Android and iOS, including after device restart.
- Understand natural English and Bangla date and time expressions with high accuracy.
- Store documents securely and retrieve them by simple request.
- Create reminders automatically from dates found in uploaded documents, after user approval.
- Work offline for all core reminder functions.

### 4.2 Non-goals for version 1

Stating what the app will *not* do protects the schedule.

- It will not be a full project management tool or team task tracker.
- It will not include shared or collaborative reminders in version 1 (planned as a later phase).
- It will not read the user's email or messages automatically.
- It will not act as a general-purpose chatbot. The AI is used only to understand and organize reminders and documents.
- It will not support wearables or smart-speaker integration at launch.

### 4.3 Success metrics

| Metric | Definition | Target (first 6 months) |
| --- | --- | --- |
| Notification delivery rate | Scheduled reminders that fire within 60 seconds of due time | 99% or higher |
| Time to create | Median seconds from app open to saved reminder (voice or text) | Under 8 seconds |
| Parsing accuracy | Text and voice inputs where date, time, and title are correct without edits | 90% or higher for English, 85% or higher for Bangla |
| Day-7 retention | Users who return on day 7 after install | 30% or higher |
| Day-30 retention | Users who return on day 30 | 15% or higher |
| Weekly active reminders | Average reminders created per active user per week | 5 or more |
| Crash-free sessions | Sessions without a crash | 99.5% or higher |
| Store rating | Average rating on app stores | 4.4 or higher |

The most important metric is the **notification delivery rate**. If this number is low, nothing else matters.

## 5. Product Scope: Feature Overview

The table below summarizes all features, grouped by release phase. Details follow in section 6.

| Feature | Description | Phase |
| --- | --- | --- |
| Manual reminder | Title, date, time, notes, repeat | 1 |
| Local notifications | Fire at due time with Done and Snooze actions | 1 |
| Reminder list and home screen | Today, upcoming, overdue, completed | 1 |
| Repeat rules | Daily, weekly, monthly, yearly, custom | 1 |
| Boot persistence | Reminders survive device restart | 1 |
| Message-to-reminder | Natural text converted to a structured reminder | 2 |
| Voice-to-reminder | Speech converted to text, then to a reminder | 2 |
| Bilingual understanding | English, Bangla, and mixed sentences | 2 |
| Document vault | Upload, organize, search, and retrieve documents | 3 |
| Document date extraction | Detect expiry and due dates, propose reminders | 3 |
| Retrieval by request | "Show my passport" returns the document | 3 |
| Categories and priorities | Work, Bill, Medicine, Birthday, Personal | 3 |
| Daily summary | Morning notification with the day's plan | 4 |
| Cloud backup and sync | Account, backup, multi-device sync | 4 |
| Home-screen widget | Today's reminders at a glance | 4 |
| Location reminders | Trigger when arriving at or leaving a place | 4 |
| Shared reminders | Send a reminder to a family member | Later |

## 6. Detailed Functional Requirements

Each requirement has an identifier so that designers, developers, and testers can refer to it precisely. "Must" means required for the phase; "should" means desirable.

### 6.1 Reminders and notifications (Pillar 1)

This is the foundation of the product. Everything else depends on it being dependable.

**Creating a reminder**

- **R-01.** The user must be able to create a reminder with a title, a date, and a time.
- **R-02.** The user should be able to add optional notes, a category, and a priority.
- **R-03.** If the user gives a date but no time, the app must apply a sensible default (for example 9:00 AM), configurable in settings.
- **R-04.** If the user gives a time but no date, the app must assume the next occurrence of that time (today if still ahead, otherwise tomorrow) and show this assumption on the confirmation screen.
- **R-05.** The user must be able to edit or delete any reminder at any time.

**Repeat rules**

- **R-06.** The user must be able to choose: does not repeat, daily, weekly (with chosen weekdays), monthly, yearly.
- **R-07.** The user should be able to set a custom interval, such as every 3 days or the last day of every month.
- **R-08.** The user should be able to end a repeat on a date or after a number of occurrences.

**Notifications**

- **N-01.** At the due time, the app must show a system notification with the title and time.
- **N-02.** The notification must offer action buttons: **Done**, **Snooze**, and optionally **Open**.
- **N-03.** Snooze must offer quick choices (10 minutes, 1 hour, tomorrow morning) and a custom choice inside the app.
- **N-04.** The user must be able to choose the notification sound and vibration, including a stronger "urgent" alert for high-priority reminders.
- **N-05.** If the user ignores a notification, the app should send one follow-up nudge after a configurable delay (default 15 minutes), and then mark the reminder as overdue.
- **N-06.** Overdue reminders must remain visible in a clearly marked list until completed or dismissed.
- **N-07.** Reminders must continue to fire after the device restarts, after the app is force-closed, and when the device is offline.
- **N-08.** The user should be able to set an advance alert, such as "remind me one day before and again one hour before".

The request that began this project also asked that the app "give the date and a notification". This is interpreted as two things: a visible **in-app message** that shows the reminder with its date and time, and a **system notification** that arrives even when the app is closed. Both are required.

### 6.2 Message-to-reminder (Pillar 3)

The user types a free-form sentence, and the app turns it into a reminder.

- **M-01.** The input box must accept free text in English, Bangla, or a mix of both.
- **M-02.** The app must extract: the task (what), the date (when), the time (at what hour), the repeat rule (how often), and optionally the people or places mentioned.
- **M-03.** The app must understand relative dates: today, tomorrow, the day after tomorrow, next Friday, in two hours, in three days, end of the month.
- **M-04.** The app must understand part-of-day words: morning, noon, afternoon, evening, night, and map them to default times that the user can change.
- **M-05.** The app must show a **confirmation card** summarizing what it understood (title, date, time, repeat) with one-tap editing before saving.
- **M-06.** If the input is ambiguous (for example "remind me about the meeting" with no time), the app must ask one short clarifying question instead of guessing.
- **M-07.** The app should support multiple reminders in one message, such as "Tomorrow buy milk at 6 and call the bank at 10".
- **M-08.** The app should learn from corrections. If the user always changes "evening" from 6 PM to 7 PM, the default should adapt.

**Example inputs and expected understanding**

| User message | Title | When | Repeat |
| --- | --- | --- | --- |
| "Doctor with Mom tomorrow at 5 PM" | Doctor with Mom | Tomorrow, 5:00 PM | None |
| "Pay electricity bill on the 10th every month" | Pay electricity bill | 10th of each month, default time | Monthly |
| "Take blood pressure medicine every day at 8 am and 8 pm" | Take blood pressure medicine | 8:00 AM and 8:00 PM | Daily |
| "Call Rahim in 2 hours" | Call Rahim | Current time plus 2 hours | None |
| "Kal bikel 5tay mayer sathe doctor" | Doctor with Mom | Tomorrow, 5:00 PM | None |
| "Amar jonmodin 12 March" | My birthday | 12 March | Yearly |

### 6.3 Voice-to-reminder (Pillar 4)

- **V-01.** A prominent microphone button must be available on the home screen and the add-reminder screen.
- **V-02.** Pressing the button starts listening, with a clear visual indicator and live transcription shown on screen.
- **V-03.** The user must be able to speak in English, Bangla, or a mix.
- **V-04.** After the user stops speaking, the transcribed text must be shown and passed through the same understanding process as typed messages (M-02 to M-07).
- **V-05.** The user must be able to correct the transcription by tapping and editing before the confirmation step.
- **V-06.** The app should offer a "hold to talk" mode and a "tap to start, tap to stop" mode.
- **V-07.** The app should fall back gracefully when speech recognition is unavailable or the microphone permission is denied, offering the text box instead.
- **V-08.** The app should provide a one-tap shortcut (home-screen icon action, widget button, or quick-settings tile) that opens directly into listening mode.

Speech recognition quality for Bangla is generally lower than for English, particularly with background noise and regional accents. The design therefore insists on the editable transcript (V-05) and the confirmation card (M-05). These two steps catch most recognition mistakes before they become wrong reminders.

### 6.4 Document vault and intelligence (Pillar 2)

The vault is a private, searchable store of the user's important papers, combined with an assistant that notices dates inside them.

**Storing documents**

- **D-01.** The user must be able to add documents by taking a photo, choosing from the gallery, or importing a PDF or file.
- **D-02.** The user must be able to name each document, assign a category (Identity, Finance, Health, Education, Vehicle, Home, Other), and add tags.
- **D-03.** The user should be able to attach multiple pages or files to one document (for example the front and back of an ID card).
- **D-04.** The vault must be protected by an app lock using fingerprint, face recognition, or a PIN.
- **D-05.** Documents must be stored encrypted on the device.

**Reading and understanding documents**

- **D-06.** The app should run text recognition (OCR) on photos and scanned files to extract the text.
- **D-07.** The app should detect key dates in the text, such as issue date, expiry date, due date, and renewal date, and label them using context (for example the words "Date of Expiry" or "Valid until").
- **D-08.** For each detected date, the app must propose a reminder and ask the user to confirm. It must never silently create reminders from documents.
- **D-09.** The default advance alerts for expiry reminders should be 90 days, 30 days, and 7 days before the date, editable by the user.
- **D-10.** The app should suggest a document title and category automatically (for example "Passport" under Identity), which the user can accept or change.

**Retrieving documents**

- **D-11.** The user must be able to search the vault by name, tag, category, or text content.
- **D-12.** The user should be able to ask in natural language, by text or voice: "Show my passport" or "Where is my car insurance paper?" The app opens the matching document directly.
- **D-13.** The user should be able to share a document securely out of the app, with a warning that sharing leaves the protected vault.
- **D-14.** Each document may be linked to one or more reminders, and the reminder must show a shortcut to the document. For example, a "Renew passport" reminder opens the passport scan.

The original request included that when the user gives a document, "the app should give it to me when I want it". Requirements D-11, D-12, and D-14 fulfil this directly: the document is stored once, and retrieved by search, by natural request, or by a linked reminder.

### 6.5 Supporting features

- **S-01. Categories.** Work, Bill, Medicine, Birthday, Family, Personal, and user-defined categories, each with a color and icon.
- **S-02. Priority.** Normal and Important. Important reminders use a stronger sound and appear first in lists.
- **S-03. Daily summary.** An optional morning notification at a chosen time listing the day's reminders, for example "You have 4 things today. First: medicine at 8:00 AM."
- **S-04. Calendar view.** A month and week view showing dots on days that contain reminders.
- **S-05. Search.** Full-text search across reminders and documents.
- **S-06. Widget.** A home-screen widget showing the next three reminders with a quick-add and a voice button.
- **S-07. Location reminders.** "Remind me to buy bread when I reach the market". Triggered by arrival or departure at a saved place.
- **S-08. Birthdays and anniversaries.** Yearly repeating reminders, optionally imported from contacts, with an advance alert.
- **S-09. Themes.** Light mode, dark mode, and larger text sizes for accessibility.
- **S-10. Backup and sync.** Optional account and cloud backup so reminders survive a lost phone and sync across devices.
- **S-11. Export.** Export reminders to a calendar file or a spreadsheet.

## 7. User Journeys

A journey describes the experience from the user's point of view. These are the main flows the design and testing must support.

### 7.1 First launch

1. The user installs and opens the app and sees a short three-screen introduction explaining voice, text, and documents.
2. The app asks for notification permission, with a plain explanation: "We need this to remind you on time."
3. On Android, the app explains the exact-alarm permission and battery optimization setting, with a button that opens the correct system screen.
4. The user chooses a language (English, Bangla, or both) and optionally a default time for morning, afternoon, and evening.
5. The app creates a sample reminder to demonstrate the experience, which the user can delete.
6. The user lands on the home screen with a prominent microphone button and a text box.

This onboarding must be short. Permissions are asked at the moment they become useful (the microphone permission when the user first taps the mic, the camera permission when the user first adds a document), except for notifications, which are asked early because they are the core of the product.

### 7.2 Create a reminder by voice

1. The user taps the microphone button and says: "Remind me to submit the report on Thursday at 11 in the morning."
2. The screen shows the live transcript while the user speaks.
3. A confirmation card appears: **Submit the report | Thursday, 11:00 AM | Does not repeat**, with Edit and Save buttons.
4. The user taps Save. A brief confirmation is shown, and the reminder appears in the upcoming list.
5. On Thursday at 11:00 AM, the phone shows a notification with Done and Snooze buttons.

### 7.3 Create a reminder by text

1. The user types "Mom's medicine every day 9 pm".
2. The confirmation card shows: **Mom's medicine | Every day at 9:00 PM | Category: Medicine**.
3. The user taps Save.

### 7.4 Add a document and create expiry reminders

1. The user opens the vault and taps Add, then photographs the passport.
2. The app reads the text and suggests: Title "Passport", Category Identity, and detected date "Date of Expiry: 14 August 2029".
3. The app asks: "Create expiry reminders 90 days, 30 days, and 7 days before?" The user taps Yes.
4. The document is saved encrypted. Three reminders are created and linked to it.
5. In May 2029, the user receives "Passport expires in 90 days" with an Open Document button that opens the scan.

### 7.5 Ask for a document

1. At an office desk, the user says: "Show my driving license."
2. The app searches the vault, finds the best match, and asks for fingerprint verification if the vault is locked.
3. The document opens full screen with options to zoom, share, or add a reminder.

### 7.6 Respond to a notification

1. The notification arrives: "Pay electricity bill".
2. The user taps **Snooze 1 hour** directly from the notification without opening the app.
3. An hour later it fires again. This time the user taps **Done**, and the reminder is completed. If it was a repeating reminder, the next occurrence is scheduled automatically.

## 8. Screen Inventory and UX Guidelines

### 8.1 Screen list

| # | Screen | Purpose | Key elements |
| --- | --- | --- | --- |
| 1 | Onboarding | Explain value and request permissions | Three slides, permission prompts, language choice |
| 2 | Home | See today and act quickly | Greeting, today's list, overdue section, large mic button, text input, add button |
| 3 | Confirmation card | Verify what the AI understood | Title, date, time, repeat, category, Edit and Save |
| 4 | Add or edit reminder | Full manual control | Fields, date and time pickers, repeat, category, priority, notes, attachments |
| 5 | All reminders | Browse and manage | Tabs (Upcoming, Overdue, Completed), filters, search |
| 6 | Calendar | See reminders by date | Month and week views, day detail list |
| 7 | Voice listening | Capture speech | Waveform, live transcript, stop and cancel |
| 8 | Vault home | Browse documents | Category folders, recent items, search bar, lock indicator |
| 9 | Document detail | View a document | Image or PDF viewer, detected dates, linked reminders, share |
| 10 | Add document | Import and classify | Camera, gallery, files, title, category, date detection results |
| 11 | Notification actions | Respond from the lock screen | Done, Snooze, Open |
| 12 | Settings | Configure the app | Language, sounds, default times, theme, security, backup, permissions guide |
| 13 | Account and backup | Cloud features | Sign in, backup status, restore, delete data |

### 8.2 Navigation structure

A bottom navigation bar with four tabs keeps the app simple: **Home**, **Calendar**, **Vault**, and **Settings**. The all-reminders list is reachable from Home. The microphone button floats on Home and on the Calendar so that capture is always one tap away.

### 8.3 Design guidelines

- **Large touch targets.** Primary buttons at least 48 density-independent pixels, and the microphone button significantly larger.
- **Readable typography.** Minimum 16 point body text with a user-adjustable scale up to 150 percent.
- **High contrast.** Meet at least WCAG AA contrast ratios in both light and dark themes.
- **Color is not the only signal.** Overdue and priority states use icons and labels in addition to color.
- **Friendly language.** Short, warm, plain sentences. Avoid technical words in user-facing messages.
- **Bangla typography.** Use a font family with full Bangla coverage and correct conjunct rendering, and test line spacing, because Bangla needs more vertical room than Latin text.
- **Local numerals and dates.** Support Bangla numerals as an option and format dates according to the chosen language.
- **Accessibility.** Full screen-reader labels, support for system font scaling, and no flashing animations.
- **Calm emotional tone.** Overdue items should be informative rather than shaming. The app should feel like a helpful friend, not a nagging boss.

## 9. System Architecture

### 9.1 Architecture principles

- **Offline first.** The phone is the source of truth. Reminders are stored and scheduled locally, so the core product works with no internet connection.
- **Cloud as an assistant, not a dependency.** The cloud is used for AI understanding, backup, and sync. If the cloud is unreachable, the app falls back to simpler on-device behavior.
- **Thin backend.** A small, secure service sits between the app and the AI provider so that secret keys never ship inside the app.
- **Cross-platform client.** One codebase for Android and iOS, with native code only where the platform requires it (exact alarms, background tasks, widgets).

### 9.2 High-level components

The system has five layers.

1. **Mobile app (client).** User interface, local database, notification scheduler, voice capture, camera and document import, on-device text recognition, and the app lock.
2. **Local storage.** An encrypted database for reminders, categories, and document metadata, plus an encrypted file store for document images and PDFs.
3. **Backend service.** A lightweight API that handles authentication, AI requests, backup, and sync. It is stateless and horizontally scalable.
4. **AI services.** A large language model for turning text into structured reminders and for labeling document dates, and a speech recognition service for voice.
5. **Cloud storage and database.** Encrypted object storage for backups of documents and a managed database for account data and synced reminders.

### 9.3 Data flow: message to reminder

1. The user types or speaks a sentence. For voice, the speech engine returns text.
2. The app first tries a **fast local parser** for common patterns (for example "tomorrow 5 pm"). If it is confident, no network call is needed.
3. If the local parser is not confident, or the sentence is complex or in Bangla, the app sends the text, the current date, time zone, and language to the backend.
4. The backend calls the language model with a strict instruction to return only structured data.
5. The backend validates the response against a schema and returns it to the app.
6. The app displays the confirmation card. After the user confirms, the reminder is saved locally and the notification is scheduled on the device.
7. If sync is enabled, the reminder is queued for upload to the cloud.

This hybrid approach keeps most requests fast and free of cost, and uses the AI only where it adds real value.

### 9.4 Data flow: document to reminders

1. The user captures or imports a document. The file is encrypted and saved locally.
2. On-device text recognition extracts the text, so the document image does not need to leave the phone.
3. By default, only the **extracted text snippets that contain dates** are sent to the backend for labeling. Full documents are not uploaded for analysis unless the user explicitly opts in.
4. The AI returns candidate dates with labels such as "expiry date" and a confidence score.
5. The app shows the candidates. The user approves, edits, or rejects each one, and approved items become reminders linked to the document.

### 9.5 Offline behavior

| Capability | Offline behavior |
| --- | --- |
| Create reminder manually | Fully available |
| Notifications | Fully available |
| Simple text parsing | Available through the local parser |
| Complex or Bangla parsing | Queued; user can save as a plain reminder and refine later |
| Voice | Available if the device supports offline speech recognition; otherwise text fallback |
| Document storage and search | Available |
| Document date detection | Basic pattern matching on device; AI labeling when online |
| Backup and sync | Queued until online |

## 10. Data Model

### 10.1 Main entities

**Reminder**

| Field | Type | Notes |
| --- | --- | --- |
| id | UUID | Unique, generated on device |
| title | Text | Required |
| notes | Text | Optional |
| due\_at | Timestamp (UTC) | Next due moment |
| timezone | Text | The time zone in which the user set it |
| repeat\_rule | Structured text | Frequency, interval, weekdays, end condition |
| category\_id | Reference | Optional |
| priority | Integer | 0 normal, 1 important |
| status | Text | active, done, snoozed, overdue, deleted |
| source | Text | manual, text, voice, document |
| document\_id | Reference | Optional link |
| advance\_alerts | List | Offsets before due time |
| created\_at, updated\_at | Timestamp | For sync and conflict handling |

**Document**

| Field | Type | Notes |
| --- | --- | --- |
| id | UUID | Unique identifier |
| title | Text | For example "Passport" |
| category | Text | Identity, Finance, Health, and so on |
| tags | List | User-defined labels |
| file\_refs | List | Encrypted file paths for each page |
| extracted\_text | Text | Stored encrypted, used for search |
| detected\_dates | List | Label, date, confidence, user decision |
| created\_at, updated\_at | Timestamp | For sync |

**Category**: id, name, color, icon, is\_default.

**Settings**: language, default times for morning, afternoon, evening, notification sound, theme, text scale, lock method, backup preference.

**User (cloud only)**: id, contact identifier, created\_at, plan, device list.

### 10.2 Design decisions

- **UTC plus time zone.** Store due times in UTC and remember the original time zone. This allows correct behavior when the user travels or when daylight saving rules change.
- **Repeat rules, not copies.** A repeating reminder is stored as one record with a rule. The app computes the next occurrence after each completion, so the database does not fill with future duplicates.
- **Soft deletion.** Deleted reminders are marked rather than removed immediately, which makes sync reliable and allows an undo.
- **Conflict handling.** When two devices change the same reminder, the most recent update wins, and the app keeps a short history for recovery.

## 11. AI and Language Design

### 11.1 What the AI does

The AI has three narrow jobs, and nothing else.

1. **Extract structure** from a sentence: title, date, time, repeat, category, priority.
2. **Label dates in documents**: decide whether a detected date is an expiry, issue, due, or birth date.
3. **Understand retrieval requests**: map "show my passport" to the right document search.

Keeping the jobs narrow makes the system cheaper, faster, easier to test, and safer.

### 11.2 Structured output contract

The language model must return data in a fixed structure. An example for the sentence "Pay electricity bill on the 10th every month at 6 pm":

| Field | Value |
| --- | --- |
| intent | create\_reminder |
| title | Pay electricity bill |
| date | The next 10th |
| time | 18:00 |
| repeat | Monthly, day 10 |
| category | Bill |
| priority | Normal |
| confidence | 0.96 |
| needs\_clarification | false |

The backend rejects any response that does not match this structure and retries once with a corrective instruction. If it still fails, the app falls back to a plain reminder using the user's original text as the title.

### 11.3 Prompting rules

- Always provide the **current date, time, weekday, and time zone** with each request, because relative words such as "tomorrow" depend on them.
- Instruct the model to **never invent** a date or time that the user did not state, and to ask for clarification instead.
- Require a **confidence score**. Low-confidence results always trigger the confirmation card with the uncertain field highlighted.
- Provide a handful of examples in both English and Bangla, including transliterated Bangla written in Latin letters.
- Treat the user's text strictly as data. Instructions embedded inside a reminder or document must never change the app's behavior.

### 11.4 Bangla and mixed-language challenges

Bangla is the most important differentiator and the hardest part. The team should plan specific work for it.

- **Three writing styles.** Users will write Bangla script, Bangla in Latin letters ("kal bikel 5tay"), and English-Bangla mixes. All three must be supported and tested.
- **Time vocabulary.** Words such as "shokal", "dupur", "bikel", "shondhya", "raat", "porshu", and "agami" need clear mappings. "Porshu" is ambiguous because it can mean the day after tomorrow or the day before yesterday depending on tense, so the app should use verb context and, when uncertain, ask.
- **Numerals.** Support both Bangla digits and Western digits.
- **Calendars.** Version 1 should support the Gregorian calendar and treat the Bangla calendar as a later enhancement.
- **Test set.** Build a test set of at least 500 realistic Bangla and mixed sentences with known correct answers, and measure accuracy against it before every release.
- **Speech.** Evaluate several speech recognition providers on Bangla with real recordings from different ages, genders, accents, and noise levels, and choose based on measured error rates.

### 11.5 Cost and speed controls

- Use the local parser first and call the AI only when needed.
- Use a small, fast model for routine parsing and reserve a larger model for hard cases.
- Cache common phrasing patterns.
- Apply a per-user daily limit on AI requests, with generous free limits and higher limits on paid plans.
- Target a total response time under two seconds for the AI path.

## 12. Notification and Scheduling Engine

This section deserves special attention because it is where reminder apps most often fail. The operating systems actively restrict background work to save battery, and the rules differ between manufacturers.

### 12.1 Approach

Schedule every reminder as a **local, OS-managed notification** at creation time. Do not rely on a server to push the notification, because a push depends on network conditions and server health. Local scheduling works even when the phone is offline. A server push can serve as an optional backup channel for synced accounts.

### 12.2 Android considerations

- **Exact alarms.** Modern Android versions require a special permission for exact-time alarms. The app must request it, explain why, and warn the user that reminders may arrive a few minutes late if it is declined.
- **Boot persistence.** After a restart, scheduled alarms are cleared. The app must register to be notified at device boot and then reschedule all active reminders.
- **Battery optimization.** Many manufacturers (including Xiaomi, Oppo, Vivo, Samsung, and Huawei) aggressively stop background apps. Provide a settings guide with device-specific instructions and a one-tap shortcut to the correct system screen.
- **Notification channels.** Create separate channels for normal, important, and daily summary notifications so the user can control sound and priority per type.
- **Notification permission.** Recent Android versions require runtime permission to show notifications.
- **Do Not Disturb.** Important reminders may optionally request permission to bypass Do Not Disturb, but this must be the user's choice.

### 12.3 iOS considerations

- **Local notification limit.** iOS allows a limited number of pending local notifications per app (currently 64). The app must schedule only the nearest reminders and refill the queue whenever it opens or runs a background refresh.
- **Limited background control.** iOS delivers scheduled local notifications reliably, but custom behavior while the app is closed is limited. Design the notification itself to carry all required actions.
- **Time-sensitive notifications.** Use the time-sensitive interruption level for important reminders, with the user's permission.
- **Permission prompt.** The notification permission prompt appears only once. If it is declined, the app must guide the user to the system settings.

### 12.4 Reliability safeguards

- **Self-check on open.** Each time the app opens, compare the database with the scheduled notifications and repair any mismatch.
- **Daily repair task.** A periodic background task re-verifies the schedule.
- **Health indicator.** A small status line in settings shows "Notifications: working" or lists the specific problem (permission denied, battery restriction, exact alarm off).
- **Missed reminder recovery.** If the phone was off at the due time, the app shows the missed reminder as soon as it starts and marks it overdue.
- **Time change handling.** Reschedule when the system time zone or clock changes.
- **Delivery logging.** Record when each notification was scheduled and when it fired (locally and, with consent, as anonymous statistics) so the team can measure the delivery rate that the success metrics depend on.

## 13. Security, Privacy, and Compliance

The app will hold identity papers, medical records, and personal schedules. A privacy failure would destroy trust, so security is a design foundation.

### 13.1 Data protection

- **Encryption at rest.** The local database and document files are encrypted using keys stored in the device's secure hardware (Android Keystore, iOS Keychain).
- **Encryption in transit.** All network traffic uses modern TLS, with certificate validation.
- **End-to-end encrypted backup (recommended).** Documents are encrypted on the device before upload, so the cloud provider and the company cannot read them. The trade-off is that the user must keep a recovery key, because the company cannot recover a lost key.
- **Minimal AI exposure.** Send only the text that is needed for the task. Never send images of documents to the AI by default, and provide a clear explanation and an opt-in switch for any feature that does.
- **No training on user data.** Use AI providers under terms that do not train on submitted content, and state this in the privacy policy.

### 13.2 Access control

- App lock with biometrics or a PIN, required to open the vault and optionally the whole app.
- Automatic re-lock after a short idle period.
- Hide content in the recent-apps screen and block screenshots inside the vault (user-configurable).
- Notification previews for sensitive reminders can be hidden on the lock screen (for example showing "Reminder" instead of "Doctor appointment").

### 13.3 Backend security

- AI provider keys are stored only on the server and never in the app.
- Authentication tokens are short-lived, and requests are rate-limited per user and per device.
- Input is validated and size-limited on every endpoint.
- Logs must never contain reminder text, document text, or personal identifiers.
- Regular dependency updates and an external security review before public launch.

### 13.4 Privacy and legal

- Publish a plain-language privacy policy that lists what data is stored, where, for how long, and who can see it.
- Provide **export my data** and **delete my account and all data** options inside the app.
- Collect only what is necessary. Analytics must be anonymous and can be switched off.
- Comply with the data protection laws in the markets served, including Bangladesh's evolving data protection rules and, for European users, GDPR. Obtain legal review before launch.
- Complete the data-safety form on Google Play and the privacy labels on the Apple App Store accurately.

### 13.5 Safety notes for medicine reminders

Medicine reminders are among the most valuable use cases and among the most sensitive. The app must make clear that it is a convenience tool and not a medical device, must never suggest or change dosages, and should show a short notice when the user creates a reminder in the Medicine category.

## 14. Technology Stack

The recommendations below favor one shared codebase, mature libraries, and low operating cost. Each choice should be validated with a short prototype before it is locked in.

| Area | Recommendation | Reason | Alternative |
| --- | --- | --- | --- |
| Mobile framework | Flutter | One codebase for Android and iOS, strong UI toolkit, good Bangla text rendering | React Native |
| Local database | SQLite with encryption (for example SQLCipher) | Reliable, queryable, works offline | Hive, Isar |
| Local notifications | flutter\_local\_notifications plus native alarm code | Mature scheduling, actions, channels | Native modules |
| Voice input | On-device speech recognition first, cloud speech as fallback | Speed and offline use; cloud improves Bangla accuracy | Dedicated speech API |
| Text recognition (OCR) | On-device OCR (for example Google ML Kit) | Documents stay on the phone | Cloud OCR |
| Language understanding | Claude API through the backend | Strong at structured extraction and multilingual text | Other LLM providers |
| Backend | Small serverless API (Node.js or Python) | Low cost, scales automatically | Managed backend such as Firebase |
| Account and sync database | Managed cloud database | Less operational work | Self-hosted PostgreSQL |
| File backup | Encrypted object storage | Cheap, durable | Device-only storage |
| Authentication | Phone number or email with one-time code, plus optional social login | Familiar to the target market | Passwordless link |
| Analytics and crash reports | Privacy-friendly analytics and a crash reporter | Measure the success metrics | None |
| Payments | Google Play Billing and Apple in-app purchase | Required by the stores | Local payment gateways for web |

### 14.1 Technical decisions to settle early

- Whether to build the local parser in Dart or reuse a shared rules library, since it must be identical on both platforms.
- Which speech provider gives the best Bangla results in the real-world test.
- Whether end-to-end encrypted backup is a launch feature or a later upgrade.
- Which minimum Android and iOS versions to support (recommended: Android 8.0 and iOS 14 or newer, adjusted to the market's device mix).

## 15. Roadmap and Development Phases

The plan is organized into four phases, each ending with something usable. Durations assume a small team (see section 16) and should be treated as estimates.

| Phase | Duration | Theme | Main deliverables | Exit criteria |
| --- | --- | --- | --- | --- |
| 0. Discovery | 1 week | Validate and prepare | Interviews with 10 target users, final feature list, design system, Bangla test set started | Scope approved |
| 1. Foundation (MVP) | 3 weeks | Reliable reminders | Manual reminders, repeat rules, local notifications, snooze and done actions, boot persistence, home and list screens, onboarding | 99% delivery in lab tests on 10 devices |
| 2. Smart input | 3 weeks | Talk or type to create | Message-to-reminder, voice input, confirmation card, Bangla and English support, backend and AI integration | 90% English and 85% Bangla parsing accuracy on the test set |
| 3. Document vault | 3 weeks | Remember papers | Encrypted vault, camera import, OCR, date detection, expiry reminders, retrieval by search and by request, app lock | Date detection accuracy of 90% on a sample of 100 documents |
| 4. Polish and growth | 3 weeks | Ready for the public | Categories, daily summary, calendar view, widget, backup and sync, settings, accessibility, performance work | Beta feedback resolved, crash-free sessions of 99.5% |
| 5. Launch | 2 weeks | Release | Store listings, privacy policy, final testing, staged rollout | Approved on both stores |

Total planned duration: roughly **15 to 16 weeks** (about four months) from kickoff to public release.

### 15.1 Phase 1 in detail (the first build)

The first build should be small and excellent.

1. Project setup, design system, and navigation.
2. Local database and reminder model, including repeat rules.
3. Add, edit, delete, complete, and snooze reminders.
4. Notification scheduling for Android and iOS, with action buttons.
5. Boot rescheduling and the self-check routine.
6. Home screen with today, upcoming, and overdue sections.
7. Permission onboarding including the battery optimization guide.
8. Testing on a device matrix and fixing delivery problems.

Do not start Phase 2 until the Phase 1 delivery rate is proven. Smart features built on an unreliable base add no value.

### 15.2 After launch

| Horizon | Candidate features |
| --- | --- |
| 1 to 3 months | Shared reminders for family, Bangla calendar support, more repeat patterns, import from calendars |
| 3 to 6 months | Location reminders, wearable support, email-to-reminder forwarding, templates for common routines |
| 6 to 12 months | Smart suggestions based on habits, family vault, business plan for shops and teams, web companion app |

## 16. Team, Timeline, and Budget

### 16.1 Suggested team

| Role | Count | Responsibility |
| --- | --- | --- |
| Product owner | 1 | Priorities, user research, acceptance |
| UI and UX designer | 1 | Flows, screens, design system, Bangla typography |
| Mobile developer (Flutter) | 2 | App, notifications, voice, vault |
| Backend and AI engineer | 1 | API, AI integration, backup and sync |
| QA engineer | 1 | Device testing, automation, notification reliability |
| Part-time language specialist | 1 | Bangla test set and review |

A founder with strong technical skill can start alone with a Phase 1 prototype, but the full plan needs the roles above, either as employees or contractors.

### 16.2 Indicative running costs

The figures below are planning estimates only and must be replaced with real quotes.

| Item | Estimate | Notes |
| --- | --- | --- |
| Apple developer account | About USD 99 per year | Required for the App Store |
| Google Play developer account | USD 25 one time | Required for Google Play |
| Cloud hosting and storage | USD 20 to 100 per month at launch | Grows with users |
| AI usage | USD 0.001 to 0.01 per smart request | Reduced by the local parser and caching |
| Speech recognition | Depends on provider and usage | Prefer on-device where quality allows |
| Design and legal review | One-time project cost | Privacy policy, terms |
| Marketing | Variable | See section 18 |

Because the local parser handles simple input, the AI cost per active user should stay small. The team should track the cost per active user from the first beta and set a limit.

### 16.3 Ways to reduce cost and risk

- Launch Android first if the target market is mostly Android, then add iOS.
- Ship Phase 1 and Phase 2 as an early public beta to gather feedback before building the vault.
- Use managed services instead of building infrastructure.

## 17. Quality Assurance and Testing Strategy

Testing for a reminder app has one special rule: **time-based behavior must be tested across real devices and real time**, because emulators hide the problems that users actually experience.

### 17.1 Test layers

| Layer | What is tested | Method |
| --- | --- | --- |
| Unit tests | Date logic, repeat rules, time zone and daylight saving handling, local parser | Automated, run on every change |
| Parsing accuracy tests | The 500-sentence English, Bangla, and mixed test set | Automated, scored and tracked every release |
| Integration tests | Database, scheduler, backend, AI contract validation | Automated |
| UI tests | Main flows: create, edit, snooze, complete, vault import | Automated on emulators and cloud devices |
| Device matrix tests | Notification delivery on at least 15 real phones across brands and OS versions | Manual plus scripted, over 48 hours |
| Long-run tests | Reminders set for days and weeks ahead, restarts, airplane mode, low battery | Manual, scheduled |
| Security tests | Encryption, lock behavior, backup, API abuse | Review and external test |
| Accessibility tests | Screen readers, large fonts, contrast | Manual with real users |
| Beta test | 100 to 300 real users for four weeks | Staged release with feedback form |

### 17.2 Critical test scenarios

- A reminder set for five minutes ahead fires on time with the app closed, with the screen off, and in battery saver mode.
- A reminder survives a phone restart and an app update.
- A repeating reminder produces the correct next date after Done and after Snooze, including month-end and leap-year cases.
- Changing the phone's time zone, or traveling, does not shift reminders unexpectedly.
- A reminder created offline syncs correctly later.
- "Porshu", "agami shukrobar", and mixed sentences produce the right date or a clarifying question.
- A document with an expiry date creates the correct advance reminders.
- The vault cannot be opened without authentication, and screenshots are blocked where configured.
- Denying the microphone, camera, or notification permission leaves the app usable with clear guidance.

### 17.3 Release criteria

A release may ship only when all of the following hold: the notification delivery rate in the device lab is at least 99 percent, no known data-loss bug is open, parsing accuracy targets are met, and crash-free sessions in beta are at least 99.5 percent.

## 18. Launch, Growth, and Business Model

### 18.1 Positioning

**Smart Reminder is the easiest way to remember anything: say it, type it, or snap it.** The message to users is simple and emotional: "Stop worrying about forgetting." For the Bangla market, the strong differentiator is genuine understanding of Bangla speech and phrasing, which most global apps handle poorly.

### 18.2 Business model

A freemium model keeps the core promise free and charges for features that cost money to run or that serve power users.

| Plan | Price (indicative) | Includes |
| --- | --- | --- |
| Free | 0 | Unlimited manual reminders, daily limit of smart text and voice requests, vault with limited storage, local-only data |
| Plus | USD 2 to 4 per month or about USD 20 to 30 per year | Higher smart-input limits, larger vault, cloud backup and sync, widget themes, advanced repeat rules |
| Family (later) | USD 5 to 8 per month | Shared reminders, family vault, up to five members |
| Business (later) | Custom | Teams, shared compliance and license renewals |

Prices should be tested with local purchasing power in mind, and local payment options should be explored. The product must never hold basic reminder reliability behind a paywall.

### 18.3 Launch plan

1. **Private alpha (weeks 8 to 10).** Friends, family, and 20 target users, focused on notification reliability.
2. **Closed beta (weeks 11 to 14).** 100 to 300 users from Facebook groups, university communities, and professional networks. Collect parsing failures and add them to the test set.
3. **Soft launch (week 15).** Release on Google Play in the primary market with a staged rollout of 10 percent, 50 percent, then 100 percent.
4. **Public launch (week 16).** Add the App Store release. Announce with a short demo video showing one spoken sentence becoming a reminder.

### 18.4 Growth ideas

- Short videos showing real situations (forgotten bill, missed appointment) and the five-second fix.
- Partnerships with universities, clinics, and community groups.
- A referral reward of extra storage or a month of Plus.
- Seasonal content: exam season, Eid, tax and license renewal periods, school admission dates.
- Store optimization with Bangla and English keywords, screenshots in both languages, and a clear first screenshot showing voice input.

### 18.5 Metrics to watch after launch

- Activation: percentage of new users who create a reminder in the first session (target 70 percent or higher).
- Notification delivery rate and the reasons for failures by device brand.
- Share of reminders created by voice and by text, and their edit rates, which indicate understanding quality.
- Vault adoption: percentage of users who save at least one document.
- Conversion to a paid plan and churn.
- AI cost per active user.

## 19. Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| 1 | Notifications are delayed or blocked by manufacturer battery rules | High | High | Permission and battery guide, health indicator, self-check, device lab testing, optional backup push |
| 2 | Bangla speech recognition is inaccurate | High | Medium | Editable transcript, confirmation card, provider comparison, text fallback |
| 3 | AI misreads a date and the user misses an event | Medium | High | Always confirm, show the date in words and as a calendar date, ask when unsure |
| 4 | Privacy breach of documents | Low | Very high | Encryption, local-first storage, minimal cloud exposure, security review |
| 5 | AI costs grow faster than revenue | Medium | Medium | Local parser, caching, small models, usage limits, paid tiers |
| 6 | Users stop opening the app because it is not engaging | Medium | High | Daily summary, widget, quick-capture shortcut, useful defaults |
| 7 | Store rejection or policy problems (permissions, data safety) | Medium | Medium | Early policy review, accurate disclosures, justified permissions |
| 8 | Scope grows and the schedule slips | High | Medium | Strict phases, non-goals list, review at each exit criterion |
| 9 | Dependence on one AI provider | Low | Medium | Abstraction layer in the backend, fallback to the local parser |
| 10 | Medical reminder misunderstood as medical advice | Low | High | Clear disclaimer, no dosage suggestions, legal review |
| 11 | Key team member leaves | Medium | Medium | Documentation, code reviews, shared ownership |

## 20. Next Steps and Open Questions

### 20.1 Decisions needed from the product owner

1. **Platform priority.** Android first, iOS first, or both together?
2. **App name.** A short, memorable name that works in English and Bangla, with the domain and store names available.
3. **Languages at launch.** English and Bangla together, or English first?
4. **Business model.** Free with ads, freemium, or paid? (This plan recommends freemium without ads.)
5. **Backup approach.** Local only for launch, or cloud backup from day one?
6. **Team and budget.** Build in-house, hire contractors, or start with a solo prototype?

### 20.2 Recommended immediate actions (first two weeks)

- [ ] Confirm the platform, name, and language decisions above.
- [ ] Interview 10 target users about how they forget and what they use today.
- [ ] Write the first 150 Bangla and English test sentences for the parser.
- [ ] Create a clickable design prototype of Home, Add reminder, Confirmation card, and Vault.
- [ ] Build a one-week technical prototype: schedule a notification, survive a restart, and parse five sample sentences.
- [ ] Compare two or three speech recognition options with real Bangla recordings.
- [ ] Set up the repository, build pipeline, and crash reporting.

## Appendix A. Glossary

| Term | Meaning |
| --- | --- |
| Confirmation card | The screen that shows what the app understood before it saves a reminder |
| Local parser | Rules running on the phone that understand simple date and time phrases without internet |
| LLM | Large language model, the AI that turns free text into structured data |
| OCR | Optical character recognition, reading text from a photo or scan |
| Vault | The encrypted, locked area where documents are stored |
| Snooze | Delaying a reminder to fire again later |
| Exact alarm | An Android alarm that fires at a precise time instead of a flexible window |
| MVP | Minimum viable product, the smallest version that delivers real value |
| E2E encryption | Encryption where only the user's devices hold the keys |
| Freemium | A free base product with paid upgrades |

## Appendix B. Sample Bangla and Mixed Test Sentences

These examples show the kind of input the parser must handle. The final test set should contain at least 500 such sentences with verified answers.

| Input (Latin-letter Bangla or mixed) | Meaning | Expected result |
| --- | --- | --- |
| "Kal shokal 8tay ofis jete hobe" | Have to go to the office tomorrow at 8 AM | Tomorrow, 8:00 AM, "Go to office" |
| "Ei Shukrobar jummar namaz er por Rahim er shathe dekha" | Meet Rahim after Friday prayer | This Friday, around 1:30 PM, ask to confirm the time |
| "Protidin raat 10tay oshudh khete hobe" | Must take medicine every night at 10 | Daily, 10:00 PM, category Medicine |
| "Mayer jonmodin 5 Falgun" | Mom's birthday on 5 Falgun | Needs the Bangla calendar, so ask the user for the Gregorian date in version 1 |
| "Month er 10 tarikh bijli bill dite hobe" | Must pay the electricity bill on the 10th of the month | Monthly on day 10, category Bill |
| "Aro 2 ghonta por call korbo" | Will call in 2 more hours | Current time plus 2 hours |

## Appendix C. Version History

| Version | Date | Change |
| --- | --- | --- |
| 1.0 | November 4, 2026 | First complete planning document |
