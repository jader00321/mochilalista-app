import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_custom_field.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_margin_indicator.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_card_header.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_card_collapsed_view.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_pricing_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_discount_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_stock_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_purchase_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_advanced_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_suggestion_chips.dart';

/// Orquestador modular de la Tarjeta de Presentación / Variante de Producto.
/// Conecta la lógica matemática y reactiva con sub-widgets especializados
/// para cabecera, vista compacta, precios, stock, compras y detalles avanzados.
class ProductPresentationCard extends StatefulWidget {
  final Map<String, dynamic> controllerMap;
  final VoidCallback onDelete;
  final VoidCallback? onClone;
  final VoidCallback? onSetDefault;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final int presentationIndex;
  final int totalPresentations;
  final Function(bool) onStateChange;
  final Widget providerDropdown;
  final Function(int leftoverStock, double costoBaseIndiv)? onCreateLeftover;
  final VoidCallback? onInvalidateLeftover;
  final VoidCallback? onBeforeDiscreteMutation;
  final VoidCallback? onDiscreteMutationCompleted;

  const ProductPresentationCard({
    super.key,
    required this.controllerMap,
    required this.onDelete,
    this.onClone,
    this.onSetDefault,
    this.onMoveUp,
    this.onMoveDown,
    this.presentationIndex = 0,
    this.totalPresentations = 1,
    required this.onStateChange,
    required this.providerDropdown,
    this.onCreateLeftover,
    this.onInvalidateLeftover,
    this.onBeforeDiscreteMutation,
    this.onDiscreteMutationCompleted,
  });

  @override
  State<ProductPresentationCard> createState() =>
      _ProductPresentationCardState();
}

class _ProductPresentationCardState extends State<ProductPresentationCard> {
  // Compras
  late TextEditingController _umpCompraCtrl;
  late TextEditingController _cantCompraCtrl;
  late TextEditingController _unidadesLoteCtrl;
  late TextEditingController _totalPagoCtrl;

  // Ventas
  late TextEditingController _specificCtrl;
  late TextEditingController _unidadVentaCtrl;
  late TextEditingController _unidadesVentaCtrl;
  late TextEditingController _costoPresCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _ventaCtrl;

  // Descuentos
  late TextEditingController _valorDescuentoCtrl;

  // Stock
  late TextEditingController _stockInicialCtrl;
  late TextEditingController _nuevoIngresoCtrl;
  late TextEditingController _stockDescuentoCtrl;
  late TextEditingController _stockFinalCtrl;
  late TextEditingController _ajusteBaseCtrl;

  late PresentationMathEngine _engine;
  bool _isCardExpanded = true;

