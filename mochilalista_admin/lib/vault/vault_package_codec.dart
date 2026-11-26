import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';

import '../core/time_utils.dart';
import 'dpapi_service.dart';
import 'vault_crypto_models.dart';

typedef VaultVmkUnwrapper = Future<Uint8List?> Function(
  VaultKeyring keyring,
  VaultUnlockCredential credential,
  DpapiService? dpapi,
);

/// Empaquetador y verificador de bóvedas portables `.mlvault` (Nivel 2: DEK efímera + GZIP + AAD).
class VaultPackageCodec {
  VaultPackageCodec._();

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
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

  /// Exporta una bóveda portable `.mlvault` cifrada con DEK efímera envuelta por la VMK.
  static Future<String> exportVaultPackage({
    required VaultKeyring keyring,
    required Uint8List vmk,
    required VaultPayloadFiles files,
    required bool includeMasterKey,
    required Map<String, dynamic> stats,
    String appVersion = '9.41.0+85',
    int dbSchemaVersion = 36,
  }) async {
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final clientsSha =
        sha256.convert(utf8.encode(files.clientsJson)).toString();
    final releasesSha =
        sha256.convert(utf8.encode(files.releasesJson)).toString();
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

    final dek = _randomBytes(32);

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

    final dekNonce = _randomBytes(12);
    final dekBox = await aesGcm.encrypt(
      dek,
      secretKey: SecretKey(vmk),
      nonce: dekNonce,
    );

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

  /// Inspecciona los metadatos públicos de una bóveda sin descifrar.
  static Map<String, dynamic> inspectVaultPackage(String vaultJson) {
    final parsed = jsonDecode(vaultJson) as Map<String, dynamic>;
    if (parsed['format'] != 'MLVAULT') {
      throw VaultFormatException(
        'Formato de bóveda inválido: se esperaba MLVAULT.',
      );
    }

    final rawStats = parsed['stats'] is Map
        ? Map<String, dynamic>.from(parsed['stats'] as Map)
        : <String, dynamic>{};
    final clientsCount = (rawStats['clients_count'] as num?)?.toInt() ??
        (rawStats['total_clients'] as num?)?.toInt() ??
        0;
    final releasesCount = (rawStats['releases_count'] as num?)?.toInt() ?? 0;
    rawStats['clients_count'] = clientsCount;
    rawStats['releases_count'] = releasesCount;

    final includesKey = parsed['includes_master_key'] == true;
    final createdAtRaw = parsed['created_at'] as String?;

    final slots = (parsed['key_slots'] as Map?) ?? {};
    return {
      'format': parsed['format'],
      'version': parsed['version'],
      'created_at': createdAtRaw,
      'created_at_lima': PeruTimeHelper.formatLimaDateTime(
        createdAtRaw,
        fallback: '-',
      ),
      'app_version': parsed['app_version'],
      'db_schema_version': parsed['db_schema_version'],
      'includes_master_key': includesKey,
      'includes_private_key': includesKey,
      'has_master_key': includesKey,
      'stats': rawStats,
      'has_dpapi': slots['slot_1_dpapi']?['wrapped_vmk_b64'] != null,
      'has_mlkey': slots['slot_2_file']?['wrapped_vmk_b64'] != null,
      'has_emergency_codes':
          (slots['slot_3_emergency']?['codes'] as List?)?.isNotEmpty == true,
      'has_pin': slots['slot_4_pin']?['enabled'] == true,
      'available_slots': [
        if (slots['slot_1_dpapi']?['wrapped_vmk_b64'] != null) 'dpapi',
        if (slots['slot_2_file']?['wrapped_vmk_b64'] != null) 'mlkey',
        if ((slots['slot_3_emergency']?['codes'] as List?)?.isNotEmpty == true)
          'rescue_code',
        if (slots['slot_4_pin']?['enabled'] == true) 'pin',
      ],
    };
  }

  /// Desempaqueta, valida integridad y restaura los archivos de una bóveda `.mlvault`.
  static Future<VaultImportResult> importVaultPackage({
    required String vaultJson,
    required VaultUnlockCredential credential,
    required VaultVmkUnwrapper unwrapVmk,
    DpapiService? dpapi,
  }) async {
    final parsed = jsonDecode(vaultJson) as Map<String, dynamic>;
    if (parsed['format'] != 'MLVAULT') {
      throw VaultFormatException(
        'Formato de bóveda inválido: se esperaba MLVAULT.',
      );
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
        throw VaultIntegrityException(
          'Fallo de integridad: ciphertext_sha256 manipulado o alterado.',
        );
      }
    }

    final keyring = VaultKeyring.fromJson(parsed);
    final vmk = await unwrapVmk(keyring, credential, dpapi);

    if (vmk == null) {
      throw VaultAuthException(
        'Credencial de desbloqueo inválida o rechazada por las ranuras de la bóveda.',
      );
    }

    final wrappedDek = parsed['wrapped_dek_by_vmk'] as Map<String, dynamic>?;
    if (wrappedDek == null) {
      throw VaultFormatException(
        'Paquete de bóveda sin wrapped_dek_by_vmk válido.',
      );
    }

    Uint8List dek;
    final aesGcm = AesGcm.with256bits();
    try {
      final dekNonce = base64Decode(wrappedDek['nonce_b64'] as String);
      final dekTag = base64Decode(wrappedDek['auth_tag_b64'] as String);
      final wrappedDekBytes =
          base64Decode(wrappedDek['wrapped_key_b64'] as String);

      final clearDek = await aesGcm.decrypt(
        SecretBox(wrappedDekBytes, nonce: dekNonce, mac: Mac(dekTag)),
        secretKey: SecretKey(vmk),
      );
      dek = Uint8List.fromList(clearDek);
    } catch (_) {
      throw VaultIntegrityException(
        'Fallo al desenvolver la DEK con la VMK: tag o datos manipulados.',
      );
    }

    final canonicalAad = buildCanonicalAad(
      format: parsed['format'] as String? ?? 'MLVAULT',
      version: parsed['version'] as String? ?? '1.1.0',
      createdAt: parsed['created_at'] as String? ?? '',
      appVersion: parsed['app_version'] as String? ?? '9.41.0+85',
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
      throw VaultIntegrityException(
        'Fallo al descifrar el payload: AAD, nonce o tag inválido.',
      );
    }

    final clearJsonStr = utf8.decode(gzip.decode(clearGzip));
    final payloadMap = jsonDecode(clearJsonStr) as Map<String, dynamic>;

    final internalManifest =
        (payloadMap['internal_manifest'] as Map<String, dynamic>?) ?? {};
    final filesMap = (payloadMap['files'] as Map<String, dynamic>?) ?? {};

    final clientsJson = filesMap['prod_clients_db_json'] as String? ?? '[]';
    final releasesJson = filesMap['prod_releases_db_json'] as String? ?? '[]';
    final configJson = filesMap['owner_config_json'] as String? ?? '{}';
    final masterKey = filesMap['ed25519_master_key'] as String?;

    if (sha256.convert(utf8.encode(clientsJson)).toString() !=
        internalManifest['clients_sha256']) {
      throw VaultIntegrityException(
        'Manifiesto interno corrompido: clients_sha256 no coincide.',
      );
    }
    if (sha256.convert(utf8.encode(releasesJson)).toString() !=
        internalManifest['releases_sha256']) {
      throw VaultIntegrityException(
        'Manifiesto interno corrompido: releases_sha256 no coincide.',
      );
    }
    if (sha256.convert(utf8.encode(configJson)).toString() !=
        internalManifest['config_sha256']) {
      throw VaultIntegrityException(
        'Manifiesto interno corrompido: config_sha256 no coincide.',
      );
    }
    if (internalManifest['master_key_sha256'] != null) {
      if (masterKey == null ||
          sha256.convert(utf8.encode(masterKey)).toString() !=
              internalManifest['master_key_sha256']) {
        throw VaultIntegrityException(
          'Manifiesto interno corrompido: master_key_sha256 no coincide.',
        );
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
