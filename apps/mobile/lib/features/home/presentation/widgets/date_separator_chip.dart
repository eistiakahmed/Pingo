import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small centred date chip shown between message groups, WhatsApp-style:
/// "Today", "Yesterday", or a plain date for older days.
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF182230),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF22304A), width: 1),
        ),
        child: Text(
          _label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
