import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import '../widgets/ambient_voice_orb.dart';
import '../widgets/quick_capability_card.dart';
import '../widgets/recent_memory_shelf.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/widgets/voice_listening_overlay.dart';

/// The central Welcome & Ambient Action Hub Screen of Pingo.
/// Provides a calm, clutter-free personal assistant home experience.
class HubScreen extends StatefulWidget {
  final Function(String query) onStartChat;
  final VoidCallback onOpenVault;

  const HubScreen({
    super.key,
    required this.onStartChat,
    required this.onOpenVault,
  });

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final TextEditingController _promptController = TextEditingController();

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'শুভ সকাল';
    } else if (hour >= 12 && hour < 15) {
      return 'শুভ দুপুর';
    } else if (hour >= 15 && hour < 18) {
      return 'শুভ বিকেল';
    } else if (hour >= 18 && hour < 22) {
      return 'শুভ সন্ধ্যা';
    } else {
      return 'শুভ রাত্রি';
    }
  }

  void _submitPrompt() {
    final text = _promptController.text.trim();
    if (text.isNotEmpty) {
      widget.onStartChat(text);
      _promptController.clear();
    }
  }

  void _launchVoice() {
    VoiceListeningOverlay.show(
      context: context,
      onSpeechFinished: (transcript) {
        widget.onStartChat(transcript);
      },
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('EEEE, d MMMM', 'bn_BD').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppConstants.spacing16),

              // Top Bar (Greeting & Status)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: AppTypography.labelMedium(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_getTimeGreeting()}, ইশতিয়াক 👋',
                        style: AppTypography.headlineMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'মেমোরি সক্রিয়',
                          style: AppTypography.labelSmall(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacing32),

              // Central Ambient Voice Orb
              AmbientVoiceOrb(
                onTap: _launchVoice,
              ),
              const SizedBox(height: AppConstants.spacing24),

              // Interactive Quick Prompt Input
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.brandPrimary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        onSubmitted: (_) => _submitPrompt(),
                        textInputAction: TextInputAction.send,
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'মুখে বলুন বা টাইপ করুন...',
                          hintStyle: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.brandPrimary),
                      onPressed: _submitPrompt,
                      tooltip: 'পাঠান',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacing32),

              // 3 Quick Capability Cards
              QuickCapabilityCard(
                icon: Icons.alarm_rounded,
                iconColor: AppColors.brandPrimary,
                title: 'রিমাইন্ডার মনে রাখুন',
                examplePrompt: 'যেমন: কাল বিকাল ৫টায় মায়ের সাথে ডাক্তার',
                onTap: () => widget.onStartChat('কাল বিকাল ৫টায় মায়ের সাথে ডাক্তার'),
              ),
              const SizedBox(height: AppConstants.spacing12),

              QuickCapabilityCard(
                icon: Icons.description_rounded,
                iconColor: AppColors.info,
                title: 'নতুন ডকুমেন্ট বা নোট তৈরি',
                examplePrompt: 'যেমন: আজকের ক্লায়েন্ট মিটিং সামারি নোট',
                onTap: () => widget.onStartChat('আজকের ক্লায়েন্ট মিটিংয়ের একটা সামারি নোট বানিয়ে দাও'),
              ),
              const SizedBox(height: AppConstants.spacing12),

              QuickCapabilityCard(
                icon: Icons.search_rounded,
                iconColor: AppColors.categoryMedicine,
                title: 'স্মার্ট মেমোরি অনুসন্ধান',
                examplePrompt: 'যেমন: আমার পাসপোর্ট বা লাইসেন্সের মেয়াদ কবে?',
                onTap: () => widget.onStartChat('আমার পাসপোর্ট এক্সপায়ারি কবে?'),
              ),
              const SizedBox(height: AppConstants.spacing32),

              // Recent Memory & Document Shelf
              RecentMemoryShelf(
                onViewAll: widget.onOpenVault,
              ),
              const SizedBox(height: AppConstants.spacing32),
            ],
          ),
        ),
      ),
    );
  }
}