  @override
  void initState() {
    super.initState();
    if (widget.controllerMap.containsKey('isExpanded')) {
      _isCardExpanded = widget.controllerMap['isExpanded'] == true;
    } else {
      _isCardExpanded = widget.controllerMap['isDefault'] == true;
      widget.controllerMap['isExpanded'] = _isCardExpanded;
    }
    _specificCtrl = widget.controllerMap['specific'];
    _unidadVentaCtrl = widget.controllerMap['unidadVenta'];
    _unidadesVentaCtrl = widget.controllerMap['unidadesVenta'];

    _costoPresCtrl = widget.controllerMap['costoPres'];
    _margenCtrl = widget.controllerMap['margen'];
    _ventaCtrl = widget.controllerMap['precioVenta'];

    _valorDescuentoCtrl = widget.controllerMap['valorDescuento'];

    _stockInicialCtrl = widget.controllerMap['stockInicial'];
    _nuevoIngresoCtrl = widget.controllerMap['nuevoIngreso'];
    _stockDescuentoCtrl = widget.controllerMap['stockDescuento'];
    _stockFinalCtrl = widget.controllerMap['stockFinal'];
    _ajusteBaseCtrl = widget.controllerMap['ajusteBase'];

    _umpCompraCtrl = widget.controllerMap['umpCompra'];
    _cantCompraCtrl = widget.controllerMap['cantCompra'];
    _unidadesLoteCtrl = widget.controllerMap['unidadesLote'];
    _totalPagoCtrl = widget.controllerMap['totalPago'];

    _engine = PresentationMathEngine(
      controllerMap: widget.controllerMap,
      onInvalidateLeftover: widget.onInvalidateLeftover,
      onStateUpdate: () {
        if (mounted) setState(() {});
      },
      umpCompraCtrl: _umpCompraCtrl,
      cantCompraCtrl: _cantCompraCtrl,
      unidadesLoteCtrl: _unidadesLoteCtrl,
      totalPagoCtrl: _totalPagoCtrl,
      specificCtrl: _specificCtrl,
      unidadVentaCtrl: _unidadVentaCtrl,
      unidadesVentaCtrl: _unidadesVentaCtrl,
      costoPresCtrl: _costoPresCtrl,
      margenCtrl: _margenCtrl,
      ventaCtrl: _ventaCtrl,
      valorDescuentoCtrl: _valorDescuentoCtrl,
      stockInicialCtrl: _stockInicialCtrl,
      nuevoIngresoCtrl: _nuevoIngresoCtrl,
      stockDescuentoCtrl: _stockDescuentoCtrl,
      stockFinalCtrl: _stockFinalCtrl,
      ajusteBaseCtrl: _ajusteBaseCtrl,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _engine.init();
    });
  }

  @override
  void didUpdateWidget(covariant ProductPresentationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controllerMap.containsKey('isExpanded') &&
        widget.controllerMap['isExpanded'] != _isCardExpanded) {
      _isCardExpanded = widget.controllerMap['isExpanded'] == true;
    }
    _engine.syncLeftoverState(
      oldWidget.controllerMap['leftoverCreated'],
      widget.controllerMap['leftoverCreated'],
    );
    if (widget.controllerMap['activeRoundingTarget'] != _engine.activeRoundingTarget) {
      _engine.activeRoundingTarget = widget.controllerMap['activeRoundingTarget'] as double?;
    }
    if (widget.controllerMap['preRoundedPrice'] != _engine.preRoundedPrice) {
      _engine.preRoundedPrice = widget.controllerMap['preRoundedPrice'] as String?;
    }
    if (widget.controllerMap['preRoundedMargen'] != _engine.preRoundedMargen) {
      _engine.preRoundedMargen = widget.controllerMap['preRoundedMargen'] as String?;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDefault = widget.controllerMap['isDefault'] == true;
    bool isPublic = widget.controllerMap['estado'] != 'privado';
    bool isEdit = widget.controllerMap['isEditMode'] == true;
    bool leftoverCreated = widget.controllerMap['leftoverCreated'] == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double pVentaVal = double.tryParse(_ventaCtrl.text) ?? 0.0;
    final double cPresVal = double.tryParse(_costoPresCtrl.text) ?? 0.0;
    final margenTexto =
        PresentationMarginIndicator.calcularMargenTexto(pVentaVal, cPresVal);
    final margenColor =
        PresentationMarginIndicator.calcularMargenColor(pVentaVal, cPresVal);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        border: Border.all(
          color: isDefault
              ? (isDark ? Colors.teal[400]! : Colors.teal)
              : (isDark ? Colors.white10 : Colors.grey.shade300),
          width: isDefault ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // 1. Cabecera superior
          PresentationCardHeader(
            isDefault: isDefault,
            isPublic: isPublic,
            presentationIndex: widget.presentationIndex,
            totalPresentations: widget.totalPresentations,
            isExpanded: _isCardExpanded,
            isDark: isDark,
            onSetDefault: widget.onSetDefault,
            onMoveUp: widget.onMoveUp,
            onMoveDown: widget.onMoveDown,
            onStateChange: widget.onStateChange,
            onClone: widget.onClone,
            onDelete: widget.onDelete,
            onToggleExpand: () {
              setState(() {
                _isCardExpanded = !_isCardExpanded;
                widget.controllerMap['isExpanded'] = _isCardExpanded;
              });
            },
          ),

          // 2. Resumen compacto cuando está colapsada
          if (!_isCardExpanded)
            PresentationCardCollapsedView(
              isDefault: isDefault,
              unidadVenta: _unidadVentaCtrl.text,
              unidadesVenta: _unidadesVentaCtrl.text,
              specificName: _specificCtrl.text,
              precioVenta: _ventaCtrl.text,
              stockFinal: _stockFinalCtrl.text,
              costoPres: _costoPresCtrl.text,
              margenTexto: margenTexto,
              margenColor: margenColor,
              isDark: isDark,
              onTap: () {
                setState(() {
                  _isCardExpanded = true;
                  widget.controllerMap['isExpanded'] = true;
                });
              },
            ),

          // 3. Cuerpo modular expandido
          if (_isCardExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y sugerencias
                  MiniInput(
                    ctrl: _specificCtrl,
                    label: "Nombre Específico / Detalle",
                    hint: "Ej: Rojo A4",
                    isDark: isDark,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  PresentationSuggestionChips(
                    specificCtrl: _specificCtrl,
                    isDark: isDark,
                    onSuggestionSelected: () {
                      widget.onBeforeDiscreteMutation?.call();
                      widget.onDiscreteMutationCompleted?.call();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Unidad y factor de venta
                  Text(
                    "¿CÓMO LO VAS A VENDER?",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.purple[300] : Colors.purple[800],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SmartUnitSelector(
                    unitCtrl: _unidadVentaCtrl,
                    factorCtrl: _unidadesVentaCtrl,
                    isDark: isDark,
                    onChanged: (unitName, factor, isAutomatic) {
                      widget.onBeforeDiscreteMutation?.call();
                      _engine.onUnidadVentaChanged(unitName, factor, isAutomatic);
                      widget.onDiscreteMutationCompleted?.call();
                    },
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 16,
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                  ),

                  // Costos y precios
                  PresentationPricingSection(
                    costoCtrl: _costoPresCtrl,
                    margenCtrl: _margenCtrl,
                    ventaCtrl: _ventaCtrl,
                    isEditMode: isEdit,
                    originalBaseCost: _engine.originalBaseCost,
                    originalFactor: _engine.originalFactor,
                    precioVentaOriginal:
                        widget.controllerMap['precioVentaOriginal'],
                    descuentoActivo:
                        widget.controllerMap['descuentoActivo'] == true,
                    precioOferta: _engine.precioOferta,
                    isDark: isDark,
                    activeRoundingTarget: _engine.activeRoundingTarget,
                    onCostChanged: () => _engine
                        .recalcularHaciaAtrasDesdeVisual(fromMargen: true),
                    onMargenChanged: () => _engine
                        .recalcularHaciaAtrasDesdeVisual(fromMargen: true),
                    onVentaChanged: () => _engine
                        .recalcularHaciaAtrasDesdeVisual(fromMargen: false),
                    onRoundPrice: (targetFraction) {
                      widget.onBeforeDiscreteMutation?.call();
                      _engine.roundPrice(targetFraction);
                      widget.onDiscreteMutationCompleted?.call();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Módulo de descuentos
                  PresentationDiscountSection(
                    descuentoActivo:
                        widget.controllerMap['descuentoActivo'] == true,
                    tipoDescuento:
                        widget.controllerMap['tipoDescuento'] ?? 'porcentaje',
                    valorDescuentoCtrl: _valorDescuentoCtrl,
                    precioVenta: double.tryParse(_ventaCtrl.text) ?? 0.0,
                    precioOferta: _engine.precioOferta,
                    isDark: isDark,
                    activeRoundingTarget: _engine.activeDiscountRoundingTarget,
                    onDiscountActiveChanged: (val) {
                      widget.onBeforeDiscreteMutation?.call();
                      setState(() {
                        widget.controllerMap['descuentoActivo'] = val;
                      });
                      widget.onDiscreteMutationCompleted?.call();
                    },
                    onDiscountTypeChanged: (type) {
                      widget.onBeforeDiscreteMutation?.call();
                      setState(() {
                        widget.controllerMap['tipoDescuento'] = type;
                      });
                      widget.onDiscreteMutationCompleted?.call();
                    },
                    onValueChanged: () {
                      _engine.onDiscountValueChanged();
                      setState(() {});
                    },
                    onRoundDiscount: (targetFraction) {
                      widget.onBeforeDiscreteMutation?.call();
                      _engine.roundDiscountPrice(targetFraction);
                      widget.onDiscreteMutationCompleted?.call();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Inventario y stock
                  PresentationStockSection(
                    stockInicialCtrl: _stockInicialCtrl,
                    nuevoIngresoCtrl: _nuevoIngresoCtrl,
                    stockDescuentoCtrl: _stockDescuentoCtrl,
                    stockFinalCtrl: _stockFinalCtrl,
                    ajusteBaseCtrl: _ajusteBaseCtrl,
                    unidadVentaCtrl: _unidadVentaCtrl,
                    unidadesVentaCtrl: _unidadesVentaCtrl,
                    specificCtrl: _specificCtrl,
                    isEditMode: isEdit,
                    originalBaseStock: _engine.originalBaseStock,
                    leftoverCreated: leftoverCreated,
                    stockValidation: _engine.stockValidation,
                    costoBaseParaSobrante: _engine.costoBaseParaSobrante,
                    isDark: isDark,
                    onStockChanged: _engine.recalcularHaciaAtrasDesdeVisual,
                    onAjusteBaseChanged: _engine.aplicarAjusteBaseManual,
                    onCreateLeftover: widget.onCreateLeftover,
                  ),
                  const SizedBox(height: 16),

                  // Datos de compra / factura
                  PresentationPurchaseSection(
                    umpCompraCtrl: _umpCompraCtrl,
                    unidadesLoteCtrl: _unidadesLoteCtrl,
                    cantCompraCtrl: _cantCompraCtrl,
                    totalPagoCtrl: _totalPagoCtrl,
                    isEditMode: isEdit,
                    isDark: isDark,
                    onUmpChanged: _engine.onUmpCompraChanged,
                    onCantCompraChanged: () {
                      if (!isEdit) _engine.recalcularDesdeCompra();
                    },
                    onTotalPagoChanged: () {
                      if (!isEdit) _engine.recalcularDesdeCompra();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Detalles avanzados
                  PresentationAdvancedSection(
                    barcodeCtrl: widget.controllerMap['barcode'],
                    imageCtrl: widget.controllerMap['image'],
                    descCtrl: widget.controllerMap['desc'],
                    providerDropdown: widget.providerDropdown,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
