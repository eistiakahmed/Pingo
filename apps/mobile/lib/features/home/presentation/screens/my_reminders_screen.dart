import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import '../state/home_reminder_provider.dart';
import '../widgets/read_only_task_card.dart';

/// Read-only autonomous task ledger screen.
/// Manual edit, delete, and checkbox completion controls are removed;
/// tasks transition automatically from `Scheduled` -> `Completed` when due.
class MyRemindersScreen extends ConsumerWidget {
  const MyRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderState = ref.watch(homeReminderProvider);

    final scheduled = reminderState.scheduledReminders
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    final completed = reminderState.completedReminders
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      appBar: AppBar(
        backgroundColor: AppColors.inkDeep,
        foregroundColor: AppColors.paperWhite,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.inkBorder, width: 1),
        ),
        title: const Text(
          'All tasks',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.paperWhite,
          ),
        ),
      ),
      body: scheduled.isEmpty && completed.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                if (scheduled.isNotEmpty) ...[
                  _sectionHeader('Scheduled (${scheduled.length})', AppColors.signalAmber),
                  ...scheduled.map((r) => ReadOnlyTaskCard(item: r)),
                ],
                if (completed.isNotEmpty) ...[
                  _sectionHeader('Completed (${completed.length})', AppColors.success),
                  ...completed.take(20).map((r) => ReadOnlyTaskCard(item: r)),
                ],
              ],
            ),
    );
  }

  Widget _sectionHeader(String label, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.paperMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.inkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inkBorder, width: 1),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.paperSubtle,
                size: 20,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No tasks yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.paperWhite,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send a voice note or message in chat to schedule an alarm automatically.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.paperSubtle,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
