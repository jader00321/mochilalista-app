part of '../matching_screen.dart';

mixin _MatchingItemModalsMixin on _MatchingScreenBase {
  @override
  Future<void> _openDetailsModal(BuildContext context, MatchPair pair) async {
    if (pair.selectedProduct == null) return;

    try {
      final inventoryProv = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      Product? fullProduct;

      try {
        fullProduct = await inventoryProv.getFullProductWithFallback(
          pair.selectedProduct!.productId,
        );
      } catch (_) {
        fullProduct = null;
      }

      if (!context.mounted) return;

      if (fullProduct == null || fullProduct.presentaciones.isEmpty) {
        fullProduct = Product(
          id: pair.selectedProduct!.productId,
          nombre: pair.selectedProduct!.productName,
          categoriaId: fullProduct?.categoriaId ?? 0,
          imagenUrl: pair.selectedProduct!.imageUrl,
          marcaId: fullProduct?.marcaId,
          presentaciones: [
            ProductPresentation(
              id: pair.selectedProduct!.presentationId,
              unidadVenta: pair.selectedProduct!.unit,
              nombreEspecifico: pair.selectedProduct!.specificName,
              precioVentaFinal: pair.selectedProduct!.price,
              precioOferta: pair.selectedProduct!.offerPrice,
              stockActual: pair.selectedProduct!.stock,
              unidadesPorLote: pair.selectedProduct!.conversionFactor,
              imagenUrl: pair.selectedProduct!.imageUrl,
            ),
          ],
        );
      }

      final currentPres = fullProduct.presentaciones.firstWhere(
        (p) => p.id == pair.selectedProduct!.presentationId,
        orElse: () => fullProduct!.presentaciones.first,
      );

      final wrapper = InventoryWrapper(
        product: fullProduct,
        presentation: currentPres,
      );
      final String? brandName = fullProduct.marcaId != null
          ? inventoryProv.getBrandName(fullProduct.marcaId)
          : pair.selectedProduct!.brand;

      final capturedProduct = fullProduct;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (ctx) => ProductQuoteDetailModal(
          wrapper: wrapper,
          brandName: brandName,
          currentQuantity: pair.selectedQuantity,
          currentOverridePrice: pair.overridePrice,
          availableBundles: Provider.of<MatchingProvider>(
            context,
            listen: false,
          ).activeBundles,
          bundleItemsCache: Provider.of<MatchingProvider>(
            context,
            listen: false,
          ).bundleItemsCache,
          onSave: (newPres, newQty, newPrice, _) {
            final provider = Provider.of<MatchingProvider>(
              context,
              listen: false,
            );

            final String variantFullName =
                (newPres.nombreEspecifico != null &&
                    newPres.nombreEspecifico!.isNotEmpty)
                ? "${capturedProduct.nombre} ${newPres.nombreEspecifico}".trim()
                : capturedProduct.nombre;

            final int factor = newPres.unidadesPorVenta > 0
                ? newPres.unidadesPorVenta
                : 1;
            final int displayStock = newPres.stockActual ~/ factor;

            final newMatched = MatchedProduct(
              productId: capturedProduct.id,
              presentationId: newPres.id!,
              fullName: variantFullName,
              productName: capturedProduct.nombre,
              specificName: newPres.nombreEspecifico,
              brand: brandName,
              price: newPres.precioVentaFinal,
              offerPrice: newPres.precioOferta,
              stock: displayStock,
              imageUrl: newPres.imagenUrl ?? capturedProduct.imagenUrl,
              unit: newPres.unidadVenta ?? "Unidad",
              conversionFactor: factor,
            );

            provider.updatePairProduct(pair.sourceItem.id, newMatched);
            provider.updatePairPrice(pair.sourceItem.id, newPrice);
            provider.updatePairQuantity(pair.sourceItem.id, newQty);
          },
        ),
      );
    } catch (e) {
      debugPrint("Error abriendo detalle de producto: $e");
      if (context.mounted) {
        AppFeedbackHelper.showError(
          context,
          "Ocurrió un error al intentar abrir el detalle del producto.",
        );
      }
    }
  }

  @override
  void _openSearchModal(BuildContext context, MatchPair pair, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => MatchingProductSearchModal(
        initialQuery: pair.sourceItem.fullName,
        isDark: isDark,
        onProductSelected: (product, categoryName) {
          Provider.of<MatchingProvider>(
            context,
            listen: false,
          ).updatePairProduct(pair.sourceItem.id, product);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  void _openSuggestedReplacementsModal(
    BuildContext context,
    MatchPair pair,
    bool isDark,
  ) {
    SuggestedReplacementsModal.show(
      context: context,
      pair: pair,
      isDark: isDark,
      onSelectReplacement: (product) {
        Provider.of<MatchingProvider>(
          context,
          listen: false,
        ).updatePairProduct(pair.sourceItem.id, product);
        AppFeedbackHelper.showSuccess(
          context,
          "Reemplazo asignado: ${product.fullName}",
        );
      },
    );
  }

  @override
  void _confirmAndDeletePair(
    BuildContext context,
    MatchPair pair,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Eliminar Producto",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          "¿Estás seguro de que deseas eliminar '${pair.sourceItem.fullName}' de la lista?",
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<MatchingProvider>(
                context,
                listen: false,
              ).deletePair(pair.sourceItem.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }
}
