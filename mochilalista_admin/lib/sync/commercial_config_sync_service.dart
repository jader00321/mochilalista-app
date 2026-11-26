import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/commercial_constants.dart';
import '../core/time_utils.dart';
import 'dart_defaults_exporter.dart';
import 'license_signer.dart';
import 'mlc1_payload_inspector.dart';

/// Excepción lanzada cuando un payload o token declarativo `MLC1-...` incumple
/// el esquema tipado, excede la cota de tamaño o posee rangos inválidos.
class CommercialConfigSyncException implements Exception {
  final String message;
  const CommercialConfigSyncException(this.message);

  @override
  String toString() => message;
}

/// Servicio emisor y verificador criptográfico declarativo `MLC1-...` (Plan Maestro 23 - Fase 3).
class CommercialConfigSyncService {
  static const String tokenPrefix = 'MLC1-';
  static const int schemaVersion = 1;
  static const int maxPayloadBytes = 8192;
  static const int maxTokenBytes = 8192;

  static const Map<String, String> catalogSlugToSyncId =
      CommercialConstants.catalogSlugToSyncId;

  final Ed25519 _ed25519 = Ed25519();

  /// Extrae un token `MLC1-...` desde mensajes completos de WhatsApp, texto libre o salida QR.
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

  /// Indica si la entrada apunta al protocolo `MLC1-` (incluso si está truncada o corrupta).
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
    final holder = DartDefaultsExporter.sanitizeString(
      nested?['holder'] ?? pm['${bankKey}_account_holder'] ?? '',
      maxLength: 120,
    );
    final acc = DartDefaultsExporter.sanitizeString(
      nested?['account'] ??
          nested?['number'] ??
          pm['${bankKey}_account_number'] ??
          '',
      maxLength: 60,
    );
    final cci = DartDefaultsExporter.sanitizeString(
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
    final phone = DartDefaultsExporter.sanitizeString(
      yapeNested?['phone'] ??
          yapeNested?['number'] ??
          pm['yape_plin_phone'] ??
          CommercialConstants.defaultYapePlinPhone,
      maxLength: 40,
    );
    final holder = DartDefaultsExporter.sanitizeString(
      yapeNested?['holder'] ??
          pm['yape_plin_holder'] ??
          li['author_full_name'] ??
          CommercialConstants.defaultAuthorName,
      maxLength: 120,
    );
    return {'phone': phone, 'holder': holder};
  }

  /// Construye el payload JSON canónico `v == 1` validando tipos, rangos y cota `<= 8192` bytes.
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
    final sup = DartDefaultsExporter.sanitizeString(
      li['support_phone'] ?? CommercialConstants.defaultSupportPhone,
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
      final parsedUm = _parseNonNegativeInt(
        rawEntry['updates_window_months'] ?? rawEntry['updates_months'],
        '$slug.updates_window_months',
        max: 1200,
        fallback: defaultUm,
      );
      final um = (defaultUm > 0 && parsedUm <= 0) ? defaultUm : parsedUm;
      final lb = DartDefaultsExporter.sanitizeString(
        rawEntry['label'] ?? slug,
        maxLength: 80,
      );
      final ds = DartDefaultsExporter.sanitizeString(
        rawEntry['description'] ?? '',
        maxLength: 180,
      );

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

  /// Firma el payload canónico `MLC1-...` usando separación de dominio explícita.
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

  /// Decodifica de forma segura (solo lectura diagnóstica) el payload de un token fallido.
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

  Map<String, dynamic> buildDiagnosticSummaryFromMap(
    Map<String, dynamic> rawMap,
  ) =>
      Mlc1PayloadInspector.buildDiagnosticSummaryFromMap(rawMap);

  Map<String, dynamic> buildCurrentConfigComparison(
    Map<String, dynamic> decodedPayload,
    Map<String, dynamic> currentConfig, {
    required int localRevision,
  }) =>
      Mlc1PayloadInspector.buildCurrentConfigComparison(
        decodedPayload: decodedPayload,
        currentConfig: currentConfig,
        localRevision: localRevision,
        buildSnapshot: (cfg, rev) => buildCanonicalPayload(cfg, revision: rev),
        buildFallbackSnapshot: (cfg) {
          final li = cfg['legal_identity'] is Map
              ? Map<String, dynamic>.from(cfg['legal_identity'] as Map)
              : <String, dynamic>{};
          final pm = cfg['payment_methods'] is Map
              ? Map<String, dynamic>.from(cfg['payment_methods'] as Map)
              : <String, dynamic>{};
          final yape = _extractYapePlin(pm, li);
          return {
            'sup': DartDefaultsExporter.sanitizeString(
              li['support_phone'] ?? '',
              maxLength: 40,
            ),
            'yh': yape['holder']!,
            'yp': yape['phone']!,
            'bcp': _extractPaymentAccountTriple(pm, 'bcp'),
            'bbva': _extractPaymentAccountTriple(pm, 'bbva'),
            'p': <String, dynamic>{},
          };
        },
      );

  String? validateDecodedPayloadSchema(dynamic decoded) =>
      Mlc1PayloadInspector.validateDecodedPayloadSchema(
        decoded,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> buildSummaryFromPayload(Map<String, dynamic> payload) =>
      Mlc1PayloadInspector.buildSummaryFromPayload(payload);

  Map<String, dynamic> buildSummaryFromConfig(
    Map<String, dynamic> config, {
    required int revision,
  }) {
    final safeRev = revision < 1 ? 1 : revision;
    final payload = buildCanonicalPayload(config, revision: safeRev);
    return buildSummaryFromPayload(payload);
  }

  String generateOwnerCommercialDefaultsDartFile(
    Map<String, dynamic> config, {
    int? revision,
  }) {
    final sys = config['system'] is Map
        ? Map<String, dynamic>.from(config['system'] as Map)
        : <String, dynamic>{};
    final effectiveRev =
        revision ?? ((sys['commercial_sync_revision'] as num?)?.toInt() ?? 0);
    final payload = buildCanonicalPayload(
      config,
      revision: effectiveRev < 1 ? 1 : effectiveRev,
    );
    return DartDefaultsExporter.renderOwnerCommercialDefaultsDartFile(
      config: config,
      canonicalPayload: payload,
      effectiveRevision: effectiveRev,
    );
  }

  String generateOwnerLegalIdentityDartSnippet(
    Map<String, dynamic> config, {
    int? revision,
  }) =>
      generateOwnerCommercialDefaultsDartFile(config, revision: revision);
}
