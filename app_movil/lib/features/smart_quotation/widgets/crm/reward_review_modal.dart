import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/core/widgets/loyalty_toast_feedback.dart';

class RewardReviewModal extends StatefulWidget {
  final ClientRewardModel? reward;
  final RewardGoalModel? goal;
  final ClientModel client;
  final VoidCallback onActionCompleted;
  final bool deliverImmediately;

  const RewardReviewModal({
    super.key,
    this.reward,
    this.goal,
    required this.client,
    required this.onActionCompleted,
    this.deliverImmediately = false,
  }) : assert(reward != null || goal != null, 'Debe proporcionarse reward o goal');

  static Future<void> show({
    required BuildContext context,
    ClientRewardModel? reward,
    RewardGoalModel? goal,
    required ClientModel client,
    required VoidCallback onActionCompleted,
    bool deliverImmediately = false,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RewardReviewModal(
        reward: reward,
        goal: goal,
        client: client,
        onActionCompleted: onActionCompleted,
        deliverImmediately: deliverImmediately,
      ),
    );
  }

  @override
  State<RewardReviewModal> createState() => _RewardReviewModalState();
}

class _RewardReviewModalState extends State<RewardReviewModal> {
  final _clientService = ClientService();
  late TextEditingController _titleController;
  late TextEditingController _valueController;
  late TextEditingController _noteController;

  late String _selectedBenefitType;
  late int _metaId;
  late int _puntosRequeridos;
  late bool _isExistingReward;
  bool _isCustomizing = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isExistingReward = widget.reward != null && widget.reward!.id > 0;
    if (widget.reward != null) {
      _metaId = widget.reward!.metaId;
      _puntosRequeridos = widget.reward!.puntosConsumidos;
      _titleController = TextEditingController(text: widget.reward!.tituloRecompensa);
      _valueController = TextEditingController(text: widget.reward!.valorBeneficio.toStringAsFixed(2));
      _noteController = TextEditingController(text: widget.reward!.notaRevision ?? '');
      _selectedBenefitType = widget.reward!.tipoBeneficio;
    } else {
      final g = widget.goal!;
      _metaId = g.id;
      _puntosRequeridos = g.puntosRequeridos;
      _titleController = TextEditingController(text: g.nombre);
      _valueController = TextEditingController(text: g.valorBeneficio.toStringAsFixed(2));
      _noteController = TextEditingController();
      _selectedBenefitType = g.tipoBeneficio;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleApproveAndSendWhatsApp() async {
    setState(() => _isProcessing = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final businessName = auth.activeBusinessName;
    final userId = auth.activeUserId;

    final double customValue = double.tryParse(_valueController.text.trim()) ??
        (widget.reward?.valorBeneficio ?? widget.goal?.valorBeneficio ?? 0.0);
    final String customTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (widget.reward?.tituloRecompensa ?? widget.goal?.nombre ?? 'Premio');
    final String? note = _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null;

    ClientRewardModel? finalReward;

    if (_isExistingReward) {
      final success = await _clientService.approveReward(
        widget.reward!.id,
        customTitle: customTitle,
        customBenefitType: _selectedBenefitType,
        customBenefitValue: customValue,
        note: note,
      );
      if (success) {
        finalReward = widget.reward!.copyWith(
          estado: 'APROBADA_NOTIFICADA',
          tituloRecompensa: customTitle,
          tipoBeneficio: _selectedBenefitType,
          valorBeneficio: customValue,
          notaRevision: note,
        );
      }
    } else {
      // Reclamo nuevo: aquí se descuentan los puntos de forma atómica
      finalReward = await _clientService.claimAndDeliverReward(
        widget.client.id,
        _metaId,
        usuarioId: userId,
        customTitle: customTitle,
        customBenefitType: _selectedBenefitType,
        customBenefitValue: customValue,
        note: note,
        deliverImmediately: widget.deliverImmediately,
      );
    }

    if (finalReward != null && mounted) {
      await LoyaltyWhatsAppService.sendRewardNotification(
        context: context,
        phone: widget.client.phone,
        clientName: widget.client.fullName,
        businessName: businessName,
        reward: finalReward,
        puntosSaldo: widget.client.puntosActuales - _puntosRequeridos,
        nivelReputacion: widget.client.nivelReputacion,
      );

      widget.onActionCompleted();
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() => _isProcessing = false);
        LoyaltyToastFeedback.showWarning(
          context,
          'No se pudo procesar el reclamo de recompensa',
        );
      }
    }
  }

