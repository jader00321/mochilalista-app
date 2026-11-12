import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class LoyaltyRulesConfigModal extends StatefulWidget {
  final int negocioId;
  final VoidCallback? onRulesSaved;

  const LoyaltyRulesConfigModal({
    super.key,
    required this.negocioId,
    this.onRulesSaved,
  });

  static Future<void> show(BuildContext context, {
    required int negocioId,
    VoidCallback? onRulesSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LoyaltyRulesConfigModal(
        negocioId: negocioId,
        onRulesSaved: onRulesSaved,
      ),
    );
  }

  @override
  State<LoyaltyRulesConfigModal> createState() => _LoyaltyRulesConfigModalState();
}

class _LoyaltyRulesConfigModalState extends State<LoyaltyRulesConfigModal> {
  final _clientService = ClientService();
  bool _isLoading = true;
  bool _isSaving = false;

  late LoyaltyRulesModel _rules;

  // Controllers
  late TextEditingController _ptsCompraCtrl;
  late TextEditingController _montoBaseCompraCtrl;
  late TextEditingController _compraMinimaCtrl;
  late TextEditingController _ptsCotizacionCtrl;
  late TextEditingController _ptsPagoPuntualCtrl;
  late TextEditingController _rachaFrecuenciaCtrl;
  late TextEditingController _ptsRachaCtrl;
  late TextEditingController _ptsLiquidacionCtrl;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    final rules = await _clientService.getLoyaltyRules(widget.negocioId);
    _rules = rules;
    _initControllers();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _initControllers() {
    _ptsCompraCtrl = TextEditingController(text: '${_rules.puntosPorUnidadMoneda}');
    _montoBaseCompraCtrl = TextEditingController(
      text: _rules.montoBaseCompra.truncateToDouble() == _rules.montoBaseCompra
          ? _rules.montoBaseCompra.toInt().toString()
          : _rules.montoBaseCompra.toStringAsFixed(2),
    );
    _compraMinimaCtrl = TextEditingController(
      text: _rules.compraMinimaParaPuntos.truncateToDouble() == _rules.compraMinimaParaPuntos
          ? _rules.compraMinimaParaPuntos.toInt().toString()
          : _rules.compraMinimaParaPuntos.toStringAsFixed(2),
    );
    _ptsCotizacionCtrl = TextEditingController(text: '${_rules.puntosBonoCotizacion}');
    _ptsPagoPuntualCtrl = TextEditingController(text: '${_rules.puntosPagoPuntual}');
    _rachaFrecuenciaCtrl = TextEditingController(text: '${_rules.cadaCuantasCuotasRacha}');
    _ptsRachaCtrl = TextEditingController(text: '${_rules.puntosBonoRacha}');
    _ptsLiquidacionCtrl = TextEditingController(text: '${_rules.puntosLiquidacionSinMora}');
  }

  @override
  void dispose() {
    _ptsCompraCtrl.dispose();
    _montoBaseCompraCtrl.dispose();
    _compraMinimaCtrl.dispose();
    _ptsCotizacionCtrl.dispose();
    _ptsPagoPuntualCtrl.dispose();
    _rachaFrecuenciaCtrl.dispose();
    _ptsRachaCtrl.dispose();
    _ptsLiquidacionCtrl.dispose();
    super.dispose();
  }

