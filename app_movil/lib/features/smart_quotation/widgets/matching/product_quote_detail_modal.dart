import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';

enum _PricingMode { normal, catalogOffer, manualDiscount }

class ProductQuoteDetailModal extends StatefulWidget {
  final InventoryWrapper wrapper; 
  final String? brandName; 
  final int currentQuantity;
  final double? currentOverridePrice; 
  final Function(ProductPresentation newPresentation, int newQty, double? newPrice, String? newName) onSave;
  final String? currentSnapshotName;
  final String? categoryName;
  final List<BundleModel>? availableBundles;
  final Map<int, List<BundleItemModel>>? bundleItemsCache;

  const ProductQuoteDetailModal({
    super.key,
    required this.wrapper,
    this.brandName,
    required this.currentQuantity,
    this.currentOverridePrice,
    required this.onSave,
    this.currentSnapshotName,
    this.categoryName,
    this.availableBundles,
    this.bundleItemsCache,
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

  _PricingMode _pricingMode = _PricingMode.normal;
  bool _isSyncing = false;
  
  int _getRealStock(ProductPresentation pres) {
    int factor = pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1;
    return pres.stockActual ~/ factor;
  }

  @override
  void initState() {
    super.initState();
    _selectedPresentation = widget.wrapper.presentation;
    
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final realStock = _getRealStock(_selectedPresentation);
    if (authProv.isCommunityClient && widget.currentQuantity > realStock) {
      _quantity = realStock > 0 ? realStock : 1;
    } else {
      _quantity = widget.currentQuantity;
    }

    _currentCategoryName = widget.categoryName ?? "";
    _qtyCtrl.text = _quantity.toString();

    _initializePricing();
    _loadFullProductDetails();
  }

  void _initializePricing() {
    final double basePrice = _selectedPresentation.precioVentaFinal;
    final bool hasOffer = _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0;
    final double offerPrice = hasOffer ? _selectedPresentation.precioOferta! : basePrice;

    double effectivePrice = widget.currentOverridePrice ?? (hasOffer ? offerPrice : basePrice);
    
    if (widget.currentOverridePrice != null) {
      if (widget.currentOverridePrice == offerPrice && hasOffer) {
        _pricingMode = _PricingMode.catalogOffer;
        _discountCtrl.text = (basePrice - offerPrice).toStringAsFixed(2);
      } else if (widget.currentOverridePrice == basePrice) {
        _pricingMode = _PricingMode.normal;
        _discountCtrl.text = "";
      } else {
        _pricingMode = _PricingMode.manualDiscount;
        double discount = basePrice - widget.currentOverridePrice!;
        _discountCtrl.text = discount > 0 ? discount.toStringAsFixed(2) : "";
      }
    } else {
      if (hasOffer) {
        _pricingMode = _PricingMode.catalogOffer;
        _discountCtrl.text = (basePrice - offerPrice).toStringAsFixed(2);
      } else {
        _pricingMode = _PricingMode.normal;
        _discountCtrl.text = "";
      }
    }
    
    _priceCtrl.text = effectivePrice.toStringAsFixed(2);
  }
  
  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
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


  double _getEffectivePrice() {
    switch (_pricingMode) {
      case _PricingMode.normal:
        return _selectedPresentation.precioVentaFinal;
      case _PricingMode.catalogOffer:
        return _selectedPresentation.precioOferta ?? _selectedPresentation.precioVentaFinal;
      case _PricingMode.manualDiscount:
        return double.tryParse(_priceCtrl.text) ?? _selectedPresentation.precioVentaFinal;
    }
  }

  void _onDiscountChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double basePrice = _selectedPresentation.precioVentaFinal;
    
    if (val.trim().isEmpty) {
      _priceCtrl.text = basePrice.toStringAsFixed(2);
      _isSyncing = false;
      setState(() {});
      return;
    }

    double disc = double.tryParse(val) ?? 0.0;
    if (disc < 0) disc = 0;
    if (disc > basePrice) {
      disc = basePrice;
      _discountCtrl.text = basePrice.toStringAsFixed(2);
    }

    double newPrice = basePrice - disc;
    _priceCtrl.text = newPrice.toStringAsFixed(2);
    _isSyncing = false;
    setState(() {}); 
  }

  void _onPriceChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double basePrice = _selectedPresentation.precioVentaFinal;
    
    if (val.trim().isEmpty) {
      _discountCtrl.text = "";
      _isSyncing = false;
      setState(() {});
      return;
    }

    double price = double.tryParse(val) ?? basePrice;
    if (price < 0) {
      price = 0;
      _priceCtrl.text = "0.00";
    }
    if (price > basePrice) {
      price = basePrice;
      _priceCtrl.text = basePrice.toStringAsFixed(2);
    }
    
    double disc = basePrice - price;
    _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
    _isSyncing = false;
    setState(() {}); 
  }

