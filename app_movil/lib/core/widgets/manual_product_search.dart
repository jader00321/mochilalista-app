import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/services/product_service.dart';

class ManualProductSearch extends StatefulWidget {
  final Function(InventoryWrapper) onSelect;

  const ManualProductSearch({super.key, required this.onSelect});

  @override
  State<ManualProductSearch> createState() => _ManualProductSearchState();
}

class _ManualProductSearchState extends State<ManualProductSearch> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ProductService _productService = ProductService();
  
  List<InventoryWrapper> _localResults = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 50;
  String _currentQuery = "";
  
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Inject negocioId immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      _productService.updateContext(invProv.negocioId);
      _performSearch("", reset: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore && !_isSearching) {
          _performSearch(_currentQuery, reset: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
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

  Future<void> _performSearch(String query, {required bool reset}) async {
    if (!mounted) return;
    
    if (reset) {
      setState(() {
        _isSearching = true;
        _skip = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final newItems = await _productService.fetchInventory({
        'q': query.isEmpty ? null : query,
        'skip': _skip,
        'limit': _limit,
      });

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
          _isSearching = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: (MediaQuery.of(context).size.height * 0.8) + bottomInset,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [if(!isDark) BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: Column(
              children: [
                Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                Text("Vincular con Existente", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Buscar: nombre, marca, categoría...",
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.blue),
                    filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    suffixIcon: _isSearching 
                        ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(strokeWidth: 3)) 
                        : null
                  ),
                  onChanged: _onSearchChanged,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    "${_localResults.length} resultados encontrados",
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
          
          // LISTA DE RESULTADOS
          Expanded(
            child: _isSearching && _localResults.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _localResults.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 60, color: isDark ? Colors.white10 : Colors.grey[300]), const SizedBox(height: 16), Text("No se encontraron coincidencias", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))]))
                  : ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
                      itemCount: _localResults.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        if (i == _localResults.length) {
                          return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
                        }
                        return _buildResultCard(_localResults[i], isDark);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(InventoryWrapper wrapper, bool isDark) {
    final prod = wrapper.product;
    final pres = wrapper.presentation;
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    
    String categoria = invProv.getCategoryName(prod.categoriaId);
    String marca = invProv.getBrandName(prod.marcaId);
    if (marca.isEmpty) marca = "Genérica";

    final String? imgUrl = pres.imagenUrl ?? prod.imagenUrl;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: () => widget.onSelect(wrapper),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: UniversalImage(path: imgUrl, fit: BoxFit.contain)
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CAMBIO FASE 1: Destacar la marca visualmente.
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withValues(alpha: 0.15) : Colors.blueGrey[50], borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.branding_watermark, size: 10, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700]), const SizedBox(width: 4), Text(marca, style: TextStyle(fontSize: 11, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[800], fontWeight: FontWeight.w900, letterSpacing: 0.5))])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange[50], borderRadius: BorderRadius.circular(6)), child: Text(categoria.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[800], letterSpacing: 0.5))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Nombres principal y específico seguidos
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: prod.nombre,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor, height: 1.2),
                        ),
                        if (pres.nombreEspecifico != null && pres.nombreEspecifico!.isNotEmpty) ...[
                          TextSpan(
                            text: ' - ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor, height: 1.2),
                          ),
                          TextSpan(
                            text: pres.nombreEspecifico,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue[300] : Colors.blue[800], height: 1.2),
                          ),
                        ]
                      ]
                    )
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                        child: Text(pres.umpCompra ?? "Unidad", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers, size: 16, color: wrapper.displayStock > 0 ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.red[400] : Colors.red)),
                          const SizedBox(width: 4),
                          Text(wrapper.displayStock > 0 ? "Stock: ${wrapper.displayStockText}" : "Agotado", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: wrapper.displayStock > 0 ? (isDark ? Colors.green[300] : Colors.green[700]) : (isDark ? Colors.red[300] : Colors.red[700]))),
                        ],
                      ),
                      Text("P.Venta: S/${pres.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    ],
                  )
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => widget.onSelect(wrapper),
                  style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.green[700] : Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text("Vincular", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}