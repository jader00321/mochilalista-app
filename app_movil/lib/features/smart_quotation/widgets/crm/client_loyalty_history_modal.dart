import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/loyalty_toast_feedback.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/reward_review_modal.dart';

part 'loyalty_history/loyalty_history_manual_bonus_dialog.dart';
part 'loyalty_history/loyalty_history_movement_card.dart';
part 'loyalty_history/loyalty_history_rewards_progress_section.dart';

class ClientLoyaltyHistoryModal extends StatefulWidget {
  final ClientModel client;
  final VoidCallback? onPointsChanged;
  final bool autoLoadHistory;
  final List<LoyaltyLedgerModel>? initialMovements;
  final Map<String, dynamic>? initialNextGoalData;
  final List<ClientRewardModel>? initialPendingRewards;
  final int initialTabIndex;

  const ClientLoyaltyHistoryModal({
    super.key,
    required this.client,
    this.onPointsChanged,
    this.autoLoadHistory = true,
    this.initialMovements,
    this.initialNextGoalData,
    this.initialPendingRewards,
    this.initialTabIndex = 0,
  });

  static Future<void> show(BuildContext context, {
    required ClientModel client,
    VoidCallback? onPointsChanged,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClientLoyaltyHistoryModal(
        client: client,
        onPointsChanged: onPointsChanged,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<ClientLoyaltyHistoryModal> createState() => _ClientLoyaltyHistoryModalState();
}

abstract class _ClientLoyaltyHistoryModalStateBase extends State<ClientLoyaltyHistoryModal> {
  final _clientService = ClientService();
  bool _isLoading = true;
  List<LoyaltyLedgerModel> _movements = [];
  List<RewardGoalModel> _goals = [];
  Map<String, dynamic>? _nextGoalData;
  List<ClientRewardModel> _pendingRewards = [];
  ClientClaimableRewardsSummary? _claimableSummary;
  String _selectedFilter = 'TODOS'; // 'TODOS', 'GANADOS', 'CANJES_AJUSTES'
  late ClientModel _currentClient;

  @override
  void initState() {
    super.initState();
    _currentClient = widget.client;
    if (widget.initialMovements != null) {
      _movements = List.from(widget.initialMovements!);
      _nextGoalData = widget.initialNextGoalData;
      _pendingRewards = widget.initialPendingRewards ?? [];
      _isLoading = false;
    }
    if (widget.autoLoadHistory && widget.initialMovements == null) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _clientService.getClientById(_currentClient.id);
      if (updated != null && mounted) {
        _currentClient = updated;
      }
      final list = await _clientService.getClientLoyaltyLedger(_currentClient.id);
      final goals = await _clientService.getRewardGoals(_currentClient.negocioId, activeOnly: true);
      final nextGoal = await _clientService.getNextGoalForClient(_currentClient.id, _currentClient.negocioId);
      final pending = await _clientService.getClientRewards(_currentClient.id, status: 'PENDIENTE_REVISION');
      final claimable = await _clientService.getClientClaimableRewardsSummary(_currentClient.id, _currentClient.negocioId);

      if (mounted) {
        setState(() {
          _movements = list;
          _goals = goals;
          _nextGoalData = nextGoal;
          _pendingRewards = pending;
          _claimableSummary = claimable;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LoyaltyLedgerModel> get _filteredMovements {
    // Excluir ruido técnico de migración que se anula mutuamente (ej. -50 pts reservado + 50 pts restauración acumulación libre)
    final cleanMovements = _movements.where((m) {
      final mot = m.motivo.toLowerCase();
      final isTechMigrationRestoration = m.tipoMovimiento == 'RESTAURACION_MIGRACION' ||
          mot.contains('restauración de puntos por cambio a acumulación libre') ||
          mot.contains('restauracion de puntos por cambio a acumulacion libre');
      final isTechMigrationReservation = mot.contains('puntos reservados por desbloqueo de meta') &&
          _movements.any((other) {
            final otherMot = other.motivo.toLowerCase();
            return other.tipoMovimiento == 'RESTAURACION_MIGRACION' ||
                otherMot.contains('restauración de puntos por cambio a acumulación libre') ||
                otherMot.contains('restauracion de puntos por cambio a acumulacion libre');
          });
      return !isTechMigrationRestoration && !isTechMigrationReservation;
    }).toList();

    if (_selectedFilter == 'GANADOS') {
      return cleanMovements.where((m) => m.puntosDelta > 0).toList();
    } else if (_selectedFilter == 'CANJES_AJUSTES') {
      return cleanMovements.where((m) => m.puntosDelta < 0).toList();
    }
    return cleanMovements;
  }


  void _showAddManualBonusModal();
  Widget _buildMovementCard(LoyaltyLedgerModel item, bool isDark);
  Widget _buildFilterChips(bool isDark);
  Widget _buildMetricCol(String label, String value, IconData icon, Color iconColor, Color textC);
  Widget _buildClaimableRewardsAndProgressSection(bool isDark, Color textColor);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final tier = _currentClient.tier;
    final claimableGoals = _claimableSummary?.claimableGoals ?? [];

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
    );

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Container(
        constraints: BoxFormatConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, effectiveBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Asa superior
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cabecera con cliente y botón cerrar
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(tier.colorHex).withValues(alpha: 0.2),
                      child: Text(
                        _currentClient.fullName.isNotEmpty
                            ? _currentClient.fullName[0].toUpperCase()
                            : "?",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(tier.colorHex),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentClient.fullName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(tier.colorHex).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tier.badgeText,
                                    style: TextStyle(
                                      color: Color(tier.colorHex),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Score: ${_currentClient.scoreReputacion}/1000",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tarjeta Resumen Compacta de 3 Métricas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF2E231F), const Color(0xFF1E1E2A)]
                          : [Colors.amber.shade50, Colors.orange.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildMetricCol(
                            "Puntos Actuales",
                            "${_currentClient.puntosActuales} pts",
                            Icons.stars_rounded,
                            Colors.amber[700]!,
                            textColor,
                          ),
                        ),
                      ),
                      Container(height: 32, width: 1, color: isDark ? Colors.white12 : Colors.grey[300]),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildMetricCol(
                            "Racha Pagos",
                            "${_currentClient.rachaPagosPuntuales} a tiempo",
                            Icons.local_fire_department_rounded,
                            Colors.orange,
                            textColor,
                          ),
                        ),
                      ),
                      Container(height: 32, width: 1, color: isDark ? Colors.white12 : Colors.grey[300]),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildMetricCol(
                            "Límite Sugerido",
                            AppCurrency.format(tier.limiteCreditoSugerido),
                            Icons.credit_score_rounded,
                            Colors.green[600]!,
                            textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // TabBar Moderno de 2 Pestañas
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282836) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    indicatorSize: TabBarIndicatorSize.tab,
                    padding: const EdgeInsets.all(3),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.card_giftcard_rounded, size: 15),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                claimableGoals.isNotEmpty
                                    ? "Premios y Metas (${claimableGoals.length})"
                                    : "Premios y Metas",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded, size: 15),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "Historial de Puntos",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Contenido de las Pestañas
                Expanded(
                  child: TabBarView(
                    children: [
                      // Pestaña 1: Premios y Metas
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildClaimableRewardsAndProgressSection(isDark, textColor),
                      ),

                      // Pestaña 2: Historial de Puntos (Amplio >70% de altura)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildFilterChips(isDark),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _showAddManualBonusModal,
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                                label: const Text(
                                  "+ Bono Manual",
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _filteredMovements.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.history_rounded, size: 44, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                            const SizedBox(height: 10),
                                            Text(
                                              _movements.isEmpty
                                                  ? "Sin movimientos de puntos registrados"
                                                  : "No hay movimientos con el filtro seleccionado",
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: _filteredMovements.length,
                                        itemBuilder: (ctx, i) => _buildMovementCard(_filteredMovements[i], isDark),
                                      ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientLoyaltyHistoryModalState extends _ClientLoyaltyHistoryModalStateBase
    with
        _LoyaltyHistoryManualBonusDialogMixin,
        _LoyaltyHistoryMovementCardMixin,
        _LoyaltyHistoryRewardsProgressSectionMixin {}

class BoxFormatConstraints extends BoxConstraints {
  const BoxFormatConstraints({super.maxHeight});
}
