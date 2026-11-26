import 'package:app_movil/features/smart_quotation/models/client_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_parse_helpers.dart';

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
      valorBeneficio: parseCrmDouble(json['valor_beneficio']),
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
      valorBeneficio: parseCrmDouble(json['valor_beneficio']),
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

class LoyaltyRulesModel {
  final int negocioId;
  final bool puntosPorCompraActivo;
  final int puntosPorUnidadMoneda;
  final double montoBaseCompra;
  final double compraMinimaParaPuntos;
  final bool bonoCotizacionActivo;
  final int puntosBonoCotizacion;
  final bool puntosAbonoInicialActivo;
  final bool bonoPagoPuntualActivo;
  final int puntosPagoPuntual;
  final bool bonoRachaActivo;
  final int cadaCuantasCuotasRacha;
  final int puntosBonoRacha;
  final bool bonoLiquidacionSinMoraActivo;
  final int puntosLiquidacionSinMora;
  final String updatedAt;

  LoyaltyRulesModel({
    required this.negocioId,
    this.puntosPorCompraActivo = true,
    this.puntosPorUnidadMoneda = 1,
    this.montoBaseCompra = 1.0,
    this.compraMinimaParaPuntos = 0.0,
    this.bonoCotizacionActivo = true,
    this.puntosBonoCotizacion = 10,
    this.puntosAbonoInicialActivo = true,
    this.bonoPagoPuntualActivo = true,
    this.puntosPagoPuntual = 25,
    this.bonoRachaActivo = true,
    this.cadaCuantasCuotasRacha = 3,
    this.puntosBonoRacha = 30,
    this.bonoLiquidacionSinMoraActivo = true,
    this.puntosLiquidacionSinMora = 50,
    required this.updatedAt,
  });

