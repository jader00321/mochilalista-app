import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/utils/app_logger.dart';

/// Resultado de la verificación de coherencia temporal (Anti-Manipulación de Reloj)
class ClockCheckResult {
  final bool isConsistent;
  final DateTime currentPhoneTime;
  final DateTime lastRecordedActivityTime;
  final String message;

  const ClockCheckResult({
    required this.isConsistent,
    required this.currentPhoneTime,
    required this.lastRecordedActivityTime,
    required this.message,
  });
}

/// Repositorio y Motor de Gestión de Licencia, Cuotas IA y Antifraude de SQLite
class LicenseRepository {
  final LocalDatabase _localDb;
  final FlutterSecureStorage _secureStorage;

  static const String firstTrialStorageKey = 'ml_first_trial_timestamp';
  static const String deviceEulaVersionKey = 'ml_device_eula_accepted_version';
  static const String deviceEulaTimestampKey = 'ml_device_eula_accepted_timestamp';

  LicenseRepository({
    LocalDatabase? localDb,
    FlutterSecureStorage? secureStorage,
  })  : _localDb = localDb ?? LocalDatabase.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Obtiene o inicializa la licencia de la app.
  /// Si la tabla está vacía (instalación limpia), inicializa automáticamente el TRIAL de 30 días con 50 escaneos IA.
  /// Si existe anclaje previo de primer trial en almacenamiento seguro, calcula la expiración a partir de esa fecha.
  Future<LicenseModel> getOrCreateLicense({DateTime? overrideNow}) async {
    final db = await _localDb.database;
    final rows = await db.query('licencia_app', limit: 1);

    if (rows.isEmpty) {
      final now = overrideNow ?? DateTime.now();
      final currentFingerprint = await DeviceFingerprint.generate();
      final monthKey = _generateMonthKey(now);

      // 🛡️ Anclaje y consulta del primer trial en almacenamiento seguro
      DateTime trialStartDate = now;
      try {
        final storedFirstTrial = await _secureStorage.read(key: firstTrialStorageKey);
        if (storedFirstTrial != null) {
          final parsed = DateTime.tryParse(storedFirstTrial);
          if (parsed != null) {
            trialStartDate = parsed;
            AppLogger.i('LicenseRepository', 'Restaurando fecha de trial original anclada: $trialStartDate');
          }
        } else {
          await _secureStorage.write(key: firstTrialStorageKey, value: now.toIso8601String());
        }
      } catch (e) {
        AppLogger.w('LicenseRepository', 'Error accediendo a first_trial_timestamp en almacenamiento seguro: $e');
      }

      final expiration = trialStartDate.add(const Duration(days: 30));

      // 🛡️ Limpieza proactiva de claves residuales de Keystore/Knox y Google Drive en instalaciones limpias
      // Garantiza que tras desinstalar y reinstalar, el EULA sea obligatorio y Google Drive arranque 100% limpio
      try {
        await _secureStorage.delete(key: deviceEulaVersionKey);
        await _secureStorage.delete(key: deviceEulaTimestampKey);
        await _secureStorage.delete(key: 'mochilalista_drive_user_cache_v1');
        await _secureStorage.delete(key: 'mochilalista_drive_backup_config_v1');
        await _secureStorage.delete(key: 'ml_gdrive_user_cache');
        await _secureStorage.delete(key: 'ml_gdrive_config');
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('mochilalista_drive_user_cache_v1');
        await prefs.remove('mochilalista_drive_backup_config_v1');
        await prefs.remove('ml_gdrive_user_cache');
        await prefs.remove('ml_gdrive_config');
      } catch (_) {}

      final initialMap = {
        'device_fingerprint': currentFingerprint,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': trialStartDate.toIso8601String(),
        'fecha_expiracion': expiration.toIso8601String(),
        'ultimo_nonce': 0,
        'ultimo_codigo_usado': null,
        'updates_until': null,
        'max_major_version': 9,
        'business_owner_tag': null,
        'fecha_ultimo_check': now.toIso8601String(),
        'ai_scans_used_month': 0,
        'ai_scans_month_key': monthKey,
        'ai_extra_credits': 0,
        'custom_gemini_api_key': null,
        'eula_accepted_version': null,
        'eula_accepted_timestamp': null,
        'migrated_from_device_id': null,
        'ai_accumulated_scans': 50,
        'ai_selected_mode': 'INCLUDED',
      };

      final id = await db.insert('licencia_app', initialMap);
      AppLogger.i('LicenseRepository', 'Inicializado TRIAL de 30 días para dispositivo $currentFingerprint');
      final newModel = LicenseModel.fromMap({...initialMap, 'id': id});
      final evaluated = await evaluateLicenseState(newModel, overrideNow: overrideNow);
      ApiConstants.setAiSelectedMode(evaluated.aiSelectedMode);
      return evaluated;
    }

    final currentModel = LicenseModel.fromMap(rows.first);
    final evaluated = await evaluateLicenseState(currentModel, overrideNow: overrideNow);
    ApiConstants.setAiSelectedMode(evaluated.aiSelectedMode);
    return evaluated;
  }

