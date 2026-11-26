import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Resultado del análisis sintáctico y criptográfico de una ficha de sincronización offline.
class SyncParseResult {
  final bool valid;
  final String? errorCode;
  final String? errorMessage;
  final String? token;
  final Map<String, dynamic>? payload;

  bool get isValid => valid;

  const SyncParseResult({
    required this.valid,
    this.errorCode,
    this.errorMessage,
    this.token,
    this.payload,
  });

  Map<String, dynamic> toJson() => {
        'valid': valid,
        if (errorCode != null) 'error_code': errorCode,
        if (errorMessage != null) 'error_message': errorMessage,
        if (token != null) 'token': token,
        if (payload != null) 'payload': payload,
      };
}

/// Servicio Criptográfico del Protocolo Dual de Sincronización Offline (`.mlsync` y `MLS1-...`).
///
/// Genera y valida tokens firmados con HMAC-SHA256 (truncados a 16 bytes en Base64URL sin relleno)
/// para certificar que el reporte del estado del dispositivo no ha sido alterado offline.
class ClientSyncService {
  /// Clave pública fija del protocolo compartida entre MochilaLista Admin y la App Móvil.
  static const String defaultHmacKey =
      'MochilaLista-OfflineSync-v1-IntegrityKey-9f7c';

  final String hmacKey;

  ClientSyncService({this.hmacKey = defaultHmacKey});

  /// Regex universal para extraer tokens `MLS1-...` incrustados en texto libre o WhatsApp.
  static final RegExp tokenRegex =
      RegExp(r'MLS1-([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)');

  /// Genera un token firmado `MLS1-...` a partir de un payload de sincronización.
  String generateSyncToken(Map<String, dynamic> payload) {
    final payloadJson = jsonEncode(payload);
    final payloadBytes = utf8.encode(payloadJson);
    final payloadB64 = base64Url.encode(payloadBytes).replaceAll('=', '');

    final hmac = Hmac(sha256, utf8.encode(hmacKey));
    final digest = hmac.convert(utf8.encode(payloadB64)).bytes;

    final tagBytes = digest.sublist(0, 16);
    final tagB64 = base64Url.encode(tagBytes).replaceAll('=', '');

    return 'MLS1-$payloadB64.$tagB64';
  }

