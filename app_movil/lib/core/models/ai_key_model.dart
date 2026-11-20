class AiKeyModel {
  final String id;
  final String alias;
  final String apiKey;
  final DateTime createdAt;
  final DateTime? lastTestedAt;
  final bool? isWorking;

  const AiKeyModel({
    required this.id,
    required this.alias,
    required this.apiKey,
    required this.createdAt,
    this.lastTestedAt,
    this.isWorking,
  });

  /// Máscara visual obligatoria: muestra los primeros 6 y los últimos 4 caracteres.
  /// Jamás expone la clave completa en texto plano en la interfaz de usuario.
  String get maskedKey {
    final clean = apiKey.trim();
    if (clean.length >= 10) {
      final prefix = clean.substring(0, 6);
      final suffix = clean.substring(clean.length - 4);
      return '$prefix••••••••$suffix';
    } else if (clean.length >= 4) {
      final prefix = clean.substring(0, 2);
      final suffix = clean.substring(clean.length - 2);
      return '$prefix••••$suffix';
    }
    return '••••••••';
  }

  AiKeyModel copyWith({
    String? id,
    String? alias,
    String? apiKey,
    DateTime? createdAt,
    DateTime? lastTestedAt,
    bool? isWorking,
    bool clearLastTestedAt = false,
  }) {
    return AiKeyModel(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      apiKey: apiKey ?? this.apiKey,
      createdAt: createdAt ?? this.createdAt,
      lastTestedAt: clearLastTestedAt ? null : (lastTestedAt ?? this.lastTestedAt),
      isWorking: clearLastTestedAt ? null : (isWorking ?? this.isWorking),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alias': alias,
      'api_key': apiKey,
      'created_at': createdAt.toIso8601String(),
      'last_tested_at': lastTestedAt?.toIso8601String(),
      'is_working': isWorking == null ? null : (isWorking! ? 1 : 0),
    };
  }

  factory AiKeyModel.fromMap(Map<String, dynamic> map) {
    return AiKeyModel(
      id: map['id'] as String? ?? '',
      alias: map['alias'] as String? ?? 'Clave Gemini',
      apiKey: (map['api_key'] ?? map['apiKey']) as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      lastTestedAt: map['last_tested_at'] != null
          ? DateTime.tryParse(map['last_tested_at'] as String)
          : null,
      isWorking: map['is_working'] == null
          ? null
          : (map['is_working'] is bool
              ? map['is_working'] as bool
              : (map['is_working'] as num).toInt() == 1),
    );
  }
}
