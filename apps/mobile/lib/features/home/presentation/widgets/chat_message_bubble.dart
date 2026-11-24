import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/voice_audio_player_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';
import '../../domain/reminder_item.dart';
import 'read_only_task_card.dart';

/// Minimalist, device-adaptive Penguin message & unified tool cards.
/// - Softly rounded (`18px`) unobtrusive bubbles harmonizing with Light/Dark mode.
/// - Unified nested cards (`14px`) for reminders, documents, voice notes, and triggered alerts.
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

  // ─────────────── UNIFIED TRIGGERED COMPLETION CARD ───────────────

  Widget _buildTriggeredAlarmBubble(BuildContext context) {
    final p = AppColors.of(context);
    final cat = ReminderCategory.fromBackendString(message.reminderCategory);
    final badgeColor = categoryBadgeColor(cat, isDark: p.isDark);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.86;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.success.withValues(alpha: p.isDark ? 0.16 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: p.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(
                        label: cat.badgeLabel,
                        color: badgeColor,
                        isDark: p.isDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: p.success,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.reminderTitle ?? message.text,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: p.textPrimary,
                      height: 1.35,
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

  // ─────────────────── MINIMALIST USER BUBBLE (RIGHT) ───────────────────

  Widget _buildUserBubble(BuildContext context) {
    final p = AppColors.of(context);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.hasBundledAttachments) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.bundledAttachments.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.border, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          size: 13,
                          color: p.accent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: p.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: p.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeStr,
              style: TextStyle(
                fontSize: 10.5,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: p.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── MINIMALIST ASSISTANT BUBBLE (LEFT) ─────────────────

  Widget _buildAssistantBubble(BuildContext context) {
    final isEmptyBody = message.text.isEmpty &&
        !message.hasAudio &&
        !message.hasReminder &&
        !message.hasDocument;
    if (isEmptyBody) return const SizedBox.shrink();

    final p = AppColors.of(context);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.86;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasAudio) ...[
              _buildVoiceNoteBar(p),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: p.textPrimary,
                  height: 1.45,
                ),
              ),
            if (message.hasReminder) ...[
              if (message.text.isNotEmpty || message.hasAudio)
                const SizedBox(height: 8),
              _buildReadOnlyScheduledCard(p),
            ],
            if (message.hasDocument) ...[
              if (message.text.isNotEmpty || message.hasAudio)
                const SizedBox(height: 8),
              _buildDocumentSlip(p),
            ],
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _timeStr,
                style: TextStyle(
                  fontSize: 10.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: p.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Minimalist Penguin Voice Note bar (`just_audio`) with warm amber accent.
  Widget _buildVoiceNoteBar(PenguinPalette p) {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border, width: 1),
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.accent,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onAccent,
                          ),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: p.onAccent,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 8),
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
                        activeTrackColor: p.accent,
                        inactiveTrackColor: p.borderActive,
                        thumbColor: p.primaryFill,
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
                            style: TextStyle(
                              fontSize: 10.5,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: p.textSecondary,
                            ),
                          ),
                          if (dur > Duration.zero)
                            Text(
                              _formatAudioDuration(dur),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: p.textMuted,
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

  /// Unified read-only scheduled reminder card with LLM category badge.
  Widget _buildReadOnlyScheduledCard(PenguinPalette p) {
    final cat = ReminderCategory.fromBackendString(message.reminderCategory);
    final badgeColor = categoryBadgeColor(cat, isDark: p.isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryBadge(
                label: cat.badgeLabel,
                color: badgeColor,
                isDark: p.isDark,
              ),
              const Spacer(),
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: p.accent,
              ),
              const SizedBox(width: 4),
              Text(
                _dueStr,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.reminderTitle!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Unified saved document slip card.
  Widget _buildDocumentSlip(PenguinPalette p) {
    final cat = ReminderCategory.fromBackendString(
      message.documentCategory ?? 'DOCUMENT',
    );
    final badgeColor = categoryBadgeColor(cat, isDark: p.isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            color: p.accent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.documentTitle!,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: p.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _CategoryBadge(
            label: cat.badgeLabel,
            color: badgeColor,
            isDark: p.isDark,
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _CategoryBadge({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}
