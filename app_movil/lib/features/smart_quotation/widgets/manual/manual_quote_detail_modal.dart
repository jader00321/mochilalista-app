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

class ManualQuoteDetailModal extends StatefulWidget {
  final MatchedProduct product;
  final int initialQty;
  final double? initialOverridePrice;
  final String? initialCustomName; 
  final String? categoryName; 
  final bool isNewAddition; 
  
  final Function(MatchedProduct product, int qty, double? overridePrice, String? customName) onConfirm;

  const ManualQuoteDetailModal({
    super.key,
    required this.product,
    this.initialQty = 1,
    this.initialOverridePrice,
    this.initialCustomName,
    this.categoryName,
    this.isNewAddition = false, 
    required this.onConfirm,
  });

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
    
    if (initialDiscount > 0.01 || widget.initialOverridePrice != null) {
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
        stock: pres.stockActual,
        imageUrl: pres.imagenUrl ?? _fullProduct!.imagenUrl,
        unit: pres.unidadVenta ?? "Unidad", 
        conversionFactor: pres.unidadesPorVenta, 
      );
      
      _systemPrice = _currentSelection.price;
      _isManualPrice = false;
      _priceCtrl.text = _systemPrice.toStringAsFixed(2);
      _discountCtrl.text = "";
      
      _currentCustomName = null; // Reseteamos el custom name al cambiar de variante
      
      int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      
      final isClient = Provider.of<AuthProvider>(context, listen: false).isCommunityClient;
      if (isClient && currentQty > pres.stockActual && pres.stockActual > 0) {
        _qtyCtrl.text = pres.stockActual.toString();
      }
    });
  }

  void _confirm() {
    int finalQty = int.tryParse(_qtyCtrl.text) ?? 1;
    double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    
    double? overridePrice;
    if (finalPrice == _systemPrice && widget.product.offerPrice == null) {
      overridePrice = null;
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
    String currentBuiltName = _currentSelection.displayNameClean.trim();
    bool hasCustomName = widget.initialCustomName != null && widget.initialCustomName!.isNotEmpty;
    bool isNameChanged = !widget.isNewAddition && 
                          originalName.isNotEmpty && 
                          currentBuiltName.toLowerCase() != originalName.toLowerCase() &&
                          !originalName.toLowerCase().contains("nuevo ítem") &&
                          !hasCustomName;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),

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
                      child: Container(
                        width: 90, height: 90, 
                        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300), borderRadius: BorderRadius.circular(16)), 
                        child: ClipRRect(borderRadius: BorderRadius.circular(16), child: UniversalImage(path: _currentSelection.imageUrl, fit: BoxFit.cover))
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brandName.isNotEmpty && brandName != "null") 
                          Text(brandName.toUpperCase(), style: textTheme.labelMedium?.copyWith(color: isDark ? Colors.indigo[300] : Colors.indigo[800])),
                        
                        const SizedBox(height: 2),

                        RichText(
                           maxLines: 3,
                           overflow: TextOverflow.ellipsis,
                           text: TextSpan(
                             children: [
                               TextSpan(text: "${_currentSelection.productName} ", style: textTheme.titleLarge?.copyWith(color: textColor)),
                               if (_currentSelection.specificName != null && _currentSelection.specificName!.isNotEmpty)
                                 TextSpan(text: _currentSelection.specificName!, style: textTheme.titleLarge?.copyWith(color: isDark ? Colors.teal[300] : Colors.teal[700])),
                             ],
                           ),
                         ),
                        
                        const SizedBox(height: 10),
                        
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text("${_currentSelection.unit} (x${_currentSelection.conversionFactor})", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[700])),
                            ),
                            if (widget.categoryName != null && widget.categoryName!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                child: Text(widget.categoryName!, style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.grey[300] : Colors.grey[700])),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        Text(
                          isStockEmpty ? "Agotado (0)" : "Stock disponible: ${_currentSelection.stock}", 
                          style: textTheme.bodySmall?.copyWith(color: isStockEmpty ? (isDark ? Colors.red[400] : Colors.red) : (isDark ? Colors.green[400] : Colors.green), fontWeight: FontWeight.bold)
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
                      if (!v) { _priceCtrl.text = _systemPrice.toStringAsFixed(2); _discountCtrl.text = ""; }
                    });
                  },
                  onDiscountChanged: _onDiscountChanged,
                  onPriceChanged: _onPriceChanged,
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
                      Text("Cantidad", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        height: 60, 
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.white, border: Border.all(color: (exceedsStock || isStockEmpty) ? (isDark ? Colors.orange[400]! : Colors.orange) : (isDark ? Colors.white24 : Colors.grey.shade300), width: 1.5), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: Icon(Icons.remove, color: isDark ? Colors.red[400] : Colors.red, size: 28), onPressed: () => _qtyAction(-1, isClient)),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: _qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                                style: textTheme.displayMedium?.copyWith(color: textColor),
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
                            IconButton(icon: Icon(Icons.add, color: isDark ? Colors.green[400] : Colors.green, size: 28), onPressed: () => _qtyAction(1, isClient)),
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
                        if (totalSavings > 0) Text("Ahorro: ${currency.format(totalSavings)}", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.green[400] : Colors.green)),
                        Text("Subtotal", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(currency.format(subtotal), style: textTheme.displayLarge?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              
              if (isStockEmpty) 
                Padding(padding: const EdgeInsets.only(top: 12), child: Text("⚠️ Producto agotado. Requiere revisión para venderse.", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.red[300] : Colors.red[700])))
              else if (exceedsStock && !isClient) 
                Padding(padding: const EdgeInsets.only(top: 12), child: Text("⚠️ Supera el stock actual de ${_currentSelection.stock}.", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.orange[400] : Colors.orange[800]))),
              
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
      ),
    );
  }
}