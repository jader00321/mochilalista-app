/// Modos de operación para extraer una variante a un producto autónomo
enum ProductExtractionMode {
  copy,
  cut,
}

/// Opciones de estructuración de presentaciones en el nuevo producto
/// cuando la variante extraída tiene Factor > 1 (Par, Pack, Caja, Docena, etc.)
enum VariantExtractionStructure {
  keepPackaging, // Mantener en su empaque original (ej. Caja x3)
  unitOnly, // Convertir a venta por unidad individual (Unidad x1)
  bothUnitAndPackage, // Crear con ambas presentaciones (Unidad x1 + Caja x3) vinculadas en Stock Compartido
}

/// Datos generales del producto padre que se pueden copiar al nuevo producto
class VariantExtractionGeneralData {
  final bool copyCategory;
  final bool copyBrand;
  final bool copyProvider;
  final bool copyDescription;
  final bool copyImages;

  final int? categoryId;
  final String? categoryName;
  final int? brandId;
  final String? brandName;
  final int? generalProviderId;
  final String? generalProviderName;
  final String? description;
  final String? imageUrl;

  const VariantExtractionGeneralData({
    this.copyCategory = true,
    this.copyBrand = true,
    this.copyProvider = true,
    this.copyDescription = true,
    this.copyImages = true,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.generalProviderId,
    this.generalProviderName,
    this.description,
    this.imageUrl,
  });

