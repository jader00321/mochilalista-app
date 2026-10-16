import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';
import 'package:app_movil/core/widgets/product_nomenclature_label.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class RestockAlertsCard extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;

  const RestockAlertsCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<RestockAlertsCard> createState() => _RestockAlertsCardState();
}

class _RestockAlertsCardState extends State<RestockAlertsCard> {
  int _selectedProductIndex = -1;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Text("Riesgo de Quiebre de Stock", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text("${widget.data.lowStockProducts.length}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (widget.data.lowStockProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: widget.isDark ? Colors.grey[700] : Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      "Tu inventario está en niveles óptimos.\nNingún producto requiere reabastecimiento urgente.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...widget.data.lowStockProducts.asMap().entries.map((e) {
            int index = e.key;
            var p = e.value;
            int actual = p['stock_actual'] ?? 0;
            int alerta = p['stock_alerta'] ?? 0;
            double pct = alerta > 0 ? (actual / alerta) : 0;
            if (pct > 1) pct = 1.0;
            
            bool isSelected = index == _selectedProductIndex;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedProductIndex = _selectedProductIndex == index ? -1 : index;
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
                        Expanded(
                          child: ProductNomenclatureLabel(
                            nombre: p['nombre']?.toString() ?? '',
                            marca: p['marca_nombre']?.toString(),
                            presentacion: p['presentacion_nombre']?.toString(),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("$actual / $alerta", style: TextStyle(fontWeight: FontWeight.bold, color: actual == 0 ? Colors.red : Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(actual == 0 ? Colors.red : Colors.orange),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 16),
                      _buildDetailPanel(p, actual, alerta),
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

  Widget _buildDetailPanel(Map<String, dynamic> p, int actual, int alerta) {
    String name = p['nombre']?.toString() ?? 'Producto';
    
    String insightText;
    if (actual == 0) {
      insightText = "⛔ $name se agotó completamente. Cada día sin stock es una venta perdida. Contacta a tu proveedor HOY.";
    } else if (actual <= 2) {
      insightText = "🔴 $name tiene solo $actual unidad(es). Nivel CRÍTICO. Al cruzar el umbral de seguridad ($alerta), el riesgo de quiebre es inminente. Actúa ya.";
    } else {
      insightText = "⚠️ $name: $actual de $alerta unidades de seguridad. Programa tu reabastecimiento antes de que baje a nivel crítico.";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(actual == 0 ? Icons.error_outline : Icons.speed, color: actual == 0 ? Colors.red : Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                actual == 0 ? "Stock Agotado" : "Alerta de Stock",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insightText,
            style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final invProv = Provider.of<InventoryProvider>(
                      context,
                      listen: false,
                    );
                    final analytics = Provider.of<AnalyticsProvider>(
                      context,
                      listen: false,
                    );
                    final presId = p['presentacion_id'] as int?;
                    final prodId = p['producto_id'] as int?;
                    if (presId == null || prodId == null) {
                      CustomSnackBar.show(
                        context,
                        message: "No se identificó la presentación",
                        isError: true,
                      );
                      return;
                    }
                    final fullProd = await invProv
                        .getFullProductWithFallback(prodId);
                    final targetPres = fullProd?.presentaciones
                        .where((pr) => pr.id == presId)
                        .firstOrNull;
                    if (targetPres != null && mounted) {
                      await StockUpdateModal.show(
                        context: context,
                        presentation: targetPres,
                        provider: invProv,
                        isDark: widget.isDark,
                      );
                      if (mounted) {
                        analytics.runStaggeredAnalysis();
                      }
                    }
                  },
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text(
                    "Ajustar Stock",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: actual == 0 ? Colors.red : Colors.orange,
                    side: BorderSide(
                      color: actual == 0 ? Colors.red : Colors.orange,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmartRestockScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text(
                    "Smart Restock",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actual == 0 ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