  /// Genera el contenido estructurado de un archivo JSON `.mlsync` (`MLSYNC_V1`).
  Map<String, dynamic> generateMlsyncFileContent(Map<String, dynamic> payload) {
    final token = generateSyncToken(payload);
    final tsEpoch =
        payload['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final generatedAt =
        DateTime.fromMillisecondsSinceEpoch(tsEpoch, isUtc: true)
            .toIso8601String();

    return {
      'format': 'MLSYNC_V1',
      'token': token,
      'hardware_id': payload['hw'] ?? '',
      'generated_at': generatedAt,
      'summary': {
        'app_version': payload['av'],
        'ai_balance': payload['ai'],
        'status': payload['st'],
        'device_model': payload['mod'],
        'backup_health': payload['bh'],
      },
    };
  }

  /// Parser universal que acepta JSON `.mlsync`, token directo `MLS1-...` o texto WhatsApp.
  SyncParseResult parseRawInput(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return const SyncParseResult(
        valid: false,
        errorCode: 'NO_TOKEN_FOUND',
        errorMessage: 'El texto ingresado está vacío.',
      );
    }

    String? tokenCandidate;

    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        trimmed.contains('"format": "MLSYNC_V1"')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic> && decoded.containsKey('token')) {
          tokenCandidate = decoded['token'] as String?;
        }
      } catch (_) {}
    }

    tokenCandidate ??= tokenRegex.firstMatch(trimmed)?.group(0);

    if (tokenCandidate == null) {
      return const SyncParseResult(
        valid: false,
        errorCode: 'NO_TOKEN_FOUND',
        errorMessage:
            'No se encontró ningún token de sincronización MLS1-... en la entrada proporcionada.',
      );
    }

    final match = tokenRegex.firstMatch(tokenCandidate);
    if (match == null) {
      return const SyncParseResult(
        valid: false,
        errorCode: 'NO_TOKEN_FOUND',
        errorMessage:
            'Formato de token MLS1 no coincide con la especificación.',
      );
    }

    final payloadB64 = match.group(1)!;
    final receivedTagB64 = match.group(2)!;

    final hmac = Hmac(sha256, utf8.encode(hmacKey));
    final expectedDigest = hmac.convert(utf8.encode(payloadB64)).bytes;
    final expectedTagBytes = expectedDigest.sublist(0, 16);

    List<int> receivedTagBytes;
    try {
      final paddedTag = _addBase64Padding(receivedTagB64);
      receivedTagBytes = base64Url.decode(paddedTag);
    } catch (_) {
      return const SyncParseResult(
        valid: false,
        errorCode: 'INVALID_SIGNATURE',
        errorMessage: 'El tag de autenticidad del token está corrupto.',
      );
    }

    if (!_fixedTimeEquals(expectedTagBytes, receivedTagBytes)) {
      return const SyncParseResult(
        valid: false,
        errorCode: 'INVALID_SIGNATURE',
        errorMessage:
            'El sello de integridad HMAC-SHA256 no es válido. Los datos han sido alterados o no provienen de una app genuina.',
      );
    }

    Map<String, dynamic> payload;
    try {
      final paddedPayload = _addBase64Padding(payloadB64);
      final payloadJsonBytes = base64Url.decode(paddedPayload);
      final payloadJsonStr = utf8.decode(payloadJsonBytes);
      final decoded = jsonDecode(payloadJsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Payload is not a JSON object');
      }
      payload = decoded;
    } catch (e) {
      return SyncParseResult(
        valid: false,
        errorCode: 'CORRUPT_PAYLOAD',
        errorMessage: 'El contenido codificado en Base64 no es un JSON válido: $e',
      );
    }

    final protocolVersion = payload['v'];
    if (protocolVersion != 1) {
      return SyncParseResult(
        valid: false,
        errorCode: 'UNSUPPORTED_VERSION',
        errorMessage:
            'Versión del protocolo MLS no soportada ($protocolVersion). Se requiere versión 1.',
      );
    }

    return SyncParseResult(
      valid: true,
      token: tokenCandidate,
      payload: payload,
    );
  }

  /// Cruza el payload verificado contra la cartera de clientes y calcula tabla diff.
  Map<String, dynamic> analyzeForClients(
    Map<String, dynamic> payload,
    List<Map<String, dynamic>> clients, {
    String? expectedClientId,
  }) {
    final hw = (payload['hw'] as String? ?? '').trim();
    final bhw = (payload['bhw'] as String? ?? '').trim();
    final st = (payload['st'] as String? ?? '').trim();
    final tsEpoch = payload['ts'] as int? ?? 0;
    final syncDateTime =
        DateTime.fromMillisecondsSinceEpoch(tsEpoch, isUtc: true);

    Map<String, dynamic>? matchedClient;
    String matchType = 'NEW_CLIENT';
    Map<String, dynamic>? migrationRescue;

    if (expectedClientId != null && expectedClientId.isNotEmpty) {
      matchedClient = clients.firstWhere(
        (c) => c['id'] == expectedClientId,
        orElse: () => <String, dynamic>{},
      );
      if (matchedClient.isNotEmpty) {
        if (matchedClient['current_device_id'] == hw) {
          matchType = 'EXACT_HARDWARE';
        } else if (bhw.isNotEmpty && matchedClient['current_device_id'] == bhw) {
          matchType = 'MIGRATION_SOURCE';
        } else {
          matchType = 'DIFFERENT_HARDWARE_TARGET';
        }
      } else {
        matchedClient = null;
      }
    }

    if (matchedClient == null && st == 'PENDIENTE_MIGRACION' && bhw.isNotEmpty) {
      final source = clients.firstWhere(
        (c) => c['current_device_id'] == bhw,
        orElse: () => <String, dynamic>{},
      );
      if (source.isNotEmpty) {
        matchedClient = source;
        matchType = 'MIGRATION_SOURCE';
      }
    }

    if (matchedClient == null && hw.isNotEmpty) {
      final exact = clients.firstWhere(
        (c) => c['current_device_id'] == hw,
        orElse: () => <String, dynamic>{},
      );
      if (exact.isNotEmpty) {
        matchedClient = exact;
        matchType = 'EXACT_HARDWARE';
      }
    }

    if (st == 'PENDIENTE_MIGRACION' || matchType == 'MIGRATION_SOURCE') {
      migrationRescue = {
        'detected': true,
        'old_hardware_id':
            bhw.isNotEmpty ? bhw : (matchedClient?['current_device_id'] ?? ''),
        'new_hardware_id': hw,
        'device_model': payload['mod'] ?? 'Dispositivo Android',
        'suggested_scenario': 'RESTORED_BACKUP',
        'matched_client_id': matchedClient?['id'],
        'matched_client_name': matchedClient?['business_name'],
      };
    }

    bool isOlderThanLastSync = false;
    String? staleWarning;
    DateTime? lastSyncAt;
    int? lastSyncTs;

    if (matchedClient != null) {
      if (matchedClient['last_sync_at'] != null) {
        lastSyncAt = DateTime.tryParse(matchedClient['last_sync_at'].toString());
        if (lastSyncAt != null && syncDateTime.isBefore(lastSyncAt)) {
          isOlderThanLastSync = true;
          staleWarning =
              'Esta ficha (${syncDateTime.toIso8601String()}) es cronológicamente anterior a la última sincronización registrada (${lastSyncAt.toIso8601String()}). Aplica solo si estás seguro.';
        }
      }
      if (matchedClient['last_sync_ts'] is num) {
        lastSyncTs = (matchedClient['last_sync_ts'] as num).toInt();
      } else if (lastSyncAt != null) {
        lastSyncTs = lastSyncAt.millisecondsSinceEpoch;
      }
    }

    final bool sameTimestamp =
        lastSyncTs != null && tsEpoch > 0 && lastSyncTs == tsEpoch;

    final changes = <Map<String, dynamic>>[];
    int? aiUsedDelta;

    if (matchedClient != null) {
      void addDiff(
        String field,
        String label,
        dynamic beforeVal,
        dynamic afterVal, {
        String type = 'text',
        int? delta,
        bool? forceIsDifferent,
      }) {
        final bStr = beforeVal?.toString() ?? '-';
        final aStr = afterVal?.toString() ?? '-';
        final isDifferent = forceIsDifferent ?? (bStr != aStr);
        changes.add({
          'field': field,
          'label': label,
          'before': beforeVal,
          'before_display': bStr,
          'after': afterVal,
          'after_display': aStr,
          'is_different': isDifferent,
          'changed': isDifferent,
          'type': type,
          if (delta != null) 'delta': delta,
        });
      }

      String normalizeOptionalStr(dynamic val, String emptyFallback) {
        final s = val?.toString().trim() ?? '';
        return s.isEmpty ? emptyFallback : s;
      }

      String normalizeBackupTimestamp(dynamic val) {
        final s = val?.toString().trim() ?? '';
        if (s.isEmpty || s == 'Nunca' || s == 'Sin respaldos' || s == 'null') {
          return 'Sin respaldos';
        }
        return s;
      }

      final prevAiuRaw = matchedClient['ai_credits_used_total'];
      final prevAiu = prevAiuRaw is num ? prevAiuRaw.toInt() : null;
      final newAiu = payload['aiu'] is num
          ? (payload['aiu'] as num).toInt()
          : (int.tryParse(payload['aiu']?.toString() ?? '') ?? 0);
      if (prevAiu != null && (newAiu - prevAiu) >= 0) {
        aiUsedDelta = newAiu - prevAiu;
      }

      final clientDr = _computeClientDaysRemaining(matchedClient);
      final reportedDr = (payload.containsKey('dr') && payload['dr'] != null)
          ? (payload['dr'] as num).toInt()
          : clientDr;

      final clientPlan = (matchedClient['license_type'] ?? 'MENSUAL')
          .toString()
          .trim()
          .toUpperCase();
      final reportedPlan =
          (payload['pl'] ?? clientPlan).toString().trim().toUpperCase();

      final clientAuthStatus = _computeAuthoritativeClientStatus(matchedClient);
      final reportedNormStatus =
          _normalizeSyncStatus(payload['st']?.toString());
      final statusDifferent = _normalizeSyncStatus(clientAuthStatus) !=
          _normalizeSyncStatus(reportedNormStatus);

      addDiff(
        'ai_reported_balance',
        'Saldo Créditos IA',
        matchedClient['ai_reported_balance'] ?? 0,
        payload['ai'] ?? 0,
        type: 'number',
      );
      addDiff(
        'ai_credits_used_total',
        'Escaneos IA Consumidos (Histórico)',
        prevAiu ?? 0,
        newAiu,
        type: 'number',
        delta: aiUsedDelta,
      );
      addDiff(
        'installed_version',
        'Versión APK Instalada',
        matchedClient['installed_version'] ?? '9.0.0',
        payload['av'] ?? '9.0.0',
        type: 'version',
      );
      addDiff(
        'device_model',
        'Modelo de Celular',
        normalizeOptionalStr(matchedClient['device_model'], 'No registrado'),
        normalizeOptionalStr(payload['mod'], 'No reportado'),
      );
      addDiff(
        'android_version',
        'Versión de Android / OS',
        normalizeOptionalStr(
            matchedClient['android_version'], 'No registrado'),
        normalizeOptionalStr(payload['os'], 'No reportado'),
      );
      addDiff(
        'profiles_count',
        'Perfiles de Negocio Activos',
        matchedClient['profiles_count'] ?? 1,
        payload['pc'] ?? 1,
        type: 'number',
      );
      addDiff(
        'backup_health_status',
        'Salud de Respaldo',
        matchedClient['backup_health_status'] ?? 'NONE',
        payload['bh'] ?? 'NONE',
        type: 'badge',
      );
      addDiff(
        'backup_drive_linked',
        'Google Drive Vinculado',
        matchedClient['backup_drive_linked'] == true,
        payload['drv'] == true,
        type: 'boolean',
      );
      addDiff(
        'last_backup_at',
        'Último Respaldo Local/Drive',
        normalizeBackupTimestamp(matchedClient['last_backup_at']),
        normalizeBackupTimestamp(payload['lb']),
        type: 'datetime',
      );
      addDiff(
        'uses_byok',
        'Usa API Key Propia (BYOK)',
        matchedClient['uses_byok'] == true,
        payload['byok'] == true,
        type: 'boolean',
      );
      addDiff(
        'ultimo_nonce',
        'Nonce Criptográfico',
        matchedClient['ultimo_nonce'] ?? 0,
        payload['n'] ?? 0,
        type: 'number',
      );
      addDiff(
        'trial_days_remaining',
        'Días de Vigencia Restantes',
        clientDr,
        reportedDr,
        type: 'number',
      );
      addDiff(
        'license_type',
        'Plan Comercial',
        clientPlan,
        reportedPlan,
        type: 'badge',
      );
      addDiff(
        'license_status',
        'Estado de Vigencia',
        clientAuthStatus,
        reportedNormStatus,
        type: 'badge',
        forceIsDifferent: statusDifferent,
      );
    }

    final bool allUnchanged =
        changes.isNotEmpty && changes.every((c) => c['is_different'] != true);

    return {
      'match_type': matchType,
      'matched_client': matchedClient,
      'is_older_than_last_sync': isOlderThanLastSync,
      'stale_warning': staleWarning,
      'sync_timestamp_utc': syncDateTime.toIso8601String(),
      'sync_timestamp_ms': tsEpoch,
      'last_sync_registered_utc': lastSyncAt?.toIso8601String(),
      'all_unchanged': allUnchanged,
      'same_timestamp': sameTimestamp,
      'ai_credits_used_delta': aiUsedDelta,
      'migration_rescue': migrationRescue,
      'changes': changes,
      'hardware_id': hw,
      'bound_hardware_id': bhw,
      'status': st,
    };
  }

  static String _normalizeSyncStatus(String? rawStatus) {
    final s = (rawStatus ?? 'ACTIVA').trim().toUpperCase();
    if (s.isEmpty) return 'ACTIVA';
    if (s == 'VENCIDA' || s == 'EXPIRED') return 'EXPIRADA';
    if (s == 'PERPETUA' || s == 'PERPETUO' || s == 'PERPETUO_LIBERADO') {
      return 'ACTIVA';
    }
    return s;
  }

  static String _computeAuthoritativeClientStatus(
    Map<String, dynamic> client,
  ) {
    final plan =
        (client['license_type'] as String? ?? 'MENSUAL').trim().toUpperCase();
    final status =
        (client['license_status'] as String? ?? '').trim().toUpperCase();

    if (plan == 'PROSPECTO' || status == 'PROSPECTO') {
      return 'PROSPECTO';
    }
    if (plan.contains('PERPETU') || status == 'PERPETUA') {
      return 'ACTIVA';
    }

    final expRaw = client['license_expires']?.toString().trim();
    if (expRaw != null && expRaw.isNotEmpty) {
      final expDate = DateTime.tryParse(expRaw);
      if (expDate != null &&
          expDate.toUtc().isBefore(DateTime.now().toUtc())) {
        return 'EXPIRADA';
      }
    } else if (status == 'EXPIRADA' || status == 'VENCIDA') {
      return 'EXPIRADA';
    }

    return 'ACTIVA';
  }

  static int _computeClientDaysRemaining(Map<String, dynamic> client) {
    if (client['trial_days_remaining'] is num) {
      return (client['trial_days_remaining'] as num).toInt();
    }
    final expRaw = client['license_expires']?.toString().trim();
    if (expRaw != null && expRaw.isNotEmpty) {
      final expDate = DateTime.tryParse(expRaw);
      if (expDate != null) {
        final diffHours =
            expDate.toUtc().difference(DateTime.now().toUtc()).inHours;
        if (diffHours <= 0) return 0;
        return (diffHours / 24).ceil();
      }
    }
    return 0;
  }

  static String _addBase64Padding(String str) {
    final remainder = str.length % 4;
    if (remainder == 0) return str;
    return str.padRight(str.length + (4 - remainder), '=');
  }

  static bool _fixedTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
