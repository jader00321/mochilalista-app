import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class StockUpdateModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;
  
  const StockUpdateModal({
    super.key, 
    required this.presentation, 
    required this.provider, 
    required this.isDark
  });

  /// 🏆 Despliegue con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<bool?> show({
    required BuildContext context,
    required ProductPresentation presentation,
    required InventoryProvider provider,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show<bool>(
      context: context,
      builder: (ctx) => StockUpdateModal(
        presentation: presentation,
        provider: provider,
        isDark: isDark,
      ),
    );
  }

  @override
  State<StockUpdateModal> createState() => _StockUpdateModalState();
}

class _StockUpdateModalState extends State<StockUpdateModal> {
  // Modo: 0 = Sumar mercancía recibida, 1 = Fijar stock total exacto
  int _selectedMode = 1;

  late TextEditingController ctrl;
  bool _isSaving = false;
  late int _currentStockBase;

  int get _factor => widget.presentation.unidadesPorVenta > 0
      ? widget.presentation.unidadesPorVenta
      : 1;

  String get _unidadVenta => widget.presentation.unidadVenta ?? 'Unidad';

  bool get _hasFactor => _factor > 1;

  int get _currentStockSalesUnits => _currentStockBase ~/ _factor;

  int get _currentStockRemainder => _currentStockBase % _factor;

  int get _parsedInput => int.tryParse(ctrl.text.trim()) ?? 0;

  int get _calculatedNewStockBase {
    if (_selectedMode == 0) {
      return _currentStockBase + (_parsedInput * _factor);
    } else {
      return _parsedInput * _factor;
    }
  }

  int get _calculatedNewStockSalesUnits => _calculatedNewStockBase ~/ _factor;

  @override
  void initState() {
    super.initState();
    _currentStockBase = widget.presentation.stockActual;
    final initialStock = _selectedMode == 0 ? 1 : _currentStockSalesUnits;
    ctrl = TextEditingController(text: initialStock.toString());
    ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _onModeChanged(int mode) {
    if (_selectedMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMode = mode;
      if (mode == 0) {
        ctrl.text = "1";
      } else {
        ctrl.text = _currentStockSalesUnits.toString();
      }
    });
  }

