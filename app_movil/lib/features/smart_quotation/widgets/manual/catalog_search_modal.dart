import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../providers/manual_quote_provider.dart'; 

// Modelos y Widgets
import '../../../../../models/inventory_wrapper.dart';
import '../../models/matching_model.dart';
import '../../../../../widgets/universal_image.dart';
import '../../../../../widgets/custom_snackbar.dart';
import 'manual_quote_detail_modal.dart';

class CatalogSearchModal extends StatefulWidget {
  final Function(MatchedProduct, int, double?, String?) onAddProduct;

  const CatalogSearchModal({super.key, required this.onAddProduct});

  @override
  State<CatalogSearchModal> createState() => _CatalogSearchModalState();
}

class _CatalogSearchModalState extends State<CatalogSearchModal> {
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  String _cleanName(String rawName) {
    return rawName.replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🔥 CORRECCIÓN 1: El ProxyProvider ya inyectó el contexto, 
      // solo iniciamos la carga de productos de frente.
      final quoteProv = Provider.of<ManualQuoteProvider>(context, listen: false);
      quoteProv.init();
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final prov = Provider.of<ManualQuoteProvider>(context, listen: false);
      if (!prov.isLoading && prov.hasMoreData) {
        prov.loadProducts(); 
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () { 
      Provider.of<ManualQuoteProvider>(context, listen: false).setSearchQuery(query);
    });
  }

