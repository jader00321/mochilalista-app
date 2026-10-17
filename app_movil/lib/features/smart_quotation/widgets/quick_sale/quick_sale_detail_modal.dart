import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';

class QuickSaleDetailModal extends StatefulWidget {
  final MatchedProduct product;
  final int initialQty;
  final double? initialOverridePrice;
  final Function(int oldPresentationId, MatchedProduct product, int qty, double? overridePrice) onConfirm;

  const QuickSaleDetailModal({
    super.key,
    required this.product,
    required this.initialQty,
    this.initialOverridePrice,
    required this.onConfirm,
  });

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required MatchedProduct product,
    required int initialQty,
    double? initialOverridePrice,
    required Function(int oldPresentationId, MatchedProduct product, int qty, double? overridePrice) onConfirm,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => QuickSaleDetailModal(
        product: product,
        initialQty: initialQty,
        initialOverridePrice: initialOverridePrice,
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

  bool _isManualPrice = false;
  bool _isSyncing = false;

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
      final prod = await invProv.getFullProductWithFallback(_currentSelection.productId);
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

  void _qtyAction(int delta) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newQty = current + delta;
    if (newQty > 0) {
      _qtyCtrl.text = newQty.toString();
      setState(() {});
    }
  }

  void _updateVariant(ProductPresentation pres) {
    setState(() {
      String fullNameBuilder = _fullProduct!.nombre;
      if (_currentSelection.brand != null && _currentSelection.brand != "null") fullNameBuilder += " ${_currentSelection.brand}";
      if (pres.nombreEspecifico != null) fullNameBuilder += " ${pres.nombreEspecifico}";

      // 🔥 MAPEAMOS LA NUEVA MATEMÁTICA
      _currentSelection = MatchedProduct(
        productId: _currentSelection.productId,
        presentationId: pres.id!,
        fullName: fullNameBuilder,
        productName: _fullProduct!.nombre,
        specificName: pres.nombreEspecifico,
        brand: _currentSelection.brand,
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
      
      int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      if (currentQty > _currentSelection.stock && _currentSelection.stock > 0) {
        _qtyCtrl.text = _currentSelection.stock.toString();
      }
    });
  }

  void _confirm() {
    int finalQty = int.tryParse(_qtyCtrl.text) ?? 1;
    double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    
    double? overridePrice;
    if (!_isManualPrice) {
      // FASE 3 FIX: Si el usuario apaga el toggle, forzamos el precio base original
      // para sobrescribir cualquier precio de oferta (offerPrice) que tenga el producto.
      overridePrice = _systemPrice;
    } else {
      // Si el toggle está encendido, usamos el precio modificado.
      // Si por alguna razón es igual al _systemPrice, igual lo pasamos para ser consistentes,
      // o podemos pasarlo como null si no hay diferencia, pero es más seguro pasar el valor.
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

    int currentQty = int.tryParse(_qtyCtrl.text) ?? 0;
    double currentPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    double subtotal = currentPrice * currentQty;
    double totalSavings = (_systemPrice - currentPrice) * currentQty;
    
    bool isStockEmpty = _currentSelection.stock <= 0;
    bool exceedsStock = currentQty > _currentSelection.stock && !_currentSelection.stock.isNegative;
    
    bool showBrand = brandName.isNotEmpty && !_currentSelection.productName.toUpperCase().contains(brandName.toUpperCase());
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // 1. INFO SUPERIOR
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
                                  categoryName: brandName,
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
                          width: 90,
                          height: 90,
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
                              categoryName: brandName,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (hasRealImage) ...[
                          Container(
                            width: 90,
                            height: 90,
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showBrand)
                          Text(brandName.toUpperCase(), style: TextStyle(fontSize: 12, color: isDark ? Colors.indigo[300] : Colors.indigo[700], fontWeight: FontWeight.w800, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        
                        Text("${_currentSelection.productName} ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, height: 1.2), maxLines: 3, overflow: TextOverflow.ellipsis),
                        
                        if (_currentSelection.specificName != null && _currentSelection.specificName!.isNotEmpty && _currentSelection.specificName != "Paquete")
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(_currentSelection.specificName!, style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]), maxLines: 3, overflow: TextOverflow.ellipsis),
                          ),
                        
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300)),
                          child: Text("Se vende por: ${_currentSelection.unit}  (Factor: ${_currentSelection.conversionFactor})", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[800], fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
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
                                final currentPres = _fullProduct?.presentaciones
                                    .firstWhere(
                                      (p) =>
                                          p.id ==
                                          _currentSelection.presentationId,
                                      orElse: () => ProductPresentation(
                                        id: _currentSelection.presentationId,
                                        precioVentaFinal:
                                            _currentSelection.price,
                                        stockActual:
                                            _currentSelection.stock *
                                            _currentSelection.conversionFactor,
                                        unidadesPorVenta:
                                            _currentSelection.conversionFactor,
                                        unidadVenta: _currentSelection.unit,
                                      ),
                                    );
                                if (currentPres != null) {
                                  await StockUpdateModal.show(
                                    context: context,
                                    presentation: currentPres,
                                    provider: invProv,
                                    isDark: isDark,
                                  );
                                  await _loadVariants();
                                  if (context.mounted) {
                                    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
                                    quickProv.syncItemPriceAndStock(
                                      _currentSelection.presentationId,
                                      newStock: _currentSelection.stock,
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
              const SizedBox(height: 24),

              // 2. VARIANTES
              if (_isLoadingVariants) const Center(child: LinearProgressIndicator())
              else if (_fullProduct != null && _fullProduct!.presentaciones.length > 1) ...[
                Text("Seleccionar Presentación:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _fullProduct!.presentaciones.map((p) {
                      final isSelected = p.id == _currentSelection.presentationId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(p.unidadVenta ?? "Unidad", style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), 
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
                const SizedBox(height: 24),
              ],

              // 3. SECCIÓN DE DESCUENTO (2 TIERS ANTI-COLISIÓN)
              Container(
                decoration: BoxDecoration(
                  color: _isManualPrice
                      ? (isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50])
                      : (isDark ? Colors.white10 : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isManualPrice
                        ? (isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade300)
                        : (isDark ? Colors.transparent : Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nivel 1: Título a la izquierda + Switch a la derecha
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_offer_outlined,
                                    size: 18,
                                    color: _isManualPrice
                                        ? (isDark ? Colors.orange[300] : Colors.orange[800])
                                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Aplicar Descuento",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _isManualPrice
                                          ? (isDark ? Colors.orange[300] : Colors.orange[900])
                                          : textColor,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _isManualPrice,
                                activeThumbColor: Colors.orange,
                                onChanged: (v) => setState(() {
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
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Nivel 2: Precio Base + Botón Editar Catálogo (Garantiza 0 colisiones en pantallas angostas)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Precio Base: ${currency.format(_systemPrice)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  final invProv = Provider.of<InventoryProvider>(context, listen: false);
                                  ProductPresentation? targetPres;
                                  if (_fullProduct != null) {
                                    targetPres = _fullProduct!.presentaciones.where(
                                      (p) => p.id == _currentSelection.presentationId,
                                    ).firstOrNull ?? _fullProduct!.presentaciones.firstOrNull;
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
                                      final updatedPres = _fullProduct!.presentaciones.where(
                                        (p) => p.id == _currentSelection.presentationId,
                                      ).firstOrNull ?? targetPres;
                                      setState(() {
                                        _systemPrice = updatedPres.precioVentaFinal;
                                        _priceCtrl.text = _systemPrice.toStringAsFixed(2);
                                        _discountCtrl.clear();
                                      });
                                      if (context.mounted) {
                                        final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
                                        quickProv.syncItemPriceAndStock(
                                          _currentSelection.presentationId,
                                          newPrice: updatedPres.precioVentaFinal,
                                        );
                                      }
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Editar Catálogo",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.blue[300] : Colors.blue[700],
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
                    if (_isManualPrice) ...[
                      Divider(height: 1, color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange[200]),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("S/ a Descontar", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 14)),
                                  TextField(
                                    controller: _discountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                                    decoration: InputDecoration(prefixText: "- ", prefixStyle: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[900], fontSize: 24, fontWeight: FontWeight.bold), isDense: true, border: InputBorder.none),
                                    onChanged: _onDiscountChanged,
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 50, color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange[300]),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Precio Final Unit.", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 14)),
                                  TextField(
                                    controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue),
                                    decoration: InputDecoration(prefixText: "S/ ", prefixStyle: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 24, fontWeight: FontWeight.bold), isDense: true, border: InputBorder.none),
                                    onChanged: _onPriceChanged,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 30),

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