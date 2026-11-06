import 'package:flutter/material.dart';

/// WhatsApp-style bottom input dock with dynamic voice/send button.
class WhatsAppInputBar extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback onVoiceTap;
  final VoidCallback onAttachmentTap;

  const WhatsAppInputBar({
    super.key,
    required this.onSendMessage,
    required this.onVoiceTap,
    required this.onAttachmentTap,
  });

  @override
  State<WhatsAppInputBar> createState() => _WhatsAppInputBarState();
}

class _WhatsAppInputBarState extends State<WhatsAppInputBar> {
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

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldBg = isDark ? const Color(0xFF202C33) : Colors.white;
    final hintColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final iconColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F);
    const actionButtonColor = Color(0xFF00A884); // WhatsApp green button

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Chat Input Pill
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_circle_outline_rounded, color: iconColor, size: 24),
                      onPressed: widget.onAttachmentTap,
                      splashRadius: 20,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF111B21),
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message Pingo...',
                          hintStyle: TextStyle(color: hintColor, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Dynamic Action Button (Voice Mic vs Send)
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: actionButtonColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _hasText ? _handleSend : widget.onVoiceTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
