import 'dart:convert';
import 'package:flutter/material.dart';

// Función global de seguridad para parsear JSON numéricos desde SQLite
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

class ClientModel {
  final int id;
  final int negocioId; 
  final int creadoPorUsuarioId; 
  final int? usuarioVinculadoId; 

  final String fullName;
  final String phone;
  final String? docNumber;
  final String? address;
  final String? email;
  final String? notes;
  
  final double totalDebt; 
  final double saldoAFavor; 
  final int pendingDeliveryCount;
  
  final String registeredDate;
  final String nivelConfianza; 
  final List<String> etiquetas;

  // 🔥 V27: Fidelización, Gamificación y Reputación Multivariable
  final int puntosActuales;
  final int puntosHistoricos;
  final int rachaPagosPuntuales;
  final int scoreReputacion;
  final String nivelReputacion;

  final List<SaleSummary> lastSales; 
  final List<PaymentModel> lastPayments;

  ClientModel({
    required this.id,
    required this.negocioId,
    required this.creadoPorUsuarioId,
    this.usuarioVinculadoId,
    required this.fullName,
    required this.phone,
    this.docNumber,
    this.address,
    this.email,
    this.notes,
    this.totalDebt = 0.0,
    this.saldoAFavor = 0.0,
    this.pendingDeliveryCount = 0, 
    required this.registeredDate,
    this.nivelConfianza = "bueno",
    this.etiquetas = const [],
    this.puntosActuales = 0,
    this.puntosHistoricos = 0,
    this.rachaPagosPuntuales = 0,
    this.scoreReputacion = 500,
    this.nivelReputacion = "PLATA",
    this.lastSales = const [],
    this.lastPayments = const [],
  });

  ReputationTier get tier => ReputationTier.fromKey(nivelReputacion);

  double get suggestedCreditLimit {
    return tier.calculateCreditLimit(lastSales, rachaPagosPuntuales, totalDebt);
  }

  double get limiteCreditoSugerido {
    if (nivelReputacion == 'OBSERVACION' || totalDebt > 0.01) return 0.0;
    return tier.limiteCreditoSugerido;
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    // Manejo seguro de etiquetas (SQLite guarda listas como String)
    List<String> parsedEtiquetas = [];
    if (json['etiquetas'] != null) {
      if (json['etiquetas'] is String) {
        try {
          parsedEtiquetas = List<String>.from(jsonDecode(json['etiquetas']));
        } catch (_) {}
      } else if (json['etiquetas'] is List) {
        parsedEtiquetas = (json['etiquetas'] as List).map((e) => e.toString()).toList();
      }
    }

    return ClientModel(
      id: json['id'] ?? 0,
      negocioId: json['negocio_id'] ?? 0,
      creadoPorUsuarioId: json['creado_por_usuario_id'] ?? 0,
      usuarioVinculadoId: json['usuario_vinculado_id'],
      fullName: json['nombre_completo'] ?? 'Desconocido',
      phone: json['telefono'] ?? '',
      docNumber: json['dni_ruc'],
      address: json['direccion'],
      email: json['correo'],
      notes: json['notas'],
      totalDebt: _parseDouble(json['deuda_total']),
      saldoAFavor: _parseDouble(json['saldo_a_favor']), 
      pendingDeliveryCount: json['entregas_pendientes'] ?? json['entregas_pendientes_count'] ?? 0, 
      registeredDate: json['fecha_registro'] ?? "",
      nivelConfianza: json['nivel_confianza'] ?? "bueno",
      etiquetas: parsedEtiquetas,
      puntosActuales: (json['puntos_actuales'] as num?)?.toInt() ?? 0,
      puntosHistoricos: (json['puntos_historicos'] as num?)?.toInt() ?? 0,
      rachaPagosPuntuales: (json['racha_pagos_puntuales'] as num?)?.toInt() ?? 0,
      scoreReputacion: (json['score_reputacion'] as num?)?.toInt() ?? 500,
      nivelReputacion: json['nivel_reputacion'] ?? "PLATA",
      lastSales: (json['ultimas_ventas'] as List?)?.map((e) => SaleSummary.fromJson(e)).toList() ?? [],
      lastPayments: (json['ultimos_pagos'] as List?)?.map((e) => PaymentModel.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'creado_por_usuario_id': creadoPorUsuarioId,
      'usuario_vinculado_id': usuarioVinculadoId,
      'nombre_completo': fullName,
      'telefono': phone,
      'dni_ruc': docNumber,
      'direccion': address,
      'correo': email,
      'notas': notes,
      'nivel_confianza': nivelConfianza,
      'etiquetas': jsonEncode(etiquetas), // IMPORTANTE: Se guarda como JSON String
      'deuda_total': totalDebt,
      'saldo_a_favor': saldoAFavor,
      'entregas_pendientes': pendingDeliveryCount,
      'puntos_actuales': puntosActuales,
      'puntos_historicos': puntosHistoricos,
      'racha_pagos_puntuales': rachaPagosPuntuales,
      'score_reputacion': scoreReputacion,
      'nivel_reputacion': nivelReputacion,
      'fecha_registro': registeredDate.isEmpty ? DateTime.now().toIso8601String() : registeredDate,
    };
  }

  ClientModel copyWith({
    int? id,
    int? negocioId,
    int? creadoPorUsuarioId,
    int? usuarioVinculadoId,
    String? fullName,
    String? phone,
    String? docNumber,
    String? address,
    String? email,
    String? notes,
    double? totalDebt,
    double? saldoAFavor,
    int? pendingDeliveryCount,
    String? registeredDate,
    String? nivelConfianza,
    List<String>? etiquetas,
    int? puntosActuales,
    int? puntosHistoricos,
    int? rachaPagosPuntuales,
    int? scoreReputacion,
    String? nivelReputacion,
    List<SaleSummary>? lastSales,
    List<PaymentModel>? lastPayments,
  }) {
    return ClientModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      creadoPorUsuarioId: creadoPorUsuarioId ?? this.creadoPorUsuarioId,
      usuarioVinculadoId: usuarioVinculadoId ?? this.usuarioVinculadoId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      docNumber: docNumber ?? this.docNumber,
      address: address ?? this.address,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      totalDebt: totalDebt ?? this.totalDebt,
      saldoAFavor: saldoAFavor ?? this.saldoAFavor,
      pendingDeliveryCount: pendingDeliveryCount ?? this.pendingDeliveryCount,
      registeredDate: registeredDate ?? this.registeredDate,
      nivelConfianza: nivelConfianza ?? this.nivelConfianza,
      etiquetas: etiquetas ?? this.etiquetas,
      puntosActuales: puntosActuales ?? this.puntosActuales,
      puntosHistoricos: puntosHistoricos ?? this.puntosHistoricos,
      rachaPagosPuntuales: rachaPagosPuntuales ?? this.rachaPagosPuntuales,
      scoreReputacion: scoreReputacion ?? this.scoreReputacion,
      nivelReputacion: nivelReputacion ?? this.nivelReputacion,
      lastSales: lastSales ?? this.lastSales,
      lastPayments: lastPayments ?? this.lastPayments,
    );
  }
}

