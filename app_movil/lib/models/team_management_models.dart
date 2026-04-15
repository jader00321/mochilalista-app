// 1. MODELO PARA VER A LOS MIEMBROS DEL EQUIPO (Derivado de NegocioUsuario)
class TeamMemberModel {
  final int usuarioId;
  final String nombre;
  final String rol;
  final String estado;
  final Map<String, dynamic> permisos;

  TeamMemberModel({
    required this.usuarioId,
    required this.nombre,
    required this.rol,
    required this.estado,
    required this.permisos,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      usuarioId: json['usuario_id'] ?? 0,
      nombre: json['nombre'] ?? 'Usuario Desconocido',
      rol: json['rol'] ?? 'trabajador',
      estado: json['estado'] ?? 'activo',
      permisos: json['permisos'] ?? {},
    );
  }

  // Helper para saber rápidamente qué permisos tiene
  bool can(String permissionKey) {
    return permisos[permissionKey] == true;
  }
}

// 2. MODELO PARA LOS CÓDIGOS DE INVITACIÓN (Derivado de CodigosAccesoNegocio)
class AccessCodeModel {
  final int id;
  final String codigo;
  final String rolAOtorgar;
  final int usosMaximos;
  final int usosActuales;
  final DateTime fechaCreacion;
  final DateTime? fechaExpiracion;

  AccessCodeModel({
    required this.id,
    required this.codigo,
    required this.rolAOtorgar,
    required this.usosMaximos,
    required this.usosActuales,
    required this.fechaCreacion,
    this.fechaExpiracion,
  });

  factory AccessCodeModel.fromJson(Map<String, dynamic> json) {
    return AccessCodeModel(
      id: json['id'] ?? 0,
      codigo: json['codigo'] ?? '',
      rolAOtorgar: json['rol_a_otorgar'] ?? 'trabajador',
      usosMaximos: json['usos_maximos'] ?? 1,
      usosActuales: json['usos_actuales'] ?? 0,
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      fechaExpiracion: json['fecha_expiracion'] != null 
          ? DateTime.parse(json['fecha_expiracion']) 
          : null,
    );
  }

  bool get isExpired {
    if (fechaExpiracion == null) return false;
    return DateTime.now().isAfter(fechaExpiracion!);
  }

  bool get isExhausted => usosActuales >= usosMaximos;
}