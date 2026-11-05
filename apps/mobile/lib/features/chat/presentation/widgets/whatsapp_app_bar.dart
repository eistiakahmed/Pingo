import 'package:flutter/material.dart';

/// WhatsApp-style header for the Pingo AI Bot chat.
class WhatsAppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onVoiceCallTap;
  final VoidCallback onClearChat;

  const WhatsAppAppBar({
    super.key,
    required this.onVoiceCallTap,
    required this.onClearChat,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // WhatsApp header green in light mode (#008069), dark slate in dark mode (#1F2C34)
    final bgColor = isDark ? const Color(0xFF1F2C34) : const Color(0xFF008069);
    const contentColor = Colors.white;

    return AppBar(
      backgroundColor: bgColor,
      elevation: 1,
      scrolledUnderElevation: 2,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          // Bot Avatar with active online badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    shape: BoxShape.circle,
                    border: Border.all(color: bgColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Bot Name & Status
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pingo',
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'online • AI Memory Assistant',
                  style: TextStyle(
                    color: Color(0xFFE2F4EE),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Voice Call',
          icon: const Icon(Icons.call_rounded, color: contentColor, size: 22),
          onPressed: onVoiceCallTap,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: contentColor),
          color: isDark ? const Color(0xFF233138) : Colors.white,
          onSelected: (value) {
            if (value == 'clear') {
              onClearChat();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'vault',
              child: ListTile(
                leading: Icon(Icons.folder_special_rounded, size: 20),
                title: Text('Memory Vault'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded, size: 20),
                title: Text('Clear chat'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
