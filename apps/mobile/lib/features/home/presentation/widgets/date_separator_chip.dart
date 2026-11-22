import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

/// Centred ledger date separator chip shown between message groups.
/// Uses the Ink neutral ramp, 8px control radius, and tabular numerals.
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
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.inkBorder, width: 1),
        ),
        child: Text(
          _label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
            color: AppColors.paperSubtle,
          ),
        ),
      ),
    );
  }
}
