class ProductPresentation {
  final int? id;
  final String? nombreEspecifico;
  final String? codigoBarras;
  final String? descripcion; 
  final String? imagenUrl;    
  final int? proveedorId; 

  final String? umpCompra;
  final double? precioUmpProveedor;
  final double? cantidadUmpComprada;
  final double? totalPagoLote;
  final int unidadesPorLote;
  final int? facturaCargaId;
  
  final String? unidadVenta;
  final int unidadesPorVenta;

  final double? costoUnitarioCalculado;
  final double? factorGananciaVenta;
  final double precioVentaFinal;
  
  final int stockActual;
  final int? stockAlerta; 
  final bool esDefault;
  final double? precioOferta;
  final String? tipoDescuento;    
  final double? valorDescuento;   
  final String estado; 
  final bool activo; // Añadido para hacer match con DB

  ProductPresentation({
    this.id,
    this.nombreEspecifico,
    this.codigoBarras,
    this.descripcion,
    this.imagenUrl,
    this.proveedorId, 
    this.umpCompra,
    this.precioUmpProveedor,
    this.cantidadUmpComprada,
    this.totalPagoLote,
    this.unidadesPorLote = 1,
    this.facturaCargaId,
    this.unidadVenta,            
    this.unidadesPorVenta = 1,   
    this.costoUnitarioCalculado,
    this.factorGananciaVenta,
    required this.precioVentaFinal,
    required this.stockActual,
    this.stockAlerta = 5, 
    this.esDefault = false,
    this.precioOferta,
    this.tipoDescuento,
    this.valorDescuento,
    this.estado = 'publico', 
    this.activo = true,
  });

  factory ProductPresentation.fromJson(Map<String, dynamic> json) {
    return ProductPresentation(
      id: json['id'],
      nombreEspecifico: json['nombre_especifico'],
      codigoBarras: json['codigo_barras'],
      descripcion: json['descripcion'], 
      imagenUrl: json['imagen_url'],
      proveedorId: json['proveedor_id'], 
      
      umpCompra: json['ump_compra'],
      precioUmpProveedor: (json['precio_ump_proveedor'] as num?)?.toDouble(),
      cantidadUmpComprada: (json['cantidad_ump_comprada'] as num?)?.toDouble(),
      totalPagoLote: (json['total_pago_lote'] as num?)?.toDouble(),
      unidadesPorLote: json['unidades_por_lote'] ?? 1,
      facturaCargaId: json['factura_carga_id'],
      
      unidadVenta: json['unidad_venta'] ?? 'Unidad',
      unidadesPorVenta: json['unidades_por_venta'] ?? 1,

      costoUnitarioCalculado: (json['costo_unitario_calculado'] as num?)?.toDouble(),
      factorGananciaVenta: (json['factor_ganancia_venta'] as num?)?.toDouble(),
      precioVentaFinal: (json['precio_venta_final'] as num?)?.toDouble() ?? 0.0,
      
      stockActual: json['stock_actual'] ?? 0,
      stockAlerta: json['stock_alerta'], 
      esDefault: json['es_default'] == 1 || json['es_default'] == true,
      activo: json['activo'] == 1 || json['activo'] == true || json['activo'] == null,
      precioOferta: json['precio_oferta'] != null ? (json['precio_oferta'] as num).toDouble() : null,
      tipoDescuento: json['tipo_descuento'],
      valorDescuento: json['valor_descuento'] != null ? (json['valor_descuento'] as num).toDouble() : null,
      estado: json['estado'] ?? 'privado', 
    );
  }

  Map<String, dynamic> toSqlite(int productoId) {
    return {
      'id': id == 0 ? null : id,
      'producto_id': productoId,
      'nombre_especifico': nombreEspecifico,
      'codigo_barras': codigoBarras,
      'descripcion': descripcion,
      'imagen_url': imagenUrl,
      'proveedor_id': proveedorId, 
      'ump_compra': umpCompra,
      'precio_ump_proveedor': precioUmpProveedor,
      'cantidad_ump_comprada': cantidadUmpComprada,
      'total_pago_lote': totalPagoLote,
      'unidades_por_lote': unidadesPorLote,
      'factura_carga_id': facturaCargaId,
      'unidad_venta': unidadVenta,               
      'unidades_por_venta': unidadesPorVenta,
      'costo_unitario_calculado': costoUnitarioCalculado,    
      'factor_ganancia_venta': factorGananciaVenta,
      'precio_venta_final': precioVentaFinal,
      'stock_actual': stockActual,
      'stock_alerta': stockAlerta, 
      'es_default': esDefault ? 1 : 0,
      'estado': estado, 
      'activo': activo ? 1 : 0,
      'precio_oferta': precioOferta,
      'tipo_descuento': tipoDescuento,
      'valor_descuento': valorDescuento,
    };
  }
}

class Product {
  final int id;
  final String nombre;
  final int? marcaId; 
  final String? descripcion;
  final int categoriaId;
  final String? imagenUrl; 
  final String? codigoBarras;
  final String estado;     
  final List<ProductPresentation> presentaciones;
  final int stockTotalCalculado;

  Product({
    required this.id,
    required this.nombre,
    this.marcaId, 
    this.descripcion,
    required this.categoriaId,
    this.imagenUrl,
    this.codigoBarras,
    this.estado = 'privado',
    this.presentaciones = const [],
    this.stockTotalCalculado = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Al venir de SQLite, la lista de presentaciones se la inyectaremos después desde el servicio
    var list = json['presentaciones'] as List? ?? [];
    List<ProductPresentation> presentationList = list.map((i) => ProductPresentation.fromJson(i)).toList();

    return Product(
      id: json['id'],
      nombre: json['nombre'],
      marcaId: json['marca_id'], 
      descripcion: json['descripcion'],
      categoriaId: json['categoria_id'] ?? 0,
      imagenUrl: json['imagen_url'],
      codigoBarras: json['codigo_barras'],
      estado: json['estado'] ?? 'privado',
      presentaciones: presentationList,
      stockTotalCalculado: json['stock_total_calculado'] ?? 0,
    );
  }

  Map<String, dynamic> toSqlite(int negocioId) {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'categoria_id': categoriaId == 0 ? null : categoriaId,
      'marca_id': marcaId,
      'codigo_barras': codigoBarras,
      'nombre': nombre,
      'descripcion': descripcion,
      'imagen_url': imagenUrl,
      'estado': estado,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    };
  }
}