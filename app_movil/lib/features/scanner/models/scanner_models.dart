import 'dart:math';

String generateFrontendUuid() {
  final random = Random();
  return "${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1000000)}";
}

class AIItemExtracted {
  String uuidTemporal; 
  String descripcion;
  
  String? productoPadreEstimado;
  String? varianteDetectada;
  String? marcaDetectada;
  String? codigo;

  String umpCompra; 
  int unidadesPorLote;
  double cantidadUmpComprada;
  double precioUmpProveedor;
  double totalPagoLote;

  String unidadVenta;

  AIItemExtracted({
    String? uuidTemporal,
    required this.descripcion,
    this.productoPadreEstimado,
    this.varianteDetectada,
    this.marcaDetectada,
    this.codigo,
    required this.umpCompra,
    required this.unidadesPorLote,
    required this.cantidadUmpComprada,
    required this.precioUmpProveedor,
    required this.totalPagoLote,
    this.unidadVenta = "Unidad",
  }) : uuidTemporal = uuidTemporal ?? generateFrontendUuid();

  factory AIItemExtracted.fromJson(Map<String, dynamic> json) {
    return AIItemExtracted(
      uuidTemporal: json['uuid_temporal'] ?? generateFrontendUuid(),
      descripcion: json['descripcion_detectada'] ?? '',
      productoPadreEstimado: json['producto_padre_estimado'],
      varianteDetectada: json['variante_detectada'],
      marcaDetectada: json['marca_detectada'],
      codigo: json['codigo_detectado'],
      
      umpCompra: json['ump_compra'] ?? 'UND',
      unidadesPorLote: json['unidades_por_lote'] ?? 1,
      cantidadUmpComprada: (json['cantidad_ump_comprada'] ?? 0).toDouble(),
      precioUmpProveedor: (json['precio_ump_proveedor'] ?? 0).toDouble(),
      totalPagoLote: (json['total_pago_lote'] ?? 0).toDouble(),
      
      unidadVenta: json['unidad_venta'] ?? json['ump_compra'] ?? 'Unidad',
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid_temporal': uuidTemporal,
    'descripcion_detectada': descripcion,
    'producto_padre_estimado': productoPadreEstimado,
    'variante_detectada': varianteDetectada,
    'marca_detectada': marcaDetectada,
    'codigo_detectado': codigo,
    'ump_compra': umpCompra,
    'unidades_por_lote': unidadesPorLote,
    'cantidad_ump_comprada': cantidadUmpComprada,
    'precio_ump_proveedor': precioUmpProveedor,
    'total_pago_lote': totalPagoLote,
    'unidad_venta': unidadVenta,
  };
}

class AIInvoiceResponse {
  int? invoiceId; 
  String proveedorDetectado;
  String? rucDetectado;
  String? fechaDetectada;
  double? montoTotalFactura;
  List<AIItemExtracted> items;

  AIInvoiceResponse({
    this.invoiceId,
    required this.proveedorDetectado,
    this.rucDetectado,
    this.fechaDetectada,
    this.montoTotalFactura,
    required this.items
  });

  factory AIInvoiceResponse.fromJson(Map<String, dynamic> json) {
    return AIInvoiceResponse(
      invoiceId: json['invoice_id'], 
      proveedorDetectado: json['proveedor_detectado'] ?? 'Desconocido',
      rucDetectado: json['ruc_detectado'],     
      fechaDetectada: json['fecha_detectada'], 
      montoTotalFactura: (json['monto_total_factura'] as num?)?.toDouble(),
      items: (json['items'] as List?)?.map((x) => AIItemExtracted.fromJson(x)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'invoice_id': invoiceId, 
    'proveedor_detectado': proveedorDetectado,
    'ruc_detectado': rucDetectado,
    'fecha_detectada': fechaDetectada,
    'monto_total_factura': montoTotalFactura,
    'items': items.map((x) => x.toJson()).toList(),
  };
}

class MatchData {
  int id;
  String nombre;
  int stockActual;
  String? marcaNombre;
  String? categoriaNombre;
  List<Map<String, dynamic>>? availablePresentations;

  double precioVentaFinal;
  double costoUnitarioCalculado;
  
  String umpCompra;
  int unidadesPorLote;
  String unidadVenta;
  int unidadesPorVenta;

  MatchData({
    required this.id, 
    required this.nombre,
    this.stockActual = 0,
    this.precioVentaFinal = 0.0,
    this.costoUnitarioCalculado = 0.0,
    this.umpCompra = "Unidad",
    this.unidadesPorLote = 1,
    this.unidadVenta = "Unidad",
    this.unidadesPorVenta = 1,
    this.availablePresentations,
    this.marcaNombre,
    this.categoriaNombre,
  });

  factory MatchData.fromJson(Map<String, dynamic> json) {
    return MatchData(
      id: json['id'],
      nombre: json['nombre'],
      marcaNombre: json['marca_nombre'], 
      categoriaNombre: json['categoria_nombre'],
      stockActual: json['stock_actual'] ?? 0,
      precioVentaFinal: (json['precio_venta_actual'] ?? 0).toDouble(), 
      costoUnitarioCalculado: (json['costo_unitario_actual'] ?? 0).toDouble(),
      
      umpCompra: json['ump_compra'] ?? json['unidad'] ?? "Unidad",
      unidadesPorLote: json['unidades_por_lote'] ?? json['factor'] ?? 1,
      unidadVenta: json['unidad_venta'] ?? json['unidad'] ?? "Unidad",
      unidadesPorVenta: json['unidades_por_venta'] ?? json['factor'] ?? 1,
      
      availablePresentations: json['available_presentations'] != null 
          ? List<Map<String, dynamic>>.from(json['available_presentations'])
          : [],
    );
  }
}

class MatchResult {
  String estado; 
  int confianza;
  MatchData? datos;

  MatchResult({required this.estado, required this.confianza, this.datos});

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      estado: json['estado'] ?? 'NUEVO',
      confianza: json['confianza'] ?? 0,
      datos: json['datos'] != null ? MatchData.fromJson(json['datos']) : null,
    );
  }
}

class StagingVariant {
  String uuidTemporal; 
  String nombreEspecifico;
  String? codigoBarra;
  
