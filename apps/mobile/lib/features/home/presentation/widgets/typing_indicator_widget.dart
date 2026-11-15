import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dynamic 3-dot jumping wave typing indicator displayed during AI parsing.
class TypingIndicatorWidget extends StatefulWidget {
  final String? statusText;

  const TypingIndicatorWidget({super.key, this.statusText});

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2A),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFF1D263B), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini Penguin Indicator Icon
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1E293B),
              ),
              child: const Center(
                child: Text('🐧', style: TextStyle(fontSize: 10)),
              ),
            ),
            const SizedBox(width: 10),

            // 3 Staggered Bouncing Wave Dots
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.22;
                    final progress = (_controller.value - delay) % 1.0;
                    final bounce = math.sin(progress * math.pi * 2).clamp(0.0, 1.0);
                    final offsetY = -bounce * 4.5;

                    return Transform.translate(
                      offset: Offset(0, offsetY),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            const Color(0xFF64748B),
                            const Color(0xFF38BDF8),
                            bounce,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            if (widget.statusText != null && widget.statusText!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                widget.statusText!,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
