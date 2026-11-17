import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/chat_message.dart';

/// WhatsApp-style message bubbles: compact user bubbles (kept blue gradient),
/// tidy assistant bubbles, a SMALL confirmation bubble for reminders
/// ("Reminder set: Title, 12:00 AM, Nov 18" built from structured fields —
/// never free-form AI prose), and tappable encrypted document cards.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isBangla;
  final VoidCallback? onConfirmReminder;
  final VoidCallback? onDiscardReminder;
  final VoidCallback? onSetExpiryAlert;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.isBangla = false,
    this.onConfirmReminder,
    this.onDiscardReminder,
    this.onSetExpiryAlert,
  });

  static const _userGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  String get _timeStr => DateFormat.jm().format(message.timestamp);

  String get _dueStr {
    final d = message.reminderDueAt!;
    return '${DateFormat.jm().format(d)}, ${DateFormat.MMMd().format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    if (message.isUser) return _buildUserBubble(context);
    return _buildAssistantBubble(context);
  }

  // ───────────────────────────── USER ─────────────────────────────

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
        padding: const EdgeInsets.only(
          left: 14,
          right: 12,
          top: 8,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          gradient: _userGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Reserve space on the last line for the inline timestamp,
            // WhatsApp-style: the time sits inside the bubble bottom-right.
            Padding(
              padding: const EdgeInsets.only(right: 46),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 15.5,
                  color: Colors.white,
                  height: 1.45, // Bangla-safe line height
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── ASSISTANT ───────────────────────────

  Widget _buildAssistantBubble(BuildContext context) {
    const bubbleBg = Color(0xFF1B2436);
    const bubbleBorder = Color(0xFF253048);
    const textColor = Color(0xFFF1F5F9);

    // Nothing to render (e.g. fully discarded proposal) — skip silently.
    final isEmptyBody = message.text.isEmpty &&
        !message.hasReminder &&
        !message.hasDocument;
    if (isEmptyBody) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: bubbleBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 44),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: textColor,
                      height: 1.45, // Bangla-safe line height
                    ),
                  ),
                ),

              // Pending proposal → compact confirm bubble with inline ✓ / ✗
              if (message.hasPendingReminder) ...[
                const SizedBox(height: 6),
                _buildCompactPendingRow(),
              ]
              // Confirmed reminder → one small tidy confirmation bubble
              else if (message.hasReminder) ...[
                const SizedBox(height: 6),
                _buildCompactReminderSetRow(),
              ],

              // Encrypted document card (tap to configure expiry alert)
              if (message.hasDocument) ...[
                const SizedBox(height: 6),
                _buildDocumentCard(),
              ],

              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _timeStr,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small, tidy confirmation: "Reminder set: Title, 12:00 AM, Nov 18".
  /// Time and date live inside the bubble, small — built from structured
  /// fields in app code, so it can never contain AI spelling mistakes.
  Widget _buildCompactReminderSetRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF102A1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF14532D), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.alarm_rounded,
            size: 17,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: isBangla ? 'রিমাইন্ডার সেট হয়েছে: ' : 'Reminder set: ',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6EE7B7),
                    ),
                  ),
                  TextSpan(
                    text: message.reminderTitle!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  TextSpan(
                    text: '\n$_dueStr',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pending proposal: same compact shape, amber, with tiny inline actions.
  /// The zero-false-alarm gate is preserved: no alarm exists until confirmed.
  Widget _buildCompactPendingRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F0E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF78350F), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 17,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: isBangla ? 'রিমাইন্ডার সেট করবেন? ' : 'Set reminder? ',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFCD34D),
                    ),
                  ),
                  TextSpan(
                    text: message.reminderTitle!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  TextSpan(
                    text: '\n$_dueStr',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Tiny inline confirm / discard actions
          InkWell(
            onTap: onConfirmReminder,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF10B981),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 15, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDiscardReminder,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 15, color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact encrypted document card. The always-visible "Set Expiry Alert"
  /// button was removed from the chat per spec — the whole card is now
  /// tappable to configure the expiry alert.
  Widget _buildDocumentCard() {
    final fileSizeText = message.fileSize != null
        ? '${(message.fileSize! / 1024).toStringAsFixed(1)} KB'
        : 'AES-256';

    return InkWell(
      onTap: onSetExpiryAlert,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1B2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF16283F),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF25405F), width: 1),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF38BDF8),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.documentTitle!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF8FAFC),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isBangla
                        ? 'ট্যাপ করে মেয়াদ এলার্ট সেট করুন · $fileSizeText'
                        : 'Tap to set expiry alert · $fileSizeText',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
