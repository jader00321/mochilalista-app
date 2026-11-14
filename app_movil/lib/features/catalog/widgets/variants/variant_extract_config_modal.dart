import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';

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

  @override
  void initState() {
    super.initState();
    final canCut = widget.totalPresentations > 1;
    _mode = canCut ? ProductExtractionMode.copy : ProductExtractionMode.copy;

    final map = widget.variantControllerMap;

    _specificName = (map['specific'] is TextEditingController)
        ? (map['specific'] as TextEditingController).text.trim()
        : (map['specific']?.toString().trim() ?? '');
    _unidadVenta = (map['unidadVenta'] is TextEditingController)
        ? (map['unidadVenta'] as TextEditingController).text.trim()
        : (map['unidadVenta']?.toString().trim() ?? 'Unidad');
    _factorVenta = int.tryParse(
          (map['unidadesVenta'] is TextEditingController)
              ? (map['unidadesVenta'] as TextEditingController).text.trim()
              : map['unidadesVenta']?.toString() ?? '1',
        ) ??
        1;
    final safeFactor = _factorVenta <= 0 ? 1 : _factorVenta;

    _precioVenta = double.tryParse(
          (map['precioVenta'] is TextEditingController)
              ? (map['precioVenta'] as TextEditingController).text.trim()
              : map['precioVenta']?.toString() ?? '0.0',
        ) ??
        0.0;
    _costoUnitario = double.tryParse(
          (map['costoPres'] is TextEditingController)
              ? (map['costoPres'] as TextEditingController).text.trim()
              : map['costoPres']?.toString() ?? '0.0',
        ) ??
        0.0;
    _margen = double.tryParse(
          (map['margen'] is TextEditingController)
              ? (map['margen'] as TextEditingController).text.trim()
              : map['margen']?.toString() ?? '1.35',
        ) ??
        1.35;

    // Desglose económico unitario estricto
    _unitCostPrice = _costoUnitario / safeFactor;
    _unitSalePrice = _precioVenta / safeFactor;

    // Detección precisa de modo de stock de origen
    final bool isSharedFlag = map['usaStockCompartido'] == true ||
        widget.modoStock == 'COMPARTIDO';
    _isSharedOrigin = isSharedFlag;

    // Cantidad visual de empaques disponibles
    _packageUnits = int.tryParse(
          (map['stockFinal'] is TextEditingController)
              ? (map['stockFinal'] as TextEditingController).text.trim()
              : map['stockFinal']?.toString() ?? '0',
        ) ??
        0;

    // Cantidad total física en unidades base
    _baseUnits = _packageUnits * safeFactor;

    // Stock base compartido del producto padre
    if (widget.parentSharedStock > 0) {
      _parentSharedStock = widget.parentSharedStock;
    } else {
      final int rawParent = int.tryParse(map['stockBaseTotal']?.toString() ?? '0') ?? 0;
      _parentSharedStock = rawParent > 0 ? rawParent : (_isSharedOrigin ? _baseUnits : 0);
    }

    _barcode = (map['barcode'] is TextEditingController)
        ? (map['barcode'] as TextEditingController).text.trim()
        : (map['barcode']?.toString().trim() ?? '');
    _variantImage = (map['image'] is TextEditingController)
        ? (map['image'] as TextEditingController).text.trim()
        : (map['image']?.toString().trim() ?? '');

    _variantProviderId = map['providerId'] as int?;
    _variantProviderName = map['deferredProviderName'] as String?;
    _hasDiscount = map['descuentoActivo'] == true;
    _discountType = map['tipoDescuento'] as String?;
    _discountValue = double.tryParse(
      (map['valorDescuento'] is TextEditingController)
          ? (map['valorDescuento'] as TextEditingController).text.trim()
          : map['valorDescuento']?.toString() ?? '',
    );
    _offerPrice = (map['precioOfertaExacto'] as num?)?.toDouble();

    // Datos de compra / factura
    final rawUmp = (map['umpCompra'] is TextEditingController)
        ? (map['umpCompra'] as TextEditingController).text.trim()
        : (map['umpCompra']?.toString().trim() ?? '');
    _umpCompra = rawUmp.isNotEmpty ? rawUmp : null;

    final rawLote = int.tryParse(
      (map['unidadesLote'] is TextEditingController)
          ? (map['unidadesLote'] as TextEditingController).text.trim()
          : map['unidadesLote']?.toString() ?? '1',
    );
    _unidadesLote = (rawLote != null && rawLote > 0) ? rawLote : 1;

    _cantCompra = double.tryParse(
      (map['cantCompra'] is TextEditingController)
          ? (map['cantCompra'] as TextEditingController).text.trim()
          : map['cantCompra']?.toString() ?? '',
    );

    _totalPago = double.tryParse(
      (map['totalPago'] is TextEditingController)
          ? (map['totalPago'] as TextEditingController).text.trim()
          : map['totalPago']?.toString() ?? '',
    );

    final rawDesc = (map['desc'] is TextEditingController)
        ? (map['desc'] as TextEditingController).text.trim()
        : (map['desc']?.toString().trim() ?? '');
    _variantDescription = rawDesc.isNotEmpty ? rawDesc : null;

    // En modo Cortar el barcode va encendido por defecto; en Copiar apagado
    _includeBarcode = (_mode == ProductExtractionMode.cut && _barcode.isNotEmpty);

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
    if (newMode == ProductExtractionMode.cut && widget.totalPresentations <= 1) {
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
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ============================================================
              // ZONA 1: CABECERA FIJA Y RESUMEN
              // ============================================================
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171722) : Colors.grey.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.teal.withValues(alpha: 0.2)
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.drive_file_move_outlined,
                            size: 20,
                            color:
                                isDark ? Colors.teal[300] : Colors.teal[700],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Convertir Variante en Producto",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                "Desde: ${widget.originProductName}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Resumen compacto con empaques y unidades base claras
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.purple.withValues(alpha: 0.25)
                                    : Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "$_unidadVenta (x$_factorVenta) ${_specificName.isNotEmpty ? _specificName : ''}".trim(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.purple[200]
                                      : Colors.purple[800],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "S/ ${_precioVenta.toStringAsFixed(2)} • $empaqueLabel",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.teal[300] : Colors.teal[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // ZONA 2: CUERPO ESCROLLEABLE
              // ============================================================
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Modo (Copiar vs Cortar)
                      Row(
                        children: [
                          Expanded(
                            child: _buildModeCard(
                              mode: ProductExtractionMode.copy,
                              icon: Icons.copy_rounded,
                              title: "Copiar",
                              desc: "Mantiene en este producto y crea uno nuevo.",
                              isSelected: _mode == ProductExtractionMode.copy,
                              isEnabled: true,
                              isDark: isDark,
                              onTap: () =>
                                  _onModeChanged(ProductExtractionMode.copy),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildModeCard(
                              mode: ProductExtractionMode.cut,
                              icon: Icons.content_cut_rounded,
                              title: "Cortar / Mover",
                              desc: canCut
                                  ? "Traslada al nuevo y retira de aquí al guardar."
                                  : "Bloqueado. Este producto solo tiene 1 variante.",
                              isSelected: _mode == ProductExtractionMode.cut,
                              isEnabled: canCut,
                              isDark: isDark,
                              onTap: canCut
                                  ? () =>
                                      _onModeChanged(ProductExtractionMode.cut)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Input Nombre del nuevo producto
                      Text(
                        "NOMBRE DEL NUEVO PRODUCTO",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                          hintText: "Ej. ${_generateCombinedName()}",
                          filled: true,
                          fillColor:
                              isDark ? Colors.white10 : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.teal.shade300
                                  : Colors.teal,
                              width: 1.5,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Sugerencias rápidas de nombre
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildNameChip(
                            label: "Padre + Variante",
                            onTap: () => setState(() =>
                                _nameCtrl.text = _generateCombinedName()),
                            isDark: isDark,
                          ),
                          if (_specificName.isNotEmpty)
                            _buildNameChip(
                              label: "Solo Variante: $_specificName",
                              onTap: () =>
                                  setState(() => _nameCtrl.text = _specificName),
                              isDark: isDark,
                            ),
                          _buildNameChip(
                            label: "Solo Padre",
                            onTap: () => setState(() => _nameCtrl.text =
                                widget.originProductName.trim()),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ======================================================
                      // DESGLOSE ECONÓMICO Y SELECTOR DE ESTRUCTURA (Factor > 1)
                      // ======================================================
                      if (_factorVenta > 1) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2638)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.blue.withValues(alpha: 0.3)
                                  : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : const Color(0xFF1E40AF),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "DESGLOSE ECONÓMICO INTELIGENTE",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: isDark
                                            ? Colors.blue[300]
                                            : const Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black26
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "• $_unidadVenta (x$_factorVenta): Costo S/ ${_costoUnitario.toStringAsFixed(2)} • Venta S/ ${_precioVenta.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.teal[300]
                                            : Colors.teal[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "• Por unidad: Costo S/ ${_unitCostPrice.toStringAsFixed(2)} • Venta S/ ${_unitSalePrice.toStringAsFixed(2)} • Margen ${((_margen - 1) * 100).toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.blue[300]
                                            : const Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "¿Cómo deseas estructurar el nuevo producto?",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey[200]
                                      : Colors.grey[900],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Opción 1: Mantener en su empaque
                              _buildStructureOption(
                                structure:
                                    VariantExtractionStructure.keepPackaging,
                                title: "1. Mantener en Empaque ($_unidadVenta x$_factorVenta)",
                                subtitle:
                                    "Se vende por $_unidadVenta a S/ ${_precioVenta.toStringAsFixed(2)} con stock de $_packageUnits ${_unidadVenta}s ($_baseUnits und. base).",
                                isSelected: _targetStructure ==
                                    VariantExtractionStructure.keepPackaging,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 6),

                              // Opción 2: Convertir a Unidad individual
                              _buildStructureOption(
                                structure: VariantExtractionStructure.unitOnly,
                                title: "2. Convertir a Unidad Individual (Unidad x1)",
                                subtitle:
                                    "Se venderá al por menor a S/ ${_unitSalePrice.toStringAsFixed(2)} con stock de $_baseUnits Unidades.",
                                isSelected: _targetStructure ==
                                    VariantExtractionStructure.unitOnly,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 6),

                              // Opción 3: Crear con ambas presentaciones vinculadas
                              _buildStructureOption(
                                structure: VariantExtractionStructure
                                    .bothUnitAndPackage,
                                title: "3. Crear con Ambas (Unidad x1 + $_unidadVenta x$_factorVenta)",
                                subtitle:
                                    "Crea 2 presentaciones en Stock Compartido ($_baseUnits und. base) para vender por menor y por mayor.",
                                isSelected: _targetStructure ==
                                    VariantExtractionStructure
                                        .bothUnitAndPackage,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // SECCIÓN A: Datos generales
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "A. DATOS GENERALES DEL PRODUCTO ACTUAL",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color:
                                    isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _copyGeneralData,
                              activeThumbColor: Colors.teal,
                              activeTrackColor:
                                  Colors.teal.withValues(alpha: 0.3),
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _copyGeneralData = val;
                                  if (!val) {
                                    _copyCategory = false;
                                    _copyBrand = false;
                                    _copyProvider = false;
                                    _copyDescription = false;
                                    _copyImages = false;
                                  } else {
                                    _copyCategory = true;
                                    _copyBrand = true;
                                    _copyProvider = true;
                                    _copyDescription = true;
                                    _copyImages = true;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildToggleChip(
                            label: "Categoría: ${widget.categoryName ?? 'Ninguna'}",
                            icon: Icons.category_outlined,
                            isSelected: _copyCategory,
                            enabled:
                                _copyGeneralData && widget.categoryId != null,
                            isDark: isDark,
                            onToggle: () => setState(
                                () => _copyCategory = !_copyCategory),
                          ),
                          _buildToggleChip(
                            label: "Marca: ${widget.brandName ?? 'Ninguna'}",
                            icon: Icons.branding_watermark_outlined,
                            isSelected: _copyBrand,
                            enabled: _copyGeneralData && widget.brandId != null,
                            isDark: isDark,
                            onToggle: () =>
                                setState(() => _copyBrand = !_copyBrand),
                          ),
                          _buildToggleChip(
                            label:
                                "Proveedor: ${widget.generalProviderName ?? 'Ninguno'}",
                            icon: Icons.local_shipping_outlined,
                            isSelected: _copyProvider,
                            enabled: _copyGeneralData &&
                                (widget.generalProviderId != null ||
                                    widget.generalProviderName != null),
                            isDark: isDark,
                            onToggle: () => setState(
                                () => _copyProvider = !_copyProvider),
                          ),
                          _buildToggleChip(
                            label: "Descripción / Notas",
                            icon: Icons.notes_rounded,
                            isSelected: _copyDescription,
                            enabled: _copyGeneralData &&
                                (widget.parentDescription?.isNotEmpty ?? false),
                            isDark: isDark,
                            onToggle: () => setState(
                                () => _copyDescription = !_copyDescription),
                          ),
                          _buildToggleChip(
                            label: "Fotos generales",
                            icon: Icons.photo_outlined,
                            isSelected: _copyImages,
                            enabled: _copyGeneralData &&
                                (widget.parentImageUrl?.isNotEmpty ?? false),
                            isDark: isDark,
                            onToggle: () =>
                                setState(() => _copyImages = !_copyImages),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: borderColor, height: 1),
                      const SizedBox(height: 14),

                      // SECCIÓN B: Datos detallados de la variante
                      Text(
                        "B. DATOS DETALLADOS DE LA VARIANTE",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildToggleChip(
                            label:
                                "Precios, Costo y Margen (S/ ${_precioVenta.toStringAsFixed(2)})",
                            icon: Icons.attach_money_rounded,
                            isSelected: _includePricing,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () => setState(
                                () => _includePricing = !_includePricing),
                          ),
                          _buildToggleChip(
                            label: "Unidad / Empaque ($_unidadVenta x$_factorVenta)",
                            icon: Icons.inventory_2_outlined,
                            isSelected: _includeUnit,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () =>
                                setState(() => _includeUnit = !_includeUnit),
                          ),
                          if (_variantImage.isNotEmpty)
                            _buildToggleChip(
                              label: "Foto de la variante",
                              icon: Icons.image_outlined,
                              isSelected: _includeVariantImage,
                              enabled: true,
                              isDark: isDark,
                              onToggle: () => setState(() =>
                                  _includeVariantImage = !_includeVariantImage),
                            ),
                          _buildToggleChip(
                            label: "Stock Actual ($empaqueLabel)",
                            icon: Icons.warehouse_outlined,
                            isSelected: _includeStock,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () =>
                                setState(() => _includeStock = !_includeStock),
                          ),
                          _buildToggleChip(
                            label: _barcode.isNotEmpty
                                ? "Código de Barras ($_barcode)"
                                : "Código de Barras (Vacío)",
                            icon: Icons.qr_code_rounded,
                            isSelected: _includeBarcode,
                            enabled: _barcode.isNotEmpty,
                            isDark: isDark,
                            onToggle: () {
                              if (_barcode.isEmpty) return;
                              setState(
                                  () => _includeBarcode = !_includeBarcode);
                            },
                          ),
                          _buildToggleChip(
                            label: "Alerta Stock Mínimo",
                            icon: Icons.notifications_active_outlined,
                            isSelected: _includeStockAlert,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () => setState(
                                () => _includeStockAlert = !_includeStockAlert),
                          ),
                        ],
                      ),

                      // Detalle si incluye stock
                      if (_includeStock && _packageUnits > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isSharedOrigin
                                        ? Icons.hub_rounded
                                        : Icons.inventory_2_outlined,
                                    size: 16,
                                    color: _isSharedOrigin
                                        ? (isDark
                                            ? Colors.blue[300]
                                            : const Color(0xFF1E40AF))
                                        : (isDark
                                            ? Colors.teal[300]
                                            : Colors.teal[700]),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _isSharedOrigin
                                          ? "Stock disponible: $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base de $_parentSharedStock und. compartidas)"
                                          : "Stock actual: $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base individuales)",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isSharedOrigin
                                            ? (isDark
                                                ? Colors.blue[200]
                                                : const Color(0xFF1E40AF))
                                            : (isDark
                                                ? Colors.teal[200]
                                                : Colors.teal[900]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _transferFullStock
                                        ? Icons.swap_horiz_rounded
                                        : Icons.exposure_zero_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.teal[300]
                                        : Colors.teal[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _transferFullStock
                                          ? (_mode == ProductExtractionMode.cut
                                              ? "Trasladar las $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base) al nuevo producto"
                                              : "Iniciar el nuevo producto con $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base)")
                                          : "Iniciar el nuevo producto con Stock: 0",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[200]
                                            : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _transferFullStock =
                                          !_transferFullStock);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      _transferFullStock
                                          ? "Cambiar a 0"
                                          : "Llevar stock",
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),

                              // Switch de descuento de inventario origen si es Cortar + Stock Compartido
                              if (_mode == ProductExtractionMode.cut &&
                                  _isSharedOrigin &&
                                  _transferFullStock) ...[
                                const SizedBox(height: 8),
                                Divider(color: borderColor, height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "¿Descontar $_baseUnits und. base del inventario compartido de '${widget.originProductName}'?",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.amber[200]
                                                  : const Color(0xFF92400E),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _deductStockFromOrigin
                                                ? "El producto '${widget.originProductName}' quedará con ${math.max(0, _parentSharedStock - _baseUnits)} und. base restantes."
                                                : "El producto '${widget.originProductName}' conservará sus $_parentSharedStock und. base intactas.",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: _deductStockFromOrigin,
                                        activeThumbColor: Colors.amber.shade700,
                                        activeTrackColor: Colors.amber
                                            .withValues(alpha: 0.3),
                                        onChanged: (val) {
                                          HapticFeedback.selectionClick();
                                          setState(() =>
                                              _deductStockFromOrigin = val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Advertencia amigable de código de barras en modo Copiar
                      if (_mode == ProductExtractionMode.copy &&
                          _barcode.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blueGrey.withValues(alpha: 0.15)
                                : Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.blueGrey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: isDark
                                    ? Colors.blueGrey[200]
                                    : Colors.blueGrey[700],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _includeBarcode
                                      ? "⚠️ Código activado en modo Copiar. Evita duplicar el mismo código si son productos físicamente distintos."
                                      : "ℹ️ Código desactivado por defecto en modo Copiar para evitar duplicidad.",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
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
              ),

              // ============================================================
              // ZONA 3: PIE DE PÁGINA FIJO (PINNED FOOTER)
              // ============================================================
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171722) : Colors.grey.shade50,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Row(
                        key: ValueKey(_mode),
                        children: [
                          Icon(
                            _mode == ProductExtractionMode.cut
                                ? Icons.security_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 14,
                            color: _mode == ProductExtractionMode.cut
                                ? Colors.amber.shade700
                                : Colors.teal,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _mode == ProductExtractionMode.cut
                                  ? "La variante se retirará de este producto de forma segura SOLO al presionar GUARDAR."
                                  : "Se abrirá Crear Producto con estos datos. El producto actual conservará sus variantes.",
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Botones Cancelar y Continuar (Texto limpio sin flechas duplicadas)
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: borderColor),
                            ),
                            child: Text(
                              "Cancelar",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: isDark
                                  ? const Color(0xFF00897B)
                                  : Colors.teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Continuar a Crear →",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStructureOption({
    required VariantExtractionStructure structure,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _targetStructure = structure);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.blue.withValues(alpha: 0.25)
                  : const Color(0xFFDBEAFE))
              : (isDark ? Colors.black12 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.blue.shade400 : const Color(0xFF2563EB))
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: isSelected
                    ? (isDark ? Colors.blue[300] : const Color(0xFF1E40AF))
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (isDark
                              ? Colors.blue[100]
                              : const Color(0xFF1E3A8A))
                          : (isDark ? Colors.grey[200] : Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required ProductExtractionMode mode,
    required IconData icon,
    required String title,
    required String desc,
    required bool isSelected,
    required bool isEnabled,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final activeColor =
        mode == ProductExtractionMode.cut ? Colors.amber.shade700 : Colors.teal;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? activeColor.withValues(alpha: 0.18)
                    : activeColor.withValues(alpha: 0.08))
                : (isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? activeColor : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: isSelected ? activeColor : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.25,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.teal[200] : Colors.teal[800],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool enabled,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onToggle();
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? Colors.teal.withValues(alpha: 0.18)
                    : Colors.teal.shade50)
                : (isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.teal.shade400 : Colors.teal)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : icon,
                size: 13,
                color: isSelected ? Colors.teal : Colors.grey,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (isDark ? Colors.teal[200] : Colors.teal[900])
                        : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
