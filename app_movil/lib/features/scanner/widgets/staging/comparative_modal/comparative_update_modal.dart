import 'package:flutter/material.dart';

import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';

part 'ui/modal_purchase_section.dart';
part 'ui/modal_sale_section.dart';
part 'ui/modal_stock_section.dart';
part 'ui/modal_discount_section.dart';
part 'ui/modal_variant_cards.dart';
part 'sections/modal_unit_and_recalculation_mixin.dart';
part 'sections/modal_header_and_identity_mixin.dart';

/// Súper modal comparativo interactivo (Antes vs. Después) de staging.
class ComparativeUpdateModal extends StatefulWidget {
  final StagingVariant variant;
  final StagingProductGroup group;
  final Map<String, dynamic> dbData;
  final bool isDark;
  final ScannerProvider provider;
  final VoidCallback onConfirm;

  const ComparativeUpdateModal({
    super.key,
    required this.variant,
    required this.group,
    required this.dbData,
    required this.isDark,
    required this.provider,
    required this.onConfirm,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required StagingVariant variant,
    required StagingProductGroup group,
    required Map<String, dynamic> dbData,
    required bool isDark,
    required ScannerProvider provider,
    required VoidCallback onConfirm,
  }) {
    variant.takeSnapshot();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ComparativeUpdateModal(
        variant: variant,
        group: group,
        dbData: dbData,
        isDark: isDark,
        provider: provider,
        onConfirm: onConfirm,
      ),
    );
  }

  static String formatUnitLabelForTest(int count, String unit) =>
      _ComparativeUpdateModalState._formatUnitLabel(count, unit);

  static String formatAccumulationBadgeText(
    int completas,
    String unidad,
    int sobrante,
  ) {
    return "$completas × $unidad disponible hoy (+$sobrante unid. base acumuladas en almacén)";
  }

  @override
  State<ComparativeUpdateModal> createState() => _ComparativeUpdateModalState();
}

class _ComparativeUpdateModalState extends State<ComparativeUpdateModal> {
  late Map<String, dynamic> _currentDbData;
  String _discountMode = 'keep';
  bool _showIdentidad = false;
  bool _showProveedor = false;
  bool _showVenta = true;

  final ScrollController _modalScrollController = ScrollController();
  final GlobalKey _keyVenta = GlobalKey();
  final GlobalKey _keyStock = GlobalKey();
  final GlobalKey _keyProveedor = GlobalKey();
  final GlobalKey _keyIdentidad = GlobalKey();

  late TextEditingController _nomCtrl;
  late TextEditingController _uVentaCtrl;
  late TextEditingController _uVentaFactorCtrl;

  late TextEditingController _costoCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _precioCtrl;

  late TextEditingController _stockIngresanteCtrl;
  late TextEditingController _manualDiscountCtrl;
  late TextEditingController _umpCompraCtrl;
  late TextEditingController _cantidadUmpCtrl;
  late TextEditingController _precioUmpCtrl;
  late TextEditingController _pagoTotalCtrl;
  late TextEditingController _unidLoteCtrl;

  late TextEditingController _marcaCtrl;
  late TextEditingController _codigoBarraCtrl;
  bool _wasConfirmed = false;

  @override
  void initState() {
    super.initState();
    _currentDbData = Map.from(widget.dbData);
    if (widget.variant.discountMode != null) {
      _discountMode = widget.variant.discountMode!;
    }

    _nomCtrl = TextEditingController();
    _marcaCtrl = TextEditingController();
    _codigoBarraCtrl = TextEditingController();
    _uVentaCtrl = TextEditingController();
    _uVentaFactorCtrl = TextEditingController();
    _costoCtrl = TextEditingController();
    _margenCtrl = TextEditingController();
    _precioCtrl = TextEditingController();
    _stockIngresanteCtrl = TextEditingController();
    _manualDiscountCtrl = TextEditingController();
    _umpCompraCtrl = TextEditingController();
    _cantidadUmpCtrl = TextEditingController();
    _precioUmpCtrl = TextEditingController();
    _pagoTotalCtrl = TextEditingController();
    _unidLoteCtrl = TextEditingController();

    _initControllers();
  }

  void updateState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _initControllers() {
    _nomCtrl.text = widget.variant.nombreEspecifico;
    _marcaCtrl.text = widget.variant.matchPresentacion.datos?.marcaNombre ?? "";
    _codigoBarraCtrl.text = widget.variant.codigoBarra ?? "";

    _uVentaCtrl.text = widget.variant.unidadVenta;
    _uVentaFactorCtrl.text = widget.variant.unidadesPorVenta.toString();

    _costoCtrl.text = widget.variant.costoUnitarioSugerido
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    _margenCtrl.text = widget.variant.factorGananciaVentaSugerido
        .toStringAsFixed(2);
    _precioCtrl.text = widget.variant.precioVentaSugerido.toStringAsFixed(2);

    _marcaCtrl.text = widget.group.marcaTexto;

    final int initialStock =
        widget.variant.stockIngresanteOverride ??
        (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote)
            .toInt();
    _stockIngresanteCtrl.text = initialStock.toString();

    _manualDiscountCtrl.text =
        widget.variant.discountManualValue?.toStringAsFixed(2) ?? '';

    _umpCompraCtrl.text = widget.variant.umpCompra;
    _cantidadUmpCtrl.text = widget.variant.cantidadUmpComprada
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    _precioUmpCtrl.text = widget.variant.precioUmpProveedor.toStringAsFixed(2);
    _pagoTotalCtrl.text = widget.variant.totalPagoLote.toStringAsFixed(2);
    _unidLoteCtrl.text = widget.variant.unidadesPorLote.toString();
  }

