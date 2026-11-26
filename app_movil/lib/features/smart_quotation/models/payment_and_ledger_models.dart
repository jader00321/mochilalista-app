import 'package:app_movil/features/smart_quotation/models/crm_parse_helpers.dart';

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
      amount: parseCrmDouble(json['monto']),
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


class LedgerItem {
  final int idRef;
  final String tipo; // 'cargo', 'abono', 'evento'
  final String? subtipo; // 'prestamo', 'venta', 'pago', 'mora', 'reprogramacion', 'ajuste', 'devolucion', 'retiro_saldo'
  final DateTime fecha;
  final double monto;
  final String detalle;
  final double saldoResultante;
  final int? ventaId;
  final int? cuotaId;
  final int? pagoId;
  final int? eventoId;
  final double? montoBase;
  final double? moraMonto;
  final String? metodoPago;
  final String? nota;
  final int? cuotaNumero;
  final String? entidadRef;
  final bool canEdit;
  final bool canDelete;
  final String? tipoEvento;
  final DateTime? fechaOperacion;

  LedgerItem({
    required this.idRef,
    required this.tipo,
    this.subtipo,
    required this.fecha,
    required this.monto,
    required this.detalle,
    required this.saldoResultante,
    this.ventaId,
    this.cuotaId,
    this.pagoId,
    this.eventoId,
    this.montoBase,
    this.moraMonto,
    this.metodoPago,
    this.nota,
    this.cuotaNumero,
    this.entidadRef,
    this.canEdit = false,
    this.canDelete = false,
    this.tipoEvento,
    this.fechaOperacion,
  });

  factory LedgerItem.fromJson(Map<String, dynamic> json) {
    return LedgerItem(
      idRef: json['id_ref'] ?? 0,
      tipo: json['tipo'] ?? 'cargo',
      subtipo: json['subtipo'],
      fecha: DateTime.tryParse(json['fecha'] ?? "") ?? DateTime.now(),
      monto: parseCrmDouble(json['monto']),
      detalle: json['detalle'] ?? '',
      saldoResultante: parseCrmDouble(json['saldo_resultante']),
      ventaId: json['venta_id'],
      cuotaId: json['cuota_id'],
      pagoId: json['pago_id'],
      eventoId: json['evento_id'],
      montoBase: json['monto_base'] != null ? parseCrmDouble(json['monto_base']) : null,
      moraMonto: json['mora_monto'] != null ? parseCrmDouble(json['mora_monto']) : null,
      metodoPago: json['metodo_pago'],
      nota: json['nota'],
      cuotaNumero: json['cuota_numero'],
      entidadRef: json['entidad_ref'],
      canEdit: json['can_edit'] == true || json['can_edit'] == 1,
      canDelete: json['can_delete'] == true || json['can_delete'] == 1,
      tipoEvento: json['tipo_evento'],
      fechaOperacion: json['fecha_operacion'] != null ? DateTime.tryParse(json['fecha_operacion']) : null,
    );
  }
}

class ClienteEventoFinancieroModel {
  final int id;
  final int negocioId;
  final int clienteId;
  final int? ventaId;
  final int? cuotaId;
  final int? pagoId;
  final String tipoEvento;
  final String titulo;
  final String? descripcion;
  final double? montoAnterior;
  final double? montoNuevo;
  final double montoImpacto;
  final String fechaEvento;
  final String? metadata;

  ClienteEventoFinancieroModel({
    required this.id,
    required this.negocioId,
    required this.clienteId,
    this.ventaId,
    this.cuotaId,
    this.pagoId,
    required this.tipoEvento,
    required this.titulo,
    this.descripcion,
    this.montoAnterior,
    this.montoNuevo,
    this.montoImpacto = 0.0,
    required this.fechaEvento,
    this.metadata,
  });

  factory ClienteEventoFinancieroModel.fromJson(Map<String, dynamic> json) {
    return ClienteEventoFinancieroModel(
      id: json['id'] ?? 0,
      negocioId: json['negocio_id'] ?? 0,
      clienteId: json['cliente_id'] ?? 0,
      ventaId: json['venta_id'],
      cuotaId: json['cuota_id'],
      pagoId: json['pago_id'],
      tipoEvento: json['tipo_evento'] ?? 'evento',
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'],
      montoAnterior: json['monto_anterior'] != null ? parseCrmDouble(json['monto_anterior']) : null,
      montoNuevo: json['monto_nuevo'] != null ? parseCrmDouble(json['monto_nuevo']) : null,
      montoImpacto: parseCrmDouble(json['monto_impacto']),
      fechaEvento: json['fecha_evento'] ?? '',
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      if (id != 0) 'id': id,
      'negocio_id': negocioId,
      'cliente_id': clienteId,
      'venta_id': ventaId,
      'cuota_id': cuotaId,
      'pago_id': pagoId,
      'tipo_evento': tipoEvento,
      'titulo': titulo,
      'descripcion': descripcion,
      'monto_anterior': montoAnterior,
      'monto_nuevo': montoNuevo,
      'monto_impacto': montoImpacto,
      'fecha_evento': fechaEvento,
      'metadata': metadata,
    };
  }
}

// ==========================================
// 🔥 V27: MODELOS DE FIDELIZACIÓN Y REPUTACIÓN
// ==========================================
