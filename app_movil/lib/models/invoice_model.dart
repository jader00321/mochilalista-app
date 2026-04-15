class InvoiceModel {
  final int id;
  final int negocioId;
  final String imagenUrl;
  final String estado; // 'procesando', 'revision', 'completado'
  final DateTime fechaCarga;
  
  // Datos de Auditoría
  final int? proveedorId;
  final double? montoTotalFactura;
  final DateTime? fechaEmision;
  final int? cantidadItemsExtraidos;
  final Map<String, dynamic>? datosCrudosIaJson;

  InvoiceModel({
    required this.id,
    required this.negocioId,
    required this.imagenUrl,
    required this.estado,
    required this.fechaCarga,
    this.proveedorId,
    this.montoTotalFactura,
    this.fechaEmision,
    this.cantidadItemsExtraidos,
    this.datosCrudosIaJson,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'],
      negocioId: json['negocio_id'],
      imagenUrl: json['imagen_url'],
      estado: json['estado'] ?? 'procesando',
      fechaCarga: DateTime.parse(json['fecha_carga']),
      proveedorId: json['proveedor_id'],
      montoTotalFactura: (json['monto_total_factura'] as num?)?.toDouble(),
      fechaEmision: json['fecha_emision'] != null ? DateTime.parse(json['fecha_emision']) : null,
      cantidadItemsExtraidos: json['cantidad_items_extraidos'],
      datosCrudosIaJson: json['datos_crudos_ia_json'],
    );
  }
}