  void _squareStock() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStockBase = (_currentStockBase ~/ _factor) * _factor;
      if (_selectedMode == 1) {
        ctrl.text = (_currentStockBase ~/ _factor).toString();
      }
    });
  }

  void _navigateToEdit() {
    final nav = Navigator.of(context);
    nav.pop();
    Product? targetProduct;
    for (final item in widget.provider.items) {
      if (item.presentation.id == widget.presentation.id) {
        targetProduct = item.product;
        break;
      }
    }
    if (targetProduct != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ProductEditScreen(
            productToEdit: targetProduct!,
            initialPresentationId: widget.presentation.id,
          ),
        ),
      );
    }
  }

  void _update(int val) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedMode == 0) {
        ctrl.text = val < 1 ? "1" : val.toString();
      } else {
        ctrl.text = val < 0 ? "0" : val.toString();
      }
    });
  }

  void _addQuickAmount(int amount) {
    _update(_parsedInput + amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final int resultingBase = _calculatedNewStockBase;
    final int resultingSalesUnits = _calculatedNewStockSalesUnits;

    final bool isOutOfStock = resultingBase <= 0;
    final bool isCritical = resultingBase > 0 && resultingSalesUnits <= (widget.presentation.stockAlerta ?? 5);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      applyEffectiveBottomPadding: true,
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDark ? Colors.blue[300] : Colors.blue[800], 
            foregroundColor: widget.isDark ? Colors.black87 : Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: _isSaving ? null : () async {
            setState(() => _isSaving = true);
            final ok = await widget.provider.updatePresentation(
              widget.presentation.id!,
              stock: resultingBase,
            );
            if (context.mounted) Navigator.pop(context, ok);
          },
          child: _isSaving 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Text("APLICAR CAMBIOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, isKeyboardOpen ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (widget.isDark ? Colors.blue[300]! : Colors.blue[800]!).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.inventory_2_outlined, color: widget.isDark ? Colors.blue[300] : Colors.blue[800], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Abastecer / Editar Stock", 
                      style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 18),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.isDark ? Colors.grey[500] : Colors.grey), 
                  onPressed: () => Navigator.pop(context), 
                  padding: EdgeInsets.zero, 
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selector de Modo (Sumar vs Fijar)
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _onModeChanged(0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedMode == 0
                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedMode == 0
                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_business_rounded,
                              size: 16,
                              color: _selectedMode == 0
                                  ? (isDark ? Colors.blue[300] : Colors.blue[800])
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Sumar Compra",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedMode == 0
                                    ? (isDark ? Colors.blue[300] : Colors.blue[800])
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => _onModeChanged(1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedMode == 1
                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedMode == 1
                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                              color: _selectedMode == 1
                                  ? (isDark ? Colors.teal[300] : Colors.teal[800])
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Fijar Stock Total",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedMode == 1
                                    ? (isDark ? Colors.teal[300] : Colors.teal[800])
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selector de Granularidad Factor-Aware (si factor > 1)
            if (_hasFactor) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.indigo[900]! : Colors.indigo[50]!).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (isDark ? Colors.indigo[400]! : Colors.indigo.shade200).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Unidad de ingreso:",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.indigo[200] : Colors.indigo[900]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue[800] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12, color: isDark ? Colors.white : Colors.blue[900]),
                          const SizedBox(width: 4),
                          Text(
                            "Por $_unidadVenta (x$_factor)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Banner Inteligente Condicional de Unidades Residuales
              if (_currentStockRemainder > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.amber[900]!.withValues(alpha: 0.25) : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.amber[400]! : Colors.amber[800]!,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: isDark ? Colors.amber[300]! : Colors.amber[900]!,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Hay $_currentStockRemainder u. base suelta(s) que no completan un $_unidadVenta (x$_factor).${_selectedMode == 1 ? ' Al fijar stock total, esas unidades sueltas se reemplazarán por el nuevo total exacto.' : ' Al sumar compra se conservarán intactas.'}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.amber[200] : Colors.amber[900],
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                side: BorderSide(color: isDark ? Colors.amber[400]! : Colors.amber[800]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _navigateToEdit,
                              icon: const Icon(Icons.build_outlined, size: 13),
                              label: const Text(
                                "🛠️ Ir a Editar",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.amber[700] : Colors.amber[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: _squareStock,
                              icon: const Icon(Icons.flash_on, size: 13),
                              label: const Text(
                                "⚡ Cuadrar aquí",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],

            SizedBox(height: isKeyboardOpen ? 12 : 20),
            
            // Stepper y TextField central
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(color: widget.isDark ? Colors.white10 : Colors.grey[200], shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: () => _update(_parsedInput - 1), 
                    icon: const Icon(Icons.remove), 
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Container(
                  width: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: ctrl,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[100], shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: () => _update(_parsedInput + 1), 
                    icon: const Icon(Icons.add), 
                    color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Chips rápidos
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (_selectedMode == 1) _buildChip("-5", -5, isDark),
                  _buildChip("+1", 1, isDark),
                  _buildChip("+5", 5, isDark),
                  _buildChip("+10", 10, isDark),
                  _buildChip("+50", 50, isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Preview del Stock Resultante (Verdad Contable)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOutOfStock
                    ? (widget.isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red[50])
                    : (isCritical
                        ? (widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50])
                        : (widget.isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50])),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOutOfStock
                      ? (widget.isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade300)
                      : (isCritical
                          ? (widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade300)
                          : (widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade300)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOutOfStock
                            ? Icons.error_outline
                            : (isCritical ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                        size: 16,
                        color: isOutOfStock
                            ? (widget.isDark ? Colors.red[300] : Colors.red)
                            : (isCritical
                                ? (widget.isDark ? Colors.orange[300] : Colors.orange)
                                : (widget.isDark ? Colors.green[400] : Colors.green)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOutOfStock ? "¡Quedará Agotado!" : (isCritical ? "Stock Bajo" : "Stock Saludable"),
                        style: TextStyle(
                          color: isOutOfStock
                              ? (widget.isDark ? Colors.red[300] : Colors.red)
                              : (isCritical
                                  ? (widget.isDark ? Colors.orange[300] : Colors.orange)
                                  : (widget.isDark ? Colors.green[400] : Colors.green)),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasFactor
                        ? (resultingBase % _factor == 0
                            ? "Resultado: $resultingSalesUnits $_unidadVenta = $resultingBase unidades base"
                            : "Resultado: $resultingSalesUnits $_unidadVenta (+ ${resultingBase % _factor} u. base suelta) = $resultingBase unidades base")
                        : "Resultado: $resultingBase unidades disponibles",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int delta, bool isDark) {
    return InkWell(
      onTap: () => _addQuickAmount(delta),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}
