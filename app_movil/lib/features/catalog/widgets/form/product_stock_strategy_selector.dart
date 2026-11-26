import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'stock_strategy/product_stock_strategy_inputs.dart';
part 'stock_strategy/product_stock_strategy_advisor.dart';

enum StockAdvisorState { hidden, recommendation, mandatory }

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
  final Key? baseCostKey;

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
    this.baseCostKey,
  });

  @override
  State<ProductStockStrategySelector> createState() =>
      _ProductStockStrategySelectorState();
}

class _ProductStockStrategySelectorState
    extends State<ProductStockStrategySelector> {
  bool _isAdvisorDismissed = false;

  void _updateState([VoidCallback? fn]) {
    if (!mounted) return;
    setState(fn ?? () {});
  }

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
      oldWidget.sharedIngresoController?.removeListener(
        _onSharedIngresoChanged,
      );
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
    _updateState();
  }

  void _onSharedStockChanged() {
    _syncSharedVariantsAfterBaseStockChange();
    _updateState();
  }

  void _updateSharedStockFromIngreso() {
    final orig = widget.originalBaseStock ?? 0;
    final ingreso =
        int.tryParse(widget.sharedIngresoController?.text.trim() ?? "0") ?? 0;
    widget.sharedStockController.text = (orig + ingreso).toString();
    _syncSharedVariantsAfterBaseStockChange();
    _updateState();
  }

  void _syncSharedVariantsAfterBaseStockChange() {
    if (widget.controllers == null || widget.controllers!.isEmpty) return;
    final int newBaseStock =
        int.tryParse(widget.sharedStockController.text.trim()) ?? 0;

    for (final c in widget.controllers!) {
      final bool isShared =
          widget.selectedStrategy == 'COMPARTIDO' ||
          (widget.selectedStrategy == 'MIXTO' &&
              c['usaStockCompartido'] == true);
      if (!isShared) continue;

      final factor =
          int.tryParse(
            (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
          ) ??
          1;
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
    if (widget.selectedStrategy != 'COMPARTIDO' &&
        widget.selectedStrategy != 'MIXTO') {
      return StockAdvisorState.hidden;
    }
    if (widget.controllers == null || widget.controllers!.isEmpty) {
      return StockAdvisorState.hidden;
    }

    final sharedItems = widget.controllers!.where((c) {
      if (widget.selectedStrategy == 'COMPARTIDO') return true;
      if (widget.selectedStrategy == 'MIXTO') {
        return c['usaStockCompartido'] == true;
      }
      return false;
    }).toList();

    if (sharedItems.isEmpty) return StockAdvisorState.hidden;

    final int stockBaseTotal =
        int.tryParse(widget.sharedStockController.text.trim()) ?? 0;
    if (stockBaseTotal <= 0) return StockAdvisorState.hidden;

    final hasExactDivisor = sharedItems.any((c) {
      final factor =
          int.tryParse(
            (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
          ) ??
          1;
      final safeFactor = factor <= 0 ? 1 : factor;
      return stockBaseTotal >= safeFactor && (stockBaseTotal % safeFactor == 0);
    });

    if (hasExactDivisor) return StockAdvisorState.hidden;

    final allZeroFormable = sharedItems.every((c) {
      final factor =
          int.tryParse(
            (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
          ) ??
          1;
      final safeFactor = factor <= 0 ? 1 : factor;
      return stockBaseTotal < safeFactor;
    });

    if (allZeroFormable) return StockAdvisorState.mandatory;
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
              if (showAdvisor &&
                  _isAdvisorDismissed &&
                  advisorState != StockAdvisorState.mandatory) ...[
                const SizedBox(width: 6),
                _buildAdvisorHeaderBadge(isDark),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
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
          if (widget.selectedStrategy == 'COMPARTIDO' ||
              widget.selectedStrategy == 'MIXTO')
            _buildSharedStrategyContainer(isDark, advisorState, showAdvisor)
          else
            _buildIndependentInfoBox(isDark),
        ],
      ),
    );
  }

  Widget _buildSharedStrategyContainer(
    bool isDark,
    StockAdvisorState advisorState,
    bool showAdvisor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262C3A) : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.blue.withValues(alpha: 0.3)
              : const Color(0xFFBFDBFE),
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
          if (!widget.isEditMode) ...[
            _buildCreateStockInputs(isDark),
            const SizedBox(height: 8),
            _buildQuickAddChipsRow(),
          ] else ...[
            _buildEditStockInputs(isDark),
            const SizedBox(height: 8),
            _buildQuickAddChipsRow(),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: widget.baseCostKey,
              child: _buildBaseCostField(isDark),
            ),
          ],
          _buildSharedVariantsSummary(isDark),
          if (showAdvisor &&
              (!_isAdvisorDismissed ||
                  advisorState == StockAdvisorState.mandatory))
            _buildAdvisorBanner(isDark, advisorState),
        ],
      ),
    );
  }
}
