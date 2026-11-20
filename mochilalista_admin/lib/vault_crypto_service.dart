import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';
import 'dpapi_service.dart';

/// Excepciones formales del subsistema de Bóveda y Criptografía (Plan 10)
class VaultException implements Exception {
  final String message;
  VaultException(this.message);
  @override
  String toString() => 'VaultException: $message';
}

class VaultAuthException extends VaultException {
  VaultAuthException(super.message);
}

class VaultIntegrityException extends VaultException {
  VaultIntegrityException(super.message);
}

class VaultFormatException extends VaultException {
  VaultFormatException(super.message);
}

/// Modelo de Llavero Maestro (Formato MLKEYRING v1.1.0)
/// Custodia la VMK envuelta en las 4 ranuras independientes (Plan 10 - Sección 5.1).
/// La VMK JAMÁS se guarda en texto plano al serializar a JSON.
class VaultKeyring {
  final String format;
  final String version;
  DateTime updatedAt;
  final Map<String, dynamic> keySlots;

  VaultKeyring({
    this.format = 'MLKEYRING',
    this.version = '1.1.0',
    DateTime? updatedAt,
    required this.keySlots,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'updated_at': updatedAt.toIso8601String(),
        'key_slots': keySlots,
      };

  factory VaultKeyring.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'MLKEYRING' && json['format'] != 'MLVAULT') {
      throw VaultFormatException('Formato de llavero inválido: esperado MLKEYRING o MLVAULT');
    }
    return VaultKeyring(
      format: 'MLKEYRING',
      version: json['version'] as String? ?? '1.1.0',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now().toUtc(),
      keySlots: Map<String, dynamic>.from(json['key_slots'] as Map? ?? {}),
    );
  }
}

/// Resultado de inicialización del llavero que entrega la VMK temporalmente en memoria
class KeyringCreationResult {
  final VaultKeyring keyring;
  final Uint8List vmk;
  KeyringCreationResult({required this.keyring, required this.vmk});
}

/// Resultado de generación del Kit de Emergencia Imprimible
class RescueKitResult {
  final List<String> codes;
  final String qrKey;
  RescueKitResult({required this.codes, required this.qrKey});
}

/// Contenedor de archivos de producción a empaquetar en una bóveda
class VaultPayloadFiles {
  final String clientsJson;
  final String releasesJson;
  final String configJson;
  final String? masterKeyEd25519;

  VaultPayloadFiles({
    required this.clientsJson,
    required this.releasesJson,
    required this.configJson,
    this.masterKeyEd25519,
  });
}

/// Tipos de credenciales para desbloquear una bóveda
enum VaultUnlockType { dpapi, mlKey, rescueCode, qrKey, pin }

/// Credencial de desbloqueo provista para importar o abrir una bóveda
class VaultUnlockCredential {
  final VaultUnlockType type;
  final String? secret;

  VaultUnlockCredential.dpapi()
      : type = VaultUnlockType.dpapi,
        secret = null;

  VaultUnlockCredential.mlKey(String mlKey)
      : type = VaultUnlockType.mlKey,
        secret = mlKey;

  VaultUnlockCredential.rescueCode(String code)
      : type = VaultUnlockType.rescueCode,
        secret = code;

  VaultUnlockCredential.qrKey(String qr)
      : type = VaultUnlockType.qrKey,
        secret = qr;

  VaultUnlockCredential.pin(String pin)
      : type = VaultUnlockType.pin,
        secret = pin;
}

/// Resultado del desempaque e importación exitosa de una bóveda
class VaultImportResult {
  final VaultPayloadFiles files;
  final VaultKeyring keyring;
  final Uint8List vmk;
  final Map<String, dynamic> internalManifest;

  VaultImportResult({
    required this.files,
    required this.keyring,
    required this.vmk,
    required this.internalManifest,
  });
}

/// Motor Criptográfico de Cifrado de Sobre en 2 Niveles (Plan 10)
/// Administra la VMK (Nivel 1), DEK efímera (Nivel 2) y formato .mlvault con nonces y tags únicos.
class VaultCryptoService {
  static const int kdfIterations = 100000;
  static const String rescueAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  static String normalizeRescueCode(String rawCode) {
    String clean = rawCode
        .trim()
        .toUpperCase()
        .replaceAll(' ', '')
        .replaceAll('-', '');
    if (clean.startsWith('ML') && clean.length >= 14) {
      clean = clean.substring(2);
    }
    return clean;
  }

