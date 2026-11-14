class NotificationPreferences {
  final int negocioId;
  final bool notifCuotasVencidas;
  final bool notifCuotasPreventivas;
  final bool notifRecargosMora;
  final bool notifConfirmacionPagos;
  final bool notifStockAgotado;
  final bool notifStockBajo;
  final bool notifStockCompartido;
  final bool notifCotizacionesVencidas;
  final bool notifMetasFidelizacion;
  final int diasAnticipacionCuotas; // 0 = mismo día, 1 = 1 día antes, 2 = 2 días, 3 = 3 días
  final int diasGraciaStockBajo; // 0 = solo tras 1ra venta, 3 = 3 días, 7 = 7 días
  final bool antiSpamStockSilencioso; // true = actualiza in-place sin revivir alertas resueltas/archivadas
  final String prioridadMinima; // 'todas', 'preventivas_criticas', 'solo_criticas'
  final bool activarSmartGrouping;
  final bool mostrarPulseDashboard;
  final String comportamientoSwipe; // 'tab_navigation', 'card_actions'
  final DateTime updatedAt;

  const NotificationPreferences({
    required this.negocioId,
    this.notifCuotasVencidas = true,
    this.notifCuotasPreventivas = true,
    this.notifRecargosMora = true,
    this.notifConfirmacionPagos = true,
    this.notifStockAgotado = true,
    this.notifStockBajo = true,
    this.notifStockCompartido = true,
    this.notifCotizacionesVencidas = true,
    this.notifMetasFidelizacion = true,
    this.diasAnticipacionCuotas = 1,
    this.diasGraciaStockBajo = 3,
    this.antiSpamStockSilencioso = true,
    this.prioridadMinima = 'todas',
    this.activarSmartGrouping = true,
    this.mostrarPulseDashboard = true,
    this.comportamientoSwipe = 'tab_navigation',
    required this.updatedAt,
  });

  factory NotificationPreferences.defaultFor(int negocioId) {
    return NotificationPreferences(
      negocioId: negocioId,
      updatedAt: DateTime.now(),
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      negocioId: (json['negocio_id'] as num?)?.toInt() ?? 0,
      notifCuotasVencidas: json['notif_cuotas_vencidas'] == 1 || json['notif_cuotas_vencidas'] == true,
      notifCuotasPreventivas: json['notif_cuotas_preventivas'] == 1 || json['notif_cuotas_preventivas'] == true,
      notifRecargosMora: json['notif_recargos_mora'] == 1 || json['notif_recargos_mora'] == true,
      notifConfirmacionPagos: json['notif_confirmacion_pagos'] == 1 || json['notif_confirmacion_pagos'] == true,
      notifStockAgotado: json['notif_stock_agotado'] == 1 || json['notif_stock_agotado'] == true,
      notifStockBajo: json['notif_stock_bajo'] == 1 || json['notif_stock_bajo'] == true,
      notifStockCompartido: json['notif_stock_compartido'] == 1 || json['notif_stock_compartido'] == true,
      notifCotizacionesVencidas: json['notif_cotizaciones_vencidas'] == 1 || json['notif_cotizaciones_vencidas'] == true,
      notifMetasFidelizacion: json['notif_metas_fidelizacion'] == 1 || json['notif_metas_fidelizacion'] == true,
      diasAnticipacionCuotas: (json['dias_anticipacion_cuotas'] as num?)?.toInt() ?? 1,
      diasGraciaStockBajo: (json['dias_gracia_stock_bajo'] as num?)?.toInt() ?? 3,
      antiSpamStockSilencioso: json['anti_spam_stock_silencioso'] != 0 && json['anti_spam_stock_silencioso'] != false,
      prioridadMinima: json['prioridad_minima'] as String? ?? 'todas',
      activarSmartGrouping: json['activar_smart_grouping'] != 0 && json['activar_smart_grouping'] != false,
      mostrarPulseDashboard: json['mostrar_pulse_dashboard'] != 0 && json['mostrar_pulse_dashboard'] != false,
      comportamientoSwipe: json['comportamiento_swipe'] as String? ?? 'tab_navigation',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'negocio_id': negocioId,
      'notif_cuotas_vencidas': notifCuotasVencidas ? 1 : 0,
      'notif_cuotas_preventivas': notifCuotasPreventivas ? 1 : 0,
      'notif_recargos_mora': notifRecargosMora ? 1 : 0,
      'notif_confirmacion_pagos': notifConfirmacionPagos ? 1 : 0,
      'notif_stock_agotado': notifStockAgotado ? 1 : 0,
      'notif_stock_bajo': notifStockBajo ? 1 : 0,
      'notif_stock_compartido': notifStockCompartido ? 1 : 0,
      'notif_cotizaciones_vencidas': notifCotizacionesVencidas ? 1 : 0,
      'notif_metas_fidelizacion': notifMetasFidelizacion ? 1 : 0,
      'dias_anticipacion_cuotas': diasAnticipacionCuotas,
      'dias_gracia_stock_bajo': diasGraciaStockBajo,
      'anti_spam_stock_silencioso': antiSpamStockSilencioso ? 1 : 0,
      'prioridad_minima': prioridadMinima,
      'activar_smart_grouping': activarSmartGrouping ? 1 : 0,
      'mostrar_pulse_dashboard': mostrarPulseDashboard ? 1 : 0,
      'comportamiento_swipe': comportamientoSwipe,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  NotificationPreferences copyWith({
    int? negocioId,
    bool? notifCuotasVencidas,
    bool? notifCuotasPreventivas,
    bool? notifRecargosMora,
    bool? notifConfirmacionPagos,
    bool? notifStockAgotado,
    bool? notifStockBajo,
    bool? notifStockCompartido,
    bool? notifCotizacionesVencidas,
    bool? notifMetasFidelizacion,
    int? diasAnticipacionCuotas,
    int? diasGraciaStockBajo,
    bool? antiSpamStockSilencioso,
    String? prioridadMinima,
    bool? activarSmartGrouping,
    bool? mostrarPulseDashboard,
    String? comportamientoSwipe,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      negocioId: negocioId ?? this.negocioId,
      notifCuotasVencidas: notifCuotasVencidas ?? this.notifCuotasVencidas,
      notifCuotasPreventivas: notifCuotasPreventivas ?? this.notifCuotasPreventivas,
      notifRecargosMora: notifRecargosMora ?? this.notifRecargosMora,
      notifConfirmacionPagos: notifConfirmacionPagos ?? this.notifConfirmacionPagos,
      notifStockAgotado: notifStockAgotado ?? this.notifStockAgotado,
      notifStockBajo: notifStockBajo ?? this.notifStockBajo,
      notifStockCompartido: notifStockCompartido ?? this.notifStockCompartido,
      notifCotizacionesVencidas: notifCotizacionesVencidas ?? this.notifCotizacionesVencidas,
      notifMetasFidelizacion: notifMetasFidelizacion ?? this.notifMetasFidelizacion,
      diasAnticipacionCuotas: diasAnticipacionCuotas ?? this.diasAnticipacionCuotas,
      diasGraciaStockBajo: diasGraciaStockBajo ?? this.diasGraciaStockBajo,
      antiSpamStockSilencioso: antiSpamStockSilencioso ?? this.antiSpamStockSilencioso,
      prioridadMinima: prioridadMinima ?? this.prioridadMinima,
      activarSmartGrouping: activarSmartGrouping ?? this.activarSmartGrouping,
      mostrarPulseDashboard: mostrarPulseDashboard ?? this.mostrarPulseDashboard,
      comportamientoSwipe: comportamientoSwipe ?? this.comportamientoSwipe,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

