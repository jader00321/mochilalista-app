class Category {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int productsCount; // Nuevo

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
      activo: json['activo'] ?? true,
      productsCount: json['products_count'] ?? 0, // Mapeo del backend
    );
  }
}