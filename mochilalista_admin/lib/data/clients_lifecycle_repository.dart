part of 'database_service.dart';

/// Repositorio de ciclo de vida del cliente: migraciones de hardware, emisiones Ed25519
/// y trazabilidad de versiones/APKs despachados.
mixin _ClientsLifecycleMixin on _DatabaseServiceBase {
  /// Reasignación de Dispositivo por Cambio o Pérdida de Celular.
  Future<Map<String, dynamic>?> migrateDevice({
    required String clientId,
    required String newDeviceId,
    required double feeAmount,
    required String paymentMethod,
    String? reason,
    bool emitImmediately = false,
    LicenseSigner? signer,
    String migrationScenario = 'RESTORED_BACKUP',
    String? newDeviceModel,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final oldDeviceId = client['current_device_id'] as String;
    final cleanNewId = newDeviceId.trim().toUpperCase();

    if (newDeviceModel != null && newDeviceModel.trim().isNotEmpty) {
      client['device_model'] = newDeviceModel.trim();
    }

    final isFreeMigration = feeAmount <= 0;
    final effectiveMethod =
        isFreeMigration ? 'Gratuito / Cortesía' : paymentMethod;
    final effectiveReason = reason?.trim().isNotEmpty == true
        ? reason!.trim()
        : (isFreeMigration
            ? 'Garantía de equipo / Traslado gratuito por cortesía'
            : 'Cambio o pérdida de teléfono');

    final history =
        (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();
    history.add({
      'old_device_id': oldDeviceId,
      'new_device_id': cleanNewId,
      'migrated_at': DateTime.now().toUtc().toIso8601String(),
      'fee_charged': feeAmount,
      'payment_method': effectiveMethod,
      'reason': effectiveReason,
      'scenario': migrationScenario,
      if (newDeviceModel != null && newDeviceModel.trim().isNotEmpty)
        'device_model': newDeviceModel.trim(),
    });
    client['device_history'] = history;
    client['current_device_id'] = cleanNewId;

    final currentNonce = (client['next_nonce'] as num?)?.toInt() ?? 1;
    final migrationNonce = currentNonce + 1;
    client['next_nonce'] = migrationNonce;

    String? generatedPaymentId;
    if (feeAmount > 0) {
      generatedPaymentId = 'MIG-${DateTime.now().millisecondsSinceEpoch}';
      final payments = (client['payment_history'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      payments.add({
        'id': generatedPaymentId,
        'date': DateTime.now().toUtc().toIso8601String(),
        'amount': feeAmount,
        'plan': 'SERVICIO_MIGRACION',
        'method': paymentMethod,
        'reference': 'Migración de $oldDeviceId a $cleanNewId',
        'notes': effectiveReason,
      });
      client['payment_history'] = payments;
    }

    String? emittedToken;
    Map<String, dynamic>? migrationTokenInfo;

    if (emitImmediately && signer != null) {
      final plan = client['license_type'] as String? ?? 'MENSUAL';
      final isPerpetual = plan.toUpperCase().contains('PERPETU');
      final currentExpStr = client['license_expires'] as String?;
      final currentExp =
          currentExpStr != null ? DateTime.tryParse(currentExpStr) : null;
      final now = DateTime.now();

      int daysToAdd = 0;
      if (migrationScenario == 'RESTORED_BACKUP') {
        daysToAdd = 0;
      } else {
        if (isPerpetual) {
          daysToAdd = 99999;
        } else if (currentExp != null && currentExp.isAfter(now)) {
          daysToAdd = math.max(1, currentExp.difference(now).inDays);
        } else {
          daysToAdd = 30;
        }
      }

      DateTime? updatesUntil;
      if (client['updates_until'] != null) {
        updatesUntil = DateTime.tryParse(client['updates_until']);
      }

      emittedToken = await signer.generateLicenseToken(
        deviceFingerprint: cleanNewId,
        plan: plan,
        daysToAdd: daysToAdd,
        nonce: migrationNonce,
        updatesUntil: updatesUntil,
        businessTag: client['business_name'] as String?,
        aiExtraCredits: 0,
        isMigration: true,
      );

      final codes = (client['generated_codes_history'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      codes.add({
        'token': emittedToken,
        'plan': plan,
        'days_added': daysToAdd,
        'nonce': migrationNonce,
        'created_at': now.toUtc().toIso8601String(),
        'emitted_at': now.toUtc().toIso8601String(),
        'device_id': cleanNewId,
        'expires_at': client['license_expires'],
        'expires_result': client['license_expires'],
        'is_migration_token': true,
        'migration_scenario': migrationScenario,
        'base_ai_credits': 0,
        'bonus_ai_credits': 0,
        'total_ai_credited': 0,
        'ai_credits': 0,
      });
      client['generated_codes_history'] = codes;

      migrationTokenInfo = {
        'token': emittedToken,
        'plan': plan,
        'device_id': cleanNewId,
        'nonce': migrationNonce,
        'days_retained': daysToAdd,
        'expires_date': client['license_expires'],
        'is_migration': true,
        'migration_scenario': migrationScenario,
      };
    }

    clients[index] = client;
    await saveClients(clients, reason: 'migrate_device_$clientId');

    final resultMap = Map<String, dynamic>.from(client);
    if (generatedPaymentId != null) {
      resultMap['payment_id'] = generatedPaymentId;
    }
    if (emittedToken != null) {
      resultMap['emitted_migration_token'] = emittedToken;
      resultMap['migration_token_info'] = migrationTokenInfo;
    }
    return resultMap;
  }

  /// Actualización del motivo u observación de una migración en el historial de hardware.
  Future<Map<String, dynamic>?> updateDeviceHistoryReason({
    required String clientId,
    required int historyIndex,
    required String reason,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final history =
        (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();
    if (historyIndex < 0 || historyIndex >= history.length) return null;

    history[historyIndex]['reason'] = reason.trim();
    client['device_history'] = history;
    clients[index] = client;

    await saveClients(clients,
        reason: 'update_migration_reason_${clientId}_$historyIndex');
    return client;
  }

  /// Registro de Código Emitido con Renovación Acumulativa y Recargas de IA.
  Future<Map<String, dynamic>?> recordCodeEmission({
    required String clientId,
    required String token,
    required String plan,
    required int daysToAdd,
    required double paymentAmount,
    required String paymentMethod,
    required String paymentRef,
    required DateTime? updatesUntil,
    int aiExtraCredits = 0,
    DateTime? customExactExpiration,
    bool resetFromToday = false,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final now = DateTime.now();
    final normPlan = LicenseSigner.normalizePlanSlug(plan);

    DateTime baseDate;
    final currentExpStr = client['license_expires'] as String?;
    final currentExp =
        currentExpStr != null ? DateTime.tryParse(currentExpStr) : null;

    if (!resetFromToday &&
        currentExp != null &&
        currentExp.isAfter(now) &&
        client['license_type'] != 'TRIAL_VENCIDO') {
      baseDate = currentExp;
    } else {
      baseDate = now;
    }

    final basePlanCredits = (normPlan == 'RECARGA_IA_150')
        ? 150
        : (normPlan == 'BONO_IA_PERSONALIZADO'
            ? 0
            : DatabaseService.getCumulativeScansForPlan(normPlan));
    final totalCreditsToAdd = (normPlan == 'BONO_IA_PERSONALIZADO')
        ? aiExtraCredits
        : (basePlanCredits + aiExtraCredits);

    DateTime newExpiration;
    if (customExactExpiration != null) {
      newExpiration = customExactExpiration;
    } else if (normPlan == 'RECARGA_IA_150' ||
        normPlan == 'BONO_IA_PERSONALIZADO') {
      newExpiration = currentExp ?? now;
    } else if (normPlan == 'PERPETUO_LIBERADO') {
      newExpiration = DateTime(2299, 12, 31);
      client['license_type'] = 'PERPETUO_LIBERADO';
      client['license_status'] = 'PERPETUA';
      client['license_expires'] = newExpiration.toUtc().toIso8601String();
    } else {
      newExpiration = baseDate.add(Duration(days: daysToAdd));
      client['license_type'] = normPlan;
      client['license_status'] = 'ACTIVA';
      client['license_expires'] = newExpiration.toUtc().toIso8601String();
    }

    if (totalCreditsToAdd > 0) {
      final currentCredits = (client['ai_extra_credits'] as num?)?.toInt() ?? 0;
      final updatedCredits = currentCredits + totalCreditsToAdd;
      client['ai_extra_credits'] = updatedCredits;

      final curReported =
          (client['ai_reported_balance'] as num?)?.toInt() ?? 50;
      client['ai_reported_balance'] = curReported + totalCreditsToAdd;
      client['ai_accumulated_credits'] =
          (client['ai_reported_balance'] as num).toInt();
    }

    if (aiExtraCredits > 0 || normPlan == 'BONO_IA_PERSONALIZADO') {
      final creditsDiscounted = (normPlan == 'BONO_IA_PERSONALIZADO')
          ? totalCreditsToAdd
          : aiExtraCredits;
      final currentPending = (client['ai_pending_bonus'] as num?)?.toInt() ?? 0;
      if (currentPending > 0) {
        final remainingPending =
            (currentPending - creditsDiscounted).clamp(0, 99999);
        client['ai_pending_bonus'] = remainingPending;
      }
    }

    final currentNonce = (client['next_nonce'] as num?)?.toInt() ?? 1;
    client['next_nonce'] = currentNonce + 1;

    if (updatesUntil != null) {
      client['updates_until'] = updatesUntil.toUtc().toIso8601String();
    }

    String? newPaymentId;
    if (paymentAmount > 0) {
      newPaymentId = 'PAY-${DateTime.now().millisecondsSinceEpoch}';
      final payments = (client['payment_history'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      payments.add({
        'id': newPaymentId,
        'date': now.toUtc().toIso8601String(),
        'amount': paymentAmount,
        'plan': normPlan,
        'method': paymentMethod,
        'reference': paymentRef,
      });
      client['payment_history'] = payments;
    }

    final codes = (client['generated_codes_history'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    codes.add({
      'token': token,
      'plan': normPlan,
      'days_added': daysToAdd,
      'nonce': currentNonce,
      'created_at': now.toUtc().toIso8601String(),
      'emitted_at': now.toUtc().toIso8601String(),
      'device_id': client['current_device_id'],
      'expires_at': newExpiration.toUtc().toIso8601String(),
      'expires_result': newExpiration.toUtc().toIso8601String(),
      'base_ai_credits': basePlanCredits,
      'bonus_ai_credits': aiExtraCredits,
      'total_ai_credited': totalCreditsToAdd,
      'ai_credits': totalCreditsToAdd,
      'payment_id': newPaymentId,
      'amount_paid': paymentAmount > 0 ? paymentAmount : 0.0,
    });
    client['generated_codes_history'] = codes;

    clients[index] = client;
    await saveClients(clients, reason: 'emit_code_$clientId');
    return client;
  }

  /// Marcar que el cliente actualizó su versión de app instalada con blindaje anti-degradación.
  Future<Map<String, dynamic>?> markClientUpdated(
    String clientId,
    String versionName, {
    bool force = false,
  }) async {
    final client = await getClientById(clientId);
    if (client == null) return null;
    final cleanTarget = versionName.trim();
    final currentInstalled =
        (client['installed_version'] as String? ?? '9.0.0').trim();
    if (!force &&
        DatabaseService.compareSemVer(currentInstalled, cleanTarget) > 0) {
      return client;
    }
    final updates = <String, dynamic>{'installed_version': cleanTarget};
    if (currentInstalled != cleanTarget) {
      updates['previous_installed_version'] = currentInstalled;
      updates['installed_version_updated_at'] =
          DateTime.now().toUtc().toIso8601String();
    }
    return updateClient(clientId, updates);
  }

  /// Registra la trazabilidad del APK enviado por WhatsApp.
  Future<Map<String, dynamic>?> recordApkDispatched(
    String clientId,
    String version, {
    String? variant,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return updateClient(clientId, {
      'last_apk_sent_version': version,
      'last_apk_sent_at': nowIso,
      if (variant != null) 'last_apk_sent_variant': variant,
    });
  }
}
