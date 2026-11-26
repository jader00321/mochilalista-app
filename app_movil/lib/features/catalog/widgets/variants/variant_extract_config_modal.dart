import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';

part 'extract_config/variant_extract_header_and_modes.dart';
part 'extract_config/variant_extract_economic_and_sections.dart';
part 'extract_config/variant_extract_stock_and_footer.dart';

/// Modal flotante de configuración previa para extraer o copiar una variante
/// hacia un producto nuevo e independiente.
/// Arquitectura en 3 zonas: Cabecera fija, Cuerpo escrolleable y Pie de página fijo.
class VariantExtractConfigModal extends StatefulWidget {
  final String originProductName;
  final int originProductId;
  final Map<String, dynamic> variantControllerMap;
  final int totalPresentations;
  final int? categoryId;
  final String? categoryName;
  final int? brandId;
  final String? brandName;
  final int? generalProviderId;
  final String? generalProviderName;
  final String? parentDescription;
  final String? parentImageUrl;
  final String modoStock;
  final int parentSharedStock;
  final bool isDark;

  const VariantExtractConfigModal({
    super.key,
    required this.originProductName,
    required this.originProductId,
    required this.variantControllerMap,
    required this.totalPresentations,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.generalProviderId,
    this.generalProviderName,
    this.parentDescription,
    this.parentImageUrl,
    this.modoStock = 'INDEPENDIENTE',
    this.parentSharedStock = 0,
    required this.isDark,
  });

  static Future<VariantExtractionBundle?> show({
    required BuildContext context,
    required String originProductName,
    required int originProductId,
    required Map<String, dynamic> variantControllerMap,
    required int totalPresentations,
    int? categoryId,
    String? categoryName,
    int? brandId,
    String? brandName,
    int? generalProviderId,
    String? generalProviderName,
    String? parentDescription,
    String? parentImageUrl,
    String modoStock = 'INDEPENDIENTE',
    int parentSharedStock = 0,
    required bool isDark,
  }) {
    return showModalBottomSheet<VariantExtractionBundle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VariantExtractConfigModal(
        originProductName: originProductName,
        originProductId: originProductId,
        variantControllerMap: variantControllerMap,
        totalPresentations: totalPresentations,
        categoryId: categoryId,
        categoryName: categoryName,
        brandId: brandId,
        brandName: brandName,
        generalProviderId: generalProviderId,
        generalProviderName: generalProviderName,
        parentDescription: parentDescription,
        parentImageUrl: parentImageUrl,
        modoStock: modoStock,
        parentSharedStock: parentSharedStock,
        isDark: isDark,
      ),
    );
  }

  @override
  State<VariantExtractConfigModal> createState() =>
      _VariantExtractConfigModalState();
}

class _VariantExtractConfigModalState extends State<VariantExtractConfigModal> {
  late ProductExtractionMode _mode;
  late final TextEditingController _nameCtrl;

  // Sección A: Datos generales
  bool _copyGeneralData = true;
  bool _copyCategory = true;
  bool _copyBrand = true;
  bool _copyProvider = true;
  bool _copyDescription = true;
  bool _copyImages = true;

  // Sección B: Datos de variante
  bool _includePricing = true;
  bool _includeUnit = true;
  bool _includeVariantImage = true;
  bool _includeStock = true;
  bool _transferFullStock = true;
  bool _includeBarcode = false;
  bool _includeStockAlert = true;

  // Manejo de Stock y Factor
  late final bool _isSharedOrigin;
  late final int _parentSharedStock;
  bool _deductStockFromOrigin = true;

  // Estructura seleccionada (para Factor > 1)
  VariantExtractionStructure _targetStructure =
      VariantExtractionStructure.keepPackaging;

  // Datos extraídos de la variante
  late final String _specificName;
  late final String _unidadVenta;
  late final int _factorVenta;
  late final double _precioVenta;
  late final double _costoUnitario;
  late final double _margen;

  // Desglose matemático unitario
  late final double _unitCostPrice;
  late final double _unitSalePrice;

  // Cantidades de stock en empaque y en unidades base
  late final int _packageUnits;
  late final int _baseUnits;