class PaymentModel {
  final int id;
  final int negocioId; 
  final int creadoPorUsuarioId; 
  final double amount;
  final String method;
  final String? note;
  final String date;

  PaymentModel({
    required this.id, 
    required this.negocioId,
    required this.creadoPorUsuarioId,
    required this.amount, 
    required this.method, 
    this.note, 
    required this.date
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? 0,
      negocioId: json['negocio_id'] ?? 0,
      creadoPorUsuarioId: json['creado_por_usuario_id'] ?? 0,
      amount: _parseDouble(json['monto']),
      method: json['metodo_pago'] ?? "Efectivo",
      note: json['nota'],
      date: json['fecha_pago'] ?? "",
    );
  }

  Map<String, dynamic> toSqlite(int? clienteId, int? ventaId, int? cuotaId) {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'creado_por_usuario_id': creadoPorUsuarioId,
      'cliente_id': clienteId,
      'venta_id': ventaId,
      'cuota_id': cuotaId,
      'monto': amount,
      'metodo_pago': method,
      'nota': note,
      'fecha_pago': date.isEmpty ? DateTime.now().toIso8601String() : date,
    };
  }
}

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
  });

  String get displayId => sequentialNumber != null ? "$sequentialNumber" : "$id";

  double get trueTotal {
    // El monto_total (total) ahora ya incluye el interés desde la base de datos
    // por lo que no es necesario volver a sumarlo dinámicamente.
    return total;
  }

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      id: json['id'] ?? 0,
      sequentialNumber: json['numero_secuencial'],
      total: _parseDouble(json['monto_total']),
      montoPagado: _parseDouble(json['monto_pagado']), 
      date: json['fecha_venta'] ?? "",
      status: json['estado_entrega'] ?? "entregado",
      origenVenta: json['origen_venta'] ?? "smart_quotation",
      itemsCount: json['items_count'] ?? 0,
      abonoInicial: _parseDouble(json['abono_inicial']),
      porcentajeInteres: _parseDouble(json['porcentaje_interes']),
      estadoPago: json['estado_pago'] ?? "pagado",
      isArchived: json['is_archived'] == 1 || json['is_archived'] == true,
      motivoAnulacion: json['motivo_anulacion'],
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
    final amt = _parseDouble(json['monto']);
    return InstallmentModel(
      id: json['id'],
      installmentNumber: json['numero_cuota'] ?? 1,
      amount: amt,
      montoPagado: _parseDouble(json['monto_pagado']),
      dueDate: json['fecha_vencimiento'] ?? "",
      status: json['estado'] ?? "pendiente",
      montoOriginal: json['monto_original'] != null ? _parseDouble(json['monto_original']) : amt,
      moraMonto: _parseDouble(json['mora_monto']),
      moraPorcentaje: _parseDouble(json['mora_porcentaje']),
      moraAutomatica: json['mora_automatica'] == 1 || json['mora_automatica'] == true,
      moraFrecuencia: json['mora_frecuencia'],
      moraIntervaloDias: (json['mora_intervalo_dias'] as num?)?.toInt() ?? 1,
      moraTipo: json['mora_tipo'] ?? 'fijo',
      moraValor: _parseDouble(json['mora_valor']),
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
      totalAmount: _parseDouble(json['monto_total']),
      paidAmount: _parseDouble(json['monto_pagado']),
      discount: _parseDouble(json['descuento_aplicado']),
      abonoInicial: _parseDouble(json['abono_inicial']),
      porcentajeInteres: _parseDouble(json['porcentaje_interes']),
      moraTotal: _parseDouble(json['mora_total']),
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
      totalIngresos: _parseDouble(json['total_ingresos']),
      totalDeuda: _parseDouble(json['total_deuda']),
      cantidadVentas: json['cantidad_ventas'] ?? 0,
      totalEfectivo: _parseDouble(json['total_efectivo']),
      totalTransferencia: _parseDouble(json['total_transferencia']),
      totalDigital: _parseDouble(json['total_digital']),
      totalProductosVendidos: json['total_productos_vendidos'] ?? 0,
    );
  }
}

