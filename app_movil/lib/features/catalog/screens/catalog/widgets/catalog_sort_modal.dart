import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class CatalogSortModal extends StatelessWidget {
  final CatalogProvider provider;

  const CatalogSortModal({super.key, required this.provider});

  static Future<void> show(BuildContext context, CatalogProvider provider) {
    HapticFeedback.lightImpact();
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => CatalogSortModal(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeOption = provider.sortOption;

    return InteractiveSheetWrapper(
      title: "Ordenar Catálogo",
      icon: Icons.sort_rounded,
      iconColor: isDark ? Colors.blue[300] : Colors.blue[700],
      maxHeightFactor: 0.65,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Selecciona cómo deseas organizar tus productos y variantes:",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: CatalogSortOption.values.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final option = CatalogSortOption.values[index];
                  final isSelected = activeOption == option;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.setSortOption(option);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : Colors.blue.withValues(alpha: 0.1))
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? Colors.blue[400]! : Colors.blue[700]!)
                                : (isDark
                                    ? Colors.white10
                                    : Colors.grey.shade300),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              option.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? (isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[800])
                                      : (isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
