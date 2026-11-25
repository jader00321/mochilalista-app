import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'license_signer.dart';
import 'time_utils.dart';

/// Excepción lanzada cuando un payload o token declarativo `MLC1-...` incumple
/// el esquema tipado, excede la cota de tamaño o posee rangos inválidos.
class CommercialConfigSyncException implements Exception {
  final String message;
  const CommercialConfigSyncException(this.message);

  @override
  String toString() => message;
}

/// Servicio emisor y verificador criptográfico declarativo `MLC1-...` (Plan Maestro 23 - Fase 3).
///
/// Características de blindaje:
/// - 100 % declarativo (solo JSON tipado de tarifas, cuotas IA, pagos y soporte; cero scripts).
/// - Separación explícita de dominio Ed25519: firma sobre `utf8.encode('MLC1-$payloadB64')`.
/// - Cota estricta de tamaño (`<= 8192` bytes) y rangos numéricos no negativos/finitos.
class CommercialConfigSyncService {
  static const String tokenPrefix = 'MLC1-';
  static const int schemaVersion = 1;
  static const int maxPayloadBytes = 8192;
  static const int maxTokenBytes = 8192;

  /// Orden y mapeo oficial de los 8 ítems comerciales hacia IDs de la app móvil.
  static const Map<String, String> catalogSlugToSyncId = {
    'MENSUAL': 'mensual',
    'TRIMESTRAL': 'trimestral',
    'SEMESTRAL': 'semestral',
    'ANUAL': 'anual',
    'PERPETUO_LIBERADO': 'perpetua',
    'RECARGA_IA_150': 'bolsa_extra_ia',
    'PASE_ACTUALIZACION_ANUAL': 'pase_anual_updates',
    'HARDWARE_MIGRATION_FEE': 'migracion',
  };

  static const Set<String> _allowedTopLevelKeys = {
    'v',
    'ver',
    'iat',
    'sup',
    'yh',
    'yp',
    'bcp',
    'bbva',
    'p',
  };

  static const Set<String> _allowedBankKeys = {'h', 'acc', 'cci'};
  static const Set<String> _allowedProductKeys = {
    'pr',
    'd',
    'ai',
    'um',
    'lb',
    'ds',
  };
  static const Set<String> _allowedProductIds = {
    'mensual',
    'trimestral',
    'semestral',
    'anual',
    'perpetua',
    'bolsa_extra_ia',
    'pase_anual_updates',
    'migracion',
  };

  final Ed25519 _ed25519 = Ed25519();

  /// Extrae un token `MLC1-...` desde mensajes completos de WhatsApp, texto libre o salida QR.
  /// Paritario con `app_movil/lib/core/services/license/commercial_config_sync_service.dart`.
  static String extractMlc1Token(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    final explicitPattern = RegExp(
      r'mlc1-([A-Za-z0-9_\-+=]{10,}\.[A-Za-z0-9_\-+=]{20,})',
      caseSensitive: false,
    );
    final match = explicitPattern.firstMatch(trimmed);
    if (match != null) {
      return '$tokenPrefix${match.group(1)!}';
    }
    return '';
  }

