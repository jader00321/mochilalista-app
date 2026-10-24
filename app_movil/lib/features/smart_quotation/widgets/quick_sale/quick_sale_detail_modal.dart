import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_price_modifier.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';

class QuickSaleDetailModal extends StatefulWidget {
  final MatchedProduct product;
  final int initialQty;
  final double? initialOverridePrice;
  final Function(int presentationId, int newStockBase)? onStockUpdated;
  final Function(int oldPresentationId, MatchedProduct product, int qty, double? overridePrice) onConfirm;

  const QuickSaleDetailModal({
    super.key,
    required this.product,
    required this.initialQty,
    this.initialOverridePrice,
    this.onStockUpdated,
    required this.onConfirm,
  });

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required MatchedProduct product,
    required int initialQty,
    double? initialOverridePrice,
    Function(int presentationId, int newStockBase)? onStockUpdated,
    required Function(int oldPresentationId, MatchedProduct product, int qty, double? overridePrice) onConfirm,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => QuickSaleDetailModal(
        product: product,
        initialQty: initialQty,
        initialOverridePrice: initialOverridePrice,
        onStockUpdated: onStockUpdated,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<QuickSaleDetailModal> createState() => _QuickSaleDetailModalState();
}

class _QuickSaleDetailModalState extends State<QuickSaleDetailModal> {
  Product? _fullProduct;
  bool _isLoadingVariants = true;
  
  late MatchedProduct _currentSelection;
  late double _systemPrice; 
  
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _discountFocusNode = FocusNode();

  bool _isDiscountActive = false;
  bool _isCustomPrice = false;
  bool _isSyncing = false;

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
    final bool isOverrideEqualBase = widget.initialOverridePrice != null &&
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
      _discountCtrl.text = diffFromBase > 0 ? diffFromBase.toStringAsFixed(2) : "";
      final double diffFromCatalog = _currentSelection.hasOffer
          ? (effectivePrice - _currentSelection.effectivePrice).abs()
          : 0.0;
      _isCustomPrice = !_currentSelection.hasOffer || diffFromCatalog >= 0.01;
    } else if (_currentSelection.hasOffer) {
      _isDiscountActive = true;
      _isCustomPrice = false;
      effectivePrice = _currentSelection.effectivePrice;
      final double diffFromBase = _systemPrice - effectivePrice;
      _discountCtrl.text = diffFromBase > 0 ? diffFromBase.toStringAsFixed(2) : "";
    } else {
      _isDiscountActive = false;
      _isCustomPrice = false;
      effectivePrice = _systemPrice;
      _discountCtrl.text = "";
    }

    _priceCtrl.text = effectivePrice.toStringAsFixed(2);

    _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
      presentationId: _currentSelection.presentationId,
      quantity: widget.initialQty,
      isDiscountActive: _isDiscountActive,
      price: effectivePrice,
      discountInput: _discountCtrl.text,
      isCustomPrice: _isCustomPrice,
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
      // 🛡️ Carga exhaustiva desde base de datos SQLite para evitar filtros o arrays parciales en memoria
      final prod = await invProv.fetchProductById(_currentSelection.productId);
      if (mounted) setState(() { _fullProduct = prod; _isLoadingVariants = false; });
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
      _isCustomPrice = (newPrice - _currentSelection.effectivePrice).abs() >= 0.01;
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
        final disc = (_systemPrice - _currentSelection.offerPrice!).clamp(0.0, double.infinity);
        _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";

