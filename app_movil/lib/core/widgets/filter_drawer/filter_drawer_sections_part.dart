part of '../filter_drawer.dart';

extension _FilterDrawerSectionsPart on _FilterDrawerState {
  Widget _buildDrawerHeader({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
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
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    "Filtros",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _reset,
              icon: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: isDark ? Colors.red[300] : Colors.red,
              ),
              label: Text(
                "Limpiar",
                style: TextStyle(
                  color: isDark ? Colors.red[300] : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualizationCard(bool isDark, Color cardBg, Color borderColor) {
    return _buildCardSection(
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
            label: "Solo Ofertas",
            isSelected: _onlyOffers,
            activeColor: Colors.deepOrange,
            icon: Icons.local_offer_outlined,
            onTap: () => _updateFilter(() => _onlyOffers = !_onlyOffers),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationStateCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return _buildCardSection(
      title: "Estado de Publicación",
      icon: Icons.visibility_outlined,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildChoiceChip(
            "Todos",
            _selectedState == null,
            () => _updateFilter(() => _selectedState = null),
            isDark: isDark,
          ),
          _buildChoiceChip(
            "Público",
            _selectedState == 'publico',
            () => _updateFilter(() => _selectedState = 'publico'),
            color: isDark ? Colors.green[400]! : Colors.green,
            isDark: isDark,
          ),
          _buildChoiceChip(
            "Privado",
            _selectedState == 'privado',
            () => _updateFilter(() => _selectedState = 'privado'),
            color: isDark ? Colors.orange[400]! : Colors.orange,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRangeCard(
    ThemeData theme,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return _buildRangeFilterCard(
      title: "Rango de Precios",
      icon: Icons.payments_outlined,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      enabled: _filterByPrice,
      switchColor: Colors.blue[600]!,
      sliderColor: isDark ? Colors.blue[300]! : theme.primaryColor,
      range: _priceRange,
      max: 500,
      divisions: 50,
      labels: RangeLabels(
        AppCurrency.format(_priceRange.start.round(), decimals: 0),
        AppCurrency.format(_priceRange.end.round(), decimals: 0),
      ),
      prefix: "S/ ",
      minController: _minPriceController,
      maxController: _maxPriceController,
      onToggle: (val) => _updateFilter(() => _filterByPrice = val),
      onRangeChanged: (val) {
        _updateFilter(() {
          _priceRange = val;
          _minPriceController.text = val.start.toStringAsFixed(0);
          _maxPriceController.text = val.end.toStringAsFixed(0);
        });
      },
      onMinSubmitted: (n) {
        if (n >= 0 && n <= _priceRange.end) {
          _updateFilter(() => _priceRange = RangeValues(n, _priceRange.end));
        }
      },
      onMaxSubmitted: (n) {
        if (n >= _priceRange.start && n <= 500) {
          _updateFilter(() => _priceRange = RangeValues(_priceRange.start, n));
        }
      },
    );
  }

  Widget _buildStockRangeCard(bool isDark, Color cardBg, Color borderColor) {
    return _buildRangeFilterCard(
      title: "Rango de Stock",
      icon: Icons.inventory_2_outlined,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      enabled: _filterByStock,
      switchColor: Colors.teal[600]!,
      sliderColor: isDark ? Colors.teal[300]! : Colors.teal,
      range: _stockRange,
      max: 100,
      divisions: 20,
      labels: RangeLabels(
        "${_stockRange.start.round()}",
        "${_stockRange.end.round()}",
      ),
      prefix: "",
      minController: _minStockController,
      maxController: _maxStockController,
      onToggle: (val) => _updateFilter(() => _filterByStock = val),
      onRangeChanged: (val) {
        _updateFilter(() {
          _stockRange = val;
          _minStockController.text = val.start.round().toString();
          _maxStockController.text = val.end.round().toString();
        });
      },
      onMinSubmitted: (n) {
        if (n >= 0 && n <= _stockRange.end) {
          _updateFilter(() => _stockRange = RangeValues(n, _stockRange.end));
        }
      },
      onMaxSubmitted: (n) {
        if (n >= _stockRange.start && n <= 100) {
          _updateFilter(() => _stockRange = RangeValues(_stockRange.start, n));
        }
      },
    );
  }

  Widget _buildRangeFilterCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required bool enabled,
    required Color switchColor,
    required Color sliderColor,
    required RangeValues range,
    required double max,
    required int divisions,
    required RangeLabels labels,
    required String prefix,
    required TextEditingController minController,
    required TextEditingController maxController,
    required ValueChanged<bool> onToggle,
    required ValueChanged<RangeValues> onRangeChanged,
    required ValueChanged<double> onMinSubmitted,
    required ValueChanged<double> onMaxSubmitted,
  }) {
    return _buildCardSection(
      title: title,
      icon: icon,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      trailing: Switch.adaptive(
        value: enabled,
        activeThumbColor: switchColor,
        onChanged: (val) {
          HapticFeedback.selectionClick();
          onToggle(val);
        },
      ),
      child: enabled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                RangeSlider(
                  values: range,
                  min: 0,
                  max: max,
                  divisions: divisions,
                  activeColor: sliderColor,
                  inactiveColor: isDark ? Colors.white12 : Colors.grey.shade300,
                  labels: labels,
                  onChanged: onRangeChanged,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniNumericInput(
                        label: "Mínimo",
                        prefix: prefix,
                        controller: minController,
                        isDark: isDark,
                        onSubmitted: (v) {
                          final n = double.tryParse(v);
                          if (n != null) {
                            onMinSubmitted(n);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "—",
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniNumericInput(
                        label: "Máximo",
                        prefix: prefix,
                        controller: maxController,
                        isDark: isDark,
                        onSubmitted: (v) {
                          final n = double.tryParse(v);
                          if (n != null) {
                            onMaxSubmitted(n);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCategoriesAccordion(
    InventoryProvider provider,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return _buildAccordionCard(
      title: "Categorías",
      icon: Icons.category_outlined,
      isExpanded: _categoriesExpanded,
      selectedCount: _selectedCategories.length,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      onToggle: () => _toggleExpandedState(
        () => _categoriesExpanded = !_categoriesExpanded,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (provider.hasOrphanCategories)
            _buildFilterChip(
              label: 'General',
              isSelected: _selectedCategories.contains(0),
              onTap: () => _toggleIntSelection(_selectedCategories, 0),
              isDark: isDark,
            ),
          ...provider.categories
              .where((c) => c.nombre.trim().toLowerCase() != 'general')
              .map((Category cat) {
                return _buildFilterChip(
                  label: cat.nombre,
                  isSelected: _selectedCategories.contains(cat.id),
                  onTap: () => _toggleIntSelection(_selectedCategories, cat.id),
                  isDark: isDark,
                );
              }),
        ],
      ),
    );
  }

  Widget _buildBrandsAccordion(
    InventoryProvider provider,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return _buildAccordionCard(
      title: "Marcas",
      icon: Icons.branding_watermark_outlined,
      isExpanded: _brandsExpanded,
      selectedCount: _selectedBrands.length,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      onToggle: () =>
          _toggleExpandedState(() => _brandsExpanded = !_brandsExpanded),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (provider.hasOrphanBrands)
            _buildFilterChip(
              label: '[ Sin Marca ]',
              isSelected: _selectedBrands.contains(0),
              onTap: () => _toggleIntSelection(_selectedBrands, 0),
              isDark: isDark,
            ),
          ...provider.brands.map((Brand brand) {
            return _buildFilterChip(
              label: brand.nombre,
              isSelected: _selectedBrands.contains(brand.id),
              onTap: () => _toggleIntSelection(_selectedBrands, brand.id),
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProvidersAccordion(
    InventoryProvider provider,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    return _buildAccordionCard(
      title: "Proveedores",
      icon: Icons.local_shipping_outlined,
      isExpanded: _providersExpanded,
      selectedCount: _selectedProviders.length,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      onToggle: () =>
          _toggleExpandedState(() => _providersExpanded = !_providersExpanded),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: provider.providers.map<Widget>((ProviderModel prov) {
          return _buildFilterChip(
            label: prov.nombreEmpresa,
            isSelected: _selectedProviders.contains(prov.id),
            activeColor: Colors.purple,
            onTap: () => _toggleIntSelection(_selectedProviders, prov.id),
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }

  void _toggleIntSelection(List<int> list, int id) {
    _updateFilter(() {
      if (list.contains(id)) {
        list.remove(id);
      } else {
        list.add(id);
      }
    });
  }
}
