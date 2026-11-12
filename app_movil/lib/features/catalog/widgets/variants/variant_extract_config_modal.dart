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
        isDark: isDark,
      ),
    );
  }

  @override
  State<VariantExtractConfigModal> createState() => _VariantExtractConfigModalState();
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

  // Datos extraídos de la variante
  late final String _specificName;
  late final String _unidadVenta;
  late final int _factorVenta;
  late final double _precioVenta;
  late final double _costoUnitario;
  late final double _margen;
  late final int _stockUnits;
  late final String _barcode;
  late final String _variantImage;
  late final int? _variantProviderId;
  late final String? _variantProviderName;
  late final bool _hasDiscount;
  late final String? _discountType;
  late final double? _discountValue;
  late final double? _offerPrice;

  @override
  void initState() {
    super.initState();
    // Si solo hay 1 presentación, forzar modo copiar
    final canCut = widget.totalPresentations > 1;
    _mode = canCut ? ProductExtractionMode.copy : ProductExtractionMode.copy;

    // Extracción limpia de los controladores de la variante
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
    _stockUnits = int.tryParse(
          (map['stockFinal'] is TextEditingController)
              ? (map['stockFinal'] as TextEditingController).text.trim()
              : map['stockFinal']?.toString() ?? '0',
        ) ??
        0;
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

    // En modo Cortar el barcode va encendido por defecto; en Copiar apagado
    _includeBarcode = (_mode == ProductExtractionMode.cut && _barcode.isNotEmpty);

    // Sugerencia inteligente inicial del nombre del nuevo producto
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
      // Regla de código de barras: si es Cortar, activarlo por defecto; si es Copiar, desactivarlo
      if (_mode == ProductExtractionMode.cut) {
        _includeBarcode = _barcode.isNotEmpty;
      } else {
        _includeBarcode = false;
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
      stockUnits: _stockUnits,
      barcode: _barcode.isNotEmpty ? _barcode : null,
      variantImage: _variantImage.isNotEmpty ? _variantImage : null,
      variantProviderId: _variantProviderId,
      variantProviderName: _variantProviderName,
      hasDiscount: _hasDiscount,
      discountType: _discountType,
      discountValue: _discountValue,
      offerPrice: _offerPrice,
      specificName: _specificName,
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.90,
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
              // ZONA 1: CABECERA FIJA Y SELECTOR DE MODO
              // ============================================================
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171722) : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tirador superior discreto
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

                    // Título y botón cerrar
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
                            color: isDark ? Colors.teal[300] : Colors.teal[700],
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
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                    const SizedBox(height: 12),

                    // Resumen compacto de la variante seleccionada
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.purple.withValues(alpha: 0.25)
                                    : Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "$_unidadVenta (x$_factorVenta) ${_specificName.isNotEmpty ? _specificName : ''}",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.purple[200] : Colors.purple[800],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "S/ ${_precioVenta.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.teal[300] : Colors.teal[800],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "• $_stockUnits uds",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Selector interactivo de 2 tarjetas: Copiar vs Cortar
                    Row(
                      children: [
                        // Tarjeta Copiar
                        Expanded(
                          child: _buildModeCard(
                            mode: ProductExtractionMode.copy,
                            icon: Icons.copy_all_rounded,
                            title: "Copiar",
                            desc: "Mantiene en este producto y crea uno nuevo.",
                            isSelected: _mode == ProductExtractionMode.copy,
                            isEnabled: true,
                            isDark: isDark,
                            onTap: () => _onModeChanged(ProductExtractionMode.copy),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tarjeta Cortar
                        Expanded(
                          child: _buildModeCard(
                            mode: ProductExtractionMode.cut,
                            icon: Icons.content_cut_rounded,
                            title: "Cortar / Mover",
                            desc: canCut
                                ? "Traslada al nuevo y retira de aquí al guardar."
                                : "Bloqueado: Única variante del producto.",
                            isSelected: _mode == ProductExtractionMode.cut,
                            isEnabled: canCut,
                            isDark: isDark,
                            onTap: () => _onModeChanged(ProductExtractionMode.cut),
                          ),
                        ),
                      ],
                    ),

                    if (!canCut) ...[
                      const SizedBox(height: 6),
                      Text(
                        "⚠️ Este producto solo tiene 1 variante; usa 'Copiar' o agrega otra antes de moverla.",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ============================================================
              // ZONA 2: CUERPO ESCROLLEABLE CON BOUNCING PHYSICS
              // ============================================================
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Input Nombre del nuevo producto
                      Text(
                        "NOMBRE DEL NUEVO PRODUCTO",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameCtrl,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: InputDecoration(
                          hintText: "Ej. Cuaderno Standford - verde",
                          prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                          filled: true,
                          fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            borderSide: const BorderSide(color: Colors.teal, width: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Chips de sugerencia rápida
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildPresetChip(
                            label: "Padre + Variante",
                            onTap: () {
                              setState(() => _nameCtrl.text = _generateCombinedName());
                            },
                            isDark: isDark,
                          ),
                          if (_specificName.isNotEmpty)
                            _buildPresetChip(
                              label: "Solo Variante: $_specificName",
                              onTap: () {
                                setState(() => _nameCtrl.text = _specificName);
                              },
                              isDark: isDark,
                            ),
                          _buildPresetChip(
                            label: "Solo Padre",
                            onTap: () {
                              setState(() => _nameCtrl.text = widget.originProductName.trim());
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: borderColor, height: 1),
                      const SizedBox(height: 14),

                      // SECCIÓN A: Datos generales del producto actual
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "A. DATOS GENERALES DEL PRODUCTO ACTUAL",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: _copyGeneralData,
                              activeThumbColor: Colors.teal,
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
                            enabled: _copyGeneralData && widget.categoryId != null,
                            isDark: isDark,
                            onToggle: () => setState(() => _copyCategory = !_copyCategory),
                          ),
                          _buildToggleChip(
                            label: "Marca: ${widget.brandName ?? 'Ninguna'}",
                            icon: Icons.branding_watermark_outlined,
                            isSelected: _copyBrand,
                            enabled: _copyGeneralData && widget.brandId != null,
                            isDark: isDark,
                            onToggle: () => setState(() => _copyBrand = !_copyBrand),
                          ),
                          _buildToggleChip(
                            label: "Proveedor: ${widget.generalProviderName ?? 'Ninguno'}",
                            icon: Icons.local_shipping_outlined,
                            isSelected: _copyProvider,
                            enabled: _copyGeneralData && widget.generalProviderId != null,
                            isDark: isDark,
                            onToggle: () => setState(() => _copyProvider = !_copyProvider),
                          ),
                          _buildToggleChip(
                            label: "Descripción / Notas",
                            icon: Icons.notes_rounded,
                            isSelected: _copyDescription,
                            enabled: _copyGeneralData &&
                                (widget.parentDescription?.isNotEmpty ?? false),
                            isDark: isDark,
                            onToggle: () => setState(() => _copyDescription = !_copyDescription),
                          ),
                          _buildToggleChip(
                            label: "Fotos generales",
                            icon: Icons.photo_outlined,
                            isSelected: _copyImages,
                            enabled: _copyGeneralData &&
                                (widget.parentImageUrl?.isNotEmpty ?? false),
                            isDark: isDark,
                            onToggle: () => setState(() => _copyImages = !_copyImages),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: borderColor, height: 1),
                      const SizedBox(height: 14),

                      // SECCIÓN B: Datos detallados de la variante a trasladar
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
                            label: "Precios, Costo y Margen (S/ ${_precioVenta.toStringAsFixed(2)})",
                            icon: Icons.attach_money_rounded,
                            isSelected: _includePricing,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () => setState(() => _includePricing = !_includePricing),
                          ),
                          _buildToggleChip(
                            label: "Unidad / Empaque ($_unidadVenta x$_factorVenta)",
                            icon: Icons.inventory_2_outlined,
                            isSelected: _includeUnit,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () => setState(() => _includeUnit = !_includeUnit),
                          ),
                          if (_variantImage.isNotEmpty)
                            _buildToggleChip(
                              label: "Foto de la variante",
                              icon: Icons.image_outlined,
                              isSelected: _includeVariantImage,
                              enabled: true,
                              isDark: isDark,
                              onToggle: () =>
                                  setState(() => _includeVariantImage = !_includeVariantImage),
                            ),
                          _buildToggleChip(
                            label: "Stock Actual ($_stockUnits uds)",
                            icon: Icons.warehouse_outlined,
                            isSelected: _includeStock,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () => setState(() => _includeStock = !_includeStock),
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
                              setState(() => _includeBarcode = !_includeBarcode);
                            },
                          ),
                          _buildToggleChip(
                            label: "Alerta Stock Mínimo",
                            icon: Icons.notifications_active_outlined,
                            isSelected: _includeStockAlert,
                            enabled: true,
                            isDark: isDark,
                            onToggle: () => setState(() => _includeStockAlert = !_includeStockAlert),
                          ),
                        ],
                      ),

                      // Detalle si incluye stock
                      if (_includeStock && _stockUnits > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _transferFullStock
                                    ? Icons.swap_horiz_rounded
                                    : Icons.exposure_zero_rounded,
                                size: 18,
                                color: isDark ? Colors.teal[300] : Colors.teal[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _transferFullStock
                                      ? (_mode == ProductExtractionMode.cut
                                          ? "Trasladar las $_stockUnits uds al nuevo producto"
                                          : "Iniciar el nuevo producto con $_stockUnits uds")
                                      : "Iniciar el nuevo producto con Stock: 0 uds",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _transferFullStock = !_transferFullStock);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  _transferFullStock ? "Cambiar a 0" : "Llevar $_stockUnits uds",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Advertencia amigable de código de barras en modo Copiar
                      if (_mode == ProductExtractionMode.copy && _barcode.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blueGrey.withValues(alpha: 0.15)
                                : Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.blueGrey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[700],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _includeBarcode
                                      ? "⚠️ Código activado en modo Copiar. Evita duplicar el mismo código si son productos físicamente distintos."
                                      : "ℹ️ Código desactivado por defecto en modo Copiar para evitar duplicidad.",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
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
                    // Texto dinámico explicativo
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
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Botones Cancelar y Continuar
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: borderColor),
                            ),
                            child: Text(
                              "Cancelar",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                            label: const Text(
                              "Continuar a Crear →",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: isDark ? const Color(0xFF00897B) : Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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

  Widget _buildModeCard({
    required ProductExtractionMode mode,
    required IconData icon,
    required String title,
    required String desc,
    required bool isSelected,
    required bool isEnabled,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeColor = mode == ProductExtractionMode.copy ? Colors.teal : Colors.amber.shade700;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(10),
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
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: isSelected ? activeColor : Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 15,
                    color: isSelected ? activeColor : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.teal[300] : Colors.teal[800],
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
