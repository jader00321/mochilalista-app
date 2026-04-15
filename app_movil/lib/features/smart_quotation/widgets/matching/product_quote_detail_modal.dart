import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../models/inventory_wrapper.dart';
import '../../../../models/product_model.dart';
import '../../../../widgets/universal_image.dart';
import '../../../../providers/inventory_provider.dart'; 
import '../../../../providers/auth_provider.dart'; 
import '../../../../widgets/full_screen_image_viewer.dart';
import '../../../../widgets/custom_snackbar.dart';

class ProductQuoteDetailModal extends StatefulWidget {
  final InventoryWrapper wrapper; 
  final String? brandName; 
  final int currentQuantity;
  final double? currentOverridePrice; 
  final Function(ProductPresentation newPresentation, int newQty, double? newPrice, String? newName) onSave;
  final String? currentSnapshotName;
  final String? categoryName; 

  const ProductQuoteDetailModal({
    super.key,
    required this.wrapper,
    this.brandName,
    required this.currentQuantity,
    this.currentOverridePrice,
    required this.onSave,
    this.currentSnapshotName,
    this.categoryName,
  });

  @override
  State<ProductQuoteDetailModal> createState() => _ProductQuoteDetailModalState();
}

class _ProductQuoteDetailModalState extends State<ProductQuoteDetailModal> {
  Product? _fullProduct;
  bool _isLoading = true;
  String _currentCategoryName = "";

