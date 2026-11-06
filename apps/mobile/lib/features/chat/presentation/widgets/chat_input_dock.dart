import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';

/// Modern conversational dock with attachment options, text input, and voice mic.
class ChatInputDock extends StatefulWidget {
  final Function(String text) onSendMessage;
  final VoidCallback onMicTap;
  final VoidCallback? onAttachTap;

  const ChatInputDock({
    super.key,
    required this.onSendMessage,
    required this.onMicTap,
    this.onAttachTap,
  });

  @override
  State<ChatInputDock> createState() => _ChatInputDockState();
}

class _ChatInputDockState extends State<ChatInputDock> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasNow = _controller.text.trim().isNotEmpty;
      if (hasNow != _hasText) {
        setState(() => _hasText = hasNow);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.spacing12,
        right: AppConstants.spacing12,
        top: AppConstants.spacing12,
        bottom: MediaQuery.of(context).padding.bottom + AppConstants.spacing12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment Button (+) for Documents
          IconButton(
            onPressed: widget.onAttachTap,
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              size: 26,
            ),
            tooltip: 'ডকুমেন্ট বা ফাইল যুক্ত করুন',
          ),

          // Text Field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'পিংগোকে কিছু বলুন বা মনে রাখতে বলুন...',
                  hintStyle: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacing8),

          // Mic or Send Button
          AnimatedSwitcher(
            duration: AppConstants.fastAnimation,
            child: _hasText
                ? InkWell(
                    key: const ValueKey('send'),
                    onTap: _submit,
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  )
                : InkWell(
                    key: const ValueKey('mic'),
                    onTap: widget.onMicTap,
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.brandPrimary, AppColors.brandSecondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

