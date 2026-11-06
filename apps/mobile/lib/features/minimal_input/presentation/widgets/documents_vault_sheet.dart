import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';

/// Structured document summary model for the Vault.
class SavedDocument {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String formattedDate;
  final List<String> tags;

  const SavedDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.formattedDate,
    required this.tags,
  });
}

/// Clean Modal Bottom Sheet showing indexed documents and notes.
class DocumentsVaultSheet extends StatelessWidget {
  const DocumentsVaultSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DocumentsVaultSheet(),
    );
  }

  static const List<SavedDocument> _sampleDocs = [
    SavedDocument(
      id: 'doc_1',
      title: 'Client Sync & Deliverables (Q4)',
      category: 'Work & Projects',
      summary: 'Sprint planning and core milestone agreement for the mobile app launch.',
      formattedDate: 'Today, 2:40 AM',
      tags: ['Meeting', 'Client', 'Q4 Roadmap'],
    ),
    SavedDocument(
      id: 'doc_2',
      title: 'Passport & National ID Data',
      category: 'Personal Documents',
      summary: 'Scanned expiry dates and emergency identification metadata.',
      formattedDate: 'Yesterday',
      tags: ['Identity', 'Vault'],
    ),
    SavedDocument(
      id: 'doc_3',
      title: 'Apartment Lease Terms',
      category: 'Finance & Housing',
      summary: 'Rent payment schedule, security deposit terms, and notice period.',
      formattedDate: 'Nov 2, 2026',
      tags: ['Contract', 'Important'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E242B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111B21);
    final cardBg = isDark ? const Color(0xFF28313A) : const Color(0xFFF7F9FA);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.folder_special_rounded, color: AppColors.brandPrimary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Document Vault',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _sampleDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = _sampleDocs[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF38434F) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.description_rounded, color: AppColors.brandPrimary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.title,
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      doc.category,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            doc.summary,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ...doc.tags.map(
                                (tag) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                doc.formattedDate,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

