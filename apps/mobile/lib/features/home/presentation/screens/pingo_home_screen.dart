import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import 'package:pingo_mobile/features/home/presentation/state/home_reminder_provider.dart';
import 'package:pingo_mobile/features/session_chat/presentation/screens/pingo_flow_screen.dart';
import 'package:pingo_mobile/features/vault/presentation/screens/pingo_vault_screen.dart';
import 'package:pingo_mobile/features/vault/presentation/screens/pingo_add_document_screen.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/screens/pingo_voice_screen.dart';
import 'package:pingo_mobile/features/profile/presentation/screens/pingo_profile_screen.dart';

/// Flagship Architectural Minimalist Dashboard for Pingo.
/// Monochromatic ink & paper aesthetic, live task agenda, and precision voice/text input.
class PingoHomeScreen extends ConsumerStatefulWidget {
  const PingoHomeScreen({super.key});

  @override
  ConsumerState<PingoHomeScreen> createState() => _PingoHomeScreenState();
}

class _PingoHomeScreenState extends ConsumerState<PingoHomeScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submitText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputController.clear();

    final lower = trimmed.toLowerCase();

    // Task inquiry detection (today, tomorrow, all tasks)
    final isQueryTasks = lower.contains('what do i have') ||
        lower.contains('task') ||
        lower.contains('tasks') ||
        lower.contains('schedule') ||
        lower.contains('কী আছে') ||
        lower.contains('কি আছে') ||
        lower.contains('টাস্ক') ||
        (lower.contains('what') && lower.contains('tomorrow')) ||
        (lower.contains('what') && lower.contains('today'));

    if (isQueryTasks) {
      PingoFlowScreen.open(context, scenario: FlowScenario.askAboutToday, prompt: trimmed);
    } else {
      PingoFlowScreen.open(context, scenario: FlowScenario.autoSaved, prompt: trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminderState = ref.watch(homeReminderProvider);
    final reminders = reminderState.reminders;
    final pendingCount = reminders.where((r) => !r.isDone).length;
    final now = DateTime.now();
    final formattedDate = DateFormat('EEE, d MMM').format(now).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Editorial Masthead
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'PINGO • EXECUTIVE SYSTEM',
                            style: AppTypography.monoLabel(
                              color: AppColors.paperSubtle,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PINGO.',
                        style: AppTypography.masthead(color: AppColors.paperWhite),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _actionPill(formattedDate, null, false),
                      const SizedBox(width: 8),
                      _actionPill('VAULT', () => PingoVaultScreen.open(context), true),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.inkBorder, height: 1, thickness: 1),

            // 2. Metrics Rule Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AGENDA — $pendingCount PENDING',
                    style: AppTypography.monoLabel(
                      color: AppColors.paperSubtle,
                      fontSize: 11,
                    ),
                  ),
                  InkWell(
                    onTap: () => PingoProfileScreen.open(context),
                    child: Text(
                      'STATUS: ONLINE',
                      style: AppTypography.monoLabel(
                        color: AppColors.paperMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Live Agenda / Tasks List (Architectural Rows)
            Expanded(
              child: reminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'NO PENDING TASKS',
                            style: AppTypography.monoLabel(
                              color: AppColors.paperSubtle,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Speak or type below to create an instant reminder.',
                            style: AppTypography.bodySmall(color: AppColors.paperSubtle),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: reminders.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: AppColors.inkBorder,
                        height: 1,
                        thickness: 0.8,
                      ),
                      itemBuilder: (context, index) {
                        final item = reminders[index];
                        return _buildReminderRow(item);
                      },
                    ),
            ),

            // 4. Quick Architectural Filter Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('TODAY\'S AGENDA', () {
                      PingoFlowScreen.open(
                        context,
                        scenario: FlowScenario.askAboutToday,
                        prompt: 'What do I have today?',
                      );
                    }),
                    const SizedBox(width: 8),
                    _chip('TEST ALERT', () {
                      PingoFlowScreen.open(
                        context,
                        scenario: FlowScenario.autoSaved,
                        prompt: 'test alert',
                      );
                    }),
                    const SizedBox(width: 8),
                    _chip('NEW REMINDER', () {
                      PingoVoiceScreen.show(context, onSpeechFinished: (speech) {
                        _submitText(speech);
                      });
                    }),
                  ],
                ),
              ),
            ),

            // 5. Precision Bottom Input Dock
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.inkSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inkBorder, width: 1),
              ),
              child: Row(
                children: [
                  // Attachment button
                  InkWell(
                    onTap: () => PingoAddDocumentScreen.open(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'DOC',
                        style: AppTypography.monoLabel(
                          color: AppColors.paperSubtle,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                  // Mic voice trigger
                  InkWell(
                    onTap: () {
                      PingoVoiceScreen.show(context, onSpeechFinished: (speech) {
                        _submitText(speech);
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'MIC',
                        style: AppTypography.monoLabel(
                          color: AppColors.paperWhite,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: _submitText,
                      style: AppTypography.bodyMedium(color: AppColors.paperWhite),
                      decoration: InputDecoration(
                        hintText: 'Type or speak in English, বাংলা...',
                        hintStyle: AppTypography.bodyMedium(color: AppColors.paperSubtle),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),

                  // Send button
                  InkWell(
                    onTap: () => _submitText(_inputController.text),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.titanium,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ENTER',
                        style: AppTypography.monoLabel(
                          color: AppColors.inkBlack,
                          fontSize: 11,
                        ),
                      ),
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

  Widget _buildReminderRow(ReminderItem item) {
    final timeStr = DateFormat('h:mm a').format(item.dueAt);
    final dateStr = DateFormat('d MMM').format(item.dueAt).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Minimalist circular toggle ring
          InkWell(
            onTap: () {
              ref.read(homeReminderProvider.notifier).toggleDone(item.id);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.isDone ? AppColors.paperSubtle : AppColors.paperWhite,
                  width: 1.5,
                ),
                color: item.isDone ? AppColors.paperSubtle : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.bodyLarge(
                    color: item.isDone ? AppColors.paperSubtle : AppColors.paperWhite,
                  ).copyWith(
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.paperSubtle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr • $timeStr',
                  style: AppTypography.monoLabel(
                    color: AppColors.paperSubtle,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Delete Action
          InkWell(
            onTap: () {
              ref.read(homeReminderProvider.notifier).deleteReminder(item.id);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'DEL',
                style: AppTypography.monoLabel(
                  color: AppColors.paperSubtle,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPill(String label, VoidCallback? onTap, bool isInteractive) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.inkBorder, width: 1),
        ),
        child: Text(
          label,
          style: AppTypography.monoLabel(
            color: isInteractive ? AppColors.paperWhite : AppColors.paperMuted,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.inkBorder, width: 1),
          color: AppColors.inkSurface,
        ),
        child: Text(
          label,
          style: AppTypography.monoLabel(
            color: AppColors.paperWhite,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
}
