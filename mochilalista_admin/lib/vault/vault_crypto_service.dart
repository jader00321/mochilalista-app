import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';

import 'dpapi_service.dart';
import 'vault_crypto_models.dart';
import 'vault_package_codec.dart';

export 'vault_crypto_models.dart';

/// Motor Criptográfico de Cifrado de Sobre en 2 Niveles (Plan 10).
/// Administra la VMK (Nivel 1), 4 ranuras de desbloqueo y empaque `.mlvault`.
class VaultCryptoService {
  static const int kdfIterations = 100000;
  static const String rescueAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
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
  }) =>
      VaultPackageCodec.buildCanonicalAad(
        format: format,
        version: version,
        createdAt: createdAt,
        appVersion: appVersion,
        dbSchemaVersion: dbSchemaVersion,
        includesMasterKey: includesMasterKey,
      );

  // =================== NIVEL 1: GESTIÓN DE VMK Y LLAVERO ===================

  static Future<KeyringCreationResult> createInitialKeyring({
    required DpapiService dpapi,
  }) async {
    final vmk = _randomBytes(32);
    final protectedVmk = await dpapi.protect(vmk);
    if (protectedVmk == null) {
      throw VaultAuthException(
        'No se pudo proteger la VMK con el servicio DPAPI.',
      );
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

  static Future<String> enrollMlKeySlot(
    VaultKeyring keyring,
    Uint8List vmk,
  ) async {
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

    return const JsonEncoder.withIndent('  ').convert({
      'format': 'MLKEY',
      'version': '1.0.0',
      'owner': 'Julio Angello Vasquez Navarro',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'key_b64': keyB64,
      'checksum_sha256': checksum,
    });
  }

  static Future<RescueKitResult> enrollRescueKitSlots(
    VaultKeyring keyring,
    Uint8List vmk,
  ) async {
    final rnd = Random.secure();
    final codesReadable = <String>[];
    final codesData = <Map<String, dynamic>>[];

    final aesGcm = AesGcm.with256bits();

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

  static void disablePinSlot(VaultKeyring keyring) {
    keyring.keySlots['slot_4_pin'] = {
      'type': 'PIN_OPTIONAL',
      'enabled': false,
      'wrapped_vmk_b64': null,
    };
    keyring.updatedAt = DateTime.now().toUtc();
  }

  // =================== DESENVOLTURA DE VMK ===================

  static Future<Uint8List?> unwrapVmkWithDpapi(
    VaultKeyring keyring,
    DpapiService dpapi,
  ) async {
    final slot1 = keyring.keySlots['slot_1_dpapi'] as Map?;
    if (slot1 == null || slot1['wrapped_vmk_b64'] == null) return null;

    final protectedBytes = base64Decode(slot1['wrapped_vmk_b64'] as String);
    return await dpapi.unprotect(protectedBytes);
  }

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

    final iterations =
        (slot3['kdf_iterations'] as num?)?.toInt() ?? kdfIterations;
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
      } catch (_) {}
    }
    return null;
  }

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

  static Future<Uint8List?> unwrapVmkWithPin(
    VaultKeyring keyring,
    String pin,
  ) async {
    final slot4 = keyring.keySlots['slot_4_pin'] as Map?;
    if (slot4 == null ||
        slot4['enabled'] != true ||
        slot4['wrapped_vmk_b64'] == null) {
      return null;
    }

    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) return null;

    try {
      final salt = base64Decode(slot4['salt_b64'] as String);
      final nonce = base64Decode(slot4['nonce_b64'] as String);
      final tag = base64Decode(slot4['auth_tag_b64'] as String);
      final cipherText = base64Decode(slot4['wrapped_vmk_b64'] as String);
      final iterations =
          (slot4['kdf_iterations'] as num?)?.toInt() ?? kdfIterations;

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

  static Future<Uint8List?> _unwrapWithCredential(
    VaultKeyring keyring,
    VaultUnlockCredential credential,
    DpapiService? dpapi,
  ) async {
    switch (credential.type) {
      case VaultUnlockType.dpapi:
        if (dpapi == null) {
          throw VaultAuthException(
            'Servicio DPAPI no provisto para el desbloqueo.',
          );
        }
        return unwrapVmkWithDpapi(keyring, dpapi);
      case VaultUnlockType.mlKey:
        if (credential.secret == null) {
          throw VaultAuthException('Archivo .mlkey no provisto.');
        }
        return unwrapVmkWithMlKey(keyring, credential.secret!);
      case VaultUnlockType.rescueCode:
        if (credential.secret == null) {
          throw VaultAuthException('Código de rescate no provisto.');
        }
        return unwrapVmkWithRescueCode(keyring, credential.secret!);
      case VaultUnlockType.qrKey:
        if (credential.secret == null) {
          throw VaultAuthException('Clave QR de rescate no provista.');
        }
        return unwrapVmkWithQrKey(keyring, credential.secret!);
      case VaultUnlockType.pin:
        if (credential.secret == null) {
          throw VaultAuthException('PIN de acceso no provisto.');
        }
        return unwrapVmkWithPin(keyring, credential.secret!);
    }
  }

  // =================== NIVEL 2: EMPAQUETADO Y DESEMPAQUE .MLVAULT ===================

  static Future<String> exportVaultPackage({
    required VaultKeyring keyring,
    required Uint8List vmk,
    required VaultPayloadFiles files,
    required bool includeMasterKey,
    required Map<String, dynamic> stats,
    String appVersion = '9.41.0+85',
    int dbSchemaVersion = 36,
  }) =>
      VaultPackageCodec.exportVaultPackage(
        keyring: keyring,
        vmk: vmk,
        files: files,
        includeMasterKey: includeMasterKey,
        stats: stats,
        appVersion: appVersion,
        dbSchemaVersion: dbSchemaVersion,
      );

  static Map<String, dynamic> inspectVaultPackage(String vaultJson) =>
      VaultPackageCodec.inspectVaultPackage(vaultJson);

  static Future<VaultImportResult> importVaultPackage({
    required String vaultJson,
    required VaultUnlockCredential credential,
    DpapiService? dpapi,
  }) =>
      VaultPackageCodec.importVaultPackage(
        vaultJson: vaultJson,
        credential: credential,
        unwrapVmk: _unwrapWithCredential,
        dpapi: dpapi,
      );
}
