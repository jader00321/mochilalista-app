import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

part 'filter_drawer/filter_drawer_sections_part.dart';
part 'filter_drawer/filter_drawer_controls_part.dart';

/// Drawer lateral de filtros de Inventario con tarjetas colapsables,
/// badges de conteo activo, conteo reactivo SQLite y blindaje inferior seguro.
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
      if (!mounted) {
        return;
      }
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      provider.loadMasterData();

      setState(() {
        _selectedCategories = List.from(provider.activeCategoryIds);
        _selectedBrands = List.from(provider.activeBrandIds);
        _selectedProviders = List.from(provider.activeProviderIds);
        _selectedState = provider.activeState;

        if (provider.activeMinPrice != null &&
            provider.activeMaxPrice != null) {
          _filterByPrice = true;
          _priceRange = RangeValues(
            provider.activeMinPrice!,
            provider.activeMaxPrice!,
          );
        } else {
          _priceRange = const RangeValues(0, 500);
        }
        _minPriceController.text = _priceRange.start.toStringAsFixed(0);
        _maxPriceController.text = _priceRange.end.toStringAsFixed(0);

        if (provider.activeMinStock != null &&
            provider.activeMaxStock != null) {
          _filterByStock = true;
          _stockRange = RangeValues(
            provider.activeMinStock!.toDouble(),
            provider.activeMaxStock!.toDouble(),
          );
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

    if (_selectedCategories.isNotEmpty) {
      filters['categoryIds'] = _selectedCategories;
    }
    if (_selectedBrands.isNotEmpty) {
      filters['brandIds'] = _selectedBrands;
    }
    if (_selectedProviders.isNotEmpty) {
      filters['providerIds'] = _selectedProviders;
    }

    if (_selectedState != null) {
      filters['estado'] = _selectedState;
    }

    if (_filterByPrice) {
      filters['minPrice'] = _priceRange.start;
      filters['maxPrice'] = _priceRange.end;
    }

    if (_filterByStock) {
      filters['minStock'] = _stockRange.start.toInt();
      filters['maxStock'] = _stockRange.end.toInt();
    }

    if (_onlyOffers) {
      filters['hasOffer'] = true;
      filters['has_offer'] = true;
    }
    if (_onlyDefaults) {
      filters['onlyDefaults'] = true;
      filters['only_defaults'] = true;
    }
    return filters;
  }

  void _refreshSqliteCount() {
    _countDebounce?.cancel();
    _countDebounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) {
        return;
      }
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

  void _toggleExpandedState(VoidCallback fn) {
    setState(fn);
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
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: 16,
    );
    final displayCount = _sqliteCount ?? provider.totalPresentationsCount;

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.85,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDrawerHeader(
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  _buildVisualizationCard(isDark, cardBg, borderColor),
                  const SizedBox(height: 12),
                  _buildPublicationStateCard(isDark, cardBg, borderColor),
                  const SizedBox(height: 12),
                  _buildPriceRangeCard(theme, isDark, cardBg, borderColor),
                  const SizedBox(height: 12),
                  _buildStockRangeCard(isDark, cardBg, borderColor),
                  const SizedBox(height: 12),
                  if (provider.categories.isNotEmpty ||
                      provider.hasOrphanCategories)
                    _buildCategoriesAccordion(
                      provider,
                      isDark,
                      cardBg,
                      borderColor,
                    ),
                  const SizedBox(height: 12),
                  if (provider.brands.isNotEmpty || provider.hasOrphanBrands)
                    _buildBrandsAccordion(
                      provider,
                      isDark,
                      cardBg,
                      borderColor,
                    ),
                  const SizedBox(height: 12),
                  if (provider.providers.isNotEmpty)
                    _buildProvidersAccordion(
                      provider,
                      isDark,
                      cardBg,
                      borderColor,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _buildBottomApplyBar(
              theme: theme,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              effectiveBottom: effectiveBottom,
              displayCount: displayCount,
            ),
          ],
        ),
      ),
    );
  }
}