  String umpCompra;
  double cantidadUmpComprada;
  double precioUmpProveedor;
  double totalPagoLote;
  int unidadesPorLote;

  String unidadVenta;
  int unidadesPorVenta;
  double costoUnitarioSugerido;
  double factorGananciaVentaSugerido;
  double precioVentaSugerido;
  
  MatchResult matchPresentacion;
  bool isConfirmed;

  bool updateCosto = true;
  bool updatePrecio = false;
  bool updateNombre = false; 
  bool updateUnidadVenta = false; 
  
  bool keepDescuento = true;
  String stockOperation = 'sumar'; // 'sumar' o 'reemplazar'

  // Backup de valores originales de factura
  late final double _originalCostoSugerido;
  late final double _originalMargen;
  late final double _originalPrecioVenta;
  late final String _originalNombreEspecifico;
  late final String _originalUnidadVenta;
  late final int _originalUnidadesPorVenta;
  
  // Backup intermedio de BD (Snapshot antes de edición del modal)
  double? _snapshotCosto;
  double? _snapshotMargen;
  double? _snapshotPrecioVenta;
  String? _snapshotNombreEspecifico;
  String? _snapshotUnidadVenta;
  int? _snapshotUnidadesPorVenta;

  StagingVariant({
    String? uuidTemporal,
    required this.nombreEspecifico,
    required this.umpCompra,
    required this.cantidadUmpComprada,
    required this.precioUmpProveedor,
    required this.totalPagoLote,
    required this.unidadesPorLote,
    required this.unidadVenta,
    required this.unidadesPorVenta,
    required this.costoUnitarioSugerido,
    required this.factorGananciaVentaSugerido,
    required this.precioVentaSugerido,
    required this.matchPresentacion,
    this.codigoBarra,
    this.isConfirmed = true,
  }) : uuidTemporal = uuidTemporal ?? generateFrontendUuid() {
    _originalCostoSugerido = costoUnitarioSugerido;
    _originalMargen = factorGananciaVentaSugerido;
    _originalPrecioVenta = precioVentaSugerido;
    _originalNombreEspecifico = nombreEspecifico;
    _originalUnidadVenta = unidadVenta;
    _originalUnidadesPorVenta = unidadesPorVenta;
  }

  factory StagingVariant.fromJson(Map<String, dynamic> json) {
    return StagingVariant(
      uuidTemporal: json['uuid_temporal'] ?? generateFrontendUuid(),
      nombreEspecifico: json['nombre_especifico'] ?? '',
      umpCompra: json['ump_compra'] ?? 'UND',
      cantidadUmpComprada: (json['cantidad_ump_comprada'] ?? 0).toDouble(),
      precioUmpProveedor: (json['precio_ump_proveedor'] ?? 0).toDouble(),
      totalPagoLote: (json['total_pago_lote'] ?? 0).toDouble(),
      unidadesPorLote: json['unidades_por_lote'] ?? 1,
      unidadVenta: json['unidad_venta'] ?? 'Unidad',
      unidadesPorVenta: json['unidades_por_venta'] ?? 1,
      costoUnitarioSugerido: (json['costo_unitario_sugerido'] ?? 0).toDouble(),
      factorGananciaVentaSugerido: (json['factor_ganancia_venta_sugerido'] ?? 1.35).toDouble(),
      precioVentaSugerido: (json['precio_venta_sugerido'] ?? 0).toDouble(),
      codigoBarra: json['codigo_barras'],
      matchPresentacion: MatchResult.fromJson(json['match_presentacion']),
      isConfirmed: json['confirmado'] == 1 || json['confirmado'] == true || json['confirmado'] == null
    );
  }

