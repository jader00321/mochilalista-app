import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';

/// Resultado inmutable de la verificación o aplicación de un token `MLC1-...`.
class CommercialConfigVerificationResult {
  final bool isValid;
  final String status;
  final String? error;
  final int? revision;
  final int? schemaVersion;
  final int? issuedAtUnix;
  final String? issuedAtLima;
  final String? appliedAtLima;
  final Map<String, dynamic>? payload;
  final String? cleanToken;

  const CommercialConfigVerificationResult({
    required this.isValid,
    required this.status,
    this.error,
    this.revision,
    this.schemaVersion,
    this.issuedAtUnix,
    this.issuedAtLima,
    this.appliedAtLima,
    this.payload,
    this.cleanToken,
  });

  factory CommercialConfigVerificationResult.invalid({
    required String status,
    required String error,
  }) {
    return CommercialConfigVerificationResult(
      isValid: false,
      status: status,
      error: error,
    );
  }
}

/// Instantánea persistida en `SharedPreferences` tras aplicar un token `MLC1-...` auténtico.
class CommercialSavedConfig {
  final int revision;
  final int issuedAtUnix;
  final int appliedAtUnix;
  final String issuedAtLima;
  final String appliedAtLima;
  final Map<String, dynamic> payload;

  const CommercialSavedConfig({
    required this.revision,
    required this.issuedAtUnix,
    required this.appliedAtUnix,
    required this.issuedAtLima,
    required this.appliedAtLima,
    required this.payload,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'revision': revision,
        'issued_at': issuedAtUnix,
        'applied_at': appliedAtUnix,
        'issued_at_lima': issuedAtLima,
        'applied_at_lima': appliedAtLima,
        'payload': payload,
      };
}

/// Receptor criptográfico offline y declarativo de configuraciones comerciales `MLC1-...`
/// (Plan Maestro 23 - Fase 4).
///
/// Garantías de seguridad:
/// - 100 % declarativo (solo JSON tipado de precios, cuotas IA, pagos y soporte; cero código).
/// - Verifica Ed25519 estrictamente con separación de dominio (`utf8.encode('MLC1-$payloadB64')`).
/// - Persistencia exclusiva en `SharedPreferences` (`ml_commercial_config_v1`), sin tocar SQLite v36.
/// - Guardia anti-downgrade monotónica por `(ver, iat)`.
class CommercialConfigSyncService {
  static const String prefsKey = 'ml_commercial_config_v1';
  static const String tokenPrefix = 'MLC1-';
  static const int schemaVersion = 1;
  static const int maxPayloadBytes = 8192;
  static const int maxTokenBytes = 8192;

  static const double maxPrice = 99999.0;
  static const int maxDays = 999999;
  static const int maxAiCredits = 1000000;
  static const int maxUpdatesMonths = 1200;
  static const int maxStringLength = 512;

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

  static const Set<String> allowedProductIds = {
    'mensual',
    'trimestral',
    'semestral',
    'anual',
    'perpetua',
    'bolsa_extra_ia',
    'pase_anual_updates',
    'migracion',
  };

  static final RegExp _controlCharsRegex = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  final Ed25519 _ed25519 = Ed25519();

  /// Extrae un token `MLC1-...` desde mensajes completos de WhatsApp, portapapeles o QR.
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

  /// Indica si el texto ingresado o escaneado apunta al protocolo `MLC1-`
  /// (incluso si está truncado o malformado) para evitar enviarlo al validador `ML9`.
  static bool looksLikeMlc1Input(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toUpperCase().startsWith(tokenPrefix)) return true;
    return extractMlc1Token(trimmed).isNotEmpty;
  }

