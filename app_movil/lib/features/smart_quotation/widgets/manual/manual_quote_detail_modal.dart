import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_price_modifier.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class ManualQuoteDetailModal extends StatefulWidget {
  final MatchedProduct product;
  final int initialQty;
  final double? initialOverridePrice;
  final String? initialCustomName;
  final String? categoryName;
  final bool isNewAddition;
  final bool isEditingSavedQuote;
  final bool isBundleOutdated;
  final Future<bool> Function()? onSyncBundle;
  final void Function(
    int presentationId,
    int newStockBase,
    double? newPrice,
    double? newOfferPrice,
    double? newCost,
  )?
  onCatalogUpdated;
  final void Function(int presentationId, int newStockBase)? onStockUpdated;

  final Function(
    MatchedProduct product,
    int qty,
    double? overridePrice,
    String? customName,
  )
  onConfirm;

  const ManualQuoteDetailModal({
    super.key,
    required this.product,
    this.initialQty = 1,
    this.initialOverridePrice,
    this.initialCustomName,
    this.categoryName,
    this.isNewAddition = false,
    this.isEditingSavedQuote = false,
    this.isBundleOutdated = false,
    this.onSyncBundle,
    this.onCatalogUpdated,
    this.onStockUpdated,
    required this.onConfirm,
  });

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required MatchedProduct product,
    int initialQty = 1,
    double? initialOverridePrice,
    String? initialCustomName,
    String? categoryName,
    bool isNewAddition = false,
    bool isEditingSavedQuote = false,
    bool isBundleOutdated = false,
    Future<bool> Function()? onSyncBundle,
    void Function(
      int presentationId,
      int newStockBase,
      double? newPrice,
      double? newOfferPrice,
      double? newCost,
    )?
    onCatalogUpdated,
    void Function(int presentationId, int newStockBase)? onStockUpdated,
    required Function(
      MatchedProduct product,
      int qty,
      double? overridePrice,
      String? customName,
    )
    onConfirm,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => ManualQuoteDetailModal(
        product: product,
        initialQty: initialQty,
        initialOverridePrice: initialOverridePrice,
        initialCustomName: initialCustomName,
        categoryName: categoryName,
        isNewAddition: isNewAddition,
        isEditingSavedQuote: isEditingSavedQuote,
        isBundleOutdated: isBundleOutdated,
        onSyncBundle: onSyncBundle,
        onCatalogUpdated: onCatalogUpdated,
        onStockUpdated: onStockUpdated,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<ManualQuoteDetailModal> createState() => _ManualQuoteDetailModalState();
}

class _ManualQuoteDetailModalState extends State<ManualQuoteDetailModal> {
  Product? _fullProduct;
  bool _isLoadingVariants = true;
  bool _showVariantSelector = false;

  late MatchedProduct _currentSelection;
  late double _systemPrice;

  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _discountFocusNode = FocusNode();

  bool _isDiscountActive = false;
  bool _isCustomPrice = false;
  bool _isSyncing = false;
  String? _currentCustomName;

  final Map<int, VariantDetailState> _variantDrafts = {};

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.product;
    _systemPrice = widget.product.price;
    _qtyCtrl.text = widget.initialQty.toString();

    // 🛡️ Precision 1: Blindaje de Desactivación Real
    // Si la variante tiene oferta en BD, pero widget.initialOverridePrice coincide con el precio base regular
    // (o se guardó explícitamente _systemPrice), la oferta fue desactivada por el usuario para esta operación.
    final bool isOverrideEqualBase =
        widget.initialOverridePrice != null &&
        (widget.initialOverridePrice! - _systemPrice).abs() < 0.01;

    double effectivePrice;
    if (isOverrideEqualBase) {
      _isDiscountActive = false;
      _isCustomPrice = false;
      effectivePrice = _systemPrice;
      _discountCtrl.text = "";
    } else if (widget.initialOverridePrice != null) {
      _isDiscountActive = true;
      effectivePrice = widget.initialOverridePrice!;
      final double diffFromBase = _systemPrice - effectivePrice;
      _discountCtrl.text = diffFromBase > 0
          ? diffFromBase.toStringAsFixed(2)
          : "";
      final double diffFromCatalog = _currentSelection.hasOffer
          ? (effectivePrice - _currentSelection.effectivePrice).abs()
          : 0.0;
      _isCustomPrice = !_currentSelection.hasOffer || diffFromCatalog >= 0.01;
    } else if (_currentSelection.hasOffer) {
      _isDiscountActive = true;
      _isCustomPrice = false;
      effectivePrice = _currentSelection.effectivePrice;
      final double diffFromBase = _systemPrice - effectivePrice;
      _discountCtrl.text = diffFromBase > 0
          ? diffFromBase.toStringAsFixed(2)
          : "";
    } else {
      _isDiscountActive = false;
      _isCustomPrice = false;
      effectivePrice = _systemPrice;
      _discountCtrl.text = "";
    }

    _priceCtrl.text = effectivePrice.toStringAsFixed(2);
    _currentCustomName = widget.initialCustomName;

    // Guardar borrador inicial para esta variante
    _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
      presentationId: _currentSelection.presentationId,
      quantity: widget.initialQty,
      isDiscountActive: _isDiscountActive,
      price: effectivePrice,
      discountInput: _discountCtrl.text,
      isCustomPrice: _isCustomPrice,
      customName: _currentCustomName,
    );

    _loadVariants();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    try {
      final prod = await invProv.fetchProductById(_currentSelection.productId);
      if (mounted) {
        setState(() {
          _fullProduct = prod;
          _isLoadingVariants = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVariants = false);
    }
  }

  void _onDiscountChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double disc = double.tryParse(val) ?? 0.0;

    if (disc < 0) disc = 0;
    if (disc > _systemPrice) {
      disc = _systemPrice;
      _discountCtrl.text = _systemPrice.toStringAsFixed(2);
    }

    double newPrice = _systemPrice - disc;
    _priceCtrl.text = newPrice.toStringAsFixed(2);

    if (_currentSelection.hasOffer) {
      _isCustomPrice =
          (newPrice - _currentSelection.effectivePrice).abs() >= 0.01;
    } else {
      _isCustomPrice = disc > 0.01;
    }

    _isSyncing = false;
    setState(() {});
  }

  void _onPriceChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double price = double.tryParse(val) ?? _systemPrice;

    if (price < 0) {
      price = 0;
      _priceCtrl.text = "0.00";
    }
    if (price > _systemPrice) {
      price = _systemPrice;
      _priceCtrl.text = _systemPrice.toStringAsFixed(2);
    }

    double disc = _systemPrice - price;
    _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";

    if (_currentSelection.hasOffer) {
      _isCustomPrice = (price - _currentSelection.effectivePrice).abs() >= 0.01;
    } else {
      _isCustomPrice = disc > 0.01;
    }

    _isSyncing = false;
    setState(() {});
  }

  void _restoreCatalogOffer() {
    if (_currentSelection.hasOffer && _currentSelection.offerPrice != null) {
      setState(() {
        _isDiscountActive = true;
        _isCustomPrice = false;
        _priceCtrl.text = _currentSelection.offerPrice!.toStringAsFixed(2);
        final disc = (_systemPrice - _currentSelection.offerPrice!).clamp(
          0.0,
          double.infinity,
        );
        _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";

        _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
          presentationId: _currentSelection.presentationId,
          quantity: int.tryParse(_qtyCtrl.text) ?? 1,
          isDiscountActive: true,
          price: _currentSelection.offerPrice!,
          discountInput: _discountCtrl.text,
          isCustomPrice: false,
          customName: _currentCustomName,
        );
      });
    }
  }

  void _qtyAction(int delta, bool isClient) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newQty = current + delta;
    if (newQty > 0) {
      if (isClient && newQty > _currentSelection.stock) {
        CustomSnackBar.show(
          context,
          message:
              "Límite de stock alcanzado (${_currentSelection.stock} disp.)",
          isError: true,
        );
        return;
      }
      _qtyCtrl.text = newQty.toString();
      setState(() {});
    }
  }

  String _cleanName(String rawName) {
    return rawName
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _updateVariant(ProductPresentation pres) {
    setState(() {
      // 1. Guardar estado de la variante saliente en el mapa de borradores
      _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
        presentationId: _currentSelection.presentationId,
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        isDiscountActive: _isDiscountActive,
        price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
        discountInput: _discountCtrl.text,
        isCustomPrice: _isCustomPrice,
        customName: _currentCustomName,
      );

      // 2. Construir MatchedProduct entrante con su costo y oferta exactos
      String cleanProductName = _cleanName(_fullProduct!.nombre);
      String cleanSpecificName = _cleanName(pres.nombreEspecifico ?? "");

      String fullNameBuilder = cleanProductName;
      if (cleanSpecificName.isNotEmpty &&
          !cleanProductName.toLowerCase().contains(
            cleanSpecificName.toLowerCase(),
          )) {
        fullNameBuilder += " $cleanSpecificName";
      }

      final newOffer = pres.hasOffer ? pres.effectivePrice : null;
      final double presCost = pres.costoPresentacionFinal;
      final double? calculatedCost = presCost > 0
          ? presCost
          : (pres.factorGananciaVenta != null && pres.factorGananciaVenta! > 0
                ? pres.precioVentaFinal / pres.factorGananciaVenta!
                : null);

      final pool =
          _fullProduct?.stockCompartido ?? widget.product.sharedStockPool;

      _currentSelection = MatchedProduct(
        productId: _currentSelection.productId,
        presentationId: pres.id!,
        fullName: fullNameBuilder,
        productName: _fullProduct!.nombre,
        specificName: pres.nombreEspecifico,
        brand: _fullProduct!.marcaNombre ?? _currentSelection.brand,
        price: pres.precioVentaFinal,
        offerPrice: newOffer,
        stock:
            pres.stockActual ~/
            (pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1),
        imageUrl: pres.imagenUrl ?? _fullProduct!.imagenUrl,
        unit: pres.unidadVenta ?? "Unidad",
        conversionFactor: pres.unidadesPorVenta,
        cost: calculatedCost,
        usaStockCompartido: pres.usaStockCompartido,
        sharedStockPool: pool,
      );

      _systemPrice = _currentSelection.price;

      // 3. Restaurar borrador previo o inicializar nueva variante
      if (_variantDrafts.containsKey(pres.id!)) {
        final draft = _variantDrafts[pres.id!]!;
        _qtyCtrl.text = draft.quantity.toString();
        _isDiscountActive = draft.isDiscountActive;
        _isCustomPrice = draft.isCustomPrice;
        _priceCtrl.text = draft.price.toStringAsFixed(2);
        _discountCtrl.text = draft.discountInput;
        _currentCustomName = draft.customName;
      } else {
        int initialQty = 1;
        _qtyCtrl.text = initialQty.toString();
        _currentCustomName = null;

        if (_currentSelection.hasOffer) {
          _isDiscountActive = true;
          _isCustomPrice = false;
          _priceCtrl.text = _currentSelection.effectivePrice.toStringAsFixed(2);
          double disc = _systemPrice - _currentSelection.effectivePrice;
          _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
        } else {
          _isDiscountActive = false;
          _isCustomPrice = false;
          _priceCtrl.text = _systemPrice.toStringAsFixed(2);
          _discountCtrl.text = "";
        }

        _variantDrafts[pres.id!] = VariantDetailState(
          presentationId: pres.id!,
          quantity: initialQty,
          isDiscountActive: _isDiscountActive,
          price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
          discountInput: _discountCtrl.text,
          isCustomPrice: _isCustomPrice,
          customName: _currentCustomName,
        );
      }

      int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      final isClient = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).isCommunityClient;
      if (isClient &&
          currentQty > _currentSelection.stock &&
          _currentSelection.stock > 0) {
        _qtyCtrl.text = _currentSelection.stock.toString();
      }
    });
  }

  void _handleDiscountToggle(bool isEnabled) {
    setState(() {
      _isDiscountActive = isEnabled;
      if (!isEnabled) {
        // 🔥 DESACTIVACIÓN REAL: Se cobra estrictamente el Precio Base Regular
        _isCustomPrice = false;
        _priceCtrl.text = _systemPrice.toStringAsFixed(2);
        _discountCtrl.clear();
      } else {
        // Activación: Si el catálogo tiene oferta, se propone inicialmente dicha oferta
        if (_currentSelection.hasOffer) {
          _isCustomPrice = false;
          _priceCtrl.text = _currentSelection.effectivePrice.toStringAsFixed(2);
          final disc = _systemPrice - _currentSelection.effectivePrice;
          _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
        } else {
          _isCustomPrice = true;
          _priceCtrl.text = _systemPrice.toStringAsFixed(2);
          _discountCtrl.clear();
        }
      }
    });
    if (isEnabled) {
      Future.microtask(() {
        if (mounted) _discountFocusNode.requestFocus();
      });
    }
  }

  void _confirm() {
    int finalQty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (finalQty <= 0) {
      CustomSnackBar.show(
        context,
        message: "La cantidad debe ser mayor a 0.",
        isError: true,
      );
      return;
    }
    double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;

    double? overridePrice;
    if (!_isDiscountActive) {
      // 🔥 Si la variante tenía oferta en BD pero el usuario apagó el switch,
      // guardamos explícitamente _systemPrice como override para anular la oferta en esta operación
      overridePrice = _currentSelection.hasOffer ? _systemPrice : null;
    } else {
      overridePrice = finalPrice;
    }

    String finalName = _currentCustomName ?? "";
    widget.onConfirm(
      _currentSelection,
      finalQty,
      overridePrice,
      finalName.isNotEmpty ? finalName : null,
    );
    Navigator.of(context).pop();

    String message = "";
    if (widget.isNewAddition) {
      message = "Producto agregado a la lista.";
    } else {
      if (finalQty != widget.initialQty) {
        message = "Cantidad actualizada en la lista.";
      } else if (_isDiscountActive) {
        message = "Descuento/Precio modificado correctamente.";
      } else {
        message = "Cambios guardados.";
      }
    }

    CustomSnackBar.show(
      context,
      message: message,
      isError: false,
      icon: Icons.check_circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme;

    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // 🔥 Ya hemos asegurado que la marca llegue como string, la mostramos directamente
    String brandName = _currentSelection.brand ?? "";
    final String bStr = (brandName.isNotEmpty && brandName != "null")
        ? brandName.trim().toUpperCase()
        : "";
    final String cStr =
        (widget.categoryName != null &&
            widget.categoryName!.isNotEmpty &&
            widget.categoryName != "null")
        ? widget.categoryName!.trim().toUpperCase()
        : "";
    String brandCategoryLabel = "";
    if (bStr.isNotEmpty && cStr.isNotEmpty && !bStr.contains(cStr)) {
      brandCategoryLabel = "$bStr · $cStr";
    } else if (bStr.isNotEmpty) {
      brandCategoryLabel = bStr;
    } else if (cStr.isNotEmpty) {
      brandCategoryLabel = cStr;
    }

    int currentQty = int.tryParse(_qtyCtrl.text) ?? 0;
    double currentPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    double subtotal = currentPrice * currentQty;
    double totalSavings = (_systemPrice - currentPrice) * currentQty;

    final effectiveStock = _currentSelection.effectiveVendibleStock;
    bool isStockEmpty = effectiveStock <= 0;
    bool exceedsStock = currentQty > effectiveStock && !isStockEmpty;

    String originalName = widget.product.fullName.trim();
    bool hasCustomName =
        widget.initialCustomName != null &&
        widget.initialCustomName!.isNotEmpty;

    // Lógica refinada (2 Capas: Cambio de usuario o Cambio de Inventario)
    bool isVariantChanged =
        _currentSelection.presentationId != widget.product.presentationId;
    bool isInventoryChanged = false;

    if (_fullProduct != null && !isVariantChanged) {
      try {
        final pres = _fullProduct!.presentaciones.firstWhere(
          (p) => p.id == _currentSelection.presentationId,
        );

        String cleanProductName = _cleanName(_fullProduct!.nombre);
        String cleanSpecificName = _cleanName(pres.nombreEspecifico ?? "");
        String liveFullName = cleanProductName;
        if (cleanSpecificName.isNotEmpty &&
            !cleanProductName.toLowerCase().contains(
              cleanSpecificName.toLowerCase(),
            )) {
          liveFullName += " $cleanSpecificName";
        }

        String liveBrand = _fullProduct!.marcaNombre ?? "";
        String originalBrand = widget.product.brand ?? "";
        String liveUnit = pres.unidadVenta ?? "Unidad";
        String originalUnit = widget.product.unit;
        int liveFactor = pres.unidadesPorVenta;
        int originalFactor = widget.product.conversionFactor;

        if (liveFullName.toLowerCase() != originalName.toLowerCase() ||
            liveBrand.toLowerCase() != originalBrand.toLowerCase() ||
            liveUnit.toLowerCase() != originalUnit.toLowerCase() ||
            liveFactor != originalFactor) {
          isInventoryChanged = true;
        }
      } catch (e) {
        // Si no se encuentra la presentación en vivo, asumimos que hubo un cambio mayor (ej. borrada)
        isInventoryChanged = true;
      }
    }

    bool isNameChanged =
        widget.isEditingSavedQuote &&
        !widget.isNewAddition &&
        originalName.isNotEmpty &&
        !originalName.toLowerCase().contains("nuevo ítem") &&
        !hasCustomName &&
        (isVariantChanged || isInventoryChanged);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: true,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isNameChanged)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Icon(
                        Icons.history,
                        size: 16,
                        color: isDark ? Colors.orange[300] : Colors.orange[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Cotizado originalmente como:\n$originalName",
                        style: textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.orange[300]
                              : Colors.orange[800],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            if (widget.isBundleOutdated)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.deepPurple.withValues(alpha: 0.15)
                      : Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sync_problem,
                          size: 20,
                          color: isDark
                              ? Colors.deepPurple[300]
                              : Colors.deepPurple[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Oferta desactualizada",
                            style: textTheme.titleSmall?.copyWith(
                              color: isDark
                                  ? Colors.deepPurple[300]
                                  : Colors.deepPurple[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "La composición, nombre o precio de esta oferta ha cambiado en el catálogo.",
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.deepPurple[200]
                            : Colors.deepPurple[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: const Text("Sincronizar Oferta"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.deepPurple[300]
                              : Colors.deepPurple[700],
                          side: BorderSide(
                            color: isDark
                                ? Colors.deepPurple.withValues(alpha: 0.5)
                                : Colors.deepPurple.shade300,
                          ),
                        ),
                        onPressed: _isSyncing || widget.onSyncBundle == null
                            ? null
                            : () async {
                                setState(() => _isSyncing = true);
                                final success = await widget.onSyncBundle!();
                                if (mounted) {
                                  setState(() => _isSyncing = false);
                                }
                                if (success && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),

            // 1. INFO SUPERIOR
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_currentSelection.imageUrl != null &&
                        _currentSelection.imageUrl!.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageViewer(
                            imageUrl: _currentSelection.imageUrl!,
                            tag:
                                "modal_cot_${_currentSelection.presentationId}",
                          ),
                        ),
                      );
                    }
                  },
                  child: Hero(
                    tag: "modal_cot_${_currentSelection.presentationId}",
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: UniversalImage(
                              path: _currentSelection.imageUrl,
                              productName: _currentSelection.productName,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (_currentSelection.imageUrl != null &&
                            _currentSelection.imageUrl!.isNotEmpty) ...[
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                          const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 30,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              brandCategoryLabel.isNotEmpty
                                  ? brandCategoryLabel
                                  : (brandName.isNotEmpty && brandName != "null"
                                        ? brandName.toUpperCase()
                                        : ""),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.indigo[300]
                                    : Colors.indigo[800],
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 22),
                            tooltip: "Cerrar",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      Text(
                        "${_currentSelection.productName} ",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (_currentSelection.specificName != null &&
                          _currentSelection.specificName!.isNotEmpty &&
                          _currentSelection.specificName != "Paquete")
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _currentSelection.specificName!,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      if (_currentSelection.description != null &&
                          _currentSelection.description!.isNotEmpty &&
                          _currentSelection.description !=
                              _currentSelection.specificName)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _currentSelection.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const SizedBox(height: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Se vende por: ${_currentSelection.unit} (x${_currentSelection.conversionFactor})",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            isStockEmpty
                                ? "Agotado (0)"
                                : (_currentSelection.usaStockCompartido
                                      ? "Stock vendible: ${_currentSelection.effectiveVendibleStock} ${_currentSelection.unit}"
                                      : "Stock disponible: ${_currentSelection.stock} ${_currentSelection.unit}"),
                            style: textTheme.bodySmall?.copyWith(
                              color: isStockEmpty
                                  ? (isDark ? Colors.red[400] : Colors.red)
                                  : (isDark ? Colors.green[400] : Colors.green),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final invProv = Provider.of<InventoryProvider>(
                                context,
                                listen: false,
                              );
                              ProductPresentation? targetPres;
                              if (_fullProduct != null) {
                                targetPres = _fullProduct!.presentaciones
                                    .where(
                                      (p) =>
                                          p.id ==
                                          _currentSelection.presentationId,
                                    )
                                    .firstOrNull;
                              }
                              if (targetPres == null) {
                                try {
                                  final freshProd = await invProv
                                      .getFullProductWithFallback(
                                        _currentSelection.productId,
                                      );
                                  targetPres = freshProd?.presentaciones
                                      .where(
                                        (p) =>
                                            p.id ==
                                            _currentSelection.presentationId,
                                      )
                                      .firstOrNull;
                                } catch (_) {}
                              }
                              if (!context.mounted) return;
                              if (targetPres != null) {
                                await StockUpdateModal.show(
                                  context: context,
                                  presentation: targetPres,
                                  provider: invProv,
                                  isDark: isDark,
                                );
                                if (!context.mounted) return;
                                await _loadVariants();
                                ProductPresentation? updatedPres;
                                if (_fullProduct != null) {
                                  updatedPres = _fullProduct!.presentaciones
                                      .where(
                                        (p) =>
                                            p.id ==
                                            _currentSelection.presentationId,
                                      )
                                      .firstOrNull;
                                }
                                if (updatedPres == null) {
                                  try {
                                    final freshProd = await invProv
                                        .getFullProductWithFallback(
                                          _currentSelection.productId,
                                        );
                                    updatedPres = freshProd?.presentaciones
                                        .where(
                                          (p) =>
                                              p.id ==
                                              _currentSelection.presentationId,
                                        )
                                        .firstOrNull;
                                  } catch (_) {}
                                }
                                final finalPres = updatedPres ?? targetPres;
                                final factor = finalPres.unidadesPorVenta > 0
                                    ? finalPres.unidadesPorVenta
                                    : 1;
                                final newOfferPrice = finalPres.hasOffer
                                    ? finalPres.effectivePrice
                                    : null;
                                final double presCost =
                                    finalPres.costoPresentacionFinal;
                                final double? calculatedCost = presCost > 0
                                    ? presCost
                                    : (finalPres.factorGananciaVenta != null &&
                                              finalPres.factorGananciaVenta! > 0
                                          ? finalPres.precioVentaFinal /
                                                finalPres.factorGananciaVenta!
                                          : null);

                                setState(() {
                                  _currentSelection = _currentSelection
                                      .copyWith(
                                        price: finalPres.precioVentaFinal,
                                        offerPrice: newOfferPrice,
                                        clearOfferPrice: !finalPres.hasOffer,
                                        stock: finalPres.stockActual ~/ factor,
                                        cost: calculatedCost,
                                        cupoMaximoVariante:
                                            finalPres.cupoMaximoVariante,
                                        clearCupo:
                                            finalPres.cupoMaximoVariante ==
                                            null,
                                      );
                                  int currentQty =
                                      int.tryParse(_qtyCtrl.text) ?? 1;
                                  final newMaxStock =
                                      finalPres.unidadesVendiblesDisponibles;
                                  if (currentQty > newMaxStock &&
                                      newMaxStock > 0) {
                                    _qtyCtrl.text = newMaxStock.toString();
                                  }
                                  _variantDrafts[_currentSelection
                                      .presentationId] = VariantDetailState(
                                    presentationId:
                                        _currentSelection.presentationId,
                                    quantity: int.tryParse(_qtyCtrl.text) ?? 1,
                                    isDiscountActive: _isDiscountActive,
                                    price:
                                        double.tryParse(_priceCtrl.text) ??
                                        _systemPrice,
                                    discountInput: _discountCtrl.text,
                                    isCustomPrice: _isCustomPrice,
                                    customName: _currentCustomName,
                                  );
                                });
                                widget.onStockUpdated?.call(
                                  _currentSelection.presentationId,
                                  finalPres.stockActual,
                                );
                                if (context.mounted) {
                                  final smartProv =
                                      Provider.of<SmartQuotationProvider>(
                                        context,
                                        listen: false,
                                      );
                                  smartProv.syncItemPriceAndStock(
                                    _currentSelection.presentationId,
                                    newStock: finalPres.stockActual ~/ factor,
                                    newPrice: finalPres.precioVentaFinal,
                                    newOfferPrice: newOfferPrice,
                                    clearOffer: !finalPres.hasOffer,
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 14,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[700],
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    "Ajustar",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. VARIANTES CON CHIPS DESCRIPTIVOS (Fase 2.2)
            if (_isLoadingVariants)
              const Center(child: LinearProgressIndicator())
            else if (_fullProduct != null &&
                _fullProduct!.presentaciones.length > 1) ...[
              InkWell(
                onTap: () => setState(
                  () => _showVariantSelector = !_showVariantSelector,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.dashboard_customize_outlined,
                              size: 18,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[800],
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "Seleccionar Variante / Presentación",
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.blue.withValues(alpha: 0.25)
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${_fullProduct!.presentaciones.length}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            _showVariantSelector ? "Ocultar" : "Ver otras",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[800],
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _showVariantSelector
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (_showVariantSelector) ...[
                if (_currentSelection.usaStockCompartido) ...[
                  Builder(
                    builder: (ctx) {
                      final pool = _fullProduct!.stockCompartido > 0
                          ? _fullProduct!.stockCompartido
                          : widget.product.sharedStockPool;
                      final factor = _currentSelection.conversionFactor > 0
                          ? _currentSelection.conversionFactor
                          : 1;
                      final maxPhysical = pool ~/ factor;
                      final cupo = _currentSelection.cupoMaximoVariante;
                      final cupoStr = cupo != null
                          ? " · Cupo: $cupo disp."
                          : "";
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.blue.shade700
                                : const Color(0xFF93C5FD),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.hub_rounded,
                              size: 16,
                              color: isDark
                                  ? Colors.blue[300]
                                  : const Color(0xFF1E40AF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Pool Base: $pool und. (= máx. $maxPhysical ${_currentSelection.unit}$cupoStr)",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "📦 Stock Propio disponible: ${_currentSelection.stock} ${_currentSelection.unit}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[200]
                                  : Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.black, Colors.black, Colors.transparent],
                      stops: [0.0, 0.94, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _fullProduct!.presentaciones.map((p) {
                        final isSelected =
                            p.id == _currentSelection.presentationId;
                        final specName =
                            (p.nombreEspecifico != null &&
                                p.nombreEspecifico!.trim().isNotEmpty)
                            ? p.nombreEspecifico!.trim()
                            : (p.esDefault
                                  ? "Principal"
                                  : (p.unidadVenta ?? "Variante"));
                        final factorStr = p.unidadesPorVenta > 1
                            ? " (x${p.unidadesPorVenta})"
                            : "";

                        int dispStock;
                        if (p.usaStockCompartido) {
                          final pool =
                              _fullProduct?.stockCompartido ??
                              widget.product.sharedStockPool;
                          final factor = p.unidadesPorVenta > 0
                              ? p.unidadesPorVenta
                              : 1;
                          final equiv = pool ~/ factor;
                          final cupo = p.cupoMaximoVariante;
                          dispStock = cupo != null
                              ? equiv.clamp(0, cupo)
                              : equiv;
                        } else {
                          dispStock = p.unidadesVendiblesDisponibles;
                        }
                        final bool isOutOfStock = dispStock <= 0;

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      specName,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.bold,
                                        color: isSelected
                                            ? (isDark
                                                  ? Colors.blue[200]
                                                  : Colors.blue[900])
                                            : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOutOfStock
                                            ? Colors.red
                                            : (dispStock < 10
                                                  ? Colors.orange
                                                  : Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${p.unidadVenta ?? 'Und'}$factorStr · ${AppCurrency.format(p.precioVentaFinal)} · ${isOutOfStock ? 'Agotado' : '$dispStock disp.'}",
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                    color: isSelected
                                        ? (isDark
                                              ? Colors.blue[100]
                                              : Colors.blue[800])
                                        : (isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600]),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (v) => v ? _updateVariant(p) : null,
                            selectedColor: isDark
                                ? Colors.blue.withValues(alpha: 0.3)
                                : Colors.blue[100],
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? (isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[900])
                                  : textColor,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // 3. SECCIÓN DE DESCUENTO (OCULTA PARA CLIENTES)
            if (!isClient)
              ManualPriceModifier(
                isManualPrice: _isDiscountActive,
                isCustomPrice: _isCustomPrice,
                systemPrice: _systemPrice,
                discountCtrl: _discountCtrl,
                priceCtrl: _priceCtrl,
                discountFocusNode: _discountFocusNode,
                catalogHasOffer: _currentSelection.hasOffer,
                catalogOfferPrice: _currentSelection.offerPrice,
                catalogDiscountPercent:
                    _currentSelection.discountPercentRounded,
                onToggle: _handleDiscountToggle,
                onDiscountChanged: _onDiscountChanged,
                onPriceChanged: _onPriceChanged,
                onRestoreCatalogOffer: _restoreCatalogOffer,
                onEditCatalogPrice: () async {
                  final invProv = Provider.of<InventoryProvider>(
                    context,
                    listen: false,
                  );
                  ProductPresentation? targetPres;
                  if (_fullProduct != null) {
                    targetPres = _fullProduct!.presentaciones
                        .where((p) => p.id == _currentSelection.presentationId)
                        .firstOrNull;
                  }
                  if (targetPres == null) {
                    try {
                      final freshProd = await invProv
                          .getFullProductWithFallback(
                            _currentSelection.productId,
                          );
                      targetPres = freshProd?.presentaciones
                          .where(
                            (p) => p.id == _currentSelection.presentationId,
                          )
                          .firstOrNull;
                    } catch (_) {}
                  }
                  if (!context.mounted) return;
                  if (targetPres != null) {
                    final didUpdate = await PriceUpdateModal.show(
                      context: context,
                      presentation: targetPres,
                      provider: invProv,
                      isDark: isDark,
                    );
                    if (!context.mounted) return;
                    if (didUpdate == true) {
                      await _loadVariants();
                      if (_fullProduct != null) {
                        final exactPres = _fullProduct!.presentaciones
                            .where(
                              (p) => p.id == _currentSelection.presentationId,
                            )
                            .firstOrNull;
                        if (exactPres != null) {
                          final factor = exactPres.unidadesPorVenta > 0
                              ? exactPres.unidadesPorVenta
                              : 1;
                          final newOffer = exactPres.hasOffer
                              ? exactPres.effectivePrice
                              : null;
                          final double presCost =
                              exactPres.costoPresentacionFinal;
                          final double? calculatedCost = presCost > 0
                              ? presCost
                              : (exactPres.factorGananciaVenta != null &&
                                        exactPres.factorGananciaVenta! > 0
                                    ? exactPres.precioVentaFinal /
                                          exactPres.factorGananciaVenta!
                                    : null);

                          setState(() {
                            _systemPrice = exactPres.precioVentaFinal;
                            _currentSelection = _currentSelection.copyWith(
                              price: exactPres.precioVentaFinal,
                              offerPrice: newOffer,
                              clearOfferPrice: !exactPres.hasOffer,
                              stock: exactPres.stockActual ~/ factor,
                              cost: calculatedCost,
                            );

                            // 🛡️ Blindaje 3: Si se editó en el catálogo y guardó en BD, NO bloquear con _isCustomPrice.
                            // Restablecer siempre _isCustomPrice = false y sincronizar con los valores del catálogo recién guardados.
                            _isCustomPrice = false;
                            if (exactPres.hasOffer) {
                              _isDiscountActive = true;
                              _priceCtrl.text = exactPres.effectivePrice
                                  .toStringAsFixed(2);
                              final disc =
                                  _systemPrice - exactPres.effectivePrice;
                              _discountCtrl.text = disc > 0
                                  ? disc.toStringAsFixed(2)
                                  : "";
                            } else {
                              _isDiscountActive = false;
                              _priceCtrl.text = exactPres.precioVentaFinal
                                  .toStringAsFixed(2);
                              _discountCtrl.clear();
                            }

                            // Sincronizar el borrador de la variante inmediatamente
                            _variantDrafts[_currentSelection
                                .presentationId] = VariantDetailState(
                              presentationId: _currentSelection.presentationId,
                              quantity: int.tryParse(_qtyCtrl.text) ?? 1,
                              isDiscountActive: _isDiscountActive,
                              price:
                                  double.tryParse(_priceCtrl.text) ??
                                  _systemPrice,
                              discountInput: _discountCtrl.text,
                              isCustomPrice: _isCustomPrice,
                              customName: _currentCustomName,
                            );
                          });

                          // Notificar de inmediato a Cotización Manual (0ms)
                          widget.onCatalogUpdated?.call(
                            exactPres.id!,
                            exactPres.stockActual,
                            exactPres.precioVentaFinal,
                            exactPres.hasOffer
                                ? exactPres.effectivePrice
                                : null,
                            calculatedCost,
                          );

                          if (context.mounted) {
                            final smartProv =
                                Provider.of<SmartQuotationProvider>(
                                  context,
                                  listen: false,
                                );
                            smartProv.syncItemPriceAndStock(
                              exactPres.id!,
                              newPrice: exactPres.precioVentaFinal,
                              newOfferPrice: exactPres.hasOffer
                                  ? exactPres.effectivePrice
                                  : null,
                              clearOffer: !exactPres.hasOffer,
                              newStock: exactPres.stockActual ~/ factor,
                            );
                            final quickProv = Provider.of<QuickSaleProvider>(
                              context,
                              listen: false,
                            );
                            quickProv.syncItemPriceAndStock(
                              exactPres.id!,
                              newPrice: exactPres.precioVentaFinal,
                              newOfferPrice: exactPres.hasOffer
                                  ? exactPres.effectivePrice
                                  : null,
                              clearOffer: !exactPres.hasOffer,
                              newStock: exactPres.stockActual ~/ factor,
                            );
                          }
                        }
                      }
                    }
                  }
                },
                isDark: isDark,
                currency: currency,
              ),
            if (!isClient) const SizedBox(height: 14),

            // 4. CANTIDAD Y TOTALES
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cantidad",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 55,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14141C) : Colors.white,
                        border: Border.all(
                          color: (exceedsStock || isStockEmpty)
                              ? (isDark ? Colors.orange[400]! : Colors.orange)
                              : (isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.remove,
                              color: isDark ? Colors.red[300] : Colors.red,
                              size: 24,
                            ),
                            onPressed: () => _qtyAction(-1, isClient),
                          ),
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: _qtyCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (v) {
                                // 🔥 BLOQUEO DE STOCK AL CLIENTE AL ESCRIBIR
                                if (isClient) {
                                  int parsed = int.tryParse(v) ?? 1;
                                  final maxLim =
                                      _currentSelection.effectiveVendibleStock;
                                  if (parsed > maxLim) {
                                    _qtyCtrl.text = maxLim.toString();
                                    CustomSnackBar.show(
                                      context,
                                      message: "Límite de stock alcanzado",
                                      isError: true,
                                    );
                                  }
                                }
                                setState(() {});
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add,
                              color: isDark ? Colors.green[400] : Colors.green,
                              size: 24,
                            ),
                            onPressed: () => _qtyAction(1, isClient),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (totalSavings > 0)
                        Text(
                          "Ahorro: ${AppCurrency.format(totalSavings)}",
                          style: TextStyle(
                            color: isDark ? Colors.green[300] : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      Text(
                        "Subtotal",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          AppCurrency.format(subtotal),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.blue[300] : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isStockEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "⚠️ Producto agotado. Requiere revisión para venderse.",
                  style: textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.red[300] : Colors.red[700],
                  ),
                ),
              )
            else if (exceedsStock && !isClient)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "⚠️ Supera el stock actual de ${_currentSelection.effectiveVendibleStock}.",
                  style: textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.orange[400] : Colors.orange[800],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 5. CONFIRMAR
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed:
                    (currentQty > 0 &&
                        subtotal >= 0 &&
                        (!isClient || !exceedsStock))
                    ? _confirm
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.isNewAddition
                      ? "AGREGAR A COTIZACIÓN"
                      : "GUARDAR CAMBIOS",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
