import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' hide Hmac;

import 'config_service.dart';
import 'database_service.dart';
import 'dpapi_service.dart';
import 'license_signer.dart';
import 'time_utils.dart';
import 'vault_crypto_service.dart';

/// Servicio de Doble Almacenamiento Cifrado y Auto-Recuperación (Plan 10 - Pilar 2)
/// Gestiona la persistencia fuera del repositorio (%APPDATA%\MochilaListaAdminVault),
/// la sincronización atómica con carpetas de nube local (Dropbox/GDrive/OneDrive),
/// la auto-recuperación ante borrados y el bloqueo/desbloqueo de sesión PIN.
class VaultStorageService {
  final String projectRootDir;
  final String mirrorDir;
  final DpapiService dpapiService;
  final DatabaseService dbService;
  final ConfigService configService;
  final LicenseSigner signer;

  // VMK resguardada estrictamente en memoria RAM volátil tras unwrap (cero texto plano en disco)
  Uint8List? _cachedVmk;
  VaultKeyring? _keyring;

  // Control de sesión PIN y protección anti-fuerza bruta
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;
  final Set<String> _validSessionTokens = {};

  VaultStorageService({
    this.projectRootDir = '.',
    String? mirrorDir,
    DpapiService? dpapiService,
    required this.dbService,
    required this.configService,
    required this.signer,
  })  : mirrorDir = mirrorDir ?? defaultMirrorDirectory(),
        dpapiService = dpapiService ?? WindowsDpapiService();

