import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// 🔍 LiveFilterBottomSheet - Mobile Awards Filtros Reactivos con Conteo a 0ms
///
/// Permite al usuario ajustar filtros de ofertas, estado de stock, rango de precios
/// con slider + inputs manuales, categorías, marcas y visualización de variantes,
/// calculando el recuento instantáneo (0ms) de productos coincidentes antes de aplicar.
class LiveFilterBottomSheet extends StatefulWidget {
  const LiveFilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => const LiveFilterBottomSheet(),
    );
  }

  @override
  State<LiveFilterBottomSheet> createState() => _LiveFilterBottomSheetState();
}

class _LiveFilterBottomSheetState extends State<LiveFilterBottomSheet> {
  final List<int> _selectedCategoryIds = [];
  final List<int> _selectedBrandIds = [];
  bool _onlyOffers = false;
  bool _onlyDefaults = false;

  // Stock status: 'all', 'in_stock', 'low_stock', 'out_of_stock'
  String _stockStatus = 'all';

  // Price range filter
  bool _filterByPrice = false;
  RangeValues _priceRange = const RangeValues(0, 200);
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  // Accordion expansion states
  bool _categoriesExpanded = true;
  bool _brandsExpanded = false;

  int? _sqliteCount;
  Timer? _countDebounce;

