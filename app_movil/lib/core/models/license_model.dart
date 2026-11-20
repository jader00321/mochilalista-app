import 'dart:math' as math;
import 'package:flutter/material.dart';

enum PlanType {
  trial,
  mensual,
  trimestral,
  semestral,
  anual,
  perpetuoLiberado;

  String get dbValue {
    switch (this) {
      case PlanType.trial:
        return 'TRIAL';
      case PlanType.mensual:
        return 'MENSUAL';
      case PlanType.trimestral:
        return 'TRIMESTRAL';
      case PlanType.semestral:
        return 'SEMESTRAL';
      case PlanType.anual:
        return 'ANUAL';
      case PlanType.perpetuoLiberado:
        return 'PERPETUO_LIBERADO';
    }
  }

  static PlanType fromString(String val) {
    switch (val.toUpperCase().trim()) {
      case 'MENSUAL':
        return PlanType.mensual;
      case 'TRIMESTRAL':
        return PlanType.trimestral;
      case 'SEMESTRAL':
        return PlanType.semestral;
      case 'ANUAL':
        return PlanType.anual;
      case 'PERPETUO_LIBERADO':
      case 'PERPETUO':
      case 'PERPETUA':
        return PlanType.perpetuoLiberado;
      case 'TRIAL':
      default:
        return PlanType.trial;
    }
  }

  int get baseMonthlyAiScans {
    switch (this) {
      case PlanType.trial:
        return 50;
      case PlanType.mensual:
        return 50;
      case PlanType.trimestral:
        return 60;
      case PlanType.semestral:
        return 75;
      case PlanType.anual:
        return 100;
      case PlanType.perpetuoLiberado:
        return 50;
    }
  }

  /// Duración base en días naturales del periodo contratado
  int get baseDurationDays {
    switch (this) {
      case PlanType.trial:
        return 30;
      case PlanType.mensual:
        return 30;
      case PlanType.trimestral:
        return 90;
      case PlanType.semestral:
        return 180;
      case PlanType.anual:
        return 365;
      case PlanType.perpetuoLiberado:
        return 365;
    }
  }
}

enum LicenseStatus {
  active,              // ACTIVA
  expiringSoon,        // POR_VENCER
  softLock,            // BLOQUEO_SUAVE
  strictLock,          // BLOQUEO_ESTRICTO
  pendingMigration,    // PENDIENTE_MIGRACION
  clockDesynced;       // RELOJ_DESAJUSTADO

  String get dbValue {
    switch (this) {
      case LicenseStatus.active:
        return 'ACTIVA';
      case LicenseStatus.expiringSoon:
        return 'POR_VENCER';
      case LicenseStatus.softLock:
        return 'BLOQUEO_SUAVE';
      case LicenseStatus.strictLock:
        return 'BLOQUEO_ESTRICTO';
      case LicenseStatus.pendingMigration:
        return 'PENDIENTE_MIGRACION';
      case LicenseStatus.clockDesynced:
        return 'RELOJ_DESAJUSTADO';
    }
  }

  static LicenseStatus fromString(String val) {
    switch (val.toUpperCase().trim()) {
      case 'POR_VENCER':
        return LicenseStatus.expiringSoon;
      case 'BLOQUEO_SUAVE':
        return LicenseStatus.softLock;
      case 'BLOQUEO_ESTRICTO':
        return LicenseStatus.strictLock;
      case 'PENDIENTE_MIGRACION':
        return LicenseStatus.pendingMigration;
      case 'RELOJ_DESAJUSTADO':
        return LicenseStatus.clockDesynced;
      case 'ACTIVA':
      default:
        return LicenseStatus.active;
    }
  }
}

