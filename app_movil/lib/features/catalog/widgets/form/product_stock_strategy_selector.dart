import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum StockAdvisorState {
  hidden,
  recommendation,
  mandatory,
}

class ProductStockStrategySelector extends StatefulWidget {
  final String selectedStrategy; // 'INDEPENDIENTE', 'COMPARTIDO', 'MIXTO'
  final ValueChanged<String> onStrategyChanged;
  final TextEditingController sharedStockController;
  final TextEditingController baseCostController;
  final bool isDark;
  final bool isEditMode;
  final TextEditingController? sharedIngresoController;
  final int? originalBaseStock;
  final List<Map<String, dynamic>>? controllers;
  final VoidCallback? onAutoCreateUnitVariant;

  const ProductStockStrategySelector({
    super.key,
    required this.selectedStrategy,
    required this.onStrategyChanged,
    required this.sharedStockController,
    required this.baseCostController,
    required this.isDark,
    this.isEditMode = false,
    this.sharedIngresoController,
    this.originalBaseStock,
    this.controllers,
    this.onAutoCreateUnitVariant,
  });

  @override
  State<ProductStockStrategySelector> createState() =>
      _ProductStockStrategySelectorState();
}

class _ProductStockStrategySelectorState
    extends State<ProductStockStrategySelector> {
  bool _isAdvisorDismissed = false;

  @override
  void initState() {
    super.initState();
    widget.sharedStockController.addListener(_onSharedStockChanged);
    widget.sharedIngresoController?.addListener(_onSharedIngresoChanged);
  }

  @override
  void didUpdateWidget(covariant ProductStockStrategySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedStockController != widget.sharedStockController) {
      oldWidget.sharedStockController.removeListener(_onSharedStockChanged);
      widget.sharedStockController.addListener(_onSharedStockChanged);
    }
    if (oldWidget.sharedIngresoController != widget.sharedIngresoController) {
      oldWidget.sharedIngresoController?.removeListener(_onSharedIngresoChanged);
      widget.sharedIngresoController?.addListener(_onSharedIngresoChanged);
    }
  }

  @override
  void dispose() {
    widget.sharedStockController.removeListener(_onSharedStockChanged);
    widget.sharedIngresoController?.removeListener(_onSharedIngresoChanged);
    super.dispose();
  }

  void _onSharedIngresoChanged() {
    if (mounted) setState(() {});
  }

  void _onSharedStockChanged() {
    _syncSharedVariantsAfterBaseStockChange();
    if (mounted) setState(() {});
  }

  void _syncSharedVariantsAfterBaseStockChange() {
    if (widget.controllers == null || widget.controllers!.isEmpty) return;
    final int newBaseStock = int.tryParse(widget.sharedStockController.text.trim()) ?? 0;

    for (final c in widget.controllers!) {
      final bool isShared = widget.selectedStrategy == 'COMPARTIDO' ||
          (widget.selectedStrategy == 'MIXTO' && c['usaStockCompartido'] == true);
      if (!isShared) continue;

      final factor = int.tryParse((c['unidadesVenta'] as TextEditingController?)?.text ?? '1') ?? 1;
      final safeFactor = factor <= 0 ? 1 : factor;
      final maxFisico = newBaseStock ~/ safeFactor;

      final stockFinalCtrl = c['stockFinal'] as TextEditingController?;
      if (stockFinalCtrl == null) continue;

      final dynamic rawCupo = c['cupoMaximoVariante'];
      if (rawCupo == null) {
        stockFinalCtrl.text = maxFisico.toString();
      } else {
        final int cupoInt = (rawCupo as num).toInt();
        if (cupoInt > maxFisico) {
          c['cupoMaximoVariante'] = maxFisico;
          stockFinalCtrl.text = maxFisico.toString();
        } else {
          stockFinalCtrl.text = cupoInt.toString();
        }
      }
    }
  }

  StockAdvisorState _evaluateStockAdvisor() {
    if (widget.selectedStrategy != 'COMPARTIDO' && widget.selectedStrategy != 'MIXTO') {
      return StockAdvisorState.hidden;
    }
    if (widget.controllers == null || widget.controllers!.isEmpty) {
      return StockAdvisorState.hidden;
    }

    final sharedItems = widget.controllers!.where((c) {
      if (widget.selectedStrategy == 'COMPARTIDO') return true;
      if (widget.selectedStrategy == 'MIXTO') return c['usaStockCompartido'] == true;
      return false;
    }).toList();

    if (sharedItems.isEmpty) return StockAdvisorState.hidden;

    final int stockBaseTotal = int.tryParse(widget.sharedStockController.text.trim()) ?? 0;
    if (stockBaseTotal <= 0) return StockAdvisorState.hidden;

    // Regla 1: Caso A (Oculto)
    // Si al menos una variante compartida activa divide exactamente las unidades base
    // (stockBaseTotal >= factor && stockBaseTotal % factor == 0)
    final hasExactDivisor = sharedItems.any((c) {
      final factor = int.tryParse((c['unidadesVenta'] as TextEditingController?)?.text ?? '1') ?? 1;
      final safeFactor = factor <= 0 ? 1 : factor;
      return stockBaseTotal >= safeFactor && (stockBaseTotal % safeFactor == 0);
    });

    if (hasExactDivisor) {
      return StockAdvisorState.hidden;
    }

    // Regla 3: Caso C (Obligatorio)
    // Si en TODAS las variantes compartidas stockBaseTotal < factor (0 paquetes vendibles en todas)
    final allZeroFormable = sharedItems.every((c) {
      final factor = int.tryParse((c['unidadesVenta'] as TextEditingController?)?.text ?? '1') ?? 1;
      final safeFactor = factor <= 0 ? 1 : factor;
      return stockBaseTotal < safeFactor;
    });

    if (allZeroFormable) {
      return StockAdvisorState.mandatory;
    }

    // Regla 2: Caso B (Recomendación opcional descartable)
    // Al menos una variante forma >= 1 paquete, pero en todas sobra residuo
    return StockAdvisorState.recommendation;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = isDark ? Colors.blue[300]! : const Color(0xFF1E5BB0);
    final cardBg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final textTheme = Theme.of(context).textTheme;

    final advisorState = _evaluateStockAdvisor();
    final bool showAdvisor = advisorState != StockAdvisorState.hidden;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.hub_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Estrategia de Stock",
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      "Define cómo se descuenta el inventario físico",
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (showAdvisor && _isAdvisorDismissed && advisorState != StockAdvisorState.mandatory)
                InkWell(
                  onTap: () => setState(() => _isAdvisorDismissed = false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.withValues(alpha: 0.25) : const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.purple.withValues(alpha: 0.5) : const Color(0xFFD8B4FE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 13,
                          color: isDark ? Colors.purple[300] : Colors.purple[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Sugerencia unitaria",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.purple[200] : Colors.purple[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector segmentado táctil apilado (Garantizado sin elipsis en 360dp)
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildSegmentOption(
                  title: "Compartido",
                  mode: "COMPARTIDO",
                  icon: Icons.hub_rounded,
                  isDark: isDark,
                ),
                _buildSegmentOption(
                  title: "Independiente",
                  mode: "INDEPENDIENTE",
                  icon: Icons.inventory_2_outlined,
                  isDark: isDark,
                ),
                _buildSegmentOption(
                  title: "Mixto",
                  mode: "MIXTO",
                  icon: Icons.tune_rounded,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Panel contextual según la estrategia seleccionada
          if (widget.selectedStrategy == 'COMPARTIDO' || widget.selectedStrategy == 'MIXTO') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262C3A) : const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue.withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: isDark ? Colors.blue[300] : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.selectedStrategy == 'COMPARTIDO'
                              ? "Inventario base compartido: Todas las presentaciones descontarán de este stock central en unidades base."
                              : "Stock Mixto: Las presentaciones marcadas con 'Compartido' descontarán de este stock.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue[200] : const Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Campos diferenciados según Crear vs. Editar Producto
                  if (!widget.isEditMode) ...[
                    // MODO CREAR PRODUCTO: Stock Base Inicial y Costo Base Unitario
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Stock Base Total *",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: widget.sharedStockController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: "0",
                                  suffixText: "und",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Costo Base Unitario",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: widget.baseCostController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                                ],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                decoration: InputDecoration(
                                  prefixText: "S/ ",
                                  hintText: "0.00",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Chips rápidos ubicados inmediatamente debajo del campo de stock base
                    _buildQuickAddChipsRow(),
                  ] else ...[
                    // MODO EDITAR PRODUCTO: Stock Base Actual + Ingreso = Final + Costo Base
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stock Base Actual
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Stock Base Actual",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                ),
                                child: Text(
                                  "${widget.originalBaseStock ?? 0} und",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // + Ingreso (Nuevas Unidades)
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "+ Ingreso (Nuevas)",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: widget.sharedIngresoController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                onChanged: (val) {
                                  _updateSharedStockFromIngreso();
                                },
                                decoration: InputDecoration(
                                  hintText: "0",
                                  suffixText: "und",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // = Stock Base Final
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "= Stock Final",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.teal[300] : const Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF134E4A).withValues(alpha: 0.5) : const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? Colors.teal.shade700 : const Color(0xFF5EEAD4)),
                                ),
                                child: Text(
                                  "${widget.sharedStockController.text.trim().isEmpty ? '0' : widget.sharedStockController.text} und",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.teal[200] : const Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Chips rápidos ubicados inmediatamente debajo de los campos de stock
                    _buildQuickAddChipsRow(),
                    const SizedBox(height: 10),
                    // Costo Base Unitario en Edición
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Costo Base Unitario",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: widget.baseCostController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                          ],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          decoration: InputDecoration(
                            prefixText: "S/ ",
                            hintText: "0.00",
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Resumen Vivo del Stock Calculado por Variante
                  _buildSharedVariantsSummary(isDark),

                  // Asesor Inteligente de Unidades Sobrantes
                  if (showAdvisor && (!_isAdvisorDismissed || advisorState == StockAdvisorState.mandatory))
                    _buildAdvisorBanner(isDark, advisorState),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers_clear_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Cada variante tiene su propio stock físico independiente. Ingresa el stock en cada tarjeta de presentación abajo.",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updateSharedStockFromIngreso() {
    final orig = widget.originalBaseStock ?? 0;
    final ingreso = int.tryParse(widget.sharedIngresoController?.text.trim() ?? "0") ?? 0;
    widget.sharedStockController.text = (orig + ingreso).toString();
    _syncSharedVariantsAfterBaseStockChange();
    setState(() {});
  }

  Widget _buildSegmentOption({
    required String title,
    required String mode,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = widget.selectedStrategy == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            widget.onStrategyChanged(mode);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2E384D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? Colors.blue[300] : const Color(0xFF1E5BB0))
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddChipsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: _buildQuickAddChip("+10 und", 10)),
          const SizedBox(width: 5),
          Expanded(child: _buildQuickAddChip("+50 und", 50)),
          const SizedBox(width: 5),
          Expanded(child: _buildQuickAddChip("+100 und", 100)),
          const SizedBox(width: 5),
          Expanded(child: _buildQuickAddChip("+500 und", 500)),
        ],
      ),
    );
  }

  Widget _buildQuickAddChip(String label, int amount) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.isEditMode && widget.sharedIngresoController != null) {
          int current = int.tryParse(widget.sharedIngresoController!.text.trim()) ?? 0;
          widget.sharedIngresoController!.text = (current + amount).toString();
          _updateSharedStockFromIngreso();
        } else {
          int current = int.tryParse(widget.sharedStockController.text.trim()) ?? 0;
          widget.sharedStockController.text = (current + amount).toString();
          _syncSharedVariantsAfterBaseStockChange();
          setState(() {});
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white12 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.blue[300] : const Color(0xFF1E5BB0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedVariantsSummary(bool isDark) {
    if (widget.controllers == null || widget.controllers!.isEmpty) {
      return const SizedBox.shrink();
    }

    final int sharedBase = int.tryParse(widget.sharedStockController.text.trim()) ?? 0;

    final sharedItems = widget.controllers!.where((c) {
      if (widget.selectedStrategy == 'COMPARTIDO') return true;
      if (widget.selectedStrategy == 'MIXTO') return c['usaStockCompartido'] == true;
      return false;
    }).toList();

    if (sharedItems.isEmpty) return const SizedBox.shrink();

    final pillWidgets = <Widget>[];
    for (int i = 0; i < sharedItems.length; i++) {
      final c = sharedItems[i];
      final rawName = (c['specific'] as TextEditingController?)?.text.trim() ?? '';
      final uVenta = (c['unidadVenta'] as TextEditingController?)?.text.trim();
      final name = rawName.isNotEmpty ? rawName : (uVenta != null && uVenta.isNotEmpty ? uVenta : 'Var #${i + 1}');
      final factor = int.tryParse((c['unidadesVenta'] as TextEditingController?)?.text ?? '1') ?? 1;
      final safeFactor = factor <= 0 ? 1 : factor;
      final maxFisico = sharedBase ~/ safeFactor;

      int? cupo;
      if (c['cupoMaximoVariante'] != null) {
        cupo = (c['cupoMaximoVariante'] as num).toInt();
      } else {
        final visual = int.tryParse((c['stockFinal'] as TextEditingController?)?.text ?? '') ?? maxFisico;
        if (visual > 0 && visual < maxFisico) cupo = visual;
      }

      final isCapped = cupo != null && cupo >= 0 && cupo < maxFisico;
      final effective = isCapped ? cupo : maxFisico;

      final label = isCapped
          ? '$name (${uVenta ?? "Und"} x$safeFactor): $effective disp. (de $maxFisico máx.)'
          : '$name (${uVenta ?? "Und"} x$safeFactor): $effective disp.';

      pillWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? Colors.blue.withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.blue[200] : const Color(0xFF1E293B),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, size: 13, color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF)),
              const SizedBox(width: 5),
              Text(
                "Stock Final Calculado por Variante:",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue[200] : const Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: pillWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisorBanner(bool isDark, StockAdvisorState state) {
    final bool isMandatory = state == StockAdvisorState.mandatory;
    final int stockBaseTotal = int.tryParse(widget.sharedStockController.text.trim()) ?? 0;

    int minFactor = 999999;
    if (widget.controllers != null) {
      for (final c in widget.controllers!) {
        final bool isShared = widget.selectedStrategy == 'COMPARTIDO' ||
            (widget.selectedStrategy == 'MIXTO' && c['usaStockCompartido'] == true);
        if (isShared) {
          final factor = int.tryParse((c['unidadesVenta'] as TextEditingController?)?.text ?? '1') ?? 1;
          final safeFactor = factor <= 0 ? 1 : factor;
          if (safeFactor < minFactor) minFactor = safeFactor;
        }
      }
    }
    if (minFactor == 999999) minFactor = 1;

    final bannerColor = isMandatory
        ? (isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF2C223E) : const Color(0xFFFAF5FF));

    final borderColor = isMandatory
        ? (isDark ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFFECACA))
        : (isDark ? Colors.purple.withValues(alpha: 0.4) : const Color(0xFFD8B4FE));

    final iconColor = isMandatory
        ? (isDark ? Colors.red[300]! : const Color(0xFFDC2626))
        : (isDark ? Colors.purple[300]! : const Color(0xFF7E22CE));

    final titleColor = isMandatory
        ? (isDark ? Colors.red[200]! : const Color(0xFF991B1B))
        : (isDark ? Colors.purple[200]! : const Color(0xFF581C87));

    final descColor = isMandatory
        ? (isDark ? Colors.grey[300]! : const Color(0xFF7F1D1D))
        : (isDark ? Colors.grey[300]! : const Color(0xFF4C1D95));

    final btnColor = isMandatory
        ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFB91C1C))
        : (isDark ? const Color(0xFF7E22CE) : const Color(0xFF9333EA));

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMandatory ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isMandatory
                      ? "Asesor de Stock: Acción requerida (Stock insuficiente)"
                      : "Asesor de Stock: Evita unidades sobrantes",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              if (!isMandatory)
                InkWell(
                  onTap: () => setState(() => _isAdvisorDismissed = true),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isMandatory
                ? "Tienes $stockBaseTotal und. base, pero tu paquete más pequeño requiere $minFactor und. Con este inventario no se puede vender ningún paquete. Crea la variante por Unidad para venderlas o aumenta el stock base."
                : "Tienes $stockBaseTotal und. base. Al vender por paquetes o pares, sobrarán unidades sueltas que no podrás liquidar. Agrega una variante por Unidad para venderlas individualmente.",
            style: TextStyle(
              fontSize: 11.5,
              color: descColor,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onAutoCreateUnitVariant?.call();
              },
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
              label: const Text(
                "Crear variante por Unidad automáticamente",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

