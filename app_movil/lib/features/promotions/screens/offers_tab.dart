import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class OffersTab extends StatefulWidget {
  const OffersTab({super.key});

  @override
  State<OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<OffersTab> {
  bool _isInsightsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<PromotionProvider>(context);
    final invProv = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final now = DateTime.now();

    final slowMovers = invProv.items.where((p) {
      if (p.presentation.stockActual < 5) return false;
      if (p.product.fechaActualizacion == null) return false;
      final lastUpdate = DateTime.tryParse(p.product.fechaActualizacion!);
      if (lastUpdate == null) return false;
      final daysSinceUpdate = now.difference(lastUpdate).inDays;
      return daysSinceUpdate > 20;
    }).take(4).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.activeBusinessId != null) {
          await prov.loadPromotions(auth.activeBusinessId!);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // INSIGHTS SECTION (Algoritmo sugestivo)
          InkWell(
            onTap: () {
              setState(() {
                _isInsightsExpanded = !_isInsightsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text("Insights & Sugerencias", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  if (slowMovers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${slowMovers.length + (slowMovers.length >= 2 ? 1 : 0)}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(_isInsightsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildInsights(context, slowMovers, prov, isDark, currency, now),
            ),
            crossFadeState: _isInsightsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          const SizedBox(height: 24),
          
          // BUNDLES SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.blue),
                  SizedBox(width: 8),
                  Text("Paquetes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Nuevo"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BundleBuilderScreen()));
                },
              )
            ],
          ),
          const SizedBox(height: 12),
          if (prov.bundles.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!)
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.discount_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text("No tienes paquetes activos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("¡Crea una promoción combinando productos para vender más rápido!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ],
                )
              ),
            ),
          
          ...prov.bundles.map((bundle) {
            final maxStock = prov.calculateBundleMaxStock(bundle.id);
            final cost = bundle.costoTotalCalculado ?? 0;
            final margin = bundle.precioVentaTotal > 0 ? (bundle.precioVentaTotal - cost) / bundle.precioVentaTotal : 0;
            final color = margin < 0.1 ? Colors.red : (margin < 0.25 ? Colors.orange : Colors.green);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => BundleBuilderScreen(bundleToEdit: bundle)));
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(bundle.nombrePaquete, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: bundle.activo ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: bundle.activo ? color.withValues(alpha: 0.5) : Colors.grey)
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: bundle.activo ? color : Colors.grey, size: 8),
                                const SizedBox(width: 4),
                                Text(bundle.activo ? "Activo" : "Inactivo", style: TextStyle(color: bundle.activo ? color : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                      if (bundle.descripcion != null && bundle.descripcion!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(bundle.descripcion!, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Precio Venta", style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(currency.format(bundle.precioVentaTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Disponibles", style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text("$maxStock uds", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Row(
                             children: [
                               Icon(margin < 0.1 ? Icons.warning_amber : Icons.trending_up, size: 16, color: color),
                               const SizedBox(width: 4),
                               Text("Margen: ${(margin * 100).toStringAsFixed(1)}%", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                             ],
                           ),
                           Row(
                             children: [
                               IconButton(
                                 icon: const Icon(Icons.share, color: Colors.blue, size: 20),
                                 constraints: const BoxConstraints(),
                                 padding: EdgeInsets.zero,
                                 tooltip: "Compartir en WhatsApp",
                                 onPressed: () {
                                   final text = "🔥 *¡OFERTA EXCLUSIVA!* 🔥\n\n✨ *${bundle.nombrePaquete}*\n${bundle.descripcion ?? ''}\n\n💰 Llévalo por solo: *${currency.format(bundle.precioVentaTotal)}*\n\n¡Stock muy limitado! 🏃‍♂️💨\nEscríbenos para separar el tuyo antes que se agoten.";
                                   Clipboard.setData(ClipboardData(text: text));
                                   CustomSnackBar.show(context, message: "Copywriting de ventas copiado al portapapeles", isError: false);
                                 },
                               ),
                               const SizedBox(width: 16),
                               IconButton(
                                 icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                 constraints: const BoxConstraints(),
                                 padding: EdgeInsets.zero,
                                 onPressed: () async {
                                   final confirm = await showDialog<bool>(
                                     context: context,
                                     builder: (ctx) => AlertDialog(
                                       title: const Text("Eliminar Paquete"),
                                       content: const Text("¿Estás seguro de eliminar este paquete?"),
                                       actions: [
                                         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                                         TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
                                       ],
                                     )
                                   );
                                   if (confirm == true && context.mounted) {
                                     try {
                                       await prov.deleteBundle(bundle.id);
                                       if (context.mounted) CustomSnackBar.show(context, message: "Paquete eliminado", isError: false);
                                     } catch(e) {
                                       if (context.mounted) CustomSnackBar.show(context, message: "Error al eliminar: $e", isError: true);
                                     }
                                   }
                                 },
                               )
                             ],
                           )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 60),
        ],
      )
    );
  }

  Widget _buildInsights(BuildContext context, List<dynamic> slowMovers, PromotionProvider prov, bool isDark, NumberFormat currency, DateTime now) {
    if (slowMovers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("¡Rotación Saludable!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text("No detectamos productos atascados en este momento.", style: TextStyle(fontSize: 12)),
                ],
              ),
            )
          ],
        )
      );
    }

    List<Widget> insightWidgets = [];

    // Fusión de productos si hay 2 o más
    if (slowMovers.length >= 2) {
      final p1 = slowMovers[0];
      final p2 = slowMovers[1];
      insightWidgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.purple.withValues(alpha: 0.1), Colors.deepPurple.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Paquete Fusión Sugerido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
                          Text("Combina productos de baja rotación", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text("Crea un 'Paquete Fusión' combinando:\n• ${p1.product.nombre}\n• ${p2.product.nombre}", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Crear Paquete"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => BundleBuilderScreen(initialTipoPromocion: 'paquete_fusion', initialMultipleItems: [p1, p2])));
                    },
                  ),
                )
              ],
            ),
          ),
        )
      );
    }

    // Sugerencias individuales
    insightWidgets.addAll(slowMovers.map((p) {
      final days = now.difference(DateTime.parse(p.product.fechaActualizacion!)).inDays;
      final stock = p.presentation.stockActual;
      final cost = (p.presentation.costoUnitarioCalculado ?? 0) * stock;
      
      final activeBundles = prov.getBundlesForPresentation(p.presentation.id);
      final hasActiveOffer = activeBundles.isNotEmpty;
      
      String promoType = 'liquidez_costo';
      String promoLabel = 'Promoción Relámpago';
      IconData promoIcon = Icons.flash_on;
      
      if (stock > 20 && days > 30) {
        promoType = '2x1';
        promoLabel = 'Crear Oferta 2x1';
        promoIcon = Icons.exposure_plus_2;
      } else if (stock >= 5 && stock <= 10 && days > 20) {
        promoType = 'precio_mayoreo';
        promoLabel = 'Descuento por Volumen';
        promoIcon = Icons.inventory_2;
      }

      final String fullName = "${p.product.nombre} ${p.presentation.nombreEspecifico ?? ''}".trim();

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: hasActiveOffer 
            ? (isDark ? Colors.blue[900]!.withValues(alpha: 0.2) : Colors.blue[50])
            : (isDark ? const Color(0xFF2C2519) : Colors.orange[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasActiveOffer 
            ? Colors.blue.withValues(alpha: 0.4) 
            : Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasActiveOffer 
                        ? Colors.blue.withValues(alpha: 0.2) 
                        : Colors.orange.withValues(alpha: 0.2), 
                      shape: BoxShape.circle
                    ),
                    child: Icon(hasActiveOffer ? Icons.local_offer : Icons.trending_down, 
                      color: hasActiveOffer ? Colors.blue : Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            InkWell(
                              onTap: () {
                                CustomSnackBar.show(context, message: "El inventario estancado inmoviliza tu capital de trabajo.", isError: false);
                              },
                              child: Icon(Icons.info_outline, size: 20, color: hasActiveOffer ? Colors.blue : Colors.orange),
                            )
                          ],
                        ),
                        if (p.product.marcaNombre != null && p.product.marcaNombre != "null" && p.product.marcaNombre!.isNotEmpty)
                          Text(p.product.marcaNombre!, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)),
                        const SizedBox(height: 4),
                        if (hasActiveOffer)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: const Text("Ya tiene oferta activa", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        Text("Lleva $days días sin rotar y tienes $stock unidades inmovilizando ${currency.format(cost)}.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: Icon(promoIcon, size: 16),
                  label: Text(hasActiveOffer ? "Crear otra promoción" : promoLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasActiveOffer ? Colors.blue : Colors.orange,
                    side: BorderSide(color: hasActiveOffer ? Colors.blue : Colors.orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  ),
                  onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => BundleBuilderScreen(initialItem: p, initialTipoPromocion: promoType)));
                  },
                ),
              )
            ],
          ),
        ),
      );
    }).toList());

    return Column(children: insightWidgets);
  }
}
