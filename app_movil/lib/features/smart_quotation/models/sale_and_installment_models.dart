import 'package:app_movil/features/smart_quotation/models/crm_parse_helpers.dart';

class SaleSummary {
  final int id;
  final int? sequentialNumber;
  final double total;
  final double montoPagado; 
  final String date;
  final String status;
  final String origenVenta; 
  final int itemsCount;     
  final double abonoInicial;
  final double porcentajeInteres;
  final String estadoPago;
  final bool isArchived;
  final String? motivoAnulacion;
  final double moraTotal;
  final double montoOriginal;

  SaleSummary({
    required this.id, 
    this.sequentialNumber,
    required this.total, 
    this.montoPagado = 0.0, 
    required this.date, 
    required this.status, 
    this.origenVenta = "smart_quotation", 
    this.itemsCount = 0,
    this.abonoInicial = 0.0,
    this.porcentajeInteres = 0.0,
    this.estadoPago = "pagado",
    this.isArchived = false,
    this.motivoAnulacion,
    this.moraTotal = 0.0,
    this.montoOriginal = 0.0,
  });

  String get displayId => sequentialNumber != null ? "$sequentialNumber" : "$id";

  double get trueTotal {
    // El monto_total (total) ahora ya incluye el interés y la mora desde la base de datos
    return total;
  }

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      id: json['id'] ?? 0,
      sequentialNumber: json['numero_secuencial'],
      total: parseCrmDouble(json['monto_total']),
      montoPagado: parseCrmDouble(json['monto_pagado']), 
      date: json['fecha_venta'] ?? "",
      status: json['estado_entrega'] ?? "entregado",
      origenVenta: json['origen_venta'] ?? "smart_quotation",
      itemsCount: json['items_count'] ?? 0,
      abonoInicial: parseCrmDouble(json['abono_inicial']),
      porcentajeInteres: parseCrmDouble(json['porcentaje_interes']),
      estadoPago: json['estado_pago'] ?? "pagado",
      isArchived: json['is_archived'] == 1 || json['is_archived'] == true,
      motivoAnulacion: json['motivo_anulacion'],
      moraTotal: parseCrmDouble(json['mora_total']),
      montoOriginal: parseCrmDouble(json['monto_original']),
    );
  }
}

class InstallmentModel {
  final int? id;
  final int installmentNumber;
  final double amount;
  final double montoPagado;
  final String dueDate;
  final String status;
  final double? montoOriginal;
  final double moraMonto;
  final double moraPorcentaje;
  final bool moraAutomatica;
  final String? moraFrecuencia;
  final int moraIntervaloDias;
  final String moraTipo;
  final double moraValor;
  final String? moraFechaInicio;
  final String? moraUltimaAplicacion;
  final int moraPeriodosAcumulados;

  double get montoBase => montoOriginal ?? amount;
  double get saldoPendiente => (amount - montoPagado) > 0 ? (amount - montoPagado) : 0.0;
  bool get tieneMora => moraMonto > 0.01;

  InstallmentModel({
    this.id,
    required this.installmentNumber,
    required this.amount,
    this.montoPagado = 0.0,
    required this.dueDate,
    this.status = "pendiente",
    this.montoOriginal,
    this.moraMonto = 0.0,
    this.moraPorcentaje = 0.0,
    this.moraAutomatica = false,
    this.moraFrecuencia,
    this.moraIntervaloDias = 1,
    this.moraTipo = 'fijo',
    this.moraValor = 0.0,
    this.moraFechaInicio,
    this.moraUltimaAplicacion,
    this.moraPeriodosAcumulados = 0,
  });

