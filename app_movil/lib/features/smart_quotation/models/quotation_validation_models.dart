import 'package:app_movil/features/smart_quotation/models/crm_parse_helpers.dart';

class BundleChange {
  final int itemId;
  final int bundleId;
  final String bundleName;
  final List<String> changes;
  final bool isDeactivated;
  final bool isDeleted;
  final bool isCompositionChange;
  final double? oldPrice;
  final double? newPrice;

  BundleChange({
    required this.itemId,
    required this.bundleId,
    required this.bundleName,
    required this.changes,
    this.isDeactivated = false,
    this.isDeleted = false,
    this.isCompositionChange = false,
    this.oldPrice,
    this.newPrice,
  });

  factory BundleChange.fromJson(Map<String, dynamic> json) {
    return BundleChange(
      itemId: json['item_id'] ?? -1,
      bundleId: json['bundle_id'] ?? -1,
      bundleName: json['bundle_name'] ?? 'Oferta',
      changes: (json['changes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isDeactivated: json['is_deactivated'] == true || json['is_deactivated'] == 1,
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
      isCompositionChange: json['is_composition_change'] == true || json['is_composition_change'] == 1,
      oldPrice: json['old_price'] != null ? (json['old_price'] as num).toDouble() : null,
      newPrice: json['new_price'] != null ? (json['new_price'] as num).toDouble() : null,
    );
  }
}

class ValidationResult {
  final bool hasIssues;
  final bool canSell;
  final List<StockWarning> stockWarnings;
  final List<PriceChange> priceChanges;
  final List<NameChange> nameChanges;
  final List<BundleChange> bundleChanges;
  final List<UnitChange> unitChanges;
  final List<SharedStockConflict> sharedStockConflicts;

  ValidationResult({
    required this.hasIssues,
    required this.canSell,
    required this.stockWarnings,
    required this.priceChanges,
    this.nameChanges = const [],
    this.bundleChanges = const [],
    this.unitChanges = const [],
    this.sharedStockConflicts = const [],
  });

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      hasIssues: json['has_issues'] == 1 || json['has_issues'] == true,
      canSell: json['can_sell'] == 1 || json['can_sell'] == true || json['can_sell'] == null,
      stockWarnings: (json['stock_warnings'] as List?)?.map((e) => StockWarning.fromJson(e)).toList() ?? [],
      priceChanges: (json['price_changes'] as List?)?.map((e) => PriceChange.fromJson(e)).toList() ?? [],
      nameChanges: (json['name_changes'] as List?)?.map((e) => NameChange.fromJson(e)).toList() ?? [],
      bundleChanges: (json['bundle_changes'] as List?)?.map((e) => BundleChange.fromJson(e)).toList() ?? [],
      unitChanges: (json['unit_changes'] as List?)?.map((e) => UnitChange.fromJson(e)).toList() ?? [],
      sharedStockConflicts: (json['shared_stock_conflicts'] as List?)?.map((e) => SharedStockConflict.fromJson(e)).toList() ?? [],
    );
  }
}

class SharedStockConflict {
  final int productId;
  final String productName;
  final int totalSharedPool;
  final int totalRequestedBaseUnits;
  final int excessBaseUnits;
  final List<QuoteItemConflictDetail> conflictingItems;

  const SharedStockConflict({
    required this.productId,
    required this.productName,
    required this.totalSharedPool,
    required this.totalRequestedBaseUnits,
    required this.excessBaseUnits,
    required this.conflictingItems,
  });

