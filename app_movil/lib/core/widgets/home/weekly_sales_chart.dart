import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class WeeklySalesChart extends StatefulWidget {
  const WeeklySalesChart({super.key});

  @override
  State<WeeklySalesChart> createState() => _WeeklySalesChartState();
}

class _WeeklySalesChartState extends State<WeeklySalesChart> {
  bool _isExpanded = false;
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final salesProv = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (salesProv.isLoading) {
      return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
    }

    // Calcular ventas por día de los últimos 7 días
    final now = DateTime.now();
    final Map<int, double> salesByDay = {
      for (int i = 0; i < 7; i++) now.subtract(Duration(days: i)).weekday: 0.0
    };
    final Map<int, int> countByDay = {
      for (int i = 0; i < 7; i++) now.subtract(Duration(days: i)).weekday: 0
    };

    for (var sale in salesProv.salesHistory) {
      if (sale.isArchived || sale.origenVenta == 'prestamo_personal') continue;
      try {
        final date = DateTime.parse(sale.saleDate);
        if (now.difference(date).inDays < 7) {
          salesByDay[date.weekday] = (salesByDay[date.weekday] ?? 0) + sale.totalAmount;
          countByDay[date.weekday] = (countByDay[date.weekday] ?? 0) + 1;
        }
      } catch (e) {
        continue;
      }
    }

    final maxSale = salesByDay.values.isEmpty ? 1.0 : salesByDay.values.reduce((a, b) => a > b ? a : b);
    final highestVal = maxSale == 0 ? 1.0 : maxSale;
    final bool hasSales = maxSale > 0;

    final List<String> days = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
    final List<String> shortDays = ["L", "M", "M", "J", "V", "S", "D"];
    final double currentWeekTotal = salesByDay.values.fold(0.0, (a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER INTERACTIVO (Mini-resumen)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (!_isExpanded) _selectedIndex = -1;
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.bar_chart, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Ventas de la Semana", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  ),
                  if (!_isExpanded && hasSales)
                    Text(
                      AppCurrency.format(currentWeekTotal),
                      style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.greenAccent[400] : Colors.green[700], fontSize: 14),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  )
                ],
              ),
            ),
          ),
          
          // CONTENIDO EXPANDIBLE
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              child: !hasSales
                  ? _buildEmptyState(context, isDark)
                  : Column(
                      children: [
                        // Tooltip dinámico
                        if (_selectedIndex != -1)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _getTooltipText(_selectedIndex, days, salesByDay, countByDay, highestVal),
                                    style: TextStyle(
                                      color: isDark ? Colors.blue[200] : Colors.blue[800],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 48), // Espacio para cuando no hay tooltip para mantener la altura constante

                        // Gráfico
                        SizedBox(
                          height: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (index) {
                              final dayIndex = (now.weekday - 6 + index) % 7;
                              final actualDay = dayIndex <= 0 ? dayIndex + 7 : dayIndex;
                              final value = salesByDay[actualDay] ?? 0.0;
                              final percentage = value / highestVal;
                              final isSelected = _selectedIndex == actualDay;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = isSelected ? -1 : actualDay;
                                  });
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (value > 0 && !isSelected)
                                      Text(
                                        NumberFormat.compactCurrency(symbol: '', decimalDigits: 0).format(value),
                                        style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ),
                                    const SizedBox(height: 4),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: percentage),
                                      duration: const Duration(milliseconds: 800),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, val, child) {
                                        return Container(
                                          width: MediaQuery.of(context).size.width > 400 ? 20 : 16,
                                          height: 80 * val,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: value > 0
                                                  ? (isSelected
                                                      ? (isDark ? [Colors.orange[400]!, Colors.orange[600]!] : [Colors.orange[300]!, Colors.orange[600]!])
                                                      : (isDark ? [Colors.blue[400]!, Colors.blue[600]!] : [Colors.blue[300]!, Colors.blue[600]!]))
                                                  : [Colors.grey.withValues(alpha: 0.2), Colors.grey.withValues(alpha: 0.2)],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: isSelected && value > 0
                                                ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      shortDays[actualDay - 1],
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                        fontSize: 12,
                                        color: isSelected 
                                            ? (isDark ? Colors.orange[300] : Colors.orange[700]) 
                                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  String _getTooltipText(int day, List<String> dayNames, Map<int, double> salesByDay, Map<int, int> countByDay, double highestVal) {
    final value = salesByDay[day] ?? 0.0;
    final count = countByDay[day] ?? 0;
    final dayName = dayNames[day - 1];

    if (value == 0) return "$dayName - Sin ventas";
    
    final formattedValue = AppCurrency.format(value);
    final isHighest = value == highestVal && value > 0;
    
    if (isHighest) {
      return "Día con mayor venta: $dayName - $formattedValue ($count ventas)";
    }
    return "$dayName - $formattedValue ($count ventas)";
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.query_stats, color: isDark ? Colors.grey[500] : Colors.grey[400], size: 32),
          const SizedBox(height: 12),
          Text(
            "Sin ventas esta semana",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            "Realiza tu primera venta para ver el rendimiento aquí.",
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }
}
