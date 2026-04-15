import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';

class CustomSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback onFilterTap;

  const CustomSearchBar({super.key, required this.onSearch, required this.onFilterTap});

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce; 

  @override
  void dispose() {
    _debounce?.cancel(); 
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 600), () {
      widget.onSearch(query);
    });
  }

  void _submitSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    widget.onSearch(_controller.text.trim());
    FocusScope.of(context).unfocus();
  }

  void _toggleCategory(int categoryId, bool isSelected, InventoryProvider provider) {
    List<int> currentIds = List.from(provider.activeCategoryIds);
    if (isSelected) {
      currentIds.add(categoryId);
    } else {
      currentIds.remove(categoryId);
    }
    provider.loadInventory(
      reset: true,
      searchQuery: provider.activeQuery, 
      categoryIds: currentIds,
      brandIds: provider.activeBrandIds,
      providerIds: provider.activeProviderIds,
      filterState: provider.activeState,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_controller.text != provider.activeQuery) {
      if (!FocusScope.of(context).hasFocus || provider.activeQuery.isEmpty) {
         _controller.text = provider.activeQuery;
         _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      }
    }

    // Comprobamos si existe algún filtro activo
    bool hasFilters = provider.activeCategoryIds.isNotEmpty || 
                      provider.activeBrandIds.isNotEmpty || 
                      provider.activeProviderIds.isNotEmpty ||
                      provider.activeState != null ||
                      provider.activeHasOffer ||
                      provider.activeOnlyDefaults ||
                      provider.activeMinPrice != null ||
                      provider.activeMinStock != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CAMPO DE TEXTO Y BOTONES DE FILTRO MEJORADOS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF23232F) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submitSearch(),
                    onChanged: _onSearchChanged, 
                    style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: "Buscar producto, marca, código...",
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color.fromARGB(255, 165, 165, 165), fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider.isLoading)
                            Transform.scale(
                              scale: 0.5, 
                              child: CircularProgressIndicator(strokeWidth: 3, color: isDark ? Colors.blue[300] : theme.primaryColor)
                            ),
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey),
                              onPressed: () {
                                _controller.clear();
                                provider.loadInventory(reset: true, searchQuery: "");
                              },
                            ),
                          if (!provider.isLoading && _controller.text.isEmpty)
                            IconButton(
                              icon: Icon(Icons.search, color: isDark ? Colors.blue[300] : theme.primaryColor, size: 24),
                              onPressed: _submitSearch,
                              tooltip: "Buscar",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // BOTÓN LIMPIAR FILTROS (Aparece dinámicamente)
              if (hasFilters) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: () {
                    _controller.clear();
                    provider.loadInventory(
                      reset: true,
                      searchQuery: "",
                      categoryIds: [],
                      brandIds: [],
                      providerIds: [],
                      filterState: null,
                      minPrice: null, maxPrice: null,
                      minStock: null, maxStock: null,
                      hasOffer: false, onlyDefaults: false
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 50, width: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.red.withOpacity(0.4) : Colors.red.withOpacity(0.3))
                    ),
                    child: Icon(Icons.cleaning_services_rounded, color: isDark ? Colors.red[300] : Colors.red, size: 24),
                  ),
                ),
              ],
              
              const SizedBox(width: 10),
              
              // BOTÓN DEL FILTER DRAWER (Diseño mejorado)
              InkWell(
                onTap: widget.onFilterTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 50, width: 50,
                  decoration: BoxDecoration(
                    color: hasFilters ? (isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50) : (isDark ? Colors.blue[800] : Colors.blue.shade100),
                    borderRadius: BorderRadius.circular(14),
                    border: hasFilters ? Border.all(color: isDark ? Colors.orange.withOpacity(0.5) : Colors.orange.shade300) : null,
                  ),
                  child: Icon(
                    hasFilters ? Icons.tune_rounded : Icons.filter_alt_rounded, 
                    color: hasFilters ? (isDark ? Colors.orange[300] : Colors.orange[800]) : (isDark ? Colors.white : Colors.blue[800]), 
                    size: 26
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. CHIPS DE CATEGORÍA
        if (provider.categories.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: provider.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final cat = provider.categories[index];
                final isSelected = provider.activeCategoryIds.contains(cat.id);

                return FilterChip(
                  label: Text(cat.nombre),
                  selected: isSelected,
                  onSelected: (val) => _toggleCategory(cat.id, val, provider),
                  showCheckmark: false,
                  backgroundColor: isDark ? Colors.white10 : Colors.white.withOpacity(0.2), 
                  selectedColor: isDark ? Colors.blue.withOpacity(0.3) : const Color.fromARGB(255, 230, 230, 230), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.transparent) : Colors.transparent), 
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? (isDark ? Colors.blue[200] : theme.primaryColor) : (isDark ? Colors.white70 : const Color.fromARGB(255, 48, 48, 48)),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}