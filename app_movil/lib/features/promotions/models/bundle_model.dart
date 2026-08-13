class BundleModel {
  final int id;
  final int? campanaId;
  final int negocioId;
  final String nombrePaquete;
  final String? descripcion;
  final String? imagenUrl;
  final double precioVentaTotal;
  final double? costoTotalCalculado;
  final bool activo;
  final String tipoPromocion;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  BundleModel({
    required this.id,
    this.campanaId,
    required this.negocioId,
    required this.nombrePaquete,
    this.descripcion,
    this.imagenUrl,
    required this.precioVentaTotal,
    this.costoTotalCalculado,
    this.activo = true,
    this.tipoPromocion = 'paquete',
    this.fechaInicio,
    this.fechaFin,
  });

  factory BundleModel.fromJson(Map<String, dynamic> json) {
    return BundleModel(
      id: json['id'] as int,
      campanaId: json['campana_id'] as int?,
      negocioId: json['negocio_id'] as int,
      nombrePaquete: json['nombre_paquete'] as String,
      descripcion: json['descripcion'] as String?,
      imagenUrl: json['imagen_url'] as String?,
      precioVentaTotal: (json['precio_venta_total'] as num).toDouble(),
      costoTotalCalculado: (json['costo_total_calculado'] as num?)?.toDouble(),
      activo: (json['activo'] as int?) == 1,
      tipoPromocion: json['tipo_promocion'] as String? ?? 'paquete',
      fechaInicio: json['fecha_inicio'] != null ? DateTime.parse(json['fecha_inicio']) : null,
      fechaFin: json['fecha_fin'] != null ? DateTime.parse(json['fecha_fin']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campana_id': campanaId,
      'negocio_id': negocioId,
      'nombre_paquete': nombrePaquete,
      'descripcion': descripcion,
      'imagen_url': imagenUrl,
      'precio_venta_total': precioVentaTotal,
      'costo_total_calculado': costoTotalCalculado,
      'activo': activo ? 1 : 0,
      'tipo_promocion': tipoPromocion,
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
    };
  }
}
