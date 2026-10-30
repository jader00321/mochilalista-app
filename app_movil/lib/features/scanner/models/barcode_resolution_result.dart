import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';

/// Tipos de resolución en las 4 situaciones reales de inventario al escanear
enum BarcodeResolutionType {
  /// Situación 1: Una variante específica tiene registrado ese código exacto
  exactVariant,

  /// Situación 2: El código es global (todas las variantes tienen el mismo código)
  /// O el código solo está registrado en el Producto Padre (se escoge variante default/primera)
  parentOrGlobal,

  /// Situación 3: Múltiples variantes (ej. 3 de 5) comparten el código escaneado
  /// (se escoge la variante principal o primera dentro de ese subconjunto coincidente)
  variantSubset,

  /// Situación 4: El código escaneado no existe en SQLite (ni en productos ni variantes)
  notFound,
}

class BarcodeResolutionResult {
  final BarcodeResolutionType type;
  final InventoryWrapper? item;
  final String barcode;
  final String? message;

  const BarcodeResolutionResult({
    required this.type,
    this.item,
    required this.barcode,
    this.message,
  });

  factory BarcodeResolutionResult.notFound(String barcode, {String? message}) {
    return BarcodeResolutionResult(
      type: BarcodeResolutionType.notFound,
      item: null,
      barcode: barcode,
      message: message ?? "Código no registrado en el inventario",
    );
  }

  factory BarcodeResolutionResult.exactVariant(InventoryWrapper item, String barcode) {
    return BarcodeResolutionResult(
      type: BarcodeResolutionType.exactVariant,
      item: item,
      barcode: barcode,
      message: "Variante identificada con éxito",
    );
  }

  factory BarcodeResolutionResult.parentOrGlobal(InventoryWrapper item, String barcode) {
    return BarcodeResolutionResult(
      type: BarcodeResolutionType.parentOrGlobal,
      item: item,
      barcode: barcode,
      message: "Producto identificado (variante principal seleccionada)",
    );
  }

  factory BarcodeResolutionResult.variantSubset(InventoryWrapper item, String barcode) {
    return BarcodeResolutionResult(
      type: BarcodeResolutionType.variantSubset,
      item: item,
      barcode: barcode,
      message: "Subconjunto de variantes identificado (variante principal seleccionada)",
    );
  }

  bool get isFound => item != null && type != BarcodeResolutionType.notFound;
  bool get isNotFound => type == BarcodeResolutionType.notFound;
  bool get isOutOfStock => item != null && item!.isOutOfStock;
  Product? get product => item?.product;
  ProductPresentation? get selectedVariant => item?.presentation;
}
