import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class ClientLoyaltyHistoryModal extends StatefulWidget {
  final ClientModel client;
  final VoidCallback? onPointsChanged;

  const ClientLoyaltyHistoryModal({
    super.key,
    required this.client,
    this.onPointsChanged,
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
  late ClientModel _currentClient;

  @override
  void initState() {
    super.initState();
    _currentClient = widget.client;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _clientService.getClientById(_currentClient.id);
      if (updated != null && mounted) {
        _currentClient = updated;
      }
      final list = await _clientService.getClientLoyaltyLedger(_currentClient.id);
      if (mounted) {
        setState(() {
          _movements = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  "Ajuste / Bono Manual",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textC),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text("+ Sumar Puntos"),
                        selected: isAdding,
                        selectedColor: Colors.green.withValues(alpha: 0.2),
                        onSelected: (val) => setDialogState(() => isAdding = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("- Restar Puntos"),
                        selected: !isAdding,
                        selectedColor: Colors.red.withValues(alpha: 0.2),
                        onSelected: (val) => setDialogState(() => isAdding = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Cantidad de Puntos",
                      suffixText: "pts",
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: "Motivo / Justificación",
                      hintText: "Ej. Bono por aniversario o recomendación",
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                onPressed: () async {
                  final rawPoints = int.tryParse(pointsCtrl.text.trim()) ?? 0;
                  if (rawPoints <= 0) return;
                  final deltaPts = isAdding ? rawPoints : -rawPoints;
                  final reason = reasonCtrl.text.trim().isNotEmpty
                      ? reasonCtrl.text.trim()
                      : (isAdding ? "Bono de fidelización otorgado" : "Ajuste manual de puntos");

                  Navigator.pop(ctx);
                  await _clientService.addManualLoyaltyMovement(
                    _currentClient.id,
                    _currentClient.negocioId,
                    pointsDelta: deltaPts,
                    motivo: reason,
                    scoreDelta: isAdding ? deltaScore : -deltaScore,
                  );

                  widget.onPointsChanged?.call();
                  _loadHistory();
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
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
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
                        Row(
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
                padding: const EdgeInsets.all(14),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol(
                      "Puntos Actuales",
                      "${_currentClient.puntosActuales} pts",
                      Icons.stars_rounded,
                      Colors.amber[700]!,
                      textColor,
                    ),
                    Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey[300]),
                    _buildMetricCol(
                      "Racha Pagos",
                      "🔥 ${_currentClient.rachaPagosPuntuales}",
                      Icons.local_fire_department_rounded,
                      Colors.orange,
                      textColor,
                    ),
                    Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey[300]),
                    _buildMetricCol(
                      "Límite Sugerido",
                      AppCurrency.format(tier.limiteCreditoSugerido),
                      Icons.credit_score_rounded,
                      Colors.green[600]!,
                      textColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Barra de título del Kardex + Botón Bono
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Kardex de Movimientos",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showAddManualBonusModal,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text(
                      "Bono Manual",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber[800],
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista de movimientos
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _movements.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                const SizedBox(height: 10),
                                Text(
                                  "Sin movimientos de fidelización registrados",
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
                            itemCount: _movements.length,
                            itemBuilder: (ctx, i) => _buildMovementCard(_movements[i], isDark),
                          ),
              ),
            ],
          ),
        ),
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