  static String buildCanonicalAad({
    required String format,
    required String version,
    required String createdAt,
    required String appVersion,
    required int dbSchemaVersion,
    required bool includesMasterKey,
  }) {
    return 'format=$format|version=$version|created_at=$createdAt|app_version=$appVersion|db_schema_version=$dbSchemaVersion|includes_master_key=$includesMasterKey';
  }

  // =================== NIVEL 1: GESTIÓN DE VMK Y LLAVERO ===================

  /// Inicializa un llavero nuevo generando una VMK de 256 bits y protegiéndola con DPAPI (Slot 1)
  static Future<KeyringCreationResult> createInitialKeyring({
    required DpapiService dpapi,
  }) async {
    final vmk = _randomBytes(32);
    final protectedVmk = await dpapi.protect(vmk);
    if (protectedVmk == null) {
      throw VaultAuthException('No se pudo proteger la VMK con el servicio DPAPI.');
    }

    final keySlots = <String, dynamic>{
      'slot_1_dpapi': {
        'type': 'WINDOWS_DPAPI_CURRENT_USER',
        'wrapped_vmk_b64': base64Encode(protectedVmk),
      },
      'slot_2_file': null,
      'slot_3_emergency': null,
      'slot_4_pin': {
        'type': 'PIN_OPTIONAL',
        'enabled': false,
        'wrapped_vmk_b64': null,
      },
    };

    final keyring = VaultKeyring(keySlots: keySlots);
    return KeyringCreationResult(keyring: keyring, vmk: vmk);
  }

  /// Registra el Archivo Llave Física (Slot 2) y retorna el JSON oficial de `llave_maestra_mochilalista.mlkey`
  static Future<String> enrollMlKeySlot(VaultKeyring keyring, Uint8List vmk) async {
    final kek = _randomBytes(32);
    final nonce = _randomBytes(12);

    final aesGcm = AesGcm.with256bits();
    final box = await aesGcm.encrypt(
      vmk,
      secretKey: SecretKey(kek),
      nonce: nonce,
    );

    keyring.keySlots['slot_2_file'] = {
      'type': 'MLKEY_FILE',
      'cipher': 'AES-256-GCM',
      'nonce_b64': base64Encode(nonce),
      'auth_tag_b64': base64Encode(box.mac.bytes),
      'wrapped_vmk_b64': base64Encode(box.cipherText),
    };
    keyring.updatedAt = DateTime.now().toUtc();

    final keyB64 = base64Encode(kek);
    final checksum = sha256.convert(utf8.encode(keyB64)).toString();

    final mlKeyJson = const JsonEncoder.withIndent('  ').convert({
      'format': 'MLKEY',
      'version': '1.0.0',
      'owner': 'Julio Angello Vasquez Navarro',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'key_b64': keyB64,
      'checksum_sha256': checksum,
    });

    return mlKeyJson;
  }

