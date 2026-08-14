import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_full_stats_modal.dart';

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
        _buildFullStatsButton(context),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1A1A24) : const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
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

  Widget _buildFullStatsButton(BuildContext context) {
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF14141C) : Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => ClientFullStatsModal(client: client, isDark: isDark),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                ? [const Color(0xFF23232F), const Color(0xFF2A2A38)]
                : [Colors.blue.shade50, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_rounded, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 24),
              const SizedBox(width: 10),
              Text(
                "Ver Analítica Completa", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, 
                  color: isDark ? Colors.blue[300] : Colors.blue[900],
                  letterSpacing: 0.5
                )
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 14),
            ],
          ),
        ),
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

}
