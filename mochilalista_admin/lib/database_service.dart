import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'license_signer.dart';
import 'config_service.dart';

/// Excepción de protección anti-sobreescritura para fichas de sincronización cronológicamente desfasadas
class StaleSyncException implements Exception {
  final String message;
  final DateTime syncTimestamp;
  final DateTime lastSyncAt;

  StaleSyncException(
    this.message, {
    required this.syncTimestamp,
    required this.lastSyncAt,
  });

  @override
  String toString() => message;
}

/// Servicio de Persistencia Real en Disco Duro con Arquitectura de Doble Estado
/// Soporta 'sandbox' (Modo Pruebas) y 'prod' (Modo Producción Real)
class DatabaseService {
  final String dataDir;
  final String backupDir;
  final String releasesDir;
  final int maxAutoSnapshots;

  String _mode = 'sandbox';

  /// Callback opcional no bloqueante disparado únicamente cuando se guardan datos en modo 'prod'
  Future<void> Function()? onProductionDataChanged;

  DatabaseService({
    this.dataDir = 'data',
    this.backupDir = 'backups',
    this.releasesDir = 'releases_apks',
    this.maxAutoSnapshots = 30,
  });

  String get currentMode => _mode;

  void setMode(String newMode) {
    if (newMode != 'sandbox' && newMode != 'prod') {
      throw ArgumentError('Modo no válido. Use "sandbox" o "prod".');
    }
    _mode = newMode;
  }

  File get _clientsFile => File('$dataDir/${_mode}_clients_db.json');
  File get _releasesFile => File('$dataDir/${_mode}_releases_db.json');
  Directory get currentReleasesApkDir => Directory('$releasesDir/$_mode');

  /// Inicializa directorios y archivos si no existen
  Future<void> init() async {
    await Directory(dataDir).create(recursive: true);
    await Directory(backupDir).create(recursive: true);
    await Directory('$releasesDir/sandbox').create(recursive: true);
    await Directory('$releasesDir/prod').create(recursive: true);

    // Inicializar SANDBOX
    final sandboxClientsFile = File('$dataDir/sandbox_clients_db.json');
    final sandboxReleasesFile = File('$dataDir/sandbox_releases_db.json');

    if (!await sandboxClientsFile.exists()) {
      // Migrar desde legacy clients_db.json si existe, o sembrar datos demo
      final legacyClients = File('$dataDir/clients_db.json');
      if (await legacyClients.exists()) {
        await legacyClients.copy(sandboxClientsFile.path);
      } else {
        await sandboxClientsFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(_getInitialSandboxClients()),
        );
      }
    }

