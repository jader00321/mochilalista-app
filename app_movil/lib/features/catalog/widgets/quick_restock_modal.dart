import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class QuickRestockModal extends StatefulWidget {
  final Product product;
  final ProductPresentation presentation;
  final VoidCallback onRestockSuccess;
  final VoidCallback onNavigateToFullEdit;
  final bool isDark;

  const QuickRestockModal({
    super.key,
    required this.product,
    required this.presentation,
    required this.onRestockSuccess,
    required this.onNavigateToFullEdit,
    required this.isDark,
  });

  @override
  State<QuickRestockModal> createState() => _QuickRestockModalState();
}

class _QuickRestockModalState extends State<QuickRestockModal> {
  // Modo: 0 = Sumar mercancía recibida, 1 = Fijar stock total exacto
  int _selectedMode = 0;

  final TextEditingController _qtyCtrl = TextEditingController();
  bool _isSaving = false;
  late int _currentStockBase;

  @override
  void initState() {
    super.initState();
    _currentStockBase = widget.presentation.stockActual;
    _qtyCtrl.text = "1";
    _qtyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  int get _factor => widget.presentation.unidadesPorVenta > 0
      ? widget.presentation.unidadesPorVenta
      : 1;

  String get _unidadVenta => widget.presentation.unidadVenta ?? 'Unidad';

  bool get _hasFactor => _factor > 1;

  int get _currentStockSalesUnits => _currentStockBase ~/ _factor;

  int get _currentStockRemainder => _currentStockBase % _factor;

  int get _parsedInput => int.tryParse(_qtyCtrl.text.trim()) ?? 0;

  int get _calculatedNewStockBase {
    if (_selectedMode == 0) {
      // Sumar nuevo stock
      return _currentStockBase + (_parsedInput * _factor);
    } else {
      // Fijar stock exacto
      return _parsedInput * _factor;
    }
  }

  int get _calculatedNewStockSalesUnits => _calculatedNewStockBase ~/ _factor;

  void _onModeChanged(int mode) {
    if (_selectedMode == mode) return;
    setState(() {
      _selectedMode = mode;
      if (mode == 0) {
        _qtyCtrl.text = "1";
      } else {
        _qtyCtrl.text = _currentStockSalesUnits.toString();
      }
    });
  }

  void _squareStock() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStockBase = (_currentStockBase ~/ _factor) * _factor;
      if (_selectedMode == 1) {
        _qtyCtrl.text = (_currentStockBase ~/ _factor).toString();
      }
    });
  }

  void _addQuickAmount(int amount) {
    int current = _parsedInput;
    if (_selectedMode == 0) {
      _qtyCtrl.text = (current + amount).clamp(1, 99999).toString();
    } else {
      _qtyCtrl.text = (current + amount).clamp(0, 99999).toString();
    }
  }

  Future<void> _submitRestock() async {
    final newStockBase = _calculatedNewStockBase;
    if (newStockBase < 0) {
      CustomSnackBar.show(context, message: "El stock no puede ser negativo", isError: true);
      return;
    }

    if (widget.presentation.id == null) {
      CustomSnackBar.show(context, message: "La presentación seleccionada no tiene ID válido", isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final invProvider = Provider.of<InventoryProvider>(context, listen: false);

    try {
      final success = await invProvider.updatePresentation(
        widget.presentation.id!,
        stock: newStockBase,
      );

      if (!mounted) return;

      if (success) {
        final remainder = newStockBase % _factor;
        final summaryMsg = _hasFactor
            ? (remainder > 0
                ? "Stock actualizado: $_calculatedNewStockSalesUnits $_unidadVenta (+ $remainder u. base suelta) = $newStockBase unidades base"
                : "Stock actualizado: $_calculatedNewStockSalesUnits $_unidadVenta = $newStockBase unidades base")
            : "Stock actualizado: $newStockBase unidades disponibles";

        CustomSnackBar.show(
          context,
          message: summaryMsg,
          isError: false,
        );
        widget.onRestockSuccess();
        Navigator.pop(context);
      } else {
        CustomSnackBar.show(context, message: "Error al actualizar el stock", isError: true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: "Error: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF1A1A24) : Colors.grey[100]!;

    final variantLabel = widget.presentation.nombreEspecifico != null &&
            widget.presentation.nombreEspecifico!.isNotEmpty
        ? widget.presentation.nombreEspecifico!
        : "$_unidadVenta (x$_factor)";

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asa de agarre
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_business, color: Colors.blue[400], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Abastecer / Editar Stock",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.product.nombre} · $variantLabel",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Selector de modo principal (Sumar compra recibida vs Fijar exacto)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedMode == 0
                              ? (isDark ? Colors.blue[800] : Colors.blue)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Sumar Compra Recibida",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedMode == 0
                                ? Colors.white
                                : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _onModeChanged(1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedMode == 1
                              ? (isDark ? Colors.blue[800] : Colors.blue)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Fijar Stock Exacto",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedMode == 1
                                ? Colors.white
                                : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selector secundario de granularidad (Solo si factor > 1)
            if (_hasFactor) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Unidad de ingreso:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue[800] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 13, color: isDark ? Colors.white : Colors.blue[900]),
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
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onNavigateToFullEdit();
                              },
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

            const SizedBox(height: 16),

            // Tarjeta de balance y comparativa dual inteligente
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Stock Actual
                  Column(
                    children: [
                      Text(
                        "Stock Actual",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hasFactor
                            ? "$_currentStockSalesUnits"
                            : "$_currentStockBase",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _currentStockBase <= 5
                              ? (isDark ? Colors.orange[300] : Colors.orange[800])
                              : textColor,
                        ),
                      ),
                      if (_hasFactor)
                        Text(
                          _currentStockRemainder > 0
                              ? "$_unidadVenta (+${_currentStockRemainder}u)\n($_currentStockBase u.)"
                              : "$_unidadVenta\n($_currentStockBase u.)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                  Icon(
                    _selectedMode == 0 ? Icons.add_circle_outline : Icons.arrow_forward_rounded,
                    color: Colors.blue[400],
                    size: 24,
                  ),
                  // Nuevo Ingreso / Ajuste
                  Column(
                    children: [
                      Text(
                        _selectedMode == 0 ? "Nuevo Ingreso" : "Ajuste",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[400],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedMode == 0 ? "+$_parsedInput" : "$_parsedInput",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue[400],
                        ),
                      ),
                      if (_hasFactor)
                        Text(
                          "$_unidadVenta\n(+${_parsedInput * _factor} u.)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[300],
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                  const Text("=", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
                  // Stock Resultante
                  Column(
                    children: [
                      Text(
                        "Stock Resultante",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.green[300] : Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hasFactor
                            ? "$_calculatedNewStockSalesUnits"
                            : "$_calculatedNewStockBase",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.green[300] : Colors.green[700],
                        ),
                      ),
                      if (_hasFactor)
                        Text(
                          _calculatedNewStockBase % _factor > 0
                              ? "$_unidadVenta (+${_calculatedNewStockBase % _factor}u)\n($_calculatedNewStockBase u.)"
                              : "$_unidadVenta\n($_calculatedNewStockBase u.)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.green[300] : Colors.green[700],
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Campo de entrada y botones de incremento rápido
            Text(
              _selectedMode == 0
                  ? (_hasFactor
                      ? "Cantidad de ${_unidadVenta}s compradas / recibidas:"
                      : "Cantidad de unidades compradas / recibidas:")
                  : (_hasFactor
                      ? "Nuevo stock total disponible (en ${_unidadVenta}s):"
                      : "Nuevo stock total disponible (en unidades base):"),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () {
                    if (_parsedInput > 0) {
                      _qtyCtrl.text = (_parsedInput - 1).toString();
                    }
                  },
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {
                    _qtyCtrl.text = (_parsedInput + 1).toString();
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Chips de incremento rápido
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickChip("+1", 1, isDark),
                _buildQuickChip("+5", 5, isDark),
                _buildQuickChip("+10", 10, isDark),
                _buildQuickChip("+20", 20, isDark),
                _buildQuickChip("+50", 50, isDark),
                _buildQuickChip("+100", 100, isDark),
              ],
            ),

            const SizedBox(height: 24),

            // Botón de confirmación
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitRestock,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 22),
                label: Text(
                  _isSaving ? "Guardando..." : "Confirmar y Actualizar Stock",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Enlace de edición completa
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onNavigateToFullEdit();
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text(
                  "Ir a edición completa del producto (precios, costos, etc.)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, int amount, bool isDark) {
    return InkWell(
      onTap: () => _addQuickAmount(amount),
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
