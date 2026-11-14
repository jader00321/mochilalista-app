import 'dart:convert';

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type; // 'alerta', 'exito', 'info', 'advertencia'
  bool isRead;
  bool isResolved;
  bool isArchived;
  final DateTime? fechaArchivado;
  bool isSilenced;
  final DateTime? fechaSilenciado;
  final String? muteKey;
  final DateTime createdAt;
  final DateTime? fechaResolucion;
  final String prioridad; // 'Alta', 'Media', 'Baja'
  final String nivelPrioridad; // 'critica', 'preventiva', 'informativa', 'sistema'
  final String? dedupKey;
  final String? objetoRelacionadoTipo; // 'cuota', 'producto', 'cotizacion', 'recompensa'
  final int? objetoRelacionadoId;
  final String? metadataJson;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.isResolved = false,
    this.isArchived = false,
    this.fechaArchivado,
    this.isSilenced = false,
    this.fechaSilenciado,
    this.muteKey,
    required this.createdAt,
    this.fechaResolucion,
    required this.prioridad,
    this.nivelPrioridad = 'informativa',
    this.dedupKey,
    this.objetoRelacionadoTipo,
    this.objetoRelacionadoId,
    this.metadataJson,
  });

  /// Determina si una notificación requiere acción del comerciante.
  bool get isActionable {
    if (type == 'alerta') return true;
    if (nivelPrioridad == 'critica' || nivelPrioridad == 'preventiva') return true;
    return false;
  }

  /// Categoría canónica del ítem: 'inventario', 'cobranza', 'cotizacion' o 'general'
  String get categoria {
    if (objetoRelacionadoTipo == 'producto') return 'inventario';
    if (objetoRelacionadoTipo == 'cuota') return 'cobranza';
    if (objetoRelacionadoTipo == 'cotizacion') return 'cotizacion';
    if (objetoRelacionadoTipo == 'recompensa') return 'recompensa';
    return 'general';
  }

  /// Título limpio sin prefijos de emojis residuales (⚠️, 🚨, 💰, 📦, etc.)
  String get cleanTitle {
    return title.replaceAll(RegExp(r'^(💰|⚠️|🚨|📋|✅|📦)\s*'), '').trim();
  }

  /// Fecha hasta la cual la alerta fue pospuesta (Snooze)
  DateTime? get snoozedUntil {
    final s = metadata['snoozed_until']?.toString();
    return s != null ? DateTime.tryParse(s)?.toLocal() : null;
  }

  /// Indica si la notificación está actualmente en periodo de posposición
  bool get isSnoozed {
    final su = snoozedUntil;
    return su != null && su.isAfter(DateTime.now());
  }

  /// Clave canónica de silenciamiento para bloquear futuras alertas del mismo ítem
  String get effectiveMuteKey {
    if (muteKey != null && muteKey!.isNotEmpty) return muteKey!;
    final tipo = objetoRelacionadoTipo?.toLowerCase() ?? 'general';
    final id = objetoRelacionadoId ?? 0;
    return '${tipo}_$id';
  }

  Map<String, dynamic>? _cachedMetadata;
  Map<String, dynamic> get metadata {
    if (_cachedMetadata != null) return _cachedMetadata!;
    if (metadataJson == null || metadataJson!.isEmpty) {
      _cachedMetadata = {};
      return _cachedMetadata!;
    }
    try {
      _cachedMetadata = jsonDecode(metadataJson!) as Map<String, dynamic>;
    } catch (_) {
      _cachedMetadata = {};
    }
    return _cachedMetadata!;
  }

  // Getters tipados seguros para In-Card Actions
  int? get clientId => (metadata['cliente_id'] as num?)?.toInt();
  String? get clientName => metadata['cliente_nombre'] as String?;
  String? get clientPhone => metadata['cliente_telefono'] as String?;
  int? get cuotaNumero => (metadata['cuota_numero'] as num?)?.toInt();
  int? get ventaId => (metadata['venta_id'] as num?)?.toInt();
  String? get folioOperacion => metadata['folio_operacion'] as String?;
  bool get esPrestamo => metadata['es_prestamo'] == true || metadata['es_prestamo'] == 1;
  double? get montoBase => (metadata['monto_base'] as num?)?.toDouble();
  double get moraAcumulada => (metadata['mora_acumulada'] as num?)?.toDouble() ?? 0.0;
  double? get saldoTotal => (metadata['saldo_total'] as num?)?.toDouble();
  int get diasAtraso => (metadata['dias_atraso'] as num?)?.toInt() ?? 0;
  String? get fechaVencimiento => metadata['fecha_vencimiento'] as String?;
  int? get stockActual => (metadata['stock_actual'] as num?)?.toInt();
  int? get stockUmbral => (metadata['stock_umbral'] as num?)?.toInt();

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final res = json['is_resolved'];
    final isRes = res == 1 || res == true;
    final resDateStr = json['fecha_resolucion'] as String?;
    final prio = json['prioridad'] ?? 'Media';

    final isArch = json['is_archived'] == 1 || json['is_archived'] == true;
    final archDateStr = json['fecha_archivado'] as String?;
    final isSil = json['is_silenced'] == 1 || json['is_silenced'] == true;
    final silDateStr = json['fecha_silenciado'] as String?;
    final mKey = json['mute_key'] as String?;
    
    String nivel = json['nivel_prioridad'] ?? '';
    if (nivel.isEmpty) {
      if (json['tipo'] == 'alerta') {
        nivel = (prio == 'Alta') ? 'critica' : 'preventiva';
      } else if (json['tipo'] == 'exito') {
        nivel = 'informativa';
      } else {
        nivel = 'sistema';
      }
    }

    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['titulo'] ?? 'Notificación',
      message: json['mensaje'] ?? '',
      type: json['tipo'] ?? 'info',
      isRead: json['leida'] == 1 || json['leida'] == true,
      isResolved: isRes,
      isArchived: isArch,
      fechaArchivado: archDateStr != null ? DateTime.tryParse(archDateStr)?.toLocal() : null,
      isSilenced: isSil,
      fechaSilenciado: silDateStr != null ? DateTime.tryParse(silDateStr)?.toLocal() : null,
      muteKey: mKey,
      createdAt: DateTime.tryParse(json['fecha_creacion']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      fechaResolucion: resDateStr != null ? DateTime.tryParse(resDateStr)?.toLocal() : null,
      prioridad: prio,
      nivelPrioridad: nivel,
      dedupKey: json['dedup_key'] as String?,
      objetoRelacionadoTipo: json['objeto_relacionado_tipo'] as String?,
      objetoRelacionadoId: json['objeto_relacionado_id'] as int?,
      metadataJson: json['metadata_json'] as String?,
    );
  }

  Map<String, dynamic> toSqlite(int userId, int negocioId) {
    return {
      'id': id == 0 ? null : id,
      'user_id': userId,
      'negocio_id': negocioId,
      'dedup_key': dedupKey,
      'titulo': title,
      'mensaje': message,
      'tipo': type,
      'nivel_prioridad': nivelPrioridad,
      'leida': isRead ? 1 : 0,
      'is_resolved': isResolved ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'fecha_archivado': fechaArchivado?.toUtc().toIso8601String(),
      'is_silenced': isSilenced ? 1 : 0,
      'fecha_silenciado': fechaSilenciado?.toUtc().toIso8601String(),
      'mute_key': muteKey ?? effectiveMuteKey,
      'fecha_creacion': createdAt.toUtc().toIso8601String(),
      'fecha_resolucion': fechaResolucion?.toUtc().toIso8601String(),
      'prioridad': prioridad,
      'objeto_relacionado_tipo': objetoRelacionadoTipo,
      'objeto_relacionado_id': objetoRelacionadoId,
      'metadata_json': metadataJson,
    };
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    bool? isResolved,
    bool? isArchived,
    DateTime? fechaArchivado,
    bool? isSilenced,
    DateTime? fechaSilenciado,
    String? muteKey,
    DateTime? createdAt,
    DateTime? fechaResolucion,
    String? prioridad,
    String? nivelPrioridad,
    String? dedupKey,
    String? objetoRelacionadoTipo,
    int? objetoRelacionadoId,
    String? metadataJson,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
      isArchived: isArchived ?? this.isArchived,
      fechaArchivado: fechaArchivado ?? this.fechaArchivado,
      isSilenced: isSilenced ?? this.isSilenced,
      fechaSilenciado: fechaSilenciado ?? this.fechaSilenciado,
      muteKey: muteKey ?? this.muteKey,
      createdAt: createdAt ?? this.createdAt,
      fechaResolucion: fechaResolucion ?? this.fechaResolucion,
      prioridad: prioridad ?? this.prioridad,
      nivelPrioridad: nivelPrioridad ?? this.nivelPrioridad,
      dedupKey: dedupKey ?? this.dedupKey,
      objetoRelacionadoTipo: objetoRelacionadoTipo ?? this.objetoRelacionadoTipo,
      objetoRelacionadoId: objetoRelacionadoId ?? this.objetoRelacionadoId,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }
}
