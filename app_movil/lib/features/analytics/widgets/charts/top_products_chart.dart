import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/core/widgets/product_nomenclature_label.dart';

class TopProductsChart extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;

  const TopProductsChart({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<TopProductsChart> createState() => _TopProductsChartState();
}

class _TopProductsChartState extends State<TopProductsChart> {
  int _selectedProductIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.topProducts.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (var p in widget.data.topProducts) {
      double totalVendido = (p['total_vendido'] as num).toDouble();
      if (totalVendido > maxVal) maxVal = totalVendido;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top Productos Más Vendidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ...widget.data.topProducts.asMap().entries.map((e) {
            int index = e.key;
            var p = e.value;
            double totalVendido = (p['total_vendido'] as num).toDouble();
            double pct = maxVal > 0 ? (totalVendido / maxVal) : 0;
            bool isSelected = index == _selectedProductIndex;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedProductIndex == index) {
                    _selectedProductIndex = -1;
                  } else {
                    _selectedProductIndex = index;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 8.0 : 0.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: isSelected ? (widget.isDark ? Colors.white10 : Colors.grey[100]) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ProductNomenclatureLabel(
                            nombre: p['nombre']?.toString() ?? '',
                            marca: p['marca_nombre']?.toString(),
                            presentacion: p['presentacion_nombre']?.toString(),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${totalVendido.toInt()} unid.",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (p['monto_vendido'] != null)
                              Text(
                                "S/ ${(p['monto_vendido'] as num).toDouble().toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            color: widget.isDark ? Colors.white10 : Colors.grey[200],
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: pct),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutQuart,
                            builder: (context, value, child) {
                              return FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      colors: isSelected 
                                        ? [Colors.orange[400]!, Colors.deepOrange[400]!] 
                                        : [Colors.purple[400]!, Colors.blue[400]!],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 16),
                      _buildDetailPanel(p),
                    ]
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(Map<String, dynamic> p) {
    String name = p['nombre']?.toString() ?? 'Producto';
    int totalVendido = (p['total_vendido'] as num).toInt();
    
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
          Icon(Icons.star, color: Colors.orange[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "El producto $name es un pilar de tu negocio con $totalVendido unidades vendidas. Asegúrate de nunca quebrar stock para no perder este flujo de ingresos.",
              style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
            ),
          )
        ],
      ),
    );
  }
}
