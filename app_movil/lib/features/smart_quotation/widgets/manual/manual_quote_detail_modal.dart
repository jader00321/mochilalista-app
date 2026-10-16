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
  
  final Function(MatchedProduct product, int qty, double? overridePrice, String? customName) onConfirm;

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
    required Function(MatchedProduct product, int qty, double? overridePrice, String? customName) onConfirm,
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
  
  late MatchedProduct _currentSelection;
  late double _systemPrice;
  
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  bool _isManualPrice = false;
  bool _isSyncing = false;
  String? _currentCustomName;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.product;
    _systemPrice = widget.product.price; 
    
    _qtyCtrl.text = widget.initialQty.toString();

    double effectivePrice = widget.initialOverridePrice ?? widget.product.offerPrice ?? _systemPrice;
    
    _priceCtrl.text = effectivePrice.toStringAsFixed(2);
    double initialDiscount = _systemPrice - effectivePrice;
    
    if (initialDiscount > 0.01 || (widget.initialOverridePrice != null && (widget.initialOverridePrice! - _systemPrice).abs() > 0.01)) {
      _isManualPrice = true;
      _discountCtrl.text = initialDiscount > 0 ? initialDiscount.toStringAsFixed(2) : "0.00";
    } else {
      _isManualPrice = false;
      _discountCtrl.text = "";
    }
    
    _currentCustomName = widget.initialCustomName;
    _loadVariants();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    try {
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
    _isSyncing = false;
    setState(() {}); 
  }

  void _qtyAction(int delta, bool isClient) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newQty = current + delta;
    if (newQty > 0) {
      // 🔥 BLOQUEO DE STOCK AL CLIENTE AL DARLE '+'
      if (isClient && newQty > _currentSelection.stock) {
         CustomSnackBar.show(context, message: "Límite de stock alcanzado (${_currentSelection.stock} disp.)", isError: true);
         return;
      }
      _qtyCtrl.text = newQty.toString();
      setState(() {});
    }
  }

  String _cleanName(String rawName) {
    return rawName.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _updateVariant(ProductPresentation pres) {
    setState(() {
      String cleanProductName = _cleanName(_fullProduct!.nombre);
      String cleanSpecificName = _cleanName(pres.nombreEspecifico ?? "");
      
      String fullNameBuilder = cleanProductName;
      if (cleanSpecificName.isNotEmpty && !cleanProductName.toLowerCase().contains(cleanSpecificName.toLowerCase())) {
        fullNameBuilder += " $cleanSpecificName";
      }

      _currentSelection = MatchedProduct(
        productId: _currentSelection.productId,
        presentationId: pres.id!,
        fullName: fullNameBuilder,
        productName: _fullProduct!.nombre,
        specificName: pres.nombreEspecifico,
        brand: _fullProduct!.marcaNombre ?? _currentSelection.brand,
        price: pres.precioVentaFinal, 
        offerPrice: (pres.precioOferta != null && pres.precioOferta! > 0) ? pres.precioOferta : null,
        stock: pres.stockActual ~/ (pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1),
        imageUrl: pres.imagenUrl ?? _fullProduct!.imagenUrl,
        unit: pres.unidadVenta ?? "Unidad", 
        conversionFactor: pres.unidadesPorVenta, 
      );
      
      _systemPrice = _currentSelection.price;
      
      if (_currentSelection.offerPrice != null && _currentSelection.offerPrice! > 0) {
        _isManualPrice = true;
        _priceCtrl.text = _currentSelection.offerPrice!.toStringAsFixed(2);
        double disc = _systemPrice - _currentSelection.offerPrice!;
        _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
      } else {
        _isManualPrice = false;
        _priceCtrl.text = _systemPrice.toStringAsFixed(2);
        _discountCtrl.text = "";
      }
      
      _currentCustomName = null; // Reseteamos el custom name al cambiar de variante
      
      int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      
      final isClient = Provider.of<AuthProvider>(context, listen: false).isCommunityClient;
      if (isClient && currentQty > _currentSelection.stock && _currentSelection.stock > 0) {
        _qtyCtrl.text = _currentSelection.stock.toString();
      }
    });
  }

  void _confirm() {
    int finalQty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (finalQty <= 0) {
      CustomSnackBar.show(context, message: "La cantidad debe ser mayor a 0.", isError: true);
      return;
    }
    double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    
    double? overridePrice;
    if (!_isManualPrice) {
      // Si el usuario apaga el toggle, forzamos el precio de sistema original
      // para sobrescribir cualquier precio de oferta (offerPrice) que tenga la variante.
      overridePrice = _systemPrice;
    } else {
      overridePrice = finalPrice;
    }
    
    String finalName = _currentCustomName ?? ""; 
    widget.onConfirm(_currentSelection, finalQty, overridePrice, finalName.isNotEmpty ? finalName : null);
    
    String message = "";
    if (widget.isNewAddition) {
        message = "Producto agregado a la lista.";
    } else {
        if (finalQty != widget.initialQty) {
            message = "Cantidad actualizada en la lista.";
        } else if (_isManualPrice) {
            message = "Descuento/Precio modificado correctamente.";
        } else {
            message = "Cambios guardados.";
        }
    }

    CustomSnackBar.show(
      context, 
      message: message, 
      isError: false,
      icon: Icons.check_circle
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

    int currentQty = int.tryParse(_qtyCtrl.text) ?? 0;
    double currentPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    double subtotal = currentPrice * currentQty;
    double totalSavings = (_systemPrice - currentPrice) * currentQty;
    
    bool isStockEmpty = _currentSelection.stock <= 0;
    bool exceedsStock = currentQty > _currentSelection.stock && !isStockEmpty;

    String originalName = widget.product.fullName.trim(); 
    bool hasCustomName = widget.initialCustomName != null && widget.initialCustomName!.isNotEmpty;
    
    // Lógica refinada (2 Capas: Cambio de usuario o Cambio de Inventario)
    bool isVariantChanged = _currentSelection.presentationId != widget.product.presentationId;
    bool isInventoryChanged = false;

    if (_fullProduct != null && !isVariantChanged) {
      try {
        final pres = _fullProduct!.presentaciones.firstWhere(
          (p) => p.id == _currentSelection.presentationId,
        );

        String cleanProductName = _cleanName(_fullProduct!.nombre);
        String cleanSpecificName = _cleanName(pres.nombreEspecifico ?? "");
        String liveFullName = cleanProductName;
        if (cleanSpecificName.isNotEmpty && !cleanProductName.toLowerCase().contains(cleanSpecificName.toLowerCase())) {
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

    bool isNameChanged = widget.isEditingSavedQuote && 
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

              if (isNameChanged)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Icon(Icons.history, size: 16, color: isDark ? Colors.orange[300] : Colors.orange[800]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("Cotizado originalmente como:\n$originalName", style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.orange[300] : Colors.orange[800], fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),

              if (widget.isBundleOutdated)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isDark ? Colors.deepPurple.withValues(alpha: 0.15) : Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sync_problem, size: 20, color: isDark ? Colors.deepPurple[300] : Colors.deepPurple[700]),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Oferta desactualizada", style: textTheme.titleSmall?.copyWith(color: isDark ? Colors.deepPurple[300] : Colors.deepPurple[700], fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("La composición, nombre o precio de esta oferta ha cambiado en el catálogo.", style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.deepPurple[200] : Colors.deepPurple[800])),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: _isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, size: 18),
                          label: const Text("Sincronizar Oferta"),
                          style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.deepPurple[300] : Colors.deepPurple[700], side: BorderSide(color: isDark ? Colors.deepPurple.withValues(alpha: 0.5) : Colors.deepPurple.shade300)),
                          onPressed: _isSyncing || widget.onSyncBundle == null ? null : () async {
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
                      )
                    ],
                  ),
                ),
              
              // 1. INFO SUPERIOR
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_currentSelection.imageUrl != null && _currentSelection.imageUrl!.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: _currentSelection.imageUrl!, tag: "modal_cot_${_currentSelection.presentationId}")));
                      }
                    },
                    child: Hero(
                      tag: "modal_cot_${_currentSelection.presentationId}",
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 90, height: 90, 
                            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300), borderRadius: BorderRadius.circular(16)), 
                            child: ClipRRect(borderRadius: BorderRadius.circular(16), child: UniversalImage(path: _currentSelection.imageUrl, fit: BoxFit.cover))
                          ),
                          if (_currentSelection.imageUrl != null && _currentSelection.imageUrl!.isNotEmpty) ...[
                            Container(width: 90, height: 90, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black.withValues(alpha: 0.3))),
                            const Icon(Icons.zoom_in, color: Colors.white, size: 30)
                          ]
                        ]
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brandName.isNotEmpty && brandName != "null") 
                          Text(brandName.toUpperCase(), style: TextStyle(fontSize: 12, color: isDark ? Colors.indigo[300] : Colors.indigo[800], fontWeight: FontWeight.w800, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        
                        const SizedBox(height: 2),

                        Text("${_currentSelection.productName} ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, height: 1.2), maxLines: 3, overflow: TextOverflow.ellipsis),
                        
                        if (_currentSelection.specificName != null && _currentSelection.specificName!.isNotEmpty && _currentSelection.specificName != "Paquete")
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(_currentSelection.specificName!, style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]), maxLines: 3, overflow: TextOverflow.ellipsis),
                          ),
                        
                        if (_currentSelection.description != null && _currentSelection.description!.isNotEmpty && _currentSelection.description != _currentSelection.specificName)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_currentSelection.description!, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]), maxLines: 3, overflow: TextOverflow.ellipsis),
                          ),
                        
                        const SizedBox(height: 10),
                        
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text("${_currentSelection.unit} (x${_currentSelection.conversionFactor})", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                            ),
                            if (widget.categoryName != null && widget.categoryName!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                child: Text(widget.categoryName!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              isStockEmpty
                                  ? "Agotado (0)"
                                  : "Stock disponible: ${_currentSelection.stock} ${_currentSelection.unit}",
                              style: textTheme.bodySmall?.copyWith(
                                color: isStockEmpty
                                    ? (isDark ? Colors.red[400] : Colors.red)
                                    : (isDark
                                        ? Colors.green[400]
                                        : Colors.green),
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
                                      .firstOrNull ??
                                      _fullProduct!.presentaciones.firstOrNull;
                                }
                                if (targetPres != null) {
                                  await StockUpdateModal.show(
                                    context: context,
                                    presentation: targetPres,
                                    provider: invProv,
                                    isDark: isDark,
                                  );
                                  await _loadVariants();
                                  if (_fullProduct != null) {
                                    final updatedPres = _fullProduct!
                                        .presentaciones
                                        .where(
                                          (p) =>
                                              p.id ==
                                              _currentSelection.presentationId,
                                        )
                                        .firstOrNull ??
                                        targetPres;
                                    setState(() {
                                      _currentSelection = MatchedProduct(
                                        productId: _currentSelection.productId,
                                        presentationId:
                                            _currentSelection.presentationId,
                                        fullName: _currentSelection.fullName,
                                        productName:
                                            _currentSelection.productName,
                                        specificName:
                                            _currentSelection.specificName,
                                        brand: _currentSelection.brand,
                                        price: updatedPres.precioVentaFinal,
                                        offerPrice: updatedPres.precioOferta,
                                        stock: updatedPres.stockActual,
                                        imageUrl: _currentSelection.imageUrl,
                                        unit: _currentSelection.unit,
                                        conversionFactor:
                                            _currentSelection.conversionFactor,
                                      );
                                    });
                                    if (context.mounted) {
                                      final smartProv = Provider.of<SmartQuotationProvider>(context, listen: false);
                                      smartProv.syncItemPriceAndStock(
                                        _currentSelection.presentationId,
                                        newStock: updatedPres.stockActual,
                                        newPrice: updatedPres.precioVentaFinal,
                                      );
                                    }
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
                  )
                ],
              ),
              const SizedBox(height: 24),

              // 2. VARIANTES 
              if (_isLoadingVariants) const Center(child: LinearProgressIndicator())
              else if (_fullProduct != null && _fullProduct!.presentaciones.length > 1) ...[
                Text("Seleccionar Presentación:", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[300] : Colors.grey[800])),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _fullProduct!.presentaciones.map((p) {
                      final isSelected = p.id == _currentSelection.presentationId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(p.unidadVenta ?? "Unidad", style: textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), 
                          selected: isSelected, 
                          onSelected: (v) => v ? _updateVariant(p) : null, 
                          selectedColor: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue[100],
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                          labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue[900]) : textColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 3. SECCIÓN DE DESCUENTO (OCULTA PARA CLIENTES)
              if (!isClient)
                ManualPriceModifier(
                  isManualPrice: _isManualPrice,
                  systemPrice: _systemPrice,
                  discountCtrl: _discountCtrl,
                  priceCtrl: _priceCtrl,
                  onToggle: (v) {
                    setState(() {
                      _isManualPrice = v;
                      if (!v) { 
                        _priceCtrl.text = _systemPrice.toStringAsFixed(2); 
                        _discountCtrl.text = ""; 
                      } else {
                        if (_currentSelection.offerPrice != null && _currentSelection.offerPrice! > 0) {
                          _priceCtrl.text = _currentSelection.offerPrice!.toStringAsFixed(2);
                          double disc = _systemPrice - _currentSelection.offerPrice!;
                          _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
                        }
                      }
                    });
                  },
                  onDiscountChanged: _onDiscountChanged,
                  onPriceChanged: _onPriceChanged,
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
                          .firstOrNull ??
                          _fullProduct!.presentaciones.firstOrNull;
                    }
                    if (targetPres != null) {
                      await PriceUpdateModal.show(
                        context: context,
                        presentation: targetPres,
                        provider: invProv,
                        isDark: isDark,
                      );
                      await _loadVariants();
                      if (_fullProduct != null) {
                        final updatedPres = _fullProduct!.presentaciones
                            .where(
                              (p) => p.id == _currentSelection.presentationId,
                            )
                            .firstOrNull ??
                            targetPres;
                        setState(() {
                          _systemPrice = updatedPres.precioVentaFinal;
                          _priceCtrl.text = _systemPrice.toStringAsFixed(2);
                          _discountCtrl.clear();
                        });
                        if (context.mounted) {
                          final smartProv = Provider.of<SmartQuotationProvider>(context, listen: false);
                          smartProv.syncItemPriceAndStock(
                            _currentSelection.presentationId,
                            newPrice: updatedPres.precioVentaFinal,
                          );
                        }
                      }
                    }
                  },
                  isDark: isDark,
                  currency: currency,
                ),
              if (!isClient) const SizedBox(height: 30),

              // 4. CANTIDAD Y TOTALES
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Cantidad", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        height: 55, 
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.white, border: Border.all(color: (exceedsStock || isStockEmpty) ? (isDark ? Colors.orange[400]! : Colors.orange) : (isDark ? Colors.white24 : Colors.grey.shade300), width: 1.5), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: Icon(Icons.remove, color: isDark ? Colors.red[300] : Colors.red, size: 24), onPressed: () => _qtyAction(-1, isClient)),
                            SizedBox(
                              width: 50,
                              child: TextField(
                                controller: _qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                onChanged: (v) {
                                  // 🔥 BLOQUEO DE STOCK AL CLIENTE AL ESCRIBIR
                                  if (isClient) {
                                      int parsed = int.tryParse(v) ?? 1;
                                      if (parsed > _currentSelection.stock) {
                                          _qtyCtrl.text = _currentSelection.stock.toString();
                                          CustomSnackBar.show(context, message: "Límite de stock alcanzado", isError: true);
                                      }
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                            IconButton(icon: Icon(Icons.add, color: isDark ? Colors.green[400] : Colors.green, size: 24), onPressed: () => _qtyAction(1, isClient)),
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
                          alignment: Alignment.centerRight,
                          child: Text(currency.format(subtotal), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue)),
                        ),
                      ],
                    ),
                  )
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
                    "⚠️ Supera el stock actual de ${_currentSelection.stock}.",
                    style: textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.orange[400] : Colors.orange[800],
                    ),
                  ),
                ),
              
              const SizedBox(height: 35),

              // 5. CONFIRMAR
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: (currentQty > 0 && subtotal >= 0 && (!isClient || !exceedsStock)) ? _confirm : null, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(
                    widget.isNewAddition ? "AGREGAR A COTIZACIÓN" : "GUARDAR CAMBIOS", 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}