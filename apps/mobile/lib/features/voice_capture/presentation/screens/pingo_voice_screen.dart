import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';

/// Fullscreen Voice Capture screen with zero demo data.
class PingoVoiceScreen extends StatefulWidget {
  final Function(String speechText)? onSpeechFinished;

  const PingoVoiceScreen({super.key, this.onSpeechFinished});

  static Future<void> show(BuildContext context, {Function(String)? onSpeechFinished}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => PingoVoiceScreen(onSpeechFinished: onSpeechFinished),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  State<PingoVoiceScreen> createState() => _PingoVoiceScreenState();
}

class _PingoVoiceScreenState extends State<PingoVoiceScreen>
    with SingleTickerProviderStateMixin {
  String _currentLanguage = 'English + বাংলা';
  String _liveSpeechText = ''; // Clean: Starts empty, dynamically populated
  late AnimationController _animController;
  final TextEditingController _typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  void _finishVoice([String? customText]) {
    final text = customText ?? (_liveSpeechText.trim().isNotEmpty ? _liveSpeechText.trim() : 'New reminder');
    Navigator.of(context).pop();
    if (widget.onSpeechFinished != null) {
      widget.onSpeechFinished!(text);
    }
  }

  void _openTypeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type your reminder', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: _typeController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Call dentist tomorrow at 10 AM',
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop();
            _finishVoice(val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pingoPurple),
            onPressed: () {
              Navigator.of(ctx).pop();
              _finishVoice(_typeController.text);
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleLanguage() {
    setState(() {
      if (_currentLanguage == 'English + বাংলা') {
        _currentLanguage = 'বাংলা';
      } else if (_currentLanguage == 'বাংলা') {
        _currentLanguage = 'English';
      } else {
        _currentLanguage = 'English + বাংলা';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // Top Bar: (X) on left, Language Pill on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _toggleLanguage,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      child: Text(
                        _currentLanguage,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.pingoDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Status & Realtime Transcribed Text
              const Text(
                'Listening...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pingoPurple,
                ),
              ),
              const SizedBox(height: 14),

              // Clean text state: Displays live speech or calm prompt
              Text(
                _liveSpeechText.isNotEmpty
                    ? _liveSpeechText
                    : 'What should I remember for you?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: _liveSpeechText.isNotEmpty
                      ? textColor
                      : (isDark ? Colors.white60 : const Color(0xFF9CA3AF)),
                  letterSpacing: -0.4,
                ),
              ),

              const Spacer(flex: 3),

              // Central Ripple Orb with Audio Waves
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final scale = 1.0 + (_animController.value * 0.08);
                  final outerRadius = 135.0 * scale;
                  final midRadius = 105.0 * scale;

                  return SizedBox(
                    width: 270,
                    height: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer subtle ring
                        Container(
                          width: outerRadius * 2,
                          height: outerRadius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.pingoPurple.withValues(alpha: 0.06),
                          ),
                        ),
                        // Mid ring
                        Container(
                          width: midRadius * 2,
                          height: midRadius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.pingoPurple.withValues(alpha: 0.12),
                          ),
                        ),
                        // Core solid button with soundwaves
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.pingoPurple,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.pingoPurple.withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.white,
                              size: 58,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // Caption
              Text(
                'Speak naturally. I will save it when you stop.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.pingoMuted,
                ),
              ),

              const Spacer(flex: 2),

              // Bottom Action Controls: Cancel | Stop | Type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),

                  // Stop & Save (Red circle with white square)
                  GestureDetector(
                    onTap: () => _finishVoice(),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEF4444),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Type Button
                  InkWell(
                    onTap: _openTypeDialog,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      child: Text(
                        'Type',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
