import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';

class CatalogFilterDrawer extends StatefulWidget {
  const CatalogFilterDrawer({super.key});

  @override
  State<CatalogFilterDrawer> createState() => _CatalogFilterDrawerState();
}

class _CatalogFilterDrawerState extends State<CatalogFilterDrawer> {
  List<int> _selectedCategories = [];
  List<int> _selectedBrands = [];
  
  bool _filterByPrice = false;
  // 🔥 Rango Sincronizado a 500
  RangeValues _priceRange = const RangeValues(0, 500);
  
  bool _onlyOffers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CatalogProvider>(context, listen: false);
      final filters = provider.advancedFilters; 

      setState(() {
        if (filters['category_ids'] != null) { 
          _selectedCategories = List.from(filters['category_ids']);
        }
        if (filters['brand_ids'] != null) {
          _selectedBrands = List.from(filters['brand_ids']);
        }
        
        if (filters['min_price'] != null && filters['max_price'] != null) {
          _filterByPrice = true;
          _priceRange = RangeValues(filters['min_price'], filters['max_price']);
        }

        if (filters['has_offer'] == true) {
          _onlyOffers = true;
        }
      });
    });
  }

  void _apply() {
    final filters = <String, dynamic>{};

    if (_selectedCategories.isNotEmpty) filters['category_ids'] = _selectedCategories;
    if (_selectedBrands.isNotEmpty) filters['brand_ids'] = _selectedBrands;
    
    if (_filterByPrice) {
      filters['min_price'] = _priceRange.start;
      filters['max_price'] = _priceRange.end;
    }

    if (_onlyOffers) filters['has_offer'] = true;

    Provider.of<CatalogProvider>(context, listen: false).applyAdvancedFilters(filters);
    Navigator.pop(context); 
  }

  void _reset() {
    setState(() {
      _selectedCategories.clear();
      _selectedBrands.clear();
      _filterByPrice = false;
      _priceRange = const RangeValues(0, 500); // 🔥 Sincronizado
      _onlyOffers = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CatalogProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final drawerBgColor = isDark ? const Color(0xFF1A1A24) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85, 
      backgroundColor: drawerBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. CABECERA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Filtros", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: Icon(Icons.cleaning_services_outlined, size: 18, color: isDark ? Colors.red[400] : Colors.red),
                    label: Text("Limpiar", style: TextStyle(color: isDark ? Colors.red[400] : Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  )
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

            // 2. CONTENIDO
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  // --- OFERTAS ---
                  _buildSectionLabel("Estado y Ofertas", isDark),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Solo Ofertas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                            const SizedBox(height: 2),
                            Text("Productos con descuento", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _onlyOffers,
                        activeColor: isDark ? Colors.red[400] : Colors.red,
                        onChanged: (v) => setState(() => _onlyOffers = v),
                      ),
                    ],
                  ),
                  
                  Divider(height: 40, color: isDark ? Colors.white10 : Colors.grey[200]),

                  // --- RANGO DE PRECIO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Filtrar por Precio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      Switch.adaptive(
                        value: _filterByPrice,
                        onChanged: (v) => setState(() => _filterByPrice = v),
                        activeColor: isDark ? Colors.blue[300] : theme.primaryColor,
                      )
                    ],
                  ),
                  if (_filterByPrice) ...[
                    const SizedBox(height: 16),
                    RangeSlider(
                      values: _priceRange,
                      min: 0, max: 500, // 🔥 Aumentado para mayor rango comercial
                      divisions: 50,
                      activeColor: isDark ? Colors.blue[300] : theme.primaryColor,
                      inactiveColor: isDark ? Colors.white24 : Colors.grey[300],
                      labels: RangeLabels("S/ ${_priceRange.start.round()}", "S/ ${_priceRange.end.round()}"),
                      onChanged: (val) => setState(() => _priceRange = val),
                    ),
                    Center(child: Text("S/ ${_priceRange.start.toStringAsFixed(0)} - S/ ${_priceRange.end.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue[300] : theme.primaryColor))),
                  ],
                  Divider(height: 40, color: isDark ? Colors.white10 : Colors.grey[200]),

                  // --- CATEGORÍAS ---
                  _buildSectionLabel("Categorías", isDark),
                  if (provider.categories.isEmpty) 
                    Padding(padding: const EdgeInsets.all(8.0), child: Text("Cargando...", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 14))),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: provider.categories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat.id);
                      return FilterChip(
                        label: Text(cat.nombre, style: TextStyle(fontSize: 14, color: isSelected ? (isDark ? Colors.blue[200] : Colors.blue[800]) : textColor)),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            val ? _selectedCategories.add(cat.id) : _selectedCategories.remove(cat.id);
                          });
                        },
                        selectedColor: isDark ? Colors.blue.withOpacity(0.2) : theme.primaryColor.withOpacity(0.1),
                        checkmarkColor: isDark ? Colors.blue[200] : theme.primaryColor,
                        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: isSelected ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.transparent) : (isDark ? Colors.white10 : Colors.transparent)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),

                  // --- MARCAS ---
                  _buildSectionLabel("Marcas", isDark),
                  if (provider.brands.isEmpty) 
                    Padding(padding: const EdgeInsets.all(8.0), child: Text("Cargando...", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 14))),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: provider.brands.map((brand) {
                      final isSelected = _selectedBrands.contains(brand.id);
                      return FilterChip(
                        label: Text(brand.nombre, style: TextStyle(fontSize: 14, color: isSelected ? (isDark ? Colors.blue[200] : Colors.blue[800]) : textColor)),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            val ? _selectedBrands.add(brand.id) : _selectedBrands.remove(brand.id);
                          });
                        },
                        selectedColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                        checkmarkColor: isDark ? Colors.blue[300] : Colors.blue,
                        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: isSelected ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.transparent) : (isDark ? Colors.white10 : Colors.transparent)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // 3. BOTÓN APLICAR
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blue[700] : theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                  ),
                  child: const Text("VER RESULTADOS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : Colors.grey, letterSpacing: 1.0)),
    );
  }
}