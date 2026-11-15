import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/services/voice_recognition_service.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';

/// Architectural Minimalist Fullscreen Voice Capture screen with hardware Speech-to-Text audio capture.
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
  String _currentLanguage = 'বাংলা';
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
      duration: const Duration(milliseconds: 1200),
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
        backgroundColor: AppColors.inkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.inkBorder, width: 1),
        ),
        title: Text(
          'MANUAL ENTRY',
          style: AppTypography.monoLabel().copyWith(
            color: AppColors.paperWhite,
            letterSpacing: 1.2,
          ),
        ),
        content: TextField(
          controller: _typeController,
          autofocus: true,
          style: const TextStyle(color: AppColors.paperWhite, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'e.g. Call dentist tomorrow at 10 AM',
            hintStyle: TextStyle(color: AppColors.paperMuted.withValues(alpha: 0.6)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkBorder),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.paperWhite),
            ),
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop();
            _finishVoice(val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CANCEL',
              style: AppTypography.monoLabel().copyWith(color: AppColors.paperMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _finishVoice(_typeController.text);
            },
            child: Text(
              'DONE',
              style: AppTypography.monoLabel().copyWith(color: AppColors.paperWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langPill(String label, String langCode) {
    final isSelected = _currentLanguage == langCode;
    return GestureDetector(
      onTap: () => _setLanguage(langCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? AppColors.paperWhite : Colors.transparent,
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.monoLabel().copyWith(
            fontSize: 11,
            color: isSelected ? AppColors.inkBlack : AppColors.paperMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top Bar: Clean minimal close [X] and segmented language pills
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inkBorder, width: 1),
                        color: AppColors.inkSurface,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.paperWhite,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.inkBorder, width: 1),
                      color: AppColors.inkSurface,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _langPill('বাংলা', 'বাংলা'),
                        _langPill('English', 'English'),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Status Indicator (Monospace Label)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? const Color(0xFF10B981) : AppColors.paperMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening
                        ? (_currentLanguage == 'বাংলা' ? 'শুনছি · RECORDING' : 'LISTENING · ACTIVE')
                        : (_currentLanguage == 'বাংলা' ? 'বিরতি · PAUSED' : 'TAP TO RESUME'),
                    style: AppTypography.monoLabel().copyWith(
                      color: _isListening ? AppColors.paperWhite : AppColors.paperMuted,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Transcribed Text Display (High typographic contrast)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _liveSpeechText.isNotEmpty
                      ? _liveSpeechText
                      : (_currentLanguage == 'বাংলা'
                          ? 'আপনার রিমাইন্ডারটি স্পষ্ট করে বলুন...'
                          : 'Speak your reminder clearly...'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: _liveSpeechText.isNotEmpty
                        ? AppColors.paperWhite
                        : AppColors.paperMuted.withValues(alpha: 0.5),
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Center Minimal Visualizer: Concentric hairline rings & central graphite capsule
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final soundScale = (_soundLevel.clamp(0.0, 10.0) / 10.0) * 0.25;
                  final pulse = _isListening ? (1.0 + (_animController.value * 0.08) + soundScale) : 1.0;

                  return SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer hairline ring
                        Container(
                          width: 220 * pulse,
                          height: 220 * pulse,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.inkBorder.withValues(alpha: _isListening ? 0.8 : 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        // Middle hairline ring
                        Container(
                          width: 170 * pulse,
                          height: 170 * pulse,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.inkBorder.withValues(alpha: _isListening ? 0.9 : 0.4),
                              width: 1,
                            ),
                          ),
                        ),
                        // Center Core: Ink Surface with hairline white border
                        GestureDetector(
                          onTap: () {
                            if (_isListening) {
                              _pauseListening();
                            } else {
                              _startVoiceRecognition();
                            }
                          },
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.inkCard,
                              border: Border.all(
                                color: _isListening ? AppColors.paperWhite : AppColors.inkBorder,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                                color: _isListening ? AppColors.paperWhite : AppColors.paperMuted,
                                size: 44,
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

              // Architectural Guidance Note
              Text(
                _currentLanguage == 'বাংলা'
                    ? 'কথা শেষ হলে স্বয়ংক্রিয়ভাবে সেভ হবে'
                    : 'AUTOMATIC COMMIT ON SILENCE',
                style: AppTypography.monoLabel().copyWith(
                  fontSize: 11,
                  color: AppColors.paperMuted,
                  letterSpacing: 1.0,
                ),
              ),

              const Spacer(flex: 2),

              // Bottom Precision Dock: [ CANCEL ] · [ STOP/SAVE ] · [ TYPE ]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inkBorder, width: 1),
                        color: AppColors.inkSurface,
                      ),
                      child: Text(
                        'DISCARD',
                        style: AppTypography.monoLabel().copyWith(
                          fontSize: 12,
                          color: AppColors.paperMuted,
                        ),
                      ),
                    ),
                  ),

                  // Stop & Save: Crisp high-contrast square in circular container
                  GestureDetector(
                    onTap: () => _finishVoice(),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.paperWhite,
                        border: Border.all(color: AppColors.paperWhite, width: 1),
                      ),
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.inkBlack,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Manual Type
                  InkWell(
                    onTap: _openTypeDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inkBorder, width: 1),
                        color: AppColors.inkSurface,
                      ),
                      child: Text(
                        'KEYBOARD',
                        style: AppTypography.monoLabel().copyWith(
                          fontSize: 12,
                          color: AppColors.paperWhite,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
