# Feature Spec 33: Penguin Adaptive Theme, Visual-Only Composer & Minimalist Chat Bubbles

## Overview
Refines the Pingo Flutter client (`apps/mobile`) into a device-adaptive, minimalist Penguin visual system that respects the OS Light and Dark modes, eliminates decorative background patterns, standardizes dashboard navigation with vector icons, simplifies staged composer attachments into visual-only preview cards, and unifies chat bubbles with Pingo's multi-tool cards.

## 1. Device-Adaptive Penguin Palette (`AppColors.of(context)`)
| Token | Dark Mode (Matte Charcoal) | Light Mode (Soft Off-White) | Role |
| :--- | :--- | :--- | :--- |
| `bg` | `#0E0F12` | `#F5F6F8` | Solid, pattern-free scaffold background |
| `chrome` | `#121317` | `#FFFFFF` | Top bar / app bar surface |
| `card` | `#17191E` | `#FFFFFF` | Task cards, assistant bubbles, composer |
| `surface` | `#21242B` | `#ECEEF2` | User bubbles, metric tiles, nested tool cards |
| `border` | `#282C35` | `#E1E4EA` | Quiet 1px hairline border |
| `borderActive` | `#393F4D` | `#CBD0DA` | Focused/active border |
| `textPrimary` | `#FFFFFF` | `#111216` | Pure white / deep black primary typography |
| `textSecondary` | `#B2B7C2` | `#525763` | Secondary labels and metadata |
| `textMuted` | `#7E8594` | `#7B818F` | Timestamps, hints, subdued icons |
| `primaryFill` | `#FFFFFF` | `#111216` | High-contrast primary CTAs & Send button |
| `accent` | `#F09A2B` | `#E0861B` | Warm penguin-beak amber for active indicators & key actions |

- `AppTheme.lightTheme` (`Brightness.light`) and `AppTheme.darkTheme` (`Brightness.dark`) are both explicitly built and wired to `ThemeMode.system` in `PingoApp`.
- `TechCanvasBackground` renders a plain solid `ColoredBox(color: Theme.of(context).scaffoldBackgroundColor)` with `_PingoLedgerPainter` removed.

## 2. Dashboard Navigation Polish
- Replaced `'See all →'` text button next to *Remaining tasks* with a standardized `IconButton` using `Icons.chevron_right_rounded` (`key: ValueKey('see_all_tasks_button')`, tooltip `'View all tasks'`, warm amber foreground).

## 3. Visual-Only Staged Attachment Cards (`StagedAttachmentPreviewCard`)
- Removed the raw filename text box from composer attachment previews.
- Each staged attachment renders as a `56×56` rounded (`BorderRadius.circular(14)`) visual-only card:
  - Image attachments display a full-bleed `Image.file(..., fit: BoxFit.cover)` thumbnail.
  - Non-image documents display a clean centered vector icon (`Icons.picture_as_pdf_outlined` / `Icons.description_outlined`).
  - A compact circular `×` button in the top-right corner dismisses the staged item without auto-sending.

## 4. Minimalist Chat Bubbles & Unified Multi-Tool Layout
- Chat bubbles use soft uniform `18px` rounding, quiet `1px` borders, and harmonious `p.surface` (user) / `p.card` (assistant) fills instead of WhatsApp's asymmetric tails and green accents.
- Voice note playback controls use Penguin warm amber (`p.accent`) for Play/Pause and active slider progress.
- Reminders, documents, voice notes, and triggered completion alerts share one cohesive `14px` nested card rhythm.
