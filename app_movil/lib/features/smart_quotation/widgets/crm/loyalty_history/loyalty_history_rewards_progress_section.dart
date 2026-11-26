part of '../client_loyalty_history_modal.dart';

mixin _LoyaltyHistoryRewardsProgressSectionMixin on _ClientLoyaltyHistoryModalStateBase {
  @override
  Widget _buildClaimableRewardsAndProgressSection(bool isDark, Color textColor) {
    final claimableGoals = _claimableSummary?.claimableGoals ?? [];
    final nextGoal = _claimableSummary?.nextGoal ?? (_nextGoalData?['goal'] as RewardGoalModel?);
    final int missing = _claimableSummary?.puntosFaltantesParaSiguiente ??
        ((_nextGoalData?['puntos_faltantes'] ?? _nextGoalData?['missing'] as num?)?.toInt() ?? 0);
    final double progress = (_claimableSummary != null
        ? (_claimableSummary!.progresoSiguienteMeta)
        : (((_nextGoalData?['progreso'] ?? _nextGoalData?['progress'] as num?)?.toDouble() ?? 0.0))).clamp(0.0, 1.0);

    // Metas del catálogo siguientes
    final followingGoals = _goals
        .where((g) => g.activo && (nextGoal == null || g.puntosRequeridos > nextGoal.puntosRequeridos))
        .toList()
      ..sort((a, b) => a.puntosRequeridos.compareTo(b.puntosRequeridos));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SECCIÓN: PREMIOS DISPONIBLES PARA RECLAMAR
        if (claimableGoals.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF3A2E1E), const Color(0xFF241C15)]
                    : [Colors.amber.shade50, Colors.orange.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.shade600.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.card_giftcard_rounded, color: Colors.amber[800], size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Premios Listos (${claimableGoals.length})",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Alcanzados con sus ${_currentClient.puntosActuales} pts",
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Botón avisar al cliente por WhatsApp
                    TextButton.icon(
                      onPressed: () async {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final msg = LoyaltyWhatsAppService.buildAvailableRewardsMessage(
                          clientName: _currentClient.fullName,
                          businessName: auth.activeBusinessName,
                          puntosSaldo: _currentClient.puntosActuales,
                          nivelReputacion: _currentClient.tier.key,
                          claimableGoals: claimableGoals,
                          upcomingGoal: nextGoal,
                          missingPoints: missing,
                        );
                        if (!mounted) return;
                        await LoyaltyWhatsAppService.showEditableWhatsAppPreviewModal(
                          context: context,
                          title: "Avisar Premios Disponibles",
                          initialMessage: msg,
                          phone: _currentClient.phone,
                        );
                      },
                      icon: const Icon(Icons.chat_rounded, size: 13),
                      label: const Text("Avisar", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        backgroundColor: Colors.green.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...claimableGoals.map((g) {
                  String benefitDescription;
                  if (g.tipoBeneficio == 'DESCUENTO_MONTO') {
                    benefitDescription = "Descuento de ${AppCurrency.format(g.valorBeneficio)}";
                  } else if (g.tipoBeneficio == 'DESCUENTO_PORCENTAJE') {
                    benefitDescription = "${g.valorBeneficio.toInt()}% de Descuento";
                  } else if (g.tipoBeneficio == 'PRODUCTO_REGALO') {
                    benefitDescription = g.valorBeneficio > 0
                        ? "Producto de Regalo (${AppCurrency.format(g.valorBeneficio)})"
                        : "Producto de Regalo";
                  } else if (g.descripcion != null && g.descripcion!.isNotEmpty) {
                    benefitDescription = g.descripcion!;
                  } else {
                    benefitDescription = g.nombre;
                  }

                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF28221D) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.nombre,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${g.puntosRequeridos} pts • $benefitDescription",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.amber[300] : Colors.amber[800],
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => RewardReviewModal(
                                goal: g,
                                client: _currentClient,
                                onActionCompleted: () async {
                                  widget.onPointsChanged?.call();
                                  await _loadHistory();
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.touch_app_rounded, size: 13),
                          label: const Text("Reclamar", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // 2. RECOMPENSA PENDIENTE (REVISIÓN / CANJE PREVIO)
        if (_pendingRewards.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF332619) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.card_giftcard_rounded, color: Colors.amber[800], size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Premio pendiente de revisión",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                      Text(
                        _pendingRewards.first.tituloRecompensa,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => RewardReviewModal(
                        reward: _pendingRewards.first,
                        client: _currentClient,
                        onActionCompleted: () async {
                          widget.onPointsChanged?.call();
                          await _loadHistory();
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text("Revisar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 3. PRÓXIMA META SUPERIOR (ESPACIADO DEFENSIVO ANTI-COLISIÓN)
        if (nextGoal != null) ...[
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242432) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Próxima Meta: ${nextGoal.titulo}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10), // <-- Espaciador defensivo garantizado
                    Text(
                      missing <= 0 ? "¡Meta alcanzada!" : "Faltan $missing pts",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: missing <= 0 ? Colors.green : Colors.amber[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.green : Colors.amber.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_currentClient.puntosActuales} / ${nextGoal.puntosRequeridos} pts",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // 4. CATÁLOGO DE SIGUIENTES METAS PARA MOTIVAR EL AHORRO
        if (followingGoals.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Próximos Premios del Catálogo",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          ...followingGoals.take(3).map((g) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.nombre,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${g.puntosRequeridos} pts",
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // 5. ACCIÓN RÁPIDA: ENVIAR CARTILLA / GUÍA DE PUNTOS
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final rules = await _clientService.getLoyaltyRules(_currentClient.negocioId);
                final msg = LoyaltyWhatsAppService.buildLoyaltyGuideAndCatalogMessage(
                  businessName: auth.activeBusinessName,
                  rules: rules,
                  activeGoals: _goals.where((g) => g.activo).toList(),
                  clientName: _currentClient.fullName,
                  puntosActuales: _currentClient.puntosActuales,
                );
                if (!mounted) return;
                await LoyaltyWhatsAppService.showEditableWhatsAppPreviewModal(
                  context: context,
                  title: "Guía de Puntos y Premios",
                  initialMessage: msg,
                  phone: _currentClient.phone,
                  rules: rules,
                  activeGoals: _goals.where((g) => g.activo).toList(),
                  businessName: auth.activeBusinessName,
                  clientName: _currentClient.fullName,
                  puntosActuales: _currentClient.puntosActuales,
                );
              },
              icon: Icon(Icons.menu_book_rounded, size: 15, color: isDark ? Colors.amber[300] : Colors.amber[800]),
              label: Text(
                "Enviar Cartilla de Puntos al Cliente",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.amber[200] : Colors.amber[900],
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ],
    );
  }

}
