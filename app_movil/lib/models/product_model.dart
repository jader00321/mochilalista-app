// app/models/product_model.dart

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
  final int? stockAlerta; // 🔥 AGREGADO: Campo faltante que causaba el error
  final bool esDefault;
  final double? precioOferta;
  final String? tipoDescuento;    
  final double? valorDescuento;   
  final String estado; 

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
    this.stockAlerta = 5, // 🔥 AGREGADO: Valor por defecto
    this.esDefault = false,
    this.precioOferta,
    this.tipoDescuento,
    this.valorDescuento,
    this.estado = 'publico', 
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
      stockAlerta: json['stock_alerta'], // 🔥 AGREGADO: Mapeo del JSON
      esDefault: json['es_default'] ?? false,
      precioOferta: json['precio_oferta'] != null ? (json['precio_oferta'] as num).toDouble() : null,
      tipoDescuento: json['tipo_descuento'],
      valorDescuento: json['valor_descuento'] != null ? (json['valor_descuento'] as num).toDouble() : null,
      estado: json['estado'] ?? 'privado', 
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      'stock_alerta': stockAlerta, // 🔥 AGREGADO: Envío al Backend
      'es_default': esDefault,
      'estado': estado, 
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
}