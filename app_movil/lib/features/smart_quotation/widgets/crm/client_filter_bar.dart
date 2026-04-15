import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tracking_provider.dart';

class ClientFilterBar extends StatelessWidget {
  const ClientFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      height: 70,
      color: bgColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _buildFilterChip(
            label: "Con Deuda",
            icon: Icons.money_off,
            isSelected: provider.filterHasDebt,
            activeColor: isDark ? Colors.red[400]! : Colors.red,
            isDark: isDark,
            onSelected: (_) => provider.toggleDebtFilter(),
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            label: "Por Entregar",
            icon: Icons.local_shipping,
            isSelected: provider.filterPendingDelivery,
            activeColor: isDark ? Colors.orange[300]! : Colors.orange,
            isDark: isDark,
            onSelected: (_) => provider.toggleDeliveryFilter(),
          ),
          const SizedBox(width: 10),
          // 🔥 FASE 4: NUEVO FILTRO
          _buildFilterChip(
            label: "Clientes App",
            icon: Icons.phone_android,
            isSelected: provider.filterIsAppClient,
            activeColor: isDark ? Colors.teal[300]! : Colors.teal,
            isDark: isDark,
            onSelected: (_) => provider.toggleAppClientFilter(),
          ),
          const SizedBox(width: 10),
          _buildConfidenceChip(provider, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required IconData icon, required bool isSelected, required Color activeColor, required bool isDark, required Function(bool) onSelected}) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 15)),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
      selectedColor: activeColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: isSelected ? activeColor.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.grey.shade300))),
    );
  }

  Widget _buildConfidenceChip(TrackingProvider provider, bool isDark) {
    bool isSelected = provider.filterConfidenceLevel != "todos";
    String label = isSelected ? provider.filterConfidenceLevel.toUpperCase() : "Nivel Confianza";
    Color activeColor = isDark ? Colors.purple[300]! : Colors.purple;

    return InputChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield, size: 20, color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 15)),
          if (!isSelected) ...[
            const SizedBox(width: 6),
            Icon(Icons.arrow_drop_down, size: 22, color: isDark ? Colors.grey[400] : Colors.grey),
          ]
        ],
      ),
      selected: isSelected,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
      selectedColor: activeColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87), 
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14), 
        side: BorderSide(color: isSelected ? activeColor.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.grey.shade300))
      ),
      showCheckmark: false,
      onPressed: () {
        String next;
        switch (provider.filterConfidenceLevel) {
          case 'todos': next = 'excelente'; break;
          case 'excelente': next = 'bueno'; break;
          case 'bueno': next = 'regular'; break;
          case 'regular': next = 'moroso'; break;
          default: next = 'todos';
        }
        provider.setConfidenceFilter(next);
      },
      onDeleted: isSelected ? () {
        provider.setConfidenceFilter('todos');
      } : null,
      deleteIcon: Icon(Icons.close, size: 20, color: activeColor),
    );
  }
}