  @override
  void dispose() {
    if (!_wasConfirmed) {
      widget.variant.restoreFromSnapshot();
    }
    _nomCtrl.dispose();
    _uVentaCtrl.dispose();
    _uVentaFactorCtrl.dispose();
    _costoCtrl.dispose();
    _margenCtrl.dispose();
    _precioCtrl.dispose();
    _marcaCtrl.dispose();
    _codigoBarraCtrl.dispose();
    _stockIngresanteCtrl.dispose();
    _manualDiscountCtrl.dispose();
    _umpCompraCtrl.dispose();
    _cantidadUmpCtrl.dispose();
    _precioUmpCtrl.dispose();
    _pagoTotalCtrl.dispose();
    _unidLoteCtrl.dispose();
    _modalScrollController.dispose();
    super.dispose();
  }

  void _autoScrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = key.currentContext;
      if (targetContext != null && targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  void _toggleAccordion(String section) {
    updateState(() {
      if (section == 'venta') {
        _showVenta = !_showVenta;
      }
      if (section == 'proveedor') {
        _showProveedor = !_showProveedor;
      }
      if (section == 'identidad') {
        _showIdentidad = !_showIdentidad;
      }
    });

    final bool isOpened =
        (section == 'venta' && _showVenta) ||
        (section == 'proveedor' && _showProveedor) ||
        (section == 'identidad' && _showIdentidad);

    if (isOpened) {
      final key = section == 'venta'
          ? _keyVenta
          : (section == 'proveedor' ? _keyProveedor : _keyIdentidad);
      _autoScrollTo(key);
    }
  }

  static String _formatUnitLabel(int count, String rawUnit) =>
      _formatComparativeUnitLabel(count, rawUnit);

  @override
  Widget build(BuildContext context) {
    final bool isNuevo =
        widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE";
    final bool hasDiscount =
        !isNuevo && _currentDbData['precio_oferta'] != null;
    final String presName = isNuevo
        ? 'Nueva Presentación'
        : (_currentDbData['nombre_completo']?.toString() ??
              _currentDbData['nombre_especifico']?.toString() ??
              'General');
    final String brand = widget.group.marcaTexto.isEmpty
        ? "Genérica"
        : widget.group.marcaTexto;
    final String cat =
        widget.group.matchProducto.datos?.categoriaNombre ?? "Sin categoría";

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.94,
      enableDragToDismiss: false,
      applyEffectiveBottomPadding: false,
      titleWidget: _buildModalTitleBar(isNuevo),
      bottomAction: _buildSaveDecisionButton(),
      child: Scrollbar(
        controller: _modalScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _modalScrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 4,
            bottom:
                MediaQuery.viewInsetsOf(context).bottom +
                InteractiveSheetWrapper.kModalScrollBottomClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderContextCard(
                isNuevo: isNuevo,
                presName: presName,
                brand: brand,
                cat: cat,
              ),
              _buildVariantCards(),
              _buildDiscrepancyBanner(isNuevo: isNuevo),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _keyVenta,
                child: _buildGroupedSaleRow(isNuevo),
              ),
              KeyedSubtree(
                key: _keyStock,
                child: !isNuevo
                    ? _buildStockManagementRow()
                    : _buildNewVariantStockRow(),
              ),
              _buildLeftoverWarning(),
              if (hasDiscount) _buildDiscountRow(),
              KeyedSubtree(
                key: _keyProveedor,
                child: _buildGroupedPurchaseRow(),
              ),
              _buildIdentityAccordion(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalTitleBar(bool isNuevo) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "Control de ${isNuevo ? 'Creación' : 'Variante'}",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: widget.isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.variant.sourceVariantUuid == null &&
                widget.variant.hasSnapshotBeenModified)
              IconButton(
                icon: const Icon(Icons.restore),
                color: Colors.blue,
                iconSize: 22,
                tooltip: "Restaurar cambios",
                onPressed: () {
                  widget.variant.restoreFromSnapshot();
                  _initControllers();
                  updateState(() {});
                },
              ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveDecisionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _hasDeficit ? null : _applyChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: _hasDeficit
              ? (widget.isDark ? Colors.grey[800] : Colors.grey[400])
              : Colors.blue[800],
          foregroundColor: Colors.white,
          disabledBackgroundColor: widget.isDark
              ? Colors.grey[850]
              : Colors.grey[300],
          disabledForegroundColor: widget.isDark
              ? Colors.grey[500]
              : Colors.grey[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _hasDeficit ? "SOLUCIONA EL STOCK FALTANTE" : "GUARDAR DECISIÓN",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