class BundleChange {
  final int itemId;
  final int bundleId;
  final String bundleName;
  final List<String> changes;
  final bool isDeactivated;
  final bool isDeleted;
  final bool isCompositionChange;
  final double? oldPrice;
  final double? newPrice;

  BundleChange({
    required this.itemId,
    required this.bundleId,
    required this.bundleName,
    required this.changes,
    this.isDeactivated = false,
    this.isDeleted = false,
    this.isCompositionChange = false,
    this.oldPrice,
    this.newPrice,
  });

  factory BundleChange.fromJson(Map<String, dynamic> json) {
    return BundleChange(
      itemId: json['item_id'] ?? -1,
      bundleId: json['bundle_id'] ?? -1,
      bundleName: json['bundle_name'] ?? 'Oferta',
      changes: (json['changes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isDeactivated: json['is_deactivated'] == true || json['is_deactivated'] == 1,
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
      isCompositionChange: json['is_composition_change'] == true || json['is_composition_change'] == 1,
      oldPrice: json['old_price'] != null ? (json['old_price'] as num).toDouble() : null,
      newPrice: json['new_price'] != null ? (json['new_price'] as num).toDouble() : null,
    );
  }
}

class ValidationResult {
  final bool hasIssues;
  final bool canSell;
  final List<StockWarning> stockWarnings;
  final List<PriceChange> priceChanges;
  final List<NameChange> nameChanges;
  final List<BundleChange> bundleChanges;
  final List<UnitChange> unitChanges;
  final List<SharedStockConflict> sharedStockConflicts;

  ValidationResult({
    required this.hasIssues,
    required this.canSell,
    required this.stockWarnings,
    required this.priceChanges,
    this.nameChanges = const [],
    this.bundleChanges = const [],
    this.unitChanges = const [],
    this.sharedStockConflicts = const [],
  });

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      hasIssues: json['has_issues'] == 1 || json['has_issues'] == true,
      canSell: json['can_sell'] == 1 || json['can_sell'] == true || json['can_sell'] == null,
      stockWarnings: (json['stock_warnings'] as List?)?.map((e) => StockWarning.fromJson(e)).toList() ?? [],
      priceChanges: (json['price_changes'] as List?)?.map((e) => PriceChange.fromJson(e)).toList() ?? [],
      nameChanges: (json['name_changes'] as List?)?.map((e) => NameChange.fromJson(e)).toList() ?? [],
      bundleChanges: (json['bundle_changes'] as List?)?.map((e) => BundleChange.fromJson(e)).toList() ?? [],
      unitChanges: (json['unit_changes'] as List?)?.map((e) => UnitChange.fromJson(e)).toList() ?? [],
      sharedStockConflicts: (json['shared_stock_conflicts'] as List?)?.map((e) => SharedStockConflict.fromJson(e)).toList() ?? [],
    );
  }
}