  void _restoreDefaults() {
    final def = LoyaltyRulesModel.defaultRules(widget.negocioId);
    setState(() {
      _rules = def;
      _ptsCompraCtrl.text = '${def.puntosPorUnidadMoneda}';
      _montoBaseCompraCtrl.text = '${def.montoBaseCompra.toInt()}';
      _compraMinimaCtrl.text = '${def.compraMinimaParaPuntos.toInt()}';
      _ptsCotizacionCtrl.text = '${def.puntosBonoCotizacion}';
      _ptsPagoPuntualCtrl.text = '${def.puntosPagoPuntual}';
      _rachaFrecuenciaCtrl.text = '${def.cadaCuantasCuotasRacha}';
      _ptsRachaCtrl.text = '${def.puntosBonoRacha}';
      _ptsLiquidacionCtrl.text = '${def.puntosLiquidacionSinMora}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Valores recomendados restablecidos. Presiona Guardar para aplicar.'),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveRules() async {
    setState(() => _isSaving = true);
    final updated = _rules.copyWith(
      puntosPorUnidadMoneda: int.tryParse(_ptsCompraCtrl.text.trim()) ?? 1,
      montoBaseCompra: double.tryParse(_montoBaseCompraCtrl.text.trim()) ?? 1.0,
      compraMinimaParaPuntos: double.tryParse(_compraMinimaCtrl.text.trim()) ?? 0.0,
      puntosBonoCotizacion: int.tryParse(_ptsCotizacionCtrl.text.trim()) ?? 10,
      puntosPagoPuntual: int.tryParse(_ptsPagoPuntualCtrl.text.trim()) ?? 25,
      cadaCuantasCuotasRacha: int.tryParse(_rachaFrecuenciaCtrl.text.trim()) ?? 3,
      puntosBonoRacha: int.tryParse(_ptsRachaCtrl.text.trim()) ?? 30,
      puntosLiquidacionSinMora: int.tryParse(_ptsLiquidacionCtrl.text.trim()) ?? 50,
      updatedAt: DateTime.now().toIso8601String(),
    );

    final success = await _clientService.updateLoyaltyRules(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reglas de ganancia de puntos guardadas correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRulesSaved?.call();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar las reglas'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF282838) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(
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

                // Encabezado
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Configurar Reglas de Puntos",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Define cómo ganan puntos tus clientes",
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
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
                const SizedBox(height: 12),

                // Contenido scrolleable
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Regla 1: Compras al Contado
                              _buildRuleCard(
                                title: "1. Compras al Contado (Caja Rápida)",
                                description: "Otorga puntos automáticos por cada compra pagada al contado.",
                                icon: Icons.shopping_bag_rounded,
                                isActive: _rules.puntosPorCompraActivo,
                                onToggle: (val) => setState(() => _rules = _rules.copyWith(puntosPorCompraActivo: val)),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSmallNumberField(
                                          controller: _ptsCompraCtrl,
                                          label: "Puntos ganados",
                                          suffix: "pts",
                                          isDark: isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildSmallNumberField(
                                          controller: _montoBaseCompraCtrl,
                                          label: "Por cada",
                                          prefix: "S/ ",
                                          isDark: isDark,
                                          isDecimal: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildSmallNumberField(
                                    controller: _compraMinimaCtrl,
                                    label: "Compra mínima para aplicar (opcional)",
                                    prefix: "S/ ",
                                    isDark: isDark,
                                    isDecimal: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Regla 2: Cotizaciones Concretadas
                              _buildRuleCard(
                                title: "2. Cotizaciones Concretadas",
                                description: "Bono extra cuando una cotización se convierte en venta efectiva.",
                                icon: Icons.description_rounded,
                                isActive: _rules.bonoCotizacionActivo,
                                onToggle: (val) => setState(() => _rules = _rules.copyWith(bonoCotizacionActivo: val)),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                children: [
                                  _buildSmallNumberField(
                                    controller: _ptsCotizacionCtrl,
                                    label: "Bono por concretar cotización",
                                    suffix: "pts extra",
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Regla 3: Abono Inicial en Ventas al Crédito
                              _buildRuleCard(
                                title: "3. Abono Inicial en Ventas al Crédito",
                                description: "Premia proporcionalmente el pago inicial entregado al llevar mercadería al crédito.",
                                icon: Icons.payments_rounded,
                                isActive: _rules.puntosAbonoInicialActivo,
                                onToggle: (val) => setState(() => _rules = _rules.copyWith(puntosAbonoInicialActivo: val)),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                children: [
                                  Text(
                                    "Los puntos se calculan automáticamente con la fórmula de compra sobre el monto del abono inicial.",
                                    style: TextStyle(fontSize: 12, color: subtextColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Regla 4: Pago de Cuota a Tiempo
                              _buildRuleCard(
                                title: "4. Pago de Cuota Puntual",
                                description: "Premia a los clientes que pagan su cuota en o antes de la fecha de vencimiento.",
                                icon: Icons.verified_rounded,
                                isActive: _rules.bonoPagoPuntualActivo,
                                onToggle: (val) => setState(() => _rules = _rules.copyWith(bonoPagoPuntualActivo: val)),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                children: [
                                  _buildSmallNumberField(
                                    controller: _ptsPagoPuntualCtrl,
                                    label: "Puntos por cuota a tiempo",
                                    suffix: "pts",
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Regla 5: Bono por Racha de Pagos Puntuales
                              _buildRuleCard(
                                title: "5. Racha de Pagos Puntuales",
                                description: "Incentivo adicional por mantener pagos consecutivos sin ningún retraso.",
                                icon: Icons.local_fire_department_rounded,
                                isActive: _rules.bonoRachaActivo,
                                onToggle: (val) => setState(() => _rules = _rules.copyWith(bonoRachaActivo: val)),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSmallNumberField(
                                          controller: _rachaFrecuenciaCtrl,
                                          label: "Cada",
                                          suffix: "cuotas a tiempo",
                                          isDark: isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildSmallNumberField(
                                          controller: _ptsRachaCtrl,
                                          label: "Bono racha",
                                          suffix: "pts",
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Regla 6: Liquidación Total sin Mora
                              _buildRuleCard(
                                title: "6. Liquidación Total sin Mora",
                                description: "Bono final al cancelar la última cuota de un crédito habiendo cumplido a tiempo.",
                                icon: Icons.card_giftcard_rounded,
                                isActive: _rules.bonoLiquidacionSinMoraActivo,
                                onToggle: (val) => setState(() => _rules = _rules.copyWith(bonoLiquidacionSinMoraActivo: val)),
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                children: [
                                  _buildSmallNumberField(
                                    controller: _ptsLiquidacionCtrl,
                                    label: "Bono por finiquito sin mora",
                                    suffix: "pts",
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                ),

                const SizedBox(height: 12),

                // Botones footer
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: _isLoading || _isSaving ? null : _restoreDefaults,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("Valores por Defecto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || _isSaving ? null : _saveRules,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text("Guardar Reglas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isActive,
    required ValueChanged<bool> onToggle,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? Colors.amber.withValues(alpha: 0.35) : borderColor,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isActive ? Colors.amber.withValues(alpha: 0.18) : Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.amber[800] : Colors.grey,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive ? textColor : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Switch.adaptive(
                value: isActive,
                onChanged: onToggle,
                activeTrackColor: Colors.amber[700],
              ),
            ],
          ),
          Text(
            description,
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          if (isActive && children.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _buildSmallNumberField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    required bool isDark,
    bool isDecimal = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: [
        if (!isDecimal) FilteringTextInputFormatter.digitsOnly,
      ],
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixText: prefix,
        suffixText: suffix,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
