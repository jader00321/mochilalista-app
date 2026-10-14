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

  int get _currentStock => widget.presentation.stockActual;

  int get _parsedInput => int.tryParse(_qtyCtrl.text.trim()) ?? 0;

  int get _calculatedNewStock {
    if (_selectedMode == 0) {
      // Sumar nuevo stock
      return _currentStock + _parsedInput;
    } else {
      // Fijar stock exacto
      return _parsedInput;
    }
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
    final newStock = _calculatedNewStock;
    if (newStock < 0) {
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
        stock: newStock,
      );

      if (!mounted) return;

      if (success) {
        CustomSnackBar.show(
          context,
          message: "Stock actualizado: $newStock unidades disponibles",
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

    final factorVenta = widget.presentation.unidadesPorVenta;
    final variantLabel = widget.presentation.nombreEspecifico != null &&
            widget.presentation.nombreEspecifico!.isNotEmpty
        ? widget.presentation.nombreEspecifico!
        : "${widget.presentation.unidadVenta ?? 'Unidad'} (x$factorVenta)";

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

            const SizedBox(height: 20),

            // Selector de modo (Sumar compra recibida vs Fijar exacto)
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
                      onTap: () {
                        setState(() {
                          _selectedMode = 0;
                          _qtyCtrl.text = "1";
                        });
                      },
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
                      onTap: () {
                        setState(() {
                          _selectedMode = 1;
                          _qtyCtrl.text = _currentStock.toString();
                        });
                      },
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

            const SizedBox(height: 20),

            // Tarjeta de balance y comparativa
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
                        "$_currentStock",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _currentStock <= 5
                              ? (isDark ? Colors.orange[300] : Colors.orange[800])
                              : textColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _selectedMode == 0 ? Icons.add_circle_outline : Icons.arrow_forward_rounded,
                    color: Colors.blue[400],
                    size: 24,
                  ),
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
                    ],
                  ),
                  const Text("=", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                        "$_calculatedNewStock",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.green[300] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Campo de entrada y botones de incremento rápido
            Text(
              _selectedMode == 0
                  ? "Cantidad de unidades compradas / recibidas:"
                  : "Nuevo stock total disponible:",
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
