import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';

class SmartQuotationModel {
  final int id;
  final int? sequentialNumber;
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
  final QuotationContextMode? explicitContextMode;

  String get displayId => sequentialNumber != null ? sequentialNumber.toString() : id.toString();

  QuotationContextMode get contextMode {
    if (explicitContextMode != null) return explicitContextMode!;
    if (notas != null) {
      final lowerNotas = notas!.toLowerCase();
      if (lowerNotas.contains('[modo:wholesale]') || lowerNotas.contains('[modo:mayorista]') || lowerNotas.contains('[mayorista]')) {
        return QuotationContextMode.wholesale;
      }
      if (lowerNotas.contains('[modo:general]')) {
        return QuotationContextMode.general;
      }
      if (lowerNotas.contains('[modo:school]') || lowerNotas.contains('[modo:escolar]')) {
        return QuotationContextMode.school;
      }
    }
    if (institutionName != null && institutionName!.isNotEmpty) {
      final lower = institutionName!.toLowerCase();
      if (lower.contains('ruc') || lower.contains('bodega') || lower.contains('empresa') || lower.contains('comercial') || lower.contains('distribuidora') || lower.contains('s.a.') || lower.contains('s.a.c.') || lower.contains('e.i.r.l.')) {
        return QuotationContextMode.wholesale;
      }
      if (lower.contains('colegio') || lower.contains('i.e.') || lower.contains('escuela') || lower.contains('instituto')) {
        return QuotationContextMode.school;
      }
    }
    if (gradeLevel != null && gradeLevel!.isNotEmpty) {
      final lower = gradeLevel!.toLowerCase();
      if (lower.contains('grado') || lower.contains('prim') || lower.contains('sec') || lower.contains('inicial') || lower.contains('básico') || lower.contains('kinder')) {
        return QuotationContextMode.school;
      }
      return QuotationContextMode.general;
    }
    return QuotationContextMode.general;
  }

  /// Devuelve las notas limpias sin los tags internos de modo ([modo:general], etc.)
  String get displayNotas => (notas ?? "").replaceAll(RegExp(r'\[modo:\w+\]\s*'), '').replaceAll(RegExp(r'\[mayorista\]\s*'), '').trim();

  SmartQuotationModel({
    required this.id,
    this.sequentialNumber,
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
    this.explicitContextMode,
  });

