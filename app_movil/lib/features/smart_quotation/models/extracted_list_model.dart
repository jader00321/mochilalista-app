import 'package:flutter/material.dart';

enum QuotationContextMode {
  general,   // 🛒 Pedido General / Lista de compras / Abarrotes / Ferretería / Bazar
  wholesale, // 📦 Mayorista / Negocio / Bodega / B2B
  school,    // 🎓 Lista Escolar de útiles y papelería
}

extension QuotationContextModeExt on QuotationContextMode {
  String get label {
    switch (this) {
      case QuotationContextMode.general:
        return 'Pedido General';
      case QuotationContextMode.wholesale:
        return 'Mayorista / Negocio';
      case QuotationContextMode.school:
        return 'Lista Escolar';
    }
  }

  IconData get icon {
    switch (this) {
      case QuotationContextMode.general:
        return Icons.shopping_bag_outlined;
      case QuotationContextMode.wholesale:
        return Icons.storefront_rounded;
      case QuotationContextMode.school:
        return Icons.school_outlined;
    }
  }

  static QuotationContextMode fromString(String? val) {
    if (val == null) return QuotationContextMode.general;
    final lower = val.trim().toLowerCase();
    if (lower.contains('wholesale') || lower.contains('mayor') || lower.contains('b2b') || lower.contains('negocio')) {
      return QuotationContextMode.wholesale;
    }
    if (lower.contains('school') || lower.contains('escolar') || lower.contains('colegio') || lower.contains('util')) {
      return QuotationContextMode.school;
    }
    return QuotationContextMode.general;
  }
}

class SchoolListAnalysisResponse {
  final ExtractedMetadata metadata;
  final List<ExtractedItem> items;

  SchoolListAnalysisResponse({required this.metadata, required this.items});

  factory SchoolListAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return SchoolListAnalysisResponse(
      metadata: ExtractedMetadata.fromJson(json['metadata'] ?? {}),
      items: (json['items'] as List?)
              ?.map((i) => ExtractedItem.fromJson(i))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class ExtractedMetadata {
  QuotationContextMode contextMode;
  String? clientOrContactName;
  String? businessOrInstitutionName;
  String? phone;
  String? referenceNotes;

  // 🔄 Retrocompatibilidad estricta con código previo y SQLite (Vector A7)
  String? get institutionName => businessOrInstitutionName;
  set institutionName(String? val) => businessOrInstitutionName = val;

  String? get studentName => clientOrContactName;
  set studentName(String? val) => clientOrContactName = val;

  String? get gradeLevel => referenceNotes;
  set gradeLevel(String? val) => referenceNotes = val;

  ExtractedMetadata({
    this.contextMode = QuotationContextMode.general,
    this.clientOrContactName,
    this.businessOrInstitutionName,
    this.phone,
    this.referenceNotes,
    String? institutionName,
    String? studentName,
    String? gradeLevel,
  }) {
    if (institutionName != null && businessOrInstitutionName == null) {
      businessOrInstitutionName = institutionName;
    }
    if (studentName != null && clientOrContactName == null) {
      clientOrContactName = studentName;
    }
    if (gradeLevel != null && referenceNotes == null) {
      referenceNotes = gradeLevel;
    }
  }

  factory ExtractedMetadata.fromJson(Map<String, dynamic> json) {
    final modeRaw = json['detected_mode'] ?? json['context_mode'] ?? json['quotation_type'];
    QuotationContextMode mode;
    if (modeRaw != null) {
      mode = QuotationContextModeExt.fromString(modeRaw.toString());
    } else if (json['institution_name'] != null || json['grade_level'] != null) {
      mode = QuotationContextMode.school;
    } else {
      mode = QuotationContextMode.general;
    }

    final contact = json['client_or_contact_name'] ?? json['contact_name'] ?? json['client_name'] ?? json['student_name'];
    final org = json['business_or_institution_name'] ?? json['organization_name'] ?? json['business_name'] ?? json['institution_name'];
    final ref = json['reference_info'] ?? json['reference_notes'] ?? json['grade_level'];

    return ExtractedMetadata(
      contextMode: mode,
      clientOrContactName: contact?.toString(),
      businessOrInstitutionName: org?.toString(),
      phone: json['phone']?.toString(),
      referenceNotes: ref?.toString(),
      institutionName: org?.toString(),
      studentName: contact?.toString(),
      gradeLevel: ref?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detected_mode': contextMode.name,
      'context_mode': contextMode.name,
      'client_or_contact_name': clientOrContactName,
      'contact_name': clientOrContactName,
      'client_name': clientOrContactName,
      'student_name': studentName,
      'business_or_institution_name': businessOrInstitutionName,
      'organization_name': businessOrInstitutionName,
      'business_name': businessOrInstitutionName,
      'institution_name': institutionName,
      'phone': phone,
      'reference_info': referenceNotes,
      'reference_notes': referenceNotes,
      'grade_level': gradeLevel,
    };
  }

  ExtractedMetadata copyWith({
    QuotationContextMode? contextMode,
    String? clientOrContactName,
    String? businessOrInstitutionName,
    String? phone,
    String? referenceNotes,
    String? institutionName,
    String? studentName,
    String? gradeLevel,
  }) {
    return ExtractedMetadata(
      contextMode: contextMode ?? this.contextMode,
      clientOrContactName: clientOrContactName ?? this.clientOrContactName,
      businessOrInstitutionName: businessOrInstitutionName ?? this.businessOrInstitutionName,
      phone: phone ?? this.phone,
      referenceNotes: referenceNotes ?? this.referenceNotes,
      institutionName: institutionName ?? this.institutionName,
      studentName: studentName ?? this.studentName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
    );
  }

  ExtractedMetadata clone() {
    return ExtractedMetadata(
      contextMode: contextMode,
      clientOrContactName: clientOrContactName,
      businessOrInstitutionName: businessOrInstitutionName,
      phone: phone,
      referenceNotes: referenceNotes,
      institutionName: institutionName,
      studentName: studentName,
      gradeLevel: gradeLevel,
    );
  }
}

class ExtractedItem {
  int id;
  String originalText;
  String fullName;
  String? brand;
  int quantity;
  String? unit;
  String? notes;

  ExtractedItem({
    required this.id,
    required this.originalText,
    required this.fullName,
    this.brand,
    this.quantity = 1,
    this.unit,
    this.notes,
  });

  factory ExtractedItem.fromJson(Map<String, dynamic> json) {
    return ExtractedItem(
      id: json['id'] ?? 0,
      originalText: json['original_text'] ?? '',
      fullName: json['full_name'] ?? '',
      brand: json['brand'],
      quantity: json['quantity'] ?? 1,
      unit: json['unit'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_text': originalText,
      'full_name': fullName,
      'brand': brand,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
    };
  }

  ExtractedItem clone() {
    return ExtractedItem(
      id: id,
      originalText: originalText,
      fullName: fullName,
      brand: brand,
      quantity: quantity,
      unit: unit,
      notes: notes,
    );
  }
}