import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Quiet opacity-pulsing 3-dot status indicator displayed during parsing.
/// No emoji, no colored sine-wave bounce, no drop shadows.
class TypingIndicatorWidget extends StatefulWidget {
  final String? statusText;

  const TypingIndicatorWidget({super.key, this.statusText});

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inkBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
              ),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.signalAmber,
                ),
              ),
            ),
            if (widget.statusText != null && widget.statusText!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                widget.statusText!,
                style: const TextStyle(
                  color: AppColors.paperMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
