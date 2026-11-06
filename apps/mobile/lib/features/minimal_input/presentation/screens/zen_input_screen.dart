import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import '../widgets/zen_input_bar.dart';
import '../widgets/documents_vault_sheet.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/widgets/voice_listening_overlay.dart';

/// Pure, distraction-free single-prompt interface with zero chat history.
class ZenInputScreen extends StatefulWidget {
  const ZenInputScreen({super.key});

  @override
  State<ZenInputScreen> createState() => _ZenInputScreenState();
}

class _ZenInputScreenState extends State<ZenInputScreen> {
  String? _statusFeedback;

  void _triggerFeedback(String message) {
    setState(() => _statusFeedback = message);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _statusFeedback = null);
      }
    });
  }

  void _handleTextSubmission(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('remind') || lower.contains('doctor') || lower.contains('meeting') || lower.contains('মনে')) {
      _triggerFeedback('✓ Reminder scheduled in memory');
    } else if (lower.contains('doc') || lower.contains('note') || lower.contains('summary') || lower.contains('ডকুমেন্ট')) {
      _triggerFeedback('✓ Document created & saved to vault');
    } else {
      _triggerFeedback('✓ Thought saved to memory');
    }
  }

  void _openVoice() {
    VoiceListeningOverlay.show(
      context: context,
      onSpeechFinished: (recognizedText) {
        if (recognizedText.trim().isNotEmpty) {
          _handleTextSubmission(recognizedText);
        }
      },
    );
  }

  void _openDocsVault() {
    DocumentsVaultSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pure zen canvas background
    final canvasBg = isDark ? const Color(0xFF0F141A) : const Color(0xFFF9FAFB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: canvasBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Subtle top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pingo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.folder_special_outlined,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      size: 22,
                    ),
                    tooltip: 'View Document Vault',
                    onPressed: _openDocsVault,
                  ),
                ],
              ),

              // Zen Canvas Centerpiece (Zero chat history)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subtle breathing aura icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brandPrimary.withValues(alpha: 0.85),
                              AppColors.brandSecondary.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandPrimary.withValues(alpha: 0.25),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.blur_on_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'What should I remember?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Speak or write a thought, task, or document note',
                        style: TextStyle(
                          fontSize: 14,
                          color: subColor,
                        ),
                      ),

                      // Ephemeral Feedback Pill (Shows momentarily, then disappears)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(top: 28),
                        height: _statusFeedback != null ? 36 : 0,
                        child: _statusFeedback != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A884).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00A884).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF00A884), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      _statusFeedback!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF00A884),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),

              // Single Bottom Capture Dock
              ZenInputBar(
                onSubmitText: _handleTextSubmission,
                onVoiceTap: _openVoice,
                onDocTap: _openDocsVault,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