  void _openDetail(InventoryWrapper wrapper, String brandName, String catName) {
    final prod = wrapper.product;
    final pres = wrapper.presentation;

    // Bloqueo de producto sin stock.
    if (pres.stockActual <= 0) {
      CustomSnackBar.show(
        context, 
        message: "Este producto está temporalmente agotado. Intenta con otra variante o marca.", 
        isError: true,
        icon: Icons.production_quantity_limits
      );
      return;
    }
    
    String cleanProd = _cleanName(prod.nombre);
    String cleanSpec = _cleanName(pres.nombreEspecifico ?? "");
    
    String fullNameBuilder = cleanProd;
    if (cleanSpec.isNotEmpty && !cleanProd.toLowerCase().contains(cleanSpec.toLowerCase())) {
       fullNameBuilder += " $cleanSpec";
    }

    final matched = MatchedProduct(
      productId: prod.id,
      presentationId: pres.id ?? 0, 
      fullName: fullNameBuilder,
      productName: prod.nombre,
      specificName: pres.nombreEspecifico,
      brand: brandName,
      price: pres.precioVentaFinal, 
      offerPrice: pres.precioOferta,
      stock: pres.stockActual,
      imageUrl: pres.imagenUrl ?? prod.imagenUrl,
      unit: pres.unidadVenta ?? "Unidad", 
      conversionFactor: pres.unidadesPorVenta, 
    );

    final provider = Provider.of<ManualQuoteProvider>(context, listen: false);
    final categoryName = provider.getCategoryName(prod.categoriaId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualQuoteDetailModal(
        product: matched,
        initialQty: 1,
        initialCustomName: fullNameBuilder,
        categoryName: categoryName,
        isNewAddition: true, 
        onConfirm: (finalProd, qty, price, name) {
          widget.onAddProduct(finalProd, qty, price, name);
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ManualQuoteProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9, 
      decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          // 1. Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: false,
                    style: TextStyle(color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre, marca...",
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.blue, size: 24),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14141C) : Colors.blue[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: _searchCtrl.text.isNotEmpty 
                        ? IconButton(
                            icon: Icon(Icons.clear, color: isDark ? Colors.white70 : Colors.grey),
                            onPressed: () {
                              _searchCtrl.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black54, size: 28), 
                  onPressed: () => Navigator.pop(context)
                )
              ],
            ),
          ),
          
          // 2. Filtros de Categoría
          if (provider.categories.isNotEmpty)
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: provider.categories.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    final isSelected = provider.selectedCategoryId == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: const Text("Todos", style: TextStyle(fontSize: 15)),
                        selected: isSelected,
                        onSelected: (v) => provider.selectCategory(null),
                        selectedColor: isDark ? Colors.blue[300] : Colors.blue[800],
                        labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.black87 : Colors.white) : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey.shade300))),
                      ),
                    );
                  }
                  
                  final cat = provider.categories[i - 1];
                  final isSelected = cat.id == provider.selectedCategoryId;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(cat.nombre, style: const TextStyle(fontSize: 15)),
                      selected: isSelected,
                      onSelected: (v) => provider.selectCategory(cat.id),
                      selectedColor: isDark ? Colors.blue[300] : Colors.blue[800],
                      labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.black87 : Colors.white) : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey.shade300))),
                    ),
                  );
                },
              ),
            ),
          
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200])),

          // 3. Contador de Resultados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text("${provider.resultsCount} productos encontrados", style: textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
                if (provider.isLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                ]
              ],
            ),
          ),

          // 4. Lista de Resultados
          Expanded(
            child: provider.searchResults.isEmpty && !provider.isLoading
              ? _buildEmptyState(isDark, textTheme)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: provider.searchResults.length + (provider.hasMoreData && !provider.isLoading ? 0 : 0),
                  itemBuilder: (ctx, i) {
                    if (i >= provider.searchResults.length) return const SizedBox.shrink();

                    final wrapper = provider.searchResults[i];
                    final prod = wrapper.product;
                    final pres = wrapper.presentation;
                    
                    final brandName = provider.getBrandName(prod.marcaId);
                    final catName = provider.getCategoryName(prod.categoriaId); 
                    
                    Color stockColor = isDark ? Colors.green[400]! : Colors.green;
                    String stockText = "${pres.stockActual} disp.";
                    bool isOutOfStock = false;
                    
                    if (pres.stockActual <= 0) {
                      stockColor = isDark ? Colors.red[400]! : Colors.red;
                      stockText = "Agotado";
                      isOutOfStock = true;
                    } else if (pres.stockActual <= 5) {
                      stockColor = isDark ? Colors.orange[400]! : Colors.orange;
                      stockText = "¡Últimos ${pres.stockActual}!";
                    }

                    String cleanProd = _cleanName(prod.nombre);
                    String cleanSpec = _cleanName(pres.nombreEspecifico ?? "");

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: isDark ? 0 : 2,
                      color: isDark 
                        ? (isOutOfStock ? const Color(0xFF1A1A24).withOpacity(0.5) : const Color(0xFF14141C)) 
                        : (isOutOfStock ? Colors.grey.shade50 : Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
                      child: InkWell(
                        onTap: () => _openDetail(wrapper, brandName, catName),
                        borderRadius: BorderRadius.circular(16),
                        child: Opacity(
                          opacity: isOutOfStock ? 0.5 : 1.0, 
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
                                    color: isDark ? Colors.white10 : Colors.white,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: UniversalImage(path: pres.imagenUrl ?? prod.imagenUrl, fit: BoxFit.contain),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (brandName.isNotEmpty)
                                        Text(brandName.toUpperCase(), style: textTheme.labelMedium?.copyWith(color: isDark ? Colors.indigo[300] : Colors.indigo[900])),
                                      const SizedBox(height: 2),
                                      
                                      RichText(
                                         maxLines: 2,
                                         overflow: TextOverflow.ellipsis,
                                         text: TextSpan(
                                           children: [
                                             TextSpan(text: "$cleanProd ", style: textTheme.titleMedium?.copyWith(color: textColor)),
                                             if (cleanSpec.isNotEmpty)
                                               TextSpan(text: cleanSpec, style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w600)),
                                           ],
                                         ),
                                       ),
                                      
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 6,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text("${pres.unidadVenta ?? 'Unidad'} (x${pres.unidadesPorVenta})", style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[800], fontWeight: FontWeight.bold)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: stockColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: stockColor.withOpacity(0.4))),
                                            child: Text(stockText, style: textTheme.labelSmall?.copyWith(color: stockColor)),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.end,
                                              spacing: 6,
                                              children: [
                                                if (pres.precioOferta != null && pres.precioOferta! > 0)
                                                  Text("S/ ${pres.precioVentaFinal.toStringAsFixed(2)}", style: textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text("S/ ${(pres.precioOferta ?? pres.precioVentaFinal).toStringAsFixed(2)}", style: textTheme.titleLarge?.copyWith(color: (pres.precioOferta != null && pres.precioOferta! > 0) ? (isDark ? Colors.red[300] : Colors.red) : (isDark ? Colors.blue[300] : Colors.blue[900]))),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(isOutOfStock ? Icons.cancel_outlined : Icons.add_circle_outline, color: isOutOfStock ? Colors.grey : (isDark ? Colors.blue[300] : Colors.blue[700]), size: 28)
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, TextTheme theme) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
        const SizedBox(height: 16),
        Text("No se encontraron productos", style: theme.titleMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey)),
        const SizedBox(height: 8),
        Text("Prueba con otra palabra clave", style: theme.bodyMedium?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey)),
      ],
    ));
  }
}