part of '../quick_sale_screen.dart';

mixin _QuickSaleDialogsMixin on _QuickSaleScreenStateBase {
  Future<void> _handlePullToRefresh() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
      final promoProv = Provider.of<PromotionProvider>(context, listen: false);
      final invProv = Provider.of<InventoryProvider>(context, listen: false);

      if (auth.activeBusinessId != null) {
        await promoProv.loadPromotions(auth.activeBusinessId!);
        _recentSoldFuture = SalesService().getRecentSoldPresentations(
          auth.activeBusinessId!,
        );
      }

      for (final item in List.of(quickProv.cartItems)) {
        final prod = await invProv.fetchProductById(item.productId);
        if (prod != null) {
          final pres = prod.presentaciones
              .where((p) => p.id == item.presentationId)
              .firstOrNull;
          if (pres != null) {
            final factor = pres.unidadesPorVenta > 0
                ? pres.unidadesPorVenta
                : 1;
            final newOffer = pres.hasOffer ? pres.effectivePrice : null;
            quickProv.syncItemPriceAndStock(
              item.presentationId,
              newPrice: pres.precioVentaFinal,
              newOfferPrice: newOffer,
              clearOffer: !pres.hasOffer,
              newStock: pres.stockActual ~/ factor,
            );
          }
        }
      }

      if (mounted) {
        setState(() {});
        AppFeedbackHelper.showSuccess(
          context,
          "Precios y stock sincronizados con el catálogo.",
          icon: Icons.sync,
        );
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Modo Exploración",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "Estás en el Modo Exploración.\n\nPuedes buscar productos y añadirlos al carrito para probar la interfaz, pero para Procesar el Cobro o Buscar Clientes Reales necesitas tener un negocio registrado.\n\nVe a tu Perfil para crear tu negocio.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Entendido",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> _openDetailModal(
    QuickSaleProvider provider,
    int presentationId,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final item = provider.cartItems.firstWhere(
      (p) => p.presentationId == presentationId,
    );
    final qty = provider.getQuantity(presentationId);
    final effectivePrice = provider.getEffectivePrice(presentationId);

    await QuickSaleDetailModal.show(
      context,
      product: item,
      initialQty: qty,
      initialOverridePrice: effectivePrice,
      onConfirm: (oldPresentationId, product, newQty, newPrice) {
        final error = provider.updateItemFromModal(
          oldPresentationId,
          product,
          newQty,
          newPrice,
        );
        if (error != null) {
          AppFeedbackHelper.showError(context, error);
        }
      },
    );

    if (mounted) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Future<void> _processToCheckout() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    final provider = Provider.of<QuickSaleProvider>(context, listen: false);
    if (provider.isEmpty) return;

    final wasSaleSuccessful = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickCheckoutModal(),
    );

    if (mounted) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      if (wasSaleSuccessful == true) {
        _saleCompleted = true;
      }
    }
  }

  void _showClearCartModal(
    BuildContext context,
    QuickSaleProvider prov,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0.8, end: 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: (scale - 0.8) * 5, child: child),
          );
        },
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_sweep,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "¿Vaciar Caja?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ],
          ),
          content: Text(
            "¿Estás seguro de que deseas eliminar todos los productos de la lista actual? Esta acción no se puede deshacer.",
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Cancelar",
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                prov.clearCart();
                Navigator.pop(ctx);
                AppFeedbackHelper.showSuccess(
                  context,
                  "Caja restablecida por completo",
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Sí, Vaciar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
