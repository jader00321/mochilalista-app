class Category {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int productsCount;

  Category({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.activo = true,
    this.productsCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      activo: json['activo'] == 1 || json['activo'] == true,
      productsCount: json['products_count'] ?? 0,
    );
  }

  Map<String, dynamic> toSqlite(int negocioId) {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo ? 1 : 0,
    };
  }
}