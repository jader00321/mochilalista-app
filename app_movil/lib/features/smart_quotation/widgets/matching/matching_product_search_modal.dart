import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/services/product_service.dart';
import 'package:app_movil/core/services/master_data_cache.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class MatchingProductSearchModal extends StatefulWidget {
  final String initialQuery;
  final bool isDark;
  final Function(MatchedProduct, String) onProductSelected;

  const MatchingProductSearchModal({
    super.key,
    required this.initialQuery,
    required this.isDark,
    required this.onProductSelected
  });

  @override
  State<MatchingProductSearchModal> createState() => _MatchingProductSearchModalState();
}

class _MatchingProductSearchModalState extends State<MatchingProductSearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ProductService _productService = ProductService();
  
  Timer? _debounce;
  List<InventoryWrapper> _localResults = []; 
  List<Category> _categories = [];
  int? _selectedCategoryId; 
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 20;
  String _currentQuery = "";

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery;
    _currentQuery = widget.initialQuery;
    
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      if (invProv.negocioId != null) {
        _productService.updateContext(invProv.negocioId);
      }
      _categories = MasterDataCache().categories;
      _performSearch(_currentQuery, reset: true); 
    });
    
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore && !_isLoading) {
           _performSearch(_currentQuery, reset: false);
        }
      }
    });
  }
  
  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _currentQuery = query;
        _performSearch(query, reset: true);
    });
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _performSearch(_currentQuery, reset: true);
  }

  Future<void> _performSearch(String query, {required bool reset}) async {
    if (!mounted) return;

    if (reset) {
      setState(() {
        _isLoading = true;
        _skip = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false); 
      
      Map<String, String> queryParams = {
        'skip': _skip.toString(),
        'limit': _limit.toString(),
      };
      
      if (query.isNotEmpty) queryParams['q'] = query;
      if (_selectedCategoryId != null) queryParams['category_ids'] = _selectedCategoryId.toString();
      if (auth.isCommunityClient) queryParams['min_stock'] = "1";
      
      final newItems = await _productService.fetchInventory(queryParams);
      
      if (!mounted) return;
      
      if (newItems != null) {
        setState(() {
          if (newItems.length < _limit) {
            _hasMore = false;
          }
          if (reset) {
            _localResults = newItems;
          } else {
            _localResults.addAll(newItems);
          }
          _skip += newItems.length;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  String _cleanName(String rawName) {
    return rawName.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Color _getStockColor(int stock) {
    if (stock <= 0) return widget.isDark ? Colors.red[300]! : Colors.red;
    if (stock < 10) return widget.isDark ? Colors.orange[300]! : Colors.orange;
    return widget.isDark ? Colors.green[400]! : Colors.green;
  }
  
  String _getBrandName(int? id) {
     if (id == null) return "";
     final list = MasterDataCache().brands.where((b) => b.id == id).toList();
     return list.isNotEmpty ? list.first.nombre : "";
  }
  
  String _getCategoryName(int? id) {
     if (id == null) return "";
     final list = _categories.where((c) => c.id == id).toList();
     return list.isNotEmpty ? list.first.nombre : "";
  }

  @override
  Widget build(BuildContext context) {
    final isClient = Provider.of<AuthProvider>(context, listen: false).isCommunityClient;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl, autofocus: true,
                    style: textTheme.bodyLarge?.copyWith(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Buscar producto...", 
                      hintStyle: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey),
                      prefixIcon: Icon(Icons.search, color: widget.isDark ? Colors.blue[300] : Colors.blue, size: 24), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), 
                      filled: true, 
                      fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], 
                      suffixIcon: IconButton(icon: Icon(Icons.clear, color: widget.isDark ? Colors.white70 : Colors.grey), onPressed: () { _searchCtrl.clear(); _currentQuery = ""; _performSearch("", reset: true); })
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(icon: Icon(Icons.close, color: widget.isDark ? Colors.white : Colors.black54, size: 28), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),

          if (_categories.isNotEmpty)
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    final isSelected = _selectedCategoryId == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: const Text("Todos", style: TextStyle(fontSize: 15)),
                        selected: isSelected,
                        onSelected: (v) => _onCategorySelected(null),
                        selectedColor: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                        labelStyle: TextStyle(color: isSelected ? (widget.isDark ? Colors.black87 : Colors.white) : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        backgroundColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : (widget.isDark ? Colors.white24 : Colors.grey.shade300))),
                      ),
                    );
                  }
                  
                  final cat = _categories[i - 1];
                  final isSelected = cat.id == _selectedCategoryId;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(cat.nombre, style: const TextStyle(fontSize: 15)),
                      selected: isSelected,
                      onSelected: (v) => _onCategorySelected(cat.id),
                      selectedColor: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                      labelStyle: TextStyle(color: isSelected ? (widget.isDark ? Colors.black87 : Colors.white) : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      backgroundColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : (widget.isDark ? Colors.white24 : Colors.grey.shade300))),
                    ),
                  );
                },
              ),
            ),
          
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey[200])),

          Expanded(
            child: _isLoading && _localResults.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _localResults.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: widget.isDark ? Colors.white10 : Colors.grey[300]), const SizedBox(height: 16), Text("No se encontraron productos", style: textTheme.titleMedium?.copyWith(color: widget.isDark ? Colors.grey[500] : Colors.grey))]))
                : ListView.separated(
                    controller: _scrollCtrl, padding: const EdgeInsets.all(20), itemCount: _localResults.length + (_isLoadingMore ? 1 : 0), separatorBuilder: (_, __) => Divider(height: 20, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
                    itemBuilder: (ctx, i) {
                      if (i == _localResults.length) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                      
                      final wrapper = _localResults[i];
                      final prod = wrapper.product;
                      final pres = wrapper.presentation;
                      
                      final brandName = _getBrandName(prod.marcaId);
                      final catName = _getCategoryName(prod.categoriaId); 
                      
                      final hasOffer = pres.precioOferta != null && pres.precioOferta! > 0;
                      Color stockColor = _getStockColor(pres.stockActual);
                      String stockText = pres.stockActual > 0 ? "Stock: ${pres.stockActual}" : "AGOTADO";

                      String cleanProd = _cleanName(prod.nombre);
                      String cleanSpec = _cleanName(pres.nombreEspecifico ?? "");
                      
                      String fullNameBuilder = cleanProd;
                      if (cleanSpec.isNotEmpty && !cleanProd.toLowerCase().contains(cleanSpec.toLowerCase())) {
                        fullNameBuilder += " $cleanSpec";
                      }

                      final matched = MatchedProduct(
                        productId: prod.id, 
                        presentationId: pres.id!, 
                        fullName: fullNameBuilder, 
                        productName: prod.nombre, 
                        specificName: pres.nombreEspecifico, 
                        brand: brandName, 
                        price: pres.precioVentaFinal, 
                        offerPrice: hasOffer ? pres.precioOferta : null, 
                        stock: pres.stockActual, 
                        imageUrl: pres.imagenUrl ?? prod.imagenUrl, 
                        unit: pres.unidadVenta ?? "Unidad", 
                        conversionFactor: pres.unidadesPorVenta
                      );

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          width: 60, height: 60, 
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: widget.isDark ? Colors.white10 : Colors.grey[100]), 
                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: UniversalImage(path: matched.imageUrl, fit: BoxFit.contain))
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (matched.brand != null && matched.brand!.isNotEmpty)
                              Text(matched.brand!.toUpperCase(), style: textTheme.labelMedium?.copyWith(color: widget.isDark ? Colors.indigo[300] : Colors.indigo[600])),
                            
                            RichText(
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                               text: TextSpan(
                                 children: [
                                   TextSpan(text: "${matched.productName} ", style: textTheme.titleMedium?.copyWith(color: textColor)),
                                   if (matched.specificName != null && matched.specificName!.isNotEmpty)
                                     TextSpan(text: matched.specificName!, style: textTheme.titleMedium?.copyWith(color: widget.isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w600)),
                                 ],
                               ),
                             ),
                          ]
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text("${matched.unit.toUpperCase()} (x${matched.conversionFactor})", style: textTheme.labelSmall?.copyWith(color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
                                  ),
                                  if (catName.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: widget.isDark ? Colors.grey.withValues(alpha: 0.15) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                      child: Text(catName, style: textTheme.labelSmall?.copyWith(color: widget.isDark ? Colors.grey[400] : Colors.grey[700])),
                                    ),
                                ],
                              ),
                              if (matched.offerPrice != null) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [Text("S/ ${matched.price.toStringAsFixed(2)}", style: textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: widget.isDark ? Colors.grey[500] : Colors.grey)), const SizedBox(width: 6), Text("Oferta", style: textTheme.labelMedium?.copyWith(color: widget.isDark ? Colors.red[300] : Colors.red[700]))]))
                            ]
                          ),
                        ),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text("S/ ${(matched.offerPrice ?? matched.price).toStringAsFixed(2)}", style: textTheme.displaySmall?.copyWith(color: widget.isDark ? Colors.blue[300] : Colors.blue)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: stockColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text(stockText, style: textTheme.labelSmall?.copyWith(color: stockColor))
                          ),
                        ]),
                        onTap: () {
                          if (isClient && pres.stockActual <= 0) {
                              CustomSnackBar.show(context, message: "Este producto está agotado y no puede agregarse al pedido.", isError: true);
                              return;
                          }
                          widget.onProductSelected(matched, catName);
                        }
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}