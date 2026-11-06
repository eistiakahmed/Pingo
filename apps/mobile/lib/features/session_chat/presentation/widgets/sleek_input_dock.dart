import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';

/// Ultra-clean, user-friendly input dock with document upload icon,
/// borderless text field, and voice/send action button.
class SleekInputDock extends StatefulWidget {
  final Function(String) onSubmitText;
  final VoidCallback onVoiceTap;
  final VoidCallback onUploadTap;

  const SleekInputDock({
    super.key,
    required this.onSubmitText,
    required this.onVoiceTap,
    required this.onUploadTap,
  });

  @override
  State<SleekInputDock> createState() => _SleekInputDockState();
}

class _SleekInputDockState extends State<SleekInputDock> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasTextNow = _controller.text.trim().isNotEmpty;
      if (hasTextNow != _hasText) {
        setState(() => _hasText = hasTextNow);
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
      widget.onSubmitText(text);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dockBg = isDark ? const Color(0xFF1E242B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3842) : const Color(0xFFE5E7EB);
    final iconColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final hintColor = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Document Upload Icon Button (No text, pure clean icon)
          IconButton(
            icon: Icon(
              Icons.attach_file_rounded,
              color: iconColor,
              size: 24,
            ),
            tooltip: 'Upload Document or File',
            splashRadius: 22,
            onPressed: widget.onUploadTap,
          ),

          // Borderless Clean Text Input (Zero internal boxes/outlines)
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: textColor,
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
              cursorColor: AppColors.brandPrimary,
              decoration: InputDecoration(
                hintText: 'Ask, remember, or draft anything...',
                hintStyle: TextStyle(
                  color: hintColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),

          const SizedBox(width: 4),

          // Dynamic Action Button (Voice Mic vs Send Arrow)
          GestureDetector(
            onTap: _hasText ? _submit : widget.onVoiceTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hasText
                    ? AppColors.brandPrimary
                    : AppColors.brandPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _hasText ? Icons.arrow_upward_rounded : Icons.mic_rounded,
                  color: _hasText ? Colors.white : AppColors.brandPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

