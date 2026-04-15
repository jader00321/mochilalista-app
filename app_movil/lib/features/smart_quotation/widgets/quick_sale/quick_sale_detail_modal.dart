import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../models/product_model.dart';
import '../../models/matching_model.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../widgets/universal_image.dart';

class QuickSaleDetailModal extends StatefulWidget {
  final MatchedProduct product;
  final int initialQty;
  final double? initialOverridePrice;
  final Function(MatchedProduct product, int qty, double? overridePrice) onConfirm;

  const QuickSaleDetailModal({
    super.key,
    required this.product,
    required this.initialQty,
    this.initialOverridePrice,
    required this.onConfirm,
  });

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
    
    if (initialDiscount > 0) {
      _isManualPrice = true;
      _discountCtrl.text = initialDiscount.toStringAsFixed(2);
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
    if (disc > _systemPrice) disc = _systemPrice;

    double newPrice = _systemPrice - disc;
    _priceCtrl.text = newPrice.toStringAsFixed(2);
    _isSyncing = false;
    setState(() {}); 
  }

  void _onPriceChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double price = double.tryParse(val) ?? _systemPrice;
    
    if (price > _systemPrice) price = _systemPrice;

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
        stock: pres.stockActual,
        imageUrl: pres.imagenUrl ?? _fullProduct!.imagenUrl,
        unit: pres.umpCompra ?? "Unidad", 
        conversionFactor: pres.unidadesPorLote, 
      );
      
      _systemPrice = _currentSelection.price;
      
      _isManualPrice = false;
      _priceCtrl.text = _systemPrice.toStringAsFixed(2);
      _discountCtrl.text = "";
      
      int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      if (currentQty > pres.stockActual && pres.stockActual > 0) {
        _qtyCtrl.text = pres.stockActual.toString();
      }
    });
  }

  void _confirm() {
    int finalQty = int.tryParse(_qtyCtrl.text) ?? 1;
    double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    double? overridePrice = (finalPrice == _systemPrice) ? null : finalPrice;
    widget.onConfirm(_currentSelection, finalQty, overridePrice);
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

    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. INFO SUPERIOR
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => showDialog(context: context, builder: (ctx) => Dialog(backgroundColor: Colors.transparent, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: UniversalImage(path: _currentSelection.imageUrl, fit: BoxFit.contain)))),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(width: 90, height: 90, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: UniversalImage(path: _currentSelection.imageUrl, fit: BoxFit.cover))),
                        Container(width: 90, height: 90, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black.withOpacity(0.3))),
                        const Icon(Icons.zoom_in, color: Colors.white, size: 30)
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brandName.isNotEmpty) Text(brandName.toUpperCase(), style: TextStyle(color: isDark ? Colors.indigo[300] : Colors.indigo[800], fontWeight: FontWeight.w900, fontSize: 13)),
                        Text(_currentSelection.productName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, height: 1.2, color: textColor)),
                        if (_currentSelection.specificName != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_currentSelection.specificName!, style: TextStyle(color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.bold, fontSize: 15))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300)),
                          child: Text("Se vende por: ${_currentSelection.unit}  (Factor: ${_currentSelection.conversionFactor})", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[800], fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(isStockEmpty ? "Agotado" : "Stock disponible: ${_currentSelection.stock}", style: TextStyle(color: isStockEmpty ? (isDark ? Colors.red[300] : Colors.red) : (isDark ? Colors.green[400] : Colors.green), fontWeight: FontWeight.bold, fontSize: 15)),
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
                          label: Text(p.umpCompra ?? "Unidad", style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), 
                          selected: isSelected, 
                          onSelected: (v) => v ? _updateVariant(p) : null, 
                          selectedColor: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue[100],
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                          labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.blue[300] : Colors.blue[900]) : textColor),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 3. SECCIÓN DE DESCUENTO
              Container(
                decoration: BoxDecoration(color: _isManualPrice ? (isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50]) : (isDark ? Colors.white10 : Colors.grey[50]), borderRadius: BorderRadius.circular(16), border: Border.all(color: _isManualPrice ? (isDark ? Colors.orange.withOpacity(0.5) : Colors.orange.shade300) : (isDark ? Colors.transparent : Colors.grey.shade300))),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text("Aplicar Descuento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _isManualPrice ? (isDark ? Colors.orange[300] : Colors.orange[900]) : textColor)),
                      subtitle: Text("Precio Base: ${currency.format(_systemPrice)}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      value: _isManualPrice,
                      activeThumbColor: Colors.orange,
                      onChanged: (v) => setState(() {
                        _isManualPrice = v;
                        if (!v) { _priceCtrl.text = _systemPrice.toStringAsFixed(2); _discountCtrl.text = ""; }
                      }),
                    ),
                    if (_isManualPrice) ...[
                      Divider(height: 1, color: isDark ? Colors.orange.withOpacity(0.3) : Colors.orange[200]),
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
                            Container(width: 1, height: 50, color: isDark ? Colors.orange.withOpacity(0.3) : Colors.orange[300]),
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
              const SizedBox(height: 30),

              // 5. CONFIRMAR
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: (currentQty > 0 && subtotal >= 0 && !exceedsStock) ? _confirm : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("GUARDAR CAMBIOS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}