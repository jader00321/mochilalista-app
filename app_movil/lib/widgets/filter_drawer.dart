import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';

class FilterDrawer extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;

  const FilterDrawer({super.key, required this.onApplyFilters});

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  List<int> _selectedCategories = [];
  List<int> _selectedBrands = [];
  List<int> _selectedProviders = [];
  
  String? _selectedState; 
  
  bool _filterByPrice = false;
  RangeValues _priceRange = const RangeValues(0, 50); 
  
  bool _filterByStock = false;
  RangeValues _stockRange = const RangeValues(0, 20); 
  
  bool _onlyOffers = false;
  bool _onlyDefaults = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      provider.loadMasterData();
      
      setState(() {
        _selectedCategories = List.from(provider.activeCategoryIds);
        _selectedBrands = List.from(provider.activeBrandIds);
        _selectedProviders = List.from(provider.activeProviderIds);
        _selectedState = provider.activeState;
        
        if (provider.activeMinPrice != null && provider.activeMaxPrice != null) {
          _filterByPrice = true;
          _priceRange = RangeValues(provider.activeMinPrice!, provider.activeMaxPrice!);
        } else {
          _priceRange = const RangeValues(0, 500); 
        }
        
        if (provider.activeMinStock != null && provider.activeMaxStock != null) {
          _filterByStock = true;
          _stockRange = RangeValues(provider.activeMinStock!.toDouble(), provider.activeMaxStock!.toDouble());
        } else {
          _stockRange = const RangeValues(0, 100); 
        }
        
        _onlyOffers = provider.activeHasOffer;
        _onlyDefaults = provider.activeOnlyDefaults;
      });
    });
  }

  void _apply() {
    final filters = <String, dynamic>{};

    if (_selectedCategories.isNotEmpty) filters['categoryIds'] = _selectedCategories;
    if (_selectedBrands.isNotEmpty) filters['brandIds'] = _selectedBrands;
    if (_selectedProviders.isNotEmpty) filters['providerIds'] = _selectedProviders;
    
    if (_selectedState != null) filters['estado'] = _selectedState;

    if (_filterByPrice) {
      filters['minPrice'] = _priceRange.start;
      filters['maxPrice'] = _priceRange.end;
    }
    
    if (_filterByStock) {
      filters['minStock'] = _stockRange.start.toInt();
      filters['maxStock'] = _stockRange.end.toInt();
    }

    if (_onlyOffers) filters['hasOffer'] = true;
    if (_onlyDefaults) filters['onlyDefaults'] = true;

    widget.onApplyFilters(filters);
    Navigator.pop(context); 
  }

  void _reset() {
    setState(() {
      _selectedCategories.clear();
      _selectedBrands.clear();
      _selectedProviders.clear();
      _selectedState = null;
      _filterByPrice = false;
      _priceRange = const RangeValues(0, 500);
      _filterByStock = false;
      _stockRange = const RangeValues(0, 100);
      _onlyOffers = false;
      _onlyDefaults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1A1A24) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75, 
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(24))),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CABECERA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23232F) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Filtros", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: Icon(Icons.cleaning_services_outlined, size: 18, color: isDark ? Colors.red[300] : Colors.red),
                    label: Text("Limpiar", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),

            // 2. CUERPO SCROLLABLE
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  
                  // SECCIÓN: VISUALIZACIÓN
                  _buildSectionLabel("Visualización", isDark),
                  CheckboxListTile(
                    title: Text("Solo Principales", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                    subtitle: Text("Ocultar variantes", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
                    value: _onlyDefaults,
                    activeColor: isDark ? Colors.blue[300] : theme.primaryColor,
                    checkColor: isDark ? Colors.black87 : Colors.white,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => _onlyDefaults = v!),
                  ),
                  Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),

                  // SECCIÓN: ESTADO Y OFERTAS
                  _buildSectionLabel("Estado y Ofertas", isDark),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChoiceChip("Todos", _selectedState == null, () => setState(() => _selectedState = null), isDark: isDark),
                      _buildChoiceChip("Público", _selectedState == 'publico', () => setState(() => _selectedState = 'publico'), color: isDark ? Colors.green[400]! : Colors.green, isDark: isDark),
                      _buildChoiceChip("Privado", _selectedState == 'privado', () => setState(() => _selectedState = 'privado'), color: isDark ? Colors.orange[400]! : Colors.orange, isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    title: Text("Solo Ofertas", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                    subtitle: Text("Productos con descuento", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
                    value: _onlyOffers,
                    activeColor: isDark ? Colors.red[400] : Colors.red,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _onlyOffers = v),
                  ),
                  Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),

                  // SECCIÓN: PRECIO
                  _buildSwitchHeader("Rango de Precio", _filterByPrice, (v) => setState(() => _filterByPrice = v), isDark),
                  if (_filterByPrice) ...[
                    const SizedBox(height: 10),
                    RangeSlider(
                      values: _priceRange,
                      min: 0, max: 500, 
                      divisions: 50, 
                      activeColor: isDark ? Colors.blue[300] : theme.primaryColor,
                      inactiveColor: isDark ? Colors.white24 : Colors.grey[300],
                      labels: RangeLabels("S/ ${_priceRange.start.round()}", "S/ ${_priceRange.end.round()}"),
                      onChanged: (val) => setState(() => _priceRange = val),
                    ),
                    Center(child: Text("S/ ${_priceRange.start.toStringAsFixed(0)} - S/ ${_priceRange.end.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.blue[200] : theme.primaryColor))),
                  ],
                  Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),

                  // SECCIÓN: STOCK
                  _buildSwitchHeader("Rango de Stock", _filterByStock, (v) => setState(() => _filterByStock = v), isDark),
                  if (_filterByStock) ...[
                    const SizedBox(height: 10),
                    RangeSlider(
                      values: _stockRange,
                      min: 0, max: 100, 
                      divisions: 20, 
                      activeColor: isDark ? Colors.teal[300] : Colors.teal,
                      inactiveColor: isDark ? Colors.white24 : Colors.grey[300],
                      labels: RangeLabels("${_stockRange.start.round()}", "${_stockRange.end.round()}"),
                      onChanged: (val) => setState(() => _stockRange = val),
                    ),
                    Center(child: Text("${_stockRange.start.round()} u. - ${_stockRange.end.round()} u.", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.teal[200] : Colors.teal, fontSize: 15))),
                  ],
                  Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),

                  // SECCIÓN: CATEGORÍAS
                  _buildSectionLabel("Categorías", isDark),
                  if (provider.categories.isEmpty) 
                    Padding(padding: const EdgeInsets.all(8.0), child: Text("Cargando...", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 14))),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.categories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat.id);
                      return FilterChip(
                        label: Text(cat.nombre, style: TextStyle(fontSize: 14, color: isSelected ? (isDark ? Colors.blue[200] : theme.primaryColor) : textColor)),
                        selected: isSelected,
                        selectedColor: isDark ? Colors.blue.withOpacity(0.2) : theme.primaryColor.withOpacity(0.1),
                        checkmarkColor: isDark ? Colors.blue[300] : theme.primaryColor,
                        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: isSelected ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.transparent) : (isDark ? Colors.white10 : Colors.transparent)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (selected) {
                          setState(() {
                            selected ? _selectedCategories.add(cat.id) : _selectedCategories.remove(cat.id);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // SECCIÓN: MARCAS
                  _buildSectionLabel("Marcas", isDark),
                  if (provider.brands.isEmpty) 
                    Padding(padding: const EdgeInsets.all(8.0), child: Text("Cargando...", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 14))),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.brands.map((brand) {
                      final isSelected = _selectedBrands.contains(brand.id);
                      return FilterChip(
                        label: Text(brand.nombre, style: TextStyle(fontSize: 14, color: isSelected ? (isDark ? Colors.blue[200] : Colors.blue[800]) : textColor)),
                        selected: isSelected,
                        selectedColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                        checkmarkColor: isDark ? Colors.blue[300] : Colors.blue,
                        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: isSelected ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.transparent) : (isDark ? Colors.white10 : Colors.transparent)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (selected) {
                          setState(() {
                            selected ? _selectedBrands.add(brand.id) : _selectedBrands.remove(brand.id);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // SECCIÓN: PROVEEDORES
                  _buildSectionLabel("Proveedores", isDark),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.providers.map((prov) {
                      final isSelected = _selectedProviders.contains(prov.id);
                      return FilterChip(
                        label: Text(prov.nombreEmpresa, style: TextStyle(fontSize: 14, color: isSelected ? (isDark ? Colors.purple[200] : Colors.purple[900]) : textColor)),
                        selected: isSelected,
                        selectedColor: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.withOpacity(0.1),
                        checkmarkColor: isDark ? Colors.purple[300] : Colors.purple,
                        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: isSelected ? (isDark ? Colors.purple.withOpacity(0.5) : Colors.transparent) : (isDark ? Colors.white10 : Colors.transparent)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (selected) {
                          setState(() {
                            selected ? _selectedProviders.add(prov.id) : _selectedProviders.remove(prov.id);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 50), 
                ],
              ),
            ),

            // 3. BOTÓN FLOTANTE INFERIOR
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23232F) : Colors.white,
                boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blue[700] : theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: isDark ? 0 : 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _apply,
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
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1.0)),
    );
  }

  Widget _buildSwitchHeader(String title, bool value, Function(bool) onChanged, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
        Switch(
          value: value, 
          onChanged: onChanged,
          activeThumbColor: isDark ? Colors.blue[300] : Theme.of(context).primaryColor,
        )
      ],
    );
  }

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onSelected, {Color color = Colors.grey, required bool isDark}) {
    Color activeColor = color == Colors.grey ? (isDark ? Colors.grey[300]! : Colors.black87) : color;
    
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: activeColor.withOpacity(0.15),
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
      labelStyle: TextStyle(
        color: selected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 14
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? (isDark ? activeColor.withOpacity(0.5) : Colors.transparent) : (isDark ? Colors.white10 : Colors.grey.shade300))
      ),
    );
  }
}