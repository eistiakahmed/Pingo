import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/voice_audio_player_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';
import '../../domain/reminder_item.dart';
import 'read_only_task_card.dart';

/// Clean, minimal WhatsApp-inspired message & notification bubbles.
/// - Read-only zero-touch task cards with LLM category badges (`MEDICINE`, `BILL`, etc.).
/// - Interactive `just_audio` Play/Pause voice note bar.
/// - Bundled attachment pills on multimodal messages.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({
    super.key,
    required this.message,
  });

  String get _timeStr => DateFormat('HH:mm').format(message.timestamp);

  String get _dueStr {
    final d = message.reminderDueAt!;
    return '${DateFormat.jm().format(d)} · ${DateFormat('d MMM').format(d)}';
  }

  String _formatAudioDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (message.isAlarmTriggeredAlert) {
      return _buildTriggeredAlarmBubble(context);
    }
    if (message.isUser) return _buildUserBubble(context);
    return _buildAssistantBubble(context);
  }

  // ─────────────── MINIMAL TRIGGERED REMINDER CARD ───────────────

  Widget _buildTriggeredAlarmBubble(BuildContext context) {
    final cat = ReminderCategory.fromBackendString(message.reminderCategory);
    final badgeColor = categoryBadgeColor(cat);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inkBorderActive, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          cat.badgeLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: AppColors.paperSubtle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message.reminderTitle ?? message.text,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paperWhite,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── WHATSAPP-STYLE USER BUBBLE (RIGHT) ───────────────────

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 14),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(3),
          ),
          border: Border.all(color: AppColors.inkBorderActive, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.hasBundledAttachments) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: message.bundledAttachments.map((name) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.inkCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.inkBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 13,
                          color: AppColors.paperMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.paperMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.paperWhite,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _timeStr,
              style: const TextStyle(
                fontSize: 10.5,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppColors.paperSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── WHATSAPP-STYLE ASSISTANT BUBBLE (LEFT) ─────────────────

  Widget _buildAssistantBubble(BuildContext context) {
    final isEmptyBody = message.text.isEmpty &&
        !message.hasAudio &&
        !message.hasReminder &&
        !message.hasDocument;
    if (isEmptyBody) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 14),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: AppColors.inkBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasAudio) ...[
              _buildWhatsAppVoiceNoteBar(),
              if (message.text.isNotEmpty) const SizedBox(height: 6),
            ],

            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.paperWhite,
                    height: 1.4,
                  ),
                ),
              ),

            if (message.hasReminder) ...[
              if (message.text.isNotEmpty || message.hasAudio)
                const SizedBox(height: 6),
              _buildReadOnlyScheduledCard(),
            ],

            if (message.hasDocument) ...[
              if (message.text.isNotEmpty || message.hasAudio)
                const SizedBox(height: 6),
              _buildDocumentSlip(),
            ],

            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _timeStr,
                style: const TextStyle(
                  fontSize: 10.5,
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

  /// Minimal WhatsApp-style Voice Note bar (`just_audio`).
  Widget _buildWhatsAppVoiceNoteBar() {
    final playerService = VoiceAudioPlayerService.instance;
    return ListenableBuilder(
      listenable: playerService,
      builder: (context, _) {
        final isActive = playerService.isActiveMessage(message.id);
        final isPlaying = isActive && playerService.isPlaying;
        final isLoading = isActive && playerService.isLoading;
        final pos = isActive ? playerService.position : Duration.zero;
        final dur = isActive ? playerService.duration : Duration.zero;

        final maxMs =
            dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final curMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.inkSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  playerService.toggleOrPlay(
                    messageId: message.id,
                    audioUrl: message.audioUrl!,
                  );
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.inkBlack,
                          ),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.inkBlack,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                        activeTrackColor: AppColors.success,
                        inactiveTrackColor: AppColors.inkBorderActive,
                        thumbColor: AppColors.paperWhite,
                      ),
                      child: Slider(
                        value: curMs,
                        min: 0.0,
                        max: maxMs,
                        onChanged: isActive && dur.inMilliseconds > 0
                            ? (val) {
                                playerService.seekForMessage(
                                  message.id,
                                  Duration(milliseconds: val.round()),
                                );
                              }
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isActive ? _formatAudioDuration(pos) : '0:00',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: AppColors.paperMuted,
                            ),
                          ),
                          if (dur > Duration.zero)
                            Text(
                              _formatAudioDuration(dur),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: AppColors.paperSubtle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Read-only zero-touch scheduled alarm card with LLM category badge (no manual edit/undo).
  Widget _buildReadOnlyScheduledCard() {
    final cat = ReminderCategory.fromBackendString(message.reminderCategory);
    final badgeColor = categoryBadgeColor(cat);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inkBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cat.badgeLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: badgeColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _dueStr,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.paperMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.reminderTitle!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.paperWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSlip() {
    final cat = ReminderCategory.fromBackendString(
      message.documentCategory ?? 'DOCUMENT',
    );
    final badgeColor = categoryBadgeColor(cat);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inkBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppColors.paperMuted,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.documentTitle!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.paperWhite,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              cat.badgeLabel,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
