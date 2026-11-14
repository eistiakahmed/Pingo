import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// The interactive Smart Confirmation Card displayed as a modal bottom sheet.
/// Fulfills requirement M-05 & Product Principle: "Confirm before committing".
class ConfirmationCard extends StatefulWidget {
  final String initialTitle;
  final DateTime initialDateTime;
  final ReminderCategory initialCategory;
  final ReminderPriority initialPriority;
  final String? initialRepeatRule;
  final Function(ReminderItem confirmedItem) onConfirm;
  final VoidCallback? onEditDetails;

  const ConfirmationCard({
    super.key,
    required this.initialTitle,
    required this.initialDateTime,
    this.initialCategory = ReminderCategory.other,
    this.initialPriority = ReminderPriority.normal,
    this.initialRepeatRule,
    required this.onConfirm,
    this.onEditDetails,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required DateTime dateTime,
    ReminderCategory category = ReminderCategory.other,
    ReminderPriority priority = ReminderPriority.normal,
    String? repeatRule,
    required Function(ReminderItem confirmedItem) onConfirm,
    VoidCallback? onEditDetails,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConfirmationCard(
        initialTitle: title,
        initialDateTime: dateTime,
        initialCategory: category,
        initialPriority: priority,
        initialRepeatRule: repeatRule,
        onConfirm: onConfirm,
        onEditDetails: onEditDetails,
      ),
    );
  }

  @override
  State<ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends State<ConfirmationCard> {
  late TextEditingController _titleController;
  late DateTime _selectedDateTime;
  late ReminderCategory _selectedCategory;
  late ReminderPriority _selectedPriority;
  late String? _repeatRule;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _selectedDateTime = widget.initialDateTime;
    _selectedCategory = widget.initialCategory;
    _selectedPriority = widget.initialPriority;
    _repeatRule = widget.initialRepeatRule;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return DateFormat('EEEE, d MMMM', 'bn_BD').format(dt);
  }

  String _formatTime(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }

  Color _getCategoryColor(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.medicine:
        return AppColors.categoryMedicine;
      case ReminderCategory.bill:
        return AppColors.categoryBill;
      case ReminderCategory.work:
        return AppColors.categoryWork;
      case ReminderCategory.personal:
        return AppColors.categoryPersonal;
      case ReminderCategory.birthday:
        return AppColors.categoryBirthday;
      case ReminderCategory.other:
        return AppColors.brandSecondary;
    }
  }

  String _getCategoryLabel(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.medicine:
        return 'ওষুধ';
      case ReminderCategory.bill:
        return 'বিল';
      case ReminderCategory.work:
        return 'অফিস';
      case ReminderCategory.personal:
        return 'ব্যক্তিগত';
      case ReminderCategory.birthday:
        return 'জন্মদিন';
      case ReminderCategory.other:
        return 'সাধারণ';
    }
  }

  void _handleConfirm() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final item = ReminderItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      dueAt: _selectedDateTime,
      category: _selectedCategory,
      priority: _selectedPriority,
      repeatRule: _repeatRule,
    );

    widget.onConfirm(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(_selectedCategory);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppConstants.spacing20,
        right: AppConstants.spacing20,
        top: AppConstants.spacing16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppConstants.spacing20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing16),

          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacing8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI স্মার্ট রিমাইন্ডার নিশ্চিতকরণ',
                    style: AppTypography.titleMedium(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    'যাচাই করে এক ট্যাপে সংরক্ষণ করুন',
                    style: AppTypography.bodySmall(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing20),

          // Title Input Field
          Text(
            'শিরোনাম (Title)',
            style: AppTypography.labelSmall(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.spacing6),
          TextField(
            controller: _titleController,
            style: AppTypography.titleLarge(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'কাজের নাম লিখুন...',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacing16,
                vertical: AppConstants.spacing12,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing16),

          // Chips Grid (Date, Time, Repeat, Category)
          Wrap(
            spacing: AppConstants.spacing8,
            runSpacing: AppConstants.spacing8,
            children: [
              // Date Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: AppColors.brandPrimary),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(_selectedDateTime),
                      style: AppTypography.labelMedium(),
                    ),
                  ],
                ),
              ),

              // Time Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.brandPrimary),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_selectedDateTime),
                      style: AppTypography.labelMedium(),
                    ),
                  ],
                ),
              ),

              // Category Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_outline_rounded,
                        size: 14, color: categoryColor),
                    const SizedBox(width: 6),
                    Text(
                      _getCategoryLabel(_selectedCategory),
                      style: AppTypography.labelMedium(color: categoryColor),
                    ),
                  ],
                ),
              ),

              // Repeat rule chip (if present)
              if (_repeatRule != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat_rounded,
                          size: 14, color: AppColors.info),
                      const SizedBox(width: 6),
                      Text(
                        _repeatRule!,
                        style: AppTypography.labelMedium(color: AppColors.info),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing24),

          // Action Buttons (Edit vs Confirm)
          Row(
            children: [
              // Edit Details Button
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onEditDetails?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                  ),
                  child: Text(
                    'বিস্তারিত এডিট',
                    style: AppTypography.labelMedium(),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacing12),

              // Confirm & Save Button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'নিশ্চিত ও সংরক্ষণ',
                        style: AppTypography.labelLarge(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

