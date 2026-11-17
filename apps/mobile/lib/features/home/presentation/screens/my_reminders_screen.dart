import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/services/fcm_service.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/features/reminder_editor/presentation/screens/edit_reminder_screen.dart';
import '../../domain/reminder_item.dart';
import '../state/home_reminder_provider.dart';
import '../state/pingo_chat_provider.dart';

/// "My reminders": a dedicated screen listing upcoming reminders where the
/// user can edit or delete them. The chat never renders reminder lists —
/// this screen is the single source for managing saved reminders.
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
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111726),
        foregroundColor: const Color(0xFFF1F5F9),
        elevation: 0,
        title: Text(
          isBangla ? 'আমার রিমাইন্ডার' : 'My reminders',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF1F5F9),
          ),
        ),
        actions: [
          // Test Alert lives here now — moved out of the chat per spec.
          IconButton(
            tooltip: isBangla ? 'টেস্ট এলার্ট' : 'Test alert',
            icon: const Icon(Icons.notifications_active_rounded, size: 21),
            color: const Color(0xFF38BDF8),
            onPressed: () {
              HapticFeedback.lightImpact();
              NotificationService.instance.showInstantTestNotification(
                title: isBangla ? 'পিঙ্গো টেস্ট এলার্ট' : 'Pingo Test Alert',
                body: isBangla
                    ? 'এলার্ম এবং নোটিফিকেশন ইঞ্জিন সফলভাবে সক্রিয় রয়েছে।'
                    : 'Alarms and notification engine are fully operational.',
              );
              FcmService.instance.triggerBackendTestPush();
            },
          ),
        ],
      ),
      body: active.isEmpty && done.isEmpty
          ? _buildEmptyState(isBangla)
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                if (overdue.isNotEmpty) ...[
                  _sectionHeader(
                    isBangla ? 'ওভারডিউ' : 'OVERDUE',
                    const Color(0xFFF87171),
                  ),
                  ...overdue
                      .map((r) => _reminderTile(context, ref, r, isBangla)),
                ],
                if (upcoming.isNotEmpty) ...[
                  _sectionHeader(
                    isBangla ? 'আসন্ন' : 'UPCOMING',
                    const Color(0xFF38BDF8),
                  ),
                  ...upcoming
                      .map((r) => _reminderTile(context, ref, r, isBangla)),
                ],
                if (done.isNotEmpty) ...[
                  _sectionHeader(
                    isBangla ? 'সম্পন্ন' : 'COMPLETED',
                    const Color(0xFF10B981),
                  ),
                  ...done.take(10)
                      .map((r) => _reminderTile(context, ref, r, isBangla)),
                ],
              ],
            ),
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _reminderTile(
      BuildContext context, WidgetRef ref, ReminderItem r, bool isBangla) {
    final timeStr = DateFormat.jm().format(r.dueAt);
    final dateStr = DateFormat.MMMd().format(r.dueAt);

    return Dismissible(
      key: ValueKey('reminder_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: const Color(0xFFEF4444),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        // Cancels the exact alarm + removes locally + syncs deletion upstream.
        ref.read(homeReminderProvider.notifier).deleteReminder(r.id);
      },
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          EditReminderScreen.show(
            context: context,
            initialItem: r,
            onSave: (saved) {
              // Reschedules the exact alarm through the reminder engine.
              ref.read(homeReminderProvider.notifier).updateReminder(saved);
            },
            onDelete: () {
              ref.read(homeReminderProvider.notifier).deleteReminder(r.id);
            },
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B), width: 1),
          ),
          child: Row(
            children: [
              // Completion toggle
              InkWell(
                onTap: () {
                  ref.read(homeReminderProvider.notifier).toggleDone(r.id);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: r.isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF475569),
                      width: 1.6,
                    ),
                    color: r.isDone
                        ? const Color(0xFF10B981)
                        : Colors.transparent,
                  ),
                  child: r.isDone
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: r.isDone
                            ? const Color(0xFF64748B)
                            : const Color(0xFFF1F5F9),
                        decoration:
                            r.isDone ? TextDecoration.lineThrough : null,
                        height: 1.45, // Bangla-safe line height
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr · $dateStr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: r.isDone
                            ? const Color(0xFF475569)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isBangla) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF131B2A),
              border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: Colors.grey[500],
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isBangla ? 'কোনো রিমাইন্ডার নেই' : 'No reminders yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBangla
                ? 'চ্যাটে লিখে বা বলে রিমাইন্ডার যোগ করুন।'
                : 'Add reminders by typing or speaking in the chat.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
