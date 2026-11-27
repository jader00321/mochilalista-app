import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/morphing_accordion.dart';
import 'package:app_movil/core/widgets/tour/configs/bundle_builder_tour.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';

part 'bundle_builder/bundle_builder_logic_mixin.dart';
part 'bundle_builder/bundle_builder_sections_mixin.dart';
part 'bundle_builder/bundle_builder_pricing_mixin.dart';
part 'bundle_builder/bundle_builder_product_picker_mixin.dart';

class BundleBuilderScreen extends StatefulWidget {
  final BundleModel? bundleToEdit;
  final InventoryWrapper? initialItem;
  final List<InventoryWrapper>? initialMultipleItems;
  final String? initialTipoPromocion;
  final bool autoTriggerTour;
  final BundleBuilderTourKeys? tourKeys;

  const BundleBuilderScreen({
    super.key,
    this.bundleToEdit,
    this.initialItem,
    this.initialMultipleItems,
    this.initialTipoPromocion,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<BundleBuilderScreen> createState() => _BundleBuilderScreenState();
}

abstract class _BundleBuilderScreenStateBase
    extends State<BundleBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  late final BundleBuilderTourKeys _tourKeys;

  List<BundleItemModel> _selectedItems = [];
  bool _isActive = true;
  String _searchQuery = "";

  String _tipoPromocion = 'paquete';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool _userEditedName = false;
  bool _userEditedPrice = false;
  bool _userEditedDesc = false;

  static const _promoTypes = [
    {
      'id': 'paquete',
      'icon': Icons.inventory_2,
      'label': 'Paquete Fusión',
      'color': Colors.blue,
      'desc':
          'Combina productos complementarios a precio especial. Aumenta el ticket promedio.',
    },
    {
      'id': 'flash',
      'icon': Icons.bolt,
      'label': 'Oferta Flash',
      'color': Colors.amber,
      'desc':
          'Descuento agresivo por tiempo limitado. Ideal para fechas escolares. Requiere fecha de fin.',
    },
    {
      'id': 'liquidez_costo',
      'icon': Icons.water_drop,
      'label': 'Liquidez',
      'color': Colors.cyan,
      'desc':
          'Venta al costo para recuperar capital. Ideal para productos sin rotación.',
    },
    {
      'id': '2x1',
      'icon': Icons.exposure_plus_2,
      'label': '2x1',
      'color': Colors.green,
      'desc':
          'El cliente paga 1 y lleva 2. Se ajusta la cantidad mínima a 2 unidades automáticamente.',
    },
    {
      'id': 'volumen',
      'icon': Icons.shopping_cart,
      'label': 'Mayoreo',
      'color': Colors.deepPurple,
      'desc':
          'Descuento por comprar +3 unidades del mismo producto. Ideal para ventas al por mayor.',
    },
    {
      'id': 'escolar',
      'icon': Icons.school,
      'label': 'Pack Escolar',
      'color': Colors.teal,
      'desc':
          'Agrupación estacional de útiles esenciales para la vuelta a clases a precio competitivo.',
    },
  ];

  void _autoSuggestNameAndPrice();
  void _applyPromoRules();
  void _addItem(InventoryWrapper product);
  void _removeItem(int index);
  void _showInfoTooltip(
    BuildContext context,
    String title,
    String message,
    IconData icon,
  );

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? BundleBuilderTourKeys();
    if (widget.autoTriggerTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await InteractiveTourService.maybeStartAutomaticTour(
          context,
          BundleBuilderTour.buildConfig(keys: _tourKeys),
        );
      });
    }
    if (widget.bundleToEdit != null) {
      _nameController.text = widget.bundleToEdit!.nombrePaquete;
      _descController.text = widget.bundleToEdit!.descripcion ?? '';
      _priceController.text = widget.bundleToEdit!.precioVentaTotal
          .toStringAsFixed(2);
      _isActive = widget.bundleToEdit!.activo;
      _tipoPromocion = widget.bundleToEdit!.tipoPromocion;
      _fechaInicio = widget.bundleToEdit!.fechaInicio;
      _fechaFin = widget.bundleToEdit!.fechaFin;
      _userEditedName = true;
      _userEditedDesc = _descController.text.isNotEmpty;
      _userEditedPrice = false;

      final prov = Provider.of<PromotionProvider>(context, listen: false);
      _selectedItems = List.from(
        prov.getItemsForBundle(widget.bundleToEdit!.id),
      );
    } else if (widget.initialMultipleItems != null &&
        widget.initialMultipleItems!.isNotEmpty) {
      if (widget.initialTipoPromocion != null) {
        _tipoPromocion = widget.initialTipoPromocion!;
      }
      for (var item in widget.initialMultipleItems!) {
        _selectedItems.add(
          BundleItemModel(
            id: 0,
            paqueteId: 0,
            productoId: item.product.id,
            presentacionId: item.presentation.id ?? 0,
            cantidadRequerida: 1,
            precioOriginalUnitario: item.effectivePrice,
          ),
        );
      }
      _scheduleInitialSuggestion();
    } else if (widget.initialItem != null) {
      if (widget.initialTipoPromocion != null) {
        _tipoPromocion = widget.initialTipoPromocion!;
      }
      _selectedItems.add(
        BundleItemModel(
          id: 0,
          paqueteId: 0,
          productoId: widget.initialItem!.product.id,
          presentacionId: widget.initialItem!.presentation.id ?? 0,
          cantidadRequerida: 1,
          precioOriginalUnitario: widget.initialItem!.effectivePrice,
        ),
      );
      _scheduleInitialSuggestion();
    }
  }

  void _scheduleInitialSuggestion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyPromoRules();
      _autoSuggestNameAndPrice();
      setState(() {});

      if (widget.initialTipoPromocion != null) {
        final currentPromo = _promoTypes.firstWhere(
          (t) => t['id'] == _tipoPromocion,
          orElse: () => _promoTypes.first,
        );
        AppFeedbackHelper.showSuccess(
          context,
          "Sugerencia aplicada: ${currentPromo['label']}",
        );
      }
    });
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(
      context,
      BundleBuilderTour.buildConfig(keys: _tourKeys),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double get _totalBaseCost {
    final inv = Provider.of<InventoryProvider>(context, listen: false);
    double total = 0;
    for (var item in _selectedItems) {
      try {
        final prod = inv.items.firstWhere(
          (p) => p.presentation.id == item.presentacionId,
        );
        total +=
            (prod.presentation.costoUnitarioCalculado ?? 0) *
            item.cantidadRequerida;
      } catch (_) {}
    }
    return total;
  }

  double get _totalOriginalPrice {
    final inv = Provider.of<InventoryProvider>(context, listen: false);
    double total = 0;
    for (var item in _selectedItems) {
      try {
        final prod = inv.items.firstWhere(
          (p) => p.presentation.id == item.presentacionId,
        );
        total += prod.effectivePrice * item.cantidadRequerida;
      } catch (_) {}
    }
    return total;
  }
}

