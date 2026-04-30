class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  bool isRead;
  final DateTime createdAt;
  
  final String prioridad;
  final String? objetoRelacionadoTipo;
  final int? objetoRelacionadoId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.prioridad,
    this.objetoRelacionadoTipo,
    this.objetoRelacionadoId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['titulo'] ?? 'Notificación',
      message: json['mensaje'] ?? '',
      type: json['tipo'] ?? 'info',
      isRead: json['leida'] == 1 || json['leida'] == true,
      createdAt: DateTime.parse(json['fecha_creacion']).toLocal(),
      prioridad: json['prioridad'] ?? 'Media',
      objetoRelacionadoTipo: json['objeto_relacionado_tipo'],
      objetoRelacionadoId: json['objeto_relacionado_id'],
    );
  }

  Map<String, dynamic> toSqlite(int userId, int negocioId) {
    return {
      'id': id == 0 ? null : id,
      'user_id': userId,
      'negocio_id': negocioId,
      'titulo': title,
      'mensaje': message,
      'tipo': type,
      'leida': isRead ? 1 : 0,
      'fecha_creacion': createdAt.toUtc().toIso8601String(),
      'prioridad': prioridad,
      'objeto_relacionado_tipo': objetoRelacionadoTipo,
      'objeto_relacionado_id': objetoRelacionadoId,
    };
  }
}