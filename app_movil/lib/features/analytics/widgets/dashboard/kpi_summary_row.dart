import 'package:flutter/material.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';

class KpiSummaryRow extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double)? formatCurrency;

  const KpiSummaryRow({
    super.key,
    required this.data,
    required this.isDark,
    this.formatCurrency,
  });

  @override
  State<KpiSummaryRow> createState() => _KpiSummaryRowState();
}

class _KpiSummaryRowState extends State<KpiSummaryRow> {
  int _highlightedIndex = 0;
  bool _isDetailExpanded = false;

  String _formatAmount(double amount) {
    if (widget.formatCurrency != null) {
      return widget.formatCurrency!(amount);
    }
    return AppCurrency.format(amount);
  }

  void _onCardTap(int index) {
    setState(() {
      _highlightedIndex = index;
      _isDetailExpanded = false;
    });
  }

  List<Map<String, dynamic>> _getKpis() {
    final data = widget.data;
    final growthStr = '${data.salesGrowthRate > 0 ? '+' : ''}${data.salesGrowthRate.toStringAsFixed(1)}%';
    
    // Dynamic Insights
    String ventasInsight = "Has completado ${data.totalTransactions} ventas. ${data.totalTransactions > 100 ? '¡Excelente volumen! Tu negocio tiene ritmo constante.' : (data.totalTransactions > 0 ? 'Mantén el esfuerzo para seguir sumando.' : 'Pocas ventas registradas. Revisa si estás capturando todas las transacciones en el sistema.')}";
    
    String crecInsight = data.salesGrowthRate >= 0 
        ? "Creciste un ${data.salesGrowthRate.toStringAsFixed(1)}% respecto al periodo anterior. ¡Sigue así!" 
        : "Tus ventas cayeron un ${data.salesGrowthRate.abs().toStringAsFixed(1)}%. Revisa qué productos estrella podrían estar sin stock o lanza una promoción flash.";

    String rotacionInsight = "Tu inventario rota ${data.inventoryTurnoverRatio.toStringAsFixed(2)} veces. ${data.inventoryTurnoverRatio >= 2 ? '¡Excelente! Tu mercancía se mueve rápido.' : (data.inventoryTurnoverRatio >= 1 ? 'Rotación saludable, pero hay espacio para mejorar.' : 'Rotación lenta. Tienes capital estancado. Considera liquidar productos muertos.')}";

    String stockInsight = "Tienes ${_formatAmount(data.inventoryValue)} invertidos en inventario. ${data.immobilizedCapital > 0 ? 'De eso, ${_formatAmount(data.immobilizedCapital)} están estancados en productos sin ventas recientes.' : '¡Excelente gestión! Todo tu capital está en movimiento.'}";

    String inmovInsight = "Tienes ${_formatAmount(data.immobilizedCapital)} atrapados en ${data.deadStockCount} productos sin movimiento. ${data.deadStockCount > 0 ? 'Crea una Promoción de Liquidación para recuperar este dinero y reinvertirlo en productos que sí se venden.' : '¡Felicidades! No tienes capital inmovilizado.'}";

    String liqInsight = data.recoveredLiquidity > 0 
        ? "¡Has recuperado ${_formatAmount(data.recoveredLiquidity)} vendiendo stock estancado! Sigue usando las promociones de liquidación." 
        : "Aún no has recuperado liquidez. Crea tu primera Promoción de Liquidación desde el módulo de Promociones.";

    String ticketInsight = "Cada cliente gasta en promedio ${_formatAmount(data.averageTicket)} por compra. ${data.averageTicket >= 50 ? 'Buen ticket. Ofrece combos para subirlo aún más.' : 'Incentiva ventas cruzadas para elevar el gasto promedio.'}";

    return [
      {
        'title': 'Ventas',
        'value': '${data.totalTransactions}',
        'icon': Icons.receipt_long,
        'color': Colors.blueAccent,
        'explanation': ventasInsight,
      },
      {
        'title': 'Crecimiento',
        'value': growthStr,
        'icon': data.salesGrowthRate >= 0 ? Icons.trending_up : Icons.trending_down,
        'color': data.salesGrowthRate >= 0 ? Colors.green : Colors.redAccent,
        'explanation': crecInsight,
      },
      {
        'title': 'Rotación',
        'value': '${data.inventoryTurnoverRatio.toStringAsFixed(2)}x',
        'icon': Icons.autorenew,
        'color': Colors.orangeAccent,
        'explanation': rotacionInsight,
      },
      {
        'title': 'Valor Stock',
        'value': _formatAmount(data.inventoryValue),
        'icon': Icons.inventory_2,
        'color': Colors.purpleAccent,
        'explanation': stockInsight,
      },
      {
        'title': 'Inmovilizado',
        'value': _formatAmount(data.immobilizedCapital),
        'icon': Icons.lock_outline,
        'color': Colors.redAccent,
        'explanation': inmovInsight,
      },
      {
        'title': 'Liq. Recuperada',
        'value': _formatAmount(data.recoveredLiquidity),
        'icon': Icons.water_drop,
        'color': Colors.lightBlueAccent,
        'explanation': liqInsight,
      },
      {
        'title': 'Ticket Prom.',
        'value': _formatAmount(data.averageTicket),
        'icon': Icons.confirmation_number,
        'color': Colors.teal,
        'explanation': ticketInsight,
      },
    ];
  }

  Widget _buildHighlightedCard({required Key key, required Map<String, dynamic> kpi}) {
    return GestureDetector(
      key: key,
      onTap: () {
        setState(() {
          _isDetailExpanded = !_isDetailExpanded;
        });
      },
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
                  color: (kpi['color'] as Color).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(kpi['icon'], color: kpi['color'], size: 36),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi['title'], 
                      style: TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600]
                      )
                    ),
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
              const SizedBox(width: 8),
              Icon(
                _isDetailExpanded ? Icons.expand_less : Icons.touch_app, 
                color: widget.isDark ? Colors.grey[400] : Colors.grey[500], 
                size: 20
              ),
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
                  fontSize: 14, 
                  color: kpi['title'] == 'Inmovilizado' 
                      ? kpi['color'] 
                      : (widget.isDark ? Colors.white : Colors.black87)
                )
              ),
            ),
            const SizedBox(height: 2),
            Text(
              kpi['title'], 
              style: TextStyle(
                fontSize: 10, 
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600]
              ), 
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
    
    // Índices restantes
    List<int> otherIndices = [];
    for (int i = 0; i < kpis.length; i++) {
      if (i != _highlightedIndex) otherIndices.add(i);
    }
    
    return Column(
      children: [
        // Tarjeta Central Destacada Animada
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0.0), 
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
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _isDetailExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 14.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.black26 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: highlighted['color'], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            highlighted['explanation'],
                            style: TextStyle(fontSize: 13, height: 1.45, color: widget.isDark ? Colors.grey[300] : Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        // Grid de las tarjetas restantes
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
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
