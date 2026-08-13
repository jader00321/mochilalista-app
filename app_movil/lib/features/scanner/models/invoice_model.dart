import 'dart:convert';

class InvoiceModel {
  final int id;
  final int negocioId;
  final String imagenUrl;
  final String estado;
  final DateTime fechaCarga;
  
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
    Map<String, dynamic>? parsedJson;
    if (json['datos_crudos_ia_json'] != null) {
      if (json['datos_crudos_ia_json'] is String) {
        parsedJson = jsonDecode(json['datos_crudos_ia_json']);
      } else {
        parsedJson = json['datos_crudos_ia_json'];
      }
    }

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
      datosCrudosIaJson: parsedJson,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'imagen_url': imagenUrl,
      'estado': estado,
      'fecha_carga': fechaCarga.toIso8601String(),
      'proveedor_id': proveedorId,
      'monto_total_factura': montoTotalFactura,
      'fecha_emision': fechaEmision?.toIso8601String(),
      'cantidad_items_extraidos': cantidadItemsExtraidos,
      'datos_crudos_ia_json': datosCrudosIaJson != null ? jsonEncode(datosCrudosIaJson) : null,
    };
  }
}