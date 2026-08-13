import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';

class KpiSummaryRow extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const KpiSummaryRow({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  State<KpiSummaryRow> createState() => _KpiSummaryRowState();
}

class _KpiSummaryRowState extends State<KpiSummaryRow> {
  int _highlightedIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _highlightedIndex = (_highlightedIndex + 1) % 7;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onCardTap(int index) {
    setState(() {
      _highlightedIndex = index;
    });
    _startTimer(); // Reset timer
  }

  List<Map<String, dynamic>> _getKpis() {
    final data = widget.data;
    return [
      {
        'title': 'Ventas',
        'value': '${data.totalTransactions}',
        'icon': Icons.receipt_long,
        'color': Colors.blueAccent,
        'explanation': 'El número total de transacciones de venta completadas en tu negocio. Un mayor número indica más actividad comercial.',
      },
      {
        'title': 'Crecimiento',
        'value': '${data.salesGrowthRate > 0 ? '+' : ''}${data.salesGrowthRate.toStringAsFixed(1)}%',
        'icon': data.salesGrowthRate >= 0 ? Icons.trending_up : Icons.trending_down,
        'color': data.salesGrowthRate >= 0 ? Colors.green : Colors.redAccent,
        'explanation': 'Compara el volumen de ventas actual con el periodo anterior. Te ayuda a saber si tu negocio está expandiéndose o contrayéndose.',
      },
      {
        'title': 'Rotación',
        'value': data.inventoryTurnoverRatio.toStringAsFixed(2),
        'icon': Icons.autorenew,
        'color': Colors.orangeAccent,
        'explanation': 'Indica cuántas veces se ha vendido y reemplazado el inventario. Idealmente, busca un valor mayor a 1.0.',
      },
      {
        'title': 'Valor Stock',
        'value': widget.formatCurrency(data.inventoryValue),
        'icon': Icons.inventory_2,
        'color': Colors.purpleAccent,
        'explanation': 'Es el dinero total que has invertido en los productos que actualmente tienes en tu almacén. Representa tu activo más importante.',
      },
      {
        'title': 'Inmovilizado',
        'value': widget.formatCurrency(data.immobilizedCapital),
        'icon': Icons.lock_outline,
        'color': Colors.redAccent,
        'explanation': 'Este es el capital estancado en productos que NO se han vendido en los últimos 90 días. Dinero inmovilizado es dinero que no genera ganancias. Considera armar combos o liquidaciones para liberarlo.',
      },
      {
        'title': 'Liq. Recuperada',
        'value': widget.formatCurrency(data.recoveredLiquidity),
        'icon': Icons.water_drop,
        'color': Colors.lightBlueAccent,
        'explanation': 'Mide el dinero que has recuperado al vender productos estancados mediante estrategias de liquidación.',
      },
      {
        'title': 'Ticket Prom.',
        'value': widget.formatCurrency(data.averageTicket),
        'icon': Icons.confirmation_number,
        'color': Colors.teal,
        'explanation': 'Es el monto promedio que gasta cada cliente en una sola compra. Un ticket mayor indica ventas más rentables.',
      },
    ];
  }

  void _showKpiDetail(BuildContext context, String title, String value, IconData icon, Color color, String explanation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey))),
                  const SizedBox(height: 8),
                  Center(child: Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.black12 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            explanation,
                            style: TextStyle(fontSize: 14, height: 1.5, color: widget.isDark ? Colors.grey[300] : Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Entendido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildHighlightedCard({required Key key, required Map<String, dynamic> kpi}) {
    return GestureDetector(
      key: key,
      onTap: () => _showKpiDetail(context, kpi['title'], kpi['value'], kpi['icon'], kpi['color'], kpi['explanation']),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (kpi['color'] as Color).withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: GlassCard(
          isDark: widget.isDark,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (kpi['color'] as Color).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(kpi['icon'], color: kpi['color'], size: 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kpi['title'], style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        kpi['value'], 
                        style: TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.bold, 
                          color: widget.isDark ? Colors.white : Colors.black87
                        )
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.touch_app, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallCard(int index, Map<String, dynamic> kpi) {
    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: GlassCard(
        isDark: widget.isDark,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(kpi['icon'], color: kpi['color'], size: 24),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                kpi['value'], 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 15, 
                  color: kpi['title'] == 'Inmovilizado' ? kpi['color'] : (widget.isDark ? Colors.white : Colors.black87)
                )
              ),
            ),
            const SizedBox(height: 2),
            Text(
              kpi['title'], 
              style: const TextStyle(fontSize: 10, color: Colors.grey), 
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _getKpis();
    final highlighted = kpis[_highlightedIndex];
    
    // Separar los índices restantes
    List<int> otherIndices = [];
    for (int i = 0; i < kpis.length; i++) {
      if (i != _highlightedIndex) otherIndices.add(i);
    }
    
    return Column(
      children: [
        // Tarjeta Central Destacada Animada
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0.0), 
                  end: Offset.zero
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _buildHighlightedCard(
            key: ValueKey<int>(_highlightedIndex),
            kpi: highlighted,
          ),
        ),
        const SizedBox(height: 16),
        // Grid de las tarjetas restantes
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: otherIndices.length,
          itemBuilder: (context, index) {
            int originalIndex = otherIndices[index];
            return _buildSmallCard(originalIndex, kpis[originalIndex]);
          },
        ),
      ],
    );
  }
}