class SharedStockConflict {
  final int productId;
  final String productName;
  final int totalSharedPool;
  final int totalRequestedBaseUnits;
  final int excessBaseUnits;
  final List<QuoteItemConflictDetail> conflictingItems;

  const SharedStockConflict({
    required this.productId,
    required this.productName,
    required this.totalSharedPool,
    required this.totalRequestedBaseUnits,
    required this.excessBaseUnits,
    required this.conflictingItems,
  });

  factory SharedStockConflict.fromJson(Map<String, dynamic> json) {
    return SharedStockConflict(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? 'Producto compartido',
      totalSharedPool: json['total_shared_pool'] ?? 0,
      totalRequestedBaseUnits: json['total_requested_base_units'] ?? 0,
      excessBaseUnits: json['excess_base_units'] ?? 0,
      conflictingItems: (json['conflicting_items'] as List?)
              ?.map((e) => QuoteItemConflictDetail.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'total_shared_pool': totalSharedPool,
    'total_requested_base_units': totalRequestedBaseUnits,
    'excess_base_units': excessBaseUnits,
    'conflicting_items': conflictingItems.map((e) => e.toJson()).toList(),
  };
}

class QuoteItemConflictDetail {
  final int itemId;
  final int presentationId;
  final String presentationName;
  final int requestedQty;
  final int conversionFactor;
  final int requestedBaseUnits;
  final int? cupoMaximo;

  const QuoteItemConflictDetail({
    required this.itemId,
    required this.presentationId,
    required this.presentationName,
    required this.requestedQty,
    required this.conversionFactor,
    required this.requestedBaseUnits,
    this.cupoMaximo,
  });

  factory QuoteItemConflictDetail.fromJson(Map<String, dynamic> json) {
    return QuoteItemConflictDetail(
      itemId: json['item_id'] ?? 0,
      presentationId: json['presentation_id'] ?? 0,
      presentationName: json['presentation_name'] ?? '',
      requestedQty: json['requested_qty'] ?? 0,
      conversionFactor: json['conversion_factor'] ?? 1,
      requestedBaseUnits: json['requested_base_units'] ?? 0,
      cupoMaximo: json['cupo_maximo'],
    );
  }

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'presentation_id': presentationId,
    'presentation_name': presentationName,
    'requested_qty': requestedQty,
    'conversion_factor': conversionFactor,
    'requested_base_units': requestedBaseUnits,
    'cupo_maximo': cupoMaximo,
  };
}

class UnitChange {
  final int itemId;
  final String productName;
  final String oldUnit;
  final String newUnit;
  final int oldFactor;
  final int newFactor;
  final String message;

  UnitChange({
    required this.itemId,
    required this.productName,
    required this.oldUnit,
    required this.newUnit,
    this.oldFactor = 1,
    this.newFactor = 1,
    this.message = "",
  });

  factory UnitChange.fromJson(Map<String, dynamic> json) {
    return UnitChange(
      itemId: json['item_id'] ?? -1,
      productName: json['product_name'] ?? 'Desconocido',
      oldUnit: json['old_unit'] ?? 'Unidad',
      newUnit: json['new_unit'] ?? 'Unidad',
      oldFactor: json['old_factor'] ?? 1,
      newFactor: json['new_factor'] ?? 1,
      message: json['message'] ?? "",
    );
  }
}

class NameChange {
  final int itemId;
  final String oldName;
  final String newName;
  final String message;

  NameChange({
    required this.itemId,
    required this.oldName,
    required this.newName,
    this.message = "",
  });

  factory NameChange.fromJson(Map<String, dynamic> json) {
    return NameChange(
      itemId: json['item_id'] ?? -1,
      oldName: json['old_name'] ?? 'Desconocido',
      newName: json['new_name'] ?? 'Desconocido',
      message: json['message'] ?? "",
    );
  }
}

class PriceChange {
  final int itemId;
  final String productName;
  final double oldPrice;
  final double newPrice;
  final double newBasePrice; 
  final String message;      

  PriceChange({
    required this.itemId, required this.productName, required this.oldPrice, required this.newPrice, 
    this.newBasePrice = 0.0, this.message = ""
  });

  factory PriceChange.fromJson(Map<String, dynamic> json) {
    return PriceChange(
      itemId: json['item_id'] ?? -1,
      productName: json['product_name'] ?? 'Desconocido',
      oldPrice: _parseDouble(json['old_price']),
      newPrice: _parseDouble(json['new_price']),
      newBasePrice: _parseDouble(json['new_base_price']),
      message: json['message'] ?? "",
    );
  }
}

class StockWarning {
  final int itemId;
  final String productName;
  final int requested;
  final int available;
  final String message; 

