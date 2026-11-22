import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// Manual reminder creation and editing sheet — Unslop Ink & Ledger System.
/// Fixes inverted white-on-white button contrast, uses 4px grid spacing,
/// 18px line icons, tabular numerals, and sentence-case labels.
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
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');

    final initialDateTime =
        item?.dueAt ?? DateTime.now().add(const Duration(hours: 1));
    _selectedDate = DateTime(
        initialDateTime.year, initialDateTime.month, initialDateTime.day);
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);

    _selectedCategory = item?.category ?? ReminderCategory.other;
    _selectedPriority = item?.priority ?? ReminderPriority.normal;
    _selectedRepeat = _repeatOptions.contains(item?.repeatRule)
        ? item?.repeatRule
        : null;
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
      id: widget.initialItem?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      dueAt: dueAt,
      category: _selectedCategory,
      priority: _selectedPriority,
      repeatRule: _selectedRepeat,
      isDone: widget.initialItem?.isDone ?? false,
    );

    widget.onSave(item);
    Navigator.of(context).pop();
  }

  Color _getCategoryDotColor(ReminderCategory category) {
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
        return AppColors.paperSubtle;
    }
  }

  String _getCategoryLabel(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.medicine:
        return 'Medicine';
      case ReminderCategory.bill:
        return 'Bill';
      case ReminderCategory.work:
        return 'Work';
      case ReminderCategory.personal:
        return 'Personal';
      case ReminderCategory.birthday:
        return 'Birthday';
      case ReminderCategory.other:
        return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.inkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.inkBorder, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkBorderActive,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit alarm' : 'New alarm',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.paperWhite,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.paperMuted,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paperMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Title required' : null,
                style: AppTypography.bodyMedium(color: AppColors.paperWhite),
                decoration: const InputDecoration(
                  hintText: 'Doctor appointment',
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.inkSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.inkBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.paperMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('d MMM yyyy').format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  color: AppColors.paperWhite,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.inkSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.inkBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: AppColors.paperMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedTime.format(context),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  color: AppColors.paperWhite,
                                ),
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
              const SizedBox(height: 16),

              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paperMuted,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ReminderCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    final dotColor = _getCategoryDotColor(cat);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.inkSurface
                                : AppColors.inkBlack,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.inkBorderActive
                                  : AppColors.inkBorder,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                _getCategoryLabel(cat),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.paperWhite
                                      : AppColors.paperMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Repeat',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paperMuted,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _selectedRepeat,
                dropdownColor: AppColors.inkSurface,
                items: _repeatOptions.map((opt) {
                  return DropdownMenuItem<String?>(
                    value: opt,
                    child: Text(
                      opt ?? 'Once',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.paperWhite,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedRepeat = val),
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                value: _selectedPriority == ReminderPriority.important,
                activeThumbColor: AppColors.signalAmber,
                onChanged: (val) {
                  setState(() {
                    _selectedPriority = val
                        ? ReminderPriority.important
                        : ReminderPriority.normal;
                  });
                },
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Priority alarm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.paperWhite,
                  ),
                ),
                subtitle: const Text(
                  'Use high-priority sound and wake screen',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.paperSubtle,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paperMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: AppTypography.bodyMedium(color: AppColors.paperWhite),
                decoration: const InputDecoration(
                  hintText: 'Bring prescription',
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  if (isEditing && widget.onDelete != null) ...[
                    InkWell(
                      onTap: () {
                        widget.onDelete!();
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.inkSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.inkBorder,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.overdue,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.paperWhite,
                          foregroundColor: AppColors.inkBlack,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Update alarm' : 'Save alarm',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkBlack,
                          ),
                        ),
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
