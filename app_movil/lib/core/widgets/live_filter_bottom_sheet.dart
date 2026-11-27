import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';

part 'live_filter/live_filter_chips_and_inputs_mixin.dart';
part 'live_filter/live_filter_sections_mixin.dart';

/// LiveFilterBottomSheet - Filtros Reactivos con Conteo a 0ms
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

abstract class _LiveFilterBottomSheetBase extends State<LiveFilterBottomSheet> {
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

  void _updateFilter(VoidCallback fn);

  Widget _buildSectionTitle(String title, bool isDark);

  Widget _buildNumericInput({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    required Function(String) onSubmitted,
  });

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
    Color activeColor = Colors.blue,
  });

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color color = Colors.blue,
    IconData? icon,
    required bool isDark,
  });
}

class _LiveFilterBottomSheetState extends _LiveFilterBottomSheetBase
    with _LiveFilterChipsAndInputsMixin, _LiveFilterSectionsMixin {
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

  @override
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
      // 1. Categorías (soporte para ID 0: huérfanos sin categoría)
      if (_selectedCategoryIds.isNotEmpty) {
        final catId = w.product.categoriaId;
        final matches = _selectedCategoryIds.any((id) {
          if (id == 0) return catId == 0;
          return catId == id;
        });
        if (!matches) return false;
      }

      // 2. Marcas (soporte para ID 0: huérfanos sin marca)
      if (_selectedBrandIds.isNotEmpty) {
        final brandId = w.product.marcaId;
        final matches = _selectedBrandIds.any((id) {
          if (id == 0) return brandId == null || brandId == 0;
          return brandId == id;
        });
        if (!matches) return false;
      }

      // 3. Ofertas (paridad 100% con InventoryWrapper.hasOffer)
      if (_onlyOffers && !w.hasOffer) {
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
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Filtros del Catálogo',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (_hasActiveFilters)
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Limpiar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          ),

          const Divider(height: 1),

          // 2. CONTENIDO SCROLLABLE CON ACORDEONES Y CARDS
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                InteractiveSheetWrapper.kModalScrollBottomClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPromotionsCard(cardBg, borderColor, isDark),
                  const SizedBox(height: 14),
                  _buildStockStatusCard(cardBg, borderColor, isDark),
                  const SizedBox(height: 14),
                  _buildPriceRangeCard(cardBg, borderColor, isDark),
                  const SizedBox(height: 14),
                  if (categories.isNotEmpty || catProv.hasOrphanCategories)
                    _buildCategoriesAccordion(
                      categories: categories,
                      hasOrphanCategories: catProv.hasOrphanCategories,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      isDark: isDark,
                    ),
                  if (brands.isNotEmpty || catProv.hasOrphanBrands)
                    _buildBrandsAccordion(
                      brands: brands,
                      hasOrphanBrands: catProv.hasOrphanBrands,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ),

          // 3. BOTÓN FLOTANTE INFERIOR CON CONTEO EN VIVO A 0MS
          Builder(
            builder: (bCtx) {
              final effectiveBottom =
                  InteractiveSheetWrapper.getEffectiveBottomPadding(
                    bCtx,
                    minPadding:
                        InteractiveSheetWrapper.kMinDefensiveBottomClearance,
                  );
              return Container(
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
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              liveCount > 0
                                  ? 'Mostrar $liveCount ${_onlyDefaults ? (liveCount == 1 ? "Producto" : "Productos") : (liveCount == 1 ? "Variante" : "Variantes")}'
                                  : 'Aplicar Filtros',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
