class SmartQuotationModel {
  final int id;
  final int negocioId; 
  final int creadoPorUsuarioId; 
  final int? clientId;
  final String? clientName; 
  final String? institutionName;
  final String? gradeLevel;
  final String? notas;      
  
  final double totalAmount;
  final double totalSavings;
  
  final String status; 
  final String type;   
  final bool isTemplate;
  final String? sourceImageUrl; 
  final String? originalTextDump;
  
  final String createdAt;
  final int itemCount;
  final List<QuotationItem> items; 

  SmartQuotationModel({
    required this.id,
    required this.negocioId,
    required this.creadoPorUsuarioId,
    this.clientId,
    this.clientName,
    this.institutionName,
    this.gradeLevel,
    this.notas,             
    required this.totalAmount,
    required this.totalSavings,
    required this.status,
    required this.type,
    this.isTemplate = false,
    this.sourceImageUrl,
    this.originalTextDump,
    required this.createdAt,
    this.itemCount = 0,
    this.items = const [],
  });

  factory SmartQuotationModel.fromJson(Map<String, dynamic> json) {
    var itemsList = <QuotationItem>[];
    if (json['items'] != null) {
      itemsList = (json['items'] as List).map((i) => QuotationItem.fromJson(i)).toList();
    }

    return SmartQuotationModel(
      id: json['id'],
      negocioId: json['negocio_id'] ?? 0,
      creadoPorUsuarioId: json['creado_por_usuario_id'] ?? json['user_id'] ?? 0, 
      clientId: json['client_id'],
      clientName: json['client_name'],
      institutionName: json['institution_name'],
      gradeLevel: json['grade_level'],
      notas: json['notas'],                
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      totalSavings: (json['total_savings'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'DRAFT',
      type: json['type'] ?? 'manual',
      isTemplate: json['is_template'] == 1 || json['is_template'] == true, // Soporte SQLite
      sourceImageUrl: json['source_image_url'], 
      originalTextDump: json['original_text_dump'],
      createdAt: json['created_at'] ?? "",
      itemCount: json['items'] != null ? itemsList.length : (json['item_count'] ?? 0),
      items: itemsList,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'creado_por_usuario_id': creadoPorUsuarioId,
      'client_id': clientId,
      'client_name': clientName,
      'institution_name': institutionName,
      'grade_level': gradeLevel,
      'notas': notas,
      'total_amount': totalAmount,
      'total_savings': totalSavings,
      'status': status,
      'type': type,
      'is_template': isTemplate ? 1 : 0,
      'source_image_url': sourceImageUrl,
      'original_text_dump': originalTextDump,
      'created_at': createdAt.isEmpty ? DateTime.now().toIso8601String() : createdAt,
    };
  }

  SmartQuotationModel copyWith({
    int? id,
    int? negocioId,
    int? creadoPorUsuarioId,
    int? clientId,
    String? clientName,
    String? institutionName,
    String? gradeLevel,
    String? notas,
    double? totalAmount,
    double? totalSavings,
    String? status,
    String? type,
    bool? isTemplate,
    String? sourceImageUrl,
    String? originalTextDump,
    String? createdAt,
    int? itemCount,
    List<QuotationItem>? items,
  }) {
    return SmartQuotationModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      creadoPorUsuarioId: creadoPorUsuarioId ?? this.creadoPorUsuarioId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      institutionName: institutionName ?? this.institutionName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      notas: notas ?? this.notas,
      totalAmount: totalAmount ?? this.totalAmount,
      totalSavings: totalSavings ?? this.totalSavings,
      status: status ?? this.status,
      type: type ?? this.type,
      isTemplate: isTemplate ?? this.isTemplate,
      sourceImageUrl: sourceImageUrl ?? this.sourceImageUrl,
      originalTextDump: originalTextDump ?? this.originalTextDump,
      createdAt: createdAt ?? this.createdAt,
      itemCount: itemCount ?? this.itemCount,
      items: items ?? this.items,
    );
  }
  
  bool get isLocked => status == 'SOLD' || status == 'ARCHIVED';
}

class QuotationItem {
  final int id;
  final int? productId;
  final int? presentationId; 
  
  final String? productName;
  final String? brandName;
  final String? specificName;
  final String? salesUnit;
  
  final int quantity;
  final double unitPriceApplied;
  final double originalUnitPrice;
  final bool isAvailable; 
  final String? originalText;
  final String? imageUrl; 

  QuotationItem({
    required this.id,
    this.productId,
    this.presentationId,
    
    this.productName,
    this.brandName,
    this.specificName,
    this.salesUnit,
    
    required this.quantity,
    required this.unitPriceApplied,
    required this.originalUnitPrice,
    this.isAvailable = true,
    this.originalText,
    this.imageUrl, 
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    return QuotationItem(
      id: json['id'],
      productId: json['product_id'],
      presentationId: json['presentation_id'],
      
      productName: json['product_name'],
      brandName: json['brand_name'],
      specificName: json['specific_name'],
      salesUnit: json['sales_unit'],
      
      quantity: json['quantity'] ?? 1,
      unitPriceApplied: (json['unit_price_applied'] ?? 0.0).toDouble(),
      originalUnitPrice: (json['original_unit_price'] ?? 0.0).toDouble(),
      isAvailable: json['is_available'] == 1 || json['is_available'] == true || json['is_available'] == null, 
      originalText: json['original_text'],
      imageUrl: json['image_url'], 
    );
  }

  Map<String, dynamic> toSqlite(int quotationId) {
    return {
      'id': id == 0 ? null : id,
      'quotation_id': quotationId,
      'product_id': productId,
      'presentation_id': presentationId,
      'quantity': quantity,
      'unit_price_applied': unitPriceApplied,
      'original_unit_price': originalUnitPrice,
      'product_name': productName,
      'brand_name': brandName,
      'specific_name': specificName,
      'sales_unit': salesUnit,
      'original_text': originalText,
      'is_manual_price': unitPriceApplied != originalUnitPrice ? 1 : 0, 
      'is_available': isAvailable ? 1 : 0,
    };
  }

  String get displayName {
    final buffer = StringBuffer();
    if (productName != null && productName!.isNotEmpty) {
      buffer.write(productName);
    } else {
      buffer.write("Producto Desconocido");
    }
    
    if (brandName != null && brandName!.isNotEmpty && brandName != "null") {
      buffer.write(" $brandName");
    }
    if (specificName != null && specificName!.isNotEmpty) {
      buffer.write(" $specificName");
    }
    return buffer.toString().trim();
  }
}