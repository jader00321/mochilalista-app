part of '../smart_restock_screen.dart';

mixin _SmartRestockHeaderAndKpisMixin on _SmartRestockScreenStateBase {
  // =========================================================================
  // BARRA DE KPIS SUPERIORES DE ABASTECIMIENTO
  // =========================================================================
  @override
  Widget _buildKpiSummaryBar(bool isDark) {
    final reabastecerCount = _items
        .where((i) => i.status != 'saludable' || i.suggestedQty > 0)
        .length;
    final agotadosCount = _items.where((i) => i.currentStock == 0).length;
    final selectedItems = _items.where((i) => i.isSelected).toList();
    final totalInversion = selectedItems.fold(
      0.0,
      (sum, i) => sum + (i.orderQty * i.cost),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: "Por Pedir",
              value: "$reabastecerCount",
              color: reabastecerCount > 0 ? Colors.redAccent : Colors.green,
              icon: Icons.assignment_late_outlined,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              title: "Agotados",
              value: "$agotadosCount",
              color: agotadosCount > 0 ? Colors.red[900]! : Colors.green,
              icon: Icons.warning_amber_rounded,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              title: "Inversión OC",
              value: AppCurrency.format(totalInversion),
              color: Colors.blueAccent,
              icon: Icons.shopping_cart_checkout,
              isDark: isDark,
              isCompactAmount: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
    bool isCompactAmount = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isCompactAmount ? 13 : 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildHelpCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: isDark ? const Color(0xFF1E293B) : Colors.blue[50],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.blue[200]!,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _showHelpCard = !_showHelpCard),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¿Cómo leer esta pantalla e interpretar ROP?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.blue[200] : Colors.blue[800],
                        ),
                      ),
                    ),
                    Icon(
                      _showHelpCard
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: !_showHelpCard
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '• ROP (Punto de Reorden): Nivel mínimo de stock. Si tu stock cae a este valor o menos, debes pedir producto de inmediato.\n'
                            '• Velocidad: Si un producto rota lento, se muestra en unidades al mes (ej. 1.1/mes) o al día.\n'
                            '• Personaliza tu OC: Marca o desmarca productos con la casilla y usa los botones (+ / -) para modificar las cantidades antes de exportar el PDF.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// DELEGATE PINNED PARA BUSCADOR Y CHIPS (REGLA TÉCNICA 3: FONDO SÓLIDO Y EXACTITUD)
// =========================================================================
class _StickySearchAndFilterHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String currentFilter;
  final ValueChanged<String> onFilterSelected;
  final List<SmartRestockItem> items;
  final bool isDark;

  const _StickySearchAndFilterHeaderDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.currentFilter,
    required this.onFilterSelected,
    required this.items,
    required this.isDark,
  });

  @override
  double get minExtent => 98.0;

  @override
  double get maxExtent => 98.0;

  @override
  bool shouldRebuild(
    covariant _StickySearchAndFilterHeaderDelegate oldDelegate,
  ) {
    return oldDelegate.searchQuery != searchQuery ||
        oldDelegate.currentFilter != currentFilter ||
        oldDelegate.items != items ||
        oldDelegate.isDark != isDark;
  }

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    IconData? icon,
    Color? color,
  }) {
    bool isSelected = currentFilter == filterKey;
    Color effectiveColor = color ?? Colors.blueAccent;

    return FilterChip(
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: icon != null
          ? Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : effectiveColor,
            )
          : null,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      selectedColor: effectiveColor,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? Colors.white12 : Colors.grey[300]!),
        ),
      ),
      onSelected: (_) => onFilterSelected(filterKey),
    );
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final porPedirCount = items
        .where((i) => i.status != 'saludable' || i.suggestedQty > 0)
        .length;
    final urgentesCount = items
        .where((i) => i.status == 'agotado' || i.status == 'critico')
        .length;
    final preventivosCount = items
        .where((i) => i.status == 'preventivo')
        .length;
    final saludablesCount = items.where((i) => i.status == 'saludable').length;

    return Container(
      height: 98.0,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF1F5F9), // Fondo 100% sólido del Scaffold
        boxShadow: [
          if (shrinkOffset > 0)
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Buscador rápido (height 38)
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[300]!,
              ),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: "Buscar producto por nombre o marca...",
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Fila de chips acotada estrictamente con SizedBox(height: 38)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: "Por Pedir ($porPedirCount)",
                  icon: Icons.checklist_rounded,
                  filterKey: 'por_pedir',
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "Urgentes ($urgentesCount)",
                  icon: Icons.warning_amber_rounded,
                  filterKey: 'urgentes',
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "Preventivos ($preventivosCount)",
                  icon: Icons.shield_outlined,
                  filterKey: 'preventivos',
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "Saludables ($saludablesCount)",
                  icon: Icons.check_circle_outline,
                  filterKey: 'saludables',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "Todos (${items.length})",
                  icon: Icons.list_alt_rounded,
                  filterKey: 'todos',
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