  /// Registra el Kit de Emergencia (8 Códigos Cortos + QR) en Slot 3
  static Future<RescueKitResult> enrollRescueKitSlots(
    VaultKeyring keyring,
    Uint8List vmk,
  ) async {
    final rnd = Random.secure();
    final codesReadable = <String>[];
    final codesData = <Map<String, dynamic>>[];

    final aesGcm = AesGcm.with256bits();

    // 1. Generar 8 códigos alfanuméricos cortos
    for (int i = 0; i < 8; i++) {
      final sb = StringBuffer('ML-');
      for (int g = 0; g < 3; g++) {
        for (int c = 0; c < 4; c++) {
          sb.write(rescueAlphabet[rnd.nextInt(rescueAlphabet.length)]);
        }
        if (g < 2) sb.write('-');
      }
      final codeStr = sb.toString();
      codesReadable.add(codeStr);

      final normalized = normalizeRescueCode(codeStr);
      final salt = _randomBytes(16);
      final nonce = _randomBytes(12);

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: kdfIterations,
        bits: 256,
      );
      final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(normalized)),
        nonce: salt,
      );
      final kekBytes = await secretKey.extractBytes();

      final box = await aesGcm.encrypt(
        vmk,
        secretKey: SecretKey(kekBytes),
        nonce: nonce,
      );

      codesData.add({
        'code_id': i + 1,
        'salt_b64': base64Encode(salt),
        'nonce_b64': base64Encode(nonce),
        'auth_tag_b64': base64Encode(box.mac.bytes),
        'wrapped_vmk_b64': base64Encode(box.cipherText),
      });
    }

    // 2. Generar slot para código QR
    final qrKek = _randomBytes(32);
    final qrNonce = _randomBytes(12);
    final qrBox = await aesGcm.encrypt(
      vmk,
      secretKey: SecretKey(qrKek),
      nonce: qrNonce,
    );

    final qrSlot = {
      'cipher': 'AES-256-GCM',
      'nonce_b64': base64Encode(qrNonce),
      'auth_tag_b64': base64Encode(qrBox.mac.bytes),
      'wrapped_vmk_b64': base64Encode(qrBox.cipherText),
    };

    keyring.keySlots['slot_3_emergency'] = {
      'type': 'RESCUE_CODES',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'kdf_iterations': kdfIterations,
      'codes': codesData,
      'qr_slot': qrSlot,
    };
    keyring.updatedAt = DateTime.now().toUtc();

    final qrKeyString = 'MLQR-${base64Url.encode(qrKek)}';
    return RescueKitResult(codes: codesReadable, qrKey: qrKeyString);
  }

  /// Registra o actualiza el PIN personal opcional en Slot 4
  static Future<void> enrollPinSlot(
    VaultKeyring keyring,
    Uint8List vmk,
    String pin,
  ) async {
    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      throw VaultException('El PIN no puede estar vacío.');
    }

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdfIterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(cleanPin)),
      nonce: salt,
    );
    final kekBytes = await secretKey.extractBytes();

    final aesGcm = AesGcm.with256bits();
    final box = await aesGcm.encrypt(
      vmk,
      secretKey: SecretKey(kekBytes),
      nonce: nonce,
    );

    keyring.keySlots['slot_4_pin'] = {
      'type': 'PIN_OPTIONAL',
      'enabled': true,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'kdf_iterations': kdfIterations,
      'salt_b64': base64Encode(salt),
      'nonce_b64': base64Encode(nonce),
      'auth_tag_b64': base64Encode(box.mac.bytes),
      'wrapped_vmk_b64': base64Encode(box.cipherText),
    };
    keyring.updatedAt = DateTime.now().toUtc();
  }

  /// Desactiva el PIN local opcional
  static void disablePinSlot(VaultKeyring keyring) {
    keyring.keySlots['slot_4_pin'] = {
      'type': 'PIN_OPTIONAL',
      'enabled': false,
      'wrapped_vmk_b64': null,
    };
    keyring.updatedAt = DateTime.now().toUtc();
  }

  // =================== DESENVOLTURA DE VMK ===================

  /// Desenvuelve la VMK usando el Slot 1 (DPAPI de Windows)
  static Future<Uint8List?> unwrapVmkWithDpapi(
    VaultKeyring keyring,
    DpapiService dpapi,
  ) async {
    final slot1 = keyring.keySlots['slot_1_dpapi'] as Map?;
    if (slot1 == null || slot1['wrapped_vmk_b64'] == null) return null;

    final protectedBytes = base64Decode(slot1['wrapped_vmk_b64'] as String);
    return await dpapi.unprotect(protectedBytes);
  }

  /// Desenvuelve la VMK usando el Slot 2 (Archivo .mlkey)
  static Future<Uint8List?> unwrapVmkWithMlKey(
    VaultKeyring keyring,
    String mlKeyInput,
  ) async {
    final slot2 = keyring.keySlots['slot_2_file'] as Map?;
    if (slot2 == null || slot2['wrapped_vmk_b64'] == null) return null;

    String keyB64 = mlKeyInput.trim();
    if (keyB64.startsWith('{')) {
      try {
        final parsed = jsonDecode(keyB64) as Map;
        if (parsed['format'] != 'MLKEY') return null;
        final claimedChecksum = parsed['checksum_sha256'] as String?;
        final rawKeyB64 = parsed['key_b64'] as String?;
        if (rawKeyB64 == null) return null;

        if (claimedChecksum != null) {
          final computed = sha256.convert(utf8.encode(rawKeyB64)).toString();
          if (computed != claimedChecksum) return null;
        }
        keyB64 = rawKeyB64;
      } catch (_) {
        return null;
      }
    }

    try {
      final kek = base64Decode(keyB64);
      final nonce = base64Decode(slot2['nonce_b64'] as String);
      final tag = base64Decode(slot2['auth_tag_b64'] as String);
      final cipherText = base64Decode(slot2['wrapped_vmk_b64'] as String);

      final aesGcm = AesGcm.with256bits();
      final clear = await aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(kek),
      );
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }

  /// Desenvuelve la VMK usando el Slot 3 con cualquiera de los 8 Códigos de Rescate
  static Future<Uint8List?> unwrapVmkWithRescueCode(
    VaultKeyring keyring,
    String rawCode,
  ) async {
    final slot3 = keyring.keySlots['slot_3_emergency'] as Map?;
    if (slot3 == null) return null;

    final codes = slot3['codes'] as List?;
    if (codes == null || codes.isEmpty) return null;

    final normalized = normalizeRescueCode(rawCode);
    if (normalized.isEmpty) return null;

    final iterations = (slot3['kdf_iterations'] as num?)?.toInt() ?? kdfIterations;
    final aesGcm = AesGcm.with256bits();

    for (final entry in codes) {
      if (entry is! Map) continue;
      try {
        final salt = base64Decode(entry['salt_b64'] as String);
        final nonce = base64Decode(entry['nonce_b64'] as String);
        final tag = base64Decode(entry['auth_tag_b64'] as String);
        final cipherText = base64Decode(entry['wrapped_vmk_b64'] as String);

        final pbkdf2 = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: iterations,
          bits: 256,
        );
        final secretKey = await pbkdf2.deriveKey(
          secretKey: SecretKey(utf8.encode(normalized)),
          nonce: salt,
        );
        final kekBytes = await secretKey.extractBytes();

        final clear = await aesGcm.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
          secretKey: SecretKey(kekBytes),
        );
        return Uint8List.fromList(clear);
      } catch (_) {
        // Continuar evaluando los demás slots de rescate
      }
    }
    return null;
  }

  /// Desenvuelve la VMK usando la clave QR de rescate
  static Future<Uint8List?> unwrapVmkWithQrKey(
    VaultKeyring keyring,
    String qrKeyString,
  ) async {
    final slot3 = keyring.keySlots['slot_3_emergency'] as Map?;
    if (slot3 == null) return null;

    final qrSlot = slot3['qr_slot'] as Map?;
    if (qrSlot == null || qrSlot['wrapped_vmk_b64'] == null) return null;

    var cleanKey = qrKeyString.trim();
    if (cleanKey.startsWith('MLQR-')) {
      cleanKey = cleanKey.substring(5);
    }

    try {
      final kek = base64Url.decode(cleanKey);
      final nonce = base64Decode(qrSlot['nonce_b64'] as String);
      final tag = base64Decode(qrSlot['auth_tag_b64'] as String);
      final cipherText = base64Decode(qrSlot['wrapped_vmk_b64'] as String);

      final aesGcm = AesGcm.with256bits();
      final clear = await aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(kek),
      );
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }

  /// Desenvuelve la VMK usando el PIN local opcional (Slot 4)
  static Future<Uint8List?> unwrapVmkWithPin(
    VaultKeyring keyring,
    String pin,
  ) async {
    final slot4 = keyring.keySlots['slot_4_pin'] as Map?;
    if (slot4 == null || slot4['enabled'] != true || slot4['wrapped_vmk_b64'] == null) {
      return null;
    }

    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) return null;

    try {
      final salt = base64Decode(slot4['salt_b64'] as String);
      final nonce = base64Decode(slot4['nonce_b64'] as String);
      final tag = base64Decode(slot4['auth_tag_b64'] as String);
      final cipherText = base64Decode(slot4['wrapped_vmk_b64'] as String);
      final iterations = (slot4['kdf_iterations'] as num?)?.toInt() ?? kdfIterations;

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );
      final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(cleanPin)),
        nonce: salt,
      );
      final kekBytes = await secretKey.extractBytes();

      final aesGcm = AesGcm.with256bits();
      final clear = await aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(kekBytes),
      );
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }

  /// Re-envuelve la misma VMK en un nuevo servicio DPAPI (migración a otra laptop)
  static Future<bool> rewrapVmkForNewDpapi(
    VaultKeyring keyring,
    Uint8List vmk,
    DpapiService newDpapi,
  ) async {
    final protectedVmk = await newDpapi.protect(vmk);
    if (protectedVmk == null) return false;

    keyring.keySlots['slot_1_dpapi'] = {
      'type': 'WINDOWS_DPAPI_CURRENT_USER',
      'wrapped_vmk_b64': base64Encode(protectedVmk),
    };
    keyring.updatedAt = DateTime.now().toUtc();
    return true;
  }

  // =================== NIVEL 2: EMPAQUETADO Y DESEMPAQUE .MLVAULT ===================

  /// Exporta una bóveda portable .mlvault cifrada con DEK efímera envuelta por la VMK
  static Future<String> exportVaultPackage({
    required VaultKeyring keyring,
    required Uint8List vmk,
    required VaultPayloadFiles files,
    required bool includeMasterKey,
    required Map<String, dynamic> stats,
    String appVersion = '9.30.0+74',
    int dbSchemaVersion = 36,
  }) async {
    final createdAt = DateTime.now().toUtc().toIso8601String();

    // 1. Manifiesto Interno de Integridad
    final clientsSha = sha256.convert(utf8.encode(files.clientsJson)).toString();
    final releasesSha = sha256.convert(utf8.encode(files.releasesJson)).toString();
    final configSha = sha256.convert(utf8.encode(files.configJson)).toString();
    final masterKeySha = (includeMasterKey && files.masterKeyEd25519 != null)
        ? sha256.convert(utf8.encode(files.masterKeyEd25519!)).toString()
        : null;

    final internalManifest = {
      'clients_sha256': clientsSha,
      'releases_sha256': releasesSha,
      'config_sha256': configSha,
      'master_key_sha256': masterKeySha,
      'stats': stats,
    };

    final payloadMap = {
      'internal_manifest': internalManifest,
      'files': {
        'prod_clients_db_json': files.clientsJson,
        'prod_releases_db_json': files.releasesJson,
        'owner_config_json': files.configJson,
        if (includeMasterKey && files.masterKeyEd25519 != null)
          'ed25519_master_key': files.masterKeyEd25519,
      },
    };

    final payloadUtf8 = utf8.encode(jsonEncode(payloadMap));
    final compressedPayload = gzip.encode(payloadUtf8);

    // 2. Generar DEK efímera de 256 bits
    final dek = _randomBytes(32);

    // 3. Cifrar Payload con DEK (AES-256-GCM + Nonce único + AAD Canónico)
    final canonicalAad = buildCanonicalAad(
      format: 'MLVAULT',
      version: '1.1.0',
      createdAt: createdAt,
      appVersion: appVersion,
      dbSchemaVersion: dbSchemaVersion,
      includesMasterKey: includeMasterKey,
    );
    final aadBytes = utf8.encode(canonicalAad);

    final payloadNonce = _randomBytes(12);
    final aesGcm = AesGcm.with256bits();
    final payloadBox = await aesGcm.encrypt(
      compressedPayload,
      secretKey: SecretKey(dek),
      nonce: payloadNonce,
      aad: aadBytes,
    );

    final ciphertextSha = sha256.convert(payloadBox.cipherText).toString();

    // 4. Envolver la DEK con la VMK (AES-256-GCM + Nonce único)
    final dekNonce = _randomBytes(12);
    final dekBox = await aesGcm.encrypt(
      dek,
      secretKey: SecretKey(vmk),
      nonce: dekNonce,
    );

    // 5. Estructurar el paquete final .mlvault (Sección 4.1)
    final vaultMap = {
      'format': 'MLVAULT',
      'version': '1.1.0',
      'created_at': createdAt,
      'app_version': appVersion,
      'db_schema_version': dbSchemaVersion,
      'includes_master_key': includeMasterKey,
      'stats': stats,
      'wrapped_dek_by_vmk': {
        'cipher': 'AES-256-GCM',
        'nonce_b64': base64Encode(dekNonce),
        'auth_tag_b64': base64Encode(dekBox.mac.bytes),
        'wrapped_key_b64': base64Encode(dekBox.cipherText),
      },
      'key_slots': keyring.keySlots,
      'payload_envelope': {
        'cipher': 'AES-256-GCM',
        'compression': 'GZIP',
        'nonce_b64': base64Encode(payloadNonce),
        'auth_tag_b64': base64Encode(payloadBox.mac.bytes),
        'ciphertext_sha256': ciphertextSha,
        'encrypted_payload_b64': base64Encode(payloadBox.cipherText),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(vaultMap);
  }

  /// Inspecciona los metadatos públicos de una bóveda sin descifrar
  static Map<String, dynamic> inspectVaultPackage(String vaultJson) {
    final parsed = jsonDecode(vaultJson) as Map<String, dynamic>;
    if (parsed['format'] != 'MLVAULT') {
      throw VaultFormatException('Formato de bóveda inválido: se esperaba MLVAULT.');
    }

    final slots = (parsed['key_slots'] as Map?) ?? {};
    return {
      'format': parsed['format'],
      'version': parsed['version'],
      'created_at': parsed['created_at'],
      'app_version': parsed['app_version'],
      'db_schema_version': parsed['db_schema_version'],
      'includes_master_key': parsed['includes_master_key'] == true,
      'has_master_key': parsed['includes_master_key'] == true,
      'stats': parsed['stats'] ?? {},
      'has_dpapi': slots['slot_1_dpapi']?['wrapped_vmk_b64'] != null,
      'has_mlkey': slots['slot_2_file']?['wrapped_vmk_b64'] != null,
      'has_emergency_codes': (slots['slot_3_emergency']?['codes'] as List?)?.isNotEmpty == true,
      'has_pin': slots['slot_4_pin']?['enabled'] == true,
      'available_slots': [
        if (slots['slot_1_dpapi']?['wrapped_vmk_b64'] != null) 'dpapi',
        if (slots['slot_2_file']?['wrapped_vmk_b64'] != null) 'mlkey',
        if ((slots['slot_3_emergency']?['codes'] as List?)?.isNotEmpty == true) 'rescue_code',
        if (slots['slot_4_pin']?['enabled'] == true) 'pin',
      ],
    };
  }

  /// Desempaqueta, valida integridad y restaura los archivos de una bóveda .mlvault
  static Future<VaultImportResult> importVaultPackage({
    required String vaultJson,
    required VaultUnlockCredential credential,
    DpapiService? dpapi,
  }) async {
    final parsed = jsonDecode(vaultJson) as Map<String, dynamic>;
    if (parsed['format'] != 'MLVAULT') {
      throw VaultFormatException('Formato de bóveda inválido: se esperaba MLVAULT.');
    }

    final envelope = parsed['payload_envelope'] as Map<String, dynamic>?;
    if (envelope == null) {
      throw VaultFormatException('Paquete de bóveda sin payload_envelope válido.');
    }

    final cipherText = base64Decode(envelope['encrypted_payload_b64'] as String);
    final claimedCiphertextSha = envelope['ciphertext_sha256'] as String?;
    if (claimedCiphertextSha != null) {
      final computedSha = sha256.convert(cipherText).toString();
      if (computedSha != claimedCiphertextSha) {
        throw VaultIntegrityException('Fallo de integridad: ciphertext_sha256 manipulado o alterado.');
      }
    }

    final keyring = VaultKeyring.fromJson(parsed);

    // 1. Desenvolver VMK según la credencial provista
    Uint8List? vmk;
    switch (credential.type) {
      case VaultUnlockType.dpapi:
        if (dpapi == null) throw VaultAuthException('Servicio DPAPI no provisto para el desbloqueo.');
        vmk = await unwrapVmkWithDpapi(keyring, dpapi);
        break;
      case VaultUnlockType.mlKey:
        if (credential.secret == null) throw VaultAuthException('Archivo .mlkey no provisto.');
        vmk = await unwrapVmkWithMlKey(keyring, credential.secret!);
        break;
      case VaultUnlockType.rescueCode:
        if (credential.secret == null) throw VaultAuthException('Código de rescate no provisto.');
        vmk = await unwrapVmkWithRescueCode(keyring, credential.secret!);
        break;
      case VaultUnlockType.qrKey:
        if (credential.secret == null) throw VaultAuthException('Clave QR de rescate no provista.');
        vmk = await unwrapVmkWithQrKey(keyring, credential.secret!);
        break;
      case VaultUnlockType.pin:
        if (credential.secret == null) throw VaultAuthException('PIN de acceso no provisto.');
        vmk = await unwrapVmkWithPin(keyring, credential.secret!);
        break;
    }

    if (vmk == null) {
      throw VaultAuthException('Credencial de desbloqueo inválida o rechazada por las ranuras de la bóveda.');
    }

    // 2. Desenvolver la DEK con la VMK
    final wrappedDek = parsed['wrapped_dek_by_vmk'] as Map<String, dynamic>?;
    if (wrappedDek == null) {
      throw VaultFormatException('Paquete de bóveda sin wrapped_dek_by_vmk válido.');
    }

    Uint8List dek;
    final aesGcm = AesGcm.with256bits();
    try {
      final dekNonce = base64Decode(wrappedDek['nonce_b64'] as String);
      final dekTag = base64Decode(wrappedDek['auth_tag_b64'] as String);
      final wrappedDekBytes = base64Decode(wrappedDek['wrapped_key_b64'] as String);

      final clearDek = await aesGcm.decrypt(
        SecretBox(wrappedDekBytes, nonce: dekNonce, mac: Mac(dekTag)),
        secretKey: SecretKey(vmk),
      );
      dek = Uint8List.fromList(clearDek);
    } catch (_) {
      throw VaultIntegrityException('Fallo al desenvolver la DEK con la VMK: tag o datos manipulados.');
    }

    // 3. Descifrar el Payload con la DEK y AAD Canónico
    final canonicalAad = buildCanonicalAad(
      format: parsed['format'] as String? ?? 'MLVAULT',
      version: parsed['version'] as String? ?? '1.1.0',
      createdAt: parsed['created_at'] as String? ?? '',
      appVersion: parsed['app_version'] as String? ?? '9.30.0+74',
      dbSchemaVersion: (parsed['db_schema_version'] as num?)?.toInt() ?? 36,
      includesMasterKey: parsed['includes_master_key'] == true,
    );
    final aadBytes = utf8.encode(canonicalAad);

    List<int> clearGzip;
    try {
      final payloadNonce = base64Decode(envelope['nonce_b64'] as String);
      final payloadTag = base64Decode(envelope['auth_tag_b64'] as String);

      clearGzip = await aesGcm.decrypt(
        SecretBox(cipherText, nonce: payloadNonce, mac: Mac(payloadTag)),
        secretKey: SecretKey(dek),
        aad: aadBytes,
      );
    } catch (_) {
      throw VaultIntegrityException('Fallo al descifrar el payload: AAD, nonce o tag inválido.');
    }

    // 4. Descomprimir GZIP y parsear Payload
    final clearJsonStr = utf8.decode(gzip.decode(clearGzip));
    final payloadMap = jsonDecode(clearJsonStr) as Map<String, dynamic>;

    final internalManifest = (payloadMap['internal_manifest'] as Map<String, dynamic>?) ?? {};
    final filesMap = (payloadMap['files'] as Map<String, dynamic>?) ?? {};

    final clientsJson = filesMap['prod_clients_db_json'] as String? ?? '[]';
    final releasesJson = filesMap['prod_releases_db_json'] as String? ?? '[]';
    final configJson = filesMap['owner_config_json'] as String? ?? '{}';
    final masterKey = filesMap['ed25519_master_key'] as String?;

    // 5. Verificación estricta de hashes contra internal_manifest
    if (sha256.convert(utf8.encode(clientsJson)).toString() != internalManifest['clients_sha256']) {
      throw VaultIntegrityException('Manifiesto interno corrompido: clients_sha256 no coincide.');
    }
    if (sha256.convert(utf8.encode(releasesJson)).toString() != internalManifest['releases_sha256']) {
      throw VaultIntegrityException('Manifiesto interno corrompido: releases_sha256 no coincide.');
    }
    if (sha256.convert(utf8.encode(configJson)).toString() != internalManifest['config_sha256']) {
      throw VaultIntegrityException('Manifiesto interno corrompido: config_sha256 no coincide.');
    }
    if (internalManifest['master_key_sha256'] != null) {
      if (masterKey == null ||
          sha256.convert(utf8.encode(masterKey)).toString() != internalManifest['master_key_sha256']) {
        throw VaultIntegrityException('Manifiesto interno corrompido: master_key_sha256 no coincide.');
      }
    }

    final payloadFiles = VaultPayloadFiles(
      clientsJson: clientsJson,
      releasesJson: releasesJson,
      configJson: configJson,
      masterKeyEd25519: masterKey,
    );

    return VaultImportResult(
      files: payloadFiles,
      keyring: keyring,
      vmk: vmk,
      internalManifest: internalManifest,
    );
  }
}
