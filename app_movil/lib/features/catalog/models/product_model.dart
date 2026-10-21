class ProductPresentation {
  final int? id;
  final String? nombreEspecifico;
  final String? codigoBarras;
  final String? descripcion;
  final String? imagenUrl;
  final int? proveedorId;
  final String? deferredProviderName;

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
  final int orden;
  final double? precioOferta;
  final String? tipoDescuento;
  final double? valorDescuento;
  final String estado;
  final bool activo;

  ProductPresentation({
    this.id,
    this.nombreEspecifico,
    this.codigoBarras,
    this.descripcion,
    this.imagenUrl,
    this.proveedorId,
    this.deferredProviderName,
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
    this.orden = 0,
    this.precioOferta,
    this.tipoDescuento,
    this.valorDescuento,
    this.estado = 'publico',
    this.activo = true,
  });

  ProductPresentation copyWith({
    int? id,
    String? nombreEspecifico,
    String? codigoBarras,
    String? descripcion,
    String? imagenUrl,
    int? proveedorId,
    String? deferredProviderName,
    String? umpCompra,
    double? precioUmpProveedor,
    double? cantidadUmpComprada,
    double? totalPagoLote,
    int? unidadesPorLote,
    int? facturaCargaId,
    String? unidadVenta,
    int? unidadesPorVenta,
    double? costoUnitarioCalculado,
    double? factorGananciaVenta,
    double? precioVentaFinal,
    int? stockActual,
    int? stockAlerta,
    bool? esDefault,
    int? orden,
    double? precioOferta,
    String? tipoDescuento,
    double? valorDescuento,
    String? estado,
    bool? activo,
  }) {
    return ProductPresentation(
      id: id ?? this.id,
      nombreEspecifico: nombreEspecifico ?? this.nombreEspecifico,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      descripcion: descripcion ?? this.descripcion,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      proveedorId: proveedorId ?? this.proveedorId,
      deferredProviderName: deferredProviderName ?? this.deferredProviderName,
      umpCompra: umpCompra ?? this.umpCompra,
      precioUmpProveedor: precioUmpProveedor ?? this.precioUmpProveedor,
      cantidadUmpComprada: cantidadUmpComprada ?? this.cantidadUmpComprada,
      totalPagoLote: totalPagoLote ?? this.totalPagoLote,
      unidadesPorLote: unidadesPorLote ?? this.unidadesPorLote,
      facturaCargaId: facturaCargaId ?? this.facturaCargaId,
      unidadVenta: unidadVenta ?? this.unidadVenta,
      unidadesPorVenta: unidadesPorVenta ?? this.unidadesPorVenta,
      costoUnitarioCalculado:
          costoUnitarioCalculado ?? this.costoUnitarioCalculado,
      factorGananciaVenta: factorGananciaVenta ?? this.factorGananciaVenta,
      precioVentaFinal: precioVentaFinal ?? this.precioVentaFinal,
      stockActual: stockActual ?? this.stockActual,
      stockAlerta: stockAlerta ?? this.stockAlerta,
      esDefault: esDefault ?? this.esDefault,
      orden: orden ?? this.orden,
      precioOferta: precioOferta ?? this.precioOferta,
      tipoDescuento: tipoDescuento ?? this.tipoDescuento,
      valorDescuento: valorDescuento ?? this.valorDescuento,
      estado: estado ?? this.estado,
      activo: activo ?? this.activo,
    );
  }

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

      costoUnitarioCalculado: (json['costo_unitario_calculado'] as num?)
          ?.toDouble(),
      factorGananciaVenta: (json['factor_ganancia_venta'] as num?)?.toDouble(),
      precioVentaFinal: (json['precio_venta_final'] as num?)?.toDouble() ?? 0.0,

      stockActual: json['stock_actual'] ?? 0,
      stockAlerta: json['stock_alerta'],
      esDefault: json['es_default'] == 1 || json['es_default'] == true,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
      activo:
          json['activo'] == 1 ||
          json['activo'] == true ||
          json['activo'] == null,
      precioOferta: json['precio_oferta'] != null
          ? (json['precio_oferta'] as num).toDouble()
          : null,
      tipoDescuento: json['tipo_descuento'],
      valorDescuento: json['valor_descuento'] != null
          ? (json['valor_descuento'] as num).toDouble()
          : null,
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
      'deferred_provider_name': deferredProviderName,
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
      'orden': orden,
      'estado': estado,
      'activo': activo ? 1 : 0,
      'precio_oferta': precioOferta,
      'tipo_descuento': tipoDescuento,
      'valor_descuento': valorDescuento,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'orden': orden,
      'precio_oferta': precioOferta,
      'tipo_descuento': tipoDescuento,
      'valor_descuento': valorDescuento,
      'estado': estado,
      'activo': activo ? 1 : 0,
    };
  }

  /// Factor de empaque de compra (unidadesPorLote)
  int get factorUmp => unidadesPorLote > 0 ? unidadesPorLote : 1;

  /// Costo directo registrado de la presentación si existe (precio de proveedor o lote), o 0.0 si no existe.
  double get costoCompraPresentacion {
    if (precioUmpProveedor != null && precioUmpProveedor! > 0) {
      return precioUmpProveedor!;
    }
    return 0.0;
  }

  /// Costo factor-aware exacto de la presentación:
  /// 1. Si tiene costoUnitarioCalculado > 0, retorna directamente ese valor
  ///    (en la arquitectura de MochilaLista, costoUnitarioCalculado en presentaciones_producto ya es el costo de esa presentación).
  /// 2. Si no, deriva el costo unitario desde (precioUmpProveedor / factorCompra) y lo multiplica por factorVenta.
  /// 3. Si no tiene costo registrado, retorna 0.0.
  double get costoPresentacionFinal {
    if (costoUnitarioCalculado != null && costoUnitarioCalculado! > 0) {
      return costoUnitarioCalculado!;
    }
    if (precioUmpProveedor != null && precioUmpProveedor! > 0) {
      final int factorVenta = unidadesPorVenta <= 0 ? 1 : unidadesPorVenta;
      final int factorCompra = factorUmp;
      return (precioUmpProveedor! / factorCompra) * factorVenta;
    }
    return 0.0;
  }

  /// Indica si la presentación tiene una oferta o descuento válido activo
  bool get hasOffer {
    final hasPromoPrice = precioOferta != null &&
        precioOferta! > 0 &&
        precioOferta! < precioVentaFinal;
    final hasActiveDiscount = valorDescuento != null &&
        valorDescuento! > 0 &&
        tipoDescuento != null &&
        tipoDescuento!.isNotEmpty &&
        tipoDescuento != 'ninguno';
    return hasPromoPrice || hasActiveDiscount;
  }

  /// Retorna el precio efectivo de venta (precio_oferta si es válido, o calculado desde valor_descuento)
  double get effectivePrice {
    if (precioOferta != null &&
        precioOferta! > 0 &&
        precioOferta! < precioVentaFinal) {
      return precioOferta!;
    }
    if (valorDescuento != null &&
        valorDescuento! > 0 &&
        tipoDescuento != null &&
        tipoDescuento!.isNotEmpty &&
        tipoDescuento != 'ninguno') {
      if (tipoDescuento == 'porcentaje') {
        final discounted = precioVentaFinal *
            (1.0 - (valorDescuento! / 100.0));
        return discounted > 0 ? discounted : 0.0;
      } else {
        final discounted = precioVentaFinal - valorDescuento!;
        return discounted > 0 ? discounted : 0.0;
      }
    }
    return precioVentaFinal;
  }

  /// Retorna el porcentaje de descuento redondeado a entero limpio (-10%, -14%)
  int get discountPercentRounded {
    if (precioVentaFinal <= 0) return 0;
    if (tipoDescuento == 'porcentaje' &&
        valorDescuento != null &&
        valorDescuento! > 0) {
      return valorDescuento!.round();
    }
    final eff = effectivePrice;
    if (eff < precioVentaFinal) {
      return (((precioVentaFinal - eff) / precioVentaFinal) * 100).round();
    }
    return 0;
  }
}

