import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Subtle tech-themed dynamic background featuring abstract circuit traces,
/// pulsing neural AI nodes, and geometric reminder motifs.
class TechCanvasBackground extends StatefulWidget {
  final Widget child;

  const TechCanvasBackground({super.key, required this.child});

  @override
  State<TechCanvasBackground> createState() => _TechCanvasBackgroundState();
}

class _TechCanvasBackgroundState extends State<TechCanvasBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Slow 6-second ambient breathing pulse
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Deep Midnight Background
        Container(
          color: const Color(0xFF080B11),
        ),

        // 2. Subtle Animated Circuit & AI Nodes Canvas
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _TechCircuitPainter(progress: _controller.value),
              );
            },
          ),
        ),

        // 3. Foreground Content
        widget.child,
      ],
    );
  }
}

class _TechCircuitPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _TechCircuitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final circuitPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final activeCircuitPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.08)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    final pulse = math.sin(progress * math.pi * 2) * 0.5 + 0.5;

    // --- A. Abstract Circuit Traces (Top Right) ---
    final path1 = Path()
      ..moveTo(size.width * 0.7, 40)
      ..lineTo(size.width * 0.85, 40)
      ..lineTo(size.width * 0.92, 90)
      ..lineTo(size.width - 20, 90);
    canvas.drawPath(path1, circuitPaint);

    final path2 = Path()
      ..moveTo(size.width * 0.85, 40)
      ..lineTo(size.width * 0.85, 120)
      ..lineTo(size.width * 0.95, 160);
    canvas.drawPath(path2, circuitPaint);

    // --- B. Abstract Circuit Traces (Bottom Left) ---
    final path3 = Path()
      ..moveTo(20, size.height * 0.75)
      ..lineTo(60, size.height * 0.75)
      ..lineTo(100, size.height * 0.82)
      ..lineTo(100, size.height * 0.92);
    canvas.drawPath(path3, circuitPaint);

    final path4 = Path()
      ..moveTo(60, size.height * 0.75)
      ..lineTo(60, size.height * 0.65)
      ..lineTo(110, size.height * 0.60);
    canvas.drawPath(path4, activeCircuitPaint);

    // --- C. Neural AI Nodes with Pulsing Glow ---
    final nodes = [
      Offset(size.width * 0.85, 40),
      Offset(size.width * 0.92, 90),
      Offset(size.width * 0.85, 120),
      Offset(60, size.height * 0.75),
      Offset(100, size.height * 0.82),
      Offset(110, size.height * 0.60),
      Offset(size.width * 0.2, size.height * 0.35),
      Offset(size.width * 0.8, size.height * 0.55),
    ];

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final nodePulse = (math.sin((progress * math.pi * 2) + i) * 0.5 + 0.5);

      // Outer radial glow
      canvas.drawCircle(node, 10 + (nodePulse * 6), glowPaint);

      // Core node dot
      canvas.drawCircle(node, 2.5 + (nodePulse * 0.8), nodePaint);
    }

    // --- D. Geometric Reminder Motif (Faint clock dial / reminder ripple) ---
    final dialCenter = Offset(size.width * 0.5, size.height * 0.28);
    final dialRadius = 55.0;

    final dialPaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.035)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Faint circular orbit
    canvas.drawCircle(dialCenter, dialRadius, dialPaint);
    canvas.drawCircle(dialCenter, dialRadius * 0.65, dialPaint);

    // Clock dial ticks (12 hour positions)
    final tickPaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final p1 = Offset(
        dialCenter.dx + (dialRadius - 4) * math.cos(angle),
        dialCenter.dy + (dialRadius - 4) * math.sin(angle),
      );
      final p2 = Offset(
        dialCenter.dx + dialRadius * math.cos(angle),
        dialCenter.dy + dialRadius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Active pulsing time node
    final activeAngle = (progress * math.pi * 2);
    final activeOrb = Offset(
      dialCenter.dx + dialRadius * math.cos(activeAngle),
      dialCenter.dy + dialRadius * math.sin(activeAngle),
    );
    canvas.drawCircle(
      activeOrb,
      2.5,
      Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.25 + (pulse * 0.2)),
    );
  }

  @override
  bool shouldRepaint(covariant _TechCircuitPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
