import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// Full manual reminder creation and editing sheet.
/// Fulfills requirements R-01, R-02, R-05, R-06 (Full manual control).
class EditReminderScreen extends StatefulWidget {
  final ReminderItem? initialItem;
  final Function(ReminderItem savedItem) onSave;
  final VoidCallback? onDelete;

  const EditReminderScreen({
    super.key,
    this.initialItem,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    ReminderItem? initialItem,
    required Function(ReminderItem savedItem) onSave,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditReminderScreen(
        initialItem: initialItem,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late ReminderCategory _selectedCategory;
  late ReminderPriority _selectedPriority;
  String? _selectedRepeat;

  final List<String?> _repeatOptions = [
    null,
    'প্রতিদিন (Daily)',
    'প্রতি সপ্তাহে (Weekly)',
    'প্রতি মাসে (Monthly)',
    'প্রতি বছর (Yearly)',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');

    final initialDateTime = item?.dueAt ?? DateTime.now().add(const Duration(hours: 1));
    _selectedDate = DateTime(initialDateTime.year, initialDateTime.month, initialDateTime.day);
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);

    _selectedCategory = item?.category ?? ReminderCategory.other;
    _selectedPriority = item?.priority ?? ReminderPriority.normal;
    _selectedRepeat = item?.repeatRule;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final dueAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final item = ReminderItem(
      id: widget.initialItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      dueAt: dueAt,
      category: _selectedCategory,
      priority: _selectedPriority,
      repeatRule: _selectedRepeat,
      isDone: widget.initialItem?.isDone ?? false,
    );

    widget.onSave(item);
    Navigator.of(context).pop();
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
        return 'অন্যান্য';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.initialItem != null;

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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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

              // Header Title and Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'রিমাইন্ডার এডিট করুন' : 'নতুন রিমাইন্ডার',
                    style: AppTypography.headlineSmall(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'বাতিল',
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacing16),

              // Title Field
              Text(
                'কাজের শিরোনাম *',
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacing6),
              TextFormField(
                controller: _titleController,
                validator: (val) => val == null || val.trim().isEmpty ? 'শিরোনাম আবশ্যক' : null,
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'যেমন: কাল সকালে ডাক্তারের অ্যাপয়েন্টমেন্ট',
                ),
              ),
              const SizedBox(height: AppConstants.spacing16),

              // Date & Time Picker Row
              Row(
                children: [
                  // Date selector tile
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBg : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.brandPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('d MMM yyyy').format(_selectedDate),
                                style: AppTypography.bodyMedium(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacing12),

                  // Time selector tile
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBg : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 18, color: AppColors.brandPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedTime.format(context),
                                style: AppTypography.bodyMedium(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacing16),

              // Category Selector Chips
              Text(
                'ক্যাটাগরি',
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacing8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ReminderCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    final color = _getCategoryColor(cat);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(_getCategoryLabel(cat)),
                        labelStyle: AppTypography.labelSmall(
                          color: isSelected ? Colors.white : color,
                        ),
                        selectedColor: color,
                        backgroundColor: color.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: isSelected ? color : color.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppConstants.spacing16),

              // Recurrence Dropdown
              Text(
                'পুনরাবৃত্তি (Repeat Rule)',
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacing6),
              DropdownButtonFormField<String?>(
                initialValue: _selectedRepeat,
                items: _repeatOptions.map((opt) {
                  return DropdownMenuItem<String?>(
                    value: opt,
                    child: Text(
                      opt ?? 'কোনোটিই নয় (একবার)',
                      style: AppTypography.bodyMedium(),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedRepeat = val),
              ),
              const SizedBox(height: AppConstants.spacing16),

              // Priority Switch
              SwitchListTile(
                value: _selectedPriority == ReminderPriority.important,
                onChanged: (val) {
                  setState(() {
                    _selectedPriority = val ? ReminderPriority.important : ReminderPriority.normal;
                  });
                },
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'জরুরি রিমাইন্ডার (Important Alert)',
                  style: AppTypography.titleMedium(),
                ),
                subtitle: Text(
                  'উচ্চ শব্দ ও অগ্রাধিকারসহ অ্যালার্ট দেওয়া হবে',
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                secondary: Icon(
                  Icons.flag_rounded,
                  color: _selectedPriority == ReminderPriority.important
                      ? AppColors.warning
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
              const SizedBox(height: AppConstants.spacing16),

              // Optional Notes Textarea
              Text(
                'অতিরিক্ত বিবরণ (Notes)',
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacing6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: AppTypography.bodyMedium(),
                decoration: const InputDecoration(
                  hintText: 'যেমন: প্রেসক্রিপশন সাথে নেওয়া',
                ),
              ),
              const SizedBox(height: AppConstants.spacing24),

              // Action Buttons Row (Delete if edit + Save)
              Row(
                children: [
                  if (isEditing && widget.onDelete != null) ...[
                    IconButton(
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.overdue),
                      tooltip: 'মুছে ফেলুন',
                    ),
                    const SizedBox(width: AppConstants.spacing8),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'আপডেট করুন' : 'রিমাইন্ডার সংরক্ষণ করুন',
                        style: AppTypography.labelLarge(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

