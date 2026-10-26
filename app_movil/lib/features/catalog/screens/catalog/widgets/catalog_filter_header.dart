import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/widgets/sliver_sticky_header_delegate.dart';
import 'package:app_movil/features/catalog/screens/catalog/widgets/catalog_sort_modal.dart';

class CatalogFilterHeader extends StatelessWidget {
  final CatalogProvider provider;
  final bool isDark;
  final VoidCallback? onSortTap;

  const CatalogFilterHeader({
    super.key,
    required this.provider,
    required this.isDark,
    this.onSortTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: SliverStickyHeaderDelegate(
        minHeight: 56.0,
        maxHeight: 56.0,
        child: CatalogCounterBar(
          provider: provider,
          isDark: isDark,
          onSortTap: onSortTap,
        ),
      ),
    );
  }
}

class CatalogCounterBar extends StatelessWidget {
  final CatalogProvider provider;
  final bool isDark;
  final VoidCallback? onSortTap;

  const CatalogCounterBar({
    super.key,
    required this.provider,
    required this.isDark,
    this.onSortTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 22,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "${provider.realTotalProductsCount} Productos",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey[800],
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "${provider.realTotalPresentationsCount} Variantes",
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSortTap ?? () => CatalogSortModal.show(context, provider),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.15)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.blue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Text(
                        "${provider.sortOption.emoji} ${provider.sortOption.shortLabel}",
                        key: ValueKey(provider.sortOption),
                        style: textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? Colors.blue[300]
                              : Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
