import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../models/inventory_wrapper.dart';
import 'universal_image.dart';

class ManualProductSearch extends StatefulWidget {
  final Function(InventoryWrapper) onSelect;

  const ManualProductSearch({super.key, required this.onSelect});

  @override
  State<ManualProductSearch> createState() => _ManualProductSearchState();
}

class _ManualProductSearchState extends State<ManualProductSearch> {
  final TextEditingController _searchCtrl = TextEditingController();
  
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _performServerSearch(""); 
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return; 
      _performServerSearch(query);
    });
  }

  Future<void> _performServerSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    await Provider.of<InventoryProvider>(context, listen: false).loadInventory(
      reset: true, 
      searchQuery: query
    );

    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invProv = Provider.of<InventoryProvider>(context);
    final results = invProv.items; 
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
              boxShadow: [if(!isDark) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]
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
                    "${results.length} resultados encontrados",
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
          
          // LISTA DE RESULTADOS
          Expanded(
            child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : results.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 60, color: isDark ? Colors.white10 : Colors.grey[300]), const SizedBox(height: 16), Text("No se encontraron coincidencias", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))]))
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildResultCard(results[i], isDark),
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

    // 🔥 USANDO LA NUEVA UMP DE COMPRA
    String variantDisplay = pres.umpCompra ?? "Unidad";
    if (pres.nombreEspecifico != null && pres.nombreEspecifico!.isNotEmpty) {
        variantDisplay += " - ${pres.nombreEspecifico}";
    }

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
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]
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
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50], borderRadius: BorderRadius.circular(6)), child: Text(categoria.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[800], letterSpacing: 0.5))),
                      const SizedBox(width: 8),
                      Text(marca, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(prod.nombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(variantDisplay, style: TextStyle(fontSize: 14, color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.layers, size: 18, color: pres.stockActual > 0 ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.red[400] : Colors.red)),
                      const SizedBox(width: 6),
                      Text("Stock: ${pres.stockActual}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pres.stockActual > 0 ? (isDark ? Colors.green[300] : Colors.green[700]) : (isDark ? Colors.red[300] : Colors.red[700]))),
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