  StockWarning({required this.itemId, required this.productName, required this.requested, required this.available, this.message = ""});

  factory StockWarning.fromJson(Map<String, dynamic> json) {
    return StockWarning(
      itemId: json['item_id'] ?? -1,
      productName: json['product_name'] ?? 'Desconocido',
      requested: json['requested_qty'] ?? 0,
      available: json['available_stock'] ?? 0,
      message: json['message'] ?? "",
    );
  }
}

class LedgerItem {
  final int idRef;
  final String tipo; 
  final String? subtipo;
  final DateTime fecha;
  final double monto;
  final String detalle;
  final double saldoResultante;

  LedgerItem({
    required this.idRef,
    required this.tipo,
    this.subtipo,
    required this.fecha,
    required this.monto,
    required this.detalle,
    required this.saldoResultante,
  });

  factory LedgerItem.fromJson(Map<String, dynamic> json) {
    return LedgerItem(
      idRef: json['id_ref'] ?? 0,
      tipo: json['tipo'] ?? 'cargo',
      subtipo: json['subtipo'],
      fecha: DateTime.tryParse(json['fecha'] ?? "") ?? DateTime.now(),
      monto: _parseDouble(json['monto']),
      detalle: json['detalle'] ?? '',
      saldoResultante: _parseDouble(json['saldo_resultante']),
    );
  }
}

// ==========================================
// 🔥 V27: MODELOS DE FIDELIZACIÓN Y REPUTACIÓN
// ==========================================

class ReputationTier {
  final String key;
  final String displayName;
  final int minScore;
  final int maxScore;
  final Color primaryColor;
  final Color badgeDarkColor;
  final Color badgeLightColor;
  final IconData icon;
  final double creditFactor;

  const ReputationTier({
    required this.key,
    required this.displayName,
    required this.minScore,
    required this.maxScore,
    required this.primaryColor,
    required this.badgeDarkColor,
    required this.badgeLightColor,
    required this.icon,
    required this.creditFactor,
  });

  int get colorHex => primaryColor.toARGB32();
  String get name => key;

  String get badgeText {
    switch (key) {
      case 'DIAMANTE_VIP':
        return '💎 Diamante VIP';
      case 'ORO':
        return '🏆 Oro';
      case 'PLATA':
        return '🥈 Plata';
      case 'BRONCE':
        return '🥉 Bronce';
      case 'OBSERVACION':
      default:
        return '⚠️ Observación';
    }
  }

  double get limiteCreditoSugerido {
    switch (key) {
      case 'DIAMANTE_VIP':
        return 1500.0;
      case 'ORO':
        return 700.0;
      case 'PLATA':
        return 350.0;
      case 'BRONCE':
        return 150.0;
      case 'OBSERVACION':
      default:
        return 0.0;
    }
  }

  static const observacion = ReputationTier(
    key: 'OBSERVACION',
    displayName: 'En Observación',
    minScore: 0,
    maxScore: 399,
    primaryColor: Color(0xFFEF4444),
    badgeDarkColor: Color(0x33EF4444),
    badgeLightColor: Color(0x25EF4444),
    icon: Icons.warning_amber_rounded,
    creditFactor: 0.0,
  );

  static const bronce = ReputationTier(
    key: 'BRONCE',
    displayName: 'Bronce',
    minScore: 400,
    maxScore: 599,
    primaryColor: Color(0xFFCD7F32),
    badgeDarkColor: Color(0x33CD7F32),
    badgeLightColor: Color(0x25CD7F32),
    icon: Icons.shield_outlined,
    creditFactor: 1.0,
  );

  static const plata = ReputationTier(
    key: 'PLATA',
    displayName: 'Plata',
    minScore: 600,
    maxScore: 749,
    primaryColor: Color(0xFFA8B2C1),
    badgeDarkColor: Color(0x33A8B2C1),
    badgeLightColor: Color(0x25A8B2C1),
    icon: Icons.verified_outlined,
    creditFactor: 2.0,
  );

  static const oro = ReputationTier(
    key: 'ORO',
    displayName: 'Oro',
    minScore: 750,
    maxScore: 899,
    primaryColor: Color(0xFFFFB800),
    badgeDarkColor: Color(0x33FFB800),
    badgeLightColor: Color(0x25FFB800),
    icon: Icons.military_tech_rounded,
    creditFactor: 3.5,
  );

