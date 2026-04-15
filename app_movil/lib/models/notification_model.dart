class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  bool isRead;
  final DateTime createdAt;
  
  // 🔥 NUEVOS CAMPOS: DEEP LINKING
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
      isRead: json['leida'] ?? false,
      createdAt: DateTime.parse(json['fecha_creacion']).toLocal(),
      prioridad: json['prioridad'] ?? 'Media',
      objetoRelacionadoTipo: json['objeto_relacionado_tipo'],
      objetoRelacionadoId: json['objeto_relacionado_id'],
    );
  }
}