  @override
  void initState() {
    super.initState();
    final catProv = Provider.of<CatalogProvider>(context, listen: false);
    final adv = catProv.advancedFilters;

    if (adv['category_ids'] != null) {
      _selectedCategoryIds.addAll(List<int>.from(adv['category_ids']));
    } else if (catProv.selectedCategoryId != null) {
      _selectedCategoryIds.add(catProv.selectedCategoryId!);
    }

    if (adv['brand_ids'] != null) {
      _selectedBrandIds.addAll(List<int>.from(adv['brand_ids']));
    }

    if (adv['has_offer'] == true) {
      _onlyOffers = true;
    }

    if (adv['only_defaults'] == true) {
      _onlyDefaults = true;
    }

    if (adv['min_price'] != null || adv['max_price'] != null) {
      _filterByPrice = true;
      final minP = (adv['min_price'] is num)
          ? (adv['min_price'] as num).toDouble()
          : 0.0;
      final maxP = (adv['max_price'] is num)
          ? (adv['max_price'] as num).toDouble()
          : 500.0;
      _priceRange = RangeValues(minP.clamp(0.0, 500.0), maxP.clamp(0.0, 500.0));
    }

    _minPriceController.text = _priceRange.start.toStringAsFixed(0);
    _maxPriceController.text = _priceRange.end.toStringAsFixed(0);

    final minStock = adv['min_stock'];
    final maxStock = adv['max_stock'];
    if (minStock == 1 && maxStock == 5) {
      _stockStatus = 'low_stock';
    } else if (maxStock == 0) {
      _stockStatus = 'out_of_stock';
    } else if (minStock == 1 && maxStock == null) {
      _stockStatus = 'in_stock';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSqliteCount();
    });
  }

  @override
  void dispose() {
    _countDebounce?.cancel();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _updateFilter(VoidCallback fn) {
    setState(fn);
    _refreshSqliteCount();
  }

  void _refreshSqliteCount() {
    _countDebounce?.cancel();
    _countDebounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) return;
      final catProv = Provider.of<CatalogProvider>(context, listen: false);
      final filters = _buildFiltersMap();
      final count = await catProv.countFilteredProducts(filters);
      if (mounted) {
        setState(() => _sqliteCount = count);
      }
    });
  }

  Map<String, dynamic> _buildFiltersMap() {
    final filters = <String, dynamic>{};

    if (_selectedCategoryIds.isNotEmpty) {
      filters['category_ids'] = List<int>.from(_selectedCategoryIds);
    }
    if (_selectedBrandIds.isNotEmpty) {
      filters['brand_ids'] = List<int>.from(_selectedBrandIds);
    }
    if (_onlyOffers) {
      filters['has_offer'] = true;
    }
    if (_onlyDefaults) {
      filters['only_defaults'] = true;
    }
    if (_filterByPrice) {
      filters['min_price'] = _priceRange.start;
      filters['max_price'] = _priceRange.end;
    }

    if (_stockStatus == 'in_stock') {
      filters['min_stock'] = 1;
    } else if (_stockStatus == 'low_stock') {
      filters['min_stock'] = 1;
      filters['max_stock'] = 5;
    } else if (_stockStatus == 'out_of_stock') {
      filters['max_stock'] = 0;
    }
    return filters;
  }

  int _calculateLiveCount(CatalogProvider prov) {
    final allItems = prov.displayItems;
    if (allItems.isEmpty) return prov.realTotalPresentationsCount;

    return allItems.where((w) {
      // 1. Categorías
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(w.product.categoriaId)) {
        return false;
      }

      // 2. Marcas
      if (_selectedBrandIds.isNotEmpty &&
          !_selectedBrandIds.contains(w.product.marcaId)) {
        return false;
      }

      // 3. Ofertas
      if (_onlyOffers &&
          (w.presentation.precioOferta == null ||
              w.presentation.precioOferta! <= 0)) {
        return false;
      }

      // 4. Solo presentación default / principal
      if (_onlyDefaults && !w.presentation.esDefault) {
        return false;
      }

      // 5. Rango de precio
      if (_filterByPrice) {
        final effPrice = w.effectivePrice;
        if (effPrice < _priceRange.start || effPrice > _priceRange.end) {
          return false;
        }
      }

      // 6. Estado de stock
      if (_stockStatus == 'in_stock' && w.isOutOfStock) {
        return false;
      }
      if (_stockStatus == 'low_stock') {
        final stockMin = w.presentation.stockAlerta ?? 5;
        if (w.isOutOfStock || w.presentation.stockActual > stockMin) {
          return false;
        }
      }
      if (_stockStatus == 'out_of_stock' && !w.isOutOfStock) {
        return false;
      }

      return true;
    }).length;
  }

  void _applyFilters() {
    HapticFeedback.mediumImpact();
    final catProv = Provider.of<CatalogProvider>(context, listen: false);
    final filters = _buildFiltersMap();
    catProv.applyAdvancedFilters(filters);
    Navigator.pop(context);
  }

  void _resetFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategoryIds.clear();
      _selectedBrandIds.clear();
      _onlyOffers = false;
      _onlyDefaults = false;
      _stockStatus = 'all';
      _filterByPrice = false;
      _priceRange = const RangeValues(0, 200);
      _minPriceController.text = "0";
      _maxPriceController.text = "200";
      _sqliteCount = null;
    });
    final catProv = Provider.of<CatalogProvider>(context, listen: false);
    catProv.clearAllFilters();
    _refreshSqliteCount();
  }

  bool get _hasActiveFilters {
    return _selectedCategoryIds.isNotEmpty ||
        _selectedBrandIds.isNotEmpty ||
        _onlyOffers ||
        _onlyDefaults ||
        _stockStatus != 'all' ||
        _filterByPrice;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catProv = Provider.of<CatalogProvider>(context);

    final categories = catProv.categories;
    final brands = catProv.brands;
    final liveCount = _sqliteCount ?? _calculateLiveCount(catProv);
    final effectiveBottom =
        InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16);

    final cardBg = isDark ? const Color(0xFF1E1E28) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return InteractiveSheetWrapper(
      applyEffectiveBottomPadding: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CABECERA MODERNA CON BOTÓN LIMPIAR
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
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
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Filtros del Catálogo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_hasActiveFilters)
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Limpiar',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[400],
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Cerrar",
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. CONTENIDO SCROLLABLE CON ACORDEONES Y CARDS
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A. OFERTAS Y VARIANTES
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Promociones y Visualización', isDark),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip(
                              label: 'Solo ofertas 🔥',
                              isSelected: _onlyOffers,
                              activeColor: Colors.deepOrange,
                              icon: Icons.local_offer_outlined,
                              onTap: () => _updateFilter(() => _onlyOffers = !_onlyOffers),
                              isDark: isDark,
                            ),
                            _buildFilterChip(
                              label: 'Solo presentación principal',
                              isSelected: _onlyDefaults,
                              activeColor: Colors.indigo,
                              icon: Icons.star_outline_rounded,
                              onTap: () =>
                                  _updateFilter(() => _onlyDefaults = !_onlyDefaults),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // B. ESTADO DE STOCK
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Disponibilidad de Stock', isDark),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: 'Todos',
                              selected: _stockStatus == 'all',
                              onSelected: () =>
                                  _updateFilter(() => _stockStatus = 'all'),
                              isDark: isDark,
                            ),
                            _buildChoiceChip(
                              label: 'Con Stock',
                              selected: _stockStatus == 'in_stock',
                              color: Colors.teal,
                              icon: Icons.check_circle_outline,
                              onSelected: () =>
                                  _updateFilter(() => _stockStatus = 'in_stock'),
                              isDark: isDark,
                            ),
                            _buildChoiceChip(
                              label: 'Stock Bajo',
                              selected: _stockStatus == 'low_stock',
                              color: Colors.amber[700]!,
                              icon: Icons.warning_amber_rounded,
                              onSelected: () =>
                                  _updateFilter(() => _stockStatus = 'low_stock'),
                              isDark: isDark,
                            ),
                            _buildChoiceChip(
                              label: 'Agotados',
                              selected: _stockStatus == 'out_of_stock',
                              color: Colors.red,
                              icon: Icons.block_outlined,
                              onSelected: () =>
                                  _updateFilter(() => _stockStatus = 'out_of_stock'),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // C. RANGO DE PRECIOS CON SLIDER Y CAMPOS MANUALES
                  Container(
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
                            _buildSectionTitle('Rango de Precios', isDark),
                            Switch.adaptive(
                              value: _filterByPrice,
                              activeThumbColor: Colors.blue[600],
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                _updateFilter(() => _filterByPrice = val);
                              },
                            ),
                          ],
                        ),
                        if (_filterByPrice) ...[
                          const SizedBox(height: 8),
                          RangeSlider(
                            values: _priceRange,
                            min: 0,
                            max: 500,
                            divisions: 50,
                            activeColor: isDark ? Colors.blue[300] : Colors.blue[700],
                            inactiveColor:
                                isDark ? Colors.white12 : Colors.grey.shade300,
                            labels: RangeLabels(
                              "S/ ${_priceRange.start.round()}",
                              "S/ ${_priceRange.end.round()}",
                            ),
                            onChanged: (val) {
                              _updateFilter(() {
                                _priceRange = val;
                                _minPriceController.text =
                                    val.start.toStringAsFixed(0);
                                _maxPriceController.text =
                                    val.end.toStringAsFixed(0);
                              });
                            },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumericInput(
                                  label: 'Mínimo',
                                  controller: _minPriceController,
                                  isDark: isDark,
                                  onSubmitted: (val) {
                                    final n = double.tryParse(val);
                                    if (n != null && n >= 0 && n <= _priceRange.end) {
                                      _updateFilter(() {
                                        _priceRange = RangeValues(
                                          n.clamp(0.0, 500.0),
                                          _priceRange.end,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(
                                  "—",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white38 : Colors.grey[400],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildNumericInput(
                                  label: 'Máximo',
                                  controller: _maxPriceController,
                                  isDark: isDark,
                                  onSubmitted: (val) {
                                    final n = double.tryParse(val);
                                    if (n != null &&
                                        n >= _priceRange.start &&
                                        n <= 500) {
                                      _updateFilter(() {
                                        _priceRange = RangeValues(
                                          _priceRange.start,
                                          n.clamp(0.0, 500.0),
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // D. CATEGORÍAS (ACORDEÓN COLAPSABLE)
                  if (categories.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _categoriesExpanded = !_categoriesExpanded,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildSectionTitle('Categorías', isDark),
                                      if (_selectedCategoryIds.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_selectedCategoryIds.length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Icon(
                                    _categoriesExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color:
                                        isDark ? Colors.white60 : Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: categories.map((Category cat) {
                                  final isSelected =
                                      _selectedCategoryIds.contains(cat.id);
                                  return _buildFilterChip(
                                    label: cat.nombre,
                                    isSelected: isSelected,
                                    onTap: () {
                                      _updateFilter(() {
                                        if (isSelected) {
                                          _selectedCategoryIds.remove(cat.id);
                                        } else {
                                          _selectedCategoryIds.add(cat.id);
                                        }
                                      });
                                    },
                                    isDark: isDark,
                                  );
                                }).toList(),
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: _categoriesExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 200),
                          ),
                        ],
                      ),
                    ),

                  // E. MARCAS (ACORDEÓN COLAPSABLE)
                  if (brands.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _brandsExpanded = !_brandsExpanded,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildSectionTitle('Marcas', isDark),
                                      if (_selectedBrandIds.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_selectedBrandIds.length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Icon(
                                    _brandsExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color:
                                        isDark ? Colors.white60 : Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: brands.map((Brand b) {
                                  final isSelected =
                                      _selectedBrandIds.contains(b.id);
                                  return _buildFilterChip(
                                    label: b.nombre,
                                    isSelected: isSelected,
                                    onTap: () {
                                      _updateFilter(() {
                                        if (isSelected) {
                                          _selectedBrandIds.remove(b.id);
                                        } else {
                                          _selectedBrandIds.add(b.id);
                                        }
                                      });
                                    },
                                    isDark: isDark,
                                  );
                                }).toList(),
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: _brandsExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 200),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. BOTÓN FLOTANTE INFERIOR CON CONTEO EN VIVO A 0MS
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, effectiveBottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
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
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      liveCount > 0
                          ? 'Mostrar $liveCount ${liveCount == 1 ? "Producto" : "Productos"}'
                          : 'Aplicar Filtros',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: isDark ? Colors.grey[300] : Colors.grey[800],
      ),
    );
  }

  Widget _buildNumericInput({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    required Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixText: 'S/ ',
        prefixStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.blue[300] : Colors.blue[800],
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
    Color activeColor = Colors.blue,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.grey[300] : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color color = Colors.blue,
    IconData? icon,
    required bool isDark,
  }) {
    final activeColor = color;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected
                    ? activeColor
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.grey[300] : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