  VariantExtractionGeneralData copyWith({
    bool? copyCategory,
    bool? copyBrand,
    bool? copyProvider,
    bool? copyDescription,
    bool? copyImages,
    int? categoryId,
    String? categoryName,
    int? brandId,
    String? brandName,
    int? generalProviderId,
    String? generalProviderName,
    String? description,
    String? imageUrl,
  }) {
    return VariantExtractionGeneralData(
      copyCategory: copyCategory ?? this.copyCategory,
      copyBrand: copyBrand ?? this.copyBrand,
      copyProvider: copyProvider ?? this.copyProvider,
      copyDescription: copyDescription ?? this.copyDescription,
      copyImages: copyImages ?? this.copyImages,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      generalProviderId: generalProviderId ?? this.generalProviderId,
      generalProviderName: generalProviderName ?? this.generalProviderName,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Datos específicos de la variante que se trasladarán al nuevo producto
class VariantExtractionDetailData {
  final String newProductName;
  final bool includePricing;
  final bool includeUnit;
  final bool includeVariantImage;
  final bool includeStock;
  final bool transferFullStock;
  final bool includeBarcode;
  final bool includeStockAlert;

  final String unitName;
  final int unitFactor;
  final double salePrice;
  final double costPrice;
  final double margin;

  // Manejo exacto y bidireccional de empaques vs unidades base
  final int stockUnits; // Empaques o unidades según contexto (retrocompatibilidad)
  final int packageUnits; // Cantidad en unidades de empaque (ej. 3 Cajas)
  final int baseUnits; // Cantidad total física en unidades base (ej. 9 und. base)
  final bool isSharedOrigin; // ¿Provenía de stock compartido?
  final int parentSharedStock; // Stock base compartido del producto padre
  final bool deductStockFromOrigin; // ¿Descontar del stock compartido / variante de origen?

  // Inteligencia de factores (Factor > 1) y desglose económico
  final VariantExtractionStructure targetStructure;
  final double unitCostPrice; // Costo por unidad individual (C_pkg / Factor)
  final double unitSalePrice; // Precio proporcional por unidad individual (P_pkg / Factor)

  // Datos secundarios completos
  final String? barcode;
  final String? variantImage;
  final int? alertStock;
  final int? variantProviderId;
  final String? variantProviderName;
  final bool hasDiscount;
  final String? discountType;
  final double? discountValue;
  final double? offerPrice;
  final String? specificName;

  // Datos de compra / factura
  final String? umpCompra;
  final int unidadesLote;
  final double? cantCompra;
  final double? totalPago;
  final String? variantDescription;

  const VariantExtractionDetailData({
    required this.newProductName,
    this.includePricing = true,
    this.includeUnit = true,
    this.includeVariantImage = true,
    this.includeStock = true,
    this.transferFullStock = true,
    this.includeBarcode = false,
    this.includeStockAlert = true,
    this.unitName = 'Unidad',
    this.unitFactor = 1,
    this.salePrice = 0.0,
    this.costPrice = 0.0,
    this.margin = 1.35,
    this.stockUnits = 0,
    this.packageUnits = 0,
    this.baseUnits = 0,
    this.isSharedOrigin = false,
    this.parentSharedStock = 0,
    this.deductStockFromOrigin = true,
    this.targetStructure = VariantExtractionStructure.keepPackaging,
    this.unitCostPrice = 0.0,
    this.unitSalePrice = 0.0,
    this.barcode,
    this.variantImage,
    this.alertStock = 5,
    this.variantProviderId,
    this.variantProviderName,
    this.hasDiscount = false,
    this.discountType,
    this.discountValue,
    this.offerPrice,
    this.specificName,
    this.umpCompra,
    this.unidadesLote = 1,
    this.cantCompra,
    this.totalPago,
    this.variantDescription,
  });

  VariantExtractionDetailData copyWith({
    String? newProductName,
    bool? includePricing,
    bool? includeUnit,
    bool? includeVariantImage,
    bool? includeStock,
    bool? transferFullStock,
    bool? includeBarcode,
    bool? includeStockAlert,
    String? unitName,
    int? unitFactor,
    double? salePrice,
    double? costPrice,
    double? margin,
    int? stockUnits,
    int? packageUnits,
    int? baseUnits,
    bool? isSharedOrigin,
    int? parentSharedStock,
    bool? deductStockFromOrigin,
    VariantExtractionStructure? targetStructure,
    double? unitCostPrice,
    double? unitSalePrice,
    String? barcode,
    String? variantImage,
    int? alertStock,
    int? variantProviderId,
    String? variantProviderName,
    bool? hasDiscount,
    String? discountType,
    double? discountValue,
    double? offerPrice,
    String? specificName,
    String? umpCompra,
    int? unidadesLote,
    double? cantCompra,
    double? totalPago,
    String? variantDescription,
  }) {
    return VariantExtractionDetailData(
      newProductName: newProductName ?? this.newProductName,
      includePricing: includePricing ?? this.includePricing,
      includeUnit: includeUnit ?? this.includeUnit,
      includeVariantImage: includeVariantImage ?? this.includeVariantImage,
      includeStock: includeStock ?? this.includeStock,
      transferFullStock: transferFullStock ?? this.transferFullStock,
      includeBarcode: includeBarcode ?? this.includeBarcode,
      includeStockAlert: includeStockAlert ?? this.includeStockAlert,
      unitName: unitName ?? this.unitName,
      unitFactor: unitFactor ?? this.unitFactor,
      salePrice: salePrice ?? this.salePrice,
      costPrice: costPrice ?? this.costPrice,
      margin: margin ?? this.margin,
      stockUnits: stockUnits ?? this.stockUnits,
      packageUnits: packageUnits ?? this.packageUnits,
      baseUnits: baseUnits ?? this.baseUnits,
      isSharedOrigin: isSharedOrigin ?? this.isSharedOrigin,
      parentSharedStock: parentSharedStock ?? this.parentSharedStock,
      deductStockFromOrigin:
          deductStockFromOrigin ?? this.deductStockFromOrigin,
      targetStructure: targetStructure ?? this.targetStructure,
      unitCostPrice: unitCostPrice ?? this.unitCostPrice,
      unitSalePrice: unitSalePrice ?? this.unitSalePrice,
      barcode: barcode ?? this.barcode,
      variantImage: variantImage ?? this.variantImage,
      alertStock: alertStock ?? this.alertStock,
      variantProviderId: variantProviderId ?? this.variantProviderId,
      variantProviderName: variantProviderName ?? this.variantProviderName,
      hasDiscount: hasDiscount ?? this.hasDiscount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      offerPrice: offerPrice ?? this.offerPrice,
      specificName: specificName ?? this.specificName,
      umpCompra: umpCompra ?? this.umpCompra,
      unidadesLote: unidadesLote ?? this.unidadesLote,
      cantCompra: cantCompra ?? this.cantCompra,
      totalPago: totalPago ?? this.totalPago,
      variantDescription: variantDescription ?? this.variantDescription,
    );
  }
}

/// Paquete inmutable completo que transfiere la variante hacia la pantalla Crear Producto
class VariantExtractionBundle {
  final ProductExtractionMode mode;
  final int originProductId;
  final String originProductName;
  final String variantLocalId;
  final int? variantDbId;
  final bool isOriginDefault;
  final VariantExtractionGeneralData generalData;
  final VariantExtractionDetailData detailData;

  const VariantExtractionBundle({
    required this.mode,
    required this.originProductId,
    required this.originProductName,
    required this.variantLocalId,
    this.variantDbId,
    this.isOriginDefault = false,
    required this.generalData,
    required this.detailData,
  });
}

/// Resultado atómico emitido por Crear Producto hacia la pantalla origen
class ProductExtractionResult {
  final bool success;
  final ProductExtractionMode mode;
  final String variantLocalId;
  final int? variantDbId;
  final String newProductName;
  final int? newProductId;
  final bool wasOriginDefault;
  final String? transferredBarcode;
  final int transferredStock;
  final int transferredBaseUnits;
  final bool isSharedOrigin;
  final bool shouldDeductSharedPool;

  const ProductExtractionResult({
    required this.success,
    required this.mode,
    required this.variantLocalId,
    this.variantDbId,
    required this.newProductName,
    this.newProductId,
    this.wasOriginDefault = false,
    this.transferredBarcode,
    this.transferredStock = 0,
    this.transferredBaseUnits = 0,
    this.isSharedOrigin = false,
    this.shouldDeductSharedPool = true,
  });
}
