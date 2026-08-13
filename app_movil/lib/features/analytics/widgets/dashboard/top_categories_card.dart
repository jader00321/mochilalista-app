import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';

class TopCategoriesCard extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;

  const TopCategoriesCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<TopCategoriesCard> createState() => _TopCategoriesCardState();
}

class _TopCategoriesCardState extends State<TopCategoriesCard> {
  int _selectedCategoryIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.topCategories.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    if (widget.data.topCategories.isNotEmpty) {
      maxVal = (widget.data.topCategories[0]['total_vendido'] as num).toDouble();
    }

    return GlassCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Categorías Más Rentables", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...widget.data.topCategories.asMap().entries.map((e) {
            int index = e.key;
            var c = e.value;
            double total = (c['total_vendido'] as num).toDouble();
            double pct = maxVal > 0 ? (total / maxVal) : 0;
            bool isSelected = index == _selectedCategoryIndex;

            return GestureDetector(
              onTap: () {
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
                        Text("${total.toInt()} unid.", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                          valueColor: AlwaysStoppedAnimation<Color>(isSelected ? Colors.indigo : Colors.indigoAccent),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        );
                      },
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 12),
                      _buildDetailPanel(c),
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

  Widget _buildDetailPanel(Map<String, dynamic> c) {
    String name = c['nombre'];
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
          Icon(Icons.category, color: Colors.indigoAccent[200], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "La categoría $name es un motor clave para tu negocio. Considera ampliar el surtido en esta línea para aprovechar su alta rotación.",
              style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
            ),
          )
        ],
      ),
    );
  }
}
