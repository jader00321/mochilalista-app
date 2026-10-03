import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/scanner/providers/invoice_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/features/scanner/screens/invoice_detail_screen.dart';
import 'package:app_movil/features/scanner/screens/scan_screen.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InvoiceProvider>(context, listen: false).fetchInvoices(reset: true);
      // Pre-cargamos proveedores para mapear IDs a Nombres
      Provider.of<InventoryProvider>(context, listen: false).loadProviders();
    });

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) {
        if (_scrollCtrl.offset > 300) {
          if (!_showScrollToTop) setState(() => _showScrollToTop = true);
        } else {
          if (_showScrollToTop) setState(() => _showScrollToTop = false);
        }

        if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
          Provider.of<InvoiceProvider>(context, listen: false).fetchInvoices();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'completado': return isDark ? Colors.green[400]! : Colors.green[700]!;
      case 'revision': return isDark ? Colors.orange[400]! : Colors.orange[700]!;
      case 'procesando': return isDark ? Colors.blue[400]! : Colors.blue[700]!;
      default: return isDark ? Colors.grey[400]! : Colors.grey[700]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completado': return Icons.check_circle;
      case 'revision': return Icons.warning_rounded;
      case 'procesando': return Icons.hourglass_empty_rounded;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final invProv = Provider.of<InventoryProvider>(context);
    final invcProv = Provider.of<InvoiceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Historial de Facturas IA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.teal[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => invcProv.fetchInvoices(reset: true),
          )
        ],
      ),
      body: invcProv.isLoading && invcProv.invoices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : invcProv.invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("Aún no has procesado facturas", style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ScanScreen(mode: ScanMode.invoice),
                          ),
                        ),
                        icon: const Icon(Icons.document_scanner),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Escanear mi primera factura",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => invcProv.fetchInvoices(reset: true),
                  child: ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: invcProv.invoices.length + (invcProv.hasMoreData ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      if (i == invcProv.invoices.length) {
                        return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
                      }

                      final InvoiceModel invoice = invcProv.invoices[i];
                      final providerName = invProv.getProviderName(invoice.proveedorId);
                      final Color statusColor = _getStatusColor(invoice.estado, isDark);

                      return InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id)));
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF23232F) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ÍCONO Y ESTADO
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? statusColor.withValues(alpha: 0.15) : statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_getStatusIcon(invoice.estado), color: statusColor, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // INFO CENTRAL (Con maxLines: 2 para no cortar el texto)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          providerName.isNotEmpty ? providerName : "Proveedor Desconocido",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                                          maxLines: 2, overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat("dd MMM yyyy, hh:mm a").format(invoice.fechaCarga.toLocal()),
                                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 8),

                                  // MONTO
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Total",
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        invoice.montoTotalFactura != null ? "S/ ${invoice.montoTotalFactura!.toStringAsFixed(2)}" : "--",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.green[400] : Colors.green[700]),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              // ETIQUETAS INFERIORES
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      "Factura #${invoice.displayId}",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[100] : Colors.blueGrey[700]),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: isDark ? statusColor.withValues(alpha: 0.2) : statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      invoice.estado.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 0.5),
                                    ),
                                  ),
                                  if (invoice.cantidadItemsExtraidos != null && invoice.cantidadItemsExtraidos! > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.shopping_basket_outlined, size: 12, color: isDark ? Colors.purple[200] : Colors.purple[700]),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${invoice.cantidadItemsExtraidos} ítems",
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.purple[200] : Colors.purple[700]),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
          if (_showScrollToTop)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton(
                heroTag: "btn_history_up",
                mini: true,
                onPressed: () {
                  _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                },
                backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            ),
          if (invcProv.invoices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0), // Elevar el botón para que no esté tan pegado
              child: FloatingActionButton.extended(
                heroTag: "btn_history_scan",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.invoice)),
                ),
                backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                icon: const Icon(Icons.document_scanner, color: Colors.white),
                label: const Text(
                  "Escanear",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}