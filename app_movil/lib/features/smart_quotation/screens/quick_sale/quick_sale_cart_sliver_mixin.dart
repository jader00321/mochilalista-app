part of '../quick_sale_screen.dart';

mixin _QuickSaleCartSliverMixin on _QuickSaleScreenStateBase {
  List<Widget> _buildCartSlivers(
    QuickSaleProvider quickProv,
    PromotionProvider promoProv,
    bool isDark,
  ) {
    if (quickProv.cartItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: KeyedSubtree(
            key: _tourKeys.cartContainerKey,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.point_of_sale,
                      size: 90,
                      color: isDark ? Colors.white10 : Colors.pink[100],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Caja Libre",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Busca un producto para empezar a cobrar",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    String? upsellMessage;
    for (var item in quickProv.cartItems) {
      for (var bundle in promoProv.bundles) {
        if (bundle.activo) {
          final bItems = promoProv.getItemsForBundle(bundle.id);
          if (bItems.any((b) => b.presentacionId == item.presentationId)) {
            upsellMessage =
                "¡Upsell! Cambia ${item.productName} por el paquete '${bundle.nombrePaquete}' y aumenta el ticket promedio.";
            break;
          }
        }
      }
      if (upsellMessage != null) break;
    }

    return [
      if (upsellMessage != null)
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    upsellMessage,
                    style: TextStyle(
                      color: isDark ? Colors.orange[200] : Colors.orange[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.only(top: 16, bottom: 30),
        sliver: SliverReorderableList(
          itemCount: quickProv.cartItems.length,
          onReorder: (oldIndex, newIndex) =>
              quickProv.reorderCart(oldIndex, newIndex),
          itemBuilder: (ctx, i) {
            final item = quickProv.cartItems[i];
            final qty = quickProv.getQuantity(item.presentationId);
            final price = quickProv.getEffectivePrice(item.presentationId);

            return QuickSaleCartItem(
              key: ValueKey(item.presentationId),
              product: item,
              quantity: qty,
              effectivePrice: price,
              onTap: () => _openDetailModal(quickProv, item.presentationId),
              onIncrease: () {
                final error = quickProv.updateQuantity(
                  item.presentationId,
                  qty + 1,
                  item.stock,
                );
                if (error != null) AppFeedbackHelper.showError(context, error);
              },
              onDecrease: () {
                final error = quickProv.updateQuantity(
                  item.presentationId,
                  qty - 1,
                  item.stock,
                );
                if (error != null) AppFeedbackHelper.showError(context, error);
              },
              onDelete: () => quickProv.removeItem(item.presentationId),
            );
          },
        ),
      ),
    ];
  }
}
