import 'package:flutter/material.dart';
import '../../../../providers/catalog_provider.dart';
import '../../../../widgets/sliver_sticky_header_delegate.dart';

class CatalogFilterHeader extends StatelessWidget {
  final CatalogProvider provider;
  final bool isDark;

  const CatalogFilterHeader({
    super.key,
    required this.provider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return SliverPersistentHeader(
      pinned: true,
      delegate: SliverStickyHeaderDelegate(
        minHeight: 60.0,
        maxHeight: 60.0,
        child: Container(
          color: isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 22, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${provider.displayItems.length} productos",
                        style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.white70 : Colors.grey[800], fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 10),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => provider.toggleSortOrder(),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                          child: Text(
                            provider.isSortAscending ? "A - Z" : "Z - A",
                            key: ValueKey(provider.isSortAscending),
                            style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: provider.isSortAscending ? 0 : 0.5,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(Icons.arrow_downward_rounded, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      ),
    );
  }
}
