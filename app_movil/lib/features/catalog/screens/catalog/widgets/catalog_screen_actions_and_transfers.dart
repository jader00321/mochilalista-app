part of '../catalog_screen.dart';

extension _CatalogScreenActionsExtension on CatalogScreenState {
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
            const Flexible(
              child: Text(
                "Modo Exploración",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "Puedes añadir productos a tu Carrito o a tu Lista para ver cómo funciona el Catálogo.\n\n"
          "Sin embargo, para poder Cotizarlos, Venderlos o Enviarlos como Pedido, necesitas registrar tu negocio en tu Perfil.",
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

  void _goToQuickSale(List<CartItem> listItems, bool isDark) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final catalogProv = Provider.of<CatalogProvider>(context, listen: false);

    if (!quickProv.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Caja Ocupada",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            "Actualmente tienes productos pendientes en la Caja Rápida.\n\n¿Deseas limpiar la caja antes de agregar estos productos, o prefieres mezclarlos?",
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeTransferToQuickSale(
                  listItems,
                  quickProv,
                  catalogProv,
                  clearFirst: false,
                );
              },
              child: Text(
                "Mezclar",
                style: TextStyle(
                  color: isDark ? Colors.blue[300] : Colors.blue,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeTransferToQuickSale(
                  listItems,
                  quickProv,
                  catalogProv,
                  clearFirst: true,
                );
              },
              child: const Text(
                "Limpiar y Cargar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    } else {
      _executeTransferToQuickSale(
        listItems,
        quickProv,
        catalogProv,
        clearFirst: true,
      );
    }
  }

  void _executeTransferToQuickSale(
    List<CartItem> items,
    QuickSaleProvider quickProv,
    CatalogProvider catalogProv, {
    required bool clearFirst,
  }) {
    if (clearFirst) quickProv.clearCart();

    for (var cartItem in items) {
      final presId = cartItem.item.presentation.id!;
      final maxStock = cartItem.item.presentation.stockActual;

      if (!quickProv.cartItems.any((p) => p.presentationId == presId)) {
        quickProv.addToCart(cartItem.item);
        quickProv.updateQuantity(presId, cartItem.quantity, maxStock);
      } else {
        final int currentQty = quickProv.getQuantity(presId);
        quickProv.updateQuantity(
          presId,
          currentQty + cartItem.quantity,
          maxStock,
        );
      }
    }

    catalogProv.clearCart();
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
    );
  }

  void _goToManualQuotation(List<CartItem> listItems, bool isDark) {
    final quoteProv = Provider.of<SmartQuotationProvider>(
      context,
      listen: false,
    );
    final catalogProv = Provider.of<CatalogProvider>(context, listen: false);

    if (!quoteProv.hasManualDraft) {
      _executeTransferToQuotation(
        listItems,
        quoteProv,
        catalogProv,
        clearFirst: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Cotización en Progreso",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Tienes una lista en curso.\n\n¿Deseas limpiar tu lista anterior antes de agregar estos nuevos productos, o prefieres mezclarlos?",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeTransferToQuotation(
                listItems,
                quoteProv,
                catalogProv,
                clearFirst: false,
              );
            },
            child: Text(
              "Mezclar",
              style: TextStyle(
                color: isDark ? Colors.blue[300] : Colors.blue,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeTransferToQuotation(
                listItems,
                quoteProv,
                catalogProv,
                clearFirst: true,
              );
            },
            child: const Text(
              "Limpiar y Cargar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _executeTransferToQuotation(
    List<CartItem> listItems,
    SmartQuotationProvider quoteProv,
    CatalogProvider catalogProv, {
    required bool clearFirst,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;

    final List<MatchedProduct> currentItems = clearFirst
        ? []
        : List.from(quoteProv.draftManualItems ?? []);
    final Map<int, int> currentQuantities = clearFirst
        ? {}
        : Map.from(quoteProv.draftManualQuantities ?? {});

    bool stockLimitReached = false;

    for (var cartItem in listItems) {
      final item = cartItem.item;
      final prod = item.product;
      final pres = item.presentation;
      final presId = pres.id!;

      final String cleanName = prod.nombre;

      String brandName = "";
      if (prod.marcaId != null) {
        brandName = catalogProv.getBrandName(prod.marcaId);
      }

      int newQty = cartItem.quantity;

      if (currentQuantities.containsKey(presId)) {
        newQty += currentQuantities[presId]!;
      }

      // Protección de stock para clientes al mezclar listas
      if (isClient && newQty > pres.stockActual) {
        newQty = pres.stockActual;
        stockLimitReached = true;
      }

      if (currentQuantities.containsKey(presId)) {
        currentQuantities[presId] = newQty;
      } else {
        currentItems.add(
          MatchedProduct(
            productId: prod.id,
            presentationId: presId,
            fullName: cleanName,
            productName: prod.nombre,
            specificName: pres.nombreEspecifico,
            brand: brandName.isNotEmpty ? brandName : null,
            price: pres.precioVentaFinal,
            offerPrice: pres.precioOferta,
            stock: pres.stockActual,
            imageUrl: pres.imagenUrl ?? prod.imagenUrl,
            unit: pres.unidadVenta ?? "Unidad",
          ),
        );
        currentQuantities[presId] = newQty;
      }
    }

    if (stockLimitReached) {
      CustomSnackBar.show(
        context,
        message:
            "Algunos productos se ajustaron al límite de stock disponible.",
        isError: true,
      );
    }

    catalogProv.clearUtilityList();
    if (Navigator.canPop(context)) Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualQuotationScreen(
          initialItems: currentItems,
          initialQuantities: currentQuantities,
        ),
      ),
    );
  }

  void _showDetailModal(BuildContext context, InventoryWrapper item) {
    ProductDetailModal.show(
      context,
      item: item,
      isStoreMode: _isStoreMode,
      onAddToCart: (qty, [selectedPres]) {
        final targetWrapper = (selectedPres != null)
            ? item.copyWith(presentation: selectedPres)
            : item;
        Provider.of<CatalogProvider>(
          context,
          listen: false,
        ).addToCart(targetWrapper, qty);
        CustomSnackBar.show(
          context,
          message: "Agregado al Carrito: ${targetWrapper.displayNameDetail}",
          isError: false,
        );
        _refreshState(() {
          _isBottomMenuExpanded = true;
          _showBottomCart = true;
        });
      },
      onAddToList: (qty, [selectedPres]) {
        final targetWrapper = (selectedPres != null)
            ? item.copyWith(presentation: selectedPres)
            : item;
        Provider.of<CatalogProvider>(
          context,
          listen: false,
        ).addToUtilityList(targetWrapper, qty);
        CustomSnackBar.show(
          context,
          message: "Agregado a tu Lista: ${targetWrapper.displayNameDetail}",
          backgroundColor: Colors.orange[800]!,
        );
        _refreshState(() {
          _isBottomMenuExpanded = true;
          _showBottomCart = true;
        });
      },
    );
  }

  void _showListPreview(
    BuildContext context,
    bool isCart,
    bool isDark,
    AuthProvider auth,
  ) {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return CatalogCartModal(
          isCart: isCart,
          isDark: isDark,
          onProcessTap: () {
            if (!auth.hasActiveContext) {
              Navigator.pop(ctx);
              _showExplorationModal(context, isDark);
              return;
            }

            final prov = Provider.of<CatalogProvider>(context, listen: false);
            if (isCart) {
              _goToQuickSale(prov.shoppingCart, isDark);
            } else {
              _goToManualQuotation(prov.utilityList, isDark);
            }
          },
        );
      },
    );
  }
}
