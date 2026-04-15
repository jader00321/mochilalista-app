import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/inventory_provider.dart';
import '../../../../providers/auth_provider.dart'; // 🔥 Importado para el Rol
import '../../models/matching_model.dart';
import '../../../../models/inventory_wrapper.dart';
import '../../../../widgets/universal_image.dart';
import '../../../../widgets/custom_snackbar.dart';

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
  Timer? _debounce;
  List<InventoryWrapper> _mappedResults = []; 
  int? _selectedCategoryId; 

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      final prov = Provider.of<InventoryProvider>(context, listen: false);
      prov.loadMasterData(showAll: false).then((_) {
         _performSearch(widget.initialQuery, reset: true); 
      });
    });
    
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        final prov = Provider.of<InventoryProvider>(context, listen: false);
        if (!prov.isLoadingMore && prov.hasMoreData) prov.loadMore().then((_) => _updateMappedResults());
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _performSearch(query, reset: true));
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _performSearch(_searchCtrl.text, reset: true);
  }

  Future<void> _performSearch(String query, {bool reset = false}) async {
    final prov = Provider.of<InventoryProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false); // 🔥 Obtener rol
    await prov.loadInventory(
      searchQuery: query, 
      reset: reset,
      minStock: auth.isCommunityClient ? 1 : null, // 🔥 FILTRO: Solo muestra stock si es cliente
      categoryIds: _selectedCategoryId != null ? [_selectedCategoryId!] : null 
    );
    _updateMappedResults();
  }

  void _updateMappedResults() {
    if (!mounted) return;
    final prov = Provider.of<InventoryProvider>(context, listen: false);
    setState(() {
      _mappedResults = prov.items; 
    });
  }

  String _cleanName(String rawName) {
    return rawName.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Color _getStockColor(int stock) {
    if (stock <= 0) return widget.isDark ? Colors.red[300]! : Colors.red;
    if (stock < 10) return widget.isDark ? Colors.orange[300]! : Colors.orange;
    return widget.isDark ? Colors.green[400]! : Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<InventoryProvider>(context);
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
                      suffixIcon: IconButton(icon: Icon(Icons.clear, color: widget.isDark ? Colors.white70 : Colors.grey), onPressed: () { _searchCtrl.clear(); _performSearch("", reset: true); })
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(icon: Icon(Icons.close, color: widget.isDark ? Colors.white : Colors.black54, size: 28), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),

          if (prov.categories.isNotEmpty)
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: prov.categories.length + 1,
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
                  
                  final cat = prov.categories[i - 1];
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
            child: prov.isLoading && _mappedResults.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _mappedResults.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: widget.isDark ? Colors.white10 : Colors.grey[300]), const SizedBox(height: 16), Text("No se encontraron productos", style: textTheme.titleMedium?.copyWith(color: widget.isDark ? Colors.grey[500] : Colors.grey))]))
                : ListView.separated(
                    controller: _scrollCtrl, padding: const EdgeInsets.all(20), itemCount: _mappedResults.length + (prov.isLoadingMore ? 1 : 0), separatorBuilder: (_, __) => Divider(height: 20, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
                    itemBuilder: (ctx, i) {
                      if (i == _mappedResults.length) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                      
                      final wrapper = _mappedResults[i];
                      final prod = wrapper.product;
                      final pres = wrapper.presentation;
                      
                      final brandName = prov.getBrandName(prod.marcaId);
                      final catName = prov.getCategoryName(prod.categoriaId); 
                      
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
                                    decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text("${matched.unit.toUpperCase()} (x${matched.conversionFactor})", style: textTheme.labelSmall?.copyWith(color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
                                  ),
                                  if (catName.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: widget.isDark ? Colors.grey.withOpacity(0.15) : Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
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
                            decoration: BoxDecoration(color: stockColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
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