class LicenseModel {
  final int? id;
  final String deviceFingerprint;
  final String tipoPlan;
  final String estadoActual;
  final DateTime fechaInicio;
  final DateTime fechaExpiracion;
  final int ultimoNonce;
  final String? ultimoCodigoUsado;
  final DateTime? updatesUntil;
  final int maxMajorVersion;
  final String? businessOwnerTag;
  final DateTime fechaUltimoCheck;
  final int aiScansUsedMonth;
  final String aiScansMonthKey;
  final int aiExtraCredits;
  final String? customGeminiApiKey;
  final String? eulaAcceptedVersion;
  final DateTime? eulaAcceptedTimestamp;
  final String? migratedFromDeviceId;
  final String? lastExecutedAppVersion;
  final int aiAccumulatedScans;
  final String aiSelectedMode;

  const LicenseModel({
    this.id,
    required this.deviceFingerprint,
    required this.tipoPlan,
    required this.estadoActual,
    required this.fechaInicio,
    required this.fechaExpiracion,
    this.ultimoNonce = 0,
    this.ultimoCodigoUsado,
    this.updatesUntil,
    this.maxMajorVersion = 9,
    this.businessOwnerTag,
    required this.fechaUltimoCheck,
    this.aiScansUsedMonth = 0,
    this.aiScansMonthKey = '',
    this.aiExtraCredits = 0,
    this.customGeminiApiKey,
    this.eulaAcceptedVersion,
    this.eulaAcceptedTimestamp,
    this.migratedFromDeviceId,
    this.lastExecutedAppVersion,
    this.aiAccumulatedScans = 50,
    this.aiSelectedMode = 'INCLUDED',
  });

  PlanType get plan => PlanType.fromString(tipoPlan);
  LicenseStatus get status => LicenseStatus.fromString(estadoActual);

  bool get isActive => status == LicenseStatus.active || status == LicenseStatus.expiringSoon;
  bool get isPerpetual => plan == PlanType.perpetuoLiberado;
  bool get isTrial => plan == PlanType.trial;
  bool get isPendingMigration => status == LicenseStatus.pendingMigration;
  bool get isClockDesynced => status == LicenseStatus.clockDesynced;

  /// Retorna si el usuario tiene activo el modo Clave Propia (BYOK)
  bool get isUsingByokMode => aiSelectedMode.toUpperCase().trim() == 'BYOK';

  int get totalMonthlyAiQuota => plan.baseMonthlyAiScans + aiExtraCredits;
  int get remainingAiScans => aiAccumulatedScans.clamp(0, 999999);

  /// Tabla oficial de acreditación acumulativa de escaneos IA por plan o recarga
  static int getCumulativeScansForPlan(String planName) {
    switch (planName.toUpperCase().trim()) {
      case 'TRIAL':
        return 50;
      case 'MENSUAL':
        return 50;
      case 'TRIMESTRAL':
        return 180;
      case 'SEMESTRAL':
        return 450;
      case 'ANUAL':
        return 1200;
      case 'PERPETUO_LIBERADO':
      case 'PERPETUO':
      case 'PERPETUA':
        return 200;
      case 'PASE_ACTUALIZACION_ANUAL':
      case 'PASE_ANUAL_UPDATES':
      case 'PASE_UPDATES_12M':
        return 100;
      case 'RECARGA_IA_150':
        return 150;
      default:
        return 0;
    }
  }

  int get daysRemaining {
    final now = DateTime.now();
    if (fechaExpiracion.isBefore(now)) return 0;
    return fechaExpiracion.difference(now).inDays;
  }

  /// Denominador dinámico que preserva la suma acumulativa de días
  int get totalPeriodDays => math.max(plan.baseDurationDays, daysRemaining);

  /// Progreso proporcional de la vigencia (0.0 a 1.0)
  double get progressRatio =>
      totalPeriodDays > 0 ? (daysRemaining / totalPeriodDays).clamp(0.0, 1.0) : 1.0;

  /// Indica si la vigencia actual incluye días acumulados de periodos anteriores
  bool get hasAccumulatedBonusDays => !isPerpetual && daysRemaining > plan.baseDurationDays;