  static const diamanteVip = ReputationTier(
    key: 'DIAMANTE_VIP',
    displayName: 'Diamante VIP',
    minScore: 900,
    maxScore: 1000,
    primaryColor: Color(0xFF00E5FF),
    badgeDarkColor: Color(0x3300E5FF),
    badgeLightColor: Color(0x2500E5FF),
    icon: Icons.diamond_rounded,
    creditFactor: 5.0,
  );

  static const List<ReputationTier> allTiers = [
    diamanteVip,
    oro,
    plata,
    bronce,
    observacion,
  ];

  static ReputationTier fromScore(int score) {
    if (score >= 900) return diamanteVip;
    if (score >= 750) return oro;
    if (score >= 600) return plata;
    if (score >= 400) return bronce;
    return observacion;
  }

  static ReputationTier fromKey(String? key) {
    final clean = (key ?? 'PLATA').toUpperCase().trim();
    switch (clean) {
      case 'DIAMANTE_VIP':
      case 'DIAMANTE':
      case 'VIP':
        return diamanteVip;
      case 'ORO':
        return oro;
      case 'BRONCE':
        return bronce;
      case 'OBSERVACION':
      case 'MOROSO':
      case 'MALO':
        return observacion;
      case 'PLATA':
      default:
        return plata;
    }
  }

  double calculateCreditLimit(List<SaleSummary> sales, int streak, double totalDebt) {
    // Si está en observación o tiene deudas activas impagas, crédito es 0.0
    if (creditFactor <= 0.0 || totalDebt > 0.01) return 0.0;

    final validSales = sales.where((s) => !s.isArchived).toList();
    if (validSales.isEmpty) {
      return 50.0 * creditFactor;
    }

    double sum = 0.0;
    for (var s in validSales) {
      sum += s.trueTotal;
    }
    double avgTicket = sum / validSales.length;
    if (avgTicket < 30.0) avgTicket = 30.0;

    double punctualityBonus = 1.0 + (streak * 0.05).clamp(0.0, 0.4);
    double limit = avgTicket * creditFactor * punctualityBonus;

    // Redondear a múltiplos de 10
    return ((limit / 10).round() * 10).toDouble();
  }
}

class RewardGoalModel {
  final int id;
  final int negocioId;
  final String nombre;
  final int puntosRequeridos;
  final String tipoBeneficio; // DESCUENTO_MONTO, DESCUENTO_PORCENTAJE, PRODUCTO_REGALO, CREDITO_PREFERENCIAL
  final double valorBeneficio;
  final String? descripcion;
  final bool activo;
  final bool esPredeterminada;
  final String createdAt;

  RewardGoalModel({
    required this.id,
    required this.negocioId,
    required this.nombre,
    required this.puntosRequeridos,
    required this.tipoBeneficio,
    required this.valorBeneficio,
    this.descripcion,
    this.activo = true,
    this.esPredeterminada = false,
    required this.createdAt,
  });

  String get titulo => nombre;
  String get fechaCreacion => createdAt;

  String get formattedBenefit {
    switch (tipoBeneficio) {
      case 'DESCUENTO_MONTO':
        return 'S/ ${valorBeneficio.toStringAsFixed(2)} de Descuento';
      case 'DESCUENTO_PORCENTAJE':
        return '${valorBeneficio.round()}% de Descuento';
      case 'PRODUCTO_REGALO':
        return 'Producto de Regalo';
      case 'CREDITO_PREFERENCIAL':
        return 'Línea de Crédito S/ ${valorBeneficio.toStringAsFixed(2)}';
      default:
        return valorBeneficio.toString();
    }
  }

  factory RewardGoalModel.fromJson(Map<String, dynamic> json) {
    return RewardGoalModel(
      id: json['id'] ?? 0,
      negocioId: json['negocio_id'] ?? 0,
      nombre: json['titulo'] ?? json['nombre'] ?? '',
      puntosRequeridos: (json['puntos_requeridos'] as num?)?.toInt() ?? 0,
      tipoBeneficio: json['tipo_beneficio'] ?? 'DESCUENTO_MONTO',
      valorBeneficio: _parseDouble(json['valor_beneficio']),
      descripcion: json['descripcion'],
      activo: json['activo'] == 1 || json['activo'] == true,
      esPredeterminada: json['es_predeterminada'] == 1 || json['es_predeterminada'] == true,
      createdAt: json['created_at'] ?? '',
    );
  }

  factory RewardGoalModel.fromMap(Map<String, dynamic> map) => RewardGoalModel.fromJson(map);

