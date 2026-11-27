part of '../live_filter_bottom_sheet.dart';

mixin _LiveFilterSectionsMixin on _LiveFilterBottomSheetBase {
  Widget _buildPromotionsCard(Color cardBg, Color borderColor, bool isDark) {
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
          _buildSectionTitle('Promociones y Visualización', isDark),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: 'Solo ofertas',
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
    );
  }

  Widget _buildStockStatusCard(Color cardBg, Color borderColor, bool isDark) {
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
          _buildSectionTitle('Disponibilidad de Stock', isDark),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                label: 'Todos',
                selected: _stockStatus == 'all',
                onSelected: () => _updateFilter(() => _stockStatus = 'all'),
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
    );
  }

  Widget _buildPriceRangeCard(Color cardBg, Color borderColor, bool isDark) {
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
            children: [
              Expanded(child: _buildSectionTitle('Rango de Precios', isDark)),
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
              inactiveColor: isDark ? Colors.white12 : Colors.grey.shade300,
              labels: RangeLabels(
                AppCurrency.format(_priceRange.start, decimals: 0),
                AppCurrency.format(_priceRange.end, decimals: 0),
              ),
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
                      if (n != null && n >= _priceRange.start && n <= 500) {
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
    );
  }

  Widget _buildCategoriesAccordion({
    required List<Category> categories,
    required bool hasOrphanCategories,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    final chips = <Widget>[
      if (hasOrphanCategories)
        _buildFilterChip(
          label: 'General',
          isSelected: _selectedCategoryIds.contains(0),
          onTap: () {
            _updateFilter(() {
              if (_selectedCategoryIds.contains(0)) {
                _selectedCategoryIds.remove(0);
              } else {
                _selectedCategoryIds.add(0);
              }
            });
          },
          isDark: isDark,
        ),
      ...categories
          .where((c) => c.nombre.trim().toLowerCase() != 'general')
          .map((Category cat) {
            final isSelected = _selectedCategoryIds.contains(cat.id);
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
          }),
    ];

    return _buildTaxonomyAccordion(
      title: 'Categorías',
      selectedCount: _selectedCategoryIds.length,
      isExpanded: _categoriesExpanded,
      onToggle: () =>
          setState(() => _categoriesExpanded = !_categoriesExpanded),
      chips: chips,
      cardBg: cardBg,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildBrandsAccordion({
    required List<Brand> brands,
    required bool hasOrphanBrands,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    final chips = <Widget>[
      if (hasOrphanBrands)
        _buildFilterChip(
          label: '[ Sin Marca ]',
          isSelected: _selectedBrandIds.contains(0),
          onTap: () {
            _updateFilter(() {
              if (_selectedBrandIds.contains(0)) {
                _selectedBrandIds.remove(0);
              } else {
                _selectedBrandIds.add(0);
              }
            });
          },
          isDark: isDark,
        ),
      ...brands.map((Brand b) {
        final isSelected = _selectedBrandIds.contains(b.id);
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
      }),
    ];

    return _buildTaxonomyAccordion(
      title: 'Marcas',
      selectedCount: _selectedBrandIds.length,
      isExpanded: _brandsExpanded,
      onToggle: () => setState(() => _brandsExpanded = !_brandsExpanded),
      chips: chips,
      cardBg: cardBg,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildTaxonomyAccordion({
    required String title,
    required int selectedCount,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> chips,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: _buildSectionTitle(title, isDark)),
                        if (selectedCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$selectedCount',
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
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(spacing: 8, runSpacing: 8, children: chips),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
