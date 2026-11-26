part of '../products_tab.dart';

extension _ProductsTabListAndSlivers on _ProductsTabState {
  Widget _buildCreationDraftBanner(
    BuildContext context,
    InventoryProvider provider,
    bool isDark,
  ) {
    final draft = provider.creationDraft!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductCreateScreen()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF004D40).withValues(alpha: 0.3)
                  : const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF00897B)
                    : const Color(0xFF80CBC4),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Producto en creación pendiente",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF80CBC4)
                              : const Color(0xFF00695C),
                        ),
                      ),
                      Text(
                        draft.name.trim().isNotEmpty
                            ? "${draft.name.trim()} (${draft.presentations.length} var.) • Toca para continuar"
                            : "Borrador sin título • Toca para continuar",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF00897B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverList(List<InventoryWrapper> items, bool isDark) {
    Widget wrapFirstIfNeeded(int index, Widget child) {
      if (index != 0 || widget.tourKeys == null) {
        return child;
      }
      return KeyedSubtree(key: widget.tourKeys!.productCardKey, child: child);
    }

    if (_viewMode == 1) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => wrapFirstIfNeeded(
              i,
              InventoryGridCard(
                item: items[i],
                onTap: () => _navigateToDetail(ctx, items[i]),
                onTapPrice: () => _openPriceModal(ctx, items[i], isDark),
                onTapStock: () => _openStockModal(ctx, items[i], isDark),
                onMoreOptions: () => _openActions(ctx, items[i]),
              ),
            ),
            childCount: items.length,
          ),
        ),
      );
    }

    if (_viewMode == 2) {
      return SliverPadding(
        padding: const EdgeInsets.only(bottom: 110),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((ctx, i) {
            return Column(
              children: [
                wrapFirstIfNeeded(
                  i,
                  InventoryCompactTile(
                    item: items[i],
                    onTap: () => _navigateToDetail(ctx, items[i]),
                    onTapPrice: () => _openPriceModal(ctx, items[i], isDark),
                    onTapStock: () => _openStockModal(ctx, items[i], isDark),
                    onMoreOptions: () => _openActions(ctx, items[i]),
                  ),
                ),
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            );
          }, childCount: items.length),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 110),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => wrapFirstIfNeeded(
            i,
            InventoryItemTile(
              item: items[i],
              onTap: () => _navigateToDetail(ctx, items[i]),
              onTapPrice: () => _openPriceModal(ctx, items[i], isDark),
              onTapStock: () => _openStockModal(ctx, items[i], isDark),
              onMoreOptions: () => _openActions(ctx, items[i]),
            ),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, InventoryProvider provider) {
    final bool hasFilters =
        provider.activeQuery.isNotEmpty ||
        provider.activeCategoryIds.isNotEmpty ||
        provider.activeBrandIds.isNotEmpty ||
        provider.activeProviderIds.isNotEmpty ||
        provider.activeState != null;

    final Widget content = hasFilters
        ? const EmptyStateWidget(
            icon: Icons.search_off,
            title: "No hay resultados",
            subtitle: "Intenta ajustando tus filtros o términos de búsqueda.",
          )
        : const EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: "Inventario Vacío",
            subtitle:
                "Aún no tienes productos registrados. Escanea una factura o agrega uno manualmente para empezar.",
          );

    if (widget.tourKeys == null) {
      return content;
    }
    return KeyedSubtree(key: widget.tourKeys!.productCardKey, child: content);
  }
}
