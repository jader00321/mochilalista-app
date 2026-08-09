import 'package:flutter/material.dart';
import '../../providers/analytics_provider.dart';
import 'glass_card.dart';

class TopClientsCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (data.topClients.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mejores Clientes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...data.topClients.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                    child: Icon(Icons.person, size: 16, color: Colors.indigo[400]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['nombre_completo'] ?? 'Desconocido', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(formatCurrency((c['total_comprado'] as num).toDouble()), style: TextStyle(color: Colors.green[600], fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
