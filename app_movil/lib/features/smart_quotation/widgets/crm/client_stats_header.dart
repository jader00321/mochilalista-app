import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

class ClientStatsHeader extends StatelessWidget {
  final ClientModel client;
  final bool isDark;
  final VoidCallback onWhatsAppTap;
  final VoidCallback onCallTap;
  final VoidCallback onGoToQuickSale;

  const ClientStatsHeader({
    super.key,
    required this.client,
    required this.isDark,
    required this.onWhatsAppTap,
    required this.onCallTap,
    required this.onGoToQuickSale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildProfileHeader(context),
        _buildStatsCarousel(context),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1A1A24) : const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 38, 
                backgroundColor: Colors.white24,
                child: Text(
                  client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?",
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.fullName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text(client.phone, style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          Align(
            alignment: Alignment.centerLeft,
            child: _buildTrustBadge(),
          ),
          
          if (client.etiquetas.isNotEmpty) ...[
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: client.etiquetas.map((tag) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                )).toList(),
              ),
            )
          ],
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onWhatsAppTap,
                icon: const Icon(Icons.chat, size: 24),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.all(12),
                ),
                tooltip: "WhatsApp",
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onCallTap,
                icon: const Icon(Icons.call, size: 24),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.blue[600] : Colors.blue[800],
                  padding: const EdgeInsets.all(12),
                ),
                tooltip: "Llamar",
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onGoToQuickSale,
                  icon: const Icon(Icons.point_of_sale, size: 22),
                  label: const Text("Ir a Caja", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    elevation: 0
                  ),
                ),
              ),
            ],
          ),
          
          _buildDelinquencyBanner(context),
        ],
      ),
    );
  }

  Widget _buildTrustBadge() {
    Color color;
    IconData icon;
    String label = client.nivelConfianza.toUpperCase();
    switch (client.nivelConfianza.toLowerCase()) {
      case 'excelente': color = Colors.greenAccent; icon = Icons.star; break;
      case 'regular': color = Colors.orangeAccent; icon = Icons.warning; break;
      case 'moroso': color = Colors.redAccent; icon = Icons.block; break;
      case 'bueno':
      default: color = Colors.blueAccent; icon = Icons.thumb_up; break;
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildDelinquencyBanner(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final debts = provider.currentClientDebts;
    if (debts.isEmpty || provider.isLoadingDebts) return const SizedBox.shrink();

    int overdueCount = 0;
    int maxDaysOverdue = 0;
    DateTime today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);

    for (var sale in debts) {
      for (var cuota in sale.installments) {
        if (cuota.status != 'pagado') {
          DateTime dueDate = DateTime.tryParse(cuota.dueDate) ?? DateTime.now();
          dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
          if (dueDate.isBefore(today)) {
            overdueCount++;
            int days = today.difference(dueDate).inDays;
            if (days > maxDaysOverdue) maxDaysOverdue = days;
          }
        }
      }
    }

    if (overdueCount == 0 && client.totalDebt > 0) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3))),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 12),
            const Expanded(child: Text("Cliente al día. Sin cuotas vencidas.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }

    if (overdueCount > 0) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("⚠️ $overdueCount cuota(s) vencida(s)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("Deuda más antigua: hace $maxDaysOverdue días", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildStatsCarousel(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    double totalComprado = client.lastSales.fold(0.0, (sum, sale) => sum + sale.total);
    double totalPagado = client.lastSales.fold(0.0, (sum, sale) => sum + sale.montoPagado);
    int numCompras = client.lastSales.length;
    
    double ticketPromedio = numCompras > 0 ? (totalComprado / numCompras) : 0;
    
    String ultimaCompra = "N/A";
    if (client.lastSales.isNotEmpty) {
      DateTime? dt = DateTime.tryParse(client.lastSales.first.date);
      if (dt != null) {
        int diff = DateTime.now().difference(dt).inDays;
        if (diff == 0) {
          ultimaCompra = "Hoy";
        } else if (diff == 1) {
          ultimaCompra = "Ayer";
        } else {
          ultimaCompra = "Hace $diff días";
        }
      }
    }

    final stats = [
      {"title": "Deuda Actual", "value": currency.format(client.totalDebt), "color": client.totalDebt > 0 ? (isDark ? Colors.red[400] : Colors.red) : (isDark ? Colors.green[400] : Colors.green), "icon": Icons.account_balance_wallet},
      {"title": "Por Entregar", "value": "${client.pendingDeliveryCount}", "color": isDark ? Colors.orange[400] : Colors.orange[800], "icon": Icons.local_shipping},
      {"title": "Saldo a Favor", "value": currency.format(client.saldoAFavor), "color": isDark ? Colors.amber[400] : Colors.amber[800], "icon": Icons.savings},
      {"title": "Ticket Promedio", "value": currency.format(ticketPromedio), "color": isDark ? Colors.teal[300] : Colors.teal[800], "icon": Icons.analytics},
      {"title": "Última Compra", "value": ultimaCompra, "color": isDark ? Colors.indigo[300] : Colors.indigo[800], "icon": Icons.event_available},
      {"title": "N° de Compras", "value": "$numCompras", "color": isDark ? Colors.purple[300] : Colors.purple, "icon": Icons.receipt_long}, 
      {"title": "Total Pagado", "value": currency.format(totalPagado), "color": isDark ? Colors.green[400] : Colors.green[700], "icon": Icons.check_circle},
      {"title": "Total Comprado", "value": currency.format(totalComprado), "color": isDark ? Colors.blue[300] : Colors.blue[800], "icon": Icons.shopping_bag},
    ];

    return Container(
      height: 135, 
      color: isDark ? const Color(0xFF14141C) : Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.only(top: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stats.length,
        itemBuilder: (ctx, i) {
          final stat = stats[i];
          final color = stat["color"] as Color;
          return Container(
            width: 175, 
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.3)),
              boxShadow: [if (!isDark) BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(stat["icon"] as IconData, size: 20, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(stat["title"] as String, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(stat["value"] as String, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