  // Datos secundarios y avanzados
  late final String _barcode;
  late final String _variantImage;
  late final int? _variantProviderId;
  late final String? _variantProviderName;
  late final bool _hasDiscount;
  late final String? _discountType;
  late final double? _discountValue;
  late final double? _offerPrice;

  // Datos de compra / factura
  late final String? _umpCompra;
  late final int _unidadesLote;
  late final double? _cantCompra;
  late final double? _totalPago;
  late final String? _variantDescription;

  void _refreshState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  String _readStringField(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val is TextEditingController) {
      return val.text.trim();
    }
    return val?.toString().trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _mode = ProductExtractionMode.copy;
    final map = widget.variantControllerMap;

    _specificName = _readStringField(map, 'specific');
    final rawUnit = _readStringField(map, 'unidadVenta');
    _unidadVenta = rawUnit.isNotEmpty ? rawUnit : 'Unidad';
    _factorVenta = int.tryParse(_readStringField(map, 'unidadesVenta')) ?? 1;
    final safeFactor = _factorVenta <= 0 ? 1 : _factorVenta;

    _precioVenta = double.tryParse(_readStringField(map, 'precioVenta')) ?? 0.0;
    _costoUnitario = double.tryParse(_readStringField(map, 'costoPres')) ?? 0.0;
    _margen = double.tryParse(_readStringField(map, 'margen')) ?? 1.35;

    _unitCostPrice = _costoUnitario / safeFactor;
    _unitSalePrice = _precioVenta / safeFactor;

    _isSharedOrigin =
        map['usaStockCompartido'] == true || widget.modoStock == 'COMPARTIDO';
    _packageUnits = int.tryParse(_readStringField(map, 'stockFinal')) ?? 0;
    _baseUnits = _packageUnits * safeFactor;

    if (widget.parentSharedStock > 0) {
      _parentSharedStock = widget.parentSharedStock;
    } else {
      final int rawParent =
          int.tryParse(map['stockBaseTotal']?.toString() ?? '0') ?? 0;
      _parentSharedStock = rawParent > 0
          ? rawParent
          : (_isSharedOrigin ? _baseUnits : 0);
    }

    _barcode = _readStringField(map, 'barcode');
    _variantImage = _readStringField(map, 'image');
    _variantProviderId = map['providerId'] as int?;
    _variantProviderName = map['deferredProviderName'] as String?;
    _hasDiscount = map['descuentoActivo'] == true;
    _discountType = map['tipoDescuento'] as String?;
    _discountValue = double.tryParse(_readStringField(map, 'valorDescuento'));
    _offerPrice = (map['precioOfertaExacto'] as num?)?.toDouble();

    final rawUmp = _readStringField(map, 'umpCompra');
    _umpCompra = rawUmp.isNotEmpty ? rawUmp : null;

    final rawLote = int.tryParse(_readStringField(map, 'unidadesLote'));
    _unidadesLote = (rawLote != null && rawLote > 0) ? rawLote : 1;

    _cantCompra = double.tryParse(_readStringField(map, 'cantCompra'));
    _totalPago = double.tryParse(_readStringField(map, 'totalPago'));

    final rawDesc = _readStringField(map, 'desc');
    _variantDescription = rawDesc.isNotEmpty ? rawDesc : null;

    _includeBarcode =
        (_mode == ProductExtractionMode.cut && _barcode.isNotEmpty);
    _nameCtrl = TextEditingController(text: _generateCombinedName());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _generateCombinedName() {
    final parent = widget.originProductName.trim();
    if (_specificName.isNotEmpty) {
      if (parent.toLowerCase().contains(_specificName.toLowerCase())) {
        return parent;
      }
      return "$parent - $_specificName";
    }
    if (_factorVenta > 1) {
      return "$parent ($_unidadVenta x$_factorVenta)";
    }
    return "$parent ($_unidadVenta)";
  }

