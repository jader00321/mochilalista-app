import 'package:flutter/material.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_custom_field.dart';

/// Sección de Inventario y Control de Stock para la tarjeta de presentación.
/// Incluye inputs de stock inicial, ingreso, stock final calculado,
/// ajustes por ventas previas o forzado de base, y banner reactivo de residuos/sobrantes.
class PresentationStockSection extends StatefulWidget {
  final TextEditingController stockInicialCtrl;
  final TextEditingController nuevoIngresoCtrl;
  final TextEditingController stockDescuentoCtrl;
  final TextEditingController stockFinalCtrl;
  final TextEditingController ajusteBaseCtrl;
  final TextEditingController unidadVentaCtrl;
  final TextEditingController unidadesVentaCtrl;
  final TextEditingController specificCtrl;
  final bool isEditMode;
  final int originalBaseStock;
  final bool leftoverCreated;
  final StockValidationResult stockValidation;
  final double costoBaseParaSobrante;
  final bool isDark;
  final VoidCallback onStockChanged;
  final VoidCallback onAjusteBaseChanged;
  final void Function(int leftoverUnits, double costoBaseIndiv)? onCreateLeftover;

  const PresentationStockSection({
    super.key,
    required this.stockInicialCtrl,
    required this.nuevoIngresoCtrl,
    required this.stockDescuentoCtrl,
    required this.stockFinalCtrl,
    required this.ajusteBaseCtrl,
    required this.unidadVentaCtrl,
    required this.unidadesVentaCtrl,
    required this.specificCtrl,
    required this.isEditMode,
    required this.originalBaseStock,
    required this.leftoverCreated,
    required this.stockValidation,
    required this.costoBaseParaSobrante,
    required this.isDark,
    required this.onStockChanged,
    required this.onAjusteBaseChanged,
    this.onCreateLeftover,
  });

  @override
  State<PresentationStockSection> createState() =>
      _PresentationStockSectionState();
}

class _PresentationStockSectionState extends State<PresentationStockSection> {
  bool _mostrarAjusteStock = false;
  bool _mostrarAjusteBase = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final unidadLabel = widget.unidadVentaCtrl.text.isNotEmpty
        ? widget.unidadVentaCtrl.text
        : 'Uds';

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.green.withValues(alpha: 0.05)
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.green.shade100,
              ),
            ),
            child: Column(
              children: [
                if (widget.isEditMode) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: isDark
                            ? Colors.green[300]
                            : Colors.green[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.leftoverCreated
                              ? "Stock actual: ${widget.originalBaseStock} unidades base (Sobrante extraído)"
                              : "Stock actual: ${widget.originalBaseStock} unidades base",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.green[300]
                                : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: MiniInput(
                        ctrl: widget.stockInicialCtrl,
                        label: widget.isEditMode
                            ? "Stock Sistema"
                            : "Inicial (Sueltas)",
                        isNum: true,
                        hint: "0",
                        isDark: isDark,
                        onChanged: widget.onStockChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: MiniInput(
                        ctrl: widget.nuevoIngresoCtrl,
                        label: "+ Ingreso",
                        isNum: true,
                        hint: "0",
                        isDark: isDark,
                        onChanged: widget.onStockChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: MiniInput(
                        ctrl: widget.stockFinalCtrl,
                        label: "= Final ($unidadLabel)",
                        isNum: true,
                        hint: "0",
                        isBold: true,
                        isDark: isDark,
                        onChanged: widget.onStockChanged,
                      ),
                    ),
                  ],
                ),
                if (!widget.isEditMode) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: isDark
                            ? Colors.blue[300]
                            : Colors.blue[700],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "El stock unitario, ingreso y ajuste operan en unidades sueltas físicas.",
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.blue[300]
                                : Colors.blue[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _mostrarAjusteStock = !_mostrarAjusteStock),
                    icon: Icon(
                      Icons.settings_suggest,
                      size: 16,
                      color: isDark
                          ? Colors.green[400]
                          : Colors.green[700],
                    ),
                    label: Text(
                      "Ajuste por ventas previas",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.green[400]
                            : Colors.green[700],
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _mostrarAjusteStock
                      ? Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(child: Container()),
                              Expanded(
                                flex: 3,
                                child: MiniInput(
                                  ctrl: widget.stockDescuentoCtrl,
                                  label: widget.isEditMode
                                      ? "- Ajuste Ventas Previas"
                                      : "- Ajuste (Sueltas)",
                                  isNum: true,
                                  hint: "0",
                                  isDark: isDark,
                                  onChanged: widget.onStockChanged,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (widget.isEditMode) ...[
                  const Divider(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _mostrarAjusteBase = !_mostrarAjusteBase,
                      ),
                      icon: Icon(
                        Icons.settings,
                        size: 16,
                        color: isDark
                            ? Colors.orange[400]
                            : Colors.orange[700],
                      ),
                      label: Text(
                        "Ajustar Unidades Reales",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.orange[400]
                              : Colors.orange[700],
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _mostrarAjusteBase
                        ? Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.orange.shade50,
                              border: Border.all(
                                color: isDark
                                    ? Colors.orange.withValues(alpha: 0.3)
                                    : Colors.orange.shade200,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "⚠️ Sobre-escribe el cálculo automático de stock.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.orange[300]
                                        : Colors.orange[800],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: MiniInput(
                                        ctrl: widget.ajusteBaseCtrl,
                                        label: "Forzar Unidades Base",
                                        isNum: true,
                                        hint: "Ej: 26",
                                        isDark: isDark,
                                        onChanged: widget.onAjusteBaseChanged,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 🔥 ALERTA DE RESIDUO (INTELIGENTE)
          if (widget.stockValidation.status ==
                  StockValidationStatus.hasLeftover ||
              widget.stockValidation.status ==
                  StockValidationStatus.deficit) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: widget.stockValidation.status ==
                        StockValidationStatus.deficit
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.stockValidation.status ==
                          StockValidationStatus.deficit
                      ? Colors.red.shade300
                      : Colors.orange.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.stockValidation.status ==
                                StockValidationStatus.deficit
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        color: widget.stockValidation.status ==
                                StockValidationStatus.deficit
                            ? Colors.red
                            : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.stockValidation.userMessage(
                            widget.unidadVentaCtrl.text,
                            int.tryParse(widget.unidadesVentaCtrl.text) ?? 1,
                          ),
                          style: TextStyle(
                            color: isDark
                                ? (widget.stockValidation.status ==
                                        StockValidationStatus.deficit
                                    ? Colors.red[300]
                                    : Colors.orange[300])
                                : (widget.stockValidation.status ==
                                        StockValidationStatus.deficit
                                    ? Colors.red[900]
                                    : Colors.orange[900]),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.stockValidation.status ==
                      StockValidationStatus.hasLeftover) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.leftoverCreated
                            ? null
                            : () {
                                if (widget.onCreateLeftover != null) {
                                  widget.onCreateLeftover!(
                                    widget.stockValidation.leftover,
                                    widget.costoBaseParaSobrante,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.leftoverCreated
                              ? Colors.green
                              : (isDark
                                  ? Colors.orange[800]
                                  : Colors.orange),
                          foregroundColor: Colors.white,
                          elevation: widget.leftoverCreated ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        icon: Icon(
                          widget.leftoverCreated
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          size: 20,
                        ),
                        label: Text(
                          widget.leftoverCreated
                              ? "Variante sobrante creada"
                              : "Crear variante '${widget.specificCtrl.text.isNotEmpty ? '${widget.specificCtrl.text} - Suelta' : 'Suelta'}' (x1)",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
