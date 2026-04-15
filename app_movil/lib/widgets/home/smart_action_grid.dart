import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../providers/scanner_provider.dart'; 
import '../../providers/auth_provider.dart'; 
import '../../features/smart_quotation/providers/smart_quotation_provider.dart'; 

// Pantallas
import '../../screens/scan_screen.dart'; 
import '../../features/smart_quotation/screens/manual_quotation_screen.dart';
import '../../features/smart_quotation/screens/crm/client_tracking_screen.dart';
import '../../features/smart_quotation/screens/matching_screen.dart'; 
import '../../screens/scanner/invoice_review_screen.dart'; 
import '../../screens/scanner/invoice_staging_screen.dart'; 
import '../../features/smart_quotation/screens/quick_sale_screen.dart';
import '../../features/smart_quotation/screens/sales_history_screen.dart';

class SmartActionGrid extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const SmartActionGrid({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final inventoryScanner = Provider.of<ScannerProvider>(context);
    final quotationScanner = Provider.of<SmartQuotationProvider>(context);
    final authProv = Provider.of<AuthProvider>(context, listen: false); 
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isClient = authProv.isCommunityClient;

    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.05, 
      children: [
        // 1. COTIZAR LISTA MANUAL / NUEVO PEDIDO
        _buildCard(
          context,
          title: isClient ? "Crear Pedido" : "Cotizar Manual",
          subtitle: isClient ? "Catálogo Virtual" : "Detallada",
          icon: isClient ? Icons.add_shopping_cart : Icons.edit_note_rounded,
          color: isDark ? Colors.blue[400]! : Colors.blue,
          isDark: isDark,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualQuotationScreen()));
          },
        ),

        // 🔥 OCULTAMOS ESTAS AL CLIENTE, PERO SE MUESTRAN AL DUEÑO/TRABAJADOR
        if (!isClient) ...[
          // 2. VENTA RÁPIDA
          _buildCard(
            context,
            title: "Venta Rápida",
            subtitle: "Caja al paso",
            icon: Icons.flash_on_rounded, 
            color: isDark ? Colors.pink[300]! : Colors.pinkAccent,
            isDark: isDark,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
            },
          ),

          // 3. CARGAR FACTURA
          _buildCard(
            context,
            title: "Cargar Factura",
            subtitle: "Reponer Stock",
            icon: Icons.receipt_long_rounded,
            color: isDark ? Colors.teal[400]! : Colors.teal, 
            isDark: isDark,
            onTap: () {
              if (inventoryScanner.aiRawData != null) {
                _showResumeDialog(
                  context, 
                  title: "Factura Pendiente",
                  msg: "Tienes una factura en proceso de revisión o vinculación. ¿Deseas retomarla?",
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
                  }
                );
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.invoice)));
              }
            },
          ),

          // 4. COTIZAR LISTA CON IA 
          _buildCard(
            context,
            title: "Cotizar Lista",
            subtitle: "Escaneo con IA",
            icon: Icons.document_scanner_rounded,
            color: isDark ? Colors.orange[400]! : Colors.orange,
            isDark: isDark,
            onTap: () {
              if (quotationScanner.items.isNotEmpty) {
                _showResumeDialog(
                  context, 
                  title: "Lista Detectada",
                  msg: "Tienes una lista escolar procesada sin guardar.",
                  isDark: isDark,
                  onNew: () {
                    quotationScanner.clearState(); 
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation))); 
                  },
                  onResume: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MatchingScreen(
                      extractedItems: quotationScanner.items,
                      metadata: quotationScanner.metadata,
                      token: authProv.token ?? "", 
                    )));
                  }
                );
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation)));
              }
            },
          ),

          // 5. CLIENTES CRM
          _buildCard(
            context,
            title: "Clientes",
            subtitle: "Deudas y Pagos",
            icon: Icons.people_alt_rounded,
            color: isDark ? Colors.purple[300]! : Colors.purple,
            isDark: isDark,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientTrackingScreen()));
            },
          ),

          // 6. ACTIVIDAD
          _buildCard(
            context,
            title: "Actividad",
            subtitle: "Historial Ventas",
            icon: Icons.history_edu_rounded,
            color: isDark ? Colors.indigo[300]! : Colors.indigo,
            isDark: isDark,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen()));
            },
          ),
        ]
      ],
    );
  }

  void _showResumeDialog(BuildContext context, {required String title, required String msg, required bool isDark, required VoidCallback onNew, required VoidCallback onResume}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        content: Text(msg, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); onNew(); },
            child: const Text("Iniciar Nueva", style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[600] : Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { Navigator.pop(ctx); onResume(); },
            child: const Text("Retomar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required bool isDark, required VoidCallback onTap}) {
    return Material(
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      elevation: isDark ? 0 : 4,
      shadowColor: isDark ? Colors.transparent : color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: isDark ? BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5) : BorderSide.none),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withOpacity(0.15),
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12), 
              Text(
                title, 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87, height: 1.1),
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle, 
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            ],
          ),
        ),
      ),
    );
  }
}