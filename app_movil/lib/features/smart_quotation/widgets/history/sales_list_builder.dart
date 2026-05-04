import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/sale_provider.dart';
import 'sale_action_bottom_sheet.dart'; 

class SalesListBuilder extends StatefulWidget {
  const SalesListBuilder({super.key});

  @override
  State<SalesListBuilder> createState() => _SalesListBuilderState();
}

class _SalesListBuilderState extends State<SalesListBuilder> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTopButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset >= 300 && !_showBackToTopButton) {
        setState(() => _showBackToTopButton = true);
      } else if (_scrollController.offset < 300 && _showBackToTopButton) {
        setState(() => _showBackToTopButton = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (provider.isLoading && provider.salesHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.salesHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No hay ventas en este filtro", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd/MM/yyyy • hh:mm a');

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => provider.loadFilteredHistory(reset: true),
          color: Colors.blue[800],
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: provider.salesHistory.length + (provider.hasMoreData ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == provider.salesHistory.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) => provider.loadFilteredHistory());
                return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
              }

              final sale = provider.salesHistory[index];
              final isCredit = sale.paymentStatus == 'pendiente';

              return InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => SaleActionBottomSheet(sale: sale),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: sale.isArchived ? (isDark ? Colors.white10 : Colors.grey[100]) : cardColor, 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Recibo #${sale.id.toString().padLeft(5, '0')}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14)),
                          Text(dateFormat.format(DateTime.parse(sale.saleDate)), style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16), // Separación extra
                      
                      // 🔥 SOLUCIÓN VISUAL: Usamos CrossAxisAlignment.start para evitar choques
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(backgroundColor: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], radius: 22, child: Icon(Icons.person, size: 24, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                          const SizedBox(width: 12),
                          
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                String title = sale.clientName ?? (sale.origenVenta == 'pos_rapido' ? "Caja Rápida" : "Lista Cotizada");
                                String subtitle = "";
                                
                                if (sale.clientId != null) {
                                  subtitle = "Cliente vinculado";
                                } else {
                                  subtitle = "Sin Cliente Registrado";
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title, 
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: sale.isArchived ? Colors.grey : textColor),
                                      maxLines: 2, 
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subtitle.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], fontStyle: FontStyle.italic)),
                                      )
                                  ],
                                );
                              },
                            ),
                          ),
                          
                          // Monto a la derecha
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              currency.format(sale.totalAmount),
                              style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900, 
                                color: sale.isArchived ? Colors.grey : (isDark ? Colors.blue[300] : Colors.blue[900]),
                                decoration: sale.isArchived ? TextDecoration.lineThrough : null 
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _Badge(text: isCredit ? "CRÉDITO" : "PAGADO", color: isCredit ? (isDark ? Colors.orange[400]! : Colors.orange) : (isDark ? Colors.green[400]! : Colors.green), icon: isCredit ? Icons.access_time : Icons.check_circle, isDark: isDark),
                          const SizedBox(width: 8),
                          _Badge(text: sale.deliveryStatus.toUpperCase().replaceAll("_", " "), color: sale.deliveryStatus.contains("entregado") ? (isDark ? Colors.blue[300]! : Colors.blue) : (isDark ? Colors.purple[300]! : Colors.purple), icon: Icons.local_shipping, isDark: isDark),
                          if (sale.isArchived) ...[
                            const SizedBox(width: 8),
                            _Badge(text: "ANULADA", color: isDark ? Colors.red[300]! : Colors.red, icon: Icons.auto_delete, isDark: isDark),
                          ]
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          bottom: _showBackToTopButton ? 20 : -80,
          right: 20,
          child: FloatingActionButton(
            heroTag: "btn_scroll_top",
            backgroundColor: isDark ? Colors.blue[700] : Colors.blue[800],
            foregroundColor: Colors.white,
            elevation: 4,
            mini: true, 
            tooltip: "Volver arriba",
            onPressed: _scrollToTop,
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _Badge({required this.text, required this.color, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}