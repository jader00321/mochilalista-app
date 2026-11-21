import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'license_signer.dart';

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
    final reportedAi = (clientData['ai_reported_balance'] as num?)?.toInt() ?? (isProspect ? 0 : 50);
    final pendingBonusAi = (clientData['ai_pending_bonus'] as num?)?.toInt() ?? 0;
    final baseAi = isProspect ? 0 : getCumulativeScansForPlan(plan);
    final userExtraAi = (clientData['ai_extra_credits'] as num?)?.toInt() ?? pendingBonusAi;
    final totalAi = baseAi + userExtraAi;

    final phone = normalizePeruPhone(clientData['phone'] as String? ?? '');

    final newClient = {
      'id': id,
      'business_name': clientData['business_name'] ?? 'Negocio Sin Nombre',
      'owner_name': clientData['owner_name'] ?? 'Propietario',
      'document_id': clientData['document_id'] ?? '',
      'phone': phone,
      'current_device_id': rawDeviceId,
      'device_history': [],
      'installed_version': clientData['installed_version'] ?? '9.34.0',
      'license_type': plan,
      'license_status': isProspect
          ? 'PROSPECTO'
          : (plan.contains('PERPETU') ? 'PERPETUA' : 'ACTIVA'),
      'license_expires': expiresAt,
      'expected_subscription_date': clientData['expected_subscription_date'],
      'trial_days_remaining': (!isProspect && plan == 'TRIAL') ? trialDays : null,
      'next_nonce': 1,
      'updates_until': updatesUntil,
      'ai_reported_balance': reportedAi,
      'ai_pending_bonus': pendingBonusAi,
      'ai_extra_credits': totalAi,
      'ai_accumulated_credits': totalAi,
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
  Future<Map<String, dynamic>?> migrateDevice({
    required String clientId,
    required String newDeviceId,
    required double feeAmount,
    required String paymentMethod,
    String? reason,
    bool emitImmediately = false,
    LicenseSigner? signer,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final oldDeviceId = client['current_device_id'] as String;
    final cleanNewId = newDeviceId.trim().toUpperCase();

    // Guardar en historial de hardware
    final history = (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();
    history.add({
      'old_device_id': oldDeviceId,
      'new_device_id': cleanNewId,
      'migrated_at': DateTime.now().toUtc().toIso8601String(),
      'fee_charged': feeAmount,
      'payment_method': paymentMethod,
      'reason': reason ?? 'Cambio o pérdida de teléfono',
    });
    client['device_history'] = history;
    client['current_device_id'] = cleanNewId;

    // Incrementar nonce
    final currentNonce = (client['next_nonce'] as num?)?.toInt() ?? 1;
    final migrationNonce = currentNonce + 1;
    client['next_nonce'] = migrationNonce;

    // Si se cobró tarifa técnica, registrar en pagos
    if (feeAmount > 0) {
      final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      payments.add({
        'id': 'MIG-${DateTime.now().millisecondsSinceEpoch}',
        'date': DateTime.now().toUtc().toIso8601String(),
        'amount': feeAmount,
        'plan': 'SERVICIO_MIGRACION',
        'method': paymentMethod,
        'reference': 'Migración de $oldDeviceId a $cleanNewId',
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

      int daysToAdd = 30;
      if (isPerpetual) {
        daysToAdd = 99999;
      } else if (currentExp != null && currentExp.isAfter(now)) {
        daysToAdd = math.max(1, currentExp.difference(now).inDays);
      }

      DateTime? updatesUntil;
      if (client['updates_until'] != null) {
        updatesUntil = DateTime.tryParse(client['updates_until']);
      }

      // El token de migración lleva c = 0 para no inflar la cuota IA ya restaurada
      emittedToken = await signer.generateLicenseToken(
        deviceFingerprint: cleanNewId,
        plan: plan,
        daysToAdd: daysToAdd,
        nonce: migrationNonce,
        updatesUntil: updatesUntil,
        businessTag: client['business_name'] as String?,
        aiExtraCredits: 0,
      );

      final codes = (client['generated_codes_history'] as List? ?? []).cast<Map<String, dynamic>>();
      codes.add({
        'token': emittedToken,
        'plan': plan,
        'days_added': daysToAdd,
        'emitted_at': now.toUtc().toIso8601String(),
        'device_id': cleanNewId,
        'expires_result': client['license_expires'],
        'is_migration_token': true,
        'base_ai_credits': 0,
        'bonus_ai_credits': 0,
        'total_ai_credited': 0,
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
      };
    }

    clients[index] = client;
    await saveClients(clients, reason: 'migrate_device_$clientId');

    if (emittedToken != null) {
      return {
        ...client,
        'emitted_migration_token': emittedToken,
        'migration_token_info': migrationTokenInfo,
      };
    }
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

    final basePlanCredits = normPlan == 'RECARGA_IA_150' ? 150 : getCumulativeScansForPlan(normPlan);
    final totalCreditsToAdd = basePlanCredits + aiExtraCredits;

    DateTime newExpiration;
    if (customExactExpiration != null) {
      newExpiration = customExactExpiration;
    } else if (normPlan == 'RECARGA_IA_150') {
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
      client['ai_accumulated_credits'] = updatedCredits;
    }

    // Descontar bono pendiente de emitir si se entregaron créditos adicionales
    if (aiExtraCredits > 0) {
      final currentPending = (client['ai_pending_bonus'] as num?)?.toInt() ?? 0;
      if (currentPending > 0) {
        final remainingPending = (currentPending - aiExtraCredits).clamp(0, 99999);
        client['ai_pending_bonus'] = remainingPending;
      }
    }

    client['next_nonce'] = ((client['next_nonce'] as num?)?.toInt() ?? 1) + 1;

    if (updatesUntil != null) {
      client['updates_until'] = updatesUntil.toUtc().toIso8601String();
    }

    // Historial de códigos
    final codes = (client['generated_codes_history'] as List? ?? []).cast<Map<String, dynamic>>();
    codes.add({
      'token': token,
      'plan': normPlan,
      'days_added': daysToAdd,
      'emitted_at': now.toUtc().toIso8601String(),
      'device_id': client['current_device_id'],
      'expires_result': newExpiration.toUtc().toIso8601String(),
      'base_ai_credits': basePlanCredits,
      'bonus_ai_credits': aiExtraCredits,
      'total_ai_credited': totalCreditsToAdd,
    });
    client['generated_codes_history'] = codes;

    // Historial de pagos
    if (paymentAmount > 0) {
      final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      payments.add({
        'id': 'PAY-${DateTime.now().millisecondsSinceEpoch}',
        'date': now.toUtc().toIso8601String(),
        'amount': paymentAmount,
        'plan': normPlan,
        'method': paymentMethod,
        'reference': paymentRef,
      });
      client['payment_history'] = payments;
    }

    clients[index] = client;
    await saveClients(clients, reason: 'emit_code_$clientId');
    return client;
  }

  /// Marcar que el cliente actualizó su versión de app instalada
  Future<Map<String, dynamic>?> markClientUpdated(String clientId, String versionName) async {
    return updateClient(clientId, {'installed_version': versionName});
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

    clients[index] = client;
    await saveClients(clients, reason: 'delete_payment_${clientId}_$paymentId');
    return client;
  }

  /// Editar un pago existente en el historial del cliente
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
    if (paymentData.containsKey('date')) oldPayment['date'] = paymentData['date'];
    if (paymentData.containsKey('amount')) {
      oldPayment['amount'] = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
    }
    if (paymentData.containsKey('plan')) oldPayment['plan'] = paymentData['plan'];
    if (paymentData.containsKey('concept')) oldPayment['plan'] = paymentData['concept'];
    if (paymentData.containsKey('method')) oldPayment['method'] = paymentData['method'];
    if (paymentData.containsKey('payment_method')) oldPayment['method'] = paymentData['payment_method'];
    if (paymentData.containsKey('reference')) oldPayment['reference'] = paymentData['reference'];
    if (paymentData.containsKey('notes')) oldPayment['notes'] = paymentData['notes'];

    payments[pIndex] = oldPayment;
    client['payment_history'] = payments;
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

    clients[index] = client;
    await saveClients(clients, reason: 'add_manual_payment_$clientId');
    return client;
  }

  /// Alias de addManualPayment
  Future<Map<String, dynamic>?> addPayment(String clientId, Map<String, dynamic> paymentData) =>
      addManualPayment(clientId, paymentData);

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
          'client_id': c['id'],
          'business_name': c['business_name'] ?? '',
          'owner_name': c['owner_name'] ?? '',
          'phone': c['phone'] ?? '',
          'device_id': c['current_device_id'] ?? '',
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
    buffer.writeln('FECHA,ID_CLIENTE,NEGOCIO,TITULAR,TELEFONO,DEVICE_ID,MONTO_PEN,PLAN,MEDIO_PAGO,REFERENCIA');
    for (final f in finances) {
      final dateStr = (f['date'] as String).isNotEmpty ? (f['date'] as String).substring(0, 10) : '';
      final clientId = f['client_id'] ?? '';
      final biz = (f['business_name'] ?? '').toString().replaceAll('"', '""');
      final owner = (f['owner_name'] ?? '').toString().replaceAll('"', '""');
      final phone = f['phone'] ?? '';
      final devId = f['device_id'] ?? '';
      final amount = ((f['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
      final plan = f['plan'] ?? '';
      final method = f['method'] ?? '';
      final ref = (f['reference'] ?? '').toString().replaceAll('"', '""');
      buffer.writeln('$dateStr,$clientId,"$biz","$owner",$phone,$devId,$amount,$plan,"$method","$ref"');
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

  // =================== LANZAMIENTOS (RELEASES) ===================

  Future<List<Map<String, dynamic>>> getReleases() async {
    if (!await _releasesFile.exists()) return [];
    final content = await _releasesFile.readAsString();
    final list = jsonDecode(content) as List;
    return list.cast<Map<String, dynamic>>();
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
      'version_code': (releaseData['version_code'] as num?)?.toInt() ?? 24,
      'db_schema_version': (releaseData['db_schema_version'] as num?)?.toInt() ?? 35,
      'release_date': DateTime.now().toUtc().toIso8601String(),
      'type': releaseData['type'] == 'HOTFIX' ? 'HOTFIX' : 'FEATURE_RELEASE',
      'apk_file_path': releaseData['apk_file_path'] ?? '',
      'apk_download_url': releaseData['apk_download_url'] ?? '',
      'apk_sha256': (releaseData['apk_sha256'] ?? '').toString().toLowerCase(),
      'file_size_mb': releaseData['file_size_mb'] ?? '',
      'changelog': releaseData['changelog'] ?? '',
      'min_required_version': releaseData['min_required_version'] ?? '9.0.0',
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
        release[key] = value;
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

    // Si tiene archivo APK en disco, eliminarlo
    final filePath = rel['apk_file_path'] as String?;
    if (filePath != null && filePath.isNotEmpty) {
      final f = File(filePath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    await saveReleases(releases, reason: 'delete_release_$versionName');
    return true;
  }

  /// Matriz Inteligente de Distribución de Versiones
  Future<List<Map<String, dynamic>>> getUpdateDistributionMatrix() async {
    final releases = await getReleases();
    if (releases.isEmpty) return [];

    final latestRelease = releases.first;
    final clients = await getClients();
    final now = DateTime.now();

    final List<Map<String, dynamic>> matrix = [];

    for (final client in clients) {
      final installedVersion = (client['installed_version'] as String? ?? '9.0.0');
      final isUpToDate = installedVersion == latestRelease['version_name'];

      final licenseType = (client['license_type'] as String? ?? 'MENSUAL').toUpperCase();
      final isPerpetual = licenseType == 'PERPETUO_LIBERADO' || licenseType == 'PERPETUO';

      final expiresStr = client['license_expires'] as String?;
      final expires = expiresStr != null ? DateTime.tryParse(expiresStr) : null;
      final isSubscriptionActive = expires != null && expires.isAfter(now);

      final updatesUntilStr = client['updates_until'] as String?;
      final updatesUntil = updatesUntilStr != null ? DateTime.tryParse(updatesUntilStr) : null;
      final hasActiveUpdatePass = updatesUntil != null && updatesUntil.isAfter(now);

      bool isEligibleForFree = false;
      String eligibilityReason = '';
      String requiredAction = 'Ninguna (Al día)';

      if (isUpToDate) {
        isEligibleForFree = true;
        eligibilityReason = 'Ya tiene instalada la última versión.';
        requiredAction = 'Al día';
      } else if (latestRelease['type'] == 'HOTFIX') {
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

      matrix.add({
        'client_id': client['id'],
        'business_name': client['business_name'],
        'owner_name': client['owner_name'],
        'phone': client['phone'],
        'device_id': client['current_device_id'],
        'installed_version': installedVersion,
        'latest_version': latestRelease['version_name'],
        'release_type': latestRelease['type'],
        'is_up_to_date': isUpToDate,
        'is_eligible_for_free': isEligibleForFree,
        'eligibility_reason': eligibilityReason,
        'required_action': requiredAction,
        'download_url': latestRelease['apk_download_url'],
        'changelog': latestRelease['changelog'],
        'has_local_apk': (latestRelease['apk_file_path'] as String? ?? '').isNotEmpty,
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
