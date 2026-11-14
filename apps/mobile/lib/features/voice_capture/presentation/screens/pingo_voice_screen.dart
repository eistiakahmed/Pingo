import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/services/voice_recognition_service.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';

/// Fullscreen Voice Capture screen with live hardware Speech-to-Text audio capture.
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
  String _liveSpeechText = '';
  String _accumulatedPrefix = '';
  bool _isListening = false;
  double _soundLevel = 0.0;
  late AnimationController _animController;
  final TextEditingController _typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceRecognition();
    });
  }

  @override
  void dispose() {
    VoiceRecognitionService.instance.cancelListening();
    _animController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  String? _getLocaleId() {
    if (_currentLanguage == 'বাংলা') {
      return VoiceRecognitionService.instance.findBestLocale('bn') ?? 'bn_BD';
    }
    return VoiceRecognitionService.instance.findBestLocale('en') ?? 'en_US';
  }

  void _setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    await VoiceRecognitionService.instance.stopListening();
    setState(() {
      _currentLanguage = lang;
      _liveSpeechText = '';
      _accumulatedPrefix = '';
    });
    _startVoiceRecognition();
  }

  Future<void> _startVoiceRecognition() async {
    setState(() {
      _isListening = true;
      if (_liveSpeechText.isNotEmpty && !_liveSpeechText.endsWith(' ')) {
        _accumulatedPrefix = '$_liveSpeechText ';
      }
    });

    await VoiceRecognitionService.instance.startListening(
      localeId: _getLocaleId(),
      onResult: (words) {
        if (mounted) {
          setState(() {
            _liveSpeechText = '$_accumulatedPrefix$words'.trim();
          });
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level;
          });
        }
      },
      onStatusChange: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  Future<void> _pauseListening() async {
    await VoiceRecognitionService.instance.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        if (_liveSpeechText.isNotEmpty && !_liveSpeechText.endsWith(' ')) {
          _accumulatedPrefix = '$_liveSpeechText ';
        }
      });
    }
  }

  void _finishVoice([String? customText]) async {
    await VoiceRecognitionService.instance.stopListening();
    final text = customText ?? (_liveSpeechText.trim().isNotEmpty ? _liveSpeechText.trim() : 'New reminder');
    if (mounted) {
      Navigator.of(context).pop();
    }
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

  Widget _langPill(String label, String langCode, bool isDark) {
    final isSelected = _currentLanguage == langCode;
    return GestureDetector(
      onTap: () => _setLanguage(langCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected ? AppColors.pingoPurple : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
          ),
        ),
      ),
    );
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
                  // Segmented Bilingual Pill (বাংলা | English)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                      color: isDark ? AppColors.darkSurface : Colors.white,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _langPill('বাংলা', 'বাংলা', isDark),
                        _langPill('English', 'English', isDark),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Status & Realtime Transcribed Text
              Text(
                _isListening
                    ? (_currentLanguage == 'বাংলা' ? 'শুনছি...' : 'Listening...')
                    : (_currentLanguage == 'বাংলা' ? 'বলার জন্য ট্যাপ করুন' : 'Tap to speak'),
                style: const TextStyle(
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
                    : (_currentLanguage == 'বাংলা'
                        ? 'আপনার রিমাইন্ডারটি বাংলায় বলুন...'
                        : 'What should I remember for you?'),
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
                  final dynamicSoundScale = (_soundLevel.clamp(0.0, 10.0) / 10.0) * 0.15;
                  final scale = 1.0 + (_animController.value * 0.08) + dynamicSoundScale;
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
                        // Core solid button with soundwaves / Tap to Pause or Resume
                        GestureDetector(
                          onTap: () {
                            if (_isListening) {
                              _pauseListening();
                            } else {
                              _startVoiceRecognition();
                            }
                          },
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening ? AppColors.pingoPurple : const Color(0xFF6B7280),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? AppColors.pingoPurple : const Color(0xFF6B7280)).withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                                color: Colors.white,
                                size: 58,
                              ),
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
                _currentLanguage == 'বাংলা'
                    ? 'স্বাভাবিকভাবে বলুন, কথা থামালে সেভ হয়ে যাবে।'
                    : 'Speak naturally. I will save it when you stop.',
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
                        _currentLanguage == 'বাংলা' ? 'বাতিল' : 'Cancel',
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
                        _currentLanguage == 'বাংলা' ? 'লিখুন' : 'Type',
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
