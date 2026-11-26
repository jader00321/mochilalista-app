import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_movil/core/widgets/search/omni_search_models.dart';

class OmniCategoryChipsBar extends StatelessWidget {
  final String activeCategory;
  final OmniSearchCounts counts;
  final bool isDark;
  final ValueChanged<String> onCategoryChanged;

  const OmniCategoryChipsBar({
    super.key,
    required this.activeCategory,
    required this.counts,
    required this.isDark,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('all', 'Todos (${counts.total})', Icons.apps_rounded),
          const SizedBox(width: 8),
          _buildChip(
            'products',
            'Productos (${counts.products})',
            Icons.inventory_2_outlined,
          ),
          const SizedBox(width: 8),
          _buildChip(
            'clients',
            'Clientes (${counts.clients})',
            Icons.person_outline_rounded,
          ),
          const SizedBox(width: 8),
          _buildChip(
            'quotes',
            'Cotizaciones (${counts.quotes})',
            Icons.description_outlined,
          ),
          const SizedBox(width: 8),
          _buildChip(
            'sales',
            'Ventas (${counts.sales})',
            Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String id, String label, IconData icon) {
    final isSelected = activeCategory == id;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onCategoryChanged(id);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue[700] : Colors.blue[600])
              : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OmniSortBarRow extends StatelessWidget {
  final bool isQueryEmpty;
  final OmniSortOption sortOption;
  final bool isDark;
  final ValueChanged<OmniSortOption> onSortChanged;

  const OmniSortBarRow({
    super.key,
    required this.isQueryEmpty,
    required this.sortOption,
    required this.isDark,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            isQueryEmpty
                ? "Registros recientes del negocio"
                : "Resultados ordenados por:",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<OmniSortOption>(
          initialValue: sortOption,
          onSelected: (opt) {
            HapticFeedback.selectionClick();
            onSortChanged(opt);
          },
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.blue.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  sortOption.icon,
                  size: 14,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
                const SizedBox(width: 6),
                Text(
                  sortOption.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[300] : Colors.blue[800],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
              ],
            ),
          ),
          itemBuilder: (ctx) => OmniSortOption.values.map((opt) {
            final isSelected = opt == sortOption;
            return PopupMenuItem(
              value: opt,
              child: Row(
                children: [
                  Icon(
                    opt.icon,
                    size: 16,
                    color: isSelected
                        ? Colors.blue
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.blue
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class OmniSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData? icon;
  final bool isDark;

  const OmniSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color: isDark ? Colors.blue[300] : Colors.blue[800],
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$count elementos",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