  /// Formatea un timestamp UNIX UTC en hora oficial de Perú (`America/Lima`, UTC-5)
  /// con formato compacto `DD/MM/YYYY HH:mm`.
  static String formatLimaDateTime(int unixSeconds) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    );
    final lima = utc.subtract(const Duration(hours: 5));
    final d = lima.day.toString().padLeft(2, '0');
    final m = lima.month.toString().padLeft(2, '0');
    final y = lima.year.toString().padLeft(4, '0');
    final hh = lima.hour.toString().padLeft(2, '0');
    final mm = lima.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  static bool _hasInvalidControlChars(String value) {
    return value.length > maxStringLength || _controlCharsRegex.hasMatch(value);
  }

  /// Valida estrictamente el esquema tipado `v == 1`, rangos finitos y ausencia de claves desconocidas.
  static String? validateDecodedPayloadSchema(dynamic decoded) {
    if (decoded is! Map) {
      return 'El payload MLC1 debe ser un objeto JSON válido.';
    }

    for (final k in decoded.keys) {
      if (k is! String || !_allowedTopLevelKeys.contains(k)) {
        return 'Clave no autorizada en payload MLC1: "$k".';
      }
    }
    for (final reqKey in _allowedTopLevelKeys) {
      if (!decoded.containsKey(reqKey)) {
        return 'Falta clave requerida en payload MLC1: "$reqKey".';
      }
    }

    if (decoded['v'] is! int || decoded['v'] != schemaVersion) {
      return 'Versión de esquema MLC1 no soportada: ${decoded['v']}.';
    }
    if (decoded['ver'] is! int || (decoded['ver'] as int) < 1) {
      return 'Revisión `ver` inválida en payload MLC1.';
    }
    if (decoded['iat'] is! int || (decoded['iat'] as int) <= 0) {
      return 'Timestamp `iat` inválido en payload MLC1.';
    }

    for (final strKey in const ['sup', 'yh', 'yp']) {
      final v = decoded[strKey];
      if (v is! String || _hasInvalidControlChars(v)) {
        return 'Campo textual inválido o inseguro en "$strKey".';
      }
    }

    for (final bankKey in const ['bcp', 'bbva']) {
      final bankVal = decoded[bankKey];
      if (bankVal is! Map) {
        return 'Estructura bancaria inválida en "$bankKey".';
      }
      for (final bk in bankVal.keys) {
        if (bk is! String || !_allowedBankKeys.contains(bk)) {
          return 'Clave no autorizada en $bankKey: "$bk".';
        }
      }
      for (final reqBank in _allowedBankKeys) {
        final v = bankVal[reqBank];
        if (v is! String || _hasInvalidControlChars(v)) {
          return 'Campo bancario inválido en "$bankKey.$reqBank".';
        }
      }
    }

    final productsVal = decoded['p'];
    if (productsVal is! Map) {
      return 'Mapa de productos `p` inválido.';
    }
    for (final pid in allowedProductIds) {
      if (!productsVal.containsKey(pid)) {
        return 'Falta producto requerido en `p`: "$pid".';
      }
    }
    for (final entry in productsVal.entries) {
      final key = entry.key;
      if (key is! String || !allowedProductIds.contains(key)) {
        return 'Producto no autorizado en `p`: "$key".';
      }
      if (entry.value is! Map) {
        return 'Definición inválida de producto "$key".';
      }
      final prod = entry.value as Map;
      for (final pk in prod.keys) {
        if (pk is! String || !_allowedProductKeys.contains(pk)) {
          return 'Clave no autorizada en p.$key: "$pk".';
        }
      }
      for (final reqPk in _allowedProductKeys) {
        if (!prod.containsKey(reqPk)) {
          return 'Falta campo requerido en p.$key: "$reqPk".';
        }
      }

      final pr = prod['pr'];
      if (pr is! num) {
        return 'Precio inválido en p.$key: $pr';
      }
      final prDouble = pr.toDouble();
      if (prDouble.isNaN ||
          prDouble.isInfinite ||
          prDouble < 0 ||
          prDouble > maxPrice) {
        return 'Precio fuera de rango en p.$key ($prDouble).';
      }

      final d = prod['d'];
      if (d is! int || d < 0 || d > maxDays) {
        return 'Campo entero inválido en p.$key.d: $d';
      }
      final ai = prod['ai'];
      if (ai is! int || ai < 0 || ai > maxAiCredits) {
        return 'Campo entero inválido en p.$key.ai: $ai';
      }
      final um = prod['um'];
      if (um is! int || um < 0 || um > maxUpdatesMonths) {
        return 'Campo entero inválido en p.$key.um: $um';
      }

      final lb = prod['lb'];
      final ds = prod['ds'];
      if (lb is! String ||
          ds is! String ||
          _hasInvalidControlChars(lb) ||
          _hasInvalidControlChars(ds)) {
        return 'Etiqueta o descripción inválida en p.$key.';
      }
    }

    return null;
  }

  /// Lee y valida defensivamente la configuración comercial aplicada en `SharedPreferences`.
  Future<CommercialSavedConfig?> getSavedConfig({
    SharedPreferences? prefs,
  }) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final raw = sp.getString(prefsKey);
      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final payload = decoded['payload'];
      if (validateDecodedPayloadSchema(payload) != null) return null;
      final payloadMap = Map<String, dynamic>.from(payload as Map);

      final revision =
          (decoded['revision'] as num?)?.toInt() ??
          (payloadMap['ver'] as num).toInt();
      final issuedAt =
          (decoded['issued_at'] as num?)?.toInt() ??
          (payloadMap['iat'] as num).toInt();
      final appliedAt = (decoded['applied_at'] as num?)?.toInt() ?? issuedAt;

      return CommercialSavedConfig(
        revision: revision,
        issuedAtUnix: issuedAt,
        appliedAtUnix: appliedAt,
        issuedAtLima: formatLimaDateTime(issuedAt),
        appliedAtLima: formatLimaDateTime(appliedAt),
        payload: payloadMap,
      );
    } catch (_) {
      return null;
    }
  }

  /// Verifica un token `MLC1-...` offline usando firma Ed25519 con separación de dominio,
  /// esquema estricto y guardia anti-downgrade, SIN persistir cambios todavía.
  Future<CommercialConfigVerificationResult> parseAndVerifyToken(
    String rawInput, {
    bool checkDowngrade = true,
    List<int>? publicKeyBytes,
    SharedPreferences? prefs,
  }) async {
    final extracted = extractMlc1Token(rawInput);
    final clean = extracted.isNotEmpty ? extracted : rawInput.trim();

    if (clean.isEmpty || !clean.startsWith(tokenPrefix)) {
      return CommercialConfigVerificationResult.invalid(
        status: 'INVALID_PREFIX',
        error: 'El código de configuración debe iniciar con "$tokenPrefix".',
      );
    }

    final cleanBytes = utf8.encode(clean);
    if (cleanBytes.length > maxTokenBytes) {
      return CommercialConfigVerificationResult.invalid(
        status: 'EXCEEDS_MAX_SIZE',
        error:
            'La ficha MLC1 excede el tamaño máximo permitido ($maxTokenBytes bytes).',
      );
    }

    final body = clean.substring(tokenPrefix.length);
    final parts = body.split('.');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return CommercialConfigVerificationResult.invalid(
        status: 'INVALID_FORMAT',
        error:
            'Formato MLC1 inválido: se esperaba MLC1-<payload>.<firma>.',
      );
    }

    final payloadB64 = parts[0];
    final sigB64 = parts[1];

    final Uint8List payloadBytes;
    final Uint8List sigBytes;
    try {
      payloadBytes = Ed25519LicenseValidator.decodeBase64UrlSafe(payloadB64);
      sigBytes = Ed25519LicenseValidator.decodeBase64UrlSafe(sigB64);
    } catch (_) {
      return CommercialConfigVerificationResult.invalid(
        status: 'BASE64_DECODE_ERROR',
        error: 'Codificación Base64Url inválida en el token MLC1.',
      );
    }

    if (payloadBytes.length > maxPayloadBytes) {
      return CommercialConfigVerificationResult.invalid(
        status: 'EXCEEDS_MAX_SIZE',
        error:
            'El payload decodificado excede el límite de $maxPayloadBytes bytes.',
      );
    }
    if (sigBytes.length != 64) {
      return CommercialConfigVerificationResult.invalid(
        status: 'INVALID_SIGNATURE_LENGTH',
        error:
            'Longitud de firma Ed25519 inválida (${sigBytes.length} bytes; se requieren 64).',
      );
    }

    final keyBytes =
        publicKeyBytes ?? Ed25519LicenseValidator.activePublicKeyBytes;
    final pubKey = SimplePublicKey(keyBytes, type: KeyPairType.ed25519);

    // Separación de dominio explícita frente a licencias ML9: `utf8.encode('MLC1-$payloadB64')`
    final domainMessage = utf8.encode('$tokenPrefix$payloadB64');
    final isSigValid = await _ed25519.verify(
      domainMessage,
      signature: Signature(sigBytes, publicKey: pubKey),
    );
    if (!isSigValid) {
      return CommercialConfigVerificationResult.invalid(
        status: 'INVALID_SIGNATURE',
        error:
            'Firma digital Ed25519 inválida: esta ficha no es auténtica o fue alterada.',
      );
    }

    dynamic decodedJson;
    try {
      decodedJson = jsonDecode(utf8.decode(payloadBytes));
    } catch (_) {
      return CommercialConfigVerificationResult.invalid(
        status: 'INVALID_JSON',
        error: 'El contenido de la ficha MLC1 no es JSON UTF-8 válido.',
      );
    }

    final schemaError = validateDecodedPayloadSchema(decodedJson);
    if (schemaError != null) {
      return CommercialConfigVerificationResult.invalid(
        status: 'INVALID_SCHEMA',
        error: schemaError,
      );
    }

    final payloadMap = Map<String, dynamic>.from(decodedJson as Map);
    final ver = payloadMap['ver'] as int;
    final iat = payloadMap['iat'] as int;

    if (checkDowngrade) {
      final saved = await getSavedConfig(prefs: prefs);
      if (saved != null &&
          (ver < saved.revision ||
              (ver == saved.revision && iat < saved.issuedAtUnix))) {
        return CommercialConfigVerificationResult.invalid(
          status: 'DOWNGRADE_REJECTED',
          error:
              'Esta ficha de tarifas es más antigua que la que ya tienes aplicada (Rev. #${saved.revision}).',
        );
      }
    }

    return CommercialConfigVerificationResult(
      isValid: true,
      status: 'VALID',
      revision: ver,
      schemaVersion: payloadMap['v'] as int,
      issuedAtUnix: iat,
      issuedAtLima: formatLimaDateTime(iat),
      payload: payloadMap,
      cleanToken: clean,
    );
  }

  /// Verifica un token `MLC1-...` y lo persiste de forma atómica en `SharedPreferences`.
  Future<CommercialConfigVerificationResult> applyVerifiedToken(
    String rawInput, {
    List<int>? publicKeyBytes,
    SharedPreferences? prefs,
    DateTime? nowUtc,
  }) async {
    final verified = await parseAndVerifyToken(
      rawInput,
      checkDowngrade: true,
      publicKeyBytes: publicKeyBytes,
      prefs: prefs,
    );
    if (!verified.isValid || verified.payload == null) {
      return verified;
    }

    final sp = prefs ?? await SharedPreferences.getInstance();
    final appliedAtUnix =
        ((nowUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch / 1000)
            .floor();
    final issuedAtLima = verified.issuedAtLima ?? '';
    final appliedAtLima = formatLimaDateTime(appliedAtUnix);

    final record = CommercialSavedConfig(
      revision: verified.revision!,
      issuedAtUnix: verified.issuedAtUnix!,
      appliedAtUnix: appliedAtUnix,
      issuedAtLima: issuedAtLima,
      appliedAtLima: appliedAtLima,
      payload: verified.payload!,
    );

    await sp.setString(prefsKey, jsonEncode(record.toJson()));

    return CommercialConfigVerificationResult(
      isValid: true,
      status: 'VALID',
      revision: verified.revision,
      schemaVersion: verified.schemaVersion,
      issuedAtUnix: verified.issuedAtUnix,
      issuedAtLima: issuedAtLima,
      appliedAtLima: appliedAtLima,
      payload: verified.payload,
      cleanToken: verified.cleanToken,
    );
  }

  /// Elimina la ficha personalizada de `SharedPreferences`, regresando a los valores compilados.
  Future<void> resetToCompiledDefaults({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(prefsKey);
  }
}