  void _onModeChanged(ProductExtractionMode newMode) {
    if (newMode == ProductExtractionMode.cut &&
        widget.totalPresentations <= 1) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _mode = newMode;
      if (_mode == ProductExtractionMode.cut) {
        _includeBarcode = _barcode.isNotEmpty;
        _deductStockFromOrigin = true;
      } else {
        _includeBarcode = false;
        _deductStockFromOrigin = false;
      }
    });
  }

  void _submit() {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ingresa un nombre para el nuevo producto"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final generalData = VariantExtractionGeneralData(
      copyCategory: _copyGeneralData && _copyCategory,
      copyBrand: _copyGeneralData && _copyBrand,
      copyProvider: _copyGeneralData && _copyProvider,
      copyDescription: _copyGeneralData && _copyDescription,
      copyImages: _copyGeneralData && _copyImages,
      categoryId: widget.categoryId,
      categoryName: widget.categoryName,
      brandId: widget.brandId,
      brandName: widget.brandName,
      generalProviderId: widget.generalProviderId,
      generalProviderName: widget.generalProviderName,
      description: widget.parentDescription,
      imageUrl: widget.parentImageUrl,
    );

    final detailData = VariantExtractionDetailData(
      newProductName: newName,
      includePricing: _includePricing,
      includeUnit: _includeUnit,
      includeVariantImage: _includeVariantImage,
      includeStock: _includeStock,
      transferFullStock: _transferFullStock,
      includeBarcode: _includeBarcode,
      includeStockAlert: _includeStockAlert,
      unitName: _unidadVenta,
      unitFactor: _factorVenta,
      salePrice: _precioVenta,
      costPrice: _costoUnitario,
      margin: _margen,
      stockUnits: _packageUnits,
      packageUnits: _packageUnits,
      baseUnits: _baseUnits,
      isSharedOrigin: _isSharedOrigin,
      parentSharedStock: _parentSharedStock,
      deductStockFromOrigin:
          _mode == ProductExtractionMode.cut && _deductStockFromOrigin,
      targetStructure: _targetStructure,
      unitCostPrice: _unitCostPrice,
      unitSalePrice: _unitSalePrice,
      barcode: _barcode.isNotEmpty ? _barcode : null,
      variantImage: _variantImage.isNotEmpty ? _variantImage : null,
      alertStock: 5,
      variantProviderId: _variantProviderId,
      variantProviderName: _variantProviderName,
      hasDiscount: _hasDiscount,
      discountType: _discountType,
      discountValue: _discountValue,
      offerPrice: _offerPrice,
      specificName: _specificName,
      umpCompra: _umpCompra,
      unidadesLote: _unidadesLote,
      cantCompra: _cantCompra,
      totalPago: _totalPago,
      variantDescription: _variantDescription,
    );

    final bundle = VariantExtractionBundle(
      mode: _mode,
      originProductId: widget.originProductId,
      originProductName: widget.originProductName,
      variantLocalId: widget.variantControllerMap['id'].toString(),
      variantDbId: widget.variantControllerMap['db_id'] as int?,
      isOriginDefault: widget.variantControllerMap['isDefault'] == true,
      generalData: generalData,
      detailData: detailData,
    );

    HapticFeedback.mediumImpact();
    Navigator.pop(context, bundle);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final canCut = widget.totalPresentations > 1;
    final surfaceColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final mediaQuery = MediaQuery.of(context);

    final String empaqueLabel = _factorVenta > 1
        ? "$_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base)"
        : "$_baseUnits uds";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.92),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderSection(
                isDark: isDark,
                borderColor: borderColor,
                empaqueLabel: empaqueLabel,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModeAndNameSection(
                        isDark: isDark,
                        canCut: canCut,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: 14),
                      if (_factorVenta > 1) ...[
                        _buildEconomicBreakdownSection(isDark),
                        const SizedBox(height: 14),
                      ],
                      _buildGeneralAndDetailSections(
                        isDark: isDark,
                        borderColor: borderColor,
                        empaqueLabel: empaqueLabel,
                      ),
                      if (_includeStock && _packageUnits > 0) ...[
                        const SizedBox(height: 10),
                        _buildStockDetailSection(
                          isDark: isDark,
                          borderColor: borderColor,
                        ),
                      ],
                      if (_mode == ProductExtractionMode.copy &&
                          _barcode.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildBarcodeCopyNotice(isDark),
                      ],
                    ],
                  ),
                ),
              ),
              _buildPinnedFooter(isDark: isDark, borderColor: borderColor),
            ],
          ),
        ),
      ),
    );
  }
}