  void takeSnapshot() {
    _snapshotCosto = costoUnitarioSugerido;
    _snapshotMargen = factorGananciaVentaSugerido;
    _snapshotPrecioVenta = precioVentaSugerido;
    _snapshotNombreEspecifico = nombreEspecifico;
    _snapshotUnidadVenta = unidadVenta;
    _snapshotUnidadesPorVenta = unidadesPorVenta;
  }

  void restoreFromSnapshot() {
    if (_snapshotCosto != null) {
      costoUnitarioSugerido = _snapshotCosto!;
      factorGananciaVentaSugerido = _snapshotMargen!;
      precioVentaSugerido = _snapshotPrecioVenta!;
      nombreEspecifico = _snapshotNombreEspecifico!;
      unidadVenta = _snapshotUnidadVenta!;
      unidadesPorVenta = _snapshotUnidadesPorVenta!;
    }
  }

  bool get hasSnapshotBeenModified =>
      _snapshotCosto != null &&
      (costoUnitarioSugerido != _snapshotCosto ||
       factorGananciaVentaSugerido != _snapshotMargen ||
       precioVentaSugerido != _snapshotPrecioVenta ||
       nombreEspecifico != _snapshotNombreEspecifico ||
       unidadVenta != _snapshotUnidadVenta ||
       unidadesPorVenta != _snapshotUnidadesPorVenta);

  void restoreOriginals() {
    costoUnitarioSugerido = _originalCostoSugerido;
    factorGananciaVentaSugerido = _originalMargen;
    precioVentaSugerido = _originalPrecioVenta;
    nombreEspecifico = _originalNombreEspecifico;
    unidadVenta = _originalUnidadVenta;
    unidadesPorVenta = _originalUnidadesPorVenta;
    updateCosto = true;
    updatePrecio = false;
    updateNombre = false;
    updateUnidadVenta = false;
    _snapshotCosto = null; // Clear snapshot when reverting to absolute original
  }

  bool get hasBeenModified => 
    costoUnitarioSugerido != _originalCostoSugerido || 
    factorGananciaVentaSugerido != _originalMargen || 
    precioVentaSugerido != _originalPrecioVenta || 
    nombreEspecifico != _originalNombreEspecifico ||
    unidadVenta != _originalUnidadVenta ||
    unidadesPorVenta != _originalUnidadesPorVenta;
}

class StagingProductGroup {
  String uuidTemporal; 
  String nombrePadre;
  String? nombreOriginalFactura;
  String marcaTexto;
  
  MatchResult matchProducto;
  MatchResult matchMarca;
  
  int? categoriaSugeridaId;
  List<StagingVariant> variantes;

  StagingProductGroup({
    String? uuidTemporal,
    required this.nombrePadre,
    this.nombreOriginalFactura,
    required this.marcaTexto,
    required this.matchProducto,
    required this.matchMarca,
    this.categoriaSugeridaId,
    required this.variantes
  }) : uuidTemporal = uuidTemporal ?? generateFrontendUuid();

  factory StagingProductGroup.fromJson(Map<String, dynamic> json) {
    return StagingProductGroup(
      uuidTemporal: json['uuid_temporal'] ?? generateFrontendUuid(),
      nombrePadre: json['nombre_padre'],
      nombreOriginalFactura: json['nombre_padre'], 
      marcaTexto: json['marca_texto'],
      matchProducto: MatchResult.fromJson(json['match_producto']),
      matchMarca: MatchResult.fromJson(json['match_marca']),
      categoriaSugeridaId: json['categoria_sugerida_id'],
      variantes: (json['variantes'] as List).map((x) => StagingVariant.fromJson(x)).toList()
    );
  }
}

class StagingResponse {
  int? invoiceId; 
  MatchResult proveedorMatch;
  String proveedorTexto;
  String? rucProveedor;
  String? fechaFactura;
  double? montoTotalFactura;
  List<StagingProductGroup> productosAgrupados;

  StagingResponse({
    this.invoiceId,
    required this.proveedorMatch, 
    required this.proveedorTexto,
    this.rucProveedor,
    this.fechaFactura,
    this.montoTotalFactura,
    required this.productosAgrupados
  });

  factory StagingResponse.fromJson(Map<String, dynamic> json) {
    return StagingResponse(
      invoiceId: json['invoice_id'], 
      proveedorMatch: MatchResult.fromJson(json['proveedor_match']),
      proveedorTexto: json['proveedor_texto'],
      rucProveedor: json['ruc_detectado'],
      fechaFactura: json['fecha_detectada'],
      montoTotalFactura: (json['monto_total_factura'] as num?)?.toDouble(),
      productosAgrupados: (json['productos_agrupados'] as List)
          .map((x) => StagingProductGroup.fromJson(x))
          .toList(),
    );
  }
}