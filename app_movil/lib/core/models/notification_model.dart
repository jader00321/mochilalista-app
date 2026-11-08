import 'dart:convert';

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type; // 'alerta', 'exito', 'info', 'advertencia'
  bool isRead;
  bool isResolved;
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
      'fecha_creacion': createdAt.toUtc().toIso8601String(),
      'fecha_resolucion': fechaResolucion?.toUtc().toIso8601String(),
      'prioridad': prioridad,
      'objeto_relacionado_tipo': objetoRelacionadoTipo,
      'objeto_relacionado_id': objetoRelacionadoId,
      'metadata_json': metadataJson,
    };
  }
}
