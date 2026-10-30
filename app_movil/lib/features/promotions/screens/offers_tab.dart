import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

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
            
            final isAgotado = maxStock <= 0;
            
            // Map promo types to UI
            IconData promoIcon; Color promoColor; String promoLabel;
            switch(bundle.tipoPromocion) {
              case 'flash': promoIcon = Icons.bolt; promoColor = Colors.amber; promoLabel = "Flash"; break;
              case 'liquidez_costo': promoIcon = Icons.water_drop; promoColor = Colors.cyan; promoLabel = "Liquidez"; break;
              case '2x1': promoIcon = Icons.exposure_plus_2; promoColor = Colors.green; promoLabel = "2x1"; break;
              case 'volumen': promoIcon = Icons.shopping_cart; promoColor = Colors.deepPurple; promoLabel = "Mayoreo"; break;
              case 'escolar': promoIcon = Icons.school; promoColor = Colors.teal; promoLabel = "Escolar"; break;
              default: promoIcon = Icons.inventory_2; promoColor = Colors.blue; promoLabel = "Fusión"; break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    )
                ]
              ),
              child: Opacity(
                opacity: isAgotado ? 0.6 : 1.0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (isAgotado) {
                      CustomSnackBar.show(context, message: "Este paquete está agotado. Revísalo y actívalo cuando haya stock disponible.", isError: false);
                    }
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
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: promoColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(promoIcon, color: promoColor, size: 14),
                                      const SizedBox(width: 4),
                                      Text(promoLabel, style: TextStyle(color: promoColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(bundle.nombrePaquete, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.2), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
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
                                const SizedBox(width: 6),
                                Text(bundle.activo ? "ACTIVO" : "INACTIVO", style: TextStyle(color: bundle.activo ? color : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Precio de Venta", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(currency.format(bundle.precioVentaTotal), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Disponibles", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAgotado ? (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade50) : (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50),
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: Text(isAgotado ? "AGOTADO" : "$maxStock uds", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isAgotado ? (isDark ? Colors.red[300] : Colors.red[700]) : (isDark ? Colors.blue[300] : Colors.blue[700]))),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (bundle.fechaFin != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text("Vigente hasta ${DateFormat('dd/MM/yyyy').format(bundle.fechaFin!)}", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
                          ],
                        )
                      ],
                      if (!isAgotado && maxStock > 0 && maxStock <= 5) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxStock / 10.0,
                            minHeight: 4,
                            backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text("¡Quedan pocas unidades!", style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
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
                                 icon: Icon(Icons.share, color: isDark ? Colors.blue[400] : Colors.blue, size: 24),
                                 constraints: const BoxConstraints(),
                                 padding: const EdgeInsets.all(8),
                                 tooltip: "Compartir en WhatsApp",
                                 onPressed: () {
                                   final text = "🔥 *¡OFERTA EXCLUSIVA!* 🔥\n\n✨ *${bundle.nombrePaquete}*\n${bundle.descripcion ?? ''}\n\n💰 Llévalo por solo: *${currency.format(bundle.precioVentaTotal)}*\n\n¡Stock muy limitado! 🏃‍♂️💨\nEscríbenos para separar el tuyo antes que se agoten.";
                                   Clipboard.setData(ClipboardData(text: text));
                                   CustomSnackBar.show(context, message: "Copywriting de ventas copiado al portapapeles", isError: false);
                                 },
                               ),
                               const SizedBox(width: 8),
                               IconButton(
                                 icon: Icon(Icons.delete_outline, color: isDark ? Colors.red[400] : Colors.red, size: 24),
                                 constraints: const BoxConstraints(),
                                 padding: const EdgeInsets.all(8),
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
                       Navigator.push(context, MaterialPageRoute(builder: (_) => BundleBuilderScreen(initialTipoPromocion: 'paquete', initialMultipleItems: [p1, p2])));
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
        promoType = 'volumen';
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
                                _showSuggestionInsightModal(context, fullName, days, stock, cost, promoType, promoLabel, currency);
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

  void _showSuggestionInsightModal(BuildContext context, String fullName, int days, int stock, double cost, String promoType, String promoLabel, NumberFormat currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String strategyText = "";
    if (promoType == '2x1') {
      strategyText = "Tienes un volumen considerable de stock inmovilizado. Una oferta 2x1 es agresiva y perfecta para liberar espacio en estantes rápidamente y recuperar liquidez.";
    } else if (promoType == 'volumen') {
      strategyText = "Tienes algunas unidades que llevan tiempo sin moverse. Un descuento por volumen incentiva a los clientes a llevarse más de lo usual y acelera tu rotación de stock.";
    } else {
      strategyText = "Una promoción te ayudará a darle visibilidad a este producto y recuperar el capital invertido.";
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, minPadding: kMinDefensiveBottomClearance);
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Text("Insight Estratégico", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("¿Por qué sugerimos esto?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87, fontSize: 14, height: 1.5),
                      children: [
                        const TextSpan(text: "El producto "),
                        TextSpan(text: fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: " lleva "),
                        TextSpan(text: "$days días", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        const TextSpan(text: " sin registrar movimiento. Tienes "),
                        TextSpan(text: "$stock unidades", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: " en stock, lo que equivale a "),
                        TextSpan(text: currency.format(cost), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const TextSpan(text: " de capital inmovilizado que no está generando rentabilidad."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text("Estrategia: $promoLabel", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(strategyText, style: TextStyle(color: isDark ? Colors.blue[100] : Colors.blue[900], fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
