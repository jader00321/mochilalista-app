import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/sliver_sticky_header_delegate.dart';

class InventoryFilterHeader extends StatelessWidget {
  final InventoryProvider provider;
  final bool isDark;
  final int viewMode;
  final ValueChanged<int> onViewModeChanged;

  const InventoryFilterHeader({
    super.key,
    required this.provider,
    required this.isDark,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  Widget _buildSortButton(
    BuildContext context,
    InventoryProvider provider,
    IconData icon,
    SortType type,
    String label,
    bool isDark,
  ) {
    final isSelected = provider.prodSort == type;
    final color = isSelected
        ? (isDark ? Colors.blue[300]! : Theme.of(context).primaryColor)
        : (isDark ? Colors.grey[500]! : Colors.grey);

    return InkWell(
      onTap: () => provider.sortProducts(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                provider.prodAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewIcon(IconData icon, int mode, bool isDark) {
    final isSelected = viewMode == mode;
    return InkWell(
      onTap: () => onViewModeChanged(mode),
      child: Container(
        width: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white10 : Colors.grey[200])
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: mode == 0 ? const Radius.circular(10) : Radius.zero,
            right: mode == 2 ? const Radius.circular(10) : Radius.zero,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? Colors.white10 : Colors.grey.shade200,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: SliverStickyHeaderDelegate(
        minHeight: 72.0,
        maxHeight: 72.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "${provider.totalProductsCount} Productos",
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
                        "${provider.totalPresentationsCount} Variantes",
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Row(
                children: [
                  _buildSortButton(
                    context,
                    provider,
                    Icons.numbers,
                    SortType.id,
                    "ID",
                    isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildSortButton(
                    context,
                    provider,
                    Icons.sort_by_alpha,
                    SortType.alpha,
                    "A-Z",
                    isDark,
                  ),

                  Container(
                    height: 26,
                    width: 1,
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),

                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF23232F) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewIcon(Icons.view_list, 0, isDark),
                        _buildVerticalDivider(isDark),
                        _buildViewIcon(Icons.grid_view, 1, isDark),
                        _buildVerticalDivider(isDark),
                        _buildViewIcon(Icons.view_headline, 2, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
