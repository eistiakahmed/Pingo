import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';

/// Unslop message bubbles & Horological Alarm Ticket moments.
/// - Single Ink neutral ramp (#1A1E28 user surface, #11141C assistant card).
/// - Nested radius: outer 16px with 8px padding → inner ticket radius 8px.
/// - Signature detail: 6px status dot (amber pending, sage confirmed) paired
///   with tabular timestamp (`HH:MM · DD MMM`).
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

  String get _timeStr => DateFormat('HH:mm').format(message.timestamp);

  String get _dueStr {
    final d = message.reminderDueAt!;
    return '${DateFormat.jm().format(d)} · ${DateFormat('d MMM').format(d)}';
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.inkBorderActive, width: 1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.paperWhite,
                  height: 1.45,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Text(
                _timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.paperSubtle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── ASSISTANT ───────────────────────────

  Widget _buildAssistantBubble(BuildContext context) {
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.inkBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 44, 4),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.paperWhite,
                    height: 1.45,
                  ),
                ),
              ),

            if (message.hasPendingReminder) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              _buildPendingAlarmTicket(),
            ] else if (message.hasReminder) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              _buildConfirmedAlarmTicket(),
            ],

            if (message.hasDocument) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              _buildDocumentSlip(),
            ],

            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: AppColors.paperSubtle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Moment 1A: Confirmed Horological Alarm Ticket (Inner radius = 16 - 8 = 8px).
  Widget _buildConfirmedAlarmTicket() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inkBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signature timestamp row: 6px sage status dot + tabular figures
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isBangla ? 'রিমাইন্ডার নির্ধারিত' : 'Alarm scheduled',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paperMuted,
                ),
              ),
              const Spacer(),
              Text(
                _dueStr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.paperMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.reminderTitle!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.paperWhite,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Moment 1B: Pending Horological Alarm Ticket with tactile confirmation controls.
  Widget _buildPendingAlarmTicket() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inkBorderActive, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signature timestamp row: 6px signal-amber dot + tabular due time
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.signalAmber,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isBangla ? 'সময় নিশ্চিত করুন' : 'Confirm alarm',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.signalAmber,
                ),
              ),
              const Spacer(),
              Text(
                _dueStr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.paperWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.reminderTitle!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.paperWhite,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onConfirmReminder,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.paperWhite,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isBangla ? 'নিশ্চিত করুন' : 'Schedule',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkBlack,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onDiscardReminder,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.inkCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.inkBorder, width: 1),
                  ),
                  child: Text(
                    isBangla ? 'বাতিল' : 'Discard',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paperMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Moment 2: Encrypted Document Slip (Inner radius = 8px, fixed 18px icon column).
  Widget _buildDocumentSlip() {
    final fileSizeText = message.fileSize != null
        ? '${(message.fileSize! / 1024).toStringAsFixed(1)} KB'
        : 'AES-256';

    return InkWell(
      onTap: onSetExpiryAlert,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.inkBorder, width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              child: Icon(
                Icons.description_outlined,
                color: AppColors.paperMuted,
                size: 18,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paperWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBangla
                        ? 'মেয়াদ এলার্ট সেট করুন · $fileSizeText'
                        : 'Set expiry alert · $fileSizeText',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: AppColors.paperSubtle,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.paperSubtle,
            ),
          ],
        ),
      ),
    );
  }
}