  factory LoyaltyRulesModel.defaultRules(int negocioId) {
    return LoyaltyRulesModel(
      negocioId: negocioId,
      puntosPorCompraActivo: true,
      puntosPorUnidadMoneda: 1,
      montoBaseCompra: 1.0,
      compraMinimaParaPuntos: 0.0,
      bonoCotizacionActivo: true,
      puntosBonoCotizacion: 10,
      puntosAbonoInicialActivo: true,
      bonoPagoPuntualActivo: true,
      puntosPagoPuntual: 25,
      bonoRachaActivo: true,
      cadaCuantasCuotasRacha: 3,
      puntosBonoRacha: 30,
      bonoLiquidacionSinMoraActivo: true,
      puntosLiquidacionSinMora: 50,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  factory LoyaltyRulesModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyRulesModel(
      negocioId: json['negocio_id'] ?? 0,
      puntosPorCompraActivo: json['puntos_por_compra_activo'] == 1 || json['puntos_por_compra_activo'] == true,
      puntosPorUnidadMoneda: (json['puntos_por_unidad_moneda'] as num?)?.toInt() ?? 1,
      montoBaseCompra: parseCrmDouble(json['monto_base_compra']) > 0 ? parseCrmDouble(json['monto_base_compra']) : 1.0,
      compraMinimaParaPuntos: parseCrmDouble(json['compra_minima_para_puntos']),
      bonoCotizacionActivo: json['bono_cotizacion_activo'] == 1 || json['bono_cotizacion_activo'] == true,
      puntosBonoCotizacion: (json['puntos_bono_cotizacion'] as num?)?.toInt() ?? 10,
      puntosAbonoInicialActivo: json['puntos_abono_inicial_activo'] == 1 || json['puntos_abono_inicial_activo'] == true,
      bonoPagoPuntualActivo: json['bono_pago_puntual_activo'] == 1 || json['bono_pago_puntual_activo'] == true,
      puntosPagoPuntual: (json['puntos_pago_puntual'] as num?)?.toInt() ?? 25,
      bonoRachaActivo: json['bono_racha_activo'] == 1 || json['bono_racha_activo'] == true,
      cadaCuantasCuotasRacha: (json['cada_cuantas_cuotas_racha'] as num?)?.toInt() ?? 3,
      puntosBonoRacha: (json['puntos_bono_racha'] as num?)?.toInt() ?? 30,
      bonoLiquidacionSinMoraActivo: json['bono_liquidacion_sin_mora_activo'] == 1 || json['bono_liquidacion_sin_mora_activo'] == true,
      puntosLiquidacionSinMora: (json['puntos_liquidacion_sin_mora'] as num?)?.toInt() ?? 50,
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'negocio_id': negocioId,
      'puntos_por_compra_activo': puntosPorCompraActivo ? 1 : 0,
      'puntos_por_unidad_moneda': puntosPorUnidadMoneda,
      'monto_base_compra': montoBaseCompra,
      'compra_minima_para_puntos': compraMinimaParaPuntos,
      'bono_cotizacion_activo': bonoCotizacionActivo ? 1 : 0,
      'puntos_bono_cotizacion': puntosBonoCotizacion,
      'puntos_abono_inicial_activo': puntosAbonoInicialActivo ? 1 : 0,
      'bono_pago_puntual_activo': bonoPagoPuntualActivo ? 1 : 0,
      'puntos_pago_puntual': puntosPagoPuntual,
      'bono_racha_activo': bonoRachaActivo ? 1 : 0,
      'cada_cuantas_cuotas_racha': cadaCuantasCuotasRacha,
      'puntos_bono_racha': puntosBonoRacha,
      'bono_liquidacion_sin_mora_activo': bonoLiquidacionSinMoraActivo ? 1 : 0,
      'puntos_liquidacion_sin_mora': puntosLiquidacionSinMora,
      'updated_at': updatedAt.isEmpty ? DateTime.now().toIso8601String() : updatedAt,
    };
  }

  LoyaltyRulesModel copyWith({
    int? negocioId,
    bool? puntosPorCompraActivo,
    int? puntosPorUnidadMoneda,
    double? montoBaseCompra,
    double? compraMinimaParaPuntos,
    bool? bonoCotizacionActivo,
    int? puntosBonoCotizacion,
    bool? puntosAbonoInicialActivo,
    bool? bonoPagoPuntualActivo,
    int? puntosPagoPuntual,
    bool? bonoRachaActivo,
    int? cadaCuantasCuotasRacha,
    int? puntosBonoRacha,
    bool? bonoLiquidacionSinMoraActivo,
    int? puntosLiquidacionSinMora,
    String? updatedAt,
  }) {
    return LoyaltyRulesModel(
      negocioId: negocioId ?? this.negocioId,
      puntosPorCompraActivo: puntosPorCompraActivo ?? this.puntosPorCompraActivo,
      puntosPorUnidadMoneda: puntosPorUnidadMoneda ?? this.puntosPorUnidadMoneda,
      montoBaseCompra: montoBaseCompra ?? this.montoBaseCompra,
      compraMinimaParaPuntos: compraMinimaParaPuntos ?? this.compraMinimaParaPuntos,
      bonoCotizacionActivo: bonoCotizacionActivo ?? this.bonoCotizacionActivo,
      puntosBonoCotizacion: puntosBonoCotizacion ?? this.puntosBonoCotizacion,
      puntosAbonoInicialActivo: puntosAbonoInicialActivo ?? this.puntosAbonoInicialActivo,
      bonoPagoPuntualActivo: bonoPagoPuntualActivo ?? this.bonoPagoPuntualActivo,
      puntosPagoPuntual: puntosPagoPuntual ?? this.puntosPagoPuntual,
      bonoRachaActivo: bonoRachaActivo ?? this.bonoRachaActivo,
      cadaCuantasCuotasRacha: cadaCuantasCuotasRacha ?? this.cadaCuantasCuotasRacha,
      puntosBonoRacha: puntosBonoRacha ?? this.puntosBonoRacha,
      bonoLiquidacionSinMoraActivo: bonoLiquidacionSinMoraActivo ?? this.bonoLiquidacionSinMoraActivo,
      puntosLiquidacionSinMora: puntosLiquidacionSinMora ?? this.puntosLiquidacionSinMora,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ClientClaimableRewardsSummary {
  final ClientModel client;
  final List<RewardGoalModel> claimableGoals;
  final List<RewardGoalModel> upcomingGoals;
  final List<ClientRewardModel> approvedRewards;
  final Map<String, dynamic>? nextGoalData;

  ClientClaimableRewardsSummary({
    required this.client,
    required this.claimableGoals,
    required this.upcomingGoals,
    this.approvedRewards = const [],
    this.nextGoalData,
  });

  bool get hasClaimableRewards => claimableGoals.isNotEmpty;
  int get claimableCount => claimableGoals.length;
  RewardGoalModel? get nextGoal => nextGoalData?['goal'] as RewardGoalModel?;
  int get puntosFaltantesParaSiguiente =>
      ((nextGoalData?['puntos_faltantes'] ?? nextGoalData?['missing']) as num?)?.toInt() ?? 0;
  double get progresoSiguienteMeta =>
      ((nextGoalData?['progreso'] ?? nextGoalData?['progress']) as num?)?.toDouble() ?? 0.0;
}
