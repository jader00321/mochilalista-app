import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' hide Hmac;

import '../core/time_utils.dart';
import 'dpapi_service.dart';
import 'vault_crypto_service.dart';

/// Auditor de salud e integridad SHA-256 de los 5 archivos críticos y espejos de la bóveda.
class VaultIntegrityAuditor {
  VaultIntegrityAuditor._();

  static const Map<String, Map<String, String>> criticalFileDescriptors = {
    'clients_db': {
      'name': 'Cartera de Clientes',
      'path': 'data/prod_clients_db.json',
      'purpose': 'Base comercial de clientes, hardware IDs y pagos',
    },
    'releases_db': {
      'name': 'Catálogo de Lanzamientos',
      'path': 'data/prod_releases_db.json',
      'purpose': 'Historial de versiones APK, hashes SHA-256 y notas',
    },
    'owner_config': {
      'name': 'Centro de Personalización',
      'path': 'data/owner_config.json',
      'purpose': 'Tarifario oficial, bolsas IA, plantillas WhatsApp y cuentas',
    },
    'master_key': {
      'name': 'Firma Digital Privada Ed25519',
      'path': 'private_keys/ed25519_master.key',
      'purpose':
          'Clave asimétrica oficial para firmar licencias ML9 y fichas MLC1',
    },
    'vault_keyring': {
      'name': 'Llavero de Bóveda Multi-Slot',
      'path': 'data/vault_keyring.json',
      'purpose': 'Llavero AES-256-GCM con los 4 factores de desbloqueo',
    },
  };

  static Future<Map<String, dynamic>> getFileStat(
    File file, {
    String? purpose,
  }) async {
    final exists = await file.exists();
    if (!exists) {
      return {
        'exists': false,
        'path': file.path,
        'purpose': purpose,
        'size_bytes': 0,
        'modified': null,
        'modified_lima': '-',
        'last_modified': null,
        'sha256': null,
      };
    }
    final stat = await file.stat();
    String? fileSha;
    try {
      final bytes = await file.readAsBytes();
      fileSha = sha256.convert(bytes).toString();
    } catch (_) {}

    final utcIso = stat.modified.toUtc().toIso8601String();
    return {
      'exists': true,
      'path': file.path,
      'purpose': purpose,
      'size_bytes': stat.size,
      'modified': utcIso,
      'modified_lima': PeruTimeHelper.formatLimaDateTime(
        stat.modified,
        fallback: '-',
      ),
      'last_modified': utcIso,
      'sha256': fileSha,
    };
  }

