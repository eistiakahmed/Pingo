import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import '../state/home_reminder_provider.dart';
import '../widgets/read_only_task_card.dart';

/// Read-only autonomous task ledger screen using the device-adaptive Penguin palette.
class MyRemindersScreen extends ConsumerWidget {
  const MyRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppColors.of(context);
    final reminderState = ref.watch(homeReminderProvider);

    final scheduled = reminderState.scheduledReminders
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    final completed = reminderState.completedReminders
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.chrome,
        foregroundColor: p.textPrimary,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: p.border, width: 1),
        ),
        title: Text(
          'All tasks',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        ),
      ),
      body: scheduled.isEmpty && completed.isEmpty
          ? _buildEmptyState(p)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                if (scheduled.isNotEmpty) ...[
                  _sectionHeader(p, 'Scheduled (${scheduled.length})', p.accent),
                  ...scheduled.map((r) => ReadOnlyTaskCard(item: r)),
                ],
                if (completed.isNotEmpty) ...[
                  _sectionHeader(
                    p,
                    'Completed (${completed.length})',
                    p.success,
                  ),
                  ...completed.take(20).map((r) => ReadOnlyTaskCard(item: r)),
                ],
              ],
            ),
    );
  }

  Widget _sectionHeader(PenguinPalette p, String label, Color dotColor) {
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PenguinPalette p) {
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
                color: p.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.border, width: 1),
              ),
              child: Icon(
                Icons.schedule_rounded,
                color: p.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No tasks yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Send a voice note or message in chat to schedule an alarm automatically.',
              style: TextStyle(
                fontSize: 13,
                color: p.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
