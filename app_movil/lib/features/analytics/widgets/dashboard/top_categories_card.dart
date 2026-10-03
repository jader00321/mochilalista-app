import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';

class TopCategoriesCard extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const TopCategoriesCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  State<TopCategoriesCard> createState() => _TopCategoriesCardState();
}

class _TopCategoriesCardState extends State<TopCategoriesCard> {
  int _selectedCategoryIndex = -1;
  bool _showByRevenue = false;
  Timer? _autoRotateTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted && _selectedCategoryIndex == -1) {
        setState(() {
          _showByRevenue = !_showByRevenue;
        });
      }
    });
  }

  void _onUserInteraction() {
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayList = List<Map<String, dynamic>>.from(widget.data.topCategories);
    if (_showByRevenue) {
      displayList.sort((a, b) => ((b['total_ingresos'] as num?) ?? 0).compareTo((a['total_ingresos'] as num?) ?? 0));
    }

    double maxVal = 0;
    if (displayList.isNotEmpty) {
      maxVal = _showByRevenue 
          ? (displayList[0]['total_ingresos'] as num?)?.toDouble() ?? 0
          : (displayList[0]['total_vendido'] as num).toDouble();
    }

    return GlassCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _showByRevenue ? "Categorías por Ingresos" : "Categorías por Unidades", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              GestureDetector(
                onTap: () {
                  _onUserInteraction();
                  setState(() { 
                    _showByRevenue = !_showByRevenue; 
                    _selectedCategoryIndex = -1; 
                  });
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: AnimatedContainer(
                    key: ValueKey(_showByRevenue),
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showByRevenue 
                          ? Colors.amber.withValues(alpha: 0.2) 
                          : Colors.indigoAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showByRevenue ? Colors.amber.withValues(alpha: 0.5) : Colors.indigoAccent.withValues(alpha: 0.5)
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showByRevenue ? Icons.attach_money : Icons.inventory_2, 
                          size: 16, 
                          color: _showByRevenue ? (widget.isDark ? Colors.amberAccent : Colors.orange[800]) : Colors.indigoAccent
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showByRevenue ? "Ingresos" : "Unidades", 
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: _showByRevenue ? (widget.isDark ? Colors.amberAccent : Colors.orange[800]) : Colors.indigoAccent
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Column(
              key: ValueKey(_showByRevenue),
              children: displayList.isEmpty 
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: widget.isDark ? Colors.grey[700] : Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            "No hay registros de ventas recientes para calcular las mejores categorías.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                ]
              : displayList.asMap().entries.map((e) {
                int index = e.key;
                var c = e.value;
                double amount = _showByRevenue ? ((c['total_ingresos'] as num?)?.toDouble() ?? 0) : (c['total_vendido'] as num).toDouble();
                double pct = maxVal > 0 ? (amount / maxVal) : 0;
                bool isSelected = index == _selectedCategoryIndex;

                return GestureDetector(
                  onTap: () {
                    _onUserInteraction();
                    setState(() {
                      _selectedCategoryIndex = _selectedCategoryIndex == index ? -1 : index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(isSelected ? 12.0 : 0.0),
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: isSelected ? (widget.isDark ? Colors.white10 : Colors.grey[100]) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(c['nombre'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13))),
                            Text(
                              _showByRevenue ? widget.formatCurrency(amount) : "${amount.toInt()} unid.", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 13,
                                color: _showByRevenue ? (widget.isDark ? Colors.amberAccent : Colors.orange[800]) : null
                              )
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: pct),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutQuart,
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _showByRevenue 
                                    ? (isSelected ? Colors.orange : Colors.amber)
                                    : (isSelected ? Colors.indigo : Colors.indigoAccent)
                              ),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 8,
                            );
                          },
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 12),
                          _buildDetailPanel(c, index, amount),
                        ]
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (widget.data.categoryInsight != null) ...[
            const SizedBox(height: 16),
            _buildSmartInsight(widget.data.categoryInsight!),
          ]
        ],
      ),
    );
  }

  Widget _buildSmartInsight(String insight) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDark 
              ? [Colors.blueAccent.withValues(alpha: 0.1), Colors.purpleAccent.withValues(alpha: 0.1)]
              : [Colors.blue.withValues(alpha: 0.05), Colors.purple.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2)
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: widget.isDark ? Colors.white70 : Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(Map<String, dynamic> c, int index, double amount) {
    String name = c['nombre'];
    String displayAmount = _showByRevenue ? widget.formatCurrency(amount) : "${amount.toInt()} unidades";
    
    double totalRevenue = 0;
    double totalUnits = 0;
    for (var cat in widget.data.topCategories) {
      totalRevenue += (cat['total_ingresos'] as num?)?.toDouble() ?? 0;
      totalUnits += (cat['total_vendido'] as num).toDouble();
    }
    
    double revenuePct = totalRevenue > 0 ? (((c['total_ingresos'] as num?)?.toDouble() ?? 0) / totalRevenue * 100) : 0;
    double unitsPct = totalUnits > 0 ? (((c['total_vendido'] as num).toDouble()) / totalUnits * 100) : 0;

    String insightText;
    if (_showByRevenue) {
      if (index == 0) {
        insightText = "💎 $name aporta el ${revenuePct.toStringAsFixed(1)}% de tus ingresos globales ($displayAmount). Asegura el máximo margen posible aquí y mantén el stock en verde siempre.";
      } else if (revenuePct > unitsPct * 1.5) {
        insightText = "📈 $name genera $displayAmount (${revenuePct.toStringAsFixed(1)}%). Tiene un ticket promedio alto comparado con su volumen. ¡Sigue ofreciéndolo!";
      } else {
        insightText = "$name suma $displayAmount a tu caja. Intenta hacer up-selling combinándolo con tus productos más vendidos para elevar el ticket.";
      }
    } else {
      if (index == 0) {
        insightText = "🏆 $name lidera tu volumen con $displayAmount vendidas (${unitsPct.toStringAsFixed(1)}%). Amplía el surtido aquí: más variedad se traduce en mayor rotación de clientes.";
      } else if (unitsPct > revenuePct * 1.5) {
        insightText = "🛒 $name movió $displayAmount (${unitsPct.toStringAsFixed(1)}% del volumen). Atrae muchos clientes, ideal para usarlos como producto gancho hacia artículos más rentables.";
      } else {
        insightText = "$name vendió $displayAmount. Mantiene un flujo constante. Considera promociones flash para impulsar su venta en días flojos.";
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            index == 0 ? Icons.workspace_premium : Icons.category, 
            color: _showByRevenue ? Colors.amber : Colors.indigoAccent[200], 
            size: 20
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insightText,
              style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
            ),
          )
        ],
      ),
    );
  }
}
