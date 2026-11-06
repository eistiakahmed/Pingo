import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'hub_screen.dart';
import 'package:pingo_mobile/features/chat/presentation/screens/chat_screen.dart';
import 'package:pingo_mobile/features/chat/presentation/state/chat_provider.dart';

/// Main Navigation Shell hosting the Ambient Hub, Conversational Assistant, and Document Vault.
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _handleStartChat(String query) {
    ref.read(chatProvider.notifier).sendUserMessage(query);
    _switchTab(1); // Switch to Chat Tab
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      HubScreen(
        onStartChat: _handleStartChat,
        onOpenVault: () => _switchTab(2),
      ),
      const ChatScreen(),
      const _VaultPlaceholderView(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _switchTab,
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.brandPrimary.withValues(alpha: 0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.brandPrimary),
              label: 'হোম হাব',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.brandPrimary),
              label: 'অ্যাসিস্ট্যান্ট',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded, color: AppColors.brandPrimary),
              label: 'ভল্ট ও ডকস',
            ),
          ],
        ),
      ),
    );
  }
}

/// Vault & Documents preview screen.
class _VaultPlaceholderView extends StatelessWidget {
  const _VaultPlaceholderView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📁 মেমোরি ভল্ট ও ডকুমেন্টস'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.brandPrimary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'এনক্রিপ্টেড মেমোরি ভল্ট',
                style: AppTypography.headlineSmall(),
              ),
              const SizedBox(height: 8),
              Text(
                'আপনার পাসপোর্ট, লাইসেন্স, প্রেসক্রিপশন ও পিংগোর তৈরি ডকুমেন্টেশন এখানে নিরাপদে সংরক্ষিত থাকবে।',
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
