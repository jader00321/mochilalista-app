import 'extracted_list_model.dart';

enum MatchStatus {
  auto,       
  suggestion, 
  manual,     
  none        
}

class MatchedProduct {
  final int productId;
  final int presentationId;
  final String fullName; 
  final String productName;
  final String? specificName;
  final String? brand;
  final double price; 
  final double? offerPrice; 
  final int stock;
  final String? imageUrl;
  final String unit; 
  final int conversionFactor;
  final bool isAvailable;

  MatchedProduct({
    required this.productId,
    required this.presentationId,
    required this.fullName,
    this.productName = "",
    this.specificName,
    this.brand,
    required this.price,
    this.offerPrice,
    required this.stock,
    this.imageUrl,
    this.unit = "Unidad",
    this.conversionFactor = 1,
    this.isAvailable = true,
  });

  factory MatchedProduct.fromJson(Map<String, dynamic> json) {
    String full = json['full_name'] ?? '';
    String pName = json['product_name'] ?? full;
    String? sName = json['specific_name'];

    return MatchedProduct(
      productId: json['product_id'] ?? 0,
      presentationId: json['presentation_id'] ?? 0,
      fullName: full,
      productName: pName,
      specificName: sName,
      brand: json['brand'],
      price: (json['price'] ?? 0.0).toDouble(),
      offerPrice: json['offer_price'] != null ? (json['offer_price'] as num).toDouble() : null,
      stock: json['stock'] ?? 0,
      imageUrl: json['image_url'],
      unit: json['unit'] ?? "Unidad",
      conversionFactor: json['conversion_factor'] ?? 1,
      isAvailable: json['is_available'] ?? true,
    );
  }

  // 🔥 Nombre limpio sin la unidad repetida
  String get displayNameClean {
    final buffer = StringBuffer();
    buffer.write(productName);
    if (brand != null && brand!.isNotEmpty && brand != "null") buffer.write(" $brand");
    if (specificName != null && specificName!.isNotEmpty) buffer.write(" $specificName");
    return buffer.toString().trim();
  }

  String get displayNameCard => "$displayNameClean ($unit)";
  String get displayNameSearch => "$displayNameClean - $unit";

  MatchedProduct clone() {
    return MatchedProduct(
      productId: productId, presentationId: presentationId, fullName: fullName,
      productName: productName, specificName: specificName, brand: brand,
      price: price, offerPrice: offerPrice, stock: stock, imageUrl: imageUrl,
      unit: unit, conversionFactor: conversionFactor, isAvailable: isAvailable,
    );
  }
}

class BackendMatchResult {
  final int itemId;
  final String matchTypeString; 
  final int score;
  final MatchedProduct? suggestedProduct;
  final int? suggestedQuantity; // 🔥 SOLUCIÓN AL ERROR DE COMPILACIÓN (Añadido para recibir desde Python)

  BackendMatchResult({
    required this.itemId, 
    required this.matchTypeString, 
    required this.score, 
    this.suggestedProduct,
    this.suggestedQuantity // 🔥 Agregado al constructor
  });

  factory BackendMatchResult.fromJson(Map<String, dynamic> json) {
    return BackendMatchResult(
      itemId: json['item_id'], 
      matchTypeString: json['match_type'], 
      score: json['score'] ?? 0,
      suggestedProduct: json['suggested_product'] != null ? MatchedProduct.fromJson(json['suggested_product']) : null,
      suggestedQuantity: json['suggested_quantity'], // 🔥 Parseado desde el JSON del backend
    );
  }
}

class MatchPair {
  final ExtractedItem sourceItem; 
  MatchedProduct? selectedProduct; 
  MatchStatus status;
  int selectedQuantity; 
  double? overridePrice; 

  MatchPair({
    required this.sourceItem,
    this.selectedProduct,
    this.status = MatchStatus.none,
  }) : selectedQuantity = sourceItem.quantity;

  double get effectiveUnitPrice {
    if (overridePrice != null) return overridePrice!;
    if (selectedProduct != null) return selectedProduct!.offerPrice ?? selectedProduct!.price;
    return 0.0;
  }

  double get originalUnitPrice {
    return selectedProduct?.price ?? 0.0;
  }

  double get subtotal {
    return double.parse((effectiveUnitPrice * selectedQuantity).toStringAsFixed(2));
  }

  double get totalSavings {
    if (selectedProduct == null) return 0.0;
    double originalTotal = originalUnitPrice * selectedQuantity;
    return double.parse((originalTotal - subtotal).toStringAsFixed(2)); 
  }

  bool get hasDiscount => totalSavings > 0.009; 

  bool get isModified => overridePrice != null || selectedQuantity != sourceItem.quantity || status == MatchStatus.manual;

  bool get hasStockWarning => selectedProduct != null && (selectedProduct!.stock < selectedQuantity || !selectedProduct!.isAvailable);

  MatchPair clone() {
    MatchPair copy = MatchPair(
      sourceItem: sourceItem.clone(),
      selectedProduct: selectedProduct?.clone(),
      status: status,
    );
    copy.selectedQuantity = selectedQuantity;
    copy.overridePrice = overridePrice;
    return copy;
  }

  Map<String, dynamic>? toQuotationItemJson() {
    if (selectedProduct == null) return null;

    return {
      "product_id": selectedProduct!.productId,
      "presentation_id": selectedProduct!.presentationId,
      "quantity": selectedQuantity,
      "unit_price_applied": effectiveUnitPrice, 
      "original_unit_price": originalUnitPrice, 
      
      // 🔥 ENVÍO ESTRUCTURADO AL BACKEND
      "product_name": selectedProduct!.productName,
      "brand_name": selectedProduct!.brand,
      "specific_name": selectedProduct!.specificName,
      "sales_unit": selectedProduct!.unit,
      
      "original_text": sourceItem.originalText,
      "is_manual_price": overridePrice != null,
      "is_available": selectedProduct!.isAvailable
    };
  }
}