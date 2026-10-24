import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/discount_intelligent_modal.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

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

  Future<void> _openDirectDiscount(BuildContext context, Map<String, dynamic> productData) async {
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    final productId = productData['producto_id'];
    final presentationId = productData['id'];

    if (productId == null || presentationId == null) {
      CustomSnackBar.show(context, message: "Error: No se pudo identificar el producto.", isError: true);
      return;
    }

    final product = await inventoryProvider.getFullProductWithFallback(productId);
    if (product == null) {
      if (context.mounted) CustomSnackBar.show(context, message: "Error: El producto ya no existe.", isError: true);
      return;
    }

    final presentation = product.presentaciones.where((p) => p.id == presentationId).firstOrNull;
    if (presentation == null) {
      if (context.mounted) CustomSnackBar.show(context, message: "Error: La presentación ya no existe.", isError: true);
      return;
    }

    if (context.mounted) {
      await DiscountIntelligentModal.show(
        context: context,
        presentation: presentation,
        provider: inventoryProvider,
        isDark: widget.isDark,
      );
    }
  }

  Future<void> _openBundleBuilder(BuildContext context, Map<String, dynamic> productData) async {
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    final productId = productData['producto_id'];
    final presentationId = productData['id'];

    if (productId == null || presentationId == null) {
      CustomSnackBar.show(context, message: "Error: No se pudo identificar el producto.", isError: true);
      return;
    }

    final product = await inventoryProvider.getFullProductWithFallback(productId);
    if (product == null) {
      if (context.mounted) CustomSnackBar.show(context, message: "Error: El producto ya no existe.", isError: true);
      return;
    }

    final presentation = product.presentaciones.where((p) => p.id == presentationId).firstOrNull;
    if (presentation == null) {
      if (context.mounted) CustomSnackBar.show(context, message: "Error: La presentación ya no existe.", isError: true);
      return;
    }

    final wrapper = InventoryWrapper(product: product, presentation: presentation);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BundleBuilderScreen(
            initialItem: wrapper,
            initialTipoPromocion: 'liquidez_costo',
          ),
        ),
      );
    }
  }

  void _showOfferModal(BuildContext context, Map<String, dynamic> productData) {
    final isDark = widget.isDark;
    final String prodName = productData['producto_nombre'] ?? '';
    final String presName = productData['nombre_especifico'] ?? '';
    final String marcaName = productData['marca_nombre'] ?? '';
    final String fullName = presName.isNotEmpty ? "$prodName - $presName" : prodName;
    
    final int stock = productData['stock_actual'] ?? 0;
    final double cost = (productData['costo_unitario_calculado'] as num?)?.toDouble() ?? 0;
    final int diasEstancado = productData['dias_estancado'] ?? 0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Oferta',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text("Acción Rápida BI", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Elige cómo deseas liquidar y liberar el capital retenido de este producto:", style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (marcaName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text("Marca: $marcaName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Stock: $stock und.", style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text("Estancado: $diasEstancado días", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text("Capital retenido: ${AppCurrency.format(stock * cost)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.percent_rounded, size: 20),
                      label: const Text("Poner en Oferta Directa", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        _openDirectDiscount(context, productData);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, size: 20),
                      label: const Text("Crear Combo / Paquete", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        _openBundleBuilder(context, productData);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsToShow = _showAll ? widget.data.deadStockList : widget.data.deadStockList.take(5).toList();
    final analytics = Provider.of<AnalyticsProvider>(context);

    return GlassCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_empty, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Inventario Muerto", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: analytics.deadStockThresholdDays,
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    isDense: true,
                    dropdownColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: widget.isDark ? Colors.white : Colors.black
                    ),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text("> 15 días")),
                      DropdownMenuItem(value: 30, child: Text("> 30 días")),
                      DropdownMenuItem(value: 60, child: Text("> 60 días")),
                      DropdownMenuItem(value: 90, child: Text("> 90 días")),
                      DropdownMenuItem(value: 180, child: Text("> 180 días")),
                      DropdownMenuItem(value: 365, child: Text("> 1 año")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        analytics.setDeadStockThresholdDays(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "Tienes ${widget.data.deadStockCount} productos estancados • Capital inmovilizado: ${AppCurrency.format(widget.data.immobilizedCapital)}",
              style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Productos ordenados por inactividad, considerando su creación o última venta registrada.",
                    style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: Column(
              children: widget.data.deadStockList.isEmpty 
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: widget.isDark ? Colors.grey[700] : Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            "Excelente, no tienes inventario muerto para este rango de tiempo.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                ]
              : itemsToShow.map((p) {
                String prodName = p['producto_nombre'] ?? '';
                String presName = p['nombre_especifico'] ?? '';
                String marcaName = p['marca_nombre'] ?? '';
                String fullName = presName.isNotEmpty ? "$prodName - $presName" : prodName;
                int stock = p['stock_actual'] ?? 0;
                double cost = (p['costo_unitario_calculado'] as num?)?.toDouble() ?? 0;
                int diasEstancado = p['dias_estancado'] ?? 0;
                
                return InkWell(
                  onTap: () => _showOfferModal(context, p),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (marcaName.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(marcaName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ),
                                  Text("Hace $diasEstancado días", style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(AppCurrency.format(stock * cost), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("$stock und.", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.percent_rounded, size: 18, color: Colors.orange),
                          tooltip: "Poner en Oferta",
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () => _openDirectDiscount(context, p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.blueAccent),
                          tooltip: "Crear Combo",
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () => _openBundleBuilder(context, p),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                      ],
                    ),
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
        ],
      ),
    );
  }
}
