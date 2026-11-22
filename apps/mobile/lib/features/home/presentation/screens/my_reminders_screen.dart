import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/services/fcm_service.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/reminder_editor/presentation/screens/edit_reminder_screen.dart';
import '../../domain/reminder_item.dart';
import '../state/home_reminder_provider.dart';
import '../state/pingo_chat_provider.dart';

/// "My reminders" horological ledger screen.
/// - Sentence-case section labels (Overdue, Upcoming, Completed) without wide tracking.
/// - Uniform 4px grid rows with signature 6px status dot and tabular due time.
class MyRemindersScreen extends ConsumerWidget {
  const MyRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderState = ref.watch(homeReminderProvider);
    final isBangla =
        ref.watch(pingoChatProvider.select((s) => s.language)) == 'bn';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final active = reminderState.reminders
        .where((r) => !r.isDone)
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    final overdue = active.where((r) {
      final d = DateTime(r.dueAt.year, r.dueAt.month, r.dueAt.day);
      return d.isBefore(today);
    }).toList();
    final upcoming = active.where((r) => !overdue.contains(r)).toList();
    final done = reminderState.completedReminders.toList()
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
        title: Text(
          isBangla ? 'আমার রিমাইন্ডার' : 'My reminders',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.paperWhite,
          ),
        ),
        actions: [
          IconButton(
            tooltip: isBangla ? 'টেস্ট এলার্ট' : 'Test alert',
            icon: const Icon(Icons.notifications_none_rounded, size: 18),
            color: AppColors.paperMuted,
            onPressed: () {
              HapticFeedback.lightImpact();
              NotificationService.instance.showInstantTestNotification(
                title: isBangla ? 'পিঙ্গো টেস্ট এলার্ট' : 'Pingo test alert',
                body: isBangla
                    ? 'এলার্ম এবং নোটিফিকেশন সক্রিয় রয়েছে'
                    : 'Alarms and notifications are operational',
              );
              FcmService.instance.triggerBackendTestPush();
            },
          ),
        ],
      ),
      body: active.isEmpty && done.isEmpty
          ? _buildEmptyState(isBangla)
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                if (overdue.isNotEmpty) ...[
                  _sectionHeader(
                    isBangla ? 'সময় উত্তীর্ণ' : 'Overdue',
                    AppColors.overdue,
                  ),
                  ...overdue.map(
                    (r) => _reminderTile(
                      context,
                      ref,
                      r,
                      isBangla,
                      AppColors.overdue,
                    ),
                  ),
                ],
                if (upcoming.isNotEmpty) ...[
                  _sectionHeader(
                    isBangla ? 'আসন্ন' : 'Upcoming',
                    AppColors.signalAmber,
                  ),
                  ...upcoming.map(
                    (r) => _reminderTile(
                      context,
                      ref,
                      r,
                      isBangla,
                      AppColors.signalAmber,
                    ),
                  ),
                ],
                if (done.isNotEmpty) ...[
                  _sectionHeader(
                    isBangla ? 'সম্পন্ন' : 'Completed',
                    AppColors.success,
                  ),
                  ...done.take(10).map(
                        (r) => _reminderTile(
                          context,
                          ref,
                          r,
                          isBangla,
                          AppColors.success,
                        ),
                      ),
                ],
              ],
            ),
    );
  }

  Widget _sectionHeader(String label, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
              fontWeight: FontWeight.w500,
              color: AppColors.paperMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderTile(
    BuildContext context,
    WidgetRef ref,
    ReminderItem r,
    bool isBangla,
    Color statusColor,
  ) {
    final timeStr = DateFormat.jm().format(r.dueAt);
    final dateStr = DateFormat('d MMM').format(r.dueAt);

    return Dismissible(
      key: ValueKey('reminder_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.overdue,
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.paperWhite,
          size: 18,
        ),
      ),
      onDismissed: (_) {
        ref.read(homeReminderProvider.notifier).deleteReminder(r.id);
      },
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          EditReminderScreen.show(
            context: context,
            initialItem: r,
            onSave: (saved) {
              ref.read(homeReminderProvider.notifier).updateReminder(saved);
            },
            onDelete: () {
              ref.read(homeReminderProvider.notifier).deleteReminder(r.id);
            },
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.inkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inkBorder, width: 1),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  ref.read(homeReminderProvider.notifier).toggleDone(r.id);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: r.isDone
                          ? AppColors.success
                          : AppColors.inkBorderActive,
                      width: 1.5,
                    ),
                    color: r.isDone ? AppColors.success : Colors.transparent,
                  ),
                  child: r.isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.inkBlack,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: r.isDone
                            ? AppColors.paperSubtle
                            : AppColors.paperWhite,
                        decoration:
                            r.isDone ? TextDecoration.lineThrough : null,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$timeStr · $dateStr',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: AppColors.paperSubtle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.paperSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isBangla) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.inkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inkBorder, width: 1),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.paperSubtle,
                size: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isBangla ? 'কোনো রিমাইন্ডার নেই' : 'No scheduled alarms',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.paperWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isBangla
                  ? 'চ্যাটে লিখে বা বলে রিমাইন্ডার যোগ করুন'
                  : 'Write or speak a reminder in the chat',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
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
