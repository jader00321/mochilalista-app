import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// 🏆 FilterDrawer (Mobile Awards Standard)
/// Drawer lateral de filtros de Inventario con:
/// 1. Secciones modulares en tarjetas colapsables fluidas (AnimatedCrossFade).
/// 2. Badges de conteo activo por sección (Categorías, Marcas, Proveedores).
/// 3. Conteo reactivo en vivo SQLite (<2ms) en el botón inferior ("Mostrar X Productos").
/// 4. Blindaje universal inferior con InteractiveSheetWrapper.getEffectiveBottomPadding.
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
  RangeValues _priceRange = const RangeValues(0, 500);
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  bool _filterByStock = false;
  RangeValues _stockRange = const RangeValues(0, 100);
  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _maxStockController = TextEditingController();

  bool _onlyOffers = false;
  bool _onlyDefaults = false;

  bool _categoriesExpanded = true;
  bool _brandsExpanded = false;
  bool _providersExpanded = false;

  int? _sqliteCount;
  Timer? _countDebounce;

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
        _minPriceController.text = _priceRange.start.toStringAsFixed(0);
        _maxPriceController.text = _priceRange.end.toStringAsFixed(0);

        if (provider.activeMinStock != null && provider.activeMaxStock != null) {
          _filterByStock = true;
          _stockRange = RangeValues(provider.activeMinStock!.toDouble(), provider.activeMaxStock!.toDouble());
        } else {
          _stockRange = const RangeValues(0, 100);
        }
        _minStockController.text = _stockRange.start.toStringAsFixed(0);
        _maxStockController.text = _stockRange.end.toStringAsFixed(0);

        _onlyOffers = provider.activeHasOffer;
        _onlyDefaults = provider.activeOnlyDefaults;
      });

      _refreshSqliteCount();
    });
  }

  @override
  void dispose() {
    _countDebounce?.cancel();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFiltersMap() {
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
    return filters;
  }

  void _refreshSqliteCount() {
    _countDebounce?.cancel();
    _countDebounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) return;
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      final filters = _buildFiltersMap();
      final count = await provider.countFilteredItems(filters);
      if (mounted) {
        setState(() => _sqliteCount = count);
      }
    });
  }

  void _updateFilter(VoidCallback fn) {
    setState(fn);
    _refreshSqliteCount();
  }

  void _apply() {
    HapticFeedback.mediumImpact();
    final filters = _buildFiltersMap();
    widget.onApplyFilters(filters);
    Navigator.pop(context); 
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategories.clear();
      _selectedBrands.clear();
      _selectedProviders.clear();
      _selectedState = null;
      _filterByPrice = false;
      _priceRange = const RangeValues(0, 500);
      _minPriceController.text = "0";
      _maxPriceController.text = "500";
      _filterByStock = false;
      _stockRange = const RangeValues(0, 100);
      _minStockController.text = "0";
      _maxStockController.text = "100";
      _onlyOffers = false;
      _onlyDefaults = false;
      _sqliteCount = null;
    });
    _refreshSqliteCount();
  }

  bool get _hasActiveFilters {
    return _selectedCategories.isNotEmpty ||
        _selectedBrands.isNotEmpty ||
        _selectedProviders.isNotEmpty ||
        _selectedState != null ||
        _filterByPrice ||
        _filterByStock ||
        _onlyOffers ||
        _onlyDefaults;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF14141C) : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF1E1E28) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;
    final effectiveBottom =
        InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16);

    final displayCount = _sqliteCount ?? provider.totalPresentationsCount;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85, 
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(24))),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CABECERA ELEGANTE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text("Filtros", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: _reset,
                      icon: Icon(Icons.refresh_rounded, size: 16, color: isDark ? Colors.red[300] : Colors.red),
                      label: Text("Limpiar", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                ],
              ),
            ),

            // 2. CUERPO SCROLLABLE CON TARJETAS MODULARES
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  // CARD 1: VISUALIZACIÓN & PROMOCIONES
                  _buildCardSection(
                    title: "Visualización y Ofertas",
                    icon: Icons.auto_awesome_mosaic_outlined,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: "Solo Principales",
                          isSelected: _onlyDefaults,
                          activeColor: Colors.indigo,
                          icon: Icons.star_outline_rounded,
                          onTap: () => _updateFilter(() => _onlyDefaults = !_onlyDefaults),
                          isDark: isDark,
                        ),
                        _buildFilterChip(
                          label: "Solo Ofertas 🔥",
                          isSelected: _onlyOffers,
                          activeColor: Colors.deepOrange,
                          icon: Icons.local_offer_outlined,
                          onTap: () => _updateFilter(() => _onlyOffers = !_onlyOffers),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // CARD 2: ESTADO DE PUBLICACIÓN
                  _buildCardSection(
                    title: "Estado de Publicación",
                    icon: Icons.visibility_outlined,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip("Todos", _selectedState == null, () => _updateFilter(() => _selectedState = null), isDark: isDark),
                        _buildChoiceChip("Público", _selectedState == 'publico', () => _updateFilter(() => _selectedState = 'publico'), color: isDark ? Colors.green[400]! : Colors.green, isDark: isDark),
                        _buildChoiceChip("Privado", _selectedState == 'privado', () => _updateFilter(() => _selectedState = 'privado'), color: isDark ? Colors.orange[400]! : Colors.orange, isDark: isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // CARD 3: RANGO DE PRECIOS
                  _buildCardSection(
                    title: "Rango de Precios",
                    icon: Icons.payments_outlined,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    trailing: Switch.adaptive(
                      value: _filterByPrice,
                      activeThumbColor: Colors.blue[600],
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        _updateFilter(() => _filterByPrice = val);
                      },
                    ),
                    child: _filterByPrice
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              RangeSlider(
                                values: _priceRange,
                                min: 0,
                                max: 500,
                                divisions: 50,
                                activeColor: isDark ? Colors.blue[300] : theme.primaryColor,
                                inactiveColor: isDark ? Colors.white12 : Colors.grey.shade300,
                                labels: RangeLabels("S/ ${_priceRange.start.round()}", "S/ ${_priceRange.end.round()}"),
                                onChanged: (val) {
                                  _updateFilter(() {
                                    _priceRange = val;
                                    _minPriceController.text = val.start.toStringAsFixed(0);
                                    _maxPriceController.text = val.end.toStringAsFixed(0);
                                  });
                                },
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMiniNumericInput(
                                      label: "Mínimo",
                                      prefix: "S/ ",
                                      controller: _minPriceController,
                                      isDark: isDark,
                                      onSubmitted: (v) {
                                        final n = double.tryParse(v);
                                        if (n != null && n >= 0 && n <= _priceRange.end) {
                                          _updateFilter(() => _priceRange = RangeValues(n, _priceRange.end));
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text("—", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMiniNumericInput(
                                      label: "Máximo",
                                      prefix: "S/ ",
                                      controller: _maxPriceController,
                                      isDark: isDark,
                                      onSubmitted: (v) {
                                        final n = double.tryParse(v);
                                        if (n != null && n >= _priceRange.start && n <= 500) {
                                          _updateFilter(() => _priceRange = RangeValues(_priceRange.start, n));
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 12),

                  // CARD 4: RANGO DE STOCK
                  _buildCardSection(
                    title: "Rango de Stock",
                    icon: Icons.inventory_2_outlined,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    trailing: Switch.adaptive(
                      value: _filterByStock,
                      activeThumbColor: Colors.teal[600],
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        _updateFilter(() => _filterByStock = val);
                      },
                    ),
                    child: _filterByStock
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              RangeSlider(
                                values: _stockRange,
                                min: 0,
                                max: 100,
                                divisions: 20,
                                activeColor: isDark ? Colors.teal[300] : Colors.teal,
                                inactiveColor: isDark ? Colors.white12 : Colors.grey.shade300,
                                labels: RangeLabels("${_stockRange.start.round()}", "${_stockRange.end.round()}"),
                                onChanged: (val) {
                                  _updateFilter(() {
                                    _stockRange = val;
                                    _minStockController.text = val.start.round().toString();
                                    _maxStockController.text = val.end.round().toString();
                                  });
                                },
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMiniNumericInput(
                                      label: "Mínimo",
                                      prefix: "",
                                      controller: _minStockController,
                                      isDark: isDark,
                                      onSubmitted: (v) {
                                        final n = double.tryParse(v);
                                        if (n != null && n >= 0 && n <= _stockRange.end) {
                                          _updateFilter(() => _stockRange = RangeValues(n, _stockRange.end));
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text("—", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildMiniNumericInput(
                                      label: "Máximo",
                                      prefix: "",
                                      controller: _maxStockController,
                                      isDark: isDark,
                                      onSubmitted: (v) {
                                        final n = double.tryParse(v);
                                        if (n != null && n >= _stockRange.start && n <= 100) {
                                          _updateFilter(() => _stockRange = RangeValues(_stockRange.start, n));
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 12),

                  // CARD 5: CATEGORÍAS (ACORDEÓN COLAPSABLE)
                  if (provider.categories.isNotEmpty)
                    _buildAccordionCard(
                      title: "Categorías",
                      icon: Icons.category_outlined,
                      isExpanded: _categoriesExpanded,
                      selectedCount: _selectedCategories.length,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      onToggle: () => setState(() => _categoriesExpanded = !_categoriesExpanded),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.categories.map((Category cat) {
                          final isSelected = _selectedCategories.contains(cat.id);
                          return _buildFilterChip(
                            label: cat.nombre,
                            isSelected: isSelected,
                            onTap: () {
                              _updateFilter(() {
                                isSelected ? _selectedCategories.remove(cat.id) : _selectedCategories.add(cat.id);
                              });
                            },
                            isDark: isDark,
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // CARD 6: MARCAS (ACORDEÓN COLAPSABLE)
                  if (provider.brands.isNotEmpty)
                    _buildAccordionCard(
                      title: "Marcas",
                      icon: Icons.branding_watermark_outlined,
                      isExpanded: _brandsExpanded,
                      selectedCount: _selectedBrands.length,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      onToggle: () => setState(() => _brandsExpanded = !_brandsExpanded),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.brands.map((Brand brand) {
                          final isSelected = _selectedBrands.contains(brand.id);
                          return _buildFilterChip(
                            label: brand.nombre,
                            isSelected: isSelected,
                            onTap: () {
                              _updateFilter(() {
                                isSelected ? _selectedBrands.remove(brand.id) : _selectedBrands.add(brand.id);
                              });
                            },
                            isDark: isDark,
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // CARD 7: PROVEEDORES (ACORDEÓN COLAPSABLE)
                  if (provider.providers.isNotEmpty)
                    _buildAccordionCard(
                      title: "Proveedores",
                      icon: Icons.local_shipping_outlined,
                      isExpanded: _providersExpanded,
                      selectedCount: _selectedProviders.length,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      onToggle: () => setState(() => _providersExpanded = !_providersExpanded),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.providers.map<Widget>((ProviderModel prov) {
                          final isSelected = _selectedProviders.contains(prov.id);
                          return _buildFilterChip(
                            label: prov.nombreEmpresa,
                            isSelected: isSelected,
                            activeColor: Colors.purple,
                            onTap: () {
                              _updateFilter(() {
                                isSelected ? _selectedProviders.remove(prov.id) : _selectedProviders.add(prov.id);
                              });
                            },
                            isDark: isDark,
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // 3. BOTÓN FLOTANTE INFERIOR CON BLINDAJE Y CONTEO REACTIVO
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, effectiveBottom),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black45 : Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blue[700] : theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: isDark ? 0 : 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _apply,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        displayCount > 0
                            ? "Mostrar $displayCount ${displayCount == 1 ? 'Producto' : 'Productos'}"
                            : "Aplicar Filtros",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildAccordionCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required int selectedCount,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (selectedCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$selectedCount',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color activeColor = Colors.blue,
    IconData? icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    bool selected,
    VoidCallback onSelected, {
    Color color = Colors.grey,
    required bool isDark,
  }) {
    Color activeColor = color == Colors.grey ? (isDark ? Colors.grey[300]! : Colors.black87) : color;
    
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? activeColor : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? (isDark ? Colors.white : activeColor) : (isDark ? Colors.grey[300] : Colors.grey[800]),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniNumericInput({
    required String label,
    required String prefix,
    required TextEditingController controller,
    required bool isDark,
    required Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixText: prefix,
        prefixStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.blue[300] : Colors.blue[800],
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
      ),
    );
  }
}