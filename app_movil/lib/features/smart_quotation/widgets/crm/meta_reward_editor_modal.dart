import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class MetaRewardEditorModal extends StatefulWidget {
  final int negocioId;
  final RewardGoalModel? goal;

  const MetaRewardEditorModal({
    super.key,
    required this.negocioId,
    this.goal,
  });

  static Future<RewardGoalModel?> show(
    BuildContext context, {
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
    _valueCtrl = TextEditingController(
      text: g != null
          ? (g.valorBeneficio.truncateToDouble() == g.valorBeneficio
              ? g.valorBeneficio.toInt().toString()
              : g.valorBeneficio.toStringAsFixed(2))
          : '10',
    );
    _benefitType = g?.tipoBeneficio ?? 'DESCUENTO_MONTO';
    _isActive = g != null ? g.activo : true;

    _titleCtrl.addListener(_onFieldChanged);
    _descCtrl.addListener(_onFieldChanged);
    _pointsCtrl.addListener(_onFieldChanged);
    _valueCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onFieldChanged);
    _descCtrl.removeListener(_onFieldChanged);
    _pointsCtrl.removeListener(_onFieldChanged);
    _valueCtrl.removeListener(_onFieldChanged);

    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  String get _benefitValueLabel {
    switch (_benefitType) {
      case 'DESCUENTO_PORCENTAJE':
        return 'Porcentaje (%)';
      case 'DESCUENTO_MONTO':
        return 'Descuento (S/)';
      case 'PRODUCTO_REGALO':
        return 'Valor Ref. Regalo (S/)';
      case 'CREDITO_PREFERENCIAL':
      default:
        return 'Monto Crédito (S/)';
    }
  }

  String? get _benefitPrefix {
    switch (_benefitType) {
      case 'DESCUENTO_MONTO':
      case 'PRODUCTO_REGALO':
      case 'CREDITO_PREFERENCIAL':
        return 'S/ ';
      case 'DESCUENTO_PORCENTAJE':
      default:
        return null;
    }
  }

  String? get _benefitSuffix {
    switch (_benefitType) {
      case 'DESCUENTO_PORCENTAJE':
        return '%';
      default:
        return null;
    }
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
        final unlocked = await _clientService.evaluateAllClientsForActiveGoals(widget.negocioId);
        if (mounted) {
          if (unlocked.isNotEmpty) {
            CustomSnackBar.show(
              context,
              message: 'Meta creada. ${unlocked.length} cliente(s) ya cumplen y sus premios están listos para revisar',
            );
          } else {
            CustomSnackBar.show(context, message: 'Meta de recompensa creada');
          }
          Navigator.pop(context, created);
        }
      } else {
        await _clientService.updateRewardGoal(widget.goal!.id, model.toSqlite());
        final unlocked = await _clientService.evaluateAllClientsForActiveGoals(widget.negocioId);
        if (mounted) {
          if (unlocked.isNotEmpty) {
            CustomSnackBar.show(
              context,
              message: 'Meta actualizada. ${unlocked.length} cliente(s) ya cumplen y sus premios están listos para revisar',
            );
          } else {
            CustomSnackBar.show(context, message: 'Meta actualizada');
          }
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
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

                  // 1. Campo: Título de la meta
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

                  // 2. Tipo de Beneficio Comercial (Primero para condicionar el valor)
                  Text(
                    'Tipo de Beneficio Comercial',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
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

                  // 3. Fila Adaptativa: Puntos Requeridos y Valor del Beneficio
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
                              _benefitValueLabel,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _valueCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: '10',
                                prefixText: _benefitPrefix,
                                suffixText: _benefitSuffix,
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
                  const SizedBox(height: 16),

                  // 4. Descripción o Nota opcional
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

                  // 5. Estado: Activo / Inactivo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
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
                  const SizedBox(height: 20),

                  // 6. Live Preview Card en Tiempo Real
                  Row(
                    children: [
                      const Icon(Icons.visibility_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Vista Previa en Tiempo Real',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amber[300] : Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLivePreviewCard(isDark, cardColor, textColor),
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
    ),
  );
}

  Widget _buildLivePreviewCard(bool isDark, Color cardColor, Color textColor) {
    IconData icon;
    Color iconColor;
    final value = double.tryParse(_valueCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final points = int.tryParse(_pointsCtrl.text.trim()) ?? 0;
    final title = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Título de la Meta';
    final desc = _descCtrl.text.trim();

    String benefitLabel;
    switch (_benefitType) {
      case 'DESCUENTO_MONTO':
        icon = Icons.attach_money_rounded;
        iconColor = Colors.green;
        benefitLabel = 'Descuento de ${AppCurrency.format(value)}';
        break;
      case 'DESCUENTO_PORCENTAJE':
        icon = Icons.percent_rounded;
        iconColor = Colors.blue;
        benefitLabel = '${value.toStringAsFixed(0)}% de Descuento';
        break;
      case 'PRODUCTO_REGALO':
        icon = Icons.card_giftcard_rounded;
        iconColor = Colors.purple;
        benefitLabel = value > 0 ? 'Producto de Regalo (${AppCurrency.format(value)})' : 'Producto de Regalo';
        break;
      default:
        icon = Icons.credit_score_rounded;
        iconColor = Colors.amber;
        benefitLabel = value > 0 ? 'Crédito Extra de ${AppCurrency.format(value)}' : 'Crédito Preferencial';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$points pts',
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
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
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
        ],
      ),
    );
  }
}