  factory SharedStockConflict.fromJson(Map<String, dynamic> json) {
    return SharedStockConflict(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? 'Producto compartido',
      totalSharedPool: json['total_shared_pool'] ?? 0,
      totalRequestedBaseUnits: json['total_requested_base_units'] ?? 0,
      excessBaseUnits: json['excess_base_units'] ?? 0,
      conflictingItems: (json['conflicting_items'] as List?)
              ?.map((e) => QuoteItemConflictDetail.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'total_shared_pool': totalSharedPool,
    'total_requested_base_units': totalRequestedBaseUnits,
    'excess_base_units': excessBaseUnits,
    'conflicting_items': conflictingItems.map((e) => e.toJson()).toList(),
  };
}

class QuoteItemConflictDetail {
  final int itemId;
  final int presentationId;
  final String presentationName;
  final int requestedQty;
  final int conversionFactor;
  final int requestedBaseUnits;
  final int? cupoMaximo;

  const QuoteItemConflictDetail({
    required this.itemId,
    required this.presentationId,
    required this.presentationName,
    required this.requestedQty,
    required this.conversionFactor,
    required this.requestedBaseUnits,
    this.cupoMaximo,
  });

  factory QuoteItemConflictDetail.fromJson(Map<String, dynamic> json) {
    return QuoteItemConflictDetail(
      itemId: json['item_id'] ?? 0,
      presentationId: json['presentation_id'] ?? 0,
      presentationName: json['presentation_name'] ?? '',
      requestedQty: json['requested_qty'] ?? 0,
      conversionFactor: json['conversion_factor'] ?? 1,
      requestedBaseUnits: json['requested_base_units'] ?? 0,
      cupoMaximo: json['cupo_maximo'],
    );
  }

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'presentation_id': presentationId,
    'presentation_name': presentationName,
    'requested_qty': requestedQty,
    'conversion_factor': conversionFactor,
    'requested_base_units': requestedBaseUnits,
    'cupo_maximo': cupoMaximo,
  };
}

class UnitChange {
  final int itemId;
  final String productName;
  final String oldUnit;
  final String newUnit;
  final int oldFactor;
  final int newFactor;
  final String message;

  UnitChange({
    required this.itemId,
    required this.productName,
    required this.oldUnit,
    required this.newUnit,
    this.oldFactor = 1,
    this.newFactor = 1,
    this.message = "",
  });

  factory UnitChange.fromJson(Map<String, dynamic> json) {
    return UnitChange(
      itemId: json['item_id'] ?? -1,
      productName: json['product_name'] ?? 'Desconocido',
      oldUnit: json['old_unit'] ?? 'Unidad',
      newUnit: json['new_unit'] ?? 'Unidad',
      oldFactor: json['old_factor'] ?? 1,
      newFactor: json['new_factor'] ?? 1,
      message: json['message'] ?? "",
    );
  }
}

class NameChange {
  final int itemId;
  final String oldName;
  final String newName;
  final String message;

  NameChange({
    required this.itemId,
    required this.oldName,
    required this.newName,
    this.message = "",
  });

  factory NameChange.fromJson(Map<String, dynamic> json) {
    return NameChange(
      itemId: json['item_id'] ?? -1,
      oldName: json['old_name'] ?? 'Desconocido',
      newName: json['new_name'] ?? 'Desconocido',
      message: json['message'] ?? "",
    );
  }
}

class PriceChange {
  final int itemId;
  final String productName;
  final double oldPrice;
  final double newPrice;
  final double newBasePrice; 
  final String message;      

  PriceChange({
    required this.itemId, required this.productName, required this.oldPrice, required this.newPrice, 
    this.newBasePrice = 0.0, this.message = ""
  });

  factory PriceChange.fromJson(Map<String, dynamic> json) {
    return PriceChange(
      itemId: json['item_id'] ?? -1,
      productName: json['product_name'] ?? 'Desconocido',
      oldPrice: parseCrmDouble(json['old_price']),
      newPrice: parseCrmDouble(json['new_price']),
      newBasePrice: parseCrmDouble(json['new_base_price']),
      message: json['message'] ?? "",
    );
  }
}

class StockWarning {
  final int itemId;
  final String productName;
  final int requested;
  final int available;
  final String message; 

  StockWarning({required this.itemId, required this.productName, required this.requested, required this.available, this.message = ""});

  factory StockWarning.fromJson(Map<String, dynamic> json) {
    return StockWarning(
      itemId: json['item_id'] ?? -1,
      productName: json['product_name'] ?? 'Desconocido',
      requested: json['requested_qty'] ?? 0,
      available: json['available_stock'] ?? 0,
      message: json['message'] ?? "",
    );
  }
}
