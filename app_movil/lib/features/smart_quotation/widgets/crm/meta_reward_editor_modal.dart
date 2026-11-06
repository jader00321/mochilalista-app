import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class MetaRewardEditorModal extends StatefulWidget {
  final int negocioId;
  final RewardGoalModel? goal;

  const MetaRewardEditorModal({
    super.key,
    required this.negocioId,
    this.goal,
  });

  static Future<RewardGoalModel?> show(BuildContext context, {
    required int negocioId,
    RewardGoalModel? goal,
  }) {
    return showModalBottomSheet<RewardGoalModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MetaRewardEditorModal(
        negocioId: negocioId,
        goal: goal,
      ),
    );
  }

  @override
  State<MetaRewardEditorModal> createState() => _MetaRewardEditorModalState();
}

class _MetaRewardEditorModalState extends State<MetaRewardEditorModal> {
  final _formKey = GlobalKey<FormState>();
  final _clientService = ClientService();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _pointsCtrl;
  late TextEditingController _valueCtrl;

  late String _benefitType;
  late bool _isActive;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _benefitTypes = [
    {
      'key': 'DESCUENTO_MONTO',
      'label': 'Descuento en Monto (S/)',
      'icon': Icons.attach_money_rounded,
      'color': Colors.green,
    },
    {
      'key': 'DESCUENTO_PORCENTAJE',
      'label': 'Descuento Porcentual (%)',
      'icon': Icons.percent_rounded,
      'color': Colors.blue,
    },
    {
      'key': 'PRODUCTO_REGALO',
      'label': 'Producto de Regalo',
      'icon': Icons.card_giftcard_rounded,
      'color': Colors.purple,
    },
    {
      'key': 'CREDITO_PREFERENCIAL',
      'label': 'Crédito Preferencial (Límite Extra)',
      'icon': Icons.credit_score_rounded,
      'color': Colors.amber,
    },
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _titleCtrl = TextEditingController(text: g?.nombre ?? '');
    _descCtrl = TextEditingController(text: g?.descripcion ?? '');
    _pointsCtrl = TextEditingController(text: g != null ? '${g.puntosRequeridos}' : '100');
    _valueCtrl = TextEditingController(text: g != null ? g.valorBeneficio.toStringAsFixed(g.valorBeneficio.truncateToDouble() == g.valorBeneficio ? 0 : 2) : '10');
    _benefitType = g?.tipoBeneficio ?? 'DESCUENTO_MONTO';
    _isActive = g != null ? g.activo : true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final points = int.tryParse(_pointsCtrl.text.trim()) ?? 0;
    final value = double.tryParse(_valueCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

    if (points <= 0) {
      CustomSnackBar.show(context, message: 'Los puntos requeridos deben ser mayores a 0');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isNew = widget.goal == null;
      final model = RewardGoalModel(
        id: widget.goal?.id ?? 0,
        negocioId: widget.negocioId,
        nombre: _titleCtrl.text.trim(),
        descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        puntosRequeridos: points,
        tipoBeneficio: _benefitType,
        valorBeneficio: value,
        activo: _isActive,
        esPredeterminada: widget.goal?.esPredeterminada ?? false,
        createdAt: widget.goal?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (isNew) {
        final created = await _clientService.createRewardGoal(widget.negocioId, model.toSqlite());
        if (mounted) {
          CustomSnackBar.show(context, message: 'Meta de recompensa creada');
          Navigator.pop(context, created);
        }
      } else {
        await _clientService.updateRewardGoal(widget.goal!.id, model.toSqlite());
        if (mounted) {
          CustomSnackBar.show(context, message: 'Meta actualizada');
          Navigator.pop(context, model);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: 'Error al guardar la meta: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = isDark ? const Color(0xFF282836) : Colors.grey.shade50;
    final isNew = widget.goal == null;

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
    );

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, effectiveBottom),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 16),

                  // Título de la cabecera
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isNew ? 'Nueva Meta de Fidelización' : 'Editar Meta de Premio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Recompensa automática al alcanzar puntos',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                  const SizedBox(height: 20),

                  // Campo: Título de la meta
                  Text(
                    'Título del Premio',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleCtrl,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Ej. Vale S/ 10.00 en Útiles',
                      filled: true,
                      fillColor: cardColor,
                      prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un título descriptivo' : null,
                  ),
                  const SizedBox(height: 16),

                  // Puntos Requeridos y Valor del Beneficio
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Puntos Requeridos',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _pointsCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: '100',
                                suffixText: 'pts',
                                filled: true,
                                fillColor: cardColor,
                                prefixIcon: const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                final val = int.tryParse(v.trim());
                                if (val == null || val <= 0) return 'Mayor a 0';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _benefitType == 'DESCUENTO_PORCENTAJE'
                                  ? 'Porcentaje (%)'
                                  : (_benefitType == 'DESCUENTO_MONTO' ? 'Descuento (S/)' : 'Valor Estimado'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _valueCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: '10',
                                prefixText: _benefitType == 'DESCUENTO_MONTO' ? 'S/ ' : null,
                                suffixText: _benefitType == 'DESCUENTO_PORCENTAJE' ? '%' : null,
                                filled: true,
                                fillColor: cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                final val = double.tryParse(v.trim().replaceAll(',', '.'));
                                if (val == null || val <= 0) return 'Mayor a 0';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tipo de Beneficio
                  Text(
                    'Tipo de Beneficio Comercial',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _benefitType,
                        dropdownColor: isDark ? const Color(0xFF282836) : Colors.white,
                        items: _benefitTypes.map((t) {
                          return DropdownMenuItem<String>(
                            value: t['key'] as String,
                            child: Row(
                              children: [
                                Icon(t['icon'] as IconData, color: t['color'] as Color, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    t['label'] as String,
                                    style: TextStyle(fontSize: 14, color: textColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _benefitType = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Descripción o Nota opcional
                  Text(
                    'Descripción / Términos (Opcional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ej. Válido en compras mayores a S/ 30.00 o en útiles escolares.',
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Estado: Activo / Inactivo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                              color: _isActive ? Colors.green : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isActive ? 'Meta Activa (Desbloqueable)' : 'Meta Pausada',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _isActive,
                          activeTrackColor: Colors.amber,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                            )
                          : const Icon(Icons.check_rounded, size: 22),
                      label: Text(
                        _isSaving ? 'Guardando...' : (isNew ? 'Crear Meta de Premio' : 'Guardar Cambios'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
