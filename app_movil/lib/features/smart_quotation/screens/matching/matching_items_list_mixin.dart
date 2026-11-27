part of '../matching_screen.dart';

mixin _MatchingItemsListMixin on _MatchingScreenBase {
  Widget _buildEmptyMatchedCard(bool isDark) {
    return KeyedSubtree(
      key: _tourKeys.matchedItemsKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.fact_check_outlined,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Aquí verás los útiles emparejados con tu inventario y equivalentes sugeridos.",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedItemsSliver(
    MatchingProvider matchingProvider,
    bool isDark,
    bool isClient,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final pair = matchingProvider.pairs[i];
          Widget rowWidget;

          if (pair.bundleId != null) {
            final isFirstInBundle =
                matchingProvider.pairs.indexWhere(
                  (p) => p.bundleId == pair.bundleId,
                ) ==
                i;
            if (!isFirstInBundle) return const SizedBox.shrink();

            rowWidget = _buildBundleGroupCard(
              context: ctx,
              matchingProvider: matchingProvider,
              bundleId: pair.bundleId!,
              isDark: isDark,
              isClient: isClient,
            );
          } else {
            final isRepeated = matchingProvider.isProductRepeated(
              pair.selectedProduct?.presentationId,
            );
            rowWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MatchingItemRow(
                pair: pair,
                index: i,
                isRepeated: isRepeated,
                isClient: isClient,
                onTapProduct: () => _openDetailsModal(ctx, pair),
                onChangeRequest: () => _openSearchModal(ctx, pair, isDark),
                onDelete: () => _confirmAndDeletePair(ctx, pair, isDark),
                onUnlink: () =>
                    matchingProvider.unmatchItem(pair.sourceItem.id),
                onSuggestedReplacements: () =>
                    _openSuggestedReplacementsModal(ctx, pair, isDark),
              ),
            );
          }

          if (i == 0) {
            return KeyedSubtree(
              key: _tourKeys.matchedItemsKey,
              child: rowWidget,
            );
          }
          return rowWidget;
        }, childCount: matchingProvider.pairs.length),
      ),
    );
  }

  Widget _buildBundleGroupCard({
    required BuildContext context,
    required MatchingProvider matchingProvider,
    required int bundleId,
    required bool isDark,
    required bool isClient,
  }) {
    final bundlePairs = matchingProvider.pairs
        .where((p) => p.bundleId == bundleId)
        .toList();
    final bundleModel = matchingProvider.activeBundles.firstWhere(
      (b) => b.id == bundleId,
    );
    final double totalSavings =
        bundlePairs.fold(
          0.0,
          (sum, p) => sum + (p.originalUnitPrice * p.selectedQuantity),
        ) -
        bundleModel.precioVentaTotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.amber.withValues(alpha: 0.03)
            : Colors.amber.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.amber.withValues(alpha: 0.1)
                  : Colors.amber.withValues(alpha: 0.2),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.amber.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.stars, color: Colors.amber, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Agrupados en ${bundleModel.nombrePaquete}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (bundleModel.descripcion != null &&
                                bundleModel.descripcion!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  bundleModel.descripcion!,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.amber.shade300
                                        : Colors.amber.shade800,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TextButton.icon(
                      onPressed: () => matchingProvider.toggleBundleGrouping(
                        bundleModel.id,
                        false,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.link_off,
                        size: 14,
                        color: Colors.red,
                      ),
                      label: const Text(
                        "Desarmar",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (totalSavings > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_offer, color: Colors.green[600], size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Ahorro Múltiple de ${AppCurrency.format(totalSavings)}",
                        style: TextStyle(
                          color: isDark ? Colors.green[400] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          ...bundlePairs.map((bp) {
            final int originalIndex = matchingProvider.pairs.indexOf(bp);
            final bool isRepeated = matchingProvider.isProductRepeated(
              bp.selectedProduct?.presentationId,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: MatchingItemRow(
                pair: bp,
                index: originalIndex,
                isRepeated: isRepeated,
                isClient: isClient,
                onTapProduct: () => _openDetailsModal(context, bp),
                onChangeRequest: () => _openSearchModal(context, bp, isDark),
                onDelete: () => _confirmAndDeletePair(context, bp, isDark),
                onUnlink: () => matchingProvider.unmatchItem(bp.sourceItem.id),
                onSuggestedReplacements: () =>
                    _openSuggestedReplacementsModal(context, bp, isDark),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildManualAddSliver(
    MatchingProvider matchingProvider,
    bool isDark,
    TextTheme textTheme,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: KeyedSubtree(
            key: _tourKeys.manualAddKey,
            child: TextButton.icon(
              icon: Icon(
                Icons.add_circle_outline,
                size: 24,
                color: isDark ? Colors.blue[300] : Colors.blue,
              ),
              label: Text(
                "Agregar Fila Manual",
                style: textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.blue[300] : Colors.blue,
                ),
              ),
              onPressed: () => matchingProvider.addManualRow(),
            ),
          ),
        ),
      ),
    );
  }
}