class Product {
  final int id;
  final String nombre;
  final int? marcaId;
  final String? marcaNombre;
  final String? descripcion;
  final int categoriaId;
  final String? imagenUrl;
  final String? codigoBarras;
  final String estado;
  final List<ProductPresentation> presentaciones;
  final int stockTotalCalculado;
  final String? fechaActualizacion;

  Product({
    required this.id,
    required this.nombre,
    this.marcaId,
    this.marcaNombre,
    this.descripcion,
    required this.categoriaId,
    this.imagenUrl,
    this.codigoBarras,
    this.estado = 'privado',
    this.presentaciones = const [],
    this.stockTotalCalculado = 0,
    this.fechaActualizacion,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    var list = json['presentaciones'] as List? ?? [];
    List<ProductPresentation> presentationList = list
        .map((i) => ProductPresentation.fromJson(i))
        .toList();

    return Product(
      id: json['id'],
      nombre: json['nombre'],
      marcaId: json['marca_id'],
      marcaNombre: json['marca_nombre'],
      descripcion: json['descripcion'],
      categoriaId: json['categoria_id'] ?? 0,
      imagenUrl: json['imagen_url'],
      codigoBarras: json['codigo_barras'],
      estado: json['estado'] ?? 'privado',
      presentaciones: presentationList,
      stockTotalCalculado: json['stock_total_calculado'] ?? 0,
      fechaActualizacion: json['fecha_actualizacion'],
    );
  }

  Product copyWith({
    int? id,
    String? nombre,
    int? marcaId,
    String? marcaNombre,
    String? descripcion,
    int? categoriaId,
    String? imagenUrl,
    String? codigoBarras,
    String? estado,
    List<ProductPresentation>? presentaciones,
    int? stockTotalCalculado,
    String? fechaActualizacion,
  }) {
    return Product(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      marcaId: marcaId ?? this.marcaId,
      marcaNombre: marcaNombre ?? this.marcaNombre,
      descripcion: descripcion ?? this.descripcion,
      categoriaId: categoriaId ?? this.categoriaId,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      estado: estado ?? this.estado,
      presentaciones: presentaciones ?? this.presentaciones,
      stockTotalCalculado: stockTotalCalculado ?? this.stockTotalCalculado,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'marca_id': marcaId,
      'descripcion': descripcion,
      'categoria_id': categoriaId,
      'imagen_url': imagenUrl,
      'codigo_barras': codigoBarras,
      'estado': estado,
      'stock_total_calculado': stockTotalCalculado,
      'fecha_actualizacion': fechaActualizacion,
      'presentaciones': presentaciones.map((p) => p.toJson()).toList(),
    };
  }
}
