import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_custom_field.dart';

/// Sección de Inventario y Control de Stock para la tarjeta de presentación.
/// Incluye inputs de stock inicial, ingreso, stock final calculado,
/// cupo de venta para variantes compartidas y soporte reactivo de pool.
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
  final String modoStock;
  final bool usaStockCompartido;
  final ValueChanged<bool>? onToggleUsaStockCompartido;
  final TextEditingController? sharedStockCtrl;
  final Map<String, dynamic>? controllerMap;

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
    this.modoStock = 'INDEPENDIENTE',
    this.usaStockCompartido = false,
    this.onToggleUsaStockCompartido,
    this.sharedStockCtrl,
    this.controllerMap,
  });

  @override
  State<PresentationStockSection> createState() =>
      _PresentationStockSectionState();
}

class _PresentationStockSectionState extends State<PresentationStockSection> {
  bool _mostrarAjusteStock = false;
  bool _mostrarAjusteBase = false;
  Timer? _warningTimer;
  String? _quotaWarningMessage;

  @override
  void dispose() {
    _warningTimer?.cancel();
    super.dispose();
  }

  void _showMaxQuotaWarning(int maxAvailable, String unidadLabel) {
    _warningTimer?.cancel();
    setState(() {
      _quotaWarningMessage =
          "El cupo máximo no puede superar $maxAvailable $unidadLabel según el pool central.";
    });
    _warningTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _quotaWarningMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final unidadLabel = widget.unidadVentaCtrl.text.isNotEmpty
        ? widget.unidadVentaCtrl.text
        : 'Uds';

    final bool isShared = widget.modoStock == 'COMPARTIDO' ||
        (widget.modoStock == 'MIXTO' && widget.usaStockCompartido);

    final int factorV = int.tryParse(widget.unidadesVentaCtrl.text) ?? 1;
    final int safeFactor = factorV <= 0 ? 1 : factorV;

    final int sharedBase = int.tryParse(widget.sharedStockCtrl?.text ?? "0") ?? 0;
    final int availableSalesUnits = safeFactor > 0 ? (sharedBase ~/ safeFactor) : sharedBase;

    final int? customCupo = widget.controllerMap?['cupoMaximoVariante'] as int?;
    final int effectiveCupo = customCupo != null
        ? (customCupo <= availableSalesUnits ? customCupo : availableSalesUnits)
        : availableSalesUnits;

    final int visualStock = int.tryParse(widget.stockFinalCtrl.text) ?? 0;
    final int totalBaseStock = visualStock * safeFactor;

    // Sincronizar texto de stock final en modo compartido si no está tipiado
    if (isShared && widget.stockFinalCtrl.text.isEmpty) {
      widget.stockFinalCtrl.text = effectiveCupo.toString();
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector en Modo MIXTO
          if (widget.modoStock == 'MIXTO') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => widget.onToggleUsaStockCompartido?.call(true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.usaStockCompartido
                              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hub_rounded,
                              size: 14,
                              color: widget.usaStockCompartido
                                  ? (isDark ? Colors.blue[300] : const Color(0xFF1E40AF))
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Compartido",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: widget.usaStockCompartido ? FontWeight.bold : FontWeight.w500,
                                color: widget.usaStockCompartido
                                    ? (isDark ? Colors.blue[200] : const Color(0xFF1E40AF))
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
                      onTap: () => widget.onToggleUsaStockCompartido?.call(false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !widget.usaStockCompartido
                              ? (isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: !widget.usaStockCompartido
                                  ? (isDark ? Colors.teal[300] : const Color(0xFF0F766E))
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Stock Propio",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: !widget.usaStockCompartido ? FontWeight.bold : FontWeight.w500,
                                color: !widget.usaStockCompartido
                                    ? (isDark ? Colors.teal[200] : const Color(0xFF0F766E))
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

          if (isShared) ...[
            // Panel de Stock Compartido con Cupo Interactivo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2338) : const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.blue.withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue[900] : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.hub_rounded, size: 16, color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Stock del Pool Central",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.4) : const Color(0xFF93C5FD)),
                        ),
                        child: Text(
                          "= $effectiveCupo $unidadLabel disp.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[200] : const Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Factor x$safeFactor · Pool Central: $sharedBase unidades base totales.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: MiniInput(
                          ctrl: widget.stockFinalCtrl,
                          label: "Stock Final (Cupo)",
                          hint: "$availableSalesUnits",
                          isNum: true,
                          isBold: true,
                          isDark: isDark,
                          onChanged: () {
                            final raw = widget.stockFinalCtrl.text.trim();
                            if (raw.isEmpty) {
                              widget.controllerMap?['cupoMaximoVariante'] = null;
                              widget.onStockChanged();
                              setState(() {});
                              return;
                            }
                            final entered = int.tryParse(raw);
                            if (entered != null) {
                              if (entered > availableSalesUnits) {
                                widget.stockFinalCtrl.text = availableSalesUnits.toString();
                                widget.stockFinalCtrl.selection = TextSelection.collapsed(
                                  offset: widget.stockFinalCtrl.text.length,
                                );
                                widget.controllerMap?['cupoMaximoVariante'] = availableSalesUnits;
                                _showMaxQuotaWarning(availableSalesUnits, unidadLabel);
                              } else if (entered < 0) {
                                widget.stockFinalCtrl.text = "0";
                                widget.controllerMap?['cupoMaximoVariante'] = 0;
                              } else {
                                widget.controllerMap?['cupoMaximoVariante'] =
                                    (entered == availableSalesUnits) ? null : entered;
                              }
                              widget.onStockChanged();
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: customCupo != null
                                ? (isDark ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFFFEF3C7))
                                : (isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.06)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: customCupo != null
                                  ? (isDark ? Colors.amber.withValues(alpha: 0.3) : const Color(0xFFFCD34D))
                                  : (isDark ? Colors.blue.withValues(alpha: 0.2) : const Color(0xFFBFDBFE)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                customCupo != null ? "Cupo Limitado" : "Cupo Total Pool",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: customCupo != null
                                      ? (isDark ? Colors.amber[300] : const Color(0xFFB45309))
                                      : (isDark ? Colors.blue[300] : const Color(0xFF1E40AF)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                customCupo != null
                                    ? "$effectiveCupo de $availableSalesUnits $unidadLabel máx."
                                    : "Libre hasta $availableSalesUnits $unidadLabel",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_quotaWarningMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _quotaWarningMessage!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Panel de Stock Independiente
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
                  if (!widget.isEditMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: MiniInput(
                            ctrl: widget.stockInicialCtrl,
                            label: "Stock Inicial (Sueltas físicas)",
                            isNum: true,
                            hint: "0",
                            isDark: isDark,
                            onChanged: widget.onStockChanged,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: MiniInput(
                            ctrl: widget.stockInicialCtrl,
                            label: "Stock Sistema",
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
                  ],
                  if (safeFactor > 1) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calculate_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              !widget.isEditMode
                                  ? "Equivale a: $visualStock $unidadLabel ($totalBaseStock und. base)"
                                  : "Stock para la venta: $visualStock $unidadLabel ($totalBaseStock und. base)",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[200] : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!widget.isEditMode && safeFactor <= 1) ...[
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
        ],
        const SizedBox(height: 16),
          // 🔥 ALERTA DE RESIDUO (INTELIGENTE - Solo en Stock Propio)
          if (!isShared &&
              (widget.stockValidation.status ==
                      StockValidationStatus.hasLeftover ||
                  widget.stockValidation.status ==
                      StockValidationStatus.deficit)) ...[
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
