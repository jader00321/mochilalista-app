import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Motor Firmador y Validador Ed25519 para la Plataforma Admin
class LicenseSigner {
  final Ed25519 _ed25519 = Ed25519();
  SimpleKeyPair? _keyPair;
  List<int>? _publicKeyBytes;
  String? _lastKeyPath;

  /// Carga la clave maestra privada desde el archivo físico
  Future<void> loadMasterKey({String keyPath = 'private_keys/ed25519_master.key'}) async {
    _lastKeyPath = keyPath;
    final file = File(keyPath);
    if (!await file.exists()) {
      throw Exception('No se encontró el archivo de clave privada en: $keyPath');
    }
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final seed = (data['seed'] as List).cast<int>();
    _keyPair = await _ed25519.newKeyPairFromSeed(seed);
    final pub = await _keyPair!.extractPublicKey();
    _publicKeyBytes = pub.bytes;
  }

  /// Recarga en memoria la clave privada y pública Ed25519 inmediatamente
  /// después de una importación .mlvault o auto-recuperación desde espejo,
  /// sin reiniciar server.dart.
  Future<void> reloadMasterKey({String? keyPath}) async {
    final path = keyPath ?? _lastKeyPath ?? 'private_keys/ed25519_master.key';
    await loadMasterKey(keyPath: path);
  }

  bool get isLoaded => _keyPair != null && _publicKeyBytes != null;

  /// Inicializa con una clave en memoria (útil para pruebas unitarias)
  Future<void> initWithSeed(List<int> seedBytes) async {
    _keyPair = await _ed25519.newKeyPairFromSeed(seedBytes);
    final pub = await _keyPair!.extractPublicKey();
    _publicKeyBytes = pub.bytes;
  }

  List<int> get publicKeyBytes {
    if (_publicKeyBytes == null) {
      throw StateError('La clave maestra no ha sido cargada.');
    }
    return _publicKeyBytes!;
  }

  /// Firma bytes arbitrarios usando la clave privada Ed25519 maestra (para tokens declarativos MLC1-).
  Future<List<int>> signRawMessage(List<int> messageBytes) async {
    if (_keyPair == null) {
      await loadMasterKey();
    }
    final sig = await _ed25519.sign(messageBytes, keyPair: _keyPair!);
    return sig.bytes;
  }

