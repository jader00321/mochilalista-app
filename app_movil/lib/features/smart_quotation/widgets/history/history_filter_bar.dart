import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sale_provider.dart';

class HistoryFilterBar extends StatefulWidget {
  const HistoryFilterBar({super.key});

  @override
  State<HistoryFilterBar> createState() => _HistoryFilterBarState();
}

class _HistoryFilterBarState extends State<HistoryFilterBar> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SaleProvider>(context, listen: false).setSearchQuery("");
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _pickDateRange(BuildContext context, SaleProvider provider, bool isDark) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
                ? const ColorScheme.dark(primary: Colors.orange, surface: Color(0xFF23232F))
                : ColorScheme.light(primary: Colors.blue[900]!)
          ), 
          child: child!
        );
      },
    );

    if (range != null) {
      provider.setQuickFilter('personalizado', customStart: range.start, customEnd: range.end);
    }
  }

  void _showSortOptions(BuildContext context, SaleProvider provider, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        Widget buildSortTile(String title, IconData icon, String targetSortBy, String targetOrder) {
          final bool isActive = (provider.currentSortBy == targetSortBy && provider.currentOrder == targetOrder);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? (isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.08)) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.shade300) : Colors.transparent),
            ),
            child: ListTile(
              leading: Icon(icon, color: isActive ? (isDark ? Colors.blue[300] : Colors.blue[800]) : (isDark ? Colors.grey[400] : Colors.grey[600])),
              title: Text(
                title, 
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal, 
                  color: isActive ? (isDark ? Colors.blue[300] : Colors.blue[900]) : textColor
                )
              ),
              trailing: isActive ? Icon(Icons.check_circle, color: isDark ? Colors.blue[300] : Colors.blue[700]) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                provider.setSort(targetSortBy, targetOrder);
                Navigator.pop(context); 
              },
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Text("Ordenar resultados por:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              
              buildSortTile("Más recientes primero", Icons.calendar_today, "fecha_venta", "desc"),
              buildSortTile("Más antiguas primero", Icons.history, "fecha_venta", "asc"),
              buildSortTile("Mayor monto primero", Icons.arrow_upward, "monto_total", "desc"),
              buildSortTile("Menor monto primero", Icons.arrow_downward, "monto_total", "asc"),
              const SizedBox(height: 10),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1A24) : Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Buscar recibo o cliente...",
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey),
                suffixIcon: provider.searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, color: isDark ? Colors.white : Colors.black87), 
                      onPressed: () {
                        _searchCtrl.clear();
                        provider.setSearchQuery(""); 
                        FocusScope.of(context).unfocus();
                      }
                    ) 
                  : null,
                filled: true, 
                fillColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (val) => provider.setSearchQuery(val),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildChip("Hoy", 'hoy', provider, isDark),
                const SizedBox(width: 8),
                _buildChip("Esta Semana", 'semana', provider, isDark),
                const SizedBox(width: 8),
                _buildChip("Este Mes", 'este_mes', provider, isDark),
                const SizedBox(width: 8),
                _buildChip("Todas", 'todas', provider, isDark),
                const SizedBox(width: 8),
                
                ActionChip(
                  label: const Text("📅 Rango", style: TextStyle(fontWeight: FontWeight.bold)), 
                  backgroundColor: provider.activeQuickFilter == 'personalizado' ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[100]) : (isDark ? const Color(0xFF23232F) : Colors.grey[100]), 
                  side: BorderSide(color: provider.activeQuickFilter == 'personalizado' ? (isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.shade200) : Colors.transparent),
                  onPressed: () => _pickDateRange(context, provider, isDark)
                ),
                const SizedBox(width: 8),
                
                ActionChip(
                  label: Text("↕️ Ordenar", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)), 
                  backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white, 
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300), 
                  onPressed: () => _showSortOptions(context, provider, isDark)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, SaleProvider provider, bool isDark) {
    final isSelected = provider.activeQuickFilter == value;
    return ChoiceChip(
      label: Text(label), 
      selected: isSelected, 
      onSelected: (_) => provider.setQuickFilter(value), 
      selectedColor: isDark ? Colors.blue[300] : Colors.blue[800], 
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? (isDark ? Colors.black87 : Colors.white) : (isDark ? Colors.white70 : Colors.black87), 
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}