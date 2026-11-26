part of '../loyalty_center_screen.dart';

mixin _LoyaltyCenterRewardCardsMixin on _LoyaltyCenterStateBase {
  @override
  Widget _buildPendingRewardCard(
    ClientRewardModel rw,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  rw.clienteNombre ?? 'Cliente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "POR REVISAR",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, size: 15, color: Colors.amber[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rw.metaTitulo,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.amber[300] : Colors.amber[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Puntos reservados: ${rw.puntosConsumidos} pts • Desbloqueado: ${rw.fechaDesbloqueo.split('T').first}",
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () async {
                final client = _allClients.firstWhere(
                  (c) => c.id == rw.clienteId,
                  orElse: () => ClientModel(
                    id: rw.clienteId,
                    negocioId: rw.negocioId,
                    creadoPorUsuarioId: 0,
                    fullName: rw.clienteNombre ?? 'Cliente',
                    phone: rw.clienteTelefono ?? '',
                    registeredDate: '',
                  ),
                );
                await RewardReviewModal.show(
                  context: context,
                  reward: rw,
                  client: client,
                  onActionCompleted: _loadData,
                );
              },
              icon: const Icon(Icons.rate_review_rounded, size: 16),
              label: const Text(
                "Revisar y Confirmar Premio",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildGoalCard(
    RewardGoalModel goal,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    IconData icon;
    Color iconColor;
    String benefitLabel;

    switch (goal.tipoBeneficio) {
      case 'DESCUENTO_MONTO':
        icon = Icons.attach_money_rounded;
        iconColor = Colors.green;
        benefitLabel = "Descuento de ${AppCurrency.format(goal.valorBeneficio)}";
        break;
      case 'DESCUENTO_PORCENTAJE':
        icon = Icons.percent_rounded;
        iconColor = Colors.blue;
        benefitLabel = "${goal.valorBeneficio.toStringAsFixed(0)}% de Descuento";
        break;
      case 'PRODUCTO_REGALO':
        icon = Icons.card_giftcard_rounded;
        iconColor = Colors.purple;
        benefitLabel = goal.valorBeneficio > 0
            ? "Producto de Regalo (${AppCurrency.format(goal.valorBeneficio)})"
            : "Producto de Regalo";
        break;
      default:
        icon = Icons.credit_score_rounded;
        iconColor = Colors.amber;
        benefitLabel = goal.valorBeneficio > 0
            ? "Crédito Extra de ${AppCurrency.format(goal.valorBeneficio)}"
            : "Crédito Preferencial";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
                        goal.titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${goal.puntosRequeridos} pts",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  benefitLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                if (goal.descripcion != null && goal.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    goal.descripcion!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: "Editar meta",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final res = await MetaRewardEditorModal.show(
                context,
                negocioId: auth.activeBusinessId ?? 1,
                goal: goal,
              );
              if (res != null) _loadData();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildPastRewardCard(
    ClientRewardModel rw,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final bool isDelivered = rw.estado == 'CANJEADA' || rw.estado == 'ENTREGADA';
    final bool isApproved = rw.estado == 'APROBADA_NOTIFICADA';

    final Color badgeColor = isDelivered
        ? Colors.green
        : (isApproved ? Colors.blue : Colors.grey);
    final IconData badgeIcon = isDelivered
        ? Icons.check_circle_rounded
        : (isApproved ? Icons.verified_rounded : Icons.cancel_outlined);

    final String displayStatus = isDelivered
        ? 'Premio Entregado'
        : (isApproved ? 'Listo para Canje' : 'Descartado');

    final String dateStr = rw.fechaCanje != null
        ? 'Entregado: ${rw.fechaCanje!.split('T').first}'
        : (rw.fechaAprobacion != null
            ? 'Aprobado: ${rw.fechaAprobacion!.split('T').first}'
            : rw.fechaDesbloqueo.split('T').first);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(badgeIcon, color: badgeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${rw.clienteNombre ?? 'Cliente'} • ${rw.metaTitulo}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "$displayStatus • $dateStr",
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              displayStatus,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
