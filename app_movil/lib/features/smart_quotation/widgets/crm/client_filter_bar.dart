import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class ClientFilterBar extends StatelessWidget {
  const ClientFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      height: 48,
      color: bgColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        children: [
          _buildFilterChip(
            label: "Con Deuda",
            icon: Icons.money_off,
            isSelected: provider.filterHasDebt,
            activeColor: isDark ? Colors.red[400]! : Colors.red,
            isDark: isDark,
            onSelected: (_) => provider.toggleDebtFilter(),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: "Por Entregar",
            icon: Icons.local_shipping,
            isSelected: provider.filterPendingDelivery,
            activeColor: isDark ? Colors.orange[300]! : Colors.orange,
            isDark: isDark,
            onSelected: (_) => provider.toggleDeliveryFilter(),
          ),
          const SizedBox(width: 8),
          _buildConfidenceChip(context, provider, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
      selectedColor: activeColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? activeColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildConfidenceChip(BuildContext context, TrackingProvider provider, bool isDark) {
    bool isSelected = provider.filterConfidenceLevel != "todos";
    String label = isSelected ? provider.filterConfidenceLevel.toUpperCase() : "Confianza";
    Color activeColor = _getConfidenceColor(provider.filterConfidenceLevel, isDark);

    return InputChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield,
            size: 18,
            color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Icon(
            isSelected ? Icons.arrow_drop_down : Icons.arrow_drop_down,
            size: 20,
            color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ],
      ),
      selected: isSelected,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
      selectedColor: activeColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? activeColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.grey.shade300),
        ),
      ),
      showCheckmark: false,
      onPressed: () => _showConfidenceSelectorSheet(context, provider, isDark),
      onDeleted: isSelected ? () => provider.setConfidenceFilter('todos') : null,
      deleteIcon: Icon(Icons.close, size: 16, color: activeColor),
    );
  }

  Color _getConfidenceColor(String level, bool isDark) {
    switch (level.toLowerCase()) {
      case 'excelente':
        return isDark ? Colors.green[400]! : Colors.green[700]!;
      case 'bueno':
        return isDark ? Colors.blue[300]! : Colors.blue[700]!;
      case 'regular':
        return isDark ? Colors.orange[300]! : Colors.orange[800]!;
      case 'moroso':
        return isDark ? Colors.red[400]! : Colors.red[700]!;
      default:
        return isDark ? Colors.purple[300]! : Colors.purple;
    }
  }

  void _showConfidenceSelectorSheet(BuildContext context, TrackingProvider provider, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final options = [
      {'val': 'todos', 'label': 'Todos los niveles', 'desc': 'Ver todos los clientes', 'icon': Icons.people_outline, 'color': Colors.grey},
      {'val': 'excelente', 'label': 'Excelente', 'desc': 'Pago puntual y clientes VIP', 'icon': Icons.star, 'color': Colors.green},
      {'val': 'bueno', 'label': 'Bueno', 'desc': 'Confiable, historial de pago normal', 'icon': Icons.thumb_up, 'color': Colors.blue},
      {'val': 'regular', 'label': 'Regular', 'desc': 'Observado con retrasos ocasionales', 'icon': Icons.warning_amber, 'color': Colors.orange},
      {'val': 'moroso', 'label': 'Moroso', 'desc': 'Deuda crítica, solo pago de contado', 'icon': Icons.block, 'color': Colors.red},
    ];

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
          context,
          minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
        );
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, effectiveBottom),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.shield, color: Colors.purple, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Filtrar por Nivel de Confianza",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final isSelected = provider.filterConfidenceLevel == opt['val'];
                final optColor = opt['color'] as Color;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: optColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(opt['icon'] as IconData, color: optColor, size: 20),
                  ),
                  title: Text(
                    opt['label'] as String,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    opt['desc'] as String,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.purple, size: 22)
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    provider.setConfidenceFilter(opt['val'] as String);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: InteractiveSheetWrapper.kModalScrollBottomClearance),
            ],
          ),
          ),
        );
      },
    );
  }
}