  /// Etiqueta dinámica exacta del plan para el badge de cabecera
  String get dynamicPlanBadgeLabel {
    if (status == LicenseStatus.softLock || status == LicenseStatus.strictLock) {
      return "Periodo de Gracia / Modo Lectura";
    }
    if (status == LicenseStatus.pendingMigration) {
      return "Migración Pendiente";
    }
    if (status == LicenseStatus.clockDesynced) {
      return "Reloj Desajustado";
    }
    switch (plan) {
      case PlanType.mensual:
        return "Plan Mensual Activo";
      case PlanType.trimestral:
        return "Plan Trimestral Activo";
      case PlanType.semestral:
        return "Plan Semestral Activo";
      case PlanType.anual:
        return "Plan Anual Activo";
      case PlanType.perpetuoLiberado:
        return "Licencia Perpetua Liberada";
      case PlanType.trial:
        return "Prueba Gratuita (Trial)";
    }
  }

  /// Color temático representativo para el badge dinámico
  Color get dynamicPlanBadgeColor {
    if (status == LicenseStatus.softLock || status == LicenseStatus.strictLock) {
      return const Color(0xFFE65100);
    }
    if (status == LicenseStatus.pendingMigration || status == LicenseStatus.clockDesynced) {
      return const Color(0xFFC62828);
    }
    switch (plan) {
      case PlanType.mensual:
        return const Color(0xFF1565C0);
      case PlanType.trimestral:
        return const Color(0xFF283593);
      case PlanType.semestral:
        return const Color(0xFF00838F);
      case PlanType.anual:
        return const Color(0xFF2E7D32);
      case PlanType.perpetuoLiberado:
        return const Color(0xFF6A1B9A);
      case PlanType.trial:
        return const Color(0xFF00695C);
    }
  }

