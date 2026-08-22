import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';

class TopClientsCard extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const TopClientsCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  State<TopClientsCard> createState() => _TopClientsCardState();
}

class _TopClientsCardState extends State<TopClientsCard> {
  int _selectedClientIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.topClients.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      isDark: widget.isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mejores Clientes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...widget.data.topClients.asMap().entries.map((e) {
            int idx = e.key;
            var c = e.value;
            bool isSelected = idx == _selectedClientIndex;
            
            Color avatarColor = Colors.indigo.withValues(alpha: 0.1);
            IconData avatarIcon = Icons.person;
            Color iconColor = Colors.indigo[400]!;

            if (idx == 0) {
              avatarColor = Colors.amber.withValues(alpha: 0.2);
              avatarIcon = Icons.workspace_premium;
              iconColor = Colors.amber[700]!;
            } else if (idx == 1) {
              avatarColor = Colors.grey.withValues(alpha: 0.2);
              avatarIcon = Icons.workspace_premium;
              iconColor = Colors.grey[600]!;
            } else if (idx == 2) {
              avatarColor = Colors.brown.withValues(alpha: 0.2);
              avatarIcon = Icons.workspace_premium;
              iconColor = Colors.brown[400]!;
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedClientIndex = _selectedClientIndex == idx ? -1 : idx;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 8.0 : 0.0),
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: isSelected ? (widget.isDark ? Colors.white10 : Colors.grey[100]) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: avatarColor,
                          child: Icon(avatarIcon, size: 16, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['nombre_completo'] ?? 'Desconocido', style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(widget.formatCurrency((c['total_comprado'] as num).toDouble()), style: TextStyle(color: Colors.green[600], fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 12),
                      _buildDetailPanel(c, idx),
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

  Widget _buildDetailPanel(Map<String, dynamic> c, int index) {
    String name = c['nombre_completo'] ?? 'Cliente';
    double totalComprado = (c['total_comprado'] as num).toDouble();
    int numCompras = c['num_compras'] ?? 1;
    double ticketPromedio = totalComprado / numCompras;

    String insightText;
    if (index == 0) {
      insightText = "🏆 $name es tu cliente VIP con ${widget.formatCurrency(totalComprado)} en $numCompras compras (Ticket prom: ${widget.formatCurrency(ticketPromedio)}). ¡Envíale una oferta exclusiva por WhatsApp usando el Cotizador Manual para premiar su lealtad!";
    } else if (index <= 2) {
      insightText = "$name ha invertido ${widget.formatCurrency(totalComprado)} en $numCompras compras. Está a punto de convertirse en tu próximo VIP. Una promoción personalizada podría impulsar su recurrencia.";
    } else {
      insightText = "$name acumula ${widget.formatCurrency(totalComprado)} en $numCompras compras. Cada cliente cuenta. Recuérdale tus ofertas vigentes para fidelizarlo.";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(index == 0 ? Icons.workspace_premium : Icons.auto_awesome, color: Colors.amber[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insightText,
              style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
            ),
          )
        ],
      ),
    );
  }
}