  static Future<Map<String, dynamic>> checkStorageHealth({
    required String projectRootDir,
    required String mirrorDir,
    required File clientsDbFile,
    required File releasesDbFile,
    required File ownerConfigFile,
    required File masterKeyFile,
    required File keyringFile,
    required File mirrorVaultFile,
    required File mirrorKeyringFile,
    required File mirrorManifestFile,
    required VaultKeyring? keyring,
    required String? cloudPath,
  }) async {
    final clientsStat = await getFileStat(
      clientsDbFile,
      purpose: criticalFileDescriptors['clients_db']!['purpose'],
    );
    final releasesStat = await getFileStat(
      releasesDbFile,
      purpose: criticalFileDescriptors['releases_db']!['purpose'],
    );
    final configStat = await getFileStat(
      ownerConfigFile,
      purpose: criticalFileDescriptors['owner_config']!['purpose'],
    );
    final keyStat = await getFileStat(
      masterKeyFile,
      purpose: criticalFileDescriptors['master_key']!['purpose'],
    );
    final keyringStat = await getFileStat(
      keyringFile,
      purpose: criticalFileDescriptors['vault_keyring']!['purpose'],
    );

    final mirrorExists = await Directory(mirrorDir).exists();
    final mirrorVaultExists = await mirrorVaultFile.exists();
    final mirrorKeyringExists = await mirrorKeyringFile.exists();
    final mirrorManifestExists = await mirrorManifestFile.exists();

    DateTime? mirrorLastSync;
    int? mirrorSizeBytes;
    String? mirrorSha256;

    if (mirrorVaultExists) {
      final stat = await mirrorVaultFile.stat();
      mirrorLastSync = stat.modified;
      mirrorSizeBytes = stat.size;
      try {
        final bytes = await mirrorVaultFile.readAsBytes();
        mirrorSha256 = sha256.convert(bytes).toString();
      } catch (_) {}
    }

    bool cloudAccessible = false;
    bool cloudVaultExists = false;
    DateTime? cloudLastSync;
    int? cloudSizeBytes;

    if (cloudPath != null && cloudPath.isNotEmpty) {
      final cloudDir = Directory(cloudPath);
      if (await cloudDir.exists()) {
        cloudAccessible = true;
        final cloudVault =
            File('${cloudDir.path}/MochilaLista_Backup_Sync.mlvault');
        if (await cloudVault.exists()) {
          cloudVaultExists = true;
          final stat = await cloudVault.stat();
          cloudLastSync = stat.modified;
          cloudSizeBytes = stat.size;
        }
      }
    }

    final slots = keyring?.keySlots ?? {};
    final dpapiEnrolled = slots['slot_1_dpapi'] != null &&
        slots['slot_1_dpapi']['wrapped_vmk_b64'] != null;
    final mlkeyEnrolled = slots['slot_2_file'] != null &&
        slots['slot_2_file']['wrapped_vmk_b64'] != null;
    final rescueKitEnrolled = slots['slot_3_emergency'] != null &&
        (slots['slot_3_emergency']['codes'] as List?)?.isNotEmpty == true;
    final pinEnabled =
        slots['slot_4_pin'] != null && slots['slot_4_pin']['enabled'] == true;

    final bool missingLocalData = (!clientsStat['exists'] ||
            clientsStat['size_bytes'] == 0 ||
            clientsStat['size_bytes'] == 2) ||
        (!keyStat['exists'] || keyStat['size_bytes'] == 0);
    final bool recoveryAvailable =
        missingLocalData && mirrorVaultExists && (mirrorSizeBytes ?? 0) > 0;

    final int activeFactorsCount = (dpapiEnrolled ? 1 : 0) +
        (mlkeyEnrolled ? 1 : 0) +
        (rescueKitEnrolled ? 1 : 0) +
        (pinEnabled ? 1 : 0);
    final int securityScore = activeFactorsCount * 25;
    final bool mirrorActive = mirrorExists && mirrorVaultExists;
    final bool cloudMirrorActive = cloudAccessible && cloudVaultExists;

    String overallStatus = 'healthy';
    if (recoveryAvailable) {
      overallStatus = 'recovery_mode';
    } else if (!dpapiEnrolled || !mirrorVaultExists || securityScore < 50) {
      overallStatus = 'warning';
    }

    return {
      'status': overallStatus,
      'recovery_available': recoveryAvailable,
      'security_score': securityScore,
      'active_factors_count': activeFactorsCount,
      'total_factors_count': 4,
      'mirror_active': mirrorActive,
      'cloud_mirror_active': cloudMirrorActive,
      'primary_storage_path': '$projectRootDir/data',
      'mirror_storage_path': mirrorDir,
      'mirror_exists': mirrorExists,
      'cloud_sync_path': cloudPath,
      'pin_enabled': pinEnabled,
      'keyring_info': {
        'active_slots': [
          if (dpapiEnrolled) 'dpapi',
          if (mlkeyEnrolled) 'mlkey',
          if (rescueKitEnrolled) 'rescue_code',
          if (pinEnabled) 'pin',
        ],
      },
      'files': {
        'clients_db': clientsStat,
        'releases_db': releasesStat,
        'owner_config': configStat,
        'master_key': keyStat,
        'vault_keyring': keyringStat,
      },
      'mirror': {
        'mirror_dir': mirrorDir,
        'mirror_exists': mirrorExists,
        'mlvault_exists': mirrorVaultExists,
        'keyring_exists': mirrorKeyringExists,
        'manifest_exists': mirrorManifestExists,
        'last_sync': mirrorLastSync?.toUtc().toIso8601String(),
        'last_sync_lima': mirrorLastSync != null
            ? PeruTimeHelper.formatLimaDateTime(mirrorLastSync, fallback: '')
            : null,
        'size_bytes': mirrorSizeBytes,
        'ciphertext_sha256': mirrorSha256,
      },
      'cloud': {
        'configured': cloudPath != null && cloudPath.isNotEmpty,
        'cloud_path': cloudPath,
        'accessible': cloudAccessible,
        'mlvault_exists': cloudVaultExists,
        'last_sync': cloudLastSync?.toUtc().toIso8601String(),
        'last_sync_lima': cloudLastSync != null
            ? PeruTimeHelper.formatLimaDateTime(cloudLastSync, fallback: '')
            : null,
        'size_bytes': cloudSizeBytes,
      },
      'factors': {
        'dpapi_enrolled': dpapiEnrolled,
        'mlkey_enrolled': mlkeyEnrolled,
        'rescue_kit_enrolled': rescueKitEnrolled,
        'pin_enabled': pinEnabled,
      },
    };
  }

