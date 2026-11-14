import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/session_chat/presentation/screens/pingo_flow_screen.dart';
import 'package:pingo_mobile/features/vault/presentation/screens/pingo_vault_screen.dart';
import 'package:pingo_mobile/features/vault/presentation/screens/pingo_add_document_screen.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/screens/pingo_voice_screen.dart';
import 'package:pingo_mobile/features/profile/presentation/screens/pingo_profile_screen.dart';

/// The flagship Home Screen implementing '1. Home.png' with 100% fidelity.
class PingoHomeScreen extends StatefulWidget {
  const PingoHomeScreen({super.key});

  @override
  State<PingoHomeScreen> createState() => _PingoHomeScreenState();
}

class _PingoHomeScreenState extends State<PingoHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _submitText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputController.clear();

    final lower = trimmed.toLowerCase();
    final hasTimeOrDate = RegExp(
      r'(\b\d{1,2}(:\d{2})?\s*(am|pm|a\.m\.|p\.m\.)\b|\b(tomorrow|today|tonight|alarm|reminder|meeting|doctor|medicine|bill)\b|[০-৯\d]+(\s*:\s*[০-৯\d]+)?\s*টা|কাল|আগামীকাল|পরশু|আজ|সকাল|বিকাল|সন্ধ্যা|রাত|ঔষধ|বিল|মিটিং|নামাজ)',
      caseSensitive: false,
    ).hasMatch(trimmed);

    if (lower.contains('what do i have') || lower.contains('ask about today') || trimmed == 'What do I have today?') {
      PingoFlowScreen.open(context, scenario: FlowScenario.askAboutToday, prompt: trimmed);
    } else if (hasTimeOrDate) {
      PingoFlowScreen.open(context, scenario: FlowScenario.autoSaved, prompt: trimmed);
    } else {
      PingoFlowScreen.open(context, scenario: FlowScenario.askQuestion, prompt: trimmed);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning.';
    if (hour < 17) return 'Good afternoon.';
    return 'Good evening.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pingoSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.pingoBorder;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;
    final mutedColor = isDark ? AppColors.darkTextSecondary : AppColors.pingoMuted;

    final formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Pingo Bell Logo on Left, Vault Button on Right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo + Bell Button (Opens Profile)
                  InkWell(
                    onTap: () => PingoProfileScreen.open(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.pingoPurple,
                            size: 26,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Pingo',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: AppColors.pingoPurple,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Vault Circular Button
                  InkWell(
                    onTap: () => PingoVaultScreen.open(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.folder_outlined,
                          size: 22,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Date Caption
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 8),

              // Large Bold Headline
              Text(
                '${_getGreeting()}\nWhat should I\nremember?',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: textColor,
                  letterSpacing: -0.6,
                ),
              ),

              const Spacer(flex: 3),

              // Hero Pulsing Voice Mic Button
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulseController.value * 0.08);
                        final outerR = 115.0 * scale;
                        final midR = 92.0 * scale;

                        return SizedBox(
                          width: 230,
                          height: 230,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer Ring
                              Container(
                                width: outerR * 2,
                                height: outerR * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.pingoPurple.withValues(alpha: 0.05),
                                ),
                              ),
                              // Mid Ring
                              Container(
                                width: midR * 2,
                                height: midR * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.pingoPurple.withValues(alpha: 0.10),
                                ),
                              ),
                              // Solid Mic Button
                              GestureDetector(
                                onTap: () {
                                  PingoVoiceScreen.show(context, onSpeechFinished: (speech) {
                                    _submitText(speech);
                                  });
                                },
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.pingoPurple,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.pingoPurple.withValues(alpha: 0.38),
                                        blurRadius: 28,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.mic,
                                      color: Colors.white,
                                      size: 54,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Tap and say it',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Quick Suggestion Chips
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _chip('What do I have today?', () {
                          PingoFlowScreen.open(
                            context,
                            scenario: FlowScenario.askAboutToday,
                            prompt: 'What do I have today?',
                          );
                        }),
                        const SizedBox(width: 8),
                        _chip('Pay bill on the 10th', () {
                          PingoFlowScreen.open(
                            context,
                            scenario: FlowScenario.autoSaved,
                            prompt: 'Pay bill on the 10th',
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _chip('Medicine every day 9 pm', () {
                      PingoFlowScreen.open(
                        context,
                        scenario: FlowScenario.autoSaved,
                        prompt: 'Medicine every day 9 pm',
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sleek Bottom Input Dock
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Row(
                  children: [
                    // Paperclip Document Add Button
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file_rounded,
                        color: Color(0xFF6B7280),
                        size: 24,
                      ),
                      tooltip: 'Add document',
                      onPressed: () => PingoAddDocumentScreen.open(context),
                    ),

                    // Borderless Text Field
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        onSubmitted: _submitText,
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Or type, or add a document',
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        ),
                      ),
                    ),

                    // Solid Purple Up-Arrow Button
                    GestureDetector(
                      onTap: () => _submitText(_inputController.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.pingoPurple,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          color: Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

