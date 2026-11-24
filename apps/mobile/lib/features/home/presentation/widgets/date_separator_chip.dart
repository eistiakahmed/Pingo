import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

/// Centred adaptive date separator chip shown between message groups.
class DateSeparatorChip extends StatelessWidget {
  final DateTime date;
  final bool isBangla;

  const DateSeparatorChip({
    super.key,
    required this.date,
    this.isBangla = false,
  });

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(thatDay).inDays;

    if (diff == 0) return isBangla ? 'আজ' : 'Today';
    if (diff == 1) return isBangla ? 'গতকাল' : 'Yesterday';
    return DateFormat('d MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Text(
          _label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: p.textMuted,
          ),
        ),
      ),
    );
  }
}
