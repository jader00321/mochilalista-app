import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/reward_review_modal.dart';

class ClientLoyaltyHistoryModal extends StatefulWidget {
  final ClientModel client;
  final VoidCallback? onPointsChanged;
  final bool autoLoadHistory;
  final List<LoyaltyLedgerModel>? initialMovements;
  final Map<String, dynamic>? initialNextGoalData;
  final List<ClientRewardModel>? initialPendingRewards;

  const ClientLoyaltyHistoryModal({
    super.key,
    required this.client,
    this.onPointsChanged,
    this.autoLoadHistory = true,
    this.initialMovements,
    this.initialNextGoalData,
    this.initialPendingRewards,
  });

  static Future<void> show(BuildContext context, {
    required ClientModel client,
    VoidCallback? onPointsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClientLoyaltyHistoryModal(
        client: client,
        onPointsChanged: onPointsChanged,
      ),
    );
  }

  @override
  State<ClientLoyaltyHistoryModal> createState() => _ClientLoyaltyHistoryModalState();
}

class _ClientLoyaltyHistoryModalState extends State<ClientLoyaltyHistoryModal> {
  final _clientService = ClientService();
  bool _isLoading = true;
  List<LoyaltyLedgerModel> _movements = [];
  List<RewardGoalModel> _goals = [];
  Map<String, dynamic>? _nextGoalData;
  List<ClientRewardModel> _pendingRewards = [];
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

