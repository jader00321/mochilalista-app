import 'dart:convert';
import 'package:app_movil/features/smart_quotation/models/crm_parse_helpers.dart';
import 'package:app_movil/features/smart_quotation/models/payment_and_ledger_models.dart';
import 'package:app_movil/features/smart_quotation/models/reputation_tier_model.dart';
import 'package:app_movil/features/smart_quotation/models/sale_and_installment_models.dart';

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

  ReputationTier get tier => ReputationTier.fromScore(scoreReputacion);

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
      totalDebt: parseCrmDouble(json['deuda_total']),
      saldoAFavor: parseCrmDouble(json['saldo_a_favor']), 
      pendingDeliveryCount: json['entregas_pendientes'] ?? json['entregas_pendientes_count'] ?? 0, 
      registeredDate: json['fecha_registro'] ?? "",
      nivelConfianza: json['nivel_confianza'] ?? "bueno",
      etiquetas: parsedEtiquetas,
      puntosActuales: (json['puntos_actuales'] as num?)?.toInt() ?? 0,
      puntosHistoricos: (json['puntos_historicos'] as num?)?.toInt() ?? 0,
      rachaPagosPuntuales: (json['racha_pagos_puntuales'] as num?)?.toInt() ?? 0,
      scoreReputacion: (json['score_reputacion'] as num?)?.toInt() ?? 500,
      nivelReputacion: json['score_reputacion'] != null 
          ? ReputationTier.fromScore((json['score_reputacion'] as num).toInt()).key 
          : (json['nivel_reputacion'] ?? "PLATA"),
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
