class ProviderModel {
  final int id;
  final int? idNegocio;
  final String nombreEmpresa;
  final String? contactoNombre;
  final String? telefono;
  final String? correo;
  final String? ruc;
  final DateTime? fechaCreacion;
  final bool activo;
  final int productsCount; // Nuevo

  ProviderModel({
    required this.id,
    this.idNegocio,
    required this.nombreEmpresa,
    this.contactoNombre,
    this.telefono,
    this.correo,
    this.ruc,
    this.fechaCreacion,
    this.activo = true,
    this.productsCount = 0,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] ?? 0,
      idNegocio: json['negocio_id'] ?? json['id_negocio'], 
      nombreEmpresa: json['nombre_empresa'] ?? '',
      contactoNombre: json['contacto_nombre'],
      telefono: json['telefono'],
      correo: json['email'] ?? json['correo_electronico'], 
      ruc: json['ruc'],
      fechaCreacion: json['fecha_creacion'] != null 
          ? DateTime.tryParse(json['fecha_creacion'].toString()) 
          : null,
      activo: json['activo'] ?? true,
      productsCount: json['products_count'] ?? 0,
    );
  }
}