  factory InstallmentModel.fromJson(Map<String, dynamic> json) {
    final amt = parseCrmDouble(json['monto']);
    return InstallmentModel(
      id: json['id'],
      installmentNumber: json['numero_cuota'] ?? 1,
      amount: amt,
      montoPagado: parseCrmDouble(json['monto_pagado']),
      dueDate: json['fecha_vencimiento'] ?? "",
      status: json['estado'] ?? "pendiente",
      montoOriginal: json['monto_original'] != null ? parseCrmDouble(json['monto_original']) : amt,
      moraMonto: parseCrmDouble(json['mora_monto']),
      moraPorcentaje: parseCrmDouble(json['mora_porcentaje']),
      moraAutomatica: json['mora_automatica'] == 1 || json['mora_automatica'] == true,
      moraFrecuencia: json['mora_frecuencia'],
      moraIntervaloDias: (json['mora_intervalo_dias'] as num?)?.toInt() ?? 1,
      moraTipo: json['mora_tipo'] ?? 'fijo',
      moraValor: parseCrmDouble(json['mora_valor']),
      moraFechaInicio: json['mora_fecha_inicio'],
      moraUltimaAplicacion: json['mora_ultima_aplicacion'],
      moraPeriodosAcumulados: (json['mora_periodos_acumulados'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toSqlite(int ventaId) {
    return {
      'id': id == 0 ? null : id,
      'venta_id': ventaId,
      'numero_cuota': installmentNumber,
      'monto': amount,
      'monto_pagado': montoPagado,
      'fecha_vencimiento': dueDate,
      'estado': status,
      'monto_original': montoOriginal ?? amount,
      'mora_monto': moraMonto,
      'mora_porcentaje': moraPorcentaje,
      'mora_automatica': moraAutomatica ? 1 : 0,
      'mora_frecuencia': moraFrecuencia,
      'mora_intervalo_dias': moraIntervaloDias,
      'mora_tipo': moraTipo,
      'mora_valor': moraValor,
      'mora_fecha_inicio': moraFechaInicio,
      'mora_ultima_aplicacion': moraUltimaAplicacion,
      'mora_periodos_acumulados': moraPeriodosAcumulados,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      "numero_cuota": installmentNumber,
      "monto": amount,
      "fecha_vencimiento": dueDate,
      "monto_original": montoOriginal ?? amount,
      "mora_monto": moraMonto,
      "mora_porcentaje": moraPorcentaje,
      "mora_automatica": moraAutomatica ? 1 : 0,
    };
  }

  InstallmentModel copyWith({
    int? id,
    int? installmentNumber,
    double? amount,
    double? montoPagado,
    String? dueDate,
    String? status,
    double? montoOriginal,
    double? moraMonto,
    double? moraPorcentaje,
    bool? moraAutomatica,
    String? moraFrecuencia,
    int? moraIntervaloDias,
    String? moraTipo,
    double? moraValor,
    String? moraFechaInicio,
    String? moraUltimaAplicacion,
    int? moraPeriodosAcumulados,
  }) {
    return InstallmentModel(
      id: id ?? this.id,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      amount: amount ?? this.amount,
      montoPagado: montoPagado ?? this.montoPagado,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      montoOriginal: montoOriginal ?? this.montoOriginal,
      moraMonto: moraMonto ?? this.moraMonto,
      moraPorcentaje: moraPorcentaje ?? this.moraPorcentaje,
      moraAutomatica: moraAutomatica ?? this.moraAutomatica,
      moraFrecuencia: moraFrecuencia ?? this.moraFrecuencia,
      moraIntervaloDias: moraIntervaloDias ?? this.moraIntervaloDias,
      moraTipo: moraTipo ?? this.moraTipo,
      moraValor: moraValor ?? this.moraValor,
      moraFechaInicio: moraFechaInicio ?? this.moraFechaInicio,
      moraUltimaAplicacion: moraUltimaAplicacion ?? this.moraUltimaAplicacion,
      moraPeriodosAcumulados: moraPeriodosAcumulados ?? this.moraPeriodosAcumulados,
    );
  }
}

class SaleModel {
  final int id;
  final int? sequentialNumber;
  final int negocioId; 
  final int creadoPorUsuarioId; 
  final int? quotationId; 
  final int? clientId;
  final String? clientName;
  final String origenVenta; 
  final bool isArchived;    
  final String paymentMethod;
  final String paymentStatus;
  final String deliveryStatus;
  final String? deliveryDate; 
  final double totalAmount;
  final double paidAmount;
  final double discount;
  final double abonoInicial;
  final double porcentajeInteres;
  final double moraTotal;
  final int cuotasVencidasCount;
  final String saleDate;
  final String? motivoAnulacion;
  final String? notes; // Add notes field
  final List<InstallmentModel> installments; 
  
  double get trueTotalAmount {
    // El interés y mora ya están sumados en el totalAmount guardado en la BD
    return totalAmount;
  }

  /// Capital base prestado protegido matemáticamente contra moras agregadas
  double get capitalPrestadoCalculado {
    if (!isLoan) return totalAmount;
    final double totalSinMora = (totalAmount - moraTotal) > 0 ? (totalAmount - moraTotal) : 0.0;
    if (porcentajeInteres <= 0) return totalSinMora;
    return totalSinMora / (1 + (porcentajeInteres / 100));
  }

  /// Interés financiero original protegido contra moras agregadas
  double get interesMontoCalculado {
    if (!isLoan || porcentajeInteres <= 0) return 0.0;
    final double totalSinMora = (totalAmount - moraTotal) > 0 ? (totalAmount - moraTotal) : 0.0;
    final double capital = capitalPrestadoCalculado;
    final diff = totalSinMora - capital;
    return diff > 0 ? diff : 0.0;
  }

  double get pendingDebt {
    if (isArchived) return 0.0;
    final diff = trueTotalAmount - paidAmount;
    return diff > 0.01 ? diff : 0.0;
  }

  double get totalPaid => paidAmount;
  bool get isFullyPaid => !isArchived && pendingDebt <= 0.01;
  bool get isPartialPayment => !isArchived && paidAmount > 0.01 && pendingDebt > 0.01;
  bool get isUnpaid => !isArchived && paidAmount <= 0.01 && pendingDebt > 0.01;
  bool get isLoan => origenVenta == 'prestamo_personal';
  bool get isQuickSale => origenVenta == 'pos_rapido';
  bool get isQuotationSale => origenVenta == 'smart_quotation' || quotationId != null;

  String get displayId => sequentialNumber != null ? sequentialNumber.toString() : id.toString();

  SaleModel({
    required this.id,
    this.sequentialNumber,
    required this.negocioId,
    required this.creadoPorUsuarioId,
    this.quotationId,
    required this.clientId,
    this.clientName,
    this.origenVenta = "smart_quotation",
    this.isArchived = false,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryStatus,
    this.deliveryDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.discount,
    this.abonoInicial = 0.0,
    this.porcentajeInteres = 0.0,
    this.moraTotal = 0.0,
    this.cuotasVencidasCount = 0,
    required this.saleDate,
    this.motivoAnulacion,
    this.notes,
    this.installments = const [],
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] ?? 0,
      sequentialNumber: json['numero_secuencial'],
      negocioId: json['negocio_id'] ?? 0,
      creadoPorUsuarioId: json['creado_por_usuario_id'] ?? 0,
      quotationId: json['cotizacion_id'],
      clientId: json['cliente_id'],
      clientName: json['cliente_nombre'] ?? (json['cliente_info'] != null ? json['cliente_info']['nombre_completo'] : null),
      origenVenta: json['origen_venta'] ?? "smart_quotation",
      isArchived: json['is_archived'] == 1 || json['is_archived'] == true,
      paymentMethod: json['metodo_pago'] ?? "",
      paymentStatus: json['estado_pago'] ?? "",
      deliveryStatus: json['estado_entrega'] ?? "",
      deliveryDate: json['fecha_entrega'],
      totalAmount: parseCrmDouble(json['monto_total']),
      paidAmount: parseCrmDouble(json['monto_pagado']),
      discount: parseCrmDouble(json['descuento_aplicado']),
      abonoInicial: parseCrmDouble(json['abono_inicial']),
      porcentajeInteres: parseCrmDouble(json['porcentaje_interes']),
      moraTotal: parseCrmDouble(json['mora_total']),
      cuotasVencidasCount: (json['cuotas_vencidas_count'] as num?)?.toInt() ?? 0,
      saleDate: json['fecha_venta'] ?? "",
      motivoAnulacion: json['motivo_anulacion'],
      notes: json['notas'] ?? json['nota_prestamo'],
      installments: (json['cuotas'] as List?)?.map((e) => InstallmentModel.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'numero_secuencial': sequentialNumber,
      'negocio_id': negocioId,
      'creado_por_usuario_id': creadoPorUsuarioId,
      'cotizacion_id': quotationId,
      'cliente_id': clientId,
      'origen_venta': origenVenta,
      'is_archived': isArchived ? 1 : 0,
      'metodo_pago': paymentMethod,
      'estado_pago': paymentStatus,
      'estado_entrega': deliveryStatus,
      'fecha_entrega': deliveryDate,
      'monto_total': totalAmount,
      'monto_pagado': paidAmount,
      'descuento_aplicado': discount,
      'abono_inicial': abonoInicial,
      'porcentaje_interes': porcentajeInteres,
      'mora_total': moraTotal,
      'fecha_venta': saleDate.isEmpty ? DateTime.now().toIso8601String() : saleDate,
    };
  }

  Map<String, dynamic> toMap() {
    final map = toSqlite();
    map['cliente_nombre'] = clientName;
    map['notas'] = notes;
    map['nota_prestamo'] = notes;
    map['abono_inicial'] = abonoInicial;
    map['porcentaje_interes'] = porcentajeInteres;
    map['mora_total'] = moraTotal;
    map['cuotas_vencidas_count'] = cuotasVencidasCount;
    return map;
  }

  SaleModel copyWith({
    int? id,
    int? sequentialNumber,
    int? negocioId,
    int? creadoPorUsuarioId,
    int? quotationId,
    int? clientId,
    String? clientName,
    String? origenVenta,
    bool? isArchived,
    String? paymentMethod,
    String? paymentStatus,
    String? deliveryStatus,
    String? deliveryDate,
    double? totalAmount,
    double? paidAmount,
    double? discount,
    double? abonoInicial,
    double? porcentajeInteres,
    double? moraTotal,
    int? cuotasVencidasCount,
    String? saleDate,
    String? motivoAnulacion,
    String? notes,
    List<InstallmentModel>? installments,
  }) {
    return SaleModel(
      id: id ?? this.id,
      sequentialNumber: sequentialNumber ?? this.sequentialNumber,
      negocioId: negocioId ?? this.negocioId,
      creadoPorUsuarioId: creadoPorUsuarioId ?? this.creadoPorUsuarioId,
      quotationId: quotationId ?? this.quotationId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      origenVenta: origenVenta ?? this.origenVenta,
      isArchived: isArchived ?? this.isArchived,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      discount: discount ?? this.discount,
      abonoInicial: abonoInicial ?? this.abonoInicial,
      porcentajeInteres: porcentajeInteres ?? this.porcentajeInteres,
      moraTotal: moraTotal ?? this.moraTotal,
      cuotasVencidasCount: cuotasVencidasCount ?? this.cuotasVencidasCount,
      saleDate: saleDate ?? this.saleDate,
      motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
      notes: notes ?? this.notes,
      installments: installments ?? this.installments,
    );
  }
}

class SalesStatsModel {
  final double totalIngresos;
  final double totalDeuda;
  final int cantidadVentas;
  final double totalEfectivo;
  final double totalTransferencia;
  final double totalDigital;
  final int totalProductosVendidos;

  SalesStatsModel({
    required this.totalIngresos,
    required this.totalDeuda,
    required this.cantidadVentas,
    this.totalEfectivo = 0.0,
    this.totalTransferencia = 0.0,
    this.totalDigital = 0.0,
    this.totalProductosVendidos = 0,
  });

  factory SalesStatsModel.fromJson(Map<String, dynamic> json) {
    return SalesStatsModel(
      totalIngresos: parseCrmDouble(json['total_ingresos']),
      totalDeuda: parseCrmDouble(json['total_deuda']),
      cantidadVentas: json['cantidad_ventas'] ?? 0,
      totalEfectivo: parseCrmDouble(json['total_efectivo']),
      totalTransferencia: parseCrmDouble(json['total_transferencia']),
      totalDigital: parseCrmDouble(json['total_digital']),
      totalProductosVendidos: json['total_productos_vendidos'] ?? 0,
    );
  }
}
