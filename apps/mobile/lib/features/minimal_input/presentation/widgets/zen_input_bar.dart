import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';

/// Single unified capture dock with Doc button, text input, and voice mic.
class ZenInputBar extends StatefulWidget {
  final Function(String) onSubmitText;
  final VoidCallback onVoiceTap;
  final VoidCallback onDocTap;

  const ZenInputBar({
    super.key,
    required this.onSubmitText,
    required this.onVoiceTap,
    required this.onDocTap,
  });

  @override
  State<ZenInputBar> createState() => _ZenInputBarState();
}

class _ZenInputBarState extends State<ZenInputBar> {
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

    final barBg = isDark ? const Color(0xFF1E242B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3842) : const Color(0xFFE5E7EB);
    final hintColor = isDark ? const Color(0xFF8B98A5) : const Color(0xFF9CA3AF);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          // Doc Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onDocTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: AppColors.brandPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Docs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),

          // Single Text Input
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: textColor, fontSize: 15.5),
              decoration: InputDecoration(
                hintText: 'Type a thought, task, or note...',
                hintStyle: TextStyle(color: hintColor, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),

          // Dynamic Action Button (Voice Mic vs Send)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _hasText ? AppColors.brandPrimary : AppColors.brandPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _hasText ? Icons.arrow_upward_rounded : Icons.mic_rounded,
                color: _hasText ? Colors.white : AppColors.brandPrimary,
                size: 22,
              ),
              onPressed: _hasText ? _submit : widget.onVoiceTap,
            ),
          ),
        ],
      ),
    );
  }
}