  /// Indica si la entrada apunta al protocolo `MLC1-` (incluso si está truncada o corrupta)
  /// para evitar que sea evaluada por el validador `ML9`.
  static bool looksLikeMlc1Input(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toUpperCase().startsWith(tokenPrefix)) return true;
    if (extractMlc1Token(trimmed).isNotEmpty) return true;
    return RegExp(r'(?:^|\s)\*?MLC1-', caseSensitive: false).hasMatch(trimmed);
  }

  static double _roundPrice(num raw, String fieldName) {
    final val = raw.toDouble();
    if (val.isNaN || val.isInfinite || val < 0 || val > 1000000) {
      throw CommercialConfigSyncException(
        'Valor numérico fuera de rango permitido en "$fieldName": $raw',
      );
    }
    return (val * 100).round() / 100.0;
  }

  static int _parseNonNegativeInt(
    dynamic raw,
    String fieldName, {
    int max = 1000000,
    int fallback = 0,
  }) {
    if (raw == null) return fallback;
    if (raw is! num || raw.toDouble().isNaN || raw.toDouble().isInfinite) {
      throw CommercialConfigSyncException(
        'Entero inválido en "$fieldName": $raw',
      );
    }
    final intVal = raw.toInt();
    if (intVal < 0 || intVal > max) {
      throw CommercialConfigSyncException(
        'Entero fuera de rango en "$fieldName": $intVal',
      );
    }
    return intVal;
  }

  static String _sanitizeString(dynamic raw, {int maxLength = 240}) {
    final s = (raw?.toString() ?? '').replaceAll('\r', ' ').trim();
    if (s.length > maxLength) {
      return s.substring(0, maxLength).trim();
    }
    return s;
  }

  /// Ordena recursivamente todas las llaves de Map alfabéticamente para serialización canónica estable.
  static dynamic _canonicalizeValue(dynamic value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((e) => e.toString()).toList()..sort();
      final result = <String, dynamic>{};
      for (final k in sortedKeys) {
        result[k] = _canonicalizeValue(value[k]);
      }
      return result;
    }
    if (value is List) {
      return value.map(_canonicalizeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> _extractPaymentAccountTriple(
    Map<String, dynamic> pm,
    String bankKey,
  ) {
    final nested = pm[bankKey] is Map ? pm[bankKey] as Map : null;
    final holder = _sanitizeString(
      nested?['holder'] ?? pm['${bankKey}_account_holder'] ?? '',
      maxLength: 120,
    );
    final acc = _sanitizeString(
      nested?['account'] ??
          nested?['number'] ??
          pm['${bankKey}_account_number'] ??
          '',
      maxLength: 60,
    );
    final cci = _sanitizeString(
      nested?['cci'] ?? pm['${bankKey}_cci'] ?? '',
      maxLength: 60,
    );
    return <String, dynamic>{
      'acc': acc,
      'cci': cci,
      'h': holder,
    };
  }

  static Map<String, String> _extractYapePlin(
    Map<String, dynamic> pm,
    Map<String, dynamic> li,
  ) {
    final yapeNested = pm['yape_plin'] is Map ? pm['yape_plin'] as Map : null;
    final phone = _sanitizeString(
      yapeNested?['phone'] ??
          yapeNested?['number'] ??
          pm['yape_plin_phone'] ??
          '922836879',
      maxLength: 40,
    );
    final holder = _sanitizeString(
      yapeNested?['holder'] ??
          pm['yape_plin_holder'] ??
          li['author_full_name'] ??
          'Julio Angello Vasquez Navarro',
      maxLength: 120,
    );
    return {'phone': phone, 'holder': holder};
  }

  /// Construye el payload JSON canónico `v == 1` validando tipos, rangos y cota <= 8192 bytes.
  Map<String, dynamic> buildCanonicalPayload(
    Map<String, dynamic> config, {
    required int revision,
    DateTime? nowUtc,
  }) {
    if (revision < 1) {
      throw const CommercialConfigSyncException(
        'La revisión de sincronización `ver` debe ser >= 1.',
      );
    }

    final li = config['legal_identity'] is Map
        ? Map<String, dynamic>.from(config['legal_identity'] as Map)
        : <String, dynamic>{};
    final pm = config['payment_methods'] is Map
        ? Map<String, dynamic>.from(config['payment_methods'] as Map)
        : <String, dynamic>{};
    final catalog = config['catalog'] is Map
        ? Map<String, dynamic>.from(config['catalog'] as Map)
        : <String, dynamic>{};

    final yape = _extractYapePlin(pm, li);
    final sup = _sanitizeString(
      li['support_phone'] ?? '+51 922 836 879',
      maxLength: 40,
    );
    final iatSec =
        ((nowUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch / 1000)
            .floor();

    final productsMap = <String, dynamic>{};
    catalogSlugToSyncId.forEach((slug, syncId) {
      final rawEntry = catalog[slug] is Map
          ? Map<String, dynamic>.from(catalog[slug] as Map)
          : <String, dynamic>{};

      final rawPrice = rawEntry['price'];
      if (rawPrice is! num) {
        throw CommercialConfigSyncException(
          'Falta precio numérico válido para $slug en catalog.',
        );
      }
      final pr = _roundPrice(rawPrice, '$slug.price');
      final d = _parseNonNegativeInt(rawEntry['days'], '$slug.days');
      final ai =
          _parseNonNegativeInt(rawEntry['ai_credits'], '$slug.ai_credits');
      final defaultUm = (slug == 'PERPETUO_LIBERADO' ||
              slug == 'PASE_ACTUALIZACION_ANUAL')
          ? 12
          : 0;
      final um = _parseNonNegativeInt(
        rawEntry['updates_window_months'] ?? rawEntry['updates_months'],
        '$slug.updates_window_months',
        max: 1200,
        fallback: defaultUm,
      );
      final lb = _sanitizeString(rawEntry['label'] ?? slug, maxLength: 80);
      final ds = _sanitizeString(rawEntry['description'] ?? '', maxLength: 180);

      productsMap[syncId] = <String, dynamic>{
        'ai': ai,
        'd': d,
        'ds': ds,
        'lb': lb,
        'pr': pr,
        'um': um,
      };
    });

    final rawPayload = <String, dynamic>{
      'bbva': _extractPaymentAccountTriple(pm, 'bbva'),
      'bcp': _extractPaymentAccountTriple(pm, 'bcp'),
      'iat': iatSec,
      'p': productsMap,
      'sup': sup,
      'v': schemaVersion,
      'ver': revision,
      'yh': yape['holder']!,
      'yp': yape['phone']!,
    };

    final canonicalPayload =
        _canonicalizeValue(rawPayload) as Map<String, dynamic>;
    final encodedBytes = utf8.encode(jsonEncode(canonicalPayload));
    if (encodedBytes.length > maxPayloadBytes) {
      throw CommercialConfigSyncException(
        'El payload canónico excede la cota máxima de $maxPayloadBytes bytes (${encodedBytes.length} B).',
      );
    }

    return canonicalPayload;
  }

  /// Firma el payload canónico `MLC1-...` usando separación de dominio explícita:
  /// `utf8.encode('MLC1-$payloadB64')` sobre Ed25519.
  Future<Map<String, dynamic>> generateSignedToken(
    Map<String, dynamic> config, {
    required int revision,
    LicenseSigner? signer,
    SimpleKeyPair? keyPair,
    DateTime? nowUtc,
  }) async {
    if (signer == null && keyPair == null) {
      throw ArgumentError(
        'Debe proveer `signer` (LicenseSigner) o `keyPair` (SimpleKeyPair) para firmar MLC1.',
      );
    }

    final issuedUtc = (nowUtc ?? DateTime.now()).toUtc();
    final canonicalPayload = buildCanonicalPayload(
      config,
      revision: revision,
      nowUtc: issuedUtc,
    );

    final canonicalJsonStr = jsonEncode(canonicalPayload);
    final payloadBytes = utf8.encode(canonicalJsonStr);
    final payloadB64 = LicenseSigner.encodeBase64UrlSafe(payloadBytes);

    // Salvaguarda 1 (Plan 23 v1.1): separación de dominio explícita frente a ML9
    final domainMessage = utf8.encode('$tokenPrefix$payloadB64');

    final List<int> sigBytes;
    if (keyPair != null) {
      final signature = await _ed25519.sign(domainMessage, keyPair: keyPair);
      sigBytes = signature.bytes;
    } else {
      sigBytes = await signer!.signRawMessage(domainMessage);
    }

    final sigB64 = LicenseSigner.encodeBase64UrlSafe(sigBytes);
    final token = '$tokenPrefix$payloadB64.$sigB64';
    final tokenByteLength = utf8.encode(token).length;
    if (tokenByteLength > maxTokenBytes) {
      throw CommercialConfigSyncException(
        'El token firmado MLC1 excede el límite de $maxTokenBytes bytes ($tokenByteLength B).',
      );
    }

    return {
      'token': token,
      'revision': revision,
      'issued_at': issuedUtc.toIso8601String(),
      'issued_at_unix': canonicalPayload['iat'],
      'issued_at_lima': PeruTimeHelper.formatLimaDateTime(issuedUtc),
      'payload_bytes': payloadBytes.length,
      'token_bytes': tokenByteLength,
      'payload': canonicalPayload,
      'summary': buildSummaryFromPayload(canonicalPayload),
    };
  }

  /// Verifica estructura, separación de dominio `MLC1-$payloadB64`, firma Ed25519 y esquema tipado.
  Future<Map<String, dynamic>> verifySignedToken(
    String rawToken, {
    LicenseSigner? signer,
    SimplePublicKey? publicKey,
    List<int>? publicKeyBytes,
  }) async {
    final extracted = extractMlc1Token(rawToken);
    final clean = extracted.isNotEmpty ? extracted : rawToken.trim();
    if (clean.isEmpty || !clean.startsWith(tokenPrefix)) {
      return {
        'valid': false,
        'status': 'INVALID_PREFIX',
        'error': 'El token debe iniciar con el prefijo exacto "$tokenPrefix".',
      };
    }

    final cleanBytes = utf8.encode(clean);
    if (cleanBytes.length > maxTokenBytes) {
      return {
        'valid': false,
        'status': 'EXCEEDS_MAX_SIZE',
        'error':
            'El token excede el tamaño máximo permitido ($maxTokenBytes bytes).',
      };
    }

    final body = clean.substring(tokenPrefix.length);
    final parts = body.split('.');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return {
        'valid': false,
        'status': 'INVALID_FORMAT',
        'error':
            'Formato inválido: se requiere MLC1-<payload_b64url>.<sig_b64url>.',
      };
    }

    final payloadB64 = parts[0];
    final sigB64 = parts[1];

    final Uint8List payloadBytes;
    final Uint8List sigBytes;
    try {
      payloadBytes = LicenseSigner.decodeBase64UrlSafe(payloadB64);
      sigBytes = LicenseSigner.decodeBase64UrlSafe(sigB64);
    } catch (e) {
      return {
        'valid': false,
        'status': 'BASE64_DECODE_ERROR',
        'error': 'Base64Url inválido en token MLC1: $e',
      };
    }

    if (payloadBytes.length > maxPayloadBytes) {
      return {
        'valid': false,
        'status': 'EXCEEDS_MAX_SIZE',
        'error':
            'Payload decodificado excede $maxPayloadBytes bytes (${payloadBytes.length} B).',
      };
    }
    if (sigBytes.length != 64) {
      return {
        'valid': false,
        'status': 'INVALID_SIGNATURE_LENGTH',
        'error':
            'Longitud de firma Ed25519 inválida (${sigBytes.length} B; requeridos 64 B).',
      };
    }

    SimplePublicKey? resolvedPubKey = publicKey;
    if (resolvedPubKey == null && publicKeyBytes != null) {
      resolvedPubKey =
          SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    } else if (resolvedPubKey == null && signer != null) {
      resolvedPubKey =
          SimplePublicKey(signer.publicKeyBytes, type: KeyPairType.ed25519);
    }
    if (resolvedPubKey == null) {
      return {
        'valid': false,
        'status': 'MISSING_PUBLIC_KEY',
        'error': 'No se proporcionó clave pública Ed25519 para verificar.',
      };
    }

    // Verificar estrictamente sobre `utf8.encode('MLC1-$payloadB64')`
    final domainMessage = utf8.encode('$tokenPrefix$payloadB64');
    final isSigValid = await _ed25519.verify(
      domainMessage,
      signature: Signature(sigBytes, publicKey: resolvedPubKey),
    );
    if (!isSigValid) {
      return {
        'valid': false,
        'status': 'INVALID_SIGNATURE',
        'error':
            'Firma Ed25519 inválida (token adulterado, dominio incorrecto o clave distinta).',
      };
    }

    dynamic decodedJson;
    try {
      decodedJson = jsonDecode(utf8.decode(payloadBytes));
    } catch (e) {
      return {
        'valid': false,
        'status': 'INVALID_JSON',
        'error': 'JSON inválido en payload MLC1: $e',
      };
    }

    final schemaError = validateDecodedPayloadSchema(decodedJson);
    if (schemaError != null) {
      return {
        'valid': false,
        'status': 'INVALID_SCHEMA',
        'error': schemaError,
      };
    }

    final payloadMap = Map<String, dynamic>.from(decodedJson as Map);
    final iatUnix = (payloadMap['iat'] as num).toInt();
    final issuedUtc =
        DateTime.fromMillisecondsSinceEpoch(iatUnix * 1000, isUtc: true);

    return {
      'valid': true,
      'status': 'VALID',
      'revision': (payloadMap['ver'] as num).toInt(),
      'schema_version': (payloadMap['v'] as num).toInt(),
      'issued_at': issuedUtc.toIso8601String(),
      'issued_at_unix': iatUnix,
      'issued_at_lima': PeruTimeHelper.formatLimaDateTime(issuedUtc),
      'payload_bytes': payloadBytes.length,
      'token_bytes': cleanBytes.length,
      'max_payload_bytes': maxPayloadBytes,
      'domain_separated': true,
      'domain_message_prefix': tokenPrefix,
      'clean_token': clean,
      'payload': payloadMap,
      'summary': buildSummaryFromPayload(payloadMap),
    };
  }

  /// Decodifica de forma segura y acotada (solo lectura diagnóstica, nunca confiable)
  /// el payload JSON de una ficha `MLC1-...` cuya firma o esquema fallaron.
  Map<String, dynamic>? tryDecodePayloadDiagnostic(String rawInput) {
    final extracted = extractMlc1Token(rawInput);
    var clean = extracted.isNotEmpty ? extracted : rawInput.trim();
    if (clean.isEmpty) return null;

    if (!clean.toUpperCase().startsWith(tokenPrefix)) {
      final marker = RegExp(
        r'(?:^|\s)\*?(mlc1-[^\s*]+)',
        caseSensitive: false,
      ).firstMatch(clean);
      if (marker == null) return null;
      clean = marker.group(1)!;
    }

    if (utf8.encode(clean).length > maxTokenBytes) return null;
    final body = clean.substring(tokenPrefix.length);
    final dotIdx = body.indexOf('.');
    final payloadB64 = dotIdx >= 0 ? body.substring(0, dotIdx) : body;
    if (payloadB64.isEmpty) return null;

    try {
      final payloadBytes = LicenseSigner.decodeBase64UrlSafe(payloadB64);
      if (payloadBytes.isEmpty || payloadBytes.length > maxPayloadBytes) {
        return null;
      }
      final decoded = jsonDecode(utf8.decode(payloadBytes));
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Extrae un resumen diagnóstico tolerante a campos parciales o corruptos (solo lectura).
  Map<String, dynamic> buildDiagnosticSummaryFromMap(
    Map<String, dynamic> rawMap,
  ) {
    final rev = (rawMap['ver'] is num) ? (rawMap['ver'] as num).toInt() : null;
    final iat = (rawMap['iat'] is num) ? (rawMap['iat'] as num).toInt() : null;
    String? issuedLima;
    if (iat != null && iat > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true);
      issuedLima = PeruTimeHelper.formatLimaDateTime(dt);
    }
    final productsRaw = rawMap['p'];
    final unexpectedKeys = rawMap.keys
        .map((k) => k.toString())
        .where((k) => !_allowedTopLevelKeys.contains(k))
        .toList();

    return {
      'revision': rev,
      'schema_version': rawMap['v'],
      'issued_at_lima': issuedLima,
      'support_phone': rawMap['sup']?.toString(),
      'yape_holder': rawMap['yh']?.toString(),
      'yape_phone': rawMap['yp']?.toString(),
      'products_count': productsRaw is Map ? productsRaw.length : 0,
      'unexpected_keys': unexpectedKeys,
    };
  }

  static String _formatBankAccountDisplay(Map? bankMap) {
    if (bankMap == null) return 'Omitido';
    final acc = (bankMap['acc'] ?? '').toString().trim();
    final cci = (bankMap['cci'] ?? '').toString().trim();
    final holder = (bankMap['h'] ?? '').toString().trim();
    if (acc.isEmpty && cci.isEmpty && holder.isEmpty) return 'Omitido';
    final parts = <String>[];
    if (acc.isNotEmpty) parts.add(acc);
    if (cci.isNotEmpty) parts.add('CCI: $cci');
    if (holder.isNotEmpty) parts.add(holder);
    return parts.join(' · ');
  }

  static bool _bankAccountsEqual(Map? a, Map? b) {
    for (final k in const ['h', 'acc', 'cci']) {
      final av = (a?[k] ?? '').toString().trim();
      final bv = (b?[k] ?? '').toString().trim();
      if (av != bv) return false;
    }
    return true;
  }

  /// Compara la ficha `MLC1` decodificada contra la revisión local y `owner_config.json` actual.
  Map<String, dynamic> buildCurrentConfigComparison(
    Map<String, dynamic> decodedPayload,
    Map<String, dynamic> currentConfig, {
    required int localRevision,
  }) {
    final tokenRev = (decodedPayload['ver'] as num?)?.toInt() ?? 0;
    final safeLocalRev = localRevision < 0 ? 0 : localRevision;

    final String revisionStatus;
    final String revisionStatusLabel;
    final String recommendation;
    if (safeLocalRev >= 1 && tokenRev == safeLocalRev) {
      revisionStatus = 'CURRENT';
      revisionStatusLabel = 'Revisión vigente en Admin';
      recommendation =
          'Revisión vigente actual en Admin — Lista para compartir con tus clientes.';
    } else if (tokenRev < safeLocalRev) {
      revisionStatus = 'SUPERSEDED';
      revisionStatusLabel = 'Revisión anterior a la local';
      recommendation =
          'Revisión anterior — Los celulares que ya aplicaron la Rev. #$safeLocalRev la rechazarán por protección anti-downgrade; genera una ficha nueva si deseas actualizarlos.';
    } else {
      revisionStatus = 'AHEAD_OR_EXTERNAL';
      revisionStatusLabel = 'Revisión superior a la local';
      recommendation =
          'Revisión superior a la local — Emitida en otro equipo o antes de restaurar un respaldo.';
    }

    Map<String, dynamic> currentSnapshot;
    try {
      currentSnapshot = buildCanonicalPayload(
        currentConfig,
        revision: safeLocalRev < 1 ? 1 : safeLocalRev,
      );
    } catch (_) {
      final li = currentConfig['legal_identity'] is Map
          ? Map<String, dynamic>.from(currentConfig['legal_identity'] as Map)
          : <String, dynamic>{};
      final pm = currentConfig['payment_methods'] is Map
          ? Map<String, dynamic>.from(currentConfig['payment_methods'] as Map)
          : <String, dynamic>{};
      final yape = _extractYapePlin(pm, li);
      currentSnapshot = {
        'sup': _sanitizeString(li['support_phone'] ?? '', maxLength: 40),
        'yh': yape['holder']!,
        'yp': yape['phone']!,
        'bcp': _extractPaymentAccountTriple(pm, 'bcp'),
        'bbva': _extractPaymentAccountTriple(pm, 'bbva'),
        'p': <String, dynamic>{},
      };
    }

    final tokProducts = decodedPayload['p'] is Map
        ? decodedPayload['p'] as Map
        : const <String, dynamic>{};
    final curProducts = currentSnapshot['p'] is Map
        ? currentSnapshot['p'] as Map
        : const <String, dynamic>{};

    final productsDiff = <Map<String, dynamic>>[];
    int diffCount = 0;

    for (final id in catalogSlugToSyncId.values) {
      final tp = tokProducts[id] is Map ? tokProducts[id] as Map : const {};
      final cp = curProducts[id] is Map ? curProducts[id] as Map : const {};

      final tokPr = ((tp['pr'] as num?)?.toDouble() ?? 0.0);
      final tokD = (tp['d'] as num?)?.toInt() ?? 0;
      final tokAi = (tp['ai'] as num?)?.toInt() ?? 0;
      final tokUm = (tp['um'] as num?)?.toInt() ?? 0;
      final tokLb = (tp['lb'] ?? '').toString().trim();

      final curPr = ((cp['pr'] as num?)?.toDouble() ?? 0.0);
      final curD = (cp['d'] as num?)?.toInt() ?? 0;
      final curAi = (cp['ai'] as num?)?.toInt() ?? 0;
      final curUm = (cp['um'] as num?)?.toInt() ?? 0;
      final curLb = (cp['lb'] ?? '').toString().trim();

      final changedFields = <String>[];
      if ((tokPr - curPr).abs() >= 0.005) changedFields.add('pr');
      if (tokD != curD) changedFields.add('d');
      if (tokAi != curAi) changedFields.add('ai');
      if (tokUm != curUm) changedFields.add('um');

      final matches = changedFields.isEmpty;
      if (!matches) diffCount++;

      productsDiff.add({
        'id': id,
        'label': curLb.isNotEmpty ? curLb : (tokLb.isNotEmpty ? tokLb : id),
        'token_label': tokLb,
        'current_label': curLb,
        'token_values': {
          'pr': tokPr,
          'd': tokD,
          'ai': tokAi,
          'um': tokUm,
        },
        'current_values': {
          'pr': curPr,
          'd': curD,
          'ai': curAi,
          'um': curUm,
        },
        'changed_fields': changedFields,
        'matches': matches,
      });
    }

    final tokSup = (decodedPayload['sup'] ?? '').toString().trim();
    final curSup = (currentSnapshot['sup'] ?? '').toString().trim();
    final tokYh = (decodedPayload['yh'] ?? '').toString().trim();
    final curYh = (currentSnapshot['yh'] ?? '').toString().trim();
    final tokYp = (decodedPayload['yp'] ?? '').toString().trim();
    final curYp = (currentSnapshot['yp'] ?? '').toString().trim();
    final tokBcp = decodedPayload['bcp'] is Map ? decodedPayload['bcp'] as Map : null;
    final curBcp = currentSnapshot['bcp'] is Map ? currentSnapshot['bcp'] as Map : null;
    final tokBbva = decodedPayload['bbva'] is Map ? decodedPayload['bbva'] as Map : null;
    final curBbva = currentSnapshot['bbva'] is Map ? currentSnapshot['bbva'] as Map : null;

    final channelsDiff = <Map<String, dynamic>>[
      {
        'key': 'sup',
        'label': 'Teléfono Soporte',
        'token_value': tokSup.isEmpty ? 'Omitido' : tokSup,
        'current_value': curSup.isEmpty ? 'Omitido' : curSup,
        'matches': tokSup == curSup,
      },
      {
        'key': 'yh',
        'label': 'Titular Yape / Plin',
        'token_value': tokYh.isEmpty ? 'Omitido' : tokYh,
        'current_value': curYh.isEmpty ? 'Omitido' : curYh,
        'matches': tokYh == curYh,
      },
      {
        'key': 'yp',
        'label': 'Número Yape / Plin',
        'token_value': tokYp.isEmpty ? 'Omitido' : tokYp,
        'current_value': curYp.isEmpty ? 'Omitido' : curYp,
        'matches': tokYp == curYp,
      },
      {
        'key': 'bcp',
        'label': 'Cuenta BCP',
        'token_value': _formatBankAccountDisplay(tokBcp),
        'current_value': _formatBankAccountDisplay(curBcp),
        'matches': _bankAccountsEqual(tokBcp, curBcp),
      },
      {
        'key': 'bbva',
        'label': 'Cuenta BBVA',
        'token_value': _formatBankAccountDisplay(tokBbva),
        'current_value': _formatBankAccountDisplay(curBbva),
        'matches': _bankAccountsEqual(tokBbva, curBbva),
      },
    ];

    for (final ch in channelsDiff) {
      if (ch['matches'] != true) diffCount++;
    }

    return {
      'local_revision': safeLocalRev,
      'token_revision': tokenRev,
      'revision_status': revisionStatus,
      'revision_status_label': revisionStatusLabel,
      'recommendation': recommendation,
      'diff_vs_current': {
        'matches_current': diffCount == 0,
        'total_differences': diffCount,
        'products_diff': productsDiff,
        'channels_diff': channelsDiff,
      },
    };
  }

  /// Valida estrictamente el esquema tipado `v == 1` rechazando claves desconocidas o rangos negativos.
  String? validateDecodedPayloadSchema(dynamic decoded) {
    if (decoded is! Map) {
      return 'El payload MLC1 debe ser un objeto JSON.';
    }
    final map = decoded;
    for (final k in map.keys) {
      if (!_allowedTopLevelKeys.contains(k)) {
        return 'Clave no autorizada en payload MLC1: "$k".';
      }
    }

    if (map['v'] is! int || map['v'] != schemaVersion) {
      return 'Versión de esquema no soportada: ${map['v']}.';
    }
    if (map['ver'] is! int || (map['ver'] as int) < 1) {
      return 'Revisión `ver` inválida en payload MLC1.';
    }
    if (map['iat'] is! int || (map['iat'] as int) <= 0) {
      return 'Timestamp `iat` inválido en payload MLC1.';
    }

    for (final strKey in ['sup', 'yh', 'yp']) {
      if (map[strKey] is! String) {
        return 'Campo textual inválido o faltante: "$strKey".';
      }
    }

    for (final bankKey in ['bcp', 'bbva']) {
      final bankVal = map[bankKey];
      if (bankVal is! Map) {
        return 'Estructura bancaria inválida en "$bankKey".';
      }
      for (final bk in bankVal.keys) {
        if (!_allowedBankKeys.contains(bk)) {
          return 'Clave no autorizada en $bankKey: "$bk".';
        }
      }
      for (final reqBank in _allowedBankKeys) {
        if (bankVal[reqBank] is! String) {
          return 'Campo bancario "$bankKey.$reqBank" debe ser String.';
        }
      }
    }

    final productsVal = map['p'];
    if (productsVal is! Map) {
      return 'Mapa de productos `p` inválido.';
    }
    for (final pid in _allowedProductIds) {
      if (!productsVal.containsKey(pid)) {
        return 'Falta producto requerido en `p`: "$pid".';
      }
    }
    for (final entry in productsVal.entries) {
      if (!_allowedProductIds.contains(entry.key)) {
        return 'Producto no autorizado en `p`: "${entry.key}".';
      }
      if (entry.value is! Map) {
        return 'Definición inválida de producto "${entry.key}".';
      }
      final prod = entry.value as Map;
      for (final pk in prod.keys) {
        if (!_allowedProductKeys.contains(pk)) {
          return 'Clave no autorizada en p.${entry.key}: "$pk".';
        }
      }
      final pr = prod['pr'];
      if (pr is! num || pr.toDouble().isNaN || pr.toDouble().isInfinite || pr < 0) {
        return 'Precio inválido en p.${entry.key}: $pr';
      }
      for (final intField in ['d', 'ai', 'um']) {
        final v = prod[intField];
        if (v is! int || v < 0) {
          return 'Campo entero inválido en p.${entry.key}.$intField: $v';
        }
      }
      if (prod['lb'] is! String || prod['ds'] is! String) {
        return 'Etiqueta/descripción inválida en p.${entry.key}.';
      }
    }
    return null;
  }

  /// Construye un resumen legible para UI desktop (`#modalCommercialConfigSync`) y respuestas API.
  Map<String, dynamic> buildSummaryFromPayload(Map<String, dynamic> payload) {
    final bcp = payload['bcp'] as Map? ?? const {};
    final bbva = payload['bbva'] as Map? ?? const {};
    final products = payload['p'] as Map? ?? const {};
    final orderedPlans = <Map<String, dynamic>>[];

    for (final id in catalogSlugToSyncId.values) {
      final p = products[id];
      if (p is Map) {
        orderedPlans.add({
          'id': id,
          'label': p['lb'] ?? id,
          'price': (p['pr'] as num?)?.toDouble() ?? 0.0,
          'days': (p['d'] as num?)?.toInt() ?? 0,
          'ai_credits': (p['ai'] as num?)?.toInt() ?? 0,
          'updates_months': (p['um'] as num?)?.toInt() ?? 0,
          'description': p['ds'] ?? '',
        });
      }
    }

    return {
      'revision': payload['ver'],
      'support_phone': payload['sup'] ?? '',
      'yape_holder': payload['yh'] ?? '',
      'yape_phone': payload['yp'] ?? '',
      'bcp_configured': (bcp['acc']?.toString().trim().isNotEmpty ?? false),
      'bcp': Map<String, dynamic>.from(bcp),
      'bbva_configured': (bbva['acc']?.toString().trim().isNotEmpty ?? false),
      'bbva': Map<String, dynamic>.from(bbva),
      'plans': orderedPlans,
    };
  }

  /// Construye resumen directamente desde un mapa `owner_config` usando [buildCanonicalPayload].
  Map<String, dynamic> buildSummaryFromConfig(
    Map<String, dynamic> config, {
    required int revision,
  }) {
    final safeRev = revision < 1 ? 1 : revision;
    final payload = buildCanonicalPayload(config, revision: safeRev);
    return buildSummaryFromPayload(payload);
  }

  static String _escapeDartSingleQuoted(String raw) {
    return raw
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\r', ' ')
        .replaceAll('\n', r'\n');
  }

  /// Genera código Dart limpio listo para copiar en `OwnerLegalIdentity` y defaults móviles
  /// cuando se compile una nueva versión APK.
  String generateOwnerLegalIdentityDartSnippet(
    Map<String, dynamic> config, {
    int? revision,
  }) {
    final li = config['legal_identity'] is Map
        ? Map<String, dynamic>.from(config['legal_identity'] as Map)
        : <String, dynamic>{};
    final pm = config['payment_methods'] is Map
        ? Map<String, dynamic>.from(config['payment_methods'] as Map)
        : <String, dynamic>{};
    final sys = config['system'] is Map
        ? Map<String, dynamic>.from(config['system'] as Map)
        : <String, dynamic>{};

    final effectiveRev = revision ??
        ((sys['commercial_sync_revision'] as num?)?.toInt() ?? 0);
    final payload = buildCanonicalPayload(
      config,
      revision: effectiveRev < 1 ? 1 : effectiveRev,
    );
    final bcp = payload['bcp'] as Map<String, dynamic>;
    final bbva = payload['bbva'] as Map<String, dynamic>;
    final products = payload['p'] as Map<String, dynamic>;

    final author = _escapeDartSingleQuoted(
      _sanitizeString(li['author_full_name'] ?? 'Julio Angello Vasquez Navarro'),
    );
    final commercialName = _escapeDartSingleQuoted(
      _sanitizeString(li['commercial_name'] ?? 'MochilaLista'),
    );
    final supportPhone = _escapeDartSingleQuoted(payload['sup'] as String);
    final cleanSupDigits =
        (payload['sup'] as String).replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappUrl = _escapeDartSingleQuoted(
      cleanSupDigits.isNotEmpty
          ? 'https://wa.me/$cleanSupDigits'
          : _sanitizeString(
              li['support_whatsapp_url'] ?? 'https://wa.me/51922836879',
            ),
    );
    final website = _escapeDartSingleQuoted(
      _sanitizeString(li['official_website'] ?? 'https://mochilalista.com'),
    );
    final legalFramework = _escapeDartSingleQuoted(
      _sanitizeString(
        li['legal_framework'] ??
            'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI',
      ),
    );
    final dataLaw = _escapeDartSingleQuoted(
      _sanitizeString(
        li['personal_data_law'] ??
            'Ley N° 29733 (Ley de Protección de Datos Personales)',
      ),
    );
    final yapeHolder = _escapeDartSingleQuoted(payload['yh'] as String);
    final yapePhone = _escapeDartSingleQuoted(payload['yp'] as String);
    final bcpHolder = _escapeDartSingleQuoted(bcp['h'] as String);
    final bcpAcc = _escapeDartSingleQuoted(bcp['acc'] as String);
    final bcpCci = _escapeDartSingleQuoted(bcp['cci'] as String);
    final bbvaHolder = _escapeDartSingleQuoted(bbva['h'] as String);
    final bbvaAcc = _escapeDartSingleQuoted(bbva['acc'] as String);
    final bbvaCci = _escapeDartSingleQuoted(bbva['cci'] as String);

    final buf = StringBuffer()
      ..writeln(
          '// Generado desde MochilaLista Admin (owner_config.json • Revisión MLC1 #$effectiveRev)')
      ..writeln(
          '// Pegar en: app_movil/lib/core/config/owner_legal_identity.dart')
      ..writeln("  static const int commercialSyncDefaultRevision = $effectiveRev;")
      ..writeln("  static const String authorFullName = '$author';")
      ..writeln("  static const String appCommercialName = '$commercialName';")
      ..writeln(
          "  static const String legalFrameworkNotice = '$legalFramework';")
      ..writeln("  static const String personalDataLawNotice = '$dataLaw';")
      ..writeln("  static const String supportPhone = '$supportPhone';")
      ..writeln("  static const String supportWhatsAppUrl = '$whatsappUrl';")
      ..writeln("  static const String officialWebsite = '$website';")
      ..writeln("  static const String yapePlinHolder = '$yapeHolder';")
      ..writeln("  static const String yapePlinPhone = '$yapePhone';")
      ..writeln("  static const String bcpAccountHolder = '$bcpHolder';")
      ..writeln("  static const String bcpAccountNumber = '$bcpAcc';")
      ..writeln("  static const String bcpCciNumber = '$bcpCci';")
      ..writeln("  static const String bbvaAccountHolder = '$bbvaHolder';")
      ..writeln("  static const String bbvaAccountNumber = '$bbvaAcc';")
      ..writeln("  static const String bbvaCciNumber = '$bbvaCci';")
      ..writeln('')
      ..writeln(
          '  /// Catálogo comercial por defecto compilado para nuevas versiones APK')
      ..writeln(
          '  static const Map<String, Map<String, Object>> defaultCommercialPlans = {');

    for (final id in catalogSlugToSyncId.values) {
      final p = products[id] as Map<String, dynamic>;
      final priceStr = ((p['pr'] as num).toDouble()).toStringAsFixed(2);
      final labelEsc = _escapeDartSingleQuoted(p['lb'] as String);
      final descEsc = _escapeDartSingleQuoted(p['ds'] as String);
      buf
        ..writeln("    '$id': {")
        ..writeln("      'pr': $priceStr,")
        ..writeln("      'd': ${p['d']},")
        ..writeln("      'ai': ${p['ai']},")
        ..writeln("      'um': ${p['um']},")
        ..writeln("      'lb': '$labelEsc',")
        ..writeln("      'ds': '$descEsc',")
        ..writeln('    },');
    }
    buf.writeln('  };');

    // Referencia explícita a pm para evitar advertencias en futuros refactors
    assert(pm.isEmpty || pm.isNotEmpty);
    return buf.toString();
  }
}