  factory SmartQuotationModel.fromJson(Map<String, dynamic> json) {
    var itemsList = <QuotationItem>[];
    if (json['items'] != null) {
      itemsList = (json['items'] as List).map((i) => QuotationItem.fromJson(i)).toList();
    }

    return SmartQuotationModel(
      id: json['id'],
      sequentialNumber: json['numero_secuencial'],
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
      explicitContextMode: json['context_mode'] != null
          ? QuotationContextMode.values.firstWhere((e) => e.name == json['context_mode'].toString(), orElse: () => QuotationContextMode.general)
          : (json['notas'] != null && json['notas'].toString().contains('[modo:general]')
              ? QuotationContextMode.general
              : (json['notas'] != null && (json['notas'].toString().contains('[modo:wholesale]') || json['notas'].toString().contains('[modo:mayorista]') || json['notas'].toString().contains('[mayorista]'))
                  ? QuotationContextMode.wholesale
                  : (json['notas'] != null && (json['notas'].toString().contains('[modo:school]') || json['notas'].toString().contains('[modo:escolar]'))
                      ? QuotationContextMode.school
                      : null))),
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'numero_secuencial': sequentialNumber,
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
  final int? bundleId;
  
  final String? productName;
  final String? brandName;
  final String? specificName;
  final String? salesUnit;
  
  final int quantity;
  final double unitPriceApplied;
  final double originalUnitPrice;
  final bool isAvailable; 
  final bool isManualPrice; 
  final String? originalText;
  final String? imageUrl; 

  QuotationItem({
    required this.id,
    this.productId,
    this.presentationId,
    this.bundleId,
    
    this.productName,
    this.brandName,
    this.specificName,
    this.salesUnit,
    
    required this.quantity,
    required this.unitPriceApplied,
    required this.originalUnitPrice,
    this.isAvailable = true,
    this.isManualPrice = false,
    this.originalText,
    this.imageUrl, 
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    return QuotationItem(
      id: json['id'],
      productId: json['product_id'],
      presentationId: json['presentation_id'],
      bundleId: json['bundle_id'],
      
      productName: json['product_name'],
      brandName: json['brand_name'],
      specificName: json['specific_name'],
      salesUnit: json['sales_unit'],
      
      quantity: json['quantity'] ?? 1,
      unitPriceApplied: (json['unit_price_applied'] ?? 0.0).toDouble(),
      originalUnitPrice: (json['original_unit_price'] ?? 0.0).toDouble(),
      isAvailable: json['is_available'] == 1 || json['is_available'] == true || json['is_available'] == null, 
      isManualPrice: json['is_manual_price'] == 1 || json['is_manual_price'] == true,
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
      'bundle_id': bundleId,
      'quantity': quantity,
      'unit_price_applied': unitPriceApplied,
      'original_unit_price': originalUnitPrice,
      'product_name': productName,
      'brand_name': brandName,
      'specific_name': specificName,
      'sales_unit': salesUnit,
      'original_text': originalText,
      'image_url': imageUrl,
      'is_manual_price': isManualPrice ? 1 : 0, 
      'is_available': isAvailable ? 1 : 0,
    };
  }

  /// Genera un nombre de producto limpio, elegante y profesional (Vector A4),
  /// deduplicando tokens redundantes entre el nombre base, la marca y la presentación.
  String get displayNameClean {
    final baseProduct = (productName ?? "Producto Desconocido").trim();
    if (baseProduct.isEmpty) return "Producto Desconocido";

    final brand = (brandName != null && brandName != "null") ? brandName!.trim() : "";
    final specific = (specificName != null && specificName != "null") ? specificName!.trim() : "";

    // Normalizador de tokens para comparación insensible a mayúsculas y acentos
    String norm(String s) => s.toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'[^\w\s]'), '');

    final productNorm = norm(baseProduct);
    final productTokens = productNorm.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

    // 1. Verificar si la marca ya está contenida en el nombre del producto
    String? brandToAdd;
    if (brand.isNotEmpty) {
      final brandNorm = norm(brand);
      final brandTokens = brandNorm.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
      final isBrandContained = brandTokens.isNotEmpty && brandTokens.every((t) => productTokens.contains(t) || productNorm.contains(t));
      if (!isBrandContained) {
        brandToAdd = brand;
      }
    }

    // 2. Extraer partes no redundantes de specificName
    String? specificToAdd;
    if (specific.isNotEmpty) {
      if (norm(specific) != productNorm && (brandToAdd == null || norm(specific) != norm(brandToAdd))) {
        final specificWords = specific.split(RegExp(r'\s+'));
        final keptWords = <String>[];
        for (final word in specificWords) {
          final wNorm = norm(word);
          if (wNorm.isEmpty) continue;
          final inProduct = productTokens.contains(wNorm) || productNorm.contains(wNorm);
          final inBrand = brand.isNotEmpty && norm(brand).contains(wNorm);
          if (!inProduct && !inBrand) {
            keptWords.add(word);
          }
        }
        if (keptWords.isNotEmpty) {
          specificToAdd = keptWords.join(' ');
        }
      }
    }

    final details = <String>[];
    if (brandToAdd != null && brandToAdd.isNotEmpty) {
      details.add(brandToAdd);
    }
    if (specificToAdd != null && specificToAdd.isNotEmpty) {
      details.add(specificToAdd);
    }

    if (details.isEmpty) {
      return baseProduct;
    }

    return "$baseProduct (${details.join(' • ')})";
  }

  String get displayName => displayNameClean;
}