part of '../client_loyalty_history_modal.dart';

mixin _LoyaltyHistoryMovementCardMixin on _ClientLoyaltyHistoryModalStateBase {
  @override
  Widget _buildMovementCard(LoyaltyLedgerModel item, bool isDark) {
    final isPositive = item.puntosDelta > 0;
    final isNeutral = item.puntosDelta == 0;
    final Color badgeColor = isNeutral
        ? Colors.grey
        : (isPositive ? Colors.green : Colors.redAccent);

    IconData icon;
    switch (item.tipoMovimiento) {
      case 'COMPRA_CONTADO':
      case 'COMPRA_CREDITO':
        icon = Icons.shopping_bag_rounded;
        break;
      case 'PAGO_PUNTUAL_BONO':
      case 'PAGO_PUNTUAL_RACHA':
        icon = Icons.local_fire_department_rounded;
        break;
      case 'LIQUIDACION_PUNTUAL_BONO':
        icon = Icons.verified_rounded;
        break;
      case 'COTIZACION_CONCRETADA_BONO':
        icon = Icons.request_quote_rounded;
        break;
      case 'CANJE_RECOMPENSA':
        icon = Icons.card_giftcard_rounded;
        break;
      case 'RESTAURACION_MIGRACION':
        icon = Icons.restore_rounded;
        break;
      case 'MORA_PENALIZACION':
        icon = Icons.warning_amber_rounded;
        break;
      case 'ANULACION_VENTA_REVERSA':
      case 'REVERSION_PAGO':
        icon = Icons.undo_rounded;
        break;
      default:
        icon = Icons.stars_rounded;
    }

    String formattedDate = item.fechaRegistro;
    try {
      final dt = DateTime.parse(item.fechaRegistro);
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282836) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.motivo,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.25,
                        ),
                        maxLines: 3,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${isPositive ? '+' : ''}${item.puntosDelta} pts",
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Saldo: ${item.saldoPuntosDespues} pts",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber[300] : Colors.amber[800],
                      ),
                    ),
                  ],
                ),
                if (item.scoreReputacionDelta != 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        item.scoreReputacionDelta > 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: item.scoreReputacionDelta > 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${item.scoreReputacionDelta > 0 ? '+' : ''}${item.scoreReputacionDelta} reputación",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.scoreReputacionDelta > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget _buildFilterChips(bool isDark) {
    final filters = [
      {'id': 'TODOS', 'label': 'Todos', 'icon': Icons.list_rounded},
      {'id': 'GANADOS', 'label': '+ Ganados', 'icon': Icons.add_circle_outline_rounded},
      {'id': 'CANJES_AJUSTES', 'label': '- Salidas', 'icon': Icons.remove_circle_outline_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = f['id'] as String),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.amber[700]!.withValues(alpha: 0.25) : Colors.amber.shade100)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.amber[700]!
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 13,
                      color: isSelected ? Colors.amber[800] : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? (isDark ? Colors.amber[300] : Colors.amber[900]) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget _buildMetricCol(String label, String value, IconData icon, Color iconColor, Color textC) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textC.withValues(alpha: 0.7)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textC),
        ),
      ],
    );
  }
}
