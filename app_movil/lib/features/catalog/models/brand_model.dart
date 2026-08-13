class Brand {
  final int id;
  final String nombre;
  final String? urlImagen;
  final bool activo;
  final int productsCount;

  Brand({
    required this.id,
    required this.nombre,
    this.urlImagen,
    this.activo = true,
    this.productsCount = 0,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      urlImagen: json['imagen_url'] ?? json['urlImagen'],
      activo: json['activo'] == 1 || json['activo'] == true,
      productsCount: json['products_count'] ?? 0,
    );
  }

  Map<String, dynamic> toSqlite(int negocioId) {
    return {
      'id': id == 0 ? null : id, 
      'negocio_id': negocioId,
      'nombre': nombre,
      'imagen_url': urlImagen,
      'activo': activo ? 1 : 0,
    };
  }
}