  RewardGoalModel copyWith({
    int? id,
    int? negocioId,
    String? nombre,
    int? puntosRequeridos,
    String? tipoBeneficio,
    double? valorBeneficio,
    String? descripcion,
    bool? activo,
    bool? esPredeterminada,
    String? createdAt,
  }) {
    return RewardGoalModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      nombre: nombre ?? this.nombre,
      puntosRequeridos: puntosRequeridos ?? this.puntosRequeridos,
      tipoBeneficio: tipoBeneficio ?? this.tipoBeneficio,
      valorBeneficio: valorBeneficio ?? this.valorBeneficio,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
      esPredeterminada: esPredeterminada ?? this.esPredeterminada,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'nombre': nombre,
      'puntos_requeridos': puntosRequeridos,
      'tipo_beneficio': tipoBeneficio,
      'valor_beneficio': valorBeneficio,
      'descripcion': descripcion,
      'activo': activo ? 1 : 0,
      'es_predeterminada': esPredeterminada ? 1 : 0,
      'created_at': createdAt.isEmpty ? DateTime.now().toIso8601String() : createdAt,
    };
  }
}

class ClientRewardModel {
  final int id;
  final int negocioId;
  final int clienteId;
  final int metaId;
  final int puntosConsumidos;
  final String estado; // PENDIENTE_REVISION, APROBADA_NOTIFICADA, CANJEADA, DESCARTADA
  final String tipoBeneficio;
  final double valorBeneficio;
  final String tituloRecompensa;
  final String? descripcionRecompensa;
  final String fechaDesbloqueo;
  final String? fechaAprobacion;
  final String? fechaCanje;
  final int? ventaCanjeId;
  final String? notaRevision;
  final String? clienteNombre;
  final String? clienteTelefono;

  ClientRewardModel({
    required this.id,
    required this.negocioId,
    required this.clienteId,
    required this.metaId,
    required this.puntosConsumidos,
    this.estado = 'PENDIENTE_REVISION',
    required this.tipoBeneficio,
    required this.valorBeneficio,
    required this.tituloRecompensa,
    this.descripcionRecompensa,
    required this.fechaDesbloqueo,
    this.fechaAprobacion,
    this.fechaCanje,
    this.ventaCanjeId,
    this.notaRevision,
    this.clienteNombre,
    this.clienteTelefono,
  });

  bool get isPendingReview => estado == 'PENDIENTE_REVISION';
  bool get isApproved => estado == 'APROBADA_NOTIFICADA';
  bool get isRedeemed => estado == 'CANJEADA';
  bool get isDiscarded => estado == 'DESCARTADA';

  String get metaTitulo => tituloRecompensa;

  String get formattedBenefit {
    switch (tipoBeneficio) {
      case 'DESCUENTO_MONTO':
        return 'S/ ${valorBeneficio.toStringAsFixed(2)} de Descuento';
      case 'DESCUENTO_PORCENTAJE':
        return '${valorBeneficio.round()}% de Descuento';
      case 'PRODUCTO_REGALO':
        return 'Producto de Regalo';
      case 'CREDITO_PREFERENCIAL':
        return 'Línea Preferencial S/ ${valorBeneficio.toStringAsFixed(2)}';
      default:
        return tituloRecompensa;
    }
  }

  factory ClientRewardModel.fromJson(Map<String, dynamic> json) {
    return ClientRewardModel(
      id: json['id'] ?? 0,
      negocioId: json['negocio_id'] ?? 0,
      clienteId: json['cliente_id'] ?? 0,
      metaId: json['meta_id'] ?? 0,
      puntosConsumidos: (json['puntos_consumidos'] as num?)?.toInt() ?? 0,
      estado: json['estado'] ?? 'PENDIENTE_REVISION',
      tipoBeneficio: json['tipo_beneficio'] ?? 'DESCUENTO_MONTO',
      valorBeneficio: _parseDouble(json['valor_beneficio']),
      tituloRecompensa: json['meta_titulo'] ?? json['titulo_recompensa'] ?? 'Premio Desbloqueado',
      descripcionRecompensa: json['descripcion_recompensa'],
      fechaDesbloqueo: json['fecha_desbloqueo'] ?? '',
      fechaAprobacion: json['fecha_aprobacion'],
      fechaCanje: json['fecha_canje'],
      ventaCanjeId: json['venta_canje_id'],
      notaRevision: json['nota_revision'],
      clienteNombre: json['cliente_nombre'] ?? json['nombre_completo'],
      clienteTelefono: json['cliente_telefono'] ?? json['telefono'],
    );
  }

