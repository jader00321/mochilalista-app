class BundleItemModel {
  final int id;
  final int paqueteId;
  final int productoId;
  final int presentacionId;
  final int cantidadRequerida;
  final double? precioOriginalUnitario;

  BundleItemModel({
    required this.id,
    required this.paqueteId,
    required this.productoId,
    required this.presentacionId,
    this.cantidadRequerida = 1,
    this.precioOriginalUnitario,
  });

  factory BundleItemModel.fromJson(Map<String, dynamic> json) {
    return BundleItemModel(
      id: json['id'] as int,
      paqueteId: json['paquete_id'] as int,
      productoId: json['producto_id'] as int,
      presentacionId: json['presentacion_id'] as int,
      cantidadRequerida: json['cantidad_requerida'] as int? ?? 1,
      precioOriginalUnitario: (json['precio_original_unitario'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paquete_id': paqueteId,
      'producto_id': productoId,
      'presentacion_id': presentacionId,
      'cantidad_requerida': cantidadRequerida,
      'precio_original_unitario': precioOriginalUnitario,
    };
  }
}