  late ProductPresentation _selectedPresentation;
  late int _quantity;
  
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  bool _isManualPrice = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _selectedPresentation = widget.wrapper.presentation;
    
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.isCommunityClient && widget.currentQuantity > _selectedPresentation.stockActual) {
      _quantity = _selectedPresentation.stockActual > 0 ? _selectedPresentation.stockActual : 1;
    } else {
      _quantity = widget.currentQuantity;
    }

    _currentCategoryName = widget.categoryName ?? "";
    _qtyCtrl.text = _quantity.toString();

    double systemPrice = widget.wrapper.effectivePrice;
    double effectivePrice = widget.currentOverridePrice ?? systemPrice;
    
    _priceCtrl.text = effectivePrice.toStringAsFixed(2);
    double initialDiscount = systemPrice - effectivePrice;
    
    if (initialDiscount > 0.01) {
      _isManualPrice = true;
      _discountCtrl.text = initialDiscount.toStringAsFixed(2);
    } else if (widget.currentOverridePrice != null && widget.currentOverridePrice != systemPrice) {
      _isManualPrice = true;
      _discountCtrl.text = "0.00";
    } else {
      _isManualPrice = false;
      _discountCtrl.text = "";
    }

    _loadFullProductDetails();
  }

  Future<void> _loadFullProductDetails() async {
    final inventoryProv = Provider.of<InventoryProvider>(context, listen: false);
    final product = await inventoryProv.fetchProductById(widget.wrapper.product.id);

    if (mounted) {
      setState(() {
        _fullProduct = product; 
        _isLoading = false;
        
        if (_currentCategoryName.isEmpty && product != null) {
          _currentCategoryName = inventoryProv.getCategoryName(product.categoriaId);
        }

        if (_fullProduct != null) {
          try {
            _selectedPresentation = _fullProduct!.presentaciones.firstWhere(
              (p) => p.id == _selectedPresentation.id,
              orElse: () => _selectedPresentation
            );
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  double _getCurrentListPrice() {
    return _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0 
           ? _selectedPresentation.precioOferta! 
           : _selectedPresentation.precioVentaFinal;
  }

  void _onDiscountChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double sysPrice = _getCurrentListPrice();
    double disc = double.tryParse(val) ?? 0.0;
    
    if (disc < 0) disc = 0;
    if (disc > sysPrice) disc = sysPrice;

    double newPrice = sysPrice - disc;
    _priceCtrl.text = newPrice.toStringAsFixed(2);
    _isSyncing = false;
    setState(() {}); 
  }

  void _onPriceChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double sysPrice = _getCurrentListPrice();
    double price = double.tryParse(val) ?? sysPrice;
    double disc = sysPrice - price;
    
    _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
    _isSyncing = false;
    setState(() {}); 
  }

  void _qtyAction(int delta, bool isClient) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newQty = current + delta;
    
    if (newQty > 0) {
      if (isClient && newQty > _selectedPresentation.stockActual) {
        CustomSnackBar.show(context, message: "Límite de stock alcanzado (${_selectedPresentation.stockActual} disp.)", isError: true);
        return;
      }
      _qtyCtrl.text = newQty.toString();
      setState(() => _quantity = newQty);
    }
  }

  void _handleSave() {
    final sysPrice = _getCurrentListPrice();
    final finalPrice = _isManualPrice ? (double.tryParse(_priceCtrl.text) ?? sysPrice) : sysPrice;
    final overridePrice = (finalPrice == sysPrice) ? null : finalPrice;
    
    widget.onSave(_selectedPresentation, _quantity, overridePrice, null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final productDisplay = _fullProduct ?? widget.wrapper.product;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    final sysPrice = _getCurrentListPrice();
    final unitPrice = _isManualPrice ? (double.tryParse(_priceCtrl.text) ?? sysPrice) : sysPrice;
    final subtotal = unitPrice * _quantity;
    final originalTotal = sysPrice * _quantity;
    final savings = originalTotal - subtotal;

    bool isStockEmpty = _selectedPresentation.stockActual <= 0;
    bool exceedsStock = _quantity > _selectedPresentation.stockActual && !isStockEmpty;

    String snapshot = widget.currentSnapshotName?.trim() ?? "";
    String currentBuiltName = "${productDisplay.nombre} ${_selectedPresentation.nombreEspecifico ?? ''}".trim();
    bool isNameChanged = snapshot.isNotEmpty && 
                         currentBuiltName.toLowerCase() != snapshot.toLowerCase() &&
                         !snapshot.toLowerCase().contains("nuevo ítem");

    final double initialSize = isClient ? 0.50 : 0.55;
    final double maxSize = isClient ? 0.60 : 0.65;

    return DraggableScrollableSheet(
      initialChildSize: initialSize, 
      minChildSize: 0.4,
      maxChildSize: maxSize, 
      builder: (_, controller) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                
                if (isNameChanged)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(Icons.history, size: 18, color: isDark ? Colors.orange[300] : Colors.orange[800]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text("Extraído originalmente como:\n$snapshot", style: TextStyle(fontSize: 14, color: isDark ? Colors.orange[300] : Colors.orange[800], fontStyle: FontStyle.italic), maxLines: 4, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final img = _selectedPresentation.imagenUrl ?? productDisplay.imagenUrl;
                        if (img != null && img.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: img, tag: "matching_${_selectedPresentation.id}")));
                        }
                      },
                      child: Hero(
                        tag: "matching_${_selectedPresentation.id}",
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(width: 90, height: 90, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300), borderRadius: BorderRadius.circular(16)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: UniversalImage(path: _selectedPresentation.imagenUrl ?? productDisplay.imagenUrl, fit: BoxFit.cover))),
                            Container(width: 90, height: 90, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black.withOpacity(0.2))),
                            const Icon(Icons.zoom_in, color: Colors.white, size: 36)
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.brandName != null && widget.brandName!.isNotEmpty) 
                            Text(widget.brandName!.toUpperCase(), style: textTheme.labelLarge?.copyWith(color: isDark ? Colors.indigo[300] : Colors.indigo[800])),
                          
                          const SizedBox(height: 2),
                          
                          RichText(
                             maxLines: 4,
                             overflow: TextOverflow.ellipsis,
                             text: TextSpan(
                               children: [
                                 TextSpan(text: "${productDisplay.nombre} ", style: textTheme.titleLarge?.copyWith(color: textColor)),
                                 if (_selectedPresentation.nombreEspecifico != null && _selectedPresentation.nombreEspecifico!.isNotEmpty)
                                   TextSpan(text: _selectedPresentation.nombreEspecifico!, style: textTheme.titleLarge?.copyWith(color: isDark ? Colors.teal[300] : Colors.teal[700])),
                               ],
                             ),
                           ),
                          
                          const SizedBox(height: 10),
                          
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text("${_selectedPresentation.unidadVenta ?? 'Unidad'} (x${_selectedPresentation.unidadesPorVenta})", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[700])),
                              ),
                              if (_currentCategoryName.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                  child: Text(_currentCategoryName, style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.grey[300] : Colors.grey[700])),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Text(isStockEmpty ? "Agotado (0)" : "Stock disponible: ${_selectedPresentation.stockActual}", style: textTheme.bodySmall?.copyWith(color: isStockEmpty ? (isDark ? Colors.red[400] : Colors.red) : (isDark ? Colors.green[400] : Colors.green), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
                
                const SizedBox(height: 24),

                if (_isLoading) const Center(child: CircularProgressIndicator())
                else if (_fullProduct != null && _fullProduct!.presentaciones.length > 1) ...[
                  Text("Seleccionar Variante:", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[300] : Colors.grey[800])),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _fullProduct!.presentaciones.map((p) {
                        final isSelected = p.id == _selectedPresentation.id;
                        final isOutOfStockVariant = p.stockActual <= 0;
                        // 🔥 BLOQUEO DE VARIANTE: Si es cliente y no hay stock, no la puede seleccionar
                        final isDisabled = isClient && isOutOfStockVariant;

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Text(p.unidadVenta ?? "Unidad", style: textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), 
                            selected: isSelected, 
                            onSelected: isDisabled ? null : (v) {
                              if (v) {
                                setState(() {
                                  _selectedPresentation = p;
                                  _isManualPrice = false;
                                  _priceCtrl.text = _getCurrentListPrice().toStringAsFixed(2);
                                  _discountCtrl.text = "";
                                  
                                  if (isClient && _quantity > p.stockActual) {
                                     _quantity = p.stockActual > 0 ? p.stockActual : 1;
                                     _qtyCtrl.text = _quantity.toString();
                                  }
                                });
                              }
                            }, 
                            selectedColor: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue[100],
                            backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                            labelStyle: TextStyle(
                               color: isDisabled 
                                   ? (isDark ? Colors.grey[600] : Colors.grey[400]) 
                                   : (isSelected ? (isDark ? Colors.blue[300] : Colors.blue[900]) : textColor)
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (!isClient)
                  Container(
                    decoration: BoxDecoration(color: _isManualPrice ? (isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50]) : (isDark ? Colors.white10 : Colors.grey[50]), borderRadius: BorderRadius.circular(16), border: Border.all(color: _isManualPrice ? (isDark ? Colors.orange.withOpacity(0.5) : Colors.orange.shade200) : (isDark ? Colors.transparent : Colors.grey.shade300))),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text("Precio Especial al Cliente", style: textTheme.titleMedium?.copyWith(color: _isManualPrice ? (isDark ? Colors.orange[300] : Colors.orange[900]) : textColor)),
                          subtitle: Text("Precio de Lista: ${currency.format(sysPrice)}", style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                          value: _isManualPrice,
                          activeThumbColor: Colors.orange,
                          onChanged: (v) => setState(() {
                            _isManualPrice = v;
                            if (!v) { _priceCtrl.text = sysPrice.toStringAsFixed(2); _discountCtrl.text = ""; }
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
                                      Text("S/ a Descontar", style: textTheme.labelLarge?.copyWith(color: isDark ? Colors.orange[300] : Colors.orange[900])),
                                      TextField(
                                        controller: _discountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: textTheme.displayMedium?.copyWith(color: textColor),
                                        decoration: InputDecoration(prefixText: "- ", prefixStyle: textTheme.displayMedium?.copyWith(color: isDark ? Colors.orange[300] : Colors.orange[900]), isDense: true, border: InputBorder.none),
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
                                      Text("Precio Final Unit.", style: textTheme.labelLarge?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[900])),
                                      TextField(
                                        controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: textTheme.displayMedium?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue),
                                        decoration: InputDecoration(prefixText: "S/ ", prefixStyle: textTheme.displayMedium?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue), isDense: true, border: InputBorder.none),
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
                if (!isClient) const SizedBox(height: 30),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
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
                                Expanded(
                                  child: TextField(
                                    controller: _qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                                    style: textTheme.displayMedium?.copyWith(color: textColor),
                                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                    onChanged: (v) {
                                      if (isClient) {
                                         int parsed = int.tryParse(v) ?? 1;
                                         if (parsed > _selectedPresentation.stockActual) {
                                            _qtyCtrl.text = _selectedPresentation.stockActual.toString();
                                            CustomSnackBar.show(context, message: "Límite de stock alcanzado", isError: true);
                                         }
                                      }
                                      setState(() => _quantity = int.tryParse(_qtyCtrl.text) ?? _quantity);
                                    },
                                  ),
                                ),
                                IconButton(icon: Icon(Icons.add, color: isDark ? Colors.green[400] : Colors.green, size: 28), onPressed: () => _qtyAction(1, isClient)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (savings > 0) FittedBox(fit: BoxFit.scaleDown, child: Text("Ahorro Múltiple: ${currency.format(savings)}", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.green[400] : Colors.green))),
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
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text("⚠️ Producto agotado en inventario. Podrás guardar, pero se marcará como Pendiente de Stock.", style: textTheme.titleSmall?.copyWith(color: isDark ? Colors.red[300] : Colors.red[700])))
                else if (exceedsStock && !isClient) 
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text("⚠️ Supera el stock actual de ${_selectedPresentation.stockActual}. Se permitirá cotizar, pero requerirá reabastecimiento.", style: textTheme.titleSmall?.copyWith(color: isDark ? Colors.orange[400] : Colors.orange[800]))),
                
                const SizedBox(height: 35),

                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (_quantity > 0 && subtotal >= 0 && (!isClient || !exceedsStock)) ? _handleSave : null, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("CONFIRMAR PRODUCTO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}