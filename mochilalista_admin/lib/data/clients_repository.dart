part of 'database_service.dart';

/// Repositorio de gestión CRUD de cartera de clientes y sincronización `.mlsync`/`MLS1`.
mixin _ClientsRepositoryMixin on _DatabaseServiceBase {
  @override
  Future<List<Map<String, dynamic>>> getClients() async {
    if (!await _clientsFile.exists()) return [];
    final content = await _clientsFile.readAsString();
    final list = jsonDecode(content) as List;
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> saveClients(
    List<Map<String, dynamic>> clients, {
    String reason = 'update_clients',
  }) async {
    await _clientsFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(clients));
    await _createSnapshot(reason);
    if (_mode == 'prod' && onProductionDataChanged != null) {
      try {
        await onProductionDataChanged!();
      } catch (e) {
        stderr.writeln(
            'Warning: Error al ejecutar onProductionDataChanged tras saveClients: $e');
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> getClientById(String id) async {
    final clients = await getClients();
    try {
      return clients.firstWhere((c) => c['id'] == id);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createClient(
      Map<String, dynamic> clientData) async {
    final clients = await getClients();
    int maxNum = 0;
    for (final c in clients) {
      final cid = c['id'] as String? ?? '';
      if (cid.startsWith('CLI-')) {
        final n = int.tryParse(cid.substring(4)) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    final id = 'CLI-${(maxNum + 1).toString().padLeft(3, '0')}';
    final now = DateTime.now().toUtc();

    final rawPlan =
        (clientData['license_type'] as String? ?? 'TRIAL').toUpperCase().trim();
    final rawStatus =
        (clientData['license_status'] as String? ?? '').toUpperCase().trim();
    final isProspect = rawPlan == 'PROSPECTO' || rawStatus == 'PROSPECTO';
    final plan =
        isProspect ? 'PROSPECTO' : LicenseSigner.normalizePlanSlug(rawPlan);

    var rawDeviceId =
        (clientData['current_device_id'] ?? '').toString().trim().toUpperCase();
    if (rawDeviceId.isEmpty || rawDeviceId == 'PENDIENTE') {
      rawDeviceId = isProspect ? 'PENDIENTE' : 'ML-0000';
    }

    if (rawDeviceId != 'PENDIENTE' && rawDeviceId != 'ML-0000') {
      final exists = clients.any((c) =>
          (c['current_device_id'] as String? ?? '').toUpperCase() ==
          rawDeviceId);
      if (exists) {
        throw ArgumentError(
            'El Hardware ID $rawDeviceId ya está asignado a otro cliente.');
      }
    }

    int trialDays = 30;
    if (clientData.containsKey('trial_days_remaining') &&
        clientData['trial_days_remaining'] != null) {
      final customDays = (clientData['trial_days_remaining'] as num).toInt();
      if (customDays > 0 && customDays <= 365) {
        trialDays = customDays;
      }
    } else if (plan == 'TRIMESTRAL') {
      trialDays = 90;
    } else if (plan == 'SEMESTRAL') {
      trialDays = 180;
    } else if (plan == 'ANUAL') {
      trialDays = 365;
    } else if (plan.contains('PERPETU')) {
      trialDays = 99999;
    } else if (plan == 'PASE_ACTUALIZACION_ANUAL') {
      trialDays = 0;
    } else if (plan == 'RECARGA_IA_150') {
      trialDays = 0;
    } else if (plan == 'EXTENSION_CORTESIA') {
      trialDays = 7;
    }

    String? expiresAt;
    if (isProspect) {
      expiresAt = null;
    } else if (plan.contains('PERPETU')) {
      expiresAt = DateTime(2299, 12, 31).toUtc().toIso8601String();
    } else {
      expiresAt = clientData['license_expires'] ??
          now.add(Duration(days: trialDays)).toIso8601String();
    }

    String? updatesUntil;
    if (clientData.containsKey('updates_until') &&
        clientData['updates_until'] != null) {
      updatesUntil = clientData['updates_until'] as String?;
    } else if (plan.contains('PERPETU') || plan == 'PASE_ACTUALIZACION_ANUAL') {
      updatesUntil = now.add(const Duration(days: 365)).toIso8601String();
    } else {
      updatesUntil = null;
    }

    final hasReportedBalance = clientData.containsKey('ai_reported_balance') &&
        clientData['ai_reported_balance'] != null;
    final reportedAi = hasReportedBalance
        ? (clientData['ai_reported_balance'] as num).toInt()
        : (isProspect ? 0 : 50);
    final pendingBonusAi =
        (clientData['ai_pending_bonus'] as num?)?.toInt() ?? 0;
    final baseAi = isProspect ? 0 : DatabaseService.getCumulativeScansForPlan(plan);

    int finalExtraAi;
    int accumulatedAi;

    if (isProspect) {
      finalExtraAi = 0;
      accumulatedAi = 0;
    } else if (plan == 'TRIAL') {
      if (hasReportedBalance || pendingBonusAi > 0) {
        finalExtraAi = (clientData.containsKey('ai_extra_credits') &&
                clientData['ai_extra_credits'] != null &&
                pendingBonusAi == 0)
            ? (clientData['ai_extra_credits'] as num).toInt()
            : 0;
        accumulatedAi = reportedAi;
      } else {
        finalExtraAi =
            (clientData['ai_extra_credits'] as num?)?.toInt() ?? baseAi;
        accumulatedAi = finalExtraAi;
      }
    } else {
      final explicitExtra = (clientData['ai_extra_credits'] as num?)?.toInt();
      finalExtraAi = explicitExtra ?? baseAi;
      accumulatedAi =
          hasReportedBalance ? reportedAi : (baseAi + (explicitExtra ?? 0));
    }

    final phone =
        DatabaseService.normalizePeruPhone(clientData['phone'] as String? ?? '');
    final rawFollowup = clientData['next_followup_date'] as String?;
    final String? nextFollowup =
        (rawFollowup != null && rawFollowup.trim().isNotEmpty)
            ? rawFollowup.trim()
            : null;

    final newClient = {
      'id': id,
      'business_name': clientData['business_name'] ?? 'Negocio Sin Nombre',
      'owner_name': clientData['owner_name'] ?? 'Propietario',
      'document_id':
          clientData['document_id'] ?? clientData['document_number'] ?? '',
      'document_number':
          clientData['document_number'] ?? clientData['document_id'] ?? '',
      'phone': phone,
      'current_device_id': rawDeviceId,
      'device_model': (clientData['device_model'] as String?)?.trim() ?? '',
      'device_history': [],
      'installed_version': clientData['installed_version'] ?? '9.34.0',
      'license_type': plan,
      'license_status': isProspect
          ? 'PROSPECTO'
          : (plan.contains('PERPETU') ? 'PERPETUA' : 'ACTIVA'),
      'license_expires': expiresAt,
      'expected_subscription_date': clientData['expected_subscription_date'],
      'next_followup_date': nextFollowup,
      'trial_days_remaining':
          (!isProspect && plan == 'TRIAL') ? trialDays : null,
      'next_nonce': 1,
      'updates_until': updatesUntil,
      'ai_reported_balance': reportedAi,
      'ai_pending_bonus': pendingBonusAi,
      'ai_extra_credits': finalExtraAi,
      'ai_accumulated_credits': accumulatedAi,
      'notes': clientData['notes'] ?? '',
      'created_at': now.toIso8601String(),
      'payment_history': clientData['payment_history'] ?? [],
      'generated_codes_history': [],
    };

    clients.add(newClient);
    await saveClients(clients, reason: 'create_client_$id');
    return newClient;
  }

  @override
  Future<Map<String, dynamic>?> updateClient(
      String id, Map<String, dynamic> updates) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == id);
    if (index == -1) return null;

    final client = clients[index];

    if (updates.containsKey('phone')) {
      updates['phone'] =
          DatabaseService.normalizePeruPhone(updates['phone'] as String? ?? '');
    }

    if (updates.containsKey('next_followup_date')) {
      final rawFollowup = updates['next_followup_date'] as String?;
      updates['next_followup_date'] =
          (rawFollowup != null && rawFollowup.trim().isNotEmpty)
              ? rawFollowup.trim()
              : null;
    }

    if (updates.containsKey('current_device_id')) {
      final cleanDev =
          (updates['current_device_id'] as String? ?? '').trim().toUpperCase();
      if (cleanDev.isNotEmpty &&
          cleanDev != 'PENDIENTE' &&
          cleanDev != 'ML-0000') {
        final exists = clients.any((c) =>
            c['id'] != id &&
            (c['current_device_id'] as String? ?? '').toUpperCase() ==
                cleanDev);
        if (exists) {
          throw ArgumentError(
              'El Hardware ID $cleanDev ya está asignado a otro cliente.');
        }
      }
      updates['current_device_id'] = cleanDev.isEmpty ? 'PENDIENTE' : cleanDev;
    }

    updates.forEach((key, value) {
      if (key != 'id') {
        client[key] = value;
      }
    });

    clients[index] = client;
    await saveClients(clients, reason: 'update_client_$id');
    return client;
  }

  /// Sincronización atómica de datos reales reportados en el celular del cliente.
  Future<Map<String, dynamic>?> syncClientReportedState({
    required String clientId,
    String? deviceId,
    String? installedVersion,
    int? aiReportedBalance,
    int? trialDaysRemaining,
    String? expirationDate,
    String? deviceModel,
    String? notes,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];

    if (deviceId != null && deviceId.trim().isNotEmpty) {
      final cleanDev = deviceId.trim().toUpperCase();
      if (cleanDev != 'PENDIENTE' &&
          cleanDev != (client['current_device_id'] as String? ?? '')) {
        final exists = clients.any((c) =>
            c['id'] != clientId &&
            (c['current_device_id'] as String? ?? '').toUpperCase() ==
                cleanDev &&
            cleanDev != 'PENDIENTE' &&
            cleanDev != 'ML-0000');
        if (exists) {
          throw ArgumentError(
              'El Hardware ID $cleanDev ya está asignado a otro cliente.');
        }
      }
      client['current_device_id'] = cleanDev;
    }

    if (installedVersion != null && installedVersion.trim().isNotEmpty) {
      client['installed_version'] = installedVersion.trim();
    }

    if (aiReportedBalance != null) {
      client['ai_reported_balance'] = aiReportedBalance;
    }

    if (trialDaysRemaining != null && trialDaysRemaining > 0) {
      client['trial_days_remaining'] = trialDaysRemaining;
      client['license_expires'] = DateTime.now()
          .toUtc()
          .add(Duration(days: trialDaysRemaining))
          .toIso8601String();
    } else if (expirationDate != null && expirationDate.trim().isNotEmpty) {
      client['license_expires'] = expirationDate.trim();
    }

    if (deviceModel != null && deviceModel.trim().isNotEmpty) {
      client['device_model'] = deviceModel.trim();
    }

    if (notes != null) {
      client['notes'] = notes;
    }

    clients[index] = client;
    await saveClients(clients, reason: 'sync_reported_$clientId');
    return client;
  }

  /// Aplica el snapshot del estado real del cliente recibido mediante el protocolo MLS1 / `.mlsync`.
  Future<Map<String, dynamic>?> applyClientSyncSnapshot(
    String clientId,
    Map<String, dynamic> payload, {
    bool forceOlder = false,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];

    final tsEpoch = payload['ts'] as int? ?? 0;
    final syncDateTime =
        DateTime.fromMillisecondsSinceEpoch(tsEpoch, isUtc: true);

    if (client['last_sync_at'] != null && !forceOlder) {
      final lastSync = DateTime.tryParse(client['last_sync_at'].toString());
      if (lastSync != null && syncDateTime.isBefore(lastSync)) {
        throw StaleSyncException(
          'La ficha de sincronización (${syncDateTime.toIso8601String()}) es anterior a la última registrada (${lastSync.toIso8601String()}).',
          syncTimestamp: syncDateTime,
          lastSyncAt: lastSync,
        );
      }
    }

    if (payload.containsKey('ai') && payload['ai'] != null) {
      client['ai_reported_balance'] = (payload['ai'] as num).toInt();
    }
    if (payload.containsKey('aiu') && payload['aiu'] != null) {
      final prevAiu = client['ai_credits_used_total'] is num
          ? (client['ai_credits_used_total'] as num).toInt()
          : null;
      final newAiu = (payload['aiu'] as num).toInt();
      if (prevAiu != null && (newAiu - prevAiu) >= 0) {
        client['ai_credits_used_delta'] = newAiu - prevAiu;
      }
      client['ai_credits_used_total'] = newAiu;
    }
    if (payload.containsKey('byok')) {
      client['uses_byok'] = payload['byok'] == true;
    }
    if (payload.containsKey('av') &&
        (payload['av'] as String? ?? '').isNotEmpty) {
      client['installed_version'] = (payload['av'] as String).trim();
    }
    if (payload.containsKey('mod') &&
        (payload['mod'] as String? ?? '').isNotEmpty) {
      client['device_model'] = (payload['mod'] as String).trim();
    }
    if (payload.containsKey('os') &&
        (payload['os'] as String? ?? '').isNotEmpty) {
      client['android_version'] = (payload['os'] as String).trim();
    }
    if (payload.containsKey('pc') && payload['pc'] != null) {
      client['profiles_count'] = (payload['pc'] as num).toInt();
    }
    if (payload.containsKey('dr') && payload['dr'] != null) {
      client['trial_days_remaining'] = (payload['dr'] as num).toInt();
    }
    if (payload.containsKey('drv')) {
      client['backup_drive_linked'] = payload['drv'] == true;
    }
    if (payload.containsKey('bh') &&
        (payload['bh'] as String? ?? '').isNotEmpty) {
      client['backup_health_status'] = (payload['bh'] as String).trim();
    }
    if (payload.containsKey('lb')) {
      client['last_backup_at'] = payload['lb'];
    }
    if (payload.containsKey('n') && payload['n'] != null) {
      client['ultimo_nonce'] = (payload['n'] as num).toInt();
    }

    client['last_sync_at'] = syncDateTime.toIso8601String();
    if (tsEpoch > 0) {
      client['last_sync_ts'] = tsEpoch;
    }
    client['last_sync_payload'] = {
      'version': payload['av'],
      'version_code': payload['bc'],
      'sqlite_schema': payload['db'],
      'ai_balance': payload['ai'],
      'ai_used': payload['aiu'],
      'ai_used_delta': client['ai_credits_used_delta'],
      'profiles_count': payload['pc'],
      'days_remaining': payload['dr'],
      'status': payload['st'],
      'backup_health': payload['bh'],
      'device_model': payload['mod'],
      'android_version': payload['os'],
      'sync_ts': tsEpoch,
    };

    clients[index] = client;
    await saveClients(clients, reason: 'apply_sync_$clientId');
    return client;
  }

  Future<bool> deleteClient(String id) async {
    final clients = await getClients();
    final initialLength = clients.length;
    clients.removeWhere((c) => c['id'] == id);
    if (clients.length < initialLength) {
      await saveClients(clients, reason: 'delete_client_$id');
      return true;
    }
    return false;
  }
}