      if (mounted) {
        setState(() {
          _movements = list;
          _goals = goals;
          _nextGoalData = nextGoal;
          _pendingRewards = pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LoyaltyLedgerModel> get _filteredMovements {
    if (_selectedFilter == 'GANADOS') {
      return _movements.where((m) => m.puntosDelta > 0).toList();
    } else if (_selectedFilter == 'CANJES_AJUSTES') {
      return _movements.where((m) => m.puntosDelta < 0).toList();
    }
    return _movements;
  }

  void _showAddManualBonusModal() {
    final pointsCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    int deltaScore = 5;
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF282836) : Colors.white;
          final textC = isDark ? Colors.white : Colors.black87;

          final currentPts = _currentClient.puntosActuales;
          final enteredPts = int.tryParse(pointsCtrl.text.trim()) ?? 0;
          final bool exceedsCurrent = !isAdding && enteredPts > currentPts;
          final newBalance = isAdding
              ? currentPts + enteredPts
              : math.max(0, currentPts - enteredPts);

          // Verificar si este bono alcanzará alguna meta activa
          RewardGoalModel? willUnlockGoal;
          if (isAdding && enteredPts > 0) {
            for (var g in _goals) {
              if (newBalance >= g.puntosRequeridos && currentPts < g.puntosRequeridos) {
                willUnlockGoal = g;
                break;
              }
            }
          }

          final quickMotives = isAdding
              ? [
                  "Bono de cortesía",
                  "Pago puntual",
                  "Compra previa",
                  "Promoción especial",
                ]
              : [
                  "Corrección de saldo",
                  "Devolución de mercadería",
                  "Ajuste administrativo",
                ];

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber[700], size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Ajuste / Bono Manual",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textC),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila de Chips con Expanded y FittedBox (0 Overflow garantizado en 320/360dp)
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("+ Sumar Puntos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ),
                          ),
                          selected: isAdding,
                          selectedColor: Colors.green.withValues(alpha: 0.25),
                          onSelected: (val) {
                            setDialogState(() {
                              isAdding = true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("- Restar Puntos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ),
                          ),
                          selected: !isAdding,
                          selectedColor: Colors.red.withValues(alpha: 0.25),
                          onSelected: (val) {
                            setDialogState(() {
                              isAdding = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: "Cantidad de Puntos",
                      suffixText: "pts",
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Indicador Dinámico de Impacto en Vivo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: exceedsCurrent
                            ? Colors.red.withValues(alpha: 0.6)
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Saldo actual: $currentPts pts",
                                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_forward_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  "Nuevo: $newBalance pts",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: exceedsCurrent
                                        ? Colors.red
                                        : (isAdding ? Colors.green[600] : Colors.orange[800]),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (exceedsCurrent) ...[
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "El saldo no puede ser negativo (Excede el saldo)",
                                  style: TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (willUnlockGoal != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.amber[800]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "Desbloqueará '${willUnlockGoal.nombre}' (${willUnlockGoal.puntosRequeridos} pts) para revisión",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? Colors.amber[300] : Colors.amber[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: reasonCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: "Motivo / Justificación",
                      hintText: "Ej. Bono por recomendación",
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Chips Rápidos de Motivo en 1 Toque
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: quickMotives.map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(m, style: const TextStyle(fontSize: 10.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                            onPressed: () {
                              setDialogState(() {
                                reasonCtrl.text = m;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: (enteredPts <= 0 || exceedsCurrent)
                    ? null
                    : () async {
                        final rawPoints = enteredPts;
                        final deltaPts = isAdding ? rawPoints : -rawPoints;
                        final reason = reasonCtrl.text.trim().isNotEmpty
                            ? reasonCtrl.text.trim()
                            : (isAdding ? "Bono de fidelización otorgado" : "Ajuste manual de puntos");

                        final messenger = ScaffoldMessenger.of(context);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final userId = auth.activeUserId;
                        Navigator.pop(ctx);

                        final unlocked = await _clientService.addManualLoyaltyMovement(
                          _currentClient.id,
                          _currentClient.negocioId,
                          pointsDelta: deltaPts,
                          motivo: reason,
                          scoreDelta: isAdding ? deltaScore : -deltaScore,
                          usuarioId: userId,
                        );

                        widget.onPointsChanged?.call();
                        await _loadHistory();

                        if (mounted && unlocked.isNotEmpty) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.amber[800],
                              content: Row(
                                children: [
                                  const Icon(Icons.card_giftcard_rounded, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Meta '${unlocked.first.tituloRecompensa}' desbloqueada para revisión",
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Aplicar", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

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
        icon = Icons.local_fire_department_rounded;
        break;
      case 'CANJE_RECOMPENSA':
        icon = Icons.card_giftcard_rounded;
        break;
      case 'MORA_PENALIZACION':
        icon = Icons.warning_amber_rounded;
        break;
      case 'ANULACION_VENTA_REVERSA':
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.motivo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
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
                          fontSize: 13,
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final tier = _currentClient.tier;

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
    );

    return Container(
      constraints: BoxFormatConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, effectiveBottom),
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
              const SizedBox(height: 14),

              // Cabecera con cliente y botón cerrar
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(tier.colorHex).withValues(alpha: 0.2),
                    child: Text(
                      _currentClient.fullName.isNotEmpty
                          ? _currentClient.fullName[0].toUpperCase()
                          : "?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(tier.colorHex),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentClient.fullName,
                          style: TextStyle(
                            fontSize: 17,
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
                                  fontSize: 12,
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
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta Resumen de Puntos y Crédito
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2E231F), const Color(0xFF1E1E2A)]
                        : [Colors.amber.shade50, Colors.orange.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
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
                    Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey[300]),
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
                    Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey[300]),
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

              // Tarjeta de Próxima Meta o Recompensa Pendiente
              _buildRewardProgressOrReviewCard(isDark, textColor),
              const SizedBox(height: 12),

              // Barra de título del Kardex + Botón Bono
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Kardex de Movimientos",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _showAddManualBonusModal,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text(
                      "Bono Manual",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber[800],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Chips de filtro rápido
              _buildFilterChips(isDark),
              const SizedBox(height: 4),

              // Lista de movimientos filtrada
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredMovements.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                const SizedBox(height: 10),
                                Text(
                                  _movements.isEmpty
                                      ? "Sin movimientos de fidelización registrados"
                                      : "No hay movimientos con el filtro seleccionado",
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 14,
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
        ),
      ),
    );
  }

  Widget _buildRewardProgressOrReviewCard(bool isDark, Color textColor) {
    if (_pendingRewards.isNotEmpty) {
      final pending = _pendingRewards.first;
      return Container(
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
                    pending.tituloRecompensa,
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
                    reward: pending,
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
      );
    }

    if (_nextGoalData != null && _nextGoalData!['goal'] != null) {
      final meta = _nextGoalData!['goal'] as RewardGoalModel;
      final int missing = (_nextGoalData!['puntos_faltantes'] ?? _nextGoalData!['missing'] as num?)?.toInt() ?? 0;
      final double progress = ((_nextGoalData!['progreso'] ?? _nextGoalData!['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);

      return Container(
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
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Próxima Meta: ${meta.titulo}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  missing <= 0 ? "Meta alcanzada" : "Faltan $missing pts",
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
                  "${_currentClient.puntosActuales} / ${meta.puntosRequeridos} pts",
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
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = [
      {'id': 'TODOS', 'label': 'Todos (${_movements.length})', 'icon': Icons.list_rounded},
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

class BoxFormatConstraints extends BoxConstraints {
  const BoxFormatConstraints({super.maxHeight});
}