  /// Ruta predeterminada del espejo en el sistema operativo
  static String defaultMirrorDirectory() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return '$appData\\MochilaListaAdminVault';
    }
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return '$userProfile\\.mochilalista_admin_vault';
    }
    return 'data/vault_mirror';
  }

  // Rutas dentro del proyecto local
  File get keyringFile => File('$projectRootDir/data/vault_keyring.json');
  File get settingsFile => File('$projectRootDir/data/vault_settings.json');
  File get clientsDbFile => File('$projectRootDir/data/prod_clients_db.json');
  File get releasesDbFile => File('$projectRootDir/data/prod_releases_db.json');
  File get ownerConfigFile => File('$projectRootDir/data/owner_config.json');
  File get masterKeyFile => File('$projectRootDir/private_keys/ed25519_master.key');
  Directory get backupsDirectory => Directory('$projectRootDir/backups');

  // Rutas en el directorio espejo
  File get mirrorVaultFile => File('$mirrorDir/auto_mirror_latest.mlvault');
  File get mirrorKeyringFile => File('$mirrorDir/vault_keyring.json');
  File get mirrorManifestFile => File('$mirrorDir/vault_manifest.json');

  VaultKeyring? get keyring => _keyring;
  bool get hasCachedVmk => _cachedVmk != null;

  /// Inicializa el servicio cargando o creando el llavero con Slot 1 (DPAPI)
  Future<void> initialize() async {
    await Directory('$projectRootDir/data').create(recursive: true);
    await Directory(mirrorDir).create(recursive: true);

    if (await keyringFile.exists()) {
      try {
        final content = await keyringFile.readAsString();
        _keyring = VaultKeyring.fromJson(jsonDecode(content) as Map<String, dynamic>);
        _cachedVmk = await VaultCryptoService.unwrapVmkWithDpapi(_keyring!, dpapiService);
      } catch (e) {
        stderr.writeln('Warning: Error cargando llavero local: $e');
      }
    } else {
      // Verificar si hay llavero en el espejo
      if (await mirrorKeyringFile.exists()) {
        try {
          final content = await mirrorKeyringFile.readAsString();
          _keyring = VaultKeyring.fromJson(jsonDecode(content) as Map<String, dynamic>);
          _cachedVmk = await VaultCryptoService.unwrapVmkWithDpapi(_keyring!, dpapiService);
          // Restaurar archivo de llavero en el proyecto
          await _atomicWrite(keyringFile, content);
        } catch (_) {}
      }

      // Si aún no hay llavero, crearlo automáticamente
      if (_keyring == null) {
        final created = await VaultCryptoService.createInitialKeyring(dpapi: dpapiService);
        _keyring = created.keyring;
        _cachedVmk = created.vmk;
        await _atomicWrite(keyringFile, const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()));
      }
    }

    // Vincular hooks para sincronización automática en modo producción
    dbService.onProductionDataChanged = () async {
      await syncMirror();
    };

    configService.onConfigChanged = () async {
      await syncMirror();
    };

    // Si tenemos VMK y datos de producción, sincronizar espejo inicial
    if (_cachedVmk != null && (await clientsDbFile.exists() || await masterKeyFile.exists())) {
      await syncMirror();
    }
  }

  /// Desenvuelve y cachea la VMK si aún no está en RAM
  Future<Uint8List> _ensureVmk() async {
    if (_cachedVmk != null) return _cachedVmk!;
    if (_keyring == null) {
      throw VaultAuthException('El llavero no está inicializado.');
    }
    final vmk = await VaultCryptoService.unwrapVmkWithDpapi(_keyring!, dpapiService);
    if (vmk == null) {
      throw VaultAuthException('No se pudo desbloquear la VMK mediante Windows DPAPI.');
    }
    _cachedVmk = vmk;
    return _cachedVmk!;
  }

  /// Sincronización atómica doble: genera .mlvault cifrado en %APPDATA% y nube opcional
  Future<void> syncMirror() async {
    try {
      final vmk = await _ensureVmk();
      final currentKeyring = _keyring!;

      // Leer archivos locales de producción para el payload
      final clientsContent = await clientsDbFile.exists() ? await clientsDbFile.readAsString() : '[]';
      final releasesContent = await releasesDbFile.exists() ? await releasesDbFile.readAsString() : '[]';
      final configContent = await ownerConfigFile.exists()
          ? await ownerConfigFile.readAsString()
          : jsonEncode(ConfigService.getDefaultConfig());
      final masterKeyContent = await masterKeyFile.exists() ? await masterKeyFile.readAsString() : null;

      int clientsCount = 0;
      int releasesCount = 0;
      try {
        clientsCount = (jsonDecode(clientsContent) as List).length;
      } catch (_) {}
      try {
        releasesCount = (jsonDecode(releasesContent) as List).length;
      } catch (_) {}

      final payload = VaultPayloadFiles(
        clientsJson: clientsContent,
        releasesJson: releasesContent,
        configJson: configContent,
        masterKeyEd25519: masterKeyContent,
      );

      final stats = {
        'clients_count': clientsCount,
        'releases_count': releasesCount,
      };

      final vaultJson = await VaultCryptoService.exportVaultPackage(
        keyring: currentKeyring,
        vmk: vmk,
        files: payload,
        includeMasterKey: masterKeyContent != null,
        stats: stats,
      );

      final vaultData = jsonDecode(vaultJson) as Map<String, dynamic>;
      final envelope = vaultData['payload_envelope'] as Map<String, dynamic>?;
      final ciphertextSha = envelope?['ciphertext_sha256'] as String? ?? vaultData['ciphertext_sha256'] as String? ?? '';

      // 1. Escritura atómica en el directorio Espejo (%APPDATA%\MochilaListaAdminVault)
      await Directory(mirrorDir).create(recursive: true);
      await _atomicWrite(mirrorVaultFile, vaultJson);
      await _atomicWrite(mirrorKeyringFile, const JsonEncoder.withIndent('  ').convert(currentKeyring.toJson()));

      final manifestData = {
        'vault_version': '1.0.0',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'clients_count': clientsCount,
        'releases_count': releasesCount,
        'has_master_key': masterKeyContent != null,
        'ciphertext_sha256': ciphertextSha,
      };
      await _atomicWrite(mirrorManifestFile, const JsonEncoder.withIndent('  ').convert(manifestData));

      // 2. Sincronización opcional no bloqueante en Carpeta de Nube Local
      final cloudPath = await getCloudSyncPath();
      if (cloudPath != null && cloudPath.isNotEmpty) {
        try {
          final cloudDir = Directory(cloudPath);
          if (await cloudDir.exists()) {
            final cloudVaultFile = File('${cloudDir.path}/MochilaLista_Backup_Sync.mlvault');
            await _atomicWrite(cloudVaultFile, vaultJson);
          }
        } catch (e) {
          stderr.writeln('Warning: Error al sincronizar espejo con la carpeta de nube ($cloudPath): $e');
        }
      }
    } catch (e) {
      stderr.writeln('Warning: Error en syncMirror: $e');
    }
  }

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
      'purpose': 'Clave asimétrica oficial para firmar licencias ML9 y fichas MLC1',
    },
    'vault_keyring': {
      'name': 'Llavero de Bóveda Multi-Slot',
      'path': 'data/vault_keyring.json',
      'purpose': 'Llavero AES-256-GCM con los 4 factores de desbloqueo',
    },
  };

  /// Auditoría de salud y estado del almacenamiento, factores y espejos
  Future<Map<String, dynamic>> checkStorageHealth() async {
    final clientsStat = await _getFileStat(
      clientsDbFile,
      purpose: criticalFileDescriptors['clients_db']!['purpose'],
    );
    final releasesStat = await _getFileStat(
      releasesDbFile,
      purpose: criticalFileDescriptors['releases_db']!['purpose'],
    );
    final configStat = await _getFileStat(
      ownerConfigFile,
      purpose: criticalFileDescriptors['owner_config']!['purpose'],
    );
    final keyStat = await _getFileStat(
      masterKeyFile,
      purpose: criticalFileDescriptors['master_key']!['purpose'],
    );
    final keyringStat = await _getFileStat(
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

    final cloudPath = await getCloudSyncPath();
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

    final slots = _keyring?.keySlots ?? {};
    final dpapiEnrolled = slots['slot_1_dpapi'] != null &&
        slots['slot_1_dpapi']['wrapped_vmk_b64'] != null;
    final mlkeyEnrolled = slots['slot_2_file'] != null &&
        slots['slot_2_file']['wrapped_vmk_b64'] != null;
    final rescueKitEnrolled = slots['slot_3_emergency'] != null &&
        (slots['slot_3_emergency']['codes'] as List?)?.isNotEmpty == true;
    final pinEnabled =
        slots['slot_4_pin'] != null && slots['slot_4_pin']['enabled'] == true;

    // Condición de recuperación disponible: Faltan datos críticos locales pero el espejo tiene un .mlvault íntegro
    final bool missingLocalData = (!clientsStat['exists'] ||
            clientsStat['size_bytes'] == 0 ||
            clientsStat['size_bytes'] == 2) ||
        (!keyStat['exists'] || keyStat['size_bytes'] == 0);
    final bool recoveryAvailable =
        missingLocalData && mirrorVaultExists && (mirrorSizeBytes ?? 0) > 0;

    // Fórmula unificada del índice de protección (0..100%) sobre los 4 factores criptográficos (25% c/u)
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

  /// Auditoría integral de integridad criptográfica y paridad Disco vs Espejo (%APPDATA% + Nube).
  Future<Map<String, dynamic>> runFullIntegrityAudit() async {
    final health = await checkStorageHealth();
    final factors = health['factors'] as Map<String, dynamic>;
    final files = Map<String, dynamic>.from(health['files'] as Map);
    final mirror = Map<String, dynamic>.from(health['mirror'] as Map);
    final cloud = Map<String, dynamic>.from(health['cloud'] as Map);

    final bool dpapiEnrolled = factors['dpapi_enrolled'] == true;
    final bool mlkeyEnrolled = factors['mlkey_enrolled'] == true;
    final bool rescueKitEnrolled = factors['rescue_kit_enrolled'] == true;
    final bool pinEnabled = factors['pin_enabled'] == true;

    bool dpapiUnwrapOk = false;
    if (_keyring != null && dpapiEnrolled) {
      try {
        final unwrapped =
            await VaultCryptoService.unwrapVmkWithDpapi(_keyring!, dpapiService);
        dpapiUnwrapOk = unwrapped != null;
      } catch (_) {
        dpapiUnwrapOk = false;
      }
    }

    // Verificar paridad interna descifrando auto_mirror_latest.mlvault en memoria si es posible
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
        } else if (_cachedVmk != null) {
          // Verificar AAD/integridad vía DPAPI unicamente si disponible
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

    final Map<String, String> manifestHashKeys = {
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
        parityStatus = mirrorDecryptOk ? 'MISSING_IN_MIRROR' : 'MIRROR_UNAVAILABLE';
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
        'valid': _keyring != null,
        'format': _keyring?.format,
        'version': _keyring?.version,
        'updated_at': _keyring?.updatedAt.toIso8601String(),
        'updated_at_lima': _keyring != null
            ? PeruTimeHelper.formatLimaDateTime(_keyring!.updatedAt, fallback: '-')
            : '-',
        'active_slots': health['keyring_info']?['active_slots'] ?? <String>[],
      },
      'mirror': {
        ...mirror,
        'decrypt_ok': mirrorDecryptOk,
        'decrypt_error': mirrorDecryptError,
        'all_files_matched': matchedFilesCount == criticalFileDescriptors.length,
      },
      'cloud': cloud,
      'files': auditedFiles,
      'matched_files_count': matchedFilesCount,
      'total_critical_files': criticalFileDescriptors.length,
      'recommendations': recommendations,
    };
  }

  /// Restaura el proyecto desde el espejo auto_mirror_latest.mlvault
  Future<VaultImportResult> recoverFromMirror({VaultUnlockCredential? credential}) async {
    if (!await mirrorVaultFile.exists()) {
      throw VaultException('No se encontró el archivo de espejo auto_mirror_latest.mlvault.');
    }
    final vaultJson = await mirrorVaultFile.readAsString();
    final cred = credential ?? VaultUnlockCredential.dpapi();

    final importResult = await VaultCryptoService.importVaultPackage(
      vaultJson: vaultJson,
      credential: cred,
      dpapi: dpapiService,
    );

    // Escribir archivos recuperados
    await _atomicWrite(clientsDbFile, importResult.files.clientsJson);
    await _atomicWrite(releasesDbFile, importResult.files.releasesJson);
    await _atomicWrite(ownerConfigFile, importResult.files.configJson);

    if (importResult.files.masterKeyEd25519 != null) {
      await _atomicWrite(masterKeyFile, importResult.files.masterKeyEd25519!);
    }

    // Actualizar llavero y VMK en memoria
    _keyring = importResult.keyring;
    _cachedVmk = importResult.vmk;
    await _atomicWrite(keyringFile, const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()));

    // Recarga en caliente inmediata
    if (importResult.files.masterKeyEd25519 != null) {
      await signer.reloadMasterKey(keyPath: masterKeyFile.path);
    }
    await dbService.reloadFromDisk();
    await configService.reloadFromDisk();

    return importResult;
  }

  /// Exporta un paquete .mlvault portable manteniendo intactos los factores vigentes
  Future<String> exportPortableVault({bool includeMasterKey = true}) async {
    final vmk = await _ensureVmk();
    final currentKeyring = _keyring!;

    final clientsContent = await clientsDbFile.exists() ? await clientsDbFile.readAsString() : '[]';
    final releasesContent = await releasesDbFile.exists() ? await releasesDbFile.readAsString() : '[]';
    final configContent = await ownerConfigFile.exists()
        ? await ownerConfigFile.readAsString()
        : jsonEncode(ConfigService.getDefaultConfig());
    final masterKeyContent =
        (includeMasterKey && await masterKeyFile.exists()) ? await masterKeyFile.readAsString() : null;

    int clientsCount = 0;
    int releasesCount = 0;
    try {
      clientsCount = (jsonDecode(clientsContent) as List).length;
    } catch (_) {}
    try {
      releasesCount = (jsonDecode(releasesContent) as List).length;
    } catch (_) {}

    final payload = VaultPayloadFiles(
      clientsJson: clientsContent,
      releasesJson: releasesContent,
      configJson: configContent,
      masterKeyEd25519: masterKeyContent,
    );

    final stats = {
      'clients_count': clientsCount,
      'releases_count': releasesCount,
    };

    return await VaultCryptoService.exportVaultPackage(
      keyring: currentKeyring,
      vmk: vmk,
      files: payload,
      includeMasterKey: masterKeyContent != null,
      stats: stats,
    );
  }

  /// Inspección segura de metadatos de un paquete .mlvault sin descifrar
  Map<String, dynamic> inspectVault(String vaultPackageJson) {
    return VaultCryptoService.inspectVaultPackage(vaultPackageJson);
  }

  /// Importa un paquete .mlvault portable a la PC actual
  Future<VaultImportResult> importPortableVault({
    required String vaultJson,
    required VaultUnlockCredential credential,
    bool rewrapForCurrentDpapi = true,
  }) async {
    // 1. Snapshot preventivo en backups/ si hay datos existentes
    if (await clientsDbFile.exists()) {
      try {
        await backupsDirectory.create(recursive: true);
        final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
        await clientsDbFile.copy('${backupsDirectory.path}/pre_import_clients_$timestamp.json');
      } catch (_) {}
    }

    // 2. Descifrar y validar el paquete con la credencial suministrada
    final importResult = await VaultCryptoService.importVaultPackage(
      vaultJson: vaultJson,
      credential: credential,
      dpapi: dpapiService,
    );

    // 3. Escribir los archivos descifrados
    await _atomicWrite(clientsDbFile, importResult.files.clientsJson);
    await _atomicWrite(releasesDbFile, importResult.files.releasesJson);
    await _atomicWrite(ownerConfigFile, importResult.files.configJson);

    if (importResult.files.masterKeyEd25519 != null) {
      await _atomicWrite(masterKeyFile, importResult.files.masterKeyEd25519!);
    }

    // 4. Si se solicita, re-envolver VMK en el Windows DPAPI de esta PC
    var finalKeyring = importResult.keyring;
    if (rewrapForCurrentDpapi) {
      final success = await VaultCryptoService.rewrapVmkForNewDpapi(
        finalKeyring,
        importResult.vmk,
        dpapiService,
      );
      if (!success) {
        stderr.writeln('Warning: No se pudo re-envolver la VMK con DPAPI en esta máquina.');
      }
    }

    _keyring = finalKeyring;
    _cachedVmk = importResult.vmk;
    await _atomicWrite(keyringFile, const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()));

    // 5. Sincronizar el espejo local inmediatamente
    await syncMirror();

    // 6. Recarga en caliente inmediata de los 3 motores
    if (importResult.files.masterKeyEd25519 != null) {
      await signer.reloadMasterKey(keyPath: masterKeyFile.path);
    }
    await dbService.reloadFromDisk();
    await configService.reloadFromDisk();

    return importResult;
  }

  // =================== GESTIÓN DE FACTORES ===================

  /// Genera o recupera el archivo oficial .mlkey (Slot 2)
  Future<String> downloadMlKey() async {
    final vmk = await _ensureVmk();
    final mlKeyJson = await VaultCryptoService.enrollMlKeySlot(_keyring!, vmk);
    await _atomicWrite(keyringFile, const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()));
    await syncMirror();
    return mlKeyJson;
  }

  /// Genera el Kit de Rescate de 8 Códigos + QR (Slot 3)
  Future<RescueKitResult> generateRescueKit() async {
    final vmk = await _ensureVmk();
    final kit = await VaultCryptoService.enrollRescueKitSlots(_keyring!, vmk);
    await _atomicWrite(keyringFile, const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()));
    await syncMirror();
    return kit;
  }

  /// Configura o desactiva el PIN local (Slot 4) emitiendo sesión inmediata si se activa
  Future<Map<String, dynamic>> configurePin({
    required String? pin,
    required bool enabled,
  }) async {
    final vmk = await _ensureVmk();
    if (!enabled) {
      _keyring!.keySlots['slot_4_pin'] = {
        'type': 'PIN_OPTIONAL',
        'enabled': false,
        'wrapped_vmk_b64': null,
      };
      _keyring!.updatedAt = DateTime.now().toUtc();
      await _atomicWrite(
        keyringFile,
        const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()),
      );
      await syncMirror();
      revokeSession(null);
      return {
        'ok': true,
        'pin_enabled': false,
        'message': 'PIN local desactivado exitosamente.',
      };
    }

    if (pin == null || pin.trim().length < 4) {
      throw VaultFormatException(
        'El PIN debe tener al menos 4 dígitos o caracteres.',
      );
    }
    await VaultCryptoService.enrollPinSlot(_keyring!, vmk, pin.trim());
    await _atomicWrite(
      keyringFile,
      const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()),
    );
    await syncMirror();

    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    final token = _generateSessionToken();
    _validSessionTokens.add(token);

    return {
      'ok': true,
      'pin_enabled': true,
      'token': token,
      'session_token': token,
      'expires_in': 86400,
      'message': 'PIN local activado exitosamente.',
    };
  }

  /// Verifica el PIN local contra Slot 4 con protección anti-fuerza bruta
  Future<Map<String, dynamic>> verifyPin(String pin) async {
    if (_pinLockedUntil != null && DateTime.now().isBefore(_pinLockedUntil!)) {
      final waitSec = _pinLockedUntil!.difference(DateTime.now()).inSeconds + 1;
      throw VaultAuthException('Demasiados intentos fallidos. Bóveda bloqueada por $waitSec segundos.');
    }

    if (_keyring == null) {
      throw VaultAuthException('Llavero no cargado.');
    }

    final vmk = await VaultCryptoService.unwrapVmkWithPin(_keyring!, pin.trim());
    if (vmk == null) {
      _failedPinAttempts++;
      if (_failedPinAttempts >= 5) {
        int delaySeconds = 2;
        if (_failedPinAttempts == 6) {
          delaySeconds = 4;
        } else if (_failedPinAttempts == 7) {
          delaySeconds = 8;
        } else if (_failedPinAttempts == 8) {
          delaySeconds = 16;
        } else if (_failedPinAttempts >= 9) {
          delaySeconds = 30;
        }
        _pinLockedUntil = DateTime.now().add(Duration(seconds: delaySeconds));
      }
      throw VaultAuthException('PIN incorrecto. Intento #$_failedPinAttempts.');
    }

    // Éxito: resetear contadores y emitir token de sesión
    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    _cachedVmk = vmk;

    final token = _generateSessionToken();
    _validSessionTokens.add(token);

    return {
      'success': true,
      'ok': true,
      'token': token,
      'session_token': token,
      'expires_in': 86400,
    };
  }

  /// Restablece o desactiva el PIN olvidado validando cualquiera de los otros 3 factores
  Future<Map<String, dynamic>> recoverPin({
    required VaultUnlockCredential credential,
    String? newPin,
    bool disablePin = false,
  }) async {
    if (_keyring == null) {
      throw VaultAuthException('Llavero no cargado.');
    }

    Uint8List? vmk;
    switch (credential.type) {
      case VaultUnlockType.dpapi:
        vmk = await VaultCryptoService.unwrapVmkWithDpapi(_keyring!, dpapiService);
        break;
      case VaultUnlockType.mlKey:
        if (credential.secret == null) throw VaultAuthException('Se requiere el archivo .mlkey.');
        vmk = await VaultCryptoService.unwrapVmkWithMlKey(_keyring!, credential.secret!);
        break;
      case VaultUnlockType.rescueCode:
        if (credential.secret == null) throw VaultAuthException('Se requiere el Código de Rescate.');
        vmk = await VaultCryptoService.unwrapVmkWithRescueCode(_keyring!, credential.secret!);
        break;
      case VaultUnlockType.qrKey:
        if (credential.secret == null) throw VaultAuthException('Se requiere la clave QR.');
        vmk = await VaultCryptoService.unwrapVmkWithQrKey(_keyring!, credential.secret!);
        break;
      default:
        throw VaultAuthException('Tipo de factor no soportado para recuperación de PIN.');
    }

    if (vmk == null) {
      throw VaultAuthException('El factor de recuperación suministrado fue rechazado.');
    }

    _cachedVmk = vmk;
    _failedPinAttempts = 0;
    _pinLockedUntil = null;

    if (disablePin) {
      _keyring!.keySlots['slot_4_pin'] = {
        'type': 'PIN_OPTIONAL',
        'enabled': false,
        'wrapped_vmk_b64': null,
      };
      _keyring!.updatedAt = DateTime.now().toUtc();
    } else if (newPin != null && newPin.trim().isNotEmpty) {
      if (newPin.trim().length < 4) {
        throw VaultFormatException('El nuevo PIN debe tener al menos 4 caracteres.');
      }
      await VaultCryptoService.enrollPinSlot(_keyring!, vmk, newPin.trim());
    }

    await _atomicWrite(keyringFile, const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()));
    await syncMirror();

    final token = _generateSessionToken();
    _validSessionTokens.add(token);

    return {
      'success': true,
      'ok': true,
      'token': token,
      'session_token': token,
      'pin_enabled': isPinEnabled(),
    };
  }

  bool isPinEnabled() {
    return _keyring?.keySlots['slot_4_pin']?['enabled'] == true;
  }

  bool isSessionValid(String? token) {
    if (!isPinEnabled()) return true;
    return token != null && _validSessionTokens.contains(token);
  }

  /// Revoca el token de sesión suministrado o todos si es null (bloqueo manual)
  void revokeSession(String? token) {
    if (token != null) {
      _validSessionTokens.remove(token);
    } else {
      _validSessionTokens.clear();
    }
  }

  // =================== NUBE LOCAL Y CONFIGURACIÓN ===================

  /// Valida que la carpeta de nube local seleccionada no sea raíz de disco,
  /// directorio del sistema operativo ni carpeta interna sensible del proyecto.
  static String? validateCloudSyncDirectoryPath(
    String? rawPath, {
    String? projectRootDir,
    String? mirrorDir,
  }) {
    final clean = rawPath?.trim() ?? '';
    if (clean.isEmpty) return null;

    String norm(String p) {
      var s = p.trim().replaceAll('/', '\\');
      while (s.length > 3 && s.endsWith('\\')) {
        s = s.substring(0, s.length - 1);
      }
      return s.toLowerCase();
    }

    final normalized = norm(clean);
    if (RegExp(r'^[a-z]:\\?$').hasMatch(normalized) ||
        normalized == '\\' ||
        normalized == '/') {
      return 'No puedes usar la raíz de un disco como carpeta de Nube Local.';
    }

    final forbiddenSystemPrefixes = <String>[
      r'c:\windows',
      r'c:\program files',
      r'c:\program files (x86)',
      '/etc',
      '/usr',
      '/bin',
      '/sbin',
      '/system',
    ];
    for (final sysPath in forbiddenSystemPrefixes) {
      final sysNorm = sysPath.replaceAll('/', '\\').toLowerCase();
      if (normalized == sysNorm || normalized.startsWith('$sysNorm\\')) {
        return 'No se permite usar carpetas del sistema operativo como destino de sincronización.';
      }
    }

    final baseNorm = norm(Directory(projectRootDir ?? '.').absolute.path);
    final rawLower = clean.replaceAll('\\', '/').toLowerCase();
    if (rawLower.contains('/private_keys') ||
        rawLower.endsWith('/mochilalista_admin/data') ||
        rawLower == 'data' ||
        rawLower == 'private_keys' ||
        rawLower == 'backups') {
      return 'No se permite apuntar la Nube Local hacia carpetas internas críticas del servidor (data, backups o private_keys).';
    }

    final forbiddenInternal = <String>[
      '$baseNorm\\data',
      '$baseNorm\\private_keys',
      '$baseNorm\\backups',
      '$baseNorm\\releases_apks',
    ];
    if (mirrorDir != null && mirrorDir.trim().isNotEmpty) {
      forbiddenInternal.add(norm(Directory(mirrorDir).absolute.path));
    }

    final absNorm = norm(Directory(clean).absolute.path);
    for (final blocked in forbiddenInternal) {
      if (absNorm == blocked || absNorm.startsWith('$blocked\\')) {
        return 'La ruta seleccionada apunta a una carpeta interna de resguardo del proyecto. Elige una carpeta externa (Dropbox, Google Drive u OneDrive).';
      }
    }

    return null;
  }

  Future<String?> getCloudSyncPath() async {
    if (!await settingsFile.exists()) return null;
    try {
      final content = await settingsFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['cloud_sync_path'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setCloudSyncPath(String? path) async {
    final clean = path?.trim();
    final validationError = validateCloudSyncDirectoryPath(
      clean,
      projectRootDir: projectRootDir,
      mirrorDir: mirrorDir,
    );
    if (validationError != null) {
      throw VaultFormatException(validationError);
    }

    final effectivePath = (clean != null && clean.isNotEmpty) ? clean : null;
    if (effectivePath != null && !await Directory(effectivePath).exists()) {
      throw VaultFormatException(
        'La carpeta de nube local indicada no existe en disco: $effectivePath',
      );
    }

    final data = <String, dynamic>{'cloud_sync_path': effectivePath};
    await _atomicWrite(
      settingsFile,
      const JsonEncoder.withIndent('  ').convert(data),
    );
    if (effectivePath != null) {
      await syncMirror();
    }
  }

  // =================== HELPERS INTERNOS ===================

  Future<void> _atomicWrite(File targetFile, String content) async {
    final parentDir = targetFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    final tempFile = File('${targetFile.path}.tmp');
    await tempFile.writeAsString(content, flush: true);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);
  }

  Future<Map<String, dynamic>> _getFileStat(
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

  String _generateSessionToken() {
    final rand = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
