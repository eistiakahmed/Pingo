import 'package:flutter/material.dart';

/// Clean, pattern-free adaptive canvas background.
/// Strictly follows the active system Light or Dark Penguin palette background
/// without decorative overlays or distracting motifs.
class TechCanvasBackground extends StatelessWidget {
  final Widget child;

  const TechCanvasBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox.expand(child: child),
    );
  }
}
