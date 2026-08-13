import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';

class DeadStockCard extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;

  const DeadStockCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<DeadStockCard> createState() => _DeadStockCardState();
}

class _DeadStockCardState extends State<DeadStockCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.data.deadStockList.isEmpty) return const SizedBox.shrink();
    
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final itemsToShow = _showAll ? widget.data.deadStockList : widget.data.deadStockList.take(5).toList();

    return GlassCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_empty, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Inventario Muerto (> 90 días)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("Tienes ${widget.data.deadStockCount} productos estancados.\nCapital Inmovilizado: ${currency.format(widget.data.immobilizedCapital)}", 
                         style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: Column(
              children: itemsToShow.map((p) {
                String prodName = p['producto_nombre'] ?? '';
                String presName = p['nombre_especifico'] ?? '';
                String fullName = presName.isNotEmpty ? "$prodName - $presName" : prodName;
                int stock = p['stock_actual'] ?? 0;
                double cost = (p['costo_unitario_calculado'] as num?)?.toDouble() ?? 0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text("$stock und.", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 8),
                      Text(currency.format(stock * cost), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (widget.data.deadStockList.length > 5)
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                child: Text(_showAll ? "Ver menos" : "Ver ${widget.data.deadStockList.length - 5} más..."),
              )
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BundleBuilderScreen(
                      initialTipoPromocion: 'PAQUETE_LIQUIDACION',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.local_offer, size: 16),
              label: const Text("Crear Promoción de Liquidación"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          )
        ],
      ),
    );
  }
}
