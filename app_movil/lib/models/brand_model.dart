class Brand {
  final int id;
  final String nombre;
  final String? urlImagen;
  final bool activo;
  final int productsCount; // Nuevo

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
      // Backend manda 'imagen_url', frontend usa 'urlImagen'
      urlImagen: json['imagen_url'] ?? json['urlImagen'], 
      activo: json['activo'] ?? true,
      productsCount: json['products_count'] ?? 0,
    );
  }
}