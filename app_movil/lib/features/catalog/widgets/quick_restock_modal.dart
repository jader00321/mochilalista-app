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
  
  // Granularidad: 0 = Por Unidad de Venta (xFactor), 1 = Por Unidad Base (x1)
  int _unitGranularity = 0;

  final TextEditingController _qtyCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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

  int get _currentStockBase => widget.presentation.stockActual;

  int get _currentStockSalesUnits => _currentStockBase ~/ _factor;

  int get _currentStockRemainder => _currentStockBase % _factor;

  int get _parsedInput => int.tryParse(_qtyCtrl.text.trim()) ?? 0;

  int get _calculatedNewStockBase {
    if (_selectedMode == 0) {
      // Sumar nuevo stock
      if (_unitGranularity == 0 && _hasFactor) {
        return _currentStockBase + (_parsedInput * _factor);
      } else {
        return _currentStockBase + _parsedInput;
      }
    } else {
      // Fijar stock exacto
      if (_unitGranularity == 0 && _hasFactor) {
        return _parsedInput * _factor;
      } else {
        return _parsedInput;
      }
    }
  }

  int get _calculatedNewStockSalesUnits => _calculatedNewStockBase ~/ _factor;

  int get _calculatedNewStockRemainder => _calculatedNewStockBase % _factor;

  void _onModeChanged(int mode) {
    if (_selectedMode == mode) return;
    setState(() {
      _selectedMode = mode;
      if (mode == 0) {
        _qtyCtrl.text = "1";
      } else {
        if (_unitGranularity == 0 && _hasFactor) {
          _qtyCtrl.text = _currentStockSalesUnits.toString();
        } else {
          _qtyCtrl.text = _currentStockBase.toString();
        }
      }
    });
  }

  void _onGranularityChanged(int gran) {
    if (_unitGranularity == gran) return;
    setState(() {
      _unitGranularity = gran;
      if (_selectedMode == 0) {
        _qtyCtrl.text = gran == 0 ? "1" : _factor.toString();
      } else {
        _qtyCtrl.text = gran == 0
            ? _currentStockSalesUnits.toString()
            : _currentStockBase.toString();
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

  void _squareToExactMultiple(int targetMultipleBase) {
    setState(() {
      if (_selectedMode == 0) {
        int diff = targetMultipleBase - _currentStockBase;
        if (diff < 0) diff = 0;
        if (_unitGranularity == 0 && _hasFactor) {
          _qtyCtrl.text = (diff / _factor).ceil().toString();
        } else {
          _qtyCtrl.text = diff.toString();
        }
      } else {
        if (_unitGranularity == 0 && _hasFactor) {
          _qtyCtrl.text = (targetMultipleBase ~/ _factor).toString();
        } else {
          _qtyCtrl.text = targetMultipleBase.toString();
        }
      }
    });
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
        final summaryMsg = _hasFactor
            ? "Stock actualizado: $_calculatedNewStockSalesUnits $_unidadVenta ($newStockBase u. base)"
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

    final isOddStock = _hasFactor && (_calculatedNewStockRemainder != 0);
    final nextMultipleBase = ((_calculatedNewStockBase ~/ _factor) + 1) * _factor;
    final targetSalesUnits = nextMultipleBase ~/ _factor;

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
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _onGranularityChanged(0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _unitGranularity == 0
                                ? (isDark ? const Color(0xFF2C324A) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _unitGranularity == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.all_inbox,
                                size: 14,
                                color: _unitGranularity == 0
                                    ? Colors.blue[400]
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Por $_unidadVenta (x$_factor)",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _unitGranularity == 0
                                      ? (isDark ? Colors.blue[300] : Colors.blue[900])
                                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _onGranularityChanged(1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _unitGranularity == 1
                                ? (isDark ? const Color(0xFF2C324A) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _unitGranularity == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.format_list_numbered,
                                size: 14,
                                color: _unitGranularity == 1
                                    ? Colors.blue[400]
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Por Unidad base (x1)",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _unitGranularity == 1
                                      ? (isDark ? Colors.blue[300] : Colors.blue[900])
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
                          _unitGranularity == 0
                              ? "$_unidadVenta\n(+${_parsedInput * _factor} u.)"
                              : "Unidades base\n(+$_parsedInput u.)",
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
                          _calculatedNewStockRemainder > 0
                              ? "$_unidadVenta (+${_calculatedNewStockRemainder}u)\n($_calculatedNewStockBase u.)"
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

            // Alerta inteligente de stock impar y botón de cuadratura rápida
            if (isOddStock) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange[400]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Stock con residuo impar: $_calculatedNewStockBase u. equivalen a ${(_calculatedNewStockBase / _factor).toStringAsFixed(1)} $_unidadVenta. Quedan $_calculatedNewStockRemainder u. suelta(s) fuera de empaque.",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.orange[200] : Colors.orange[900],
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _squareToExactMultiple(nextMultipleBase),
                        icon: const Icon(Icons.bolt, size: 16),
                        label: Text(
                          "Cuadrar a $targetSalesUnits $_unidadVenta ($nextMultipleBase u.)",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.orange[300] : Colors.orange[800],
                          side: BorderSide(
                            color: isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade400,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Campo de entrada y botones de incremento rápido
            Text(
              _selectedMode == 0
                  ? (_hasFactor && _unitGranularity == 0
                      ? "Cantidad de ${_unidadVenta}s compradas / recibidas:"
                      : "Cantidad de unidades compradas / recibidas:")
                  : (_hasFactor && _unitGranularity == 0
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
