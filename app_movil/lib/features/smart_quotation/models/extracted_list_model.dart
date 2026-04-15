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
}

class ExtractedMetadata {
  String? institutionName;
  String? studentName;
  String? gradeLevel;

  ExtractedMetadata({this.institutionName, this.studentName, this.gradeLevel});

  factory ExtractedMetadata.fromJson(Map<String, dynamic> json) {
    return ExtractedMetadata(
      institutionName: json['institution_name'],
      studentName: json['student_name'],
      gradeLevel: json['grade_level'],
    );
  }

  // MÉTODO PARA RESPALDO
  ExtractedMetadata clone() {
    return ExtractedMetadata(
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

  // MÉTODO PARA RESPALDO PROFUNDO
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