    if (!await sandboxReleasesFile.exists()) {
      final legacyReleases = File('$dataDir/releases_db.json');
      if (await legacyReleases.exists()) {
        await legacyReleases.copy(sandboxReleasesFile.path);
      } else {
        await sandboxReleasesFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(_getInitialSandboxReleases()),
        );
      }
    }

    // Inicializar PRODUCCIÓN (Inicia estrictamente vacío: 0 clientes, 0 releases)
    final prodClientsFile = File('$dataDir/prod_clients_db.json');
    final prodReleasesFile = File('$dataDir/prod_releases_db.json');

    if (!await prodClientsFile.exists()) {
      await prodClientsFile.writeAsString('[]');
    }
    if (!await prodReleasesFile.exists()) {
      await prodReleasesFile.writeAsString('[]');
    }
  }

  /// Restablece los datos del entorno de pruebas a su estado inicial
  Future<void> resetSandbox() async {
    final oldMode = _mode;
    _mode = 'sandbox';
    try {
      await _createSnapshot('before_reset_sandbox');
      await _clientsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_getInitialSandboxClients()),
      );
      await _releasesFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_getInitialSandboxReleases()),
      );
      await _createSnapshot('after_reset_sandbox');
    } finally {
      _mode = oldMode;
    }
  }

  /// Crea un snapshot de seguridad en disco con timestamp y prefijo de modo
  Future<void> _createSnapshot(String reason) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final clientSnapshot = File('$backupDir/${_mode}_clients_${reason}_$timestamp.json');
    final releaseSnapshot = File('$backupDir/${_mode}_releases_${reason}_$timestamp.json');

    if (await _clientsFile.exists()) {
      await _clientsFile.copy(clientSnapshot.path);
    }
    if (await _releasesFile.exists()) {
      await _releasesFile.copy(releaseSnapshot.path);
    }
    await _cleanOldSnapshots();
  }

  /// Limpia los snapshots automáticos antiguos en `backups/`, conservando los últimos [maxAutoSnapshots] (default: 30).
  /// Excluye explícitamente cualquier respaldo manual, de bóveda o de pre-restauración/importación.
  Future<void> _cleanOldSnapshots({int? maxAutoSnapshots}) async {
    final limit = maxAutoSnapshots ?? this.maxAutoSnapshots;
    final dir = Directory(backupDir);
    if (!await dir.exists()) return;

    final List<File> autoSnapshots = [];
    final entities = await dir.list().toList();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = entity.uri.pathSegments.last;
        final lower = filename.toLowerCase();

        // Prefijos automáticos válidos: sandbox_ o prod_
        final isDbSnapshot = filename.startsWith('sandbox_') || filename.startsWith('prod_');
        if (!isDbSnapshot) continue;

        // Excluir respaldos protegidos (manuales, bóveda, pre_restore, pre_import)
        final isProtected = lower.contains('manual') ||
            lower.contains('vault') ||
            lower.contains('pre_restore') ||
            lower.contains('pre_import');
        if (isProtected) continue;

        autoSnapshots.add(entity);
      }
    }

    if (autoSnapshots.length <= limit) return;

    // Obtener stats para ordenar de más reciente a más antiguo
    final fileStats = <String, FileStat>{};
    for (final file in autoSnapshots) {
      fileStats[file.path] = await file.stat();
    }

    autoSnapshots.sort((a, b) {
      final statA = fileStats[a.path]!;
      final statB = fileStats[b.path]!;
      final cmp = statB.modified.compareTo(statA.modified);
      if (cmp != 0) return cmp;
      return b.path.compareTo(a.path);
    });

    final toDelete = autoSnapshots.sublist(limit);
    for (final file in toDelete) {
      try {
        await file.delete();
      } catch (e) {
        stderr.writeln('Warning: Error eliminando snapshot antiguo ${file.path}: $e');
      }
    }
  }

  /// Método público para forzar o parametrizar la limpieza de snapshots automáticos
  Future<void> cleanOldSnapshots({int? maxAutoSnapshots}) =>
      _cleanOldSnapshots(maxAutoSnapshots: maxAutoSnapshots);

  /// Refresca en memoria los registros de producción y releases desde disco
  Future<void> reloadFromDisk() async {
    await Directory(dataDir).create(recursive: true);
    await Directory(backupDir).create(recursive: true);
    await getClients();
    await getReleases();
  }

  // =================== CLIENTES ===================

  Future<List<Map<String, dynamic>>> getClients() async {
    if (!await _clientsFile.exists()) return [];
    final content = await _clientsFile.readAsString();
    final list = jsonDecode(content) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> saveClients(List<Map<String, dynamic>> clients, {String reason = 'update_clients'}) async {
    await _clientsFile.writeAsString(const JsonEncoder.withIndent('  ').convert(clients));
    await _createSnapshot(reason);
    if (_mode == 'prod' && onProductionDataChanged != null) {
      try {
        await onProductionDataChanged!();
      } catch (e) {
        stderr.writeln('Warning: Error al ejecutar onProductionDataChanged tras saveClients: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> getClientById(String id) async {
    final clients = await getClients();
    try {
      return clients.firstWhere((c) => c['id'] == id);
    } catch (_) {
      return null;
    }
  }

  /// Normalización estándar de teléfonos WhatsApp Perú (+51)
  static String normalizePeruPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    if (hasPlus) {
      return '+$digits';
    }
    if (digits.length == 9 && digits.startsWith('9')) {
      return '+51$digits';
    }
    if (digits.length == 11 && digits.startsWith('519')) {
      return '+$digits';
    }
    return digits;
  }

  /// Helper oficial para consultar la cuota IA base acumulativa por plan
  static int getCumulativeScansForPlan(String planName) =>
      LicenseSigner.getCumulativeScansForPlan(planName);

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> clientData) async {
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

    final rawPlan = (clientData['license_type'] as String? ?? 'TRIAL').toUpperCase().trim();
    final rawStatus = (clientData['license_status'] as String? ?? '').toUpperCase().trim();
    final isProspect = rawPlan == 'PROSPECTO' || rawStatus == 'PROSPECTO';
    final plan = isProspect ? 'PROSPECTO' : LicenseSigner.normalizePlanSlug(rawPlan);

    // 1. Manejo y validación anti-colisión de Hardware ID
    var rawDeviceId = (clientData['current_device_id'] ?? '').toString().trim().toUpperCase();
    if (rawDeviceId.isEmpty || rawDeviceId == 'PENDIENTE') {
      rawDeviceId = isProspect ? 'PENDIENTE' : 'ML-0000';
    }

    if (rawDeviceId != 'PENDIENTE' && rawDeviceId != 'ML-0000') {
      final exists = clients.any((c) =>
          (c['current_device_id'] as String? ?? '').toUpperCase() == rawDeviceId);
      if (exists) {
        throw ArgumentError('El Hardware ID $rawDeviceId ya está asignado a otro cliente.');
      }
    }

    // 2. Duración y Expiración según Modo (Soporta días reales de Trial)
    int trialDays = 30;
    if (clientData.containsKey('trial_days_remaining') && clientData['trial_days_remaining'] != null) {
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
      expiresAt = clientData['license_expires'] ?? now.add(Duration(days: trialDays)).toIso8601String();
    }

    // 3. Ventana de Actualización (updates_until)
    String? updatesUntil;
    if (clientData.containsKey('updates_until') && clientData['updates_until'] != null) {
      updatesUntil = clientData['updates_until'] as String?;
    } else if (plan.contains('PERPETU') || plan == 'PASE_ACTUALIZACION_ANUAL') {
      updatesUntil = now.add(const Duration(days: 365)).toIso8601String();
    } else {
      updatesUntil = null;
    }

    // 4. Créditos IA: saldo reportado en celular vs bono pendiente en token
    final hasReportedBalance = clientData.containsKey('ai_reported_balance') && clientData['ai_reported_balance'] != null;
    final reportedAi = hasReportedBalance
        ? (clientData['ai_reported_balance'] as num).toInt()
        : (isProspect ? 0 : 50);
    final pendingBonusAi = (clientData['ai_pending_bonus'] as num?)?.toInt() ?? 0;
    final baseAi = isProspect ? 0 : getCumulativeScansForPlan(plan);

    int finalExtraAi;
    int accumulatedAi;

    if (isProspect) {
      finalExtraAi = 0;
      accumulatedAi = 0;
    } else if (plan == 'TRIAL') {
      if (hasReportedBalance || pendingBonusAi > 0) {
        // Alta con datos reales desde UI / móvil:
        // ai_extra_credits es 0 porque aún no se emite el token
        // ai_accumulated_credits es reportedAi (lo que realmente tiene el celular, ej. 49)
        finalExtraAi = (clientData.containsKey('ai_extra_credits') && clientData['ai_extra_credits'] != null && pendingBonusAi == 0)
            ? (clientData['ai_extra_credits'] as num).toInt()
            : 0;
        accumulatedAi = reportedAi;
      } else {
        // Alta legacy sin especificar reported_balance ni pending_bonus:
        finalExtraAi = (clientData['ai_extra_credits'] as num?)?.toInt() ?? baseAi;
        accumulatedAi = finalExtraAi;
      }
    } else {
      // Clientes comerciales
      final explicitExtra = (clientData['ai_extra_credits'] as num?)?.toInt();
      finalExtraAi = explicitExtra ?? baseAi;
      accumulatedAi = hasReportedBalance ? reportedAi : (baseAi + (explicitExtra ?? 0));
    }

    final phone = normalizePeruPhone(clientData['phone'] as String? ?? '');
    final rawFollowup = clientData['next_followup_date'] as String?;
    final String? nextFollowup = (rawFollowup != null && rawFollowup.trim().isNotEmpty)
        ? rawFollowup.trim()
        : null;

    final newClient = {
      'id': id,
      'business_name': clientData['business_name'] ?? 'Negocio Sin Nombre',
      'owner_name': clientData['owner_name'] ?? 'Propietario',
      'document_id': clientData['document_id'] ?? clientData['document_number'] ?? '',
      'document_number': clientData['document_number'] ?? clientData['document_id'] ?? '',
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
      'trial_days_remaining': (!isProspect && plan == 'TRIAL') ? trialDays : null,
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

  Future<Map<String, dynamic>?> updateClient(String id, Map<String, dynamic> updates) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == id);
    if (index == -1) return null;

    final client = clients[index];

    // Normalizar teléfono si viene en updates
    if (updates.containsKey('phone')) {
      updates['phone'] = normalizePeruPhone(updates['phone'] as String? ?? '');
    }

    // Normalizar fecha de próximo seguimiento si viene en updates
    if (updates.containsKey('next_followup_date')) {
      final rawFollowup = updates['next_followup_date'] as String?;
      updates['next_followup_date'] = (rawFollowup != null && rawFollowup.trim().isNotEmpty)
          ? rawFollowup.trim()
          : null;
    }

    // Si viene current_device_id, validar unicidad
    if (updates.containsKey('current_device_id')) {
      final cleanDev = (updates['current_device_id'] as String? ?? '').trim().toUpperCase();
      if (cleanDev.isNotEmpty && cleanDev != 'PENDIENTE' && cleanDev != 'ML-0000') {
        final exists = clients.any((c) => c['id'] != id &&
            (c['current_device_id'] as String? ?? '').toUpperCase() == cleanDev);
        if (exists) {
          throw ArgumentError('El Hardware ID $cleanDev ya está asignado a otro cliente.');
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

  /// Sincronización atómica de datos reales reportados en el celular del cliente
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
      if (cleanDev != 'PENDIENTE' && cleanDev != (client['current_device_id'] as String? ?? '')) {
        final exists = clients.any((c) => c['id'] != clientId &&
            (c['current_device_id'] as String? ?? '').toUpperCase() == cleanDev &&
            cleanDev != 'PENDIENTE' && cleanDev != 'ML-0000');
        if (exists) {
          throw ArgumentError('El Hardware ID $cleanDev ya está asignado a otro cliente.');
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
      client['license_expires'] = DateTime.now().toUtc().add(Duration(days: trialDaysRemaining)).toIso8601String();
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

  /// Aplica el snapshot del estado real del cliente recibido mediante el protocolo MLS1 / .mlsync
  ///
  /// Valida anti-sobreescritura: si [ts] es anterior a [last_sync_at] y [forceOlder] != true,
  /// lanza [StaleSyncException] para responder HTTP 409 Conflict.
  /// Persiste: ai_reported_balance, ai_credits_used_total, uses_byok, installed_version,
  /// device_model, android_version, profiles_count, backup_drive_linked, backup_health_status,
  /// last_backup_at, last_sync_at (ISO UTC desde ts) y last_sync_payload.
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
    final syncDateTime = DateTime.fromMillisecondsSinceEpoch(tsEpoch, isUtc: true);

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

    // Persistir métricas operativas y técnicas reales
    if (payload.containsKey('ai')) {
      client['ai_reported_balance'] = (payload['ai'] as num).toInt();
    }
    if (payload.containsKey('aiu')) {
      client['ai_credits_used_total'] = (payload['aiu'] as num).toInt();
    }
    if (payload.containsKey('byok')) {
      client['uses_byok'] = payload['byok'] == true;
    }
    if (payload.containsKey('av') && (payload['av'] as String? ?? '').isNotEmpty) {
      client['installed_version'] = (payload['av'] as String).trim();
    }
    if (payload.containsKey('mod') && (payload['mod'] as String? ?? '').isNotEmpty) {
      client['device_model'] = (payload['mod'] as String).trim();
    }
    if (payload.containsKey('os') && (payload['os'] as String? ?? '').isNotEmpty) {
      client['android_version'] = (payload['os'] as String).trim();
    }
    if (payload.containsKey('pc')) {
      client['profiles_count'] = (payload['pc'] as num).toInt();
    }
    if (payload.containsKey('drv')) {
      client['backup_drive_linked'] = payload['drv'] == true;
    }
    if (payload.containsKey('bh') && (payload['bh'] as String? ?? '').isNotEmpty) {
      client['backup_health_status'] = (payload['bh'] as String).trim();
    }
    if (payload.containsKey('lb')) {
      client['last_backup_at'] = payload['lb'];
    }
    if (payload.containsKey('n')) {
      client['ultimo_nonce'] = (payload['n'] as num).toInt();
    }

    client['last_sync_at'] = syncDateTime.toIso8601String();
    client['last_sync_payload'] = {
      'version': payload['av'],
      'version_code': payload['bc'],
      'sqlite_schema': payload['db'],
      'ai_balance': payload['ai'],
      'ai_used': payload['aiu'],
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

  /// Reasignación de Dispositivo por Cambio o Pérdida de Celular
  /// Soporta [emitImmediately]: genera y firma en el mismo paso el nuevo token Ed25519 para el nuevo ANDROID_ID,
  /// preservando el 100% de los días restantes y la cuota IA sin duplicaciones (c = 0).
  /// Soporta [migrationScenario]: 'RESTORED_BACKUP' (y = 0 días extra) vs 'CLEAN_INSTALL' (transfiere días restantes).
  /// Soporta [newDeviceModel]: actualiza el modelo físico del equipo.
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

    // Actualizar modelo del teléfono si se suministró
    if (newDeviceModel != null && newDeviceModel.trim().isNotEmpty) {
      client['device_model'] = newDeviceModel.trim();
    }

    final isFreeMigration = feeAmount <= 0;
    final effectiveMethod = isFreeMigration ? 'Gratuito / Cortesía' : paymentMethod;
    final effectiveReason = reason?.trim().isNotEmpty == true
        ? reason!.trim()
        : (isFreeMigration
            ? 'Garantía de equipo / Traslado gratuito por cortesía'
            : 'Cambio o pérdida de teléfono');

    // Guardar en historial de hardware
    final history = (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();
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

    // Incrementar nonce
    final currentNonce = (client['next_nonce'] as num?)?.toInt() ?? 1;
    final migrationNonce = currentNonce + 1;
    client['next_nonce'] = migrationNonce;

    // Si se cobró tarifa técnica (> 0), registrar en libro de pagos; si fue gratuito, cero pagos ficticios
    String? generatedPaymentId;
    if (feeAmount > 0) {
      generatedPaymentId = 'MIG-${DateTime.now().millisecondsSinceEpoch}';
      final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
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
      final currentExp = currentExpStr != null ? DateTime.tryParse(currentExpStr) : null;
      final now = DateTime.now();

      int daysToAdd = 0;
      if (migrationScenario == 'RESTORED_BACKUP') {
        // En backup restaurado (Google Drive o .mlbg), SQLite ya tiene la fecha de expiración intacta.
        // Se emite y = 0 para reactivar la licencia sin sumar ni duplicar días.
        daysToAdd = 0;
      } else {
        // Instalación limpia desde cero: transfiere exactamente los días restantes
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

      // El token de migración lleva c = 0 para no inflar la cuota IA ya existente
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

      final codes = (client['generated_codes_history'] as List? ?? []).cast<Map<String, dynamic>>();
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

  /// Actualización del motivo u observación de una migración en el historial de hardware
  Future<Map<String, dynamic>?> updateDeviceHistoryReason({
    required String clientId,
    required int historyIndex,
    required String reason,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final history = (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();
    if (historyIndex < 0 || historyIndex >= history.length) return null;

    history[historyIndex]['reason'] = reason.trim();
    client['device_history'] = history;
    clients[index] = client;

    await saveClients(clients, reason: 'update_migration_reason_${clientId}_$historyIndex');
    return client;
  }

  /// Registro de Código Emitido con Renovación Acumulativa y Recargas de IA
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

    // Regla de Renovación Acumulativa vs Reinicio
    DateTime baseDate;
    final currentExpStr = client['license_expires'] as String?;
    final currentExp = currentExpStr != null ? DateTime.tryParse(currentExpStr) : null;

    if (!resetFromToday && currentExp != null && currentExp.isAfter(now) && client['license_type'] != 'TRIAL_VENCIDO') {
      baseDate = currentExp;
    } else {
      baseDate = now;
    }

    final basePlanCredits = (normPlan == 'RECARGA_IA_150')
        ? 150
        : (normPlan == 'BONO_IA_PERSONALIZADO' ? 0 : getCumulativeScansForPlan(normPlan));
    final totalCreditsToAdd = (normPlan == 'BONO_IA_PERSONALIZADO')
        ? aiExtraCredits
        : (basePlanCredits + aiExtraCredits);

    DateTime newExpiration;
    if (customExactExpiration != null) {
      newExpiration = customExactExpiration;
    } else if (normPlan == 'RECARGA_IA_150' || normPlan == 'BONO_IA_PERSONALIZADO') {
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

      final curReported = (client['ai_reported_balance'] as num?)?.toInt() ?? 50;
      client['ai_reported_balance'] = curReported + totalCreditsToAdd;
      client['ai_accumulated_credits'] = (client['ai_reported_balance'] as num).toInt();
    }

    // Descontar bono pendiente de emitir si se entregaron créditos adicionales
    if (aiExtraCredits > 0 || normPlan == 'BONO_IA_PERSONALIZADO') {
      final creditsDiscounted = (normPlan == 'BONO_IA_PERSONALIZADO') ? totalCreditsToAdd : aiExtraCredits;
      final currentPending = (client['ai_pending_bonus'] as num?)?.toInt() ?? 0;
      if (currentPending > 0) {
        final remainingPending = (currentPending - creditsDiscounted).clamp(0, 99999);
        client['ai_pending_bonus'] = remainingPending;
      }
    }

    final currentNonce = (client['next_nonce'] as num?)?.toInt() ?? 1;
    client['next_nonce'] = currentNonce + 1;

    if (updatesUntil != null) {
      client['updates_until'] = updatesUntil.toUtc().toIso8601String();
    }

    // Historial de pagos
    String? newPaymentId;
    if (paymentAmount > 0) {
      newPaymentId = 'PAY-${DateTime.now().millisecondsSinceEpoch}';
      final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
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

    // Historial de códigos
    final codes = (client['generated_codes_history'] as List? ?? []).cast<Map<String, dynamic>>();
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

  /// Marcar que el cliente actualizó su versión de app instalada con blindaje anti-degradación
  Future<Map<String, dynamic>?> markClientUpdated(String clientId, String versionName, {bool force = false}) async {
    final client = await getClientById(clientId);
    if (client == null) return null;
    final currentInstalled = client['installed_version'] as String? ?? '9.0.0';
    if (!force && compareSemVer(currentInstalled, versionName) > 0) {
      // Blindaje: No degradar a un cliente que ya tiene una versión superior instalada
      return client;
    }
    return updateClient(clientId, {'installed_version': versionName});
  }

  /// Registra la trazabilidad del APK enviado por WhatsApp
  Future<Map<String, dynamic>?> recordApkDispatched(String clientId, String version, {String? variant}) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return updateClient(clientId, {
      'last_apk_sent_version': version,
      'last_apk_sent_at': nowIso,
      if (variant != null) 'last_apk_sent_variant': variant,
    });
  }

  /// Eliminar un pago o anular transacción del historial de un cliente
  Future<Map<String, dynamic>?> deletePayment(String clientId, String paymentId) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
    payments.removeWhere((p) => p['id'] == paymentId);
    client['payment_history'] = payments;
    client['total_paid'] = payments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
    );

    clients[index] = client;
    await saveClients(clients, reason: 'delete_payment_${clientId}_$paymentId');
    return client;
  }

  /// Editar un pago existente en el historial del cliente (Plan Maestro 18 - Fase 4)
  Future<Map<String, dynamic>?> updatePayment(
      String clientId, String paymentId, Map<String, dynamic> paymentData) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments = (client['payment_history'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final pIndex = payments.indexWhere((p) => p['id'] == paymentId);
    if (pIndex == -1) return null;

    final oldPayment = payments[pIndex];

    // 1. Validación estricta de monto (número válido >= 0)
    if (paymentData.containsKey('amount')) {
      final rawAmt = paymentData['amount'];
      final num? parsedAmt = (rawAmt is num) ? rawAmt : num.tryParse(rawAmt.toString());
      if (parsedAmt == null || parsedAmt.isNaN || parsedAmt < 0) {
        throw ArgumentError('El monto del pago debe ser un número válido mayor o igual a cero.');
      }
      oldPayment['amount'] = parsedAmt.toDouble();
    }

    // 2. Validación estricta de fecha (formato ISO válido)
    if (paymentData.containsKey('date')) {
      final rawDate = (paymentData['date'] as String? ?? '').trim();
      if (rawDate.isNotEmpty) {
        try {
          DateTime.parse(rawDate);
          oldPayment['date'] = rawDate;
        } catch (_) {
          throw ArgumentError('La fecha del pago no tiene un formato ISO válido (YYYY-MM-DD).');
        }
      }
    }

    // 3. Concepto / Plan Oficial
    if (paymentData.containsKey('plan')) oldPayment['plan'] = paymentData['plan'];
    if (paymentData.containsKey('concept')) oldPayment['plan'] = paymentData['concept'];

    // 4. Medio de pago, referencia y notas
    if (paymentData.containsKey('method')) oldPayment['method'] = paymentData['method'];
    if (paymentData.containsKey('payment_method')) oldPayment['method'] = paymentData['payment_method'];
    if (paymentData.containsKey('reference')) oldPayment['reference'] = paymentData['reference'];
    if (paymentData.containsKey('notes')) oldPayment['notes'] = paymentData['notes'];

    // 5. Blindaje de comprobantes: ID y datos de comprobante emitido son estrictamente inmutables
    oldPayment['id'] = paymentId;
    // receipt_number, receipt_type y receipt_issued_at se preservan intactos en oldPayment

    // 6. Auditoría contable: timestamp de actualización en UTC
    oldPayment['updated_at'] = DateTime.now().toUtc().toIso8601String();

    payments[pIndex] = oldPayment;
    client['payment_history'] = payments;

    // 7. Recalcular automáticamente total_paid del cliente
    final totalPaid = payments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
    );
    client['total_paid'] = totalPaid;

    clients[index] = client;
    await saveClients(clients, reason: 'update_payment_${clientId}_$paymentId');
    return client;
  }

  /// Agregar un pago manual al historial del cliente
  Future<Map<String, dynamic>?> addManualPayment(String clientId, Map<String, dynamic> paymentData) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
    payments.add({
      'id': 'PAY-${DateTime.now().millisecondsSinceEpoch}',
      'date': paymentData['date'] ?? DateTime.now().toUtc().toIso8601String(),
      'amount': (paymentData['amount'] as num?)?.toDouble() ?? 0.0,
      'plan': paymentData['plan'] ?? 'PAGO_MANUAL',
      'method': paymentData['method'] ?? 'Efectivo',
      'reference': paymentData['reference'] ?? 'Registro Manual',
    });
    client['payment_history'] = payments;
    client['total_paid'] = payments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
    );

    clients[index] = client;
    await saveClients(clients, reason: 'add_manual_payment_$clientId');
    return client;
  }

  /// Alias de addManualPayment
  Future<Map<String, dynamic>?> addPayment(String clientId, Map<String, dynamic> paymentData) =>
      addManualPayment(clientId, paymentData);

  /// Emite o recupera la boleta (BOL-XXXX) o factura (FAC-XXXX) oficial de forma atómica e idempotente
  Future<Map<String, dynamic>?> issueOrGetPaymentReceipt({
    required String clientId,
    required String paymentId,
    required ConfigService configService,
    String? voucherType,
    String? customNote,
    String? invoiceRuc,
    String? invoiceBusinessName,
    String? invoiceFiscalAddress,
    bool? showIgvBreakdown,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments = (client['payment_history'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final pIndex = payments.indexWhere((p) => p['id'] == paymentId);
    if (pIndex == -1) return null;

    final payment = payments[pIndex];

    // Retrocompatibilidad con pagos legados que solo tienen receipt_number
    final legacyReceiptNum = payment['receipt_number'] as String?;
    if (legacyReceiptNum != null && legacyReceiptNum.trim().isNotEmpty) {
      if (legacyReceiptNum.startsWith('BOL-') && payment['receipt_bol_number'] == null) {
        payment['receipt_bol_number'] = legacyReceiptNum;
      } else if (legacyReceiptNum.startsWith('FAC-') && payment['receipt_fac_number'] == null) {
        payment['receipt_fac_number'] = legacyReceiptNum;
      }
    }

    // Determinar tipo de comprobante solicitado ('BOL' o 'FAC')
    final String requestedType = (voucherType ?? payment['receipt_type'] ?? 'BOL')
        .toString()
        .trim()
        .toUpperCase();
    final String vType = (requestedType == 'FAC') ? 'FAC' : 'BOL';

    // Verificar si ya existe correlativo para este tipo en este pago
    final String? existingTypedCorrelative = (vType == 'FAC')
        ? (payment['receipt_fac_number'] as String?)
        : (payment['receipt_bol_number'] as String?);

    final bool alreadyIssuedForType =
        existingTypedCorrelative != null && existingTypedCorrelative.trim().isNotEmpty;

    bool needsSave = false;

    if (!alreadyIssuedForType) {
      // Escanear todos los pagos de todos los clientes para hallar el correlativo máximo existente (Blindaje Anti-Colisión Plan 18.5)
      final prefix = '$vType-';
      int maxExisting = 0;
      for (final c in clients) {
        final pList = (c['payment_history'] as List? ?? []);
        for (final pItem in pList) {
          if (pItem is Map) {
            final rNum = pItem['receipt_number'] as String?;
            final rBol = pItem['receipt_bol_number'] as String?;
            final rFac = pItem['receipt_fac_number'] as String?;
            for (final cand in [rNum, rBol, rFac]) {
              if (cand != null && cand.trim().startsWith(prefix)) {
                final numPart = cand.trim().substring(prefix.length);
                final val = int.tryParse(numPart);
                if (val != null && val > maxExisting) {
                  maxExisting = val;
                }
              }
            }
          }
        }
      }

      // Asignar nuevo correlativo consumiendo contador del tipo solicitado
      final isSandbox = currentMode == 'sandbox';
      final configNum = await configService.consumeReceiptCorrelative(
        isSandbox: isSandbox,
        voucherType: vType,
      );
      final safeNum = (configNum <= maxExisting) ? (maxExisting + 1) : configNum;
      if (safeNum > configNum) {
        await configService.syncReceiptCorrelativeMin(
          isSandbox: isSandbox,
          voucherType: vType,
          nextValue: safeNum + 1,
        );
      }
      final formattedNum = '$vType-${safeNum.toString().padLeft(4, '0')}';
      if (vType == 'FAC') {
        payment['receipt_fac_number'] = formattedNum;
      } else {
        payment['receipt_bol_number'] = formattedNum;
      }
      payment['receipt_number'] = formattedNum;
      payment['receipt_type'] = vType;
      payment['receipt_issued_at'] ??= DateTime.now().toUtc().toIso8601String();
      needsSave = true;
    } else {
      // Reutilizar exactamente el correlativo previo de ese tipo (idempotencia pura)
      if (payment['receipt_number'] != existingTypedCorrelative || payment['receipt_type'] != vType) {
        payment['receipt_number'] = existingTypedCorrelative;
        payment['receipt_type'] = vType;
        needsSave = true;
      }
    }

    // Actualizar campos fiscales y notas opcionales si vienen definidos
    if (customNote != null && customNote.trim() != (payment['receipt_custom_note'] ?? '')) {
      payment['receipt_custom_note'] = customNote.trim();
      needsSave = true;
    }
    if (invoiceRuc != null && invoiceRuc.trim() != (payment['invoice_ruc'] ?? '')) {
      payment['invoice_ruc'] = invoiceRuc.trim();
      needsSave = true;
    }
    if (invoiceBusinessName != null && invoiceBusinessName.trim() != (payment['invoice_business_name'] ?? '')) {
      payment['invoice_business_name'] = invoiceBusinessName.trim();
      needsSave = true;
    }
    if (invoiceFiscalAddress != null && invoiceFiscalAddress.trim() != (payment['invoice_fiscal_address'] ?? '')) {
      payment['invoice_fiscal_address'] = invoiceFiscalAddress.trim();
      needsSave = true;
    }
    if (showIgvBreakdown != null && showIgvBreakdown != payment['show_igv_breakdown']) {
      payment['show_igv_breakdown'] = showIgvBreakdown;
      needsSave = true;
    }

    if (needsSave) {
      payments[pIndex] = payment;
      client['payment_history'] = payments;
      clients[index] = client;
      await saveClients(clients, reason: 'issue_receipt_${payment['receipt_number']}_$paymentId');
    }

    return {
      'ok': true,
      'receipt_number': payment['receipt_number'],
      'receipt_type': payment['receipt_type'] ?? vType,
      'voucher_type': payment['receipt_type'] ?? vType,
      'receipt_bol_number': payment['receipt_bol_number'],
      'receipt_fac_number': payment['receipt_fac_number'],
      'receipt_issued_at': payment['receipt_issued_at'],
      'invoice_ruc': payment['invoice_ruc'],
      'invoice_business_name': payment['invoice_business_name'],
      'invoice_fiscal_address': payment['invoice_fiscal_address'],
      'show_igv_breakdown': payment['show_igv_breakdown'] ?? false,
      'already_issued': alreadyIssuedForType,
      'payment': payment,
      'client': {
        'id': client['id'],
        'business_name': client['business_name'] ?? '',
        'owner_name': client['owner_name'] ?? '',
        'document_number': client['document_id'] ?? client['document_number'] ?? client['ruc_dni'] ?? '',
        'phone': client['phone'] ?? '',
        'current_device_id': client['current_device_id'] ?? '',
        'license_type': client['license_type'] ?? '',
        'license_status': client['license_status'] ?? '',
        'license_expires': client['license_expires'] ?? '',
      },
      'receipt_config': configService.receiptConfig,
    };
  }

  // =================== FINANZAS Y LIBRO CONTABLE ===================

  /// Obtiene la lista consolidada de cobros/transacciones financieras del entorno activo
  Future<List<Map<String, dynamic>>> getConsolidatedFinances() async {
    final clients = await getClients();
    final List<Map<String, dynamic>> result = [];
    for (final c in clients) {
      final payments = (c['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final p in payments) {
        result.add({
          'id': p['id'] ?? 'PAY-${p['date']}',
          'date': p['date'] ?? '',
          'amount': (p['amount'] as num?)?.toDouble() ?? 0.0,
          'plan': p['plan'] ?? '-',
          'method': p['method'] ?? '-',
          'reference': p['reference'] ?? '-',
          'receipt_number': p['receipt_number'] ?? '',
          'receipt_type': p['receipt_type'] ?? '',
          'receipt_bol_number': p['receipt_bol_number'] ?? '',
          'receipt_fac_number': p['receipt_fac_number'] ?? '',
          'receipt_issued_at': p['receipt_issued_at'] ?? '',
          'client_id': c['id'],
          'business_name': c['business_name'] ?? '',
          'owner_name': c['owner_name'] ?? '',
          'document_number': c['document_number'] ?? c['document_id'] ?? '',
          'phone': c['phone'] ?? '',
          'device_id': c['current_device_id'] ?? '',
          'notes': p['notes'] ?? '',
          'updated_at': p['updated_at'] ?? '',
        });
      }
    }
    result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return result;
  }

  /// Exporta el libro contable consolidado a CSV con BOM UTF-8
  Future<String> exportFinancesToCsv() async {
    final finances = await getConsolidatedFinances();
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // BOM UTF-8 para Excel
    buffer.writeln('FECHA,ID_CLIENTE,NEGOCIO,TITULAR,RUC_DNI,TELEFONO,DEVICE_ID,MONTO_PEN,PLAN,MEDIO_PAGO,REFERENCIA,TIPO_COMPROBANTE,N_COMPROBANTE');
    for (final f in finances) {
      final dateStr = (f['date'] as String).isNotEmpty ? (f['date'] as String).substring(0, 10) : '';
      final clientId = f['client_id'] ?? '';
      final biz = (f['business_name'] ?? '').toString().replaceAll('"', '""');
      final owner = (f['owner_name'] ?? '').toString().replaceAll('"', '""');
      final docId = (f['document_number'] ?? '').toString().replaceAll('"', '""');
      final phone = f['phone'] ?? '';
      final devId = f['device_id'] ?? '';
      final amount = ((f['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
      final plan = f['plan'] ?? '';
      final method = f['method'] ?? '';
      final ref = (f['reference'] ?? '').toString().replaceAll('"', '""');
      final recNum = (f['receipt_number'] as String? ?? '').trim();
      final recType = (f['receipt_type'] as String? ?? '').trim().toUpperCase();
      final tipoComp = recType.isNotEmpty ? recType : (recNum.startsWith('FAC') ? 'FAC' : (recNum.startsWith('BOL') ? 'BOL' : ''));
      buffer.writeln('$dateStr,$clientId,"$biz","$owner","$docId",$phone,$devId,$amount,$plan,"$method","$ref","$tipoComp","$recNum"');
    }
    return buffer.toString();
  }

  // =================== CENTRO DE GESTIÓN DE RESPALDOS (BACKUPS) ===================

  /// Lista los respaldos físicos en disco duro (carpeta backups/)
  Future<List<Map<String, dynamic>>> listBackups() async {
    final dir = Directory(backupDir);
    if (!await dir.exists()) return [];

    final List<Map<String, dynamic>> result = [];
    final entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.last;
        final isProd = name.startsWith('prod_') || name.contains('_prod_');
        final isSandbox = name.startsWith('sandbox_') || name.contains('_sandbox_');
        final mode = isProd ? 'prod' : (isSandbox ? 'sandbox' : 'global');

        result.add({
          'filename': name,
          'path': entity.path,
          'size_kb': (stat.size / 1024).toStringAsFixed(1),
          'size_bytes': stat.size,
          'modified_at': stat.modified.toUtc().toIso8601String(),
          'mode': mode,
        });
      }
    }
    result.sort((a, b) => (b['modified_at'] as String).compareTo(a['modified_at'] as String));
    return result;
  }

  /// Crea un snapshot manual inmediato en disco
  Future<Map<String, dynamic>> createManualBackup() async {
    final now = DateTime.now();
    final timestamp = now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final filenameClients = '${_mode}_clients_manual_$timestamp.json';
    final filenameReleases = '${_mode}_releases_manual_$timestamp.json';

    final destClients = File('$backupDir/$filenameClients');
    final destReleases = File('$backupDir/$filenameReleases');

    if (await _clientsFile.exists()) {
      await _clientsFile.copy(destClients.path);
    }
    if (await _releasesFile.exists()) {
      await _releasesFile.copy(destReleases.path);
    }

    return {
      'ok': true,
      'timestamp': now.toIso8601String(),
      'mode': _mode,
      'files': [filenameClients, filenameReleases],
      'message': 'Snapshot manual creado en disco exitosamente.',
    };
  }

  /// Restaura la base de datos a partir de un archivo de backup
  Future<bool> restoreFromBackup(String filename) async {
    final file = File('$backupDir/$filename');
    if (!await file.exists()) return false;

    // Crear snapshot de seguridad del estado actual antes de sobrescribir
    await _createSnapshot('before_restore_${filename.replaceAll('.json', '')}');

    if (filename.contains('clients')) {
      await file.copy(_clientsFile.path);
      return true;
    } else if (filename.contains('releases')) {
      await file.copy(_releasesFile.path);
      return true;
    }
    return false;
  }

  // =================== LANZAMIENTOS (RELEASES) Y SEMVER ===================

  /// Comparador Semver numérico determinista (ignora prefijos 'v' y sufijos '+build')
  static int compareSemVer(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null || a.trim().isEmpty) return -1;
    if (b == null || b.trim().isEmpty) return 1;

    final pa = _parseSemVerParts(a);
    final pb = _parseSemVerParts(b);

    if (pa.major != pb.major) return pa.major.compareTo(pb.major);
    if (pa.minor != pb.minor) return pa.minor.compareTo(pb.minor);
    if (pa.patch != pb.patch) return pa.patch.compareTo(pb.patch);

    if (pa.buildCode != null && pb.buildCode != null && pa.buildCode != pb.buildCode) {
      return pa.buildCode!.compareTo(pb.buildCode!);
    }

    return 0;
  }

  static _SemVerParts _parseSemVerParts(String s) {
    final clean = s.trim().replaceAll(RegExp(r'^[vV]'), '');
    final withoutSuffix = clean.split('-')[0];
    final buildSplit = withoutSuffix.split('+');
    final mainPart = buildSplit[0];
    final buildCode = buildSplit.length > 1 ? int.tryParse(buildSplit[1]) : null;

    final segments = mainPart.split('.');
    final major = segments.isNotEmpty ? (int.tryParse(segments[0]) ?? 0) : 0;
    final minor = segments.length > 1 ? (int.tryParse(segments[1]) ?? 0) : 0;
    final patch = segments.length > 2 ? (int.tryParse(segments[2]) ?? 0) : 0;

    return _SemVerParts(major: major, minor: minor, patch: patch, buildCode: buildCode);
  }

  Future<List<Map<String, dynamic>>> getReleases() async {
    if (!await _releasesFile.exists()) return [];
    final content = await _releasesFile.readAsString();
    final list = jsonDecode(content) as List;
    final releases = list.cast<Map<String, dynamic>>();

    for (final r in releases) {
      final p = r['apk_file_path'] as String?;
      final u = r['universal_apk'] as Map<String, dynamic>?;
      final a = r['arm64_apk'] as Map<String, dynamic>?;

      bool exists = false;
      if (p != null && p.isNotEmpty && File(p).existsSync()) {
        exists = true;
      } else if (u != null && (u['file_path'] as String? ?? '').isNotEmpty && File(u['file_path'] as String).existsSync()) {
        exists = true;
      } else if (a != null && (a['file_path'] as String? ?? '').isNotEmpty && File(a['file_path'] as String).existsSync()) {
        exists = true;
      }
      r['file_exists'] = exists;
    }

    return releases;
  }

  Future<void> saveReleases(List<Map<String, dynamic>> releases, {String reason = 'update_releases'}) async {
    await _releasesFile.writeAsString(const JsonEncoder.withIndent('  ').convert(releases));
    await _createSnapshot(reason);
    if (_mode == 'prod' && onProductionDataChanged != null) {
      try {
        await onProductionDataChanged!();
      } catch (e) {
        stderr.writeln('Warning: Error al ejecutar onProductionDataChanged tras saveReleases: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> getReleaseByVersion(String versionName) async {
    final releases = await getReleases();
    try {
      return releases.firstWhere((r) => r['version_name'] == versionName);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createRelease(Map<String, dynamic> releaseData) async {
    final releases = await getReleases();
    final versionName = releaseData['version_name'] ?? '9.24.0';

    // Eliminar duplicado si ya existía para actualizar
    releases.removeWhere((r) => r['version_name'] == versionName);

    final newRelease = {
      'version_name': versionName,
      'version_code': (releaseData['version_code'] as num?)?.toInt() ?? 82,
      'db_schema_version': (releaseData['db_schema_version'] as num?)?.toInt() ?? 36,
      'release_date': releaseData['release_date'] ?? DateTime.now().toUtc().toIso8601String(),
      'type': releaseData['type'] == 'HOTFIX' ? 'HOTFIX' : 'FEATURE_RELEASE',
      'apk_file_path': releaseData['apk_file_path'] ?? '',
      'apk_download_url': releaseData['apk_download_url'] ?? '',
      'apk_sha256': (releaseData['apk_sha256'] ?? '').toString().toLowerCase(),
      'file_size_mb': releaseData['file_size_mb'] ?? '',
      'changelog': releaseData['changelog'] ?? '',
      'internal_notes': releaseData['internal_notes'] ?? '',
      'min_required_version': releaseData['min_required_version'] ?? '9.0.0',
      'signature_verified': releaseData['signature_verified'],
      'signature_status': releaseData['signature_status'] ?? 'TOOL_UNAVAILABLE',
      'signer_sha256': releaseData['signer_sha256'],
      'signer_dn': releaseData['signer_dn'],
      if (releaseData['universal_apk'] != null)
        'universal_apk': releaseData['universal_apk'],
      if (releaseData['arm64_apk'] != null)
        'arm64_apk': releaseData['arm64_apk'],
    };

    releases.insert(0, newRelease); // Más recientes primero
    await saveReleases(releases, reason: 'create_release_${newRelease['version_name']}');
    return newRelease;
  }

  Future<Map<String, dynamic>?> updateRelease(String versionName, Map<String, dynamic> updates) async {
    final releases = await getReleases();
    final index = releases.indexWhere((r) => r['version_name'] == versionName);
    if (index == -1) return null;

    final release = releases[index];
    updates.forEach((key, value) {
      if (key != 'version_name') {
        if (key == 'version_code' || key == 'db_schema_version') {
          if (value is num) {
            release[key] = value.toInt();
          } else if (value is String) {
            release[key] = int.tryParse(value) ?? release[key];
          } else {
            release[key] = value;
          }
        } else {
          release[key] = value;
        }
      }
    });

    releases[index] = release;
    await saveReleases(releases, reason: 'update_release_$versionName');
    return release;
  }

  Future<bool> deleteRelease(String versionName) async {
    final releases = await getReleases();
    final index = releases.indexWhere((r) => r['version_name'] == versionName);
    if (index == -1) return false;

    final rel = releases.removeAt(index);

    // Si tiene archivo APK en disco, eliminarlo (principal y variantes)
    final pathsToDelete = [
      rel['apk_file_path'] as String?,
      (rel['universal_apk'] as Map<String, dynamic>?)?['file_path'] as String?,
      (rel['arm64_apk'] as Map<String, dynamic>?)?['file_path'] as String?,
    ];

    for (final p in pathsToDelete) {
      if (p != null && p.isNotEmpty) {
        final f = File(p);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }

    await saveReleases(releases, reason: 'delete_release_$versionName');
    return true;
  }

  /// Matriz Inteligente de Distribución de Versiones con Semver Real
  Future<List<Map<String, dynamic>>> getUpdateDistributionMatrix() async {
    final releases = await getReleases();
    if (releases.isEmpty) return [];

    final latestRelease = releases.first;
    final latestVersion = latestRelease['version_name'] as String? ?? '9.0.0';
    final clients = await getClients();
    final now = DateTime.now();

    final List<Map<String, dynamic>> matrix = [];

    for (final client in clients) {
      final installedVersion = (client['installed_version'] as String? ?? '9.0.0');
      final cmp = compareSemVer(installedVersion, latestVersion);
      final lastSentVersion = client['last_apk_sent_version'] as String?;
      final isSentForLatest = lastSentVersion != null && lastSentVersion == latestVersion;

      final licenseType = (client['license_type'] as String? ?? 'MENSUAL').toUpperCase();
      final situation = (client['situation'] as String? ?? '').toUpperCase();
      final isProspect = situation == 'PROSPECTO' || licenseType == 'PROSPECTO';
      final isPerpetual = licenseType == 'PERPETUO_LIBERADO' || licenseType == 'PERPETUO';

      final expiresStr = client['license_expires'] as String?;
      final expires = expiresStr != null ? DateTime.tryParse(expiresStr) : null;
      final isSubscriptionActive = expires != null && expires.isAfter(now);

      final updatesUntilStr = client['updates_until'] as String?;
      final updatesUntil = updatesUntilStr != null ? DateTime.tryParse(updatesUntilStr) : null;
      final hasActiveUpdatePass = updatesUntil != null && updatesUntil.isAfter(now);

      String updateStatus;
      bool isUpToDate;
      bool canDowngrade = false;
      bool isEligibleForFree = false;
      String eligibilityReason = '';
      String requiredAction = 'Ninguna (Al día)';

      if (isProspect) {
        updateStatus = 'PROSPECT';
        isUpToDate = false;
        isEligibleForFree = false;
        eligibilityReason = 'Prospecto comercial sin app vinculada todavía.';
        requiredAction = 'Vincular y Activar App';
      } else if (cmp > 0) {
        // Versión estrictamente superior instalada (jamás degradable)
        updateStatus = 'AHEAD';
        isUpToDate = true;
        isEligibleForFree = true;
        eligibilityReason = 'Tiene instalada una versión superior a la publicada en este catálogo.';
        requiredAction = 'Versión Superior (Al día)';
        canDowngrade = false;
      } else if (cmp == 0) {
        // Al día
        updateStatus = 'UP_TO_DATE';
        isUpToDate = true;
        isEligibleForFree = true;
        eligibilityReason = 'Ya tiene instalada la última versión.';
        requiredAction = 'Al día';
      } else {
        // cmp < 0 (Versión instalada inferior a la última disponible)
        if (isSentForLatest) {
          updateStatus = 'SENT';
          isUpToDate = false;
          isEligibleForFree = isSubscriptionActive || hasActiveUpdatePass || latestRelease['type'] == 'HOTFIX';
          final sentDate = client['last_apk_sent_at'] != null ? client['last_apk_sent_at'].toString().substring(0, 10) : '';
          eligibilityReason = 'APK ya enviado${sentDate.isNotEmpty ? " el $sentDate" : ""}. Pendiente de instalación por el cliente.';
          requiredAction = 'APK Enviado (Esperando instalación)';
        } else {
          updateStatus = 'OUTDATED';
          isUpToDate = false;
          if (latestRelease['type'] == 'HOTFIX') {
            isEligibleForFree = true;
            eligibilityReason = 'Hotfix / Parche de estabilidad (Gratuito vitalicio).';
            requiredAction = 'Enviar Actualización Gratuita';
          } else {
            // FEATURE_RELEASE
            if (isPerpetual) {
              if (hasActiveUpdatePass) {
                isEligibleForFree = true;
                eligibilityReason = 'Licencia Perpetua con Pase de Actualizaciones vigente.';
                requiredAction = 'Enviar Nueva Versión';
              } else {
                isEligibleForFree = false;
                eligibilityReason = 'Licencia Perpetua: Periodo de 1 año de updates vencido.';
                requiredAction = 'Ofrecer Pase Anual de Updates (S/ 150.00)';
              }
            } else {
              if (isSubscriptionActive) {
                isEligibleForFree = true;
                eligibilityReason = 'Suscripción activa incluye todas las actualizaciones.';
                requiredAction = 'Enviar Nueva Versión';
              } else {
                isEligibleForFree = false;
                eligibilityReason = 'Suscripción vencida. Requiere renovar el plan.';
                requiredAction = 'Renovar Suscripción para Actualizar';
              }
            }
          }
        }
      }

      matrix.add({
        'client_id': client['id'],
        'business_name': client['business_name'],
        'owner_name': client['owner_name'],
        'phone': client['phone'],
        'device_id': client['current_device_id'],
        'installed_version': installedVersion,
        'latest_version': latestVersion,
        'release_type': latestRelease['type'],
        'update_status': updateStatus,
        'can_downgrade': canDowngrade,
        'is_up_to_date': isUpToDate,
        'is_eligible_for_free': isEligibleForFree,
        'eligibility_reason': eligibilityReason,
        'required_action': requiredAction,
        'download_url': latestRelease['apk_download_url'],
        'changelog': latestRelease['changelog'],
        'has_local_apk': (latestRelease['apk_file_path'] as String? ?? '').isNotEmpty ||
            latestRelease['universal_apk'] != null ||
            latestRelease['arm64_apk'] != null,
        'last_apk_sent_version': client['last_apk_sent_version'],
        'last_apk_sent_at': client['last_apk_sent_at'],
        'universal_apk': latestRelease['universal_apk'],
        'arm64_apk': latestRelease['arm64_apk'],
        'has_universal_apk': latestRelease['universal_apk'] != null,
        'has_arm64_apk': latestRelease['arm64_apk'] != null,
      });
    }

    return matrix;
  }

  /// Obtiene el historial detallado de pagos, códigos y cambios de equipo de un cliente
  Future<Map<String, dynamic>?> getClientHistory(String id) async {
    final client = await getClientById(id);
    if (client == null) return null;

    final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
    final codes = (client['generated_codes_history'] as List? ?? []).cast<Map<String, dynamic>>();
    final devices = (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();

    double totalPaid = 0.0;
    for (final p in payments) {
      totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'client': client,
      'total_paid': totalPaid,
      'payments': payments,
      'codes': codes,
      'device_history': devices,
      'hardware': devices,
    };
  }

  /// Exportación de Clientes a formato CSV con BOM UTF-8 para apertura directa en Excel de Windows
  Future<String> exportClientsToCsv() async {
    final clients = await getClients();
    final buffer = StringBuffer();
    // Prefijo BOM UTF-8 (\uFEFF) para evitar corrupción de caracteres en Microsoft Excel Windows
    buffer.write('\uFEFF');
    buffer.writeln(
      'ID,Negocio,Propietario,RUC/DNI,Telefono,DeviceID ML-XXXX,Version Instalada,Tipo Licencia,Estado,Fecha Expiracion,Updates Hasta,Creditos IA Extra,Total Pagado (S/),Ultimo Codigo,Notas',
    );

    for (final c in clients) {
      final payments = (c['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      double totalPaid = 0.0;
      for (final p in payments) {
        totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
      }
      final codes = (c['generated_codes_history'] as List? ?? []).cast<Map<String, dynamic>>();
      final lastCode = codes.isNotEmpty ? codes.last['token'] ?? '' : '';

      buffer.writeln(
        '"${c['id']}","${c['business_name']}","${c['owner_name']}","${c['document_id']}","${c['phone']}","${c['current_device_id']}","${c['installed_version']}","${c['license_type']}","${c['license_status']}","${c['license_expires']}","${c['updates_until']}","${c['ai_extra_credits']}","S/ ${totalPaid.toStringAsFixed(2)}","${lastCode}","${(c['notes'] ?? '').replaceAll('"', '""')}"',
      );
    }
    return buffer.toString();
  }

  // =================== DATOS INICIALES DEMO (SANDBOX) ===================

  List<Map<String, dynamic>> _getInitialSandboxClients() {
    return [
      {
        'id': 'CLI-001',
        'business_name': 'Comercial & Librería El Estudiante',
        'owner_name': 'Carlos Mendoza Quispe',
        'document_id': '10458796321',
        'phone': '+51987654321',
        'current_device_id': 'ML-9K4B',
        'device_history': [],
        'installed_version': '9.34.0',
        'license_type': 'MENSUAL',
        'license_status': 'ACTIVA',
        'license_expires': '2027-01-13T23:59:59.000Z',
        'next_nonce': 2,
        'updates_until': '2026-12-14T23:59:59.000Z',
        'ai_extra_credits': 50,
        'ai_accumulated_credits': 50,
        'notes': 'Cliente puntual en Piura. Usa Yape.',
        'created_at': '2026-11-01T10:00:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-101',
            'date': '2026-11-14T10:00:00.000Z',
            'amount': 35.0,
            'plan': 'MENSUAL',
            'method': 'Yape',
            'reference': 'Op. 948102',
          }
        ],
        'generated_codes_history': [],
      },
      {
        'id': 'CLI-002',
        'business_name': 'Bazar Escolar Las Palmeras',
        'owner_name': 'Rosa María Benites',
        'document_id': '20601234567',
        'phone': '+51976543210',
        'current_device_id': 'ML-3X8P',
        'device_history': [],
        'installed_version': '9.34.0',
        'license_type': 'TRIMESTRAL',
        'license_status': 'POR_VENCER',
        'license_expires': DateTime.now().add(const Duration(days: 4)).toUtc().toIso8601String(),
        'next_nonce': 2,
        'updates_until': '2027-02-14T23:59:59.000Z',
        'ai_extra_credits': 230,
        'ai_accumulated_credits': 230,
        'notes': 'Recordar cobranza preventiva antes del vencimiento.',
        'created_at': '2026-10-15T09:30:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-102',
            'date': '2026-10-15T09:30:00.000Z',
            'amount': 90.0,
            'plan': 'TRIMESTRAL',
            'method': 'Plin',
            'reference': 'Op. 551294',
          }
        ],
        'generated_codes_history': [],
      },
      {
        'id': 'CLI-003',
        'business_name': 'Distribuidora & Útiles San Martín',
        'owner_name': 'Jorge Luis Ramos',
        'document_id': '10789456123',
        'phone': '+51954321098',
        'current_device_id': 'ML-7W2R',
        'device_history': [],
        'installed_version': '9.34.0',
        'license_type': 'PERPETUO_LIBERADO',
        'license_status': 'PERPETUA',
        'license_expires': '2299-12-31T23:59:59.000Z',
        'next_nonce': 2,
        'updates_until': DateTime.now().add(const Duration(days: 280)).toUtc().toIso8601String(),
        'ai_extra_credits': 350,
        'ai_accumulated_credits': 350,
        'notes': 'Licencia Perpetua de por vida con updates vigentes.',
        'created_at': '2026-09-01T11:00:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-103',
            'date': '2026-09-01T11:00:00.000Z',
            'amount': 850.0,
            'plan': 'PERPETUO_LIBERADO',
            'method': 'BCP',
            'reference': 'Op. 112233',
          }
        ],
        'generated_codes_history': [],
      },
      {
        'id': 'CLI-004',
        'business_name': 'Papelería & Novedades Huascarán',
        'owner_name': 'Carmen Luz Huamán',
        'document_id': '10321654987',
        'phone': '+51965432187',
        'current_device_id': 'ML-2V5M',
        'device_history': [],
        'installed_version': '9.29.0',
        'license_type': 'MENSUAL',
        'license_status': 'BLOQUEO_ESTRICTO',
        'license_expires': DateTime.now().subtract(const Duration(days: 12)).toUtc().toIso8601String(),
        'next_nonce': 2,
        'updates_until': '2026-10-01T23:59:59.000Z',
        'ai_extra_credits': 50,
        'ai_accumulated_credits': 50,
        'notes': 'Licencia vencida hace 12 días. Enviar oferta de reactivación.',
        'created_at': '2026-08-10T14:00:00.000Z',
        'payment_history': [
          {
            'id': 'PAY-104',
            'date': '2026-08-10T14:00:00.000Z',
            'amount': 35.0,
            'plan': 'MENSUAL',
            'method': 'Yape',
            'reference': 'Op. 887766',
          }
        ],
        'generated_codes_history': [],
      },
    ];
  }

  List<Map<String, dynamic>> _getInitialSandboxReleases() {
    return [
      {
        'version_name': '9.34.0',
        'version_code': 78,
        'db_schema_version': 36,
        'release_date': '2026-11-20T10:00:00.000Z',
        'type': 'FEATURE_RELEASE',
        'apk_file_path': '',
        'apk_download_url': 'https://drive.google.com/file/d/mochilalista-v9.34.0/view',
        'apk_sha256': '4a5b6c7d8e9f0123456789abcdef0123456789abcdef0123456789abcdef0123',
        'file_size_mb': '28.40 MB',
        'changelog': '• Activación 100% Offline con Hardware ID (Settings.Secure.ANDROID_ID) y EULA oficial.\n• Cuota IA 100% Acumulativa sin reseteo mensual y arquitectura Multi-Perfil con bolsa compartida.\n• Bóveda de Claves BYOK (Google Gemini) y Respaldo Blindado en Google Drive (.mlbg).\n• Esquema SQLite v36 con sincronización de perfiles y trazabilidad de inventario.',
        'min_required_version': '9.0.0',
      },
      {
        'version_name': '9.29.0',
        'version_code': 73,
        'db_schema_version': 35,
        'release_date': '2026-11-01T15:00:00.000Z',
        'type': 'HOTFIX',
        'apk_file_path': '',
        'apk_download_url': 'https://drive.google.com/file/d/mochilalista-v9.29.0/view',
        'apk_sha256': '1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890',
        'file_size_mb': '26.85 MB',
        'changelog': '• Parche correctivo: Optimización de impresión Bluetooth térmica de 80mm.\n• Corrección menor en cálculo de vuelto en ventas mixtas.',
        'min_required_version': '9.0.0',
      },
    ];
  }
}

class _SemVerParts {
  final int major;
  final int minor;
  final int patch;
  final int? buildCode;

  const _SemVerParts({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildCode,
  });
}

