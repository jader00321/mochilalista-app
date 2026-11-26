import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_custom_field.dart';

part 'stock_section/presentation_stock_shared_panel.dart';
part 'stock_section/presentation_stock_own_panel.dart';
part 'stock_section/presentation_stock_validation_alerts.dart';

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
  final void Function(int leftoverUnits, double costoBaseIndiv)?
  onCreateLeftover;
  final String modoStock;
  final bool usaStockCompartido;
  final ValueChanged<bool>? onToggleUsaStockCompartido;
  final TextEditingController? sharedStockCtrl;
  final Map<String, dynamic>? controllerMap;
  final void Function(String unitName, int factor)? onUnitChanged;

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
    this.onUnitChanged,
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
  late final FocusNode _sharedQuotaFocusNode;

  late final TextEditingController _packageInputCtrl;
  bool _isSyncingPackagingStock = false;

  @override
  void initState() {
    super.initState();
    _sharedQuotaFocusNode = FocusNode();

    final int factor = int.tryParse(widget.unidadesVentaCtrl.text) ?? 1;
    final int safeFactor = factor <= 0 ? 1 : factor;
    final int base = int.tryParse(widget.stockInicialCtrl.text) ?? 0;
    _packageInputCtrl = TextEditingController(
      text: safeFactor > 1 ? (base ~/ safeFactor).toString() : base.toString(),
    );
    widget.stockInicialCtrl.addListener(_syncFromBaseToPackageInput);
    widget.sharedStockCtrl?.addListener(_onSharedOrUnitChanged);
    widget.unidadesVentaCtrl.addListener(_onSharedOrUnitChanged);

    _syncSharedStockQuotaIfUnbounded();
  }

  void _triggerStateRebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleAjusteStock() {
    setState(() => _mostrarAjusteStock = !_mostrarAjusteStock);
  }

  void _toggleAjusteBase() {
    setState(() => _mostrarAjusteBase = !_mostrarAjusteBase);
  }

  void _syncFromBaseToPackageInput() {
    if (_isSyncingPackagingStock) return;
    final int factor = int.tryParse(widget.unidadesVentaCtrl.text) ?? 1;
    final int safeFactor = factor <= 0 ? 1 : factor;
    final int base = int.tryParse(widget.stockInicialCtrl.text) ?? 0;
    if (safeFactor <= 1) {
      if (_packageInputCtrl.text != base.toString()) {
        _isSyncingPackagingStock = true;
        _packageInputCtrl.text = base.toString();
        _isSyncingPackagingStock = false;
      }
      return;
    }
    final int pkgs = base ~/ safeFactor;
    if (_packageInputCtrl.text != pkgs.toString()) {
      _isSyncingPackagingStock = true;
      _packageInputCtrl.text = pkgs.toString();
      _isSyncingPackagingStock = false;
    }
  }

  @override
  void didUpdateWidget(covariant PresentationStockSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedStockCtrl != widget.sharedStockCtrl) {
      oldWidget.sharedStockCtrl?.removeListener(_onSharedOrUnitChanged);
      widget.sharedStockCtrl?.addListener(_onSharedOrUnitChanged);
    }
    if (oldWidget.unidadesVentaCtrl != widget.unidadesVentaCtrl) {
      oldWidget.unidadesVentaCtrl.removeListener(_onSharedOrUnitChanged);
      widget.unidadesVentaCtrl.addListener(_onSharedOrUnitChanged);
    }
    if (oldWidget.stockInicialCtrl != widget.stockInicialCtrl) {
      oldWidget.stockInicialCtrl.removeListener(_syncFromBaseToPackageInput);
      widget.stockInicialCtrl.addListener(_syncFromBaseToPackageInput);
    }
    _syncSharedStockQuotaIfUnbounded();
    _syncFromBaseToPackageInput();
  }

  @override
  void dispose() {
    widget.stockInicialCtrl.removeListener(_syncFromBaseToPackageInput);
    _packageInputCtrl.dispose();
    widget.sharedStockCtrl?.removeListener(_onSharedOrUnitChanged);
    widget.unidadesVentaCtrl.removeListener(_onSharedOrUnitChanged);
    _sharedQuotaFocusNode.dispose();
    _warningTimer?.cancel();
    super.dispose();
  }

  void _onSharedOrUnitChanged() {
    _syncSharedStockQuotaIfUnbounded();
    _syncFromBaseToPackageInput();
    _triggerStateRebuild();
  }

  void _syncSharedStockQuotaIfUnbounded() {
    final bool isShared =
        widget.modoStock == 'COMPARTIDO' ||
        (widget.modoStock == 'MIXTO' && widget.usaStockCompartido);
    if (!isShared) return;

    final int factorV = int.tryParse(widget.unidadesVentaCtrl.text) ?? 1;
    final int safeFactor = factorV <= 0 ? 1 : factorV;
    final int sharedBase =
        int.tryParse(widget.sharedStockCtrl?.text ?? "0") ?? 0;
    final int availableSalesUnits = safeFactor > 0
        ? (sharedBase ~/ safeFactor)
        : sharedBase;

    final int? customCupo = widget.controllerMap?['cupoMaximoVariante'] as int?;
    if (_sharedQuotaFocusNode.hasFocus) return;

    if (customCupo == null) {
      final currentVisual = int.tryParse(widget.stockFinalCtrl.text);
      if (currentVisual != availableSalesUnits) {
        widget.stockFinalCtrl.text = availableSalesUnits.toString();
      }
    } else if (customCupo > availableSalesUnits) {
      widget.controllerMap?['cupoMaximoVariante'] = availableSalesUnits;
      widget.stockFinalCtrl.text = availableSalesUnits.toString();
    } else {
      final currentVisual = int.tryParse(widget.stockFinalCtrl.text);
      if (currentVisual != customCupo) {
        widget.stockFinalCtrl.text = customCupo.toString();
      }
    }
  }

  void _handleSharedQuotaChanged({
    required int availableSalesUnits,
    required String unidadLabel,
  }) {
    final raw = widget.stockFinalCtrl.text.trim();
    if (raw.isEmpty) {
      widget.controllerMap?['cupoMaximoVariante'] = null;
      widget.onStockChanged();
      _triggerStateRebuild();
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
      _triggerStateRebuild();
    }
  }

  void _restoreIfEmpty(int maxFisico) {
    if (widget.stockFinalCtrl.text.trim().isEmpty) {
      widget.stockFinalCtrl.text = maxFisico.toString();
      widget.controllerMap?['cupoMaximoVariante'] = null;
      widget.onStockChanged();
      _triggerStateRebuild();
    }
  }

  void _showMaxQuotaWarning(int maxAvailable, String unidadLabel) {
    _warningTimer?.cancel();
    setState(() {
      _quotaWarningMessage =
          "El cupo máximo no puede superar $maxAvailable $unidadLabel según el inventario compartido.";
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

    final bool isShared =
        widget.modoStock == 'COMPARTIDO' ||
        (widget.modoStock == 'MIXTO' && widget.usaStockCompartido);

    final int factorV = int.tryParse(widget.unidadesVentaCtrl.text) ?? 1;
    final int safeFactor = factorV <= 0 ? 1 : factorV;

    final int sharedBase =
        int.tryParse(widget.sharedStockCtrl?.text ?? "0") ?? 0;
    final int availableSalesUnits = safeFactor > 0
        ? (sharedBase ~/ safeFactor)
        : sharedBase;

    final int? customCupo = widget.controllerMap?['cupoMaximoVariante'] as int?;
    final int effectiveCupo = customCupo != null
        ? (customCupo <= availableSalesUnits ? customCupo : availableSalesUnits)
        : availableSalesUnits;

    final int visualStock = int.tryParse(widget.stockFinalCtrl.text) ?? 0;
    final int totalBaseStock = visualStock * safeFactor;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.modoStock == 'MIXTO') _buildMixtoModeSelector(isDark),
          if (isShared)
            _buildSharedStockPanel(
              isDark: isDark,
              unidadLabel: unidadLabel,
              safeFactor: safeFactor,
              sharedBase: sharedBase,
              availableSalesUnits: availableSalesUnits,
              customCupo: customCupo,
              effectiveCupo: effectiveCupo,
            )
          else
            _buildOwnStockPanel(
              isDark: isDark,
              unidadLabel: unidadLabel,
              safeFactor: safeFactor,
              visualStock: visualStock,
              totalBaseStock: totalBaseStock,
            ),
          const SizedBox(height: 16),
          if (!isShared &&
              (widget.stockValidation.status ==
                      StockValidationStatus.hasLeftover ||
                  widget.stockValidation.status ==
                      StockValidationStatus.deficit))
            _buildStockValidationAlertBanner(
              isDark: isDark,
              unidadLabel: unidadLabel,
              safeFactor: safeFactor,
            ),
        ],
      ),
    );
  }
}