  /// Evalúa el estado integral de la licencia comprobando:
  /// 1. Doble candado anti-clonación por hardware
  /// 2. Consistencia temporal de reloj
  /// 3. Vigencia y períodos de gracia (ACTIVA -> POR_VENCER -> BLOQUEO_SUAVE -> BLOQUEO_ESTRICTO)
  Future<LicenseModel> evaluateLicenseState(
    LicenseModel model, {
    DateTime? overrideNow,
  }) async {
    final db = await _localDb.database;
    final now = overrideNow ?? DateTime.now();
    final currentFingerprint = await DeviceFingerprint.generate();

    // 1. Doble Candado Anti-Clonación: Si el archivo SQLite fue copiado a otro dispositivo
    if (model.deviceFingerprint != currentFingerprint) {
      // Verificar si es una migración transparente del mismo equipo (Legacy Build.ID -> Estable ANDROID_ID)
      final legacyFingerprint = await DeviceFingerprint.generateLegacy();
      final isLegacySameDevice = (model.deviceFingerprint == legacyFingerprint);

      if (isLegacySameDevice) {
        AppLogger.i(
          'LicenseRepository',
          'Migración transparente de hardware detectada (Legacy: ${model.deviceFingerprint} -> Estable: $currentFingerprint). Actualizando sin bloquear.',
        );
        await db.update(
          'licencia_app',
          {
            'device_fingerprint': currentFingerprint,
          },
          where: 'id = ?',
          whereArgs: [model.id ?? 1],
        );
        model = model.copyWith(deviceFingerprint: currentFingerprint);
      } else {
        AppLogger.w(
          'LicenseRepository',
          'Detectada discrepancia de hardware: Licencia=${model.deviceFingerprint} vs Dispositivo=$currentFingerprint. Bloqueando por clonación.',
        );
        final updated = model.copyWith(
          estadoActual: 'PENDIENTE_MIGRACION',
          migratedFromDeviceId: model.deviceFingerprint,
          deviceFingerprint: currentFingerprint,
          clearUltimoCodigoUsado: true,
        );
        await db.update(
          'licencia_app',
          {
            'estado_actual': 'PENDIENTE_MIGRACION',
            'migrated_from_device_id': model.deviceFingerprint,
            'device_fingerprint': currentFingerprint,
            'ultimo_codigo_usado': null,
          },
          where: 'id = ?',
          whereArgs: [model.id ?? 1],
        );
        return updated;
      }
    }

    // 2. Comprobación Anti-Manipulación de Reloj (Batería al 0% o adelanto malicioso)
    final clockCheck = await checkClockConsistency(overrideNow: now);
    if (!clockCheck.isConsistent) {
      AppLogger.w('LicenseRepository', clockCheck.message);
      final updated = model.copyWith(estadoActual: 'RELOJ_DESAJUSTADO');
      await db.update(
        'licencia_app',
        {'estado_actual': 'RELOJ_DESAJUSTADO'},
        where: 'id = ?',
        whereArgs: [model.id ?? 1],
      );
      return updated;
    }

    // 4. Si estaba desajustado o pendiente de migración y ya no lo está
    if (model.estadoActual == 'RELOJ_DESAJUSTADO') {
      // El reloj volvió a ser consistente
      AppLogger.i('LicenseRepository', 'Reloj resincronizado. Restaurando evaluación normal.');
    }

    String nuevoEstado = model.estadoActual;

    if (model.isPerpetual) {
      nuevoEstado = 'ACTIVA';
    } else {
      if (now.isBefore(model.fechaExpiracion)) {
        final remainingDays = model.fechaExpiracion.difference(now).inDays;
        if (remainingDays <= 5) {
          nuevoEstado = 'POR_VENCER';
        } else {
          nuevoEstado = 'ACTIVA';
        }
      } else {
        // Expirada
        final daysPast = now.difference(model.fechaExpiracion).inDays;
        if (daysPast <= 7) {
          nuevoEstado = 'BLOQUEO_SUAVE';
        } else {
          nuevoEstado = 'BLOQUEO_ESTRICTO';
        }
      }
    }

    final updated = model.copyWith(
      estadoActual: nuevoEstado,
      fechaUltimoCheck: now,
    );

    await db.update(
      'licencia_app',
      {
        'estado_actual': nuevoEstado,
        'fecha_ultimo_check': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [model.id ?? 1],
    );

    return updated;
  }

  /// Ejecuta la consulta cruzada sobre SQLite para comprobar que la hora actual
  /// no sea anterior a eventos comerciales previos (tolerancia de 2 horas)
  Future<ClockCheckResult> checkClockConsistency({DateTime? overrideNow}) async {
    final db = await _localDb.database;
    final now = overrideNow ?? DateTime.now();

    String? maxLicencia;
    try {
      final res = await db.rawQuery('SELECT MAX(fecha_ultimo_check) as max_ts FROM licencia_app');
      maxLicencia = res.first['max_ts'] as String?;
    } catch (_) {}

    String? maxVenta;
    try {
      final res = await db.rawQuery('SELECT MAX(COALESCE(fecha_venta, created_at)) as max_ts FROM ventas');
      maxVenta = res.first['max_ts'] as String?;
    } catch (_) {}

    String? maxStock;
    try {
      final res = await db.rawQuery('SELECT MAX(fecha_registro) as max_ts FROM stock_ledger');
      maxStock = res.first['max_ts'] as String?;
    } catch (_) {}

    String? maxQuote;
    try {
      final res = await db.rawQuery('SELECT MAX(created_at) as max_ts FROM smart_quotations');
      maxQuote = res.first['max_ts'] as String?;
    } catch (_) {}

    DateTime maxHistorical = DateTime(2026, 1, 1);
    for (final ts in [maxLicencia, maxVenta, maxStock, maxQuote]) {
      if (ts != null && ts.isNotEmpty) {
        final parsed = DateTime.tryParse(ts);
        if (parsed != null && parsed.isAfter(maxHistorical)) {
          maxHistorical = parsed;
        }
      }
    }

    // Tolerancia defensiva de 2 horas para evitar falsos positivos
    final threshold = maxHistorical.subtract(const Duration(hours: 2));

    if (now.isBefore(threshold)) {
      return ClockCheckResult(
        isConsistent: false,
        currentPhoneTime: now,
        lastRecordedActivityTime: maxHistorical,
        message:
            "Hora desincronizada: La fecha del teléfono ($now) es anterior a la última actividad registrada ($maxHistorical).",
      );
    }

    return ClockCheckResult(
      isConsistent: true,
      currentPhoneTime: now,
      lastRecordedActivityTime: maxHistorical,
      message: "Reloj sincronizado con el historial de base de datos.",
    );
  }

  /// Canjea un código de acceso firmado con Ed25519 aplicando renovación acumulativa sin pérdida de días y recargas de IA
  Future<LicenseModel> redeemLicenseCode(String rawCode, {DateTime? overrideNow}) async {
    final currentFingerprint = await DeviceFingerprint.generate();
    final currentLicense = await getOrCreateLicense(overrideNow: overrideNow);

    final validation = await Ed25519LicenseValidator.validateAndParse(
      rawCode: rawCode,
      currentDeviceFingerprint: currentFingerprint,
      currentLicense: currentLicense,
      overrideNow: overrideNow,
    );

    final now = overrideNow ?? DateTime.now();
    final db = await _localDb.database;

    final isOnlyAiRecharge = validation.plan == 'RECARGA_IA_150';
    final isMigrationReactivation = currentLicense.estadoActual == 'PENDIENTE_MIGRACION';
    final updatedPlan = isOnlyAiRecharge ? currentLicense.tipoPlan : validation.plan;
    // Si es reactivación de migración con daysToAdd == 0 (ej. perpetua o reactivación pura),
    // preserva la fecha de expiración existente sin desfasar el calendario.
    // Si daysToAdd > 0, el validador usó baseDate = now, fijando exactamente now + daysToAdd.
    final updatedExpiration = isOnlyAiRecharge
        ? currentLicense.fechaExpiracion
        : (isMigrationReactivation && validation.daysToAdd == 0 && currentLicense.fechaExpiracion.isAfter(now)
            ? currentLicense.fechaExpiracion
            : validation.newExpiration);
    // Si la reactivación proviene de PENDIENTE_MIGRACION (restauración en teléfono nuevo),
    // la base de datos ya recuperó el saldo IA acumulado histórico; no se vuelve a sumar
    // la cuota base del plan para evitar doble conteo. Solo se añaden bonos extra si existieran.
    final addedCumulativeScans = isMigrationReactivation
        ? validation.aiExtraCredits
        : (isOnlyAiRecharge
            ? math.max(150, validation.aiExtraCredits)
            : (LicenseModel.getCumulativeScansForPlan(validation.plan) + validation.aiExtraCredits));
    final updatedAccumulatedScans = currentLicense.aiAccumulatedScans + addedCumulativeScans;
    final updatedExtraCredits = currentLicense.aiExtraCredits + validation.aiExtraCredits;

    final updatedModel = currentLicense.copyWith(
      tipoPlan: updatedPlan,
      estadoActual: currentLicense.isPerpetual ? 'ACTIVA' : (isOnlyAiRecharge ? currentLicense.estadoActual : 'ACTIVA'),
      fechaExpiracion: updatedExpiration,
      ultimoNonce: validation.nonce,
      ultimoCodigoUsado: validation.cleanCode,
      updatesUntil: validation.updatesUntil ?? currentLicense.updatesUntil,
      maxMajorVersion: validation.maxMajorVersion,
      businessOwnerTag: validation.businessOwnerTag ?? currentLicense.businessOwnerTag,
      fechaUltimoCheck: now,
      aiExtraCredits: updatedExtraCredits,
      aiAccumulatedScans: updatedAccumulatedScans,
    );

    await db.update(
      'licencia_app',
      {
        'tipo_plan': updatedPlan,
        'estado_actual': updatedModel.estadoActual,
        'fecha_expiracion': updatedExpiration.toIso8601String(),
        'ultimo_nonce': validation.nonce,
        'ultimo_codigo_usado': validation.cleanCode,
        'updates_until': updatedModel.updatesUntil?.toIso8601String(),
        'max_major_version': validation.maxMajorVersion,
        'business_owner_tag': updatedModel.businessOwnerTag,
        'fecha_ultimo_check': now.toIso8601String(),
        'ai_extra_credits': updatedExtraCredits,
        'ai_accumulated_scans': updatedAccumulatedScans,
      },
      where: 'id = ?',
      whereArgs: [currentLicense.id ?? 1],
    );

    AppLogger.i('LicenseRepository', 'Código canjeado exitosamente: Plan $updatedPlan, Nueva Expiración: $updatedExpiration, Escaneos IA Acumulados: $updatedAccumulatedScans (+$addedCumulativeScans)');
    return updatedModel;
  }

  // ==========================================
  // GESTIÓN DE CUOTA IA ACUMULATIVA Y MULTI-PERFIL
  // ==========================================

  /// Consulta si el usuario puede realizar un escaneo con IA.
  /// - En modo BYOK: solo puede si tiene una clave propia configurada.
  /// - En modo INCLUDED: puede si su bolsa acumulativa aiAccumulatedScans > 0.
  Future<bool> canPerformAiScan({DateTime? overrideNow}) async {
    final license = await getOrCreateLicense(overrideNow: overrideNow);

    if (license.isUsingByokMode) {
      return ApiConstants.isUsingCustomApiKey;
    }

    return license.aiAccumulatedScans > 0;
  }

  /// Consume un escaneo de la cuota.
  /// - En modo BYOK: si tiene clave propia, retorna true sin descontar la bolsa acumulativa. Si no tiene clave, retorna false.
  /// - En modo INCLUDED: descuenta 1 escaneo de aiAccumulatedScans. Si ya no quedan, retorna false.
  Future<bool> consumeAiScan({DateTime? overrideNow}) async {
    final license = await getOrCreateLicense(overrideNow: overrideNow);

    if (license.isUsingByokMode) {
      return ApiConstants.isUsingCustomApiKey;
    }

    if (license.aiAccumulatedScans <= 0) {
      return false;
    }

    final db = await _localDb.database;
    final now = overrideNow ?? DateTime.now();
    final currentMonthKey = _generateMonthKey(now);
    final newUsedCount = (license.aiScansMonthKey == currentMonthKey)
        ? license.aiScansUsedMonth + 1
        : 1;
    final newAccumulated = (license.aiAccumulatedScans - 1).clamp(0, 999999);

    await db.update(
      'licencia_app',
      {
        'ai_accumulated_scans': newAccumulated,
        'ai_scans_used_month': newUsedCount,
        'ai_scans_month_key': currentMonthKey,
      },
      where: 'id = ?',
      whereArgs: [license.id ?? 1],
    );

    return true;
  }

  /// Retorna los escaneos de IA restantes disponibles en la bolsa (o 999999 si usa BYOK activo)
  Future<int> getRemainingAiScans({DateTime? overrideNow}) async {
    final license = await getOrCreateLicense(overrideNow: overrideNow);

    if (license.isUsingByokMode) {
      return ApiConstants.isUsingCustomApiKey ? 999999 : 0;
    }

    return license.aiAccumulatedScans.clamp(0, 999999);
  }

  /// Agrega créditos adicionales de escaneos IA a la licencia y bolsa acumulativa
  Future<void> addExtraAiCredits(int credits) async {
    final license = await getOrCreateLicense();
    final db = await _localDb.database;
    final updatedCredits = license.aiExtraCredits + credits;
    final updatedAccumulated = (license.aiAccumulatedScans + credits).clamp(0, 999999);

    await db.update(
      'licencia_app',
      {
        'ai_extra_credits': updatedCredits,
        'ai_accumulated_scans': updatedAccumulated,
      },
      where: 'id = ?',
      whereArgs: [license.id ?? 1],
    );
  }

  /// Cambia el modo de motor de IA: 'INCLUDED' o 'BYOK'
  Future<void> setAiSelectedMode(String mode) async {
    final license = await getOrCreateLicense();
    final db = await _localDb.database;
    final validMode = (mode.toUpperCase().trim() == 'BYOK') ? 'BYOK' : 'INCLUDED';

    await db.update(
      'licencia_app',
      {'ai_selected_mode': validMode},
      where: 'id = ?',
      whereArgs: [license.id ?? 1],
    );

    ApiConstants.setAiSelectedMode(validMode);
    AppLogger.i('LicenseRepository', 'Modo de IA cambiado a: $validMode');
  }

  /// Registra la aceptación del contrato EULA tanto en SQLite como a nivel de dispositivo (FlutterSecureStorage)
  Future<void> recordEulaAcceptance(String version) async {
    final license = await getOrCreateLicense();
    final db = await _localDb.database;
    final now = DateTime.now();

    await db.update(
      'licencia_app',
      {
        'eula_accepted_version': version,
        'eula_accepted_timestamp': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [license.id ?? 1],
    );

    try {
      await _secureStorage.write(key: deviceEulaVersionKey, value: version);
      await _secureStorage.write(key: deviceEulaTimestampKey, value: now.toIso8601String());
      AppLogger.i('LicenseRepository', 'EULA versión $version guardado a nivel global de dispositivo.');
    } catch (e) {
      AppLogger.w('LicenseRepository', 'Error respaldando EULA en almacenamiento seguro: $e');
    }
  }

  /// Actualiza la última versión de la aplicación ejecutada por el usuario
  Future<void> updateLastExecutedAppVersion(String version) async {
    final license = await getOrCreateLicense();
    final db = await _localDb.database;

    await db.update(
      'licencia_app',
      {'last_executed_app_version': version},
      where: 'id = ?',
      whereArgs: [license.id ?? 1],
    );
  }

  String _generateMonthKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }
}
