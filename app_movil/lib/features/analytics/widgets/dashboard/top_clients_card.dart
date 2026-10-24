import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';

class TopClientsCard extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double)? formatCurrency;

  const TopClientsCard({
    super.key,
    required this.data,
    required this.isDark,
    this.formatCurrency,
  });

  @override
  State<TopClientsCard> createState() => _TopClientsCardState();
}

class _TopClientsCardState extends State<TopClientsCard> {
  int _selectedClientIndex = -1;

  String _format(double amount) {
    if (widget.formatCurrency != null) return widget.formatCurrency!(amount);
    return AppCurrency.format(amount);
  }

  void _navigateToClientDetail(BuildContext context, Map<String, dynamic> c) {
    final client = ClientModel(
      id: c['id'] ?? 0,
      negocioId: c['negocio_id'] ?? 0,
      creadoPorUsuarioId: c['creado_por_usuario_id'] ?? 0,
      fullName: c['nombre_completo'] ?? 'Cliente',
      phone: c['telefono'] ?? '',
      registeredDate: DateTime.now().toIso8601String(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(client: client),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: widget.isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Mejores Clientes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Icon(Icons.touch_app, size: 16, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.data.topClients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: widget.isDark ? Colors.grey[700] : Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      "Aún no hay clientes frecuentes o datos de ventas suficientes para este cálculo.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...widget.data.topClients.asMap().entries.map((e) {
            int idx = e.key;
            var c = e.value;
            bool isSelected = idx == _selectedClientIndex;
            final double totalComprado = (c['total_comprado'] as num).toDouble();
            final int numCompras = c['num_compras'] ?? 1;
            
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
                padding: EdgeInsets.all(isSelected ? 10.0 : 4.0),
                margin: const EdgeInsets.only(bottom: 8.0),
                decoration: BoxDecoration(
                  color: isSelected ? (widget.isDark ? Colors.white10 : Colors.grey[100]) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: iconColor.withValues(alpha: 0.3)) : null,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: avatarColor,
                          child: Icon(avatarIcon, size: 18, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['nombre_completo'] ?? 'Desconocido', 
                                style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    _format(totalComprado), 
                                    style: TextStyle(color: Colors.green[600], fontSize: 12, fontWeight: FontWeight.bold)
                                  ),
                                  Text(
                                    " • $numCompras ${numCompras == 1 ? 'compra' : 'compras'}",
                                    style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          tooltip: "Ver detalles del cliente",
                          onPressed: () => _navigateToClientDetail(context, c),
                        ),
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
      insightText = "🏆 $name es tu cliente VIP con ${_format(totalComprado)} en $numCompras compras (Ticket prom: ${_format(ticketPromedio)}). ¡Premia su lealtad ofreciéndole promociones personalizadas!";
    } else if (index <= 2) {
      insightText = "$name ha invertido ${_format(totalComprado)} en $numCompras compras. Está a punto de convertirse en tu próximo VIP. Una promoción personalizada podría impulsar su recurrencia.";
    } else {
      insightText = "$name acumula ${_format(totalComprado)} en $numCompras compras. Cada cliente cuenta. Recuérdale tus ofertas vigentes para fidelizarlo.";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.person, size: 16),
              label: const Text("Ver perfil completo ↗", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _navigateToClientDetail(context, c),
            ),
          ),
        ],
      ),
    );
  }
}
