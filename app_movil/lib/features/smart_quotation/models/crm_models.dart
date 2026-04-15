// Función global de seguridad para parsear JSON numéricos desde Python
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
    this.lastSales = const [],
    this.lastPayments = const [],
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
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
      
      // 🔥 PARSEO SEGURO
      totalDebt: _parseDouble(json['deuda_total']),
      saldoAFavor: _parseDouble(json['saldo_a_favor']), 
      pendingDeliveryCount: json['entregas_pendientes'] ?? json['entregas_pendientes_count'] ?? 0, 
      
      registeredDate: json['fecha_registro'] ?? "",
      nivelConfianza: json['nivel_confianza'] ?? "bueno",
      etiquetas: (json['etiquetas'] as List?)?.map((e) => e.toString()).toList() ?? [],

      lastSales: (json['ultimas_ventas'] as List?)?.map((e) => SaleSummary.fromJson(e)).toList() ?? [],
      lastPayments: (json['ultimos_pagos'] as List?)?.map((e) => PaymentModel.fromJson(e)).toList() ?? [],
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
}

class SaleSummary {
  final int id;
  final double total;
  final double montoPagado; 
  final String date;
  final String status;
  final String origenVenta; 
  final int itemsCount;     

  SaleSummary({required this.id, required this.total, this.montoPagado = 0.0, required this.date, required this.status, this.origenVenta = "smart_quotation", this.itemsCount = 0});

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      id: json['id'] ?? 0,
      total: _parseDouble(json['monto_total']),
      montoPagado: _parseDouble(json['monto_pagado']), 
      date: json['fecha_venta'] ?? "",
      status: json['estado_entrega'] ?? "entregado",
      origenVenta: json['origen_venta'] ?? "smart_quotation",
      itemsCount: json['items_count'] ?? 0,
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

  InstallmentModel({
    this.id,
    required this.installmentNumber,
    required this.amount,
    this.montoPagado = 0.0,
    required this.dueDate,
    this.status = "pendiente",
  });

  factory InstallmentModel.fromJson(Map<String, dynamic> json) {
    return InstallmentModel(
      id: json['id'],
      installmentNumber: json['numero_cuota'] ?? 1,
      amount: _parseDouble(json['monto']),
      montoPagado: _parseDouble(json['monto_pagado']),
      dueDate: json['fecha_vencimiento'] ?? "",
      status: json['estado'] ?? "pendiente",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "numero_cuota": installmentNumber,
      "monto": amount,
      "fecha_vencimiento": dueDate,
    };
  }
}

class SaleModel {
  final int id;
  final int negocioId; 
  final int creadoPorUsuarioId; 
  final int? quotationId; 
  final int? clientId;
  final String origenVenta; 
  final bool isArchived;    
  final String paymentMethod;
  final String paymentStatus;
  final String deliveryStatus;
  final String? deliveryDate; 
  final double totalAmount;
  final double paidAmount;
  final double discount;
  final String saleDate;
  final List<InstallmentModel> installments; 

  SaleModel({
    required this.id,
    required this.negocioId,
    required this.creadoPorUsuarioId,
    this.quotationId,
    required this.clientId,
    this.origenVenta = "smart_quotation",
    this.isArchived = false,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryStatus,
    this.deliveryDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.discount,
    required this.saleDate,
    this.installments = const [],
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] ?? 0,
      negocioId: json['negocio_id'] ?? 0,
      creadoPorUsuarioId: json['creado_por_usuario_id'] ?? 0,
      quotationId: json['cotizacion_id'],
      clientId: json['cliente_id'],
      origenVenta: json['origen_venta'] ?? "smart_quotation",
      isArchived: json['is_archived'] ?? false,
      paymentMethod: json['metodo_pago'] ?? "",
      paymentStatus: json['estado_pago'] ?? "",
      deliveryStatus: json['estado_entrega'] ?? "",
      deliveryDate: json['fecha_entrega'],
      totalAmount: _parseDouble(json['monto_total']),
      paidAmount: _parseDouble(json['monto_pagado']),
      discount: _parseDouble(json['descuento_aplicado']),
      saleDate: json['fecha_venta'] ?? "",
      installments: (json['cuotas'] as List?)?.map((e) => InstallmentModel.fromJson(e)).toList() ?? [],
    );
  }
}

class SalesStatsModel {
  final double totalIngresos;
  final double totalDeuda;
  final int cantidadVentas;

  SalesStatsModel({
    required this.totalIngresos,
    required this.totalDeuda,
    required this.cantidadVentas,
  });

  factory SalesStatsModel.fromJson(Map<String, dynamic> json) {
    return SalesStatsModel(
      totalIngresos: _parseDouble(json['total_ingresos']),
      totalDeuda: _parseDouble(json['total_deuda']),
      cantidadVentas: json['cantidad_ventas'] ?? 0,
    );
  }
}

class ValidationResult {
  final bool hasIssues;
  final bool canSell;
  final List<StockWarning> stockWarnings;
  final List<PriceChange> priceChanges;

  ValidationResult({
    required this.hasIssues,
    required this.canSell,
    required this.stockWarnings,
    required this.priceChanges,
  });

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      hasIssues: json['has_issues'] ?? false,
      canSell: json['can_sell'] ?? true,
      stockWarnings: (json['stock_warnings'] as List?)?.map((e) => StockWarning.fromJson(e)).toList() ?? [],
      priceChanges: (json['price_changes'] as List?)?.map((e) => PriceChange.fromJson(e)).toList() ?? [],
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
  final DateTime fecha;
  final double monto;
  final String detalle;
  final double saldoResultante;

  LedgerItem({
    required this.idRef,
    required this.tipo,
    required this.fecha,
    required this.monto,
    required this.detalle,
    required this.saldoResultante,
  });

  factory LedgerItem.fromJson(Map<String, dynamic> json) {
    return LedgerItem(
      idRef: json['id_ref'] ?? 0,
      tipo: json['tipo'] ?? 'cargo',
      fecha: DateTime.tryParse(json['fecha'] ?? "") ?? DateTime.now(),
      monto: _parseDouble(json['monto']),
      detalle: json['detalle'] ?? '',
      saldoResultante: _parseDouble(json['saldo_resultante']),
    );
  }
}