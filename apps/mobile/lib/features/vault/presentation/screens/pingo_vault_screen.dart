import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/vault/presentation/screens/pingo_add_document_screen.dart';
import 'package:pingo_mobile/features/vault/presentation/screens/pingo_document_detail_screen.dart';

/// Document model for the Vault
class VaultDocument {
  final String id;
  final String title;
  final String category;
  final String expiresDate;
  final String statusText;
  final Color statusBg;
  final Color statusColor;

  const VaultDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.expiresDate,
    required this.statusText,
    required this.statusBg,
    required this.statusColor,
  });
}

/// Screen implementing '11. Vault.png' with clean dynamic data & zero mock data.
class PingoVaultScreen extends StatefulWidget {
  const PingoVaultScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PingoVaultScreen()),
    );
  }

  @override
  State<PingoVaultScreen> createState() => _PingoVaultScreenState();
}

class _PingoVaultScreenState extends State<PingoVaultScreen> {
  // Clean dynamic list: Starts completely empty (no mock data)
  final List<VaultDocument> _documents = [];

  void _addNewDocFromScanner() {
    PingoAddDocumentScreen.open(context);
  }

  int _getCount(String category) {
    return _documents.where((d) => d.category.toLowerCase() == category.toLowerCase()).length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pingoSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.pingoBorder;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;
    final mutedColor = isDark ? AppColors.darkTextSecondary : AppColors.pingoMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Top Bar: Back | Vault | Encrypted Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                              color: isDark ? AppColors.darkSurface : Colors.white,
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Vault',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: const [
                        Icon(Icons.circle, color: AppColors.success, size: 8),
                        SizedBox(width: 6),
                        Text(
                          'Locked and encrypted',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Search, or say "show my passport"',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2x2 Category Grid (Dynamic counts)
                Row(
                  children: [
                    Expanded(
                      child: _categoryCard(
                        icon: Icons.person_outline_rounded,
                        label: 'Identity',
                        docCount: '${_getCount('Identity')} documents',
                        iconBg: const Color(0xFFECEBFC),
                        iconColor: AppColors.pingoPurple,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _categoryCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Finance',
                        docCount: '${_getCount('Finance')} documents',
                        iconBg: const Color(0xFFFEF3C7),
                        iconColor: const Color(0xFFD97706),
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _categoryCard(
                        icon: Icons.favorite_border_rounded,
                        label: 'Health',
                        docCount: '${_getCount('Health')} documents',
                        iconBg: const Color(0xFFFEE2E2),
                        iconColor: const Color(0xFFDC2626),
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _categoryCard(
                        icon: Icons.school_outlined,
                        label: 'Education',
                        docCount: '${_getCount('Education')} documents',
                        iconBg: const Color(0xFFD1FAE5),
                        iconColor: const Color(0xFF059669),
                        cardBg: cardBg,
                        borderColor: borderColor,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Section: Needs attention soon
                Text(
                  'Needs attention soon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),

                // Empty State vs Document List
                if (_documents.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.pingoPurpleLight,
                          ),
                          child: const Icon(
                            Icons.folder_open_rounded,
                            color: AppColors.pingoPurple,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your vault is empty',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add your passport, driving license, or insurance documents to keep them safe and track expiry dates.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: mutedColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._documents.map((doc) => Column(
                        children: [
                          _documentItem(
                            context: context,
                            title: doc.title,
                            category: doc.category,
                            badgeText: doc.statusText,
                            badgeColor: doc.statusBg,
                            badgeTextColor: doc.statusColor,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            borderColor: borderColor,
                          ),
                          Divider(color: borderColor, height: 1),
                        ],
                      )),

                const SizedBox(height: 100),
              ],
            ),

            // Bottom Fixed '+ Add document' Button
            Positioned(
              left: 24,
              right: 24,
              bottom: 18,
              child: Center(
                child: InkWell(
                  onTap: _addNewDocFromScanner,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.pingoPurple,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pingoPurple.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Add document',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard({
    required IconData icon,
    required String label,
    required String docCount,
    required Color iconBg,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color mutedColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            docCount,
            style: TextStyle(
              fontSize: 13,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentItem({
    required BuildContext context,
    required String title,
    required String category,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: () => PingoDocumentDetailScreen.open(context, title: title, category: category),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    category,
                    style: TextStyle(fontSize: 13.5, color: mutedColor),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
