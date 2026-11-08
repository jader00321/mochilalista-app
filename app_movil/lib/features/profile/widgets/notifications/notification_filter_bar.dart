import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationFilterBar extends StatelessWidget {
  final bool isDark;
  final String categoryFilter;
  final String timeFilter;
  final int totalCount;
  final int cobranzasCount;
  final int inventarioCount;
  final int cotizacionesCount;
  final DateTime? specificDate;
  final ValueChanged<String> onCategoryFilterChanged;
  final ValueChanged<String> onTimeFilterChanged;
  final VoidCallback onSpecificDateTapped;

  const NotificationFilterBar({
    super.key,
    required this.isDark,
    required this.categoryFilter,
    required this.timeFilter,
    required this.totalCount,
    required this.cobranzasCount,
    required this.inventarioCount,
    required this.cotizacionesCount,
    required this.specificDate,
    required this.onCategoryFilterChanged,
    required this.onTimeFilterChanged,
    required this.onSpecificDateTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1E1E28) : Colors.grey[50],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Categorías con Badges
            _buildCategoryChip(
              id: 'Todas',
              label: 'Todas',
              count: totalCount,
              icon: Icons.all_inbox_rounded,
              color: isDark ? Colors.blue[300]! : Colors.blue[700]!,
            ),
            _buildCategoryChip(
              id: 'Cobranzas',
              label: 'Cobranzas',
              count: cobranzasCount,
              icon: Icons.payments_outlined,
              color: isDark ? Colors.red[300]! : Colors.red[600]!,
            ),
            _buildCategoryChip(
              id: 'Inventario',
              label: 'Inventario',
              count: inventarioCount,
              icon: Icons.inventory_2_outlined,
              color: isDark ? Colors.amber[300]! : Colors.orange[800]!,
            ),
            _buildCategoryChip(
              id: 'Cotizaciones',
              label: 'Cotizaciones',
              count: cotizacionesCount,
              icon: Icons.receipt_long_rounded,
              color: isDark ? Colors.indigo[300]! : Colors.indigo[700]!,
            ),

            const SizedBox(width: 8),
            Container(width: 1.2, height: 22, color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300]),
            const SizedBox(width: 12),

            // Filtros Temporales
            ...['Todo', 'Hoy', '7 Días'].map((f) {
              final isSel = timeFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(f, style: const TextStyle(fontSize: 12.5)),
                  selected: isSel,
                  onSelected: (v) {
                    if (v) onTimeFilterChanged(f);
                  },
                  selectedColor: isDark ? Colors.purple.withValues(alpha: 0.25) : Colors.purple[50],
                  backgroundColor: isDark ? const Color(0xFF2A2A36) : Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSel ? (isDark ? Colors.purple[200] : Colors.purple[700]) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSel ? (isDark ? Colors.purple[400]! : Colors.purple[300]!) : Colors.transparent,
                    ),
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: ChoiceChip(
                label: Text(
                  specificDate == null ? 'Específico' : DateFormat('MMM yyyy').format(specificDate!), 
                  style: const TextStyle(fontSize: 12.5),
                ),
                selected: timeFilter == 'Específico',
                onSelected: (v) {
                  if (v) onSpecificDateTapped();
                },
                selectedColor: isDark ? Colors.purple.withValues(alpha: 0.25) : Colors.purple[50],
                backgroundColor: isDark ? const Color(0xFF2A2A36) : Colors.grey[200],
                labelStyle: TextStyle(
                  color: timeFilter == 'Específico' ? (isDark ? Colors.purple[200] : Colors.purple[700]) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontWeight: timeFilter == 'Específico' ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: timeFilter == 'Específico' ? (isDark ? Colors.purple[400]! : Colors.purple[300]!) : Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final isSel = categoryFilter == id;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onCategoryFilterChanged(id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSel 
                  ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                  : (isDark ? const Color(0xFF2A2A36) : Colors.grey[200]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel ? color.withValues(alpha: 0.6) : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isSel ? color : (isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? color : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSel ? color : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$count",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationSelectionBar extends StatelessWidget {
  final bool isDark;
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const NotificationSelectionBar({
    super.key,
    required this.isDark,
    required this.selectedCount,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.red[900]!.withValues(alpha: 0.2) : Colors.red[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$selectedCount seleccionadas", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.red[200] : Colors.red[800])),
          Row(
            children: [
              TextButton(
                onPressed: onCancel,
                child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
              ),
              if (selectedCount > 0)
                ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text("Eliminar"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