  factory ClientRewardModel.fromMap(Map<String, dynamic> map) => ClientRewardModel.fromJson(map);

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'cliente_id': clienteId,
      'meta_id': metaId,
      'puntos_consumidos': puntosConsumidos,
      'estado': estado,
      'tipo_beneficio': tipoBeneficio,
      'valor_beneficio': valorBeneficio,
      'titulo_recompensa': tituloRecompensa,
      'descripcion_recompensa': descripcionRecompensa,
      'fecha_desbloqueo': fechaDesbloqueo.isEmpty ? DateTime.now().toIso8601String() : fechaDesbloqueo,
      'fecha_aprobacion': fechaAprobacion,
      'fecha_canje': fechaCanje,
      'venta_canje_id': ventaCanjeId,
      'nota_revision': notaRevision,
    };
  }

  ClientRewardModel copyWith({
    int? id,
    int? negocioId,
    int? clienteId,
    int? metaId,
    int? puntosConsumidos,
    String? estado,
    String? tipoBeneficio,
    double? valorBeneficio,
    String? tituloRecompensa,
    String? descripcionRecompensa,
    String? fechaDesbloqueo,
    String? fechaAprobacion,
    String? fechaCanje,
    int? ventaCanjeId,
    String? notaRevision,
    String? clienteNombre,
    String? clienteTelefono,
  }) {
    return ClientRewardModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      clienteId: clienteId ?? this.clienteId,
      metaId: metaId ?? this.metaId,
      puntosConsumidos: puntosConsumidos ?? this.puntosConsumidos,
      estado: estado ?? this.estado,
      tipoBeneficio: tipoBeneficio ?? this.tipoBeneficio,
      valorBeneficio: valorBeneficio ?? this.valorBeneficio,
      tituloRecompensa: tituloRecompensa ?? this.tituloRecompensa,
      descripcionRecompensa: descripcionRecompensa ?? this.descripcionRecompensa,
      fechaDesbloqueo: fechaDesbloqueo ?? this.fechaDesbloqueo,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      fechaCanje: fechaCanje ?? this.fechaCanje,
      ventaCanjeId: ventaCanjeId ?? this.ventaCanjeId,
      notaRevision: notaRevision ?? this.notaRevision,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
    );
  }
}

class LoyaltyLedgerModel {
  final int id;
  final int negocioId;
  final int clienteId;
  final String tipoMovimiento; // GANANCIA_COMPRA, BONO_PAGO_PUNTUAL, AJUSTE_MANUAL, PERDIDA_MORA, REVERSION_ANULACION, CANJE_RECOMPENSA, RESTAURACION_RECHAZO
  final int puntosDelta;
  final int puntosSaldoResultante;
  final int scoreDelta;
  final int scoreResultante;
  final String motivo;
  final String? referenciaTipo;
  final int? referenciaId;
  final String fechaRegistro;

  LoyaltyLedgerModel({
    required this.id,
    required this.negocioId,
    required this.clienteId,
    required this.tipoMovimiento,
    required this.puntosDelta,
    required this.puntosSaldoResultante,
    required this.scoreDelta,
    required this.scoreResultante,
    required this.motivo,
    this.referenciaTipo,
    this.referenciaId,
    required this.fechaRegistro,
  });

  bool get isPositive => puntosDelta >= 0;
  int get saldoPuntosDespues => puntosSaldoResultante;
  int get scoreReputacionDelta => scoreDelta;

  factory LoyaltyLedgerModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyLedgerModel(
      id: json['id'] ?? 0,
      negocioId: json['negocio_id'] ?? 0,
      clienteId: json['cliente_id'] ?? 0,
      tipoMovimiento: json['tipo_movimiento'] ?? 'GANANCIA_COMPRA',
      puntosDelta: (json['puntos_delta'] as num?)?.toInt() ?? 0,
      puntosSaldoResultante: (json['puntos_saldo_resultante'] as num?)?.toInt() ?? 0,
      scoreDelta: (json['score_delta'] as num?)?.toInt() ?? 0,
      scoreResultante: (json['score_resultante'] as num?)?.toInt() ?? 500,
      motivo: json['motivo'] ?? '',
      referenciaTipo: json['referencia_tipo'],
      referenciaId: json['referencia_id'],
      fechaRegistro: json['fecha_registro'] ?? '',
    );
  }

  factory LoyaltyLedgerModel.fromMap(Map<String, dynamic> map) => LoyaltyLedgerModel.fromJson(map);

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'negocio_id': negocioId,
      'cliente_id': clienteId,
      'tipo_movimiento': tipoMovimiento,
      'puntos_delta': puntosDelta,
      'puntos_saldo_resultante': puntosSaldoResultante,
      'score_delta': scoreDelta,
      'score_resultante': scoreResultante,
      'motivo': motivo,
      'referencia_tipo': referenciaTipo,
      'referencia_id': referenciaId,
      'fecha_registro': fechaRegistro.isEmpty ? DateTime.now().toIso8601String() : fechaRegistro,
    };
  }
}