part of '../loyalty_center_screen.dart';

mixin _LoyaltyCenterRewardsTabMixin on _LoyaltyCenterStateBase {
  // =========================================================================
  // TAB 2: RECOMPENSAS Y METAS
  // =========================================================================
  @override
  Widget _buildRewardsAndGoalsTab(bool isDark, Color cardColor, Color textColor) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BARRA DE ACCIONES EJECUTIVAS: REGLAS Y CARTILLA ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: _tourKeys.rulesConfigKey,
                    onPressed: _openRulesConfig,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text("Reglas de Puntos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openLoyaltyGuidePreview,
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text("Cartilla WhatsApp", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[200] : Colors.blueGrey[800],
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // --- SECCIÓN 1: PREMIOS DISPONIBLES PARA RECLAMAR ---
            if (_clientsWithClaimableRewards.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Premios Disponibles para Reclamar",
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
                      color: Colors.amber[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${_clientsWithClaimableRewards.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._clientsWithClaimableRewards.map((item) => _buildClaimableClientCard(item, isDark, cardColor, textColor)),
              const SizedBox(height: 20),
            ],

            // --- SECCIÓN 2: RECOMPENSAS PENDIENTES DE REVISIÓN (Solo si existen) ---
            if (_pendingRewards.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Premios Desbloqueados por Revisar",
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
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${_pendingRewards.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._pendingRewards.map((rw) => _buildPendingRewardCard(rw, isDark, cardColor, textColor)),
              const SizedBox(height: 20),
            ],

            if (_pendingRewards.isEmpty && _clientsWithClaimableRewards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2A1E) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "¡Todo al día! No hay recompensas pendientes ni premios listos para reclamar.",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.green[200] : Colors.green[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 22),

            // --- SECCIÓN 2: CATÁLOGO DE METAS DEL NEGOCIO ---
            Row(
              key: _tourKeys.rewardsCatalogKey,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Catálogo de Metas",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final res = await MetaRewardEditorModal.show(
                      context,
                      negocioId: auth.activeBusinessId ?? 1,
                    );
                    if (res != null) _loadData();
                  },
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text("Nueva Meta", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_goals.isEmpty)
              Text(
                "No hay metas configuradas. Toca '+ Nueva Meta' para agregar una.",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
              )
            else
              ..._goals.map((g) => _buildGoalCard(g, isDark, cardColor, textColor)),

            const SizedBox(height: 22),

            // --- SECCIÓN 3: HISTORIAL DE CANJES ---
            if (_pastRewards.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.history_rounded, color: isDark ? Colors.grey[400] : Colors.grey[700], size: 19),
                  const SizedBox(width: 8),
                  Text(
                    "Historial Reciente de Premios",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._pastRewards.map((rw) => _buildPastRewardCard(rw, isDark, cardColor, textColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClaimableClientCard(
    Map<String, dynamic> item,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final client = item['client'] as ClientModel;
    final goals = (item['claimable_goals'] as List).cast<RewardGoalModel>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(client.tier.colorHex).withValues(alpha: 0.2),
                child: Text(
                  client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(client.tier.colorHex),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${client.puntosActuales} pts disponibles",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.amber[300] : Colors.amber[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chat_rounded, size: 18),
                color: Colors.green[700],
                tooltip: "Avisar premios por WhatsApp",
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final msg = LoyaltyWhatsAppService.buildAvailableRewardsMessage(
                    clientName: client.fullName,
                    businessName: auth.activeBusinessName,
                    puntosSaldo: client.puntosActuales,
                    nivelReputacion: client.tier.key,
                    claimableGoals: goals,
                  );
                  if (!context.mounted) return;
                  await LoyaltyWhatsAppService.showEditableWhatsAppPreviewModal(
                    context: context,
                    title: "Avisar Premios Disponibles",
                    initialMessage: msg,
                    phone: client.phone,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: goals.map((g) {
              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF28221D) : Colors.amber.shade50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, size: 14, color: Colors.amber[800]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "${g.nombre} (${g.puntosRequeridos} pts)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                            client: client,
                            onActionCompleted: _loadData,
                          ),
                        );
                      },
                      icon: const Icon(Icons.touch_app_rounded, size: 12),
                      label: const Text(
                        "Reclamar",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

}
