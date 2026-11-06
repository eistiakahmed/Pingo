import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/presentation/state/home_reminder_provider.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/greeting_header.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/overdue_banner.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/reminder_card.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/bottom_action_bar.dart';
import 'package:pingo_mobile/features/confirmation/presentation/widgets/confirmation_card.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/widgets/voice_listening_overlay.dart';
import 'package:pingo_mobile/features/reminder_editor/presentation/screens/edit_reminder_screen.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// The central Home Screen of Pingo.
class HomeScreen extends ConsumerWidget {
  final VoidCallback? onOpenVoice;
  final Function(String query)? onQuickTextSubmit;

  const HomeScreen({
    super.key,
    this.onOpenVoice,
    this.onQuickTextSubmit,
  });

  ReminderCategory _inferCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ওষুধ') || lower.contains('medicine') || lower.contains('doctor') || lower.contains('ডাক্তার')) {
      return ReminderCategory.medicine;
    } else if (lower.contains('বিল') || lower.contains('bill') || lower.contains('টাকা')) {
      return ReminderCategory.bill;
    } else if (lower.contains('অফিস') || lower.contains('work') || lower.contains('meeting') || lower.contains('মিটিং')) {
      return ReminderCategory.work;
    } else if (lower.contains('জন্মদিন') || lower.contains('birthday')) {
      return ReminderCategory.birthday;
    }
    return ReminderCategory.personal;
  }

  void _triggerConfirmationCard(BuildContext context, WidgetRef ref, String title) {
    final category = _inferCategory(title);
    final dueAt = DateTime.now().add(const Duration(hours: 3));

    ConfirmationCard.show(
      context: context,
      title: title,
      dateTime: dueAt,
      category: category,
      priority: category == ReminderCategory.medicine
          ? ReminderPriority.important
          : ReminderPriority.normal,
      repeatRule: title.contains('প্রতিদিন') || title.contains('every day') ? 'প্রতিদিন' : null,
      onConfirm: (confirmedItem) {
        ref.read(homeReminderProvider.notifier).addReminder(confirmedItem);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('রিমাইন্ডার সংরক্ষিত: ${confirmedItem.title}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      onEditDetails: () {
        EditReminderScreen.show(
          context: context,
          initialItem: ReminderItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            dueAt: dueAt,
            category: category,
            priority: category == ReminderCategory.medicine
                ? ReminderPriority.important
                : ReminderPriority.normal,
            repeatRule: title.contains('প্রতিদিন') || title.contains('every day') ? 'প্রতিদিন' : null,
          ),
          onSave: (savedItem) {
            ref.read(homeReminderProvider.notifier).addReminder(savedItem);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('রিমাইন্ডার সংরক্ষিত: ${savedItem.title}'),
                backgroundColor: AppColors.success,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeReminderProvider);
    final notifier = ref.read(homeReminderProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayReminders = state.todayReminders;
    final overdueReminders = state.overdueReminders;
    final completedReminders = state.completedReminders;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            GreetingHeader(
              onSettingsTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('সেটিংস স্ক্রিন পরবর্তী ধাপে সংযুক্ত করা হবে'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            // Reminders Scrollable Agenda
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Overdue Alerts
                  SliverToBoxAdapter(
                    child: OverdueBanner(
                      overdueItems: overdueReminders,
                      onQuickResolve: (id) => notifier.toggleDone(id),
                    ),
                  ),

                  // Today's Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacing20,
                        vertical: AppConstants.spacing8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'আজকের রিমাইন্ডার (${todayReminders.length})',
                            style: AppTypography.titleMedium(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (todayReminders.isNotEmpty)
                            Text(
                              'সময় অনুযায়ী সাজানো',
                              style: AppTypography.labelSmall(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Today's Items
                  if (todayReminders.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.spacing32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.task_alt_rounded,
                                size: 54,
                                color: AppColors.success.withOpacity(0.5),
                              ),
                              const SizedBox(height: AppConstants.spacing12),
                              Text(
                                'আজকের সব কাজ সম্পন্ন হয়েছে!',
                                style: AppTypography.titleMedium(),
                              ),
                              const SizedBox(height: AppConstants.spacing4),
                              Text(
                                'নিচের মাইক্রোফোনে বলে নতুন রিমাইন্ডার যুক্ত করুন।',
                                style: AppTypography.bodySmall(
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = todayReminders[index];
                          return ReminderCard(
                            key: ValueKey(item.id),
                            reminder: item,
                            onToggleDone: () => notifier.toggleDone(item.id),
                            onTap: () {
                              EditReminderScreen.show(
                                context: context,
                                initialItem: item,
                                onSave: (saved) => notifier.updateReminder(saved),
                                onDelete: () => notifier.deleteReminder(item.id),
                              );
                            },
                            onSnooze: (duration) =>
                                notifier.snooze(item.id, duration),
                          );
                        },
                        childCount: todayReminders.length,
                      ),
                    ),

                  // Completed section (if any)
                  if (completedReminders.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: AppConstants.spacing20,
                          right: AppConstants.spacing20,
                          top: AppConstants.spacing24,
                          bottom: AppConstants.spacing8,
                        ),
                        child: Text(
                          'সম্পন্ন হয়েছে (${completedReminders.length})',
                          style: AppTypography.labelMedium(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = completedReminders[index];
                          return ReminderCard(
                            key: ValueKey(item.id),
                            reminder: item,
                            onToggleDone: () => notifier.toggleDone(item.id),
                            onTap: () {
                              EditReminderScreen.show(
                                context: context,
                                initialItem: item,
                                onSave: (saved) => notifier.updateReminder(saved),
                                onDelete: () => notifier.deleteReminder(item.id),
                              );
                            },
                          );
                        },
                        childCount: completedReminders.length,
                      ),
                    ),
                  ],

                  // Bottom padding for scroll
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppConstants.spacing32),
                  ),
                ],
              ),
            ),

            // Bottom Quick Action Dock
            BottomActionBar(
              onTextSubmitted: (text) {
                _triggerConfirmationCard(context, ref, text);
                onQuickTextSubmit?.call(text);
              },
              onMicTap: onOpenVoice ??
                  () {
                    VoiceListeningOverlay.show(
                      context: context,
                      onSpeechFinished: (recognizedText) {
                        _triggerConfirmationCard(context, ref, recognizedText);
                      },
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }
}