  Future<void> _handleApproveOnly() async {
    setState(() => _isProcessing = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.activeUserId;

    final double customValue = double.tryParse(_valueController.text.trim()) ??
        (widget.reward?.valorBeneficio ?? widget.goal?.valorBeneficio ?? 0.0);
    final String customTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (widget.reward?.tituloRecompensa ?? widget.goal?.nombre ?? 'Premio');
    final String? note = _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null;

    bool success = false;

    if (_isExistingReward) {
      success = await _clientService.approveReward(
        widget.reward!.id,
        customTitle: customTitle,
        customBenefitType: _selectedBenefitType,
        customBenefitValue: customValue,
        note: note,
      );
    } else {
      // Reclamo nuevo: descuenta puntos atómicamente y genera la recompensa
      final created = await _clientService.claimAndDeliverReward(
        widget.client.id,
        _metaId,
        usuarioId: userId,
        customTitle: customTitle,
        customBenefitType: _selectedBenefitType,
        customBenefitValue: customValue,
        note: note,
        deliverImmediately: widget.deliverImmediately,
      );
      success = created != null;
    }

    if (success && mounted) {
      LoyaltyToastFeedback.showSuccess(
        context,
        _isExistingReward
            ? 'Recompensa aprobada y lista para canjear'
            : (widget.deliverImmediately
                ? 'Premio entregado al cliente con éxito'
                : 'Premio reclamado con éxito. Puntos descontados.'),
      );
      widget.onActionCompleted();
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() => _isProcessing = false);
        LoyaltyToastFeedback.showWarning(
          context,
          'Saldo insuficiente para canjear este premio',
        );
      }
    }
  }

  Future<void> _handleDiscard() async {
    if (!_isExistingReward) {
      // Si era un reclamo no efectuado, simplemente cerramos sin tocar puntos
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar Recompensa?'),
        content: const Text(
          'Al descartar esta recompensa, los puntos consumidos se restaurarán automáticamente al saldo del cliente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar y Restaurar Puntos', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      final success = await _clientService.discardReward(
        widget.reward!.id,
        reason: 'Descartada por el comerciante desde el modal de revisión',
      );

      if (success && mounted) {
        LoyaltyToastFeedback.showInfo(
          context,
          'Recompensa descartada. Puntos restaurados al cliente.',
        );
        widget.onActionCompleted();
        Navigator.pop(context);
      } else {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF282838) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Barra de agarre
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revisar Recompensa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Confirmación obligatoria antes de canjear',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Cuerpo con scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta del Cliente y Meta alcanzada
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: widget.client.tier.primaryColor.withValues(alpha: 0.2),
                              child: Text(
                                widget.client.fullName.isNotEmpty
                                    ? widget.client.fullName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: widget.client.tier.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.client.fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${widget.client.tier.displayName} • ${widget.client.puntosActuales} pts disponibles',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.client.tier.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _titleController.text.isNotEmpty
                                          ? _titleController.text
                                          : (widget.reward?.tituloRecompensa ?? widget.goal?.nombre ?? 'Premio'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      'Costo: $_puntosRequeridos puntos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conmutador para personalizar beneficio
                  InkWell(
                    onTap: () => setState(() => _isCustomizing = !_isCustomizing),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            _isCustomizing ? Icons.tune : Icons.edit_outlined,
                            size: 18,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isCustomizing
                                  ? 'Ocultar personalización de premio'
                                  : '¿Deseas cambiar o personalizar este beneficio?',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sección expandible de personalización
                  if (_isCustomizing) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tipo de Beneficio',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildBenefitChip('DESCUENTO_MONTO', 'Descuento S/'),
                              _buildBenefitChip('DESCUENTO_PORCENTAJE', 'Porcentaje %'),
                              _buildBenefitChip('PRODUCTO_REGALO', 'Regalo Físico'),
                              _buildBenefitChip('CREDITO_PREFERENCIAL', 'Línea Crédito'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Título del Premio',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                          if (_selectedBenefitType != 'PRODUCTO_REGALO') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _valueController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: _selectedBenefitType == 'DESCUENTO_PORCENTAJE'
                                    ? 'Porcentaje (%)'
                                    : 'Monto (S/)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              labelText: 'Nota interna (opcional)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Botones de Acción
                  if (_isProcessing)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // 1. Confirmar y Enviar por WhatsApp
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _handleApproveAndSendWhatsApp,
                        icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'Confirmar y Enviar por WhatsApp',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. Solo Aprobar (sin abrir WhatsApp)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _handleApproveOnly,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Aprobar Premio (sin enviar WhatsApp)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. Fila de Descartar y Posponer
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _handleDiscard,
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            label: const Text(
                              'Descartar',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Revisar después',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitChip(String type, String label) {
    final isSelected = _selectedBenefitType == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      onSelected: (val) {
        if (val) setState(() => _selectedBenefitType = type);
      },
    );
  }
}

