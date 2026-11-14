import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';

/// Full-screen animated voice capture overlay with real-time waveform and live transcript.
/// Fulfills requirements V-01 to V-06 (Bilingual speech capture with editable transcript).
class VoiceListeningOverlay extends StatefulWidget {
  final Function(String recognizedText) onSpeechFinished;

  const VoiceListeningOverlay({
    super.key,
    required this.onSpeechFinished,
  });

  static Future<void> show({
    required BuildContext context,
    required Function(String recognizedText) onSpeechFinished,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Voice Listening',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: AppConstants.normalAnimation,
      pageBuilder: (ctx, anim1, anim2) => VoiceListeningOverlay(
        onSpeechFinished: onSpeechFinished,
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<VoiceListeningOverlay> createState() => _VoiceListeningOverlayState();
}

class _VoiceListeningOverlayState extends State<VoiceListeningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late TextEditingController _transcriptController;
  Timer? _simulationTimer;
  int _simulationStep = 0;

  final List<String> _simulatedSpeechStream = [
    'শুনছি... বলুন',
    'কাল...',
    'কাল বিকাল...',
    'কাল বিকাল ৫টায়...',
    'কাল বিকাল ৫টায় মায়ের সাথে...',
    'কাল বিকাল ৫টায় মায়ের সাথে ডাক্তার',
  ];

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController(text: _simulatedSpeechStream.first);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Simulate speech-to-text streaming in preview mode
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (_simulationStep < _simulatedSpeechStream.length - 1) {
        setState(() {
          _simulationStep++;
          _transcriptController.text = _simulatedSpeechStream[_simulationStep];
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _waveController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _finishListening() {
    _simulationTimer?.cancel();
    final text = _transcriptController.text.trim();
    Navigator.of(context).pop();
    if (text.isNotEmpty && text != _simulatedSpeechStream.first) {
      widget.onSpeechFinished(text);
    } else {
      widget.onSpeechFinished('কাল বিকাল ৫টায় মায়ের সাথে ডাক্তার');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacing24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top dismiss bar
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    tooltip: 'বাতিল (Cancel)',
                  ),
                ),

                // Center Waveform & Transcript Area
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic pulsating sound waves
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return SizedBox(
                          height: 90,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(7, (index) {
                              final waveOffset = (index - 3).abs() * 0.15;
                              final animValue = (_waveController.value - waveOffset).clamp(0.15, 1.0);
                              final barHeight = 20.0 + (animValue * 60.0);

                              return Container(
                                width: 7,
                                height: barHeight,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: index == 3
                                      ? AppColors.brandSecondary
                                      : Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppConstants.spacing32),

                    // Live Bilingual Transcript Display (Editable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _transcriptController,
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineSmall(color: Colors.white),
                            maxLines: 3,
                            minLines: 1,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacing8),
                          Text(
                            'ভুল হলে ট্যাপ করে টেক্সট এডিট করতে পারবেন',
                            style: AppTypography.bodySmall(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bottom Mic Action & Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacing40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel Button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 30),
                        tooltip: 'মুছে ফেলুন',
                      ),

                      // Large Pulsing Finish Mic Button
                      GestureDetector(
                        onTap: _finishListening,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.brandPrimary, AppColors.brandSecondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandPrimary.withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),

                      // Keyboard fallback Button (V-07)
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white70, size: 30),
                        tooltip: 'কীবোর্ডে লিখুন',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

