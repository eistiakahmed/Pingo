import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/voice_audio_player_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';

/// WhatsApp-style message bubbles, Voice Note Play/Pause audio bar (`just_audio`),
/// Auto-Saved Horological Alarm Tickets, and Triggered Reminder Alert Bubbles.
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

  // ─────────────── TRIGGERED REMINDER ALERT BUBBLE ───────────────

  Widget _buildTriggeredAlarmBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.signalAmber, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.signalAmber.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.signalAmber,
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
                      const Text(
                        'Reminder Triggered',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.signalAmber,
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
                  const SizedBox(height: 4),
                  Text(
                    message.reminderTitle ?? message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.paperWhite,
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

  // ───────────────────────────── USER (RIGHT) ─────────────────────────────

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

  // ─────────────────────────── ASSISTANT (LEFT) ───────────────────────────

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
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.all(10),
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
            // WhatsApp-Style Voice Note Play/Pause Bar (`just_audio`)
            if (message.hasAudio) ...[
              _buildWhatsAppVoiceNoteBar(),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
            ],

            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 12, 4),
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
              if (message.text.isNotEmpty || message.hasAudio)
                const SizedBox(height: 8),
              _buildPendingAlarmTicket(),
            ] else if (message.hasReminder) ...[
              if (message.text.isNotEmpty || message.hasAudio)
                const SizedBox(height: 8),
              _buildConfirmedAlarmTicket(),
            ],

            if (message.hasDocument) ...[
              if (message.text.isNotEmpty || message.hasAudio)
                const SizedBox(height: 8),
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

  /// WhatsApp-style Voice Note Player bar powered by `VoiceAudioPlayerService` (`just_audio`).
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPlaying ? AppColors.success : AppColors.inkBorderActive,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Play / Pause Circular Button
              InkWell(
                onTap: () {
                  playerService.toggleOrPlay(
                    messageId: message.id,
                    audioUrl: message.audioUrl!,
                  );
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
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
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 8),

              // Progress Slider + Duration Counter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
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
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isActive
                                ? _formatAudioDuration(pos)
                                : 'Voice reply',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: AppColors.paperMuted,
                            ),
                          ),
                          Text(
                            dur > Duration.zero
                                ? _formatAudioDuration(dur)
                                : 'Tap to play',
                            style: const TextStyle(
                              fontSize: 11,
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

  /// Moment 1A: Auto-Saved Horological Alarm Ticket with 1-tap Undo link.
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
              const Text(
                'Saved automatically',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  message.reminderTitle!,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paperWhite,
                    height: 1.4,
                  ),
                ),
              ),
              if (onDiscardReminder != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onDiscardReminder,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.inkCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.inkBorder, width: 1),
                    ),
                    child: const Text(
                      'Undo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.paperMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

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
              const Text(
                'Confirm alarm',
                style: TextStyle(
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
                    child: const Text(
                      'Schedule',
                      style: TextStyle(
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
                  child: const Text(
                    'Discard',
                    style: TextStyle(
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

  Widget _buildDocumentSlip() {
    final fileSizeText = message.fileSize != null
        ? '${(message.fileSize! / 1024).toStringAsFixed(1)} KB'
        : (message.documentCategory ?? 'Saved note');

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
                    fileSizeText,
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
