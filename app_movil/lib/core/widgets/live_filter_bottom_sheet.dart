import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// 🔍 LiveFilterBottomSheet - Mobile Awards Filtros Reactivos con Conteo a 0ms
///
/// Permite al usuario ajustar filtros de categoría, marca y ofertas
/// viendo el recuento en vivo de productos resultantes antes de aplicar.
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
  }

  int _calculateLiveCount(CatalogProvider prov) {
    final allItems = prov.displayItems;
    if (allItems.isEmpty) return prov.realTotalPresentationsCount;

    return allItems.where((w) {
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(w.product.categoriaId)) {
        return false;
      }
      if (_selectedBrandIds.isNotEmpty &&
          !_selectedBrandIds.contains(w.product.marcaId)) {
        return false;
      }
      if (_onlyOffers && (w.presentation.precioOferta == null || w.presentation.precioOferta! <= 0)) {
        return false;
      }
      return true;
    }).length;
  }

  void _applyFilters() {
    HapticFeedback.mediumImpact();
    final catProv = Provider.of<CatalogProvider>(context, listen: false);
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

    catProv.applyAdvancedFilters(filters);
    Navigator.pop(context);
  }

  void _resetFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategoryIds.clear();
      _selectedBrandIds.clear();
      _onlyOffers = false;
    });
    final catProv = Provider.of<CatalogProvider>(context, listen: false);
    catProv.clearAllFilters();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catProv = Provider.of<CatalogProvider>(context);

    final categories = catProv.categories;
    final brands = catProv.brands;
    final liveCount = _calculateLiveCount(catProv);
    final hasActiveFilters = _selectedCategoryIds.isNotEmpty ||
        _selectedBrandIds.isNotEmpty ||
        _onlyOffers;

    final effectiveBottom =
        InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16);

    return InteractiveSheetWrapper(
      applyEffectiveBottomPadding: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Limpiar', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contenido scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Ofertas especiales
                  _buildSectionTitle('Promociones y Ofertas', isDark),
                  const SizedBox(height: 8),
                  _buildFilterChip(
                    label: 'Solo ofertas y liquidaciones 🔥',
                    isSelected: _onlyOffers,
                    activeColor: Colors.deepOrange,
                    icon: Icons.local_offer_outlined,
                    onTap: () {
                      setState(() => _onlyOffers = !_onlyOffers);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // 2. Categorías
                  if (categories.isNotEmpty) ...[
                    _buildSectionTitle('Categorías', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((Category cat) {
                        final isSelected = _selectedCategoryIds.contains(cat.id);
                        return _buildFilterChip(
                          label: cat.nombre,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
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
                    const SizedBox(height: 20),
                  ],

                  // 3. Marcas
                  if (brands.isNotEmpty) ...[
                    _buildSectionTitle('Marcas', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: brands.map((Brand b) {
                        final isSelected = _selectedBrandIds.contains(b.id);
                        return _buildFilterChip(
                          label: b.nombre,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
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
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          // Botón de Aplicar con conteo en vivo
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
        letterSpacing: 0.5,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
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
}