  /// Icono representativo para el badge dinámico
  IconData get dynamicPlanBadgeIcon {
    if (status == LicenseStatus.softLock) return Icons.lock_clock_rounded;
    if (status == LicenseStatus.strictLock) return Icons.lock_rounded;
    if (status == LicenseStatus.pendingMigration) return Icons.phonelink_erase_rounded;
    if (status == LicenseStatus.clockDesynced) return Icons.warning_rounded;
    if (isPerpetual) return Icons.stars_rounded;
    return Icons.verified_rounded;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'device_fingerprint': deviceFingerprint,
      'tipo_plan': tipoPlan,
      'estado_actual': estadoActual,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_expiracion': fechaExpiracion.toIso8601String(),
      'ultimo_nonce': ultimoNonce,
      'ultimo_codigo_usado': ultimoCodigoUsado,
      'updates_until': updatesUntil?.toIso8601String(),
      'max_major_version': maxMajorVersion,
      'business_owner_tag': businessOwnerTag,
      'fecha_ultimo_check': fechaUltimoCheck.toIso8601String(),
      'ai_scans_used_month': aiScansUsedMonth,
      'ai_scans_month_key': aiScansMonthKey,
      'ai_extra_credits': aiExtraCredits,
      'custom_gemini_api_key': customGeminiApiKey,
      'eula_accepted_version': eulaAcceptedVersion,
      'eula_accepted_timestamp': eulaAcceptedTimestamp?.toIso8601String(),
      'migrated_from_device_id': migratedFromDeviceId,
      'last_executed_app_version': lastExecutedAppVersion,
      'ai_accumulated_scans': aiAccumulatedScans,
      'ai_selected_mode': aiSelectedMode,
    };
  }

  factory LicenseModel.fromMap(Map<String, dynamic> map) {
    return LicenseModel(
      id: map['id'] as int?,
      deviceFingerprint: map['device_fingerprint'] as String? ?? '',
      tipoPlan: map['tipo_plan'] as String? ?? 'TRIAL',
      estadoActual: map['estado_actual'] as String? ?? 'ACTIVA',
      fechaInicio: DateTime.tryParse(map['fecha_inicio'] as String? ?? '') ?? DateTime.now(),
      fechaExpiracion: DateTime.tryParse(map['fecha_expiracion'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      ultimoNonce: (map['ultimo_nonce'] as num?)?.toInt() ?? 0,
      ultimoCodigoUsado: map['ultimo_codigo_usado'] as String?,
      updatesUntil: map['updates_until'] != null
          ? DateTime.tryParse(map['updates_until'] as String)
          : null,
      maxMajorVersion: (map['max_major_version'] as num?)?.toInt() ?? 9,
      businessOwnerTag: map['business_owner_tag'] as String?,
      fechaUltimoCheck: DateTime.tryParse(map['fecha_ultimo_check'] as String? ?? '') ??
          DateTime.now(),
      aiScansUsedMonth: (map['ai_scans_used_month'] as num?)?.toInt() ?? 0,
      aiScansMonthKey: map['ai_scans_month_key'] as String? ?? '',
      aiExtraCredits: (map['ai_extra_credits'] as num?)?.toInt() ?? 0,
      customGeminiApiKey: map['custom_gemini_api_key'] as String?,
      eulaAcceptedVersion: map['eula_accepted_version'] as String?,
      eulaAcceptedTimestamp: map['eula_accepted_timestamp'] != null
          ? DateTime.tryParse(map['eula_accepted_timestamp'] as String)
          : null,
      migratedFromDeviceId: map['migrated_from_device_id'] as String?,
      lastExecutedAppVersion: map['last_executed_app_version'] as String?,
      aiAccumulatedScans: (map['ai_accumulated_scans'] as num?)?.toInt() ?? 50,
      aiSelectedMode: map['ai_selected_mode'] as String? ?? 'INCLUDED',
    );
  }

  LicenseModel copyWith({
    int? id,
    String? deviceFingerprint,
    String? tipoPlan,
    String? estadoActual,
    DateTime? fechaInicio,
    DateTime? fechaExpiracion,
    int? ultimoNonce,
    String? ultimoCodigoUsado,
    bool clearUltimoCodigoUsado = false,
    DateTime? updatesUntil,
    int? maxMajorVersion,
    String? businessOwnerTag,
    DateTime? fechaUltimoCheck,
    int? aiScansUsedMonth,
    String? aiScansMonthKey,
    int? aiExtraCredits,
    String? customGeminiApiKey,
    String? eulaAcceptedVersion,
    DateTime? eulaAcceptedTimestamp,
    String? migratedFromDeviceId,
    String? lastExecutedAppVersion,
    int? aiAccumulatedScans,
    String? aiSelectedMode,
  }) {
    return LicenseModel(
      id: id ?? this.id,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      tipoPlan: tipoPlan ?? this.tipoPlan,
      estadoActual: estadoActual ?? this.estadoActual,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaExpiracion: fechaExpiracion ?? this.fechaExpiracion,
      ultimoNonce: ultimoNonce ?? this.ultimoNonce,
      ultimoCodigoUsado: clearUltimoCodigoUsado ? null : (ultimoCodigoUsado ?? this.ultimoCodigoUsado),
      updatesUntil: updatesUntil ?? this.updatesUntil,
      maxMajorVersion: maxMajorVersion ?? this.maxMajorVersion,
      businessOwnerTag: businessOwnerTag ?? this.businessOwnerTag,
      fechaUltimoCheck: fechaUltimoCheck ?? this.fechaUltimoCheck,
      aiScansUsedMonth: aiScansUsedMonth ?? this.aiScansUsedMonth,
      aiScansMonthKey: aiScansMonthKey ?? this.aiScansMonthKey,
      aiExtraCredits: aiExtraCredits ?? this.aiExtraCredits,
      customGeminiApiKey: customGeminiApiKey ?? this.customGeminiApiKey,
      eulaAcceptedVersion: eulaAcceptedVersion ?? this.eulaAcceptedVersion,
      eulaAcceptedTimestamp: eulaAcceptedTimestamp ?? this.eulaAcceptedTimestamp,
      migratedFromDeviceId: migratedFromDeviceId ?? this.migratedFromDeviceId,
      lastExecutedAppVersion: lastExecutedAppVersion ?? this.lastExecutedAppVersion,
      aiAccumulatedScans: aiAccumulatedScans ?? this.aiAccumulatedScans,
      aiSelectedMode: aiSelectedMode ?? this.aiSelectedMode,
    );
  }
}
