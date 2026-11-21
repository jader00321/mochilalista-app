import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';

/// Resultado del análisis y validación criptográfica de un código de acceso
class LicenseValidationResult {
  final bool isValid;
  final String cleanCode;
  final Map<String, dynamic> payload;
  final String deviceFingerprint;
  final String plan;
  final int daysToAdd;
  final int nonce;
  final DateTime? updatesUntil;
  final int maxMajorVersion;
  final String? businessOwnerTag;
  final DateTime newExpiration;
  final int aiExtraCredits;

  const LicenseValidationResult({
    required this.isValid,
    required this.cleanCode,
    required this.payload,
    required this.deviceFingerprint,
    required this.plan,
    required this.daysToAdd,
    required this.nonce,
    this.updatesUntil,
    required this.maxMajorVersion,
    this.businessOwnerTag,
    required this.newExpiration,
    this.aiExtraCredits = 0,
  });
}

/// Validador Criptográfico Asimétrico Ed25519
/// La aplicación compila EXCLUSIVAMENTE la Clave Pública.
/// La Clave Privada reside únicamente en la Plataforma Admin de la laptop del autor.
class Ed25519LicenseValidator {
  /// Clave pública oficial Ed25519 de Julio Angello Vasquez Navarro (32 bytes)
  static const List<int> _defaultOfficialPublicKeyBytes = [
    0x0C, 0x05, 0xA0, 0x4E, 0x67, 0x20, 0x83, 0x1F,
    0xF7, 0x6E, 0xA0, 0x2F, 0x86, 0x13, 0x46, 0xC3,
    0xC3, 0x21, 0x45, 0x38, 0x35, 0xDD, 0x8D, 0x45,
    0xF4, 0xC0, 0x2F, 0x6C, 0xB1, 0x93, 0x59, 0xC0,
  ];

  static List<int>? _testPublicKeyBytes;

  /// Permite inyectar una clave pública generada en pruebas unitarias
  @visibleForTesting
  static void setTestPublicKey(List<int>? bytes) {
    _testPublicKeyBytes = bytes;
  }

  /// Clave pública activa para verificación asimétrica
  static List<int> get activePublicKeyBytes =>
      _testPublicKeyBytes ?? _defaultOfficialPublicKeyBytes;

  /// Decodifica cadenas Base64Url con o sin padding
  static Uint8List decodeBase64UrlSafe(String input) {
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return base64.decode(normalized);
  }

