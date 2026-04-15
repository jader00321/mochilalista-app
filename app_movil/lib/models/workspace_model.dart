class WorkspaceModel {
  final int negocioId;
  final String nombreNegocio;
  final String rol;
  final String? logoUrl;
  final String estadoAcceso;

  WorkspaceModel({
    required this.negocioId,
    required this.nombreNegocio,
    required this.rol,
    this.logoUrl,
    required this.estadoAcceso,
  });

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      negocioId: json['negocio_id'],
      nombreNegocio: json['nombre_negocio'],
      rol: json['rol'],
      logoUrl: json['logo_url'],
      estadoAcceso: json['estado_acceso'] ?? 'activo',
    );
  }
}