  static String encodeBase64UrlSafe(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Uint8List decodeBase64UrlSafe(String input) {
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return base64.decode(normalized);
  }

  /// Tabla oficial de cuota IA base acumulativa acreditada por plan comercial en app_movil
  static int getCumulativeScansForPlan(String planName) {
    switch (planName.toUpperCase().trim()) {
      case 'TRIAL':
        return 50;
      case 'MENSUAL':
        return 50;
      case 'TRIMESTRAL':
        return 180;
      case 'SEMESTRAL':
        return 450;
      case 'ANUAL':
        return 1200;
      case 'PERPETUO_LIBERADO':
      case 'PERPETUO':
      case 'PERPETUA':
        return 200;
      case 'PASE_ACTUALIZACION_ANUAL':
      case 'PASE_ANUAL_UPDATES':
      case 'PASE_UPDATES_12M':
        return 100;
      case 'RECARGA_IA_150':
        return 150;
      case 'EXTENSION_CORTESIA':
      default:
        return 0;
    }
  }

  /// Normaliza los slugs comerciales con tolerancia a alias oficiales
  static String normalizePlanSlug(String rawPlan) {
    final clean = rawPlan.toUpperCase().trim();
    if (clean == 'PASE_UPDATES_12M' || clean == 'PASE_ANUAL_UPDATES') {
      return 'PASE_ACTUALIZACION_ANUAL';
    }
    if (clean == 'PERPETUO' || clean == 'PERPETUA') {
      return 'PERPETUO_LIBERADO';
    }
    return clean;
  }

  /// Firma digitalmente un payload de licencia y devuelve el token completo `ML9-...`
  /// Aplica la regla estricta anti-doble conteo:
  /// - Para planes comerciales estándar, [aiExtraCredits] transporta ÚNICAMENTE el bono promocional adicional (0 por defecto).
  /// - Para RECARGA_IA_150, [aiExtraCredits] transporta 150 (o el monto especificado).
  Future<String> generateLicenseToken({
    required String deviceFingerprint,
    required String plan,
    required int daysToAdd,
    required int nonce,
    int maxMajorVersion = 9,
    DateTime? updatesUntil,
    String? businessTag,
    int aiExtraCredits = 0,
    bool addPrefix = true,
    bool isMigration = false,
  }) async {
    if (_keyPair == null) {
      await loadMasterKey();
    }

    final normalizedPlan = normalizePlanSlug(plan);

    final Map<String, dynamic> payload = {
      'd': deviceFingerprint.trim().toUpperCase(),
      'p': normalizedPlan,
      'y': daysToAdd,
      'n': nonce,
      'v': maxMajorVersion,
      'iat': DateTime.now().toUtc().toIso8601String(),
    };

    if (isMigration) {
      payload['m'] = 1;
    }

    // Regla anti-doble conteo en claim c:
    // Para RECARGA_IA_150, debe llevar mínimo 150 si aiExtraCredits <= 0
    int claimC = aiExtraCredits;
    if (normalizedPlan == 'RECARGA_IA_150' && claimC <= 0) {
      claimC = 150;
    }

    if (claimC > 0) {
      payload['ai_extra'] = claimC;
      payload['c'] = claimC;
    }
    if (updatesUntil != null) {
      payload['u'] = updatesUntil.toUtc().toIso8601String();
    }
    if (businessTag != null && businessTag.trim().isNotEmpty) {
      payload['b'] = businessTag.trim();
    }

    final jsonStr = jsonEncode(payload);
    final payloadBytes = utf8.encode(jsonStr);

    final signature = await _ed25519.sign(payloadBytes, keyPair: _keyPair!);
    final b64Payload = encodeBase64UrlSafe(payloadBytes);
    final b64Signature = encodeBase64UrlSafe(signature.bytes);

    final token = '$b64Payload.$b64Signature';
    return addPrefix ? 'ML9-$token' : token;
  }

  /// Valida la firma de un token contra la clave pública maestra
  Future<bool> verifyToken(String token) async {
    String clean = token.trim();
    if (clean.toUpperCase().startsWith('ML9-')) {
      clean = clean.substring(4);
    }
    final parts = clean.split('.');
    if (parts.length != 2) return false;

    try {
      final payloadBytes = decodeBase64UrlSafe(parts[0]);
      final signatureBytes = decodeBase64UrlSafe(parts[1]);
      if (signatureBytes.length != 64) return false;

      final pubKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(signatureBytes, publicKey: pubKey);
      return await _ed25519.verify(payloadBytes, signature: signature);
    } catch (_) {
      return false;
    }
  }

  /// Inspecciona y audita forensemente un código de licencia Ed25519
  Future<Map<String, dynamic>> inspectToken(String token) async {
    String clean = token.trim().replaceAll(RegExp(r'\s+'), '');
    if (!clean.toUpperCase().startsWith('ML9-')) {
      return {
        'valid': false,
        'isValid': false,
        'status': 'ERROR_FORMATO',
        'signature_verified': false,
        'signatureVerified': false,
        'message': 'Formato inválido: el token de MochilaLista debe iniciar con el prefijo "ML9-".',
        'error': 'Formato inválido: el token debe iniciar con el prefijo "ML9-".',
      };
    }
    clean = clean.substring(4);

    final parts = clean.split('.');
    if (parts.length != 2) {
      return {
        'valid': false,
        'isValid': false,
        'status': 'ERROR_FORMATO',
        'signature_verified': false,
        'signatureVerified': false,
        'message': 'Formato inválido: el token debe contener payload y firma digital separados por un punto.',
        'error': 'Formato inválido: el token debe contener payload y firma digital separados por un punto.',
      };
    }

    try {
      final payloadBytes = decodeBase64UrlSafe(parts[0]);
      final signatureBytes = decodeBase64UrlSafe(parts[1]);

      if (signatureBytes.length != 64) {
        return {
          'valid': false,
          'isValid': false,
          'status': 'FIRMA_CORRUPTA',
          'signature_verified': false,
          'signatureVerified': false,
          'message': 'Longitud de firma incorrecta (${signatureBytes.length} bytes, se requieren 64 bytes Ed25519).',
          'error': 'Firma criptográfica Ed25519 inválida o longitud incorrecta (${signatureBytes.length} bytes).',
        };
      }

      final jsonStr = utf8.decode(payloadBytes);
      final payload = jsonDecode(jsonStr) as Map<String, dynamic>;

      final pubKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(signatureBytes, publicKey: pubKey);
      final isSignatureValid = await _ed25519.verify(payloadBytes, signature: signature);

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

      final statusStr = isSignatureValid ? 'VÁLIDA' : 'FIRMA_INVÁLIDA';
      final msg = isSignatureValid
          ? 'Firma digital Ed25519 auténtica emitida por Julio Angello Vasquez Navarro.'
          : 'Firma digital NO coincide con la clave maestra privada oficial (token adulterado o clave desconocida).';

      final cleanPlan = normalizePlanSlug((payload['p'] as String? ?? '').toUpperCase());
      final planBaseAi = getCumulativeScansForPlan(cleanPlan);
      final totalAiReceived = (cleanPlan == 'RECARGA_IA_150' || cleanPlan == 'BONO_IA_PERSONALIZADO')
          ? (extraCredits > 0 ? extraCredits : (cleanPlan == 'RECARGA_IA_150' ? 150 : 0))
          : (planBaseAi + extraCredits);

      return {
        'valid': isSignatureValid,
        'isValid': isSignatureValid,
        'status': statusStr,
        'signature_verified': isSignatureValid,
        'signatureVerified': isSignatureValid,
        'message': msg,
        'error': isSignatureValid ? null : 'Firma criptográfica Ed25519 inválida o no coincide con la clave maestra.',
        'payload': payload,
        'device_id': (payload['d'] as String? ?? '').toUpperCase(),
        'deviceId': (payload['d'] as String? ?? '').toUpperCase(),
        'hardware_id_type': 'Settings.Secure.ANDROID_ID (Hardware Fingerprint)',
        'hardware_id_description': 'Identificador unívoco de instalación física ML-XXXX derivado de Settings.Secure.ANDROID_ID',
        'plan': cleanPlan,
        'days_added': (payload['y'] as num?)?.toInt() ?? 0,
        'daysAdded': (payload['y'] as num?)?.toInt() ?? 0,
        'nonce': (payload['n'] as num?)?.toInt() ?? 0,
        'max_major_version': (payload['v'] as num?)?.toInt() ?? 9,
        'minAppVersion': (payload['v'] as num?)?.toInt() ?? 9,
        'isPerpetual': cleanPlan.contains('PERPETU'),
        'expirationDate': payload['exp'] as String? ?? (payload['y'] != null ? 'calculada' : null),
        'emitted_at': payload['iat'] as String? ?? '',
        'updates_until': payload['u'] as String?,
        'business_tag': payload['b'] as String?,
        'client': payload['b'] as String?,
        'ai_extra_credits': extraCredits,
        'aiExtraCredits': extraCredits,
        'plan_base_ai_scans': planBaseAi,
        'bonus_ai_scans': extraCredits,
        'total_ai_scans_received_by_app': totalAiReceived,
        'raw_clean_code': clean,
      };
    } catch (e) {
      return {
        'valid': false,
        'isValid': false,
        'status': 'ERROR_DECODIFICACION',
        'signature_verified': false,
        'signatureVerified': false,
        'message': 'Error al decodificar payload Base64/JSON: ${e.toString()}',
        'error': 'Error de decodificación: ${e.toString()}',
      };
    }
  }
}
