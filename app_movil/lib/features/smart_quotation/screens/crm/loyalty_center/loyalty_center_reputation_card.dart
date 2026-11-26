part of '../loyalty_center_screen.dart';

mixin _LoyaltyCenterReputationCardMixin on _LoyaltyCenterStateBase {
  @override
  Widget _buildReputationClientCard(
    ClientModel client,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final tier = client.tier;
    final almostAtGoal = _almostAtGoalMap[client.id];
    final clientPendingRewards = _pendingRewards.where((rw) => rw.clienteId == client.id).toList();
    final clientClaimable = _clientsClaimableMap[client.id];

    // Cálculo de Próxima Meta para micro-barra de progreso
    RewardGoalModel? nextGoal;
    final activeGoals = _goals.where((g) => g.activo).toList();
    if (activeGoals.isNotEmpty) {
      activeGoals.sort((a, b) => a.puntosRequeridos.compareTo(b.puntosRequeridos));
      for (final g in activeGoals) {
        if (g.puntosRequeridos > client.puntosActuales) {
          nextGoal = g;
          break;
        }
      }
      nextGoal ??= activeGoals.last;
    }
    final int nextGoalTarget = nextGoal?.puntosRequeridos ?? 1;
    final double nextGoalProgress = nextGoalTarget > 0
        ? (client.puntosActuales / nextGoalTarget).clamp(0.0, 1.0)
        : 1.0;
    final int nextGoalPercent = (nextGoalProgress * 100).toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Color(tier.colorHex).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(tier.colorHex).withValues(alpha: 0.15),
                    child: Text(
                      client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(tier.colorHex),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                client.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(tier.colorHex).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(tier.icon, size: 12, color: Color(tier.colorHex)),
                                  const SizedBox(width: 4),
                                  Text(
                                    tier.badgeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(tier.colorHex),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  (client.phone.isNotEmpty && client.phone != '000000000')
                                      ? client.phone
                                      : "Sin teléfono",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Score: ${client.scoreReputacion}/1000",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Indicador de Premios Disponibles, Premio en Revisión o Casi en la Meta
              if (clientClaimable != null && clientClaimable.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.amber[800]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${clientClaimable.length} premio(s) listo(s) (${client.puntosActuales} pts)",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => RewardReviewModal(
                              goal: clientClaimable.first,
                              client: client,
                              onActionCompleted: _loadData,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                "Reclamar",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (clientPendingRewards.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard_rounded, size: 15, color: Colors.amber[800]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Premio listo para revisar: ${clientPendingRewards.first.metaTitulo}",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => RewardReviewModal(
                              reward: clientPendingRewards.first,
                              client: client,
                              onActionCompleted: _loadData,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rate_review_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                "Revisar",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (nextGoal != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF232333) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.track_changes_rounded,
                            size: 13,
                            color: Colors.amber[800],
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              "Próxima meta: ${nextGoal.nombre}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (almostAtGoal != null) ...[
                            InkWell(
                              onTap: () {
                                final auth = Provider.of<AuthProvider>(context, listen: false);
                                LoyaltyWhatsAppService.sendAlmostAtGoalNotification(
                                  context: context,
                                  phone: client.phone,
                                  clientName: client.fullName.split(' ').first,
                                  businessName: auth.businessName,
                                  goal: almostAtGoal['goal'] as RewardGoalModel,
                                  puntosFaltantes: almostAtGoal['puntos_faltantes'] as int,
                                  puntosActuales: client.puntosActuales,
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.send_rounded, size: 9, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      "Impulso",
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              "${client.puntosActuales}/$nextGoalTarget pts ($nextGoalPercent%)",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: nextGoalProgress,
                                minHeight: 4,
                                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  nextGoalProgress >= 1.0 ? Colors.green : Colors.amber[700]!,
                                ),
                              ),
                            ),
                          ),
                          if (almostAtGoal != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              "${client.puntosActuales}/$nextGoalTarget pts ($nextGoalPercent%)",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
              const SizedBox(height: 8),

              // Fila de Indicadores: Puntos, Racha y Límite sugerido (Wrap anti-desbordamiento 360dp)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, size: 15, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        "${client.puntosActuales} pts",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Colors.amber[800],
                        ),
                      ),
                      if (client.rachaPagosPuntuales > 0) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.orange),
                            const SizedBox(width: 2),
                            Text(
                              "${client.rachaPagosPuntuales} a tiempo",
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Límite Sug.: ",
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      Text(
                        AppCurrency.format(tier.limiteCreditoSugerido),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: tier.limiteCreditoSugerido > 0 ? Colors.green[600] : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => ClientLoyaltyHistoryModal.show(
                      context,
                      client: client,
                      onPointsChanged: _loadData,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, size: 12, color: Colors.amber[800]),
                          const SizedBox(width: 3),
                          Text(
                            "Ver Puntos >",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber[300] : Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