  /// Codifica en formato Base64Url sin padding
  static String encodeBase64UrlSafe(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Extrae el token criptográfico desde cualquier texto (mensajes completos de WhatsApp,
  /// con saludos, emojis, instrucciones, saltos de línea y padding '=').
  static String extractLicenseToken(String rawInput) {
    if (rawInput.trim().isEmpty) return '';

    // 1. Prioridad 1: Búsqueda explícita con prefijo oficial ML9-
    final explicitPattern = RegExp(
      r'ML9-([A-Za-z0-9_\-+=]{10,}\.[A-Za-z0-9_\-+=]{20,})',
      caseSensitive: false,
    );
    final explicitMatch = explicitPattern.firstMatch(rawInput);
    if (explicitMatch != null) {
      return explicitMatch.group(1)!;
    }

    // 2. Prioridad 2: Búsqueda del cuerpo criptográfico (Payload.Firma Ed25519 con base64/base64url y padding)
    final bodyPattern = RegExp(
      r'([A-Za-z0-9_\-+=]{10,}\.[A-Za-z0-9_\-+=]{20,})',
    );
    final bodyMatch = bodyPattern.firstMatch(rawInput);
    if (bodyMatch != null) {
      return bodyMatch.group(1)!;
    }

    // Sin fallback permisivo: si no contiene estructura criptográfica válida, retorna vacío.
    return '';
  }

  /// Extrae el token de activación exclusivo para el detector de portapapeles.
  /// Exige explícitamente el prefijo 'ML9-' seguido de la estructura 'Payload.Firma'
  /// para evitar falsos positivos con reportes de Google Drive, hashes SHA, Hardware IDs, etc.
  /// Retorna `ML9-payload.firma` canónico si coincide, o '' si no coincide.
  static String extractClipboardLicenseToken(String rawText) {
    if (rawText.trim().isEmpty) return '';

    final clipboardPattern = RegExp(
      r'ML9-([A-Za-z0-9_\-+=]{10,}\.[A-Za-z0-9_\-+=]{20,})',
      caseSensitive: false,
    );
    final match = clipboardPattern.firstMatch(rawText);
    if (match != null) {
      return 'ML9-${match.group(1)!}';
    }
    return '';
  }

  /// Limpia y normaliza el código ingresado delegando al extractor inteligente
  static String sanitizeCode(String rawCode) {
    return extractLicenseToken(rawCode);
  }

  /// Valida criptográficamente un token Ed25519 y comprueba las reglas de negocio
  static Future<LicenseValidationResult> validateAndParse({
    required String rawCode,
    required String currentDeviceFingerprint,
    required LicenseModel currentLicense,
    DateTime? overrideNow,
  }) async {
    final cleanCode = sanitizeCode(rawCode);
    final parts = cleanCode.split('.');

    if (parts.length != 2) {
      throw Exception(
        "Formato de código de acceso inválido. Debe contener payload y firma digital separados por un punto.",
      );
    }

    final Uint8List payloadBytes;
    final Uint8List signatureBytes;

    try {
      payloadBytes = decodeBase64UrlSafe(parts[0]);
    } catch (_) {
      throw Exception("El contenido de la licencia está corrupto o mal codificado.");
    }

    try {
      signatureBytes = decodeBase64UrlSafe(parts[1]);
    } catch (_) {
      throw Exception("La firma digital de la licencia está corrupta o mal codificada.");
    }

    if (signatureBytes.length != 64) {
      throw Exception("La firma digital no cumple con la longitud matemática Ed25519 (64 bytes requeridos).");
    }

    // 1. Verificación matemática estricta con Ed25519
    final ed25519 = Ed25519();
    final pubKey = SimplePublicKey(activePublicKeyBytes, type: KeyPairType.ed25519);
    final signature = Signature(signatureBytes, publicKey: pubKey);

    final isSignatureValid = await ed25519.verify(
      payloadBytes,
      signature: signature,
    );

    if (!isSignatureValid) {
      throw Exception(
        "Firma digital inválida. El código ha sido adulterado o no fue emitido por Julio Angello Vasquez Navarro.",
      );
    }

    // 2. Extracción y análisis del payload JSON
    final Map<String, dynamic> payload;
    try {
      final jsonStr = utf8.decode(payloadBytes);
      payload = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("El payload de la licencia no contiene un formato JSON válido.");
    }

    // 3. Comprobación de identidad de hardware (DeviceFingerprint)
    final tokenDeviceId = payload['d'] as String? ?? '';
    bool deviceMatches = (tokenDeviceId == currentDeviceFingerprint);
    if (!deviceMatches) {
      final legacy = await DeviceFingerprint.generateLegacy();
      if (tokenDeviceId == legacy) {
        deviceMatches = true;
      }
    }
    if (!deviceMatches) {
      throw Exception(
        "Este código pertenece al dispositivo '$tokenDeviceId', no a este teléfono ('$currentDeviceFingerprint').",
      );
    }

    // 4. Protección Anti-Replay por Nonce incremental
    final tokenNonce = (payload['n'] as num?)?.toInt() ?? 0;
    if (tokenNonce <= currentLicense.ultimoNonce) {
      throw Exception(
        "Este código ya fue canjeado previamente o contiene un correlativo vencido (Nonce $tokenNonce <= ${currentLicense.ultimoNonce}).",
      );
    }

    // 5. Cálculo de Renovación Anticipada Sin Pérdida de Días
    final now = overrideNow ?? DateTime.now();
    final plan = (payload['p'] as String? ?? 'MENSUAL').toUpperCase().trim();
    final daysToAdd = (payload['y'] as num?)?.toInt() ?? 30;
    int extraCredits = 0;
    if (payload['ai_extra'] is num) {
      extraCredits = (payload['ai_extra'] as num).toInt();
    } else if (payload['extra_ai'] is num) {
      extraCredits = (payload['extra_ai'] as num).toInt();
    } else if (payload['ai_credits'] is num) {
      extraCredits = (payload['ai_credits'] as num).toInt();
    } else if (payload['c'] is num) {
      extraCredits = (payload['c'] as num).toInt();
    }

    if (plan == 'RECARGA_IA_150' && extraCredits == 0) {
      extraCredits = 150;
    }

    // 5. Extracción y validación temporal de emisión ('iat' o alias 'e')
    DateTime? iat;
    if (payload['iat'] != null) {
      if (payload['iat'] is int) {
        final val = payload['iat'] as int;
        iat = val > 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(val, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true);
      } else {
        iat = DateTime.tryParse(payload['iat'].toString());
      }
    } else if (payload['e'] != null) {
      if (payload['e'] is int) {
        final val = payload['e'] as int;
        iat = val > 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(val, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true);
      } else {
        iat = DateTime.tryParse(payload['e'].toString());
      }
    }

    // 6. Cálculo de Expiración con Protección Anti-Replay y Renovación Anticipada
    final isPureAiRecharge =
        plan == 'RECARGA_IA_150' || plan == 'BONO_IA_PERSONALIZADO';
    if (plan == 'BONO_IA_PERSONALIZADO' && extraCredits <= 0) {
      throw Exception(
        'El bono de IA personalizado debe especificar una cantidad de escaneos mayor a 0.',
      );
    }

    // Detectar reactivación de hardware por migración (backup restaurado donde SQLite ya trae la fecha intacta y daysToAdd == 0)
    final isMigrationHardwareReactivation = (currentLicense.estadoActual ==
                'PENDIENTE_MIGRACION' ||
            (daysToAdd == 0 && currentLicense.fechaExpiracion.isAfter(now))) &&
        !isPureAiRecharge;

    DateTime newExpiration;
    if (isPureAiRecharge) {
      newExpiration = currentLicense.fechaExpiracion;
    } else if (isMigrationHardwareReactivation) {
      // En reactivación de migración con backup restaurado (y = 0), se preserva exactamente
      // la fecha de expiración que ya tiene registrada en su SQLite local sin duplicar días.
      newExpiration = currentLicense.fechaExpiracion;
    } else if (plan == 'PERPETUO_LIBERADO' || plan == 'PERPETUO') {
      newExpiration = now.add(const Duration(days: 99999));
    } else if (plan == 'PASE_ACTUALIZACION_ANUAL' || plan == 'EXTENSION_CORTESIA') {
      final isExpiredOrLocked = currentLicense.estadoActual == 'BLOQUEO_ESTRICTO' ||
          currentLicense.estadoActual == 'PENDIENTE_MIGRACION' ||
          currentLicense.fechaExpiracion.isBefore(now);
      final baseDate = (!isExpiredOrLocked && currentLicense.tipoPlan != 'TRIAL_VENCIDO')
          ? currentLicense.fechaExpiracion
          : now;
      newExpiration = baseDate.add(Duration(days: daysToAdd));
    } else {
      // Planes de suscripción temporal (MENSUAL, TRIMESTRAL, SEMESTRAL, ANUAL)
      final isCommercialActive = currentLicense.isActive && !currentLicense.isTrial;
      if (isCommercialActive) {
        // Regla Acumulativa: Si el usuario ya cuenta con suscripción comercial activa,
        // sus días vigentes NO se pierden, se suman a partir de la fecha de expiración actual.
        final baseDate = currentLicense.fechaExpiracion.isAfter(now)
            ? currentLicense.fechaExpiracion
            : now;
        newExpiration = baseDate.add(Duration(days: daysToAdd));
      } else {
        // Usuario en TRIAL o TRIAL_VENCIDO (instalación limpia tras desinstalar) o licencia expirada
        final isMigrationToken = payload['m'] == 1 ||
            payload['is_migration'] == true ||
            payload['m'] == true;
        if (isMigrationToken) {
          // Transferencia de licencia en instalación limpia: transfiere exactamente los días restantes solicitados
          newExpiration = now.add(Duration(days: daysToAdd));
        } else if (iat != null) {
          final maxExpirationFromIat = iat.add(Duration(days: daysToAdd));
          if (now.isAfter(maxExpirationFromIat)) {
            throw Exception(
              "Este código de licencia ya ha cumplido su periodo de vigencia contratado.",
            );
          }

          if (now.difference(iat) > const Duration(hours: 24)) {
            // Reinstalación / Recuperación de token de suscripción previa
            // La expiración se ancla estrictamente a la fecha de emisión original (iat + daysToAdd)
            newExpiration = maxExpirationFromIat;
          } else {
            // Compra recién emitida (<= 24h) canjeada en período de prueba:
            // Regla Acumulativa Comercial: los días restantes del trial se respetan y suman
            final baseDate = currentLicense.fechaExpiracion.isAfter(now)
                ? currentLicense.fechaExpiracion
                : now;
            newExpiration = baseDate.add(Duration(days: daysToAdd));
          }
        } else {
          // Retrocompatibilidad segura con tokens de prueba legacy sin claim 'iat'
          final baseDate = currentLicense.fechaExpiracion.isAfter(now)
              ? currentLicense.fechaExpiracion
              : now;
          newExpiration = baseDate.add(Duration(days: daysToAdd));
        }
      }
    }

    DateTime? updatesUntil;
    if (payload['u'] != null) {
      updatesUntil = DateTime.tryParse(payload['u'].toString());
    } else if (plan == 'PERPETUO_LIBERADO') {
      updatesUntil = now.add(const Duration(days: 365));
    }

    final maxMajor = (payload['v'] as num?)?.toInt() ?? 9;
    final businessTag = payload['b'] as String?;

    return LicenseValidationResult(
      isValid: true,
      cleanCode: cleanCode,
      payload: payload,
      deviceFingerprint: tokenDeviceId,
      plan: plan,
      daysToAdd: daysToAdd,
      nonce: tokenNonce,
      updatesUntil: updatesUntil,
      maxMajorVersion: maxMajor,
      businessOwnerTag: businessTag,
      newExpiration: newExpiration,
      aiExtraCredits: extraCredits,
    );
  }

  /// Evalúa si una versión instalada es válida para la licencia del comerciante
  /// - Hotfixes: Disponibles de por vida dentro de la versión mayor adquirida.
  /// - Feature Releases: Requieren suscripción activa o encontrarse dentro de la ventana updates_until.
  static bool isVersionAllowedForLicense({
    required LicenseModel license,
    required String currentAppVersion,
    required bool isHotfixOnly,
    DateTime? checkDate,
  }) {
    final now = checkDate ?? DateTime.now();

    // Extraer versión mayor (ejemplo: '2.5.0' -> 2)
    int currentMajor = 1;
    final versionParts = currentAppVersion.split('.');
    if (versionParts.isNotEmpty) {
      currentMajor = int.tryParse(versionParts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    }

    // Si supera la versión mayor autorizada por el token maestro:
    if (currentMajor > license.maxMajorVersion) {
      return false;
    }

    // Regla 1: Hotfix / Parche de Estabilidad
    if (isHotfixOnly) {
      return true; // Acceso vitalicio garantizado
    }

    // Regla 2: Feature Release / Nuevas Funciones
    if (license.isPerpetual) {
      if (license.updatesUntil == null) return false;
      return license.updatesUntil!.isAfter(now);
    }

    // Suscripciones activas
    return license.isActive && license.fechaExpiracion.isAfter(now);
  }

  /// Generador criptográfico de tokens para pruebas unitarias
  @visibleForTesting
  static Future<String> generateSignedTokenForTesting({
    required SimpleKeyPair keyPair,
    required Map<String, dynamic> payload,
    bool addMl9Prefix = false,
  }) async {
    final payloadJson = jsonEncode(payload);
    final payloadBytes = utf8.encode(payloadJson);

    final ed25519 = Ed25519();
    final signature = await ed25519.sign(
      payloadBytes,
      keyPair: keyPair,
    );

    final b64Payload = encodeBase64UrlSafe(payloadBytes);
    final b64Signature = encodeBase64UrlSafe(signature.bytes);

    final token = '$b64Payload.$b64Signature';
    return addMl9Prefix ? 'ML9-$token' : token;
  }
}
