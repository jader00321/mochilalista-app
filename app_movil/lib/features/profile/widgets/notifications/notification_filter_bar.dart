import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationFilterBar extends StatelessWidget {
  final bool isDark;
  final String readFilter;
  final String timeFilter;
  final DateTime? specificDate;
  final ValueChanged<String> onReadFilterChanged;
  final ValueChanged<String> onTimeFilterChanged;
  final VoidCallback onSpecificDateTapped;

  const NotificationFilterBar({
    super.key,
    required this.isDark,
    required this.readFilter,
    required this.timeFilter,
    required this.specificDate,
    required this.onReadFilterChanged,
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
        child: Row(
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: readFilter,
                dropdownColor: isDark ? const Color(0xFF23232F) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                icon: Icon(Icons.filter_list, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                items: ['Todas', 'Leídas', 'No Leídas'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  if (v != null) onReadFilterChanged(v);
                },
              ),
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: isDark ? Colors.white24 : Colors.grey[300]),
            const SizedBox(width: 16),
            ...['Todo', 'Hoy', '7 Días', 'Mes'].map((f) {
              final isSel = timeFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(f, style: const TextStyle(fontSize: 13)),
                  selected: isSel,
                  onSelected: (v) {
                    if (v) onTimeFilterChanged(f);
                  },
                  selectedColor: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple[50],
                  backgroundColor: isDark ? const Color(0xFF2A2A36) : Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSel ? (isDark ? Colors.purple[200] : Colors.purple[700]) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSel ? (isDark ? Colors.purple[400]! : Colors.purple[300]!) : Colors.transparent),
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(specificDate == null ? 'Específico' : DateFormat('MMM yyyy').format(specificDate!), style: const TextStyle(fontSize: 13)),
                selected: timeFilter == 'Específico',
                onSelected: (v) {
                  if (v) onSpecificDateTapped();
                },
                selectedColor: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple[50],
                backgroundColor: isDark ? const Color(0xFF2A2A36) : Colors.grey[200],
                labelStyle: TextStyle(
                  color: timeFilter == 'Específico' ? (isDark ? Colors.purple[200] : Colors.purple[700]) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontWeight: timeFilter == 'Específico' ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: timeFilter == 'Específico' ? (isDark ? Colors.purple[400]! : Colors.purple[300]!) : Colors.transparent),
                ),
              ),
            ),
          ],
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