  void _qtyAction(int delta, bool isClient) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newQty = current + delta;
    
    if (newQty > 0) {
      final realStock = _getRealStock(_selectedPresentation);
      if (isClient && newQty > realStock) {
        CustomSnackBar.show(context, message: "Límite de stock alcanzado ($realStock disp.)", isError: true);
        return;
      }
      _qtyCtrl.text = newQty.toString();
      setState(() => _quantity = newQty);
    }
  }

  void _handleSave() {
    final double finalPrice = _getEffectivePrice();
    final double defaultSystemPrice = _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0 
        ? _selectedPresentation.precioOferta! 
        : _selectedPresentation.precioVentaFinal;

    final overridePrice = (finalPrice == defaultSystemPrice) ? null : finalPrice;
    
    widget.onSave(_selectedPresentation, _quantity, overridePrice, null);
    Navigator.pop(context);
  }

  List<BundleModel> _getApplicableBundles() {
    if (widget.availableBundles == null || widget.bundleItemsCache == null || _fullProduct == null) return [];
    
    List<BundleModel> applicable = [];
    for (var bundle in widget.availableBundles!) {
       final items = widget.bundleItemsCache![bundle.id] ?? [];
       if (items.any((item) => item.productoId == _fullProduct!.id)) {
           applicable.add(bundle);
       }
    }
    return applicable;
  }

  Widget _buildPricingSection(bool isDark, TextTheme textTheme, NumberFormat currency) {
    final basePrice = _selectedPresentation.precioVentaFinal;
    final hasOffer = _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0;
    final offerPrice = hasOffer ? _selectedPresentation.precioOferta! : basePrice;
    
    final applicableBundles = _getApplicableBundles();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Configuración de Precio", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[300] : Colors.grey[800])),
        const SizedBox(height: 12),
        
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A24) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
          ),
          child: Column(
            children: [
              _buildRadioOption(
                isDark: isDark,
                textTheme: textTheme,
                currency: currency,
                mode: _PricingMode.normal,
                title: "Precio Normal",
                subtitle: "Sin descuento aplicado",
                price: basePrice,
                activeColor: Colors.blue,
              ),
              
              if (hasOffer) ...[
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                _buildRadioOption(
                  isDark: isDark,
                  textTheme: textTheme,
                  currency: currency,
                  mode: _PricingMode.catalogOffer,
                  title: "Oferta de Catálogo",
                  subtitle: "Descuento individual activo",
                  price: offerPrice,
                  activeColor: Colors.green,
                ),
              ],
              
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
              _buildRadioOption(
                isDark: isDark,
                textTheme: textTheme,
                currency: currency,
                mode: _PricingMode.manualDiscount,
                title: "Precio Especial Manual",
                subtitle: "Aplica un descuento personalizado",
                price: null,
                activeColor: Colors.orange,
              ),
              
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _pricingMode == _PricingMode.manualDiscount ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: _buildManualDiscountUI(isDark, textTheme, currency, basePrice),
              )
            ],
          ),
        ),
        
        if (applicableBundles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text("Paquetes Disponibles", style: textTheme.titleSmall?.copyWith(color: isDark ? Colors.amber[300] : Colors.amber[800])),
          const SizedBox(height: 8),
          ...applicableBundles.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade200)
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.nombrePaquete, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.amber[200] : Colors.amber[900])),
                        Text("Se aplica automáticamente (Referencial)", style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.amber[100] : Colors.amber[800])),
                      ]
                    )
                  ),
                ]
              )
            )
          ))
        ]
      ],
    );
  }

  Widget _buildRadioOption({
    required bool isDark,
    required TextTheme textTheme,
    required NumberFormat currency,
    required _PricingMode mode,
    required String title,
    required String subtitle,
    required double? price,
    required MaterialColor activeColor,
  }) {
    final bool isSelected = _pricingMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _pricingMode = mode;
          if (mode == _PricingMode.manualDiscount) {
            if (_discountCtrl.text.isEmpty || (double.tryParse(_discountCtrl.text) ?? 0.0) == 0.0) {
              final double basePrice = _selectedPresentation.precioVentaFinal;
              final bool hasOffer = _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0;
              if (hasOffer) {
                final double offerPrice = _selectedPresentation.precioOferta!;
                _discountCtrl.text = (basePrice - offerPrice).toStringAsFixed(2);
                _priceCtrl.text = offerPrice.toStringAsFixed(2);
              } else {
                _priceCtrl.text = basePrice.toStringAsFixed(2);
              }
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? activeColor.withValues(alpha: 0.1) : activeColor.shade50) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Radio<_PricingMode>(
              value: mode,
              // ignore: deprecated_member_use
              groupValue: _pricingMode,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _pricingMode = v;
                    if (v == _PricingMode.manualDiscount) {
                      if (_discountCtrl.text.isEmpty || (double.tryParse(_discountCtrl.text) ?? 0.0) == 0.0) {
                        final double basePrice = _selectedPresentation.precioVentaFinal;
                        final bool hasOffer = _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0;
                        if (hasOffer) {
                          final double offerPrice = _selectedPresentation.precioOferta!;
                          _discountCtrl.text = (basePrice - offerPrice).toStringAsFixed(2);
                          _priceCtrl.text = offerPrice.toStringAsFixed(2);
                        } else {
                          _priceCtrl.text = basePrice.toStringAsFixed(2);
                        }
                      }
                    }
                  });
                }
              },
              activeColor: activeColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium?.copyWith(color: isSelected ? (isDark ? activeColor[300] : activeColor[900]) : (isDark ? Colors.white : Colors.black87))),
                  Text(subtitle, style: textTheme.bodySmall?.copyWith(color: isSelected ? (isDark ? activeColor[200] : activeColor[700]) : (isDark ? Colors.grey[500] : Colors.grey))),
                ],
              ),
            ),
            if (price != null)
              Text(currency.format(price), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isSelected ? (isDark ? activeColor[300] : activeColor[900]) : (isDark ? Colors.grey[400] : Colors.grey[700]))),
          ],
        ),
      ),
    );
  }

  Widget _buildManualDiscountUI(bool isDark, TextTheme textTheme, NumberFormat currency, double basePrice) {
    double currentDiscount = double.tryParse(_discountCtrl.text) ?? 0.0;
    double currentPrice = double.tryParse(_priceCtrl.text) ?? basePrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withValues(alpha: 0.05) : Colors.orange.shade50,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("S/ a Descontar", style: textTheme.labelLarge?.copyWith(color: isDark ? Colors.orange[300] : Colors.orange[900])),
                    TextField(
                      controller: _discountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: textTheme.headlineSmall?.copyWith(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(prefixText: "- ", prefixStyle: textTheme.headlineSmall?.copyWith(color: isDark ? Colors.orange[300] : Colors.orange[900]), isDense: true, border: InputBorder.none, hintText: "0.00"),
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
                    Text("Precio Final Unit.", style: textTheme.labelLarge?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[900])),
                    TextField(
                      controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: textTheme.headlineSmall?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue),
                      decoration: InputDecoration(prefixText: "S/ ", prefixStyle: textTheme.headlineSmall?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue), isDense: true, border: InputBorder.none),
                      onChanged: _onPriceChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: "Base: ", style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  TextSpan(text: currency.format(basePrice), style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                  TextSpan(text: " → Menos ", style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  TextSpan(text: currency.format(currentDiscount), style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[800])),
                  TextSpan(text: " = Final: ", style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  TextSpan(text: currency.format(currentPrice), style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                ]
              )
            )
          )
        ],
      ),
    );
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
    
    final basePrice = _selectedPresentation.precioVentaFinal;
    final hasOffer = _selectedPresentation.precioOferta != null && _selectedPresentation.precioOferta! > 0;
    final defaultSystemPrice = hasOffer ? _selectedPresentation.precioOferta! : basePrice;

    final unitPrice = _getEffectivePrice();
    final subtotal = unitPrice * _quantity;
    final originalTotal = defaultSystemPrice * _quantity;
    final savings = originalTotal - subtotal;

    final realStock = _getRealStock(_selectedPresentation);
    bool isStockEmpty = realStock <= 0;
    bool exceedsStock = _quantity > realStock && !isStockEmpty;

    String snapshot = widget.currentSnapshotName?.trim() ?? "";
    String currentBuiltName = "${productDisplay.nombre} ${_selectedPresentation.nombreEspecifico ?? ''}".trim();
    bool isNameChanged = snapshot.isNotEmpty && 
                         currentBuiltName.toLowerCase() != snapshot.toLowerCase() &&
                         !snapshot.toLowerCase().contains("nuevo ítem");

    // Increased height to accommodate offers section
    final double initialSize = isClient ? 0.65 : 0.70;
    final double maxSize = isClient ? 0.80 : 0.85;

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
                    decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
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
                            Container(width: 90, height: 90, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black.withValues(alpha: 0.2))),
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
                            Text(widget.brandName!.toUpperCase(), style: TextStyle(fontSize: 12, color: isDark ? Colors.indigo[300] : Colors.indigo[800], fontWeight: FontWeight.w800, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                          
                          const SizedBox(height: 2),
                          
                          RichText(
                             maxLines: 4,
                             overflow: TextOverflow.ellipsis,
                             text: TextSpan(
                               children: [
                                 TextSpan(text: "${productDisplay.nombre} ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, height: 1.2)),
                                 if (_selectedPresentation.nombreEspecifico != null && _selectedPresentation.nombreEspecifico!.isNotEmpty)
                                   TextSpan(text: _selectedPresentation.nombreEspecifico!, style: TextStyle(fontSize: 18, color: isDark ? Colors.teal[300] : Colors.teal[700], height: 1.2)),
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
                                decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text("${_selectedPresentation.unidadVenta ?? 'Unidad'} (x${_selectedPresentation.unidadesPorVenta})", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[700])),
                              ),
                              if (_currentCategoryName.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                  child: Text(_currentCategoryName, style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.grey[300] : Colors.grey[700])),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(isStockEmpty ? "Agotado (0)" : "Stock disponible: $realStock ${_selectedPresentation.unidadVenta ?? 'Unidad'}", style: textTheme.bodySmall?.copyWith(color: isStockEmpty ? (isDark ? Colors.red[400] : Colors.red) : (isDark ? Colors.green[400] : Colors.green), fontWeight: FontWeight.bold)),
                          ),
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
                        final realVariantStock = _getRealStock(p);
                        final isOutOfStockVariant = realVariantStock <= 0;
                        final isDisabled = isClient && isOutOfStockVariant;

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${p.unidadVenta ?? 'Unidad'} - ${currency.format(p.precioVentaFinal)}", style: textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                const SizedBox(width: 6),
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOutOfStockVariant ? Colors.red : (realVariantStock < 10 ? Colors.orange : Colors.green)))
                              ],
                            ), 
                            selected: isSelected, 
                            onSelected: isDisabled ? null : (v) {
                              if (v) {
                                setState(() {
                                  _selectedPresentation = p;
                                  _initializePricing();
                                  
                                  if (isClient && _quantity > realVariantStock) {
                                     _quantity = realVariantStock > 0 ? realVariantStock : 1;
                                     _qtyCtrl.text = _quantity.toString();
                                  }
                                });
                              }
                            }, 
                            selectedColor: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue[100],
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

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: (!_isLoading && !isClient) ? _buildPricingSection(isDark, textTheme, currency) : const SizedBox.shrink(),
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
                                         final realStock = _getRealStock(_selectedPresentation);
                                         if (parsed > realStock) {
                                            _qtyCtrl.text = realStock.toString();
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
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text("⚠️ Supera el stock actual de $realStock. Se permitirá cotizar, pero requerirá reabastecimiento.", style: textTheme.titleSmall?.copyWith(color: isDark ? Colors.orange[400] : Colors.orange[800]))),
                
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