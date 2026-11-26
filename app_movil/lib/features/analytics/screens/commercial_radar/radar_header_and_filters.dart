part of '../commercial_radar_screen.dart';

/// Delegate rígido para Sticky Header de CommercialRadarScreen (0 píxeles de overflow)
class _RadarStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _RadarStickyHeaderDelegate({required this.child, this.height = 98.0});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _RadarStickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

mixin _RadarHeaderAndFiltersMixin on _CommercialRadarScreenStateBase {
  IconData _getCategoryChipIcon(String category) {
    final cat = category.toLowerCase();
    if (cat == 'todas') {
      return Icons.public_rounded;
    }
    if (cat.contains('región') || cat.contains('region')) {
      return Icons.location_on_outlined;
    }
    if (cat.contains('clima') || cat.contains('ruta')) {
      return Icons.wb_cloudy_outlined;
    }
    if (cat.contains('ley') || cat.contains('sunat')) {
      return Icons.gavel_rounded;
    }
    if (cat.contains('proveedor') || cat.contains('abastecimiento')) {
      return Icons.local_shipping_outlined;
    }
    if (cat.contains('campaña') ||
        cat.contains('campana') ||
        cat.contains('fecha')) {
      return Icons.event_available_outlined;
    }
    return Icons.label_outline_rounded;
  }

  @override
  Widget _buildStickyFilterSliver(
    bool isDark,
    Color bgColor,
    bool isNoticiasTab,
  ) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _RadarStickyHeaderDelegate(
        height: isNoticiasTab ? 142.0 : 96.0,
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            key: _tourKeys.searchFiltersKey,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pestaña Segmentada Superior: Noticias del Día vs Guardadas (X)
              Container(
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _activeTab = RadarTab.noticiasDelDia;
                          _visibleCount = 6;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _activeTab == RadarTab.noticiasDelDia
                                ? Colors.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.radar_rounded,
                                  size: 15,
                                  color: _activeTab == RadarTab.noticiasDelDia
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[700]),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Noticias del Día",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        _activeTab == RadarTab.noticiasDelDia
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _activeTab == RadarTab.noticiasDelDia
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _activeTab = RadarTab.guardadas;
                          _visibleCount = 6;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _activeTab == RadarTab.guardadas
                                ? Colors.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bookmarks_rounded,
                                  size: 15,
                                  color: _activeTab == RadarTab.guardadas
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[700]),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Guardadas (${_savedNewsMap.length})",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _activeTab == RadarTab.guardadas
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _activeTab == RadarTab.guardadas
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Buscador en Tiempo Real
              Container(
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey[300]!,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                    hintText: "Buscar noticias, rutas, SUNAT...",
                    hintStyle: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 17,
                      color: Colors.blueAccent,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey,
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              // Chips de Categorías Vectoriales Limpios (Solo si está en Noticias del Día)
              if (isNoticiasTab) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        final iconData = _getCategoryChipIcon(cat);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            avatar: Icon(
                              iconData,
                              size: 13,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.blueAccent,
                            ),
                            labelPadding: const EdgeInsets.only(
                              left: 2,
                              right: 4,
                            ),
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[800]),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => setState(() {
                              _selectedCategory = cat;
                              _visibleCount = 6;
                            }),
                            selectedColor: Colors.blueAccent,
                            backgroundColor: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.grey[200],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : (isDark
                                          ? Colors.white10
                                          : Colors.grey[300]!),
                              ),
                            ),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildFeedSliver(
    bool isDark,
    List<CommercialNewsItem> filtered,
    List<CommercialNewsItem> paged,
  ) {
    if (_isLoading && _allNewsItems.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            key: _tourKeys.signalCardKey,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 16),
                Text(
                  "Sintonizando radar con inteligencia artificial...",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            key: _tourKeys.signalCardKey,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _activeTab == RadarTab.guardadas
                      ? Icons.bookmarks_outlined
                      : Icons.radar_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  _activeTab == RadarTab.guardadas
                      ? "No tienes noticias guardadas aún"
                      : "No se encontraron noticias con los filtros actuales",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < paged.length) {
              return KeyedSubtree(
                key: index == 0 ? _tourKeys.signalCardKey : null,
                child: _buildNewsCard(paged[index], isDark),
              );
            } else if (paged.length < filtered.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _visibleCount += 6;
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      "Cargar más señales (${filtered.length - paged.length} restantes)",
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              );
            }
            return null;
          },
          childCount: paged.length < filtered.length
              ? paged.length + 1
              : paged.length,
        ),
      ),
    );
  }
}
