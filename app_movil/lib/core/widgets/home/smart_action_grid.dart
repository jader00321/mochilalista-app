import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

// Providers
import 'package:app_movil/features/scanner/providers/scanner_provider.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart'; 

import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

// Pantallas
import 'package:app_movil/features/scanner/screens/scan_screen.dart'; 
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_tracking_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart'; 
import 'package:app_movil/features/scanner/screens/invoice_review_screen.dart'; 
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart'; 
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_history_screen.dart';
import 'package:app_movil/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/screens/db_inspector_screen.dart';

class SmartActionGrid extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const SmartActionGrid({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final inventoryScanner = Provider.of<ScannerProvider>(context);
    final quotationScanner = Provider.of<SmartQuotationProvider>(context);
    final authProv = Provider.of<AuthProvider>(context, listen: false); 
    final trackingProv = Provider.of<TrackingProvider>(context);
    final salesProv = Provider.of<SaleProvider>(context);
    final quickSaleProv = Provider.of<QuickSaleProvider>(context);
    final invProv = Provider.of<InventoryProvider>(context);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isClient = authProv.isCommunityClient;
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 3 : 2;
    final double aspectRatio = screenWidth > 600 ? 1.1 : (screenWidth > 400 ? 1.05 : 0.92);

    List<Widget> cards = [];

    if (isClient) {
      cards.add(
        _buildCard(
          context, index: 0, screenWidth: screenWidth,
          title: "Crear Pedido", subtitle: "Catálogo Virtual",
          icon: Icons.add_shopping_cart_rounded, color: isDark ? Colors.blue[400]! : Colors.blue[700]!,
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualQuotationScreen())),
        )
      );
    } else {
      int idx = 0;
      cards.addAll([
        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Venta Rápida", subtitle: "Caja al paso",
          icon: Icons.flash_on_rounded, color: isDark ? Colors.pink[300]! : Colors.pink[600]!,
          isDark: isDark,
          badge: quickSaleProv.cartItems.isNotEmpty ? _buildBadge("${quickSaleProv.cartItems.length}", Colors.red) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen())),
          onLongPress: () => _showQuickSalePowerShortcut(context, quickSaleProv, isDark),
        ),
        
        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Crear Producto", subtitle: "Inventario",
          icon: Icons.add_box_rounded, color: isDark ? Colors.green[400]! : Colors.green[600]!,
          isDark: isDark,
          badge: invProv.totalPresentationsCount > 0 
              ? _buildBadge("${invProv.totalPresentationsCount}", Colors.green[800]!) 
              : null,
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductCreateScreen()));
          },
        ),

        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Cotizar Lista", subtitle: "Escaneo con IA",
          icon: Icons.document_scanner_rounded, color: isDark ? Colors.orange[400]! : Colors.orange[700]!,
          isDark: isDark,
          badge: quotationScanner.items.isNotEmpty ? _buildBadge("${quotationScanner.items.length}", Colors.orange) : null,
          onTap: () {
            if (quotationScanner.items.isNotEmpty) {
              _showResumeDialog(
                context, title: "Lista Detectada", msg: "Tienes una lista escolar procesada sin guardar.",
                isDark: isDark,
                onNew: () {
                  quotationScanner.clearState();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation)));
                },
                onResume: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchingScreen(
                  extractedItems: quotationScanner.items, metadata: quotationScanner.metadata,
                ))),
              );
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation)));
            }
          },
        ),

        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Cotizar Manual", subtitle: "Detallada",
          icon: Icons.edit_note_rounded, color: isDark ? Colors.blue[400]! : Colors.blue[700]!,
          isDark: isDark,
          badge: quotationScanner.hasManualDraft ? _buildBadge("${quotationScanner.draftManualItems!.length}", Colors.blue) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualQuotationScreen())),
        ),

        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Cargar Factura", subtitle: "Reponer Stock",
          icon: Icons.receipt_long_rounded, color: isDark ? Colors.teal[400]! : Colors.teal[600]!,
          isDark: isDark,
          badge: inventoryScanner.aiRawData != null ? _buildBadge("${inventoryScanner.aiRawData!.items.length}", Colors.teal) : null,
          onTap: () {
            if (inventoryScanner.aiRawData != null) {
              _showResumeDialog(
                context, title: "Factura Pendiente", msg: "Tienes una factura en proceso de revisión o vinculación. ¿Deseas retomarla?",
                isDark: isDark,
                onNew: () {
                  inventoryScanner.clearData();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.invoice)));
                },
                onResume: () {
                  if (inventoryScanner.hasSavedProgress && inventoryScanner.stagingData != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceReviewScreen()));
                  }
                },
              );
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.invoice)));
            }
          },
        ),

        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Clientes", subtitle: "Deudas y Pagos",
          icon: Icons.people_alt_rounded, color: isDark ? Colors.purple[300]! : Colors.purple[600]!,
          isDark: isDark,
          badge: trackingProv.clientCount > 0 ? _buildBadge("${trackingProv.clientCount}", Colors.purple) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientTrackingScreen())),
        ),

        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Actividad", subtitle: salesProv.todaySalesCount > 0 ? "${salesProv.todaySalesCount} ventas hoy" : "Historial Ventas",
          icon: Icons.history_edu_rounded, color: isDark ? Colors.indigo[300]! : Colors.indigo[600]!,
          isDark: isDark,
          badge: salesProv.todaySalesCount > 0 ? _buildBadge("${salesProv.todaySalesCount}", Colors.indigo) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
        ),
        
        _buildCard(
          context, index: idx++, screenWidth: screenWidth,
          title: "Estadísticas", subtitle: "Finanzas y Top",
          icon: Icons.pie_chart_rounded, color: isDark ? Colors.amber[500]! : Colors.amber[700]!,
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen())),
        ),
      ]);

      if (kDebugMode) {
        cards.add(
          _buildCard(
            context, index: idx++, screenWidth: screenWidth,
            title: "DB Inspector", subtitle: "Depuración BD",
            icon: Icons.admin_panel_settings_rounded, color: isDark ? Colors.grey[400]! : Colors.grey[700]!,
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DbInspectorScreen())),
          )
        );
      }
    }

    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: aspectRatio, 
      children: cards,
    );
  }
  void _showResumeDialog(BuildContext context, {required String title, required String msg, required bool isDark, required VoidCallback onNew, required VoidCallback onResume}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)),
        content: Text(msg, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, height: 1.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); onNew(); },
            child: const Text("Iniciar Nueva", style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[600] : Colors.blue[800], 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0
            ),
            onPressed: () { Navigator.pop(ctx); onResume(); },
            child: const Text("Retomar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required int index,
    required double screenWidth,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    Widget? badge,
    String? infoTooltip,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Delay basado en el índice para efecto cascada (aprox 50ms por tarjeta)
        final double delay = index * 0.1;
        final double effectiveValue = ((value - delay) / (1 - delay)).clamp(0.0, 1.0);
        
        return Transform.translate(
          offset: Offset(0, 30 * (1 - effectiveValue)),
          child: Opacity(
            opacity: effectiveValue,
            child: child,
          ),
        );
      },
      child: Material(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        elevation: isDark ? 0 : 8,
        shadowColor: isDark ? Colors.transparent : color.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5) : BorderSide.none),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: isDark ? LinearGradient(colors: [color.withValues(alpha: 0.05), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: screenWidth > 400 ? 16 : 10, vertical: screenWidth > 400 ? 12 : 8), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(screenWidth > 400 ? 12 : 8),
                      decoration: BoxDecoration(color: isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: screenWidth > 400 ? 28 : 22),
                    ),
                    if (infoTooltip != null)
                      Tooltip(
                        message: infoTooltip,
                        triggerMode: TooltipTriggerMode.tap,
                        showDuration: const Duration(seconds: 4),
                        child: Icon(Icons.info_outline, color: isDark ? Colors.grey[500] : Colors.grey[400], size: 20),
                      )
                  ],
                ),
                const SizedBox(height: 12), 
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title, 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: screenWidth > 400 ? 16 : 14, color: isDark ? Colors.white : Colors.black87, height: 1.1, letterSpacing: -0.5),
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) badge,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: screenWidth > 400 ? 13 : 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _showQuickSalePowerShortcut(BuildContext context, QuickSaleProvider prov, bool isDark) {
    HapticFeedback.heavyImpact();
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        title: "Atajos de Venta Rápida",
        maxHeightFactor: 0.6,
        applyEffectiveBottomPadding: true,
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.pinkAccent),
              ),
              title: const Text("⚡ Nueva Venta Limpia", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Vacía la caja y abre una nueva venta en blanco"),
              onTap: () {
                Navigator.pop(ctx);
                prov.clearCart();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
              },
            ),
            const Divider(),
            if (prov.cartItems.isNotEmpty) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                ),
                title: Text("🧹 Vaciar Caja (${prov.cartItems.length} ítems)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                subtitle: const Text("Descarta todos los productos actualmente en cola"),
                onTap: () {
                  Navigator.pop(ctx);
                  prov.clearCart();
                  CustomSnackBar.show(context, message: "Caja vaciada correctamente");
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: Colors.blue),
              ),
              title: const Text("Continuar Venta Pendiente", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(prov.cartItems.isNotEmpty ? "${prov.cartItems.length} productos esperando cobro" : "Caja actualmente vacía"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}