import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
  void dispose() {
    _timer?.cancel();
  }
}

class HistorySearchBar extends StatefulWidget {
  const HistorySearchBar({super.key});

  @override
  State<HistorySearchBar> createState() => _HistorySearchBarState();
}

class _HistorySearchBarState extends State<HistorySearchBar> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 300);

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
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          hintText: "Buscar por cliente, #recibo, DNI...",
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
          isDense: true,
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          filled: true, 
          fillColor: isDark ? const Color(0xFF23232F) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (val) {
          _debouncer.run(() {
            provider.setSearchQuery(val);
          });
        },
        onSubmitted: (val) {
          _debouncer.run(() {
            provider.setSearchQuery(val);
          });
        },
      ),
    );
  }
}

class HistoryFilterChips extends StatelessWidget {
  const HistoryFilterChips({super.key});

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

  void _showPeriodOptions(BuildContext context, SaleProvider provider, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        Widget buildPeriodTile(String title, IconData icon, String targetFilter) {
          final bool isActive = provider.activeQuickFilter == targetFilter;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.08)) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? (isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade300) : Colors.transparent),
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
                provider.setQuickFilter(targetFilter);
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
              Text("Filtrar periodo de tiempo:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              buildPeriodTile("Hoy", Icons.today, 'hoy'),
              buildPeriodTile("Esta Semana", Icons.calendar_view_week, 'semana'),
              buildPeriodTile("Este Mes", Icons.calendar_month, 'este_mes'),
              buildPeriodTile("6 Meses", Icons.date_range, 'seis_meses'),
              buildPeriodTile("Todo el Tiempo", Icons.all_inclusive, 'todo'),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.edit_calendar, color: isDark ? Colors.orange[300] : Colors.orange[800]),
                  title: Text(
                    provider.activeQuickFilter == 'personalizado' ? "Rango Personalizado (Activo)" : "Rango Personalizado...", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.orange[300] : Colors.orange[800]
                    )
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDateRange(context, provider, isDark);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      }
    );
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
              color: isActive ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.08)) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? (isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade300) : Colors.transparent),
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
              buildSortTile("Mayor importe primero", Icons.arrow_upward, "monto_total", "desc"),
              buildSortTile("Menor importe primero", Icons.arrow_downward, "monto_total", "asc"),
              buildSortTile("Mayor deuda pendiente", Icons.money_off, "deuda_pendiente", "desc"),
              const SizedBox(height: 10),
            ],
          ),
        );
      }
    );
  }

  String _getPeriodLabel(SaleProvider provider) {
    switch (provider.activeQuickFilter) {
      case 'hoy': return "Hoy";
      case 'semana': return "Esta Semana";
      case 'este_mes': return "Este Mes";
      case 'seis_meses': return "6 Meses";
      case 'todo': return "Todo el Tiempo";
      case 'personalizado': return "Rango Personalizado";
      default: return "Periodo";
    }
  }

  String _getSortLabel(SaleProvider provider) {
    if (provider.currentSortBy == 'deuda_pendiente') return "Mayor deuda";
    if (provider.currentSortBy == 'monto_total') {
      return provider.currentOrder == 'asc' ? "Menor importe" : "Mayor importe";
    }
    if (provider.currentSortBy == 'fecha_venta') {
      return provider.currentOrder == 'asc' ? "Más antiguas" : "Más recientes";
    }
    return "Ordenar";
  }

  Widget _buildControlPill({
    required IconData icon,
    required String label,
    required bool isDark,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final activeColor = isDark ? Colors.blue[300]! : Colors.blue[800]!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF23232F) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isActive ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[700])),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? activeColor : (isDark ? Colors.white : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: isActive ? activeColor : (isDark ? Colors.grey[500] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSegment(String label, String value, SaleProvider provider, bool isDark, {Color? activeColor}) {
    final isSelected = provider.financialStatus == value;
    final color = activeColor ?? (isDark ? Colors.blue[300]! : Colors.blue[800]!);
    return Expanded(
      child: InkWell(
        onTap: () => provider.setFinancialFilter(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected 
                ? color.withValues(alpha: 0.14) 
                : (isDark ? const Color(0xFF23232F) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? color : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1A24) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: Selectores de Periodo y Orden
          Row(
            children: [
              Expanded(
                child: _buildControlPill(
                  icon: Icons.calendar_today_rounded,
                  label: _getPeriodLabel(provider),
                  isDark: isDark,
                  isActive: provider.activeQuickFilter != 'seis_meses',
                  onTap: () => _showPeriodOptions(context, provider, isDark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildControlPill(
                  icon: Icons.swap_vert_rounded,
                  label: _getSortLabel(provider),
                  isDark: isDark,
                  isActive: provider.currentSortBy != 'fecha_venta' || provider.currentOrder != 'desc',
                  onTap: () => _showSortOptions(context, provider, isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 2: Segmento Rápido de Estado Financiero (Todos / Pagados / Con Deuda)
          Row(
            children: [
              _buildFinancialSegment("Todos", 'todos', provider, isDark),
              const SizedBox(width: 8),
              _buildFinancialSegment("Pagados", 'pagados', provider, isDark, activeColor: Colors.green),
              const SizedBox(width: 8),
              _buildFinancialSegment("Con Deuda", 'con_deuda', provider, isDark, activeColor: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}