        _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
          presentationId: _currentSelection.presentationId,
          quantity: int.tryParse(_qtyCtrl.text) ?? 1,
          isDiscountActive: true,
          price: _currentSelection.offerPrice!,
          discountInput: _discountCtrl.text,
          isCustomPrice: false,
          customName: null,
        );
      });
    }
  }

  void _qtyAction(int delta) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newQty = current + delta;
    if (newQty > 0) {
      _qtyCtrl.text = newQty.toString();
      setState(() {});
    }
  }

  String _cleanName(String rawName) {
    return rawName.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _formatPresentationChipLabel(ProductPresentation p) {
    final hasSpecific = p.nombreEspecifico != null && p.nombreEspecifico!.trim().isNotEmpty;
    final unit = p.unidadVenta ?? "Unidad";
    final factor = p.unidadesPorVenta > 1 ? " (x${p.unidadesPorVenta})" : "";
    
    if (hasSpecific) {
      return "${p.nombreEspecifico!.trim()} · $unit$factor";
    }
    return "$unit$factor";
  }

  void _updateVariant(ProductPresentation pres) {
    setState(() {
      // 1. Guardar estado de variante saliente en mapa de borradores
      _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
        presentationId: _currentSelection.presentationId,
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        isDiscountActive: _isDiscountActive,
        price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
        discountInput: _discountCtrl.text,
        isCustomPrice: _isCustomPrice,
      );

      // 2. Construir MatchedProduct entrante con su costo y oferta exactos
      String cleanProductName = _cleanName(_fullProduct!.nombre);
      String cleanSpecificName = _cleanName(pres.nombreEspecifico ?? "");
      String fullNameBuilder = cleanProductName;
      if (cleanSpecificName.isNotEmpty && !cleanProductName.toLowerCase().contains(cleanSpecificName.toLowerCase())) {
        fullNameBuilder += " $cleanSpecificName";
      }

      final newOffer = pres.hasOffer ? pres.effectivePrice : null;
      final double presCost = pres.costoPresentacionFinal;
      final double? calculatedCost = presCost > 0
          ? presCost
          : (pres.factorGananciaVenta != null && pres.factorGananciaVenta! > 0
              ? pres.precioVentaFinal / pres.factorGananciaVenta!
              : null);

      _currentSelection = MatchedProduct(
        productId: _currentSelection.productId,
        presentationId: pres.id!,
        fullName: fullNameBuilder,
        productName: _fullProduct!.nombre,
        specificName: pres.nombreEspecifico,
        brand: _fullProduct!.marcaNombre ?? _currentSelection.brand,
        price: pres.precioVentaFinal, 
        offerPrice: newOffer,
        stock: pres.stockActual ~/ (pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1),
        imageUrl: pres.imagenUrl ?? _fullProduct!.imagenUrl,
        unit: pres.unidadVenta ?? "Unidad", 
        conversionFactor: pres.unidadesPorVenta, 
        cost: calculatedCost,
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
      } else {
        int initialQty = 1;
        _qtyCtrl.text = initialQty.toString();

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
        );
      }
      
      int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      if (currentQty > _currentSelection.stock && _currentSelection.stock > 0) {
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
      CustomSnackBar.show(context, message: "La cantidad debe ser mayor a 0.", isError: true);
      return;
    }
    double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    
    double? overridePrice;
    if (!_isDiscountActive) {
      // Si la variante tenía oferta en BD pero el usuario apagó el switch,
      // guardamos explícitamente _systemPrice como override para anular la oferta en esta operación
      overridePrice = _currentSelection.hasOffer ? _systemPrice : null;
    } else {
      overridePrice = finalPrice;
    }
    
    widget.onConfirm(widget.product.presentationId, _currentSelection, finalQty, overridePrice);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final invProv = Provider.of<InventoryProvider>(context, listen: false);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    String brandName = "";
    if (_currentSelection.brand != null && _currentSelection.brand != "null") {
      final int? bId = int.tryParse(_currentSelection.brand!);
      if (bId != null) {
        brandName = invProv.getBrandName(bId);
      } else {
        brandName = _currentSelection.brand!;
      }
    }

    String categoryName = "";
    if (_fullProduct != null && _fullProduct!.categoriaId > 0) {
      categoryName = invProv.getCategoryName(_fullProduct!.categoriaId);
    }

    final String bStr = brandName.trim();
    final String cStr = categoryName.trim();
    String brandCategoryLabel = "";
    if (bStr.isNotEmpty && cStr.isNotEmpty && !bStr.toUpperCase().contains(cStr.toUpperCase())) {
      brandCategoryLabel = "${bStr.toUpperCase()} · ${cStr.toUpperCase()}";
    } else if (bStr.isNotEmpty) {
      brandCategoryLabel = bStr.toUpperCase();
    } else if (cStr.isNotEmpty) {
      brandCategoryLabel = cStr.toUpperCase();
    }

    int currentQty = int.tryParse(_qtyCtrl.text) ?? 0;
    double currentPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    double subtotal = currentPrice * currentQty;
    double totalSavings = (_systemPrice - currentPrice) * currentQty;
    
    bool isStockEmpty = _currentSelection.stock <= 0;
    bool exceedsStock = currentQty > _currentSelection.stock && !_currentSelection.stock.isNegative;
    

    final bool hasRealImage = _currentSelection.imageUrl != null &&
        _currentSelection.imageUrl!.isNotEmpty &&
        _currentSelection.imageUrl != 'null';

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: false,
      bottomAction: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (currentQty > 0 && subtotal >= 0 && !exceedsStock) ? _confirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800], 
            foregroundColor: Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("GUARDAR CAMBIOS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        ),
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // 1. INFO SUPERIOR (Con botón ✕ integrado en la cabecera)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: hasRealImage
                        ? () => showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: UniversalImage(
                                  path: _currentSelection.imageUrl,
                                  productName: _currentSelection.productName,
                                  categoryName: brandCategoryLabel.isNotEmpty ? brandCategoryLabel : brandName,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )
                        : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white,
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: UniversalImage(
                              path: _currentSelection.imageUrl,
                              productName: _currentSelection.productName,
                              categoryName: brandCategoryLabel.isNotEmpty ? brandCategoryLabel : brandName,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (hasRealImage) ...[
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                          const Icon(Icons.zoom_in, color: Colors.white, size: 28),
                        ],
                      ],
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
                                brandCategoryLabel.isNotEmpty ? brandCategoryLabel : brandName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.indigo[300] : Colors.indigo[700],
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
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? Colors.transparent : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            "Se vende por: ${_currentSelection.unit} (x${_currentSelection.conversionFactor})",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isStockEmpty
                                    ? "Agotado"
                                    : "Stock disponible: ${_currentSelection.stock} ${_currentSelection.unit}",
                                style: TextStyle(
                                  color: isStockEmpty
                                      ? (isDark ? Colors.red[300] : Colors.red)
                                      : (isDark
                                          ? Colors.green[400]
                                          : Colors.green),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final invProv = Provider.of<InventoryProvider>(
                                  context,
                                  listen: false,
                                );
                                ProductPresentation? currentPres;
                                if (_fullProduct != null) {
                                  currentPres = _fullProduct!.presentaciones
                                      .where(
                                        (p) =>
                                            p.id ==
                                            _currentSelection.presentationId,
                                      )
                                      .firstOrNull;
                                }
                                if (currentPres == null) {
                                  try {
                                    final fresh = await invProv.getFullProductWithFallback(_currentSelection.productId);
                                    currentPres = fresh?.presentaciones
                                        .where((p) => p.id == _currentSelection.presentationId)
                                        .firstOrNull;
                                  } catch (_) {}
                                }
                                if (!context.mounted) return;
                                if (currentPres != null) {
                                  await StockUpdateModal.show(
                                    context: context,
                                    presentation: currentPres,
                                    provider: invProv,
                                    isDark: isDark,
                                  );
                                  if (!context.mounted) return;
                                  await _loadVariants();
                                  ProductPresentation? updatedPres;
                                  if (_fullProduct != null) {
                                    updatedPres = _fullProduct!.presentaciones.where(
                                      (p) => p.id == _currentSelection.presentationId,
                                    ).firstOrNull;
                                  }
                                  if (updatedPres == null) {
                                    try {
                                      final fresh = await invProv.getFullProductWithFallback(_currentSelection.productId);
                                      updatedPres = fresh?.presentaciones
                                          .where((p) => p.id == _currentSelection.presentationId)
                                          .firstOrNull;
                                    } catch (_) {}
                                  }
                                  updatedPres ??= currentPres;
                                  final factor = updatedPres.unidadesPorVenta > 0 ? updatedPres.unidadesPorVenta : 1;
                                  final newStockInSalesUnits = updatedPres.stockActual ~/ factor;

                                  setState(() {
                                    _currentSelection = _currentSelection.copyWith(stock: newStockInSalesUnits);
                                    int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
                                    if (currentQty > newStockInSalesUnits && newStockInSalesUnits > 0) {
                                      _qtyCtrl.text = newStockInSalesUnits.toString();
                                    }
                                    _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
                                      presentationId: _currentSelection.presentationId,
                                      quantity: int.tryParse(_qtyCtrl.text) ?? 1,
                                      isDiscountActive: _isDiscountActive,
                                      price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
                                      discountInput: _discountCtrl.text,
                                      isCustomPrice: _isCustomPrice,
                                    );
                                  });

                                  widget.onStockUpdated?.call(_currentSelection.presentationId, updatedPres.stockActual);
                                  if (context.mounted) {
                                    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
                                    quickProv.syncItemPriceAndStock(
                                      _currentSelection.presentationId,
                                      newStock: newStockInSalesUnits,
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: 15,
                                      color: isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[700],
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      "Ajustar",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.blue[300]
                                            : Colors.blue[700],
                                        fontWeight: FontWeight.bold,
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
                  )
                ],
              ),
              const SizedBox(height: 14),

              // 2. VARIANTES CON FORMATO DESCRIPTIVO
              if (_isLoadingVariants) const Center(child: LinearProgressIndicator())
              else if (_fullProduct != null && _fullProduct!.presentaciones.length > 1) ...[
                Text("Seleccionar Presentación:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _fullProduct!.presentaciones.map((p) {
                      final isSelected = p.id == _currentSelection.presentationId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(_formatPresentationChipLabel(p), style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), 
                          selected: isSelected, 
                          onSelected: (v) => v ? _updateVariant(p) : null, 
                          selectedColor: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue[100],
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                          labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue[900]) : textColor),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. SECCIÓN DE DESCUENTO (UNIFICADA CON ManualPriceModifier)
              ManualPriceModifier(
                isManualPrice: _isDiscountActive,
                isCustomPrice: _isCustomPrice,
                systemPrice: _systemPrice,
                discountCtrl: _discountCtrl,
                priceCtrl: _priceCtrl,
                discountFocusNode: _discountFocusNode,
                catalogHasOffer: _currentSelection.hasOffer,
                catalogOfferPrice: _currentSelection.offerPrice,
                catalogDiscountPercent: _currentSelection.discountPercentRounded,
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
                        .where(
                          (p) => p.id == _currentSelection.presentationId,
                        )
                        .firstOrNull;
                  }
                  if (targetPres == null) {
                    try {
                      final freshProd = await invProv.fetchProductById(_currentSelection.productId);
                      targetPres = freshProd?.presentaciones
                          .where((p) => p.id == _currentSelection.presentationId)
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
                          final factor = exactPres.unidadesPorVenta > 0 ? exactPres.unidadesPorVenta : 1;
                          final newOffer = exactPres.hasOffer ? exactPres.effectivePrice : null;
                          final double presCost = exactPres.costoPresentacionFinal;
                          final double? calculatedCost = presCost > 0
                              ? presCost
                              : (exactPres.factorGananciaVenta != null && exactPres.factorGananciaVenta! > 0
                                  ? exactPres.precioVentaFinal / exactPres.factorGananciaVenta!
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
                              _priceCtrl.text = exactPres.effectivePrice.toStringAsFixed(2);
                              final disc = _systemPrice - exactPres.effectivePrice;
                              _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
                            } else {
                              _isDiscountActive = false;
                              _priceCtrl.text = exactPres.precioVentaFinal.toStringAsFixed(2);
                              _discountCtrl.clear();
                            }

                            // Sincronizar el borrador de la variante inmediatamente
                            _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
                              presentationId: _currentSelection.presentationId,
                              quantity: int.tryParse(_qtyCtrl.text) ?? 1,
                              isDiscountActive: _isDiscountActive,
                              price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
                              discountInput: _discountCtrl.text,
                              isCustomPrice: _isCustomPrice,
                              customName: null,
                            );
                          });

                          // Propagar a 0ms a QuickSaleProvider
                          if (context.mounted) {
                            final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
                            quickProv.syncItemPriceAndStock(
                              exactPres.id!,
                              newPrice: exactPres.precioVentaFinal,
                              newOfferPrice: exactPres.hasOffer ? exactPres.effectivePrice : null,
                              clearOffer: !exactPres.hasOffer,
                              newStock: exactPres.stockActual ~/ factor,
                            );
                          }
                        }
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 16),

              // 4. CANTIDAD Y TOTALES
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Cantidad a llevar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        height: 55,
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.white, border: Border.all(color: exceedsStock ? (isDark ? Colors.red[400]! : Colors.red) : (isDark ? Colors.white24 : Colors.grey.shade300), width: 1.5), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            IconButton(icon: Icon(Icons.remove, color: isDark ? Colors.red[300] : Colors.red, size: 24), onPressed: () => _qtyAction(-1)),
                            SizedBox(
                              width: 50,
                              child: TextField(
                                controller: _qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                onChanged: (v) => setState((){}),
                              ),
                            ),
                            IconButton(icon: Icon(Icons.add, color: isDark ? Colors.green[400] : Colors.green, size: 24), onPressed: () => _qtyAction(1)),
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
                        if (totalSavings > 0) Text("Ahorro: ${currency.format(totalSavings)}", style: TextStyle(color: isDark ? Colors.green[300] : Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("Subtotal", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(currency.format(subtotal), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              if (exceedsStock) Padding(padding: const EdgeInsets.only(top: 10), child: Text("Supera el stock actual de ${_currentSelection.stock}", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
        ),
    );
  }
}