  static Future<Map<String, dynamic>> runFullIntegrityAudit({
    required Map<String, dynamic> health,
    required VaultKeyring? keyring,
    required Uint8List? cachedVmk,
    required DpapiService dpapiService,
    required File mirrorVaultFile,
    required File mirrorKeyringFile,
  }) async {
    final factors = health['factors'] as Map<String, dynamic>;
    final files = Map<String, dynamic>.from(health['files'] as Map);
    final mirror = Map<String, dynamic>.from(health['mirror'] as Map);
    final cloud = Map<String, dynamic>.from(health['cloud'] as Map);

    final bool dpapiEnrolled = factors['dpapi_enrolled'] == true;
    final bool mlkeyEnrolled = factors['mlkey_enrolled'] == true;
    final bool rescueKitEnrolled = factors['rescue_kit_enrolled'] == true;
    final bool pinEnabled = factors['pin_enabled'] == true;

    bool dpapiUnwrapOk = false;
    if (keyring != null && dpapiEnrolled) {
      try {
        final unwrapped =
            await VaultCryptoService.unwrapVmkWithDpapi(keyring, dpapiService);
        dpapiUnwrapOk = unwrapped != null;
      } catch (_) {
        dpapiUnwrapOk = false;
      }
    }

    Map<String, dynamic>? mirrorInternalManifest;
    bool mirrorDecryptOk = false;
    String? mirrorDecryptError;

    if (await mirrorVaultFile.exists()) {
      try {
        final vaultJson = await mirrorVaultFile.readAsString();
        VaultImportResult? imported;
        if (dpapiUnwrapOk) {
          imported = await VaultCryptoService.importVaultPackage(
            vaultJson: vaultJson,
            credential: VaultUnlockCredential.dpapi(),
            dpapi: dpapiService,
          );
        } else if (cachedVmk != null) {
          mirrorDecryptError =
              'DPAPI no pudo desenvolver la VMK automáticamente para inspección en caliente.';
        }
        if (imported != null) {
          mirrorDecryptOk = true;
          mirrorInternalManifest = imported.internalManifest;
        }
      } catch (e) {
        mirrorDecryptOk = false;
        mirrorDecryptError = e.toString();
      }
    }

    String? mirrorKeyringSha;
    if (await mirrorKeyringFile.exists()) {
      try {
        final bytes = await mirrorKeyringFile.readAsBytes();
        mirrorKeyringSha = sha256.convert(bytes).toString();
      } catch (_) {}
    }

    const Map<String, String> manifestHashKeys = {
      'clients_db': 'clients_sha256',
      'releases_db': 'releases_sha256',
      'owner_config': 'config_sha256',
      'master_key': 'master_key_sha256',
    };

    final Map<String, dynamic> auditedFiles = {};
    int matchedFilesCount = 0;

    for (final entry in criticalFileDescriptors.entries) {
      final key = entry.key;
      final desc = entry.value;
      final stat = Map<String, dynamic>.from(
        (files[key] as Map?) ?? <String, dynamic>{},
      );
      final bool localExists = stat['exists'] == true;
      final String? localSha = stat['sha256'] as String?;

      String? mirrorSha;
      if (key == 'vault_keyring') {
        mirrorSha = mirrorKeyringSha;
      } else if (mirrorInternalManifest != null) {
        mirrorSha = mirrorInternalManifest[manifestHashKeys[key]] as String?;
      }

      bool parity = false;
      String parityStatus;
      if (!localExists && mirrorSha == null) {
        parityStatus = 'NOT_CREATED';
      } else if (!localExists && mirrorSha != null) {
        parityStatus = 'MISSING_LOCAL';
      } else if (localExists && mirrorSha == null) {
        parityStatus =
            mirrorDecryptOk ? 'MISSING_IN_MIRROR' : 'MIRROR_UNAVAILABLE';
      } else if (localSha == mirrorSha) {
        parity = true;
        parityStatus = 'MATCH';
        matchedFilesCount++;
      } else {
        parityStatus = 'DIVERGENT';
      }

      auditedFiles[key] = {
        ...stat,
        'key': key,
        'label': desc['name'],
        'relative_path': desc['path'],
        'purpose': desc['purpose'],
        'mirror_sha256': mirrorSha,
        'mirror_parity': parity,
        'parity_status': parityStatus,
      };
    }

    final recommendations = <String>[];
    if (!dpapiEnrolled || !dpapiUnwrapOk) {
      recommendations.add(
        'Windows DPAPI no responde para tu sesión actual; verifica el llavero o re-envuelve la VMK importando desde tu .mlkey.',
      );
    }
    if (!mlkeyEnrolled) {
      recommendations.add(
        'Descarga tu Archivo Llave Física (.mlkey) en el Paso 2 y guárdalo en una memoria USB o teléfono para habilitar mudanzas.',
      );
    }
    if (!rescueKitEnrolled) {
      recommendations.add(
        'Genera e imprime tu Kit de Rescate (8 Códigos + QR) en el Paso 3 para tener respaldo físico desconectado de internet.',
      );
    }
    if (!pinEnabled) {
      recommendations.add(
        'Opcional: activa el PIN local de consola (Factor 4) si compartes tu equipo con otras personas.',
      );
    }
    if (mirror['mlvault_exists'] != true) {
      recommendations.add(
        'Aún no existe auto_mirror_latest.mlvault en el espejo; pulsa "Sincronizar Espejo" ahora.',
      );
    } else if (matchedFilesCount < criticalFileDescriptors.length) {
      recommendations.add(
        'Algunos archivos locales difieren o faltan frente al espejo; ejecuta "Sincronizar Espejo" para igualar las huellas SHA-256.',
      );
    }
    if (cloud['configured'] != true) {
      recommendations.add(
        'Recomendado: vincula una carpeta de Google Drive, Dropbox u OneDrive en el Paso 1 como respaldo externo en la nube.',
      );
    } else if (cloud['accessible'] != true) {
      recommendations.add(
        'La carpeta de Nube Local configurada (${cloud['cloud_path']}) no es accesible en disco; revisa su ruta.',
      );
    } else if (cloud['mlvault_exists'] != true) {
      recommendations.add(
        'La carpeta de nube está vinculada pero aún no contiene MochilaLista_Backup_Sync.mlvault; pulsa "Sincronizar Espejo".',
      );
    }

    final nowUtc = DateTime.now().toUtc();
    return {
      'ok': true,
      'audited_at': nowUtc.toIso8601String(),
      'audited_at_lima': PeruTimeHelper.formatLimaDateTime(nowUtc, fallback: '-'),
      'status': health['status'],
      'recovery_available': health['recovery_available'],
      'security_score': health['security_score'],
      'active_factors_count': health['active_factors_count'],
      'total_factors_count': health['total_factors_count'],
      'cloud_mirror_active': health['cloud_mirror_active'],
      'factors': factors,
      'dpapi': {
        'enrolled': dpapiEnrolled,
        'unwrap_ok': dpapiUnwrapOk,
        'valid': dpapiEnrolled && dpapiUnwrapOk,
      },
      'keyring': {
        'exists': auditedFiles['vault_keyring']?['exists'] == true,
        'valid': keyring != null,
        'format': keyring?.format,
        'version': keyring?.version,
        'updated_at': keyring?.updatedAt.toIso8601String(),
        'updated_at_lima': keyring != null
            ? PeruTimeHelper.formatLimaDateTime(keyring.updatedAt, fallback: '-')
            : '-',
        'active_slots': health['keyring_info']?['active_slots'] ?? <String>[],
      },
      'mirror': {
        ...mirror,
        'decrypt_ok': mirrorDecryptOk,
        'decrypt_error': mirrorDecryptError,
        'all_files_matched':
            matchedFilesCount == criticalFileDescriptors.length,
      },
      'cloud': cloud,
      'files': auditedFiles,
      'matched_files_count': matchedFilesCount,
      'total_critical_files': criticalFileDescriptors.length,
      'recommendations': recommendations,
    };
  }
}