class _BundleBuilderScreenState extends _BundleBuilderScreenStateBase
    with
        _BundleBuilderLogicMixin,
        _BundleBuilderSectionsMixin,
        _BundleBuilderPricingMixin,
        _BundleBuilderProductPickerMixin {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invProv = Provider.of<InventoryProvider>(context);

    final double currentPrice = double.tryParse(_priceController.text) ?? 0.0;
    final double cost = _totalBaseCost;
    final double originalValue = _totalOriginalPrice;
    final Color profitColor = _getProfitabilityColor(
      currentPrice,
      cost,
      isDark,
    );
    final double margin = currentPrice > 0
        ? (currentPrice - cost) / currentPrice
        : 0;
    final double savings = originalValue > 0
        ? ((originalValue - currentPrice) / originalValue)
        : 0;

    final currentPromo = _BundleBuilderScreenStateBase._promoTypes.firstWhere(
      (t) => t['id'] == _tipoPromocion,
      orElse: () => _BundleBuilderScreenStateBase._promoTypes.first,
    );
    final promoColor = currentPromo['color'] as Color;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.bundleToEdit == null ? "Nuevo Paquete" : "Editar Paquete",
            maxLines: 1,
          ),
        ),
        actions: [
          InfoTooltipButton(
            title: "Creador de Combos y Promociones",
            description:
                "Crea paquetes, combos escolares o liquidaciones agrupando productos con precios de oferta para maximizar tus ventas.",
            onStartInteractiveTour: () => _startTour(context),
            tips: const [
              InfoTip(
                icon: Icons.inventory_2_outlined,
                text:
                    "Paquete Fusión: Combina 2 o más productos complementarios con un precio especial más atractivo.",
              ),
              InfoTip(
                icon: Icons.bolt_outlined,
                text:
                    "Ofertas Flash y 2x1: Descuentos temporales con fecha de caducidad ideales para campañas escolares.",
              ),
              InfoTip(
                icon: Icons.calculate_outlined,
                text:
                    "El indicador de margen te avisa si el precio asignado al combo cubre tus costos de adquisición.",
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveBundle,
            tooltip: "Guardar",
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            KeyedSubtree(
              key: _tourKeys.identityDurationKey,
              child: _buildPromoTypeSelector(isDark),
            ),
            const SizedBox(height: 24),
            _buildDateLimits(isDark),
            const SizedBox(height: 24),
            _buildPackageInfoSection(isDark),
            const SizedBox(height: 16),
            _buildHeroPriceCard(
              isDark: isDark,
              promoColor: promoColor,
              savings: savings,
              originalValue: originalValue,
            ),
            const SizedBox(height: 24),
            _buildProfitabilitySection(
              isDark: isDark,
              profitColor: profitColor,
              currentPrice: currentPrice,
              cost: cost,
              margin: margin,
              savings: savings,
            ),
            const SizedBox(height: 24),
            _buildSelectedContentSection(isDark, invProv),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _selectedItems.isNotEmpty
          ? Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                InteractiveSheetWrapper.getEffectiveBottomPadding(
                  context,
                  minPadding: 12,
                ),
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black45 : Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saveBundle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.save_rounded, size: 22),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.bundleToEdit == null
                          ? "GUARDAR PAQUETE"
                          : "ACTUALIZAR PAQUETE",
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
