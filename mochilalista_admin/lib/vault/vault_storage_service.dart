import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config/config_service.dart';
import '../core/path_security.dart';
import '../database_service.dart';
import '../license_signer.dart';
import 'dpapi_service.dart';
import 'vault_crypto_service.dart';
import 'vault_integrity_auditor.dart';
import 'vault_pin_session_manager.dart';

/// Servicio de Doble Almacenamiento Cifrado y Auto-Recuperación (Plan 10 - Pilar 2).
/// Gestiona la persistencia en espejo (`%APPDATA%\MochilaListaAdminVault`), nube local,
/// auto-recuperación ante borrados y bloqueo/desbloqueo de sesión PIN.
class VaultStorageService {
  static const Map<String, Map<String, String>> criticalFileDescriptors =
      VaultIntegrityAuditor.criticalFileDescriptors;

  final String projectRootDir;
  final String mirrorDir;
  final DpapiService dpapiService;
  final DatabaseService dbService;
  final ConfigService configService;
  final LicenseSigner signer;

  Uint8List? _cachedVmk;
  VaultKeyring? _keyring;
  final VaultPinSessionManager _pinManager = VaultPinSessionManager();

  VaultStorageService({
    this.projectRootDir = '.',
    String? mirrorDir,
    DpapiService? dpapiService,
    required this.dbService,
    required this.configService,
    required this.signer,
  })  : mirrorDir = mirrorDir ?? defaultMirrorDirectory(),
        dpapiService = dpapiService ?? WindowsDpapiService();

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

  File get keyringFile => File('$projectRootDir/data/vault_keyring.json');
  File get settingsFile => File('$projectRootDir/data/vault_settings.json');
  File get clientsDbFile => File('$projectRootDir/data/prod_clients_db.json');
  File get releasesDbFile => File('$projectRootDir/data/prod_releases_db.json');
  File get ownerConfigFile => File('$projectRootDir/data/owner_config.json');
  File get masterKeyFile => File('$projectRootDir/private_keys/ed25519_master.key');
  Directory get backupsDirectory => Directory('$projectRootDir/backups');

  File get mirrorVaultFile => File('$mirrorDir/auto_mirror_latest.mlvault');
  File get mirrorKeyringFile => File('$mirrorDir/vault_keyring.json');
  File get mirrorManifestFile => File('$mirrorDir/vault_manifest.json');

  VaultKeyring? get keyring => _keyring;
  bool get hasCachedVmk => _cachedVmk != null;

  Future<void> initialize() async {
    await Directory('$projectRootDir/data').create(recursive: true);
    await Directory(mirrorDir).create(recursive: true);

    if (await keyringFile.exists()) {
      try {
        final content = await keyringFile.readAsString();
        _keyring = VaultKeyring.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        _cachedVmk =
            await VaultCryptoService.unwrapVmkWithDpapi(_keyring!, dpapiService);
      } catch (e) {
        stderr.writeln('Warning: Error cargando llavero local: $e');
      }
    } else {
      if (await mirrorKeyringFile.exists()) {
        try {
          final content = await mirrorKeyringFile.readAsString();
          _keyring = VaultKeyring.fromJson(
            jsonDecode(content) as Map<String, dynamic>,
          );
          _cachedVmk = await VaultCryptoService.unwrapVmkWithDpapi(
            _keyring!,
            dpapiService,
          );
          await _atomicWrite(keyringFile, content);
        } catch (_) {}
      }

      if (_keyring == null) {
        final created =
            await VaultCryptoService.createInitialKeyring(dpapi: dpapiService);
        _keyring = created.keyring;
        _cachedVmk = created.vmk;
        await _persistKeyring();
      }
    }

    dbService.onProductionDataChanged = () async {
      await syncMirror();
    };

    configService.onConfigChanged = () async {
      await syncMirror();
    };

    if (_cachedVmk != null &&
        (await clientsDbFile.exists() || await masterKeyFile.exists())) {
      await syncMirror();
    }
  }

  Future<Uint8List> _ensureVmk() async {
    if (_cachedVmk != null) return _cachedVmk!;
    if (_keyring == null) {
      throw VaultAuthException('El llavero no está inicializado.');
    }
    final vmk =
        await VaultCryptoService.unwrapVmkWithDpapi(_keyring!, dpapiService);
    if (vmk == null) {
      throw VaultAuthException(
        'No se pudo desbloquear la VMK mediante Windows DPAPI.',
      );
    }
    _cachedVmk = vmk;
    return _cachedVmk!;
  }

  Future<void> _persistKeyring() async {
    await _atomicWrite(
      keyringFile,
      const JsonEncoder.withIndent('  ').convert(_keyring!.toJson()),
    );
  }

  Future<void> _persistKeyringAndSync() async {
    await _persistKeyring();
    await syncMirror();
  }

  Future<void> syncMirror() async {
    try {
      final vmk = await _ensureVmk();
      final currentKeyring = _keyring!;

      final clientsContent =
          await clientsDbFile.exists() ? await clientsDbFile.readAsString() : '[]';
      final releasesContent = await releasesDbFile.exists()
          ? await releasesDbFile.readAsString()
          : '[]';
      final configContent = await ownerConfigFile.exists()
          ? await ownerConfigFile.readAsString()
          : jsonEncode(ConfigService.getDefaultConfig());
      final masterKeyContent =
          await masterKeyFile.exists() ? await masterKeyFile.readAsString() : null;

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
      final ciphertextSha = envelope?['ciphertext_sha256'] as String? ??
          vaultData['ciphertext_sha256'] as String? ??
          '';

      await Directory(mirrorDir).create(recursive: true);
      await _atomicWrite(mirrorVaultFile, vaultJson);
      await _atomicWrite(
        mirrorKeyringFile,
        const JsonEncoder.withIndent('  ').convert(currentKeyring.toJson()),
      );

      final manifestData = {
        'vault_version': '1.0.0',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'clients_count': clientsCount,
        'releases_count': releasesCount,
        'has_master_key': masterKeyContent != null,
        'ciphertext_sha256': ciphertextSha,
      };
      await _atomicWrite(
        mirrorManifestFile,
        const JsonEncoder.withIndent('  ').convert(manifestData),
      );

      final cloudPath = await getCloudSyncPath();
      if (cloudPath != null && cloudPath.isNotEmpty) {
        try {
          final cloudDir = Directory(cloudPath);
          if (await cloudDir.exists()) {
            final cloudVaultFile =
                File('${cloudDir.path}/MochilaLista_Backup_Sync.mlvault');
            await _atomicWrite(cloudVaultFile, vaultJson);
          }
        } catch (e) {
          stderr.writeln(
            'Warning: Error al sincronizar espejo con la carpeta de nube ($cloudPath): $e',
          );
        }
      }
    } catch (e) {
      stderr.writeln('Warning: Error en syncMirror: $e');
    }
  }

  Future<Map<String, dynamic>> checkStorageHealth() async {
    final cloudPath = await getCloudSyncPath();
    return VaultIntegrityAuditor.checkStorageHealth(
      projectRootDir: projectRootDir,
      mirrorDir: mirrorDir,
      clientsDbFile: clientsDbFile,
      releasesDbFile: releasesDbFile,
      ownerConfigFile: ownerConfigFile,
      masterKeyFile: masterKeyFile,
      keyringFile: keyringFile,
      mirrorVaultFile: mirrorVaultFile,
      mirrorKeyringFile: mirrorKeyringFile,
      mirrorManifestFile: mirrorManifestFile,
      keyring: _keyring,
      cloudPath: cloudPath,
    );
  }

  Future<Map<String, dynamic>> runFullIntegrityAudit() async {
    final health = await checkStorageHealth();
    return VaultIntegrityAuditor.runFullIntegrityAudit(
      health: health,
      keyring: _keyring,
      cachedVmk: _cachedVmk,
      dpapiService: dpapiService,
      mirrorVaultFile: mirrorVaultFile,
      mirrorKeyringFile: mirrorKeyringFile,
    );
  }

  Future<VaultImportResult> recoverFromMirror({
    VaultUnlockCredential? credential,
  }) async {
    if (!await mirrorVaultFile.exists()) {
      throw VaultException(
        'No se encontró el archivo de espejo auto_mirror_latest.mlvault.',
      );
    }
    final vaultJson = await mirrorVaultFile.readAsString();
    final cred = credential ?? VaultUnlockCredential.dpapi();

    final importResult = await VaultCryptoService.importVaultPackage(
      vaultJson: vaultJson,
      credential: cred,
      dpapi: dpapiService,
    );

    await _atomicWrite(clientsDbFile, importResult.files.clientsJson);
    await _atomicWrite(releasesDbFile, importResult.files.releasesJson);
    await _atomicWrite(ownerConfigFile, importResult.files.configJson);

    if (importResult.files.masterKeyEd25519 != null) {
      await _atomicWrite(masterKeyFile, importResult.files.masterKeyEd25519!);
    }

    _keyring = importResult.keyring;
    _cachedVmk = importResult.vmk;
    await _persistKeyring();

    if (importResult.files.masterKeyEd25519 != null) {
      await signer.reloadMasterKey(keyPath: masterKeyFile.path);
    }
    await dbService.reloadFromDisk();
    await configService.reloadFromDisk();

    return importResult;
  }

  Future<String> exportPortableVault({bool includeMasterKey = true}) async {
    final vmk = await _ensureVmk();
    final currentKeyring = _keyring!;

    final clientsContent =
        await clientsDbFile.exists() ? await clientsDbFile.readAsString() : '[]';
    final releasesContent = await releasesDbFile.exists()
        ? await releasesDbFile.readAsString()
        : '[]';
    final configContent = await ownerConfigFile.exists()
        ? await ownerConfigFile.readAsString()
        : jsonEncode(ConfigService.getDefaultConfig());
    final masterKeyContent = (includeMasterKey && await masterKeyFile.exists())
        ? await masterKeyFile.readAsString()
        : null;

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

    return VaultCryptoService.exportVaultPackage(
      keyring: currentKeyring,
      vmk: vmk,
      files: payload,
      includeMasterKey: masterKeyContent != null,
      stats: stats,
    );
  }

  Map<String, dynamic> inspectVault(String vaultPackageJson) =>
      VaultCryptoService.inspectVaultPackage(vaultPackageJson);

  Future<VaultImportResult> importPortableVault({
    required String vaultJson,
    required VaultUnlockCredential credential,
    bool rewrapForCurrentDpapi = true,
  }) async {
    if (await clientsDbFile.exists()) {
      try {
        await backupsDirectory.create(recursive: true);
        final timestamp =
            DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
        await clientsDbFile.copy(
          '${backupsDirectory.path}/pre_import_clients_$timestamp.json',
        );
      } catch (_) {}
    }

    final importResult = await VaultCryptoService.importVaultPackage(
      vaultJson: vaultJson,
      credential: credential,
      dpapi: dpapiService,
    );

    await _atomicWrite(clientsDbFile, importResult.files.clientsJson);
    await _atomicWrite(releasesDbFile, importResult.files.releasesJson);
    await _atomicWrite(ownerConfigFile, importResult.files.configJson);

    if (importResult.files.masterKeyEd25519 != null) {
      await _atomicWrite(masterKeyFile, importResult.files.masterKeyEd25519!);
    }

    final finalKeyring = importResult.keyring;
    if (rewrapForCurrentDpapi) {
      final success = await VaultCryptoService.rewrapVmkForNewDpapi(
        finalKeyring,
        importResult.vmk,
        dpapiService,
      );
      if (!success) {
        stderr.writeln(
          'Warning: No se pudo re-envolver la VMK con DPAPI en esta máquina.',
        );
      }
    }

    _keyring = finalKeyring;
    _cachedVmk = importResult.vmk;
    await _persistKeyringAndSync();

    if (importResult.files.masterKeyEd25519 != null) {
      await signer.reloadMasterKey(keyPath: masterKeyFile.path);
    }
    await dbService.reloadFromDisk();
    await configService.reloadFromDisk();

    return importResult;
  }

  // =================== GESTIÓN DE FACTORES ===================

  Future<String> downloadMlKey() async {
    final vmk = await _ensureVmk();
    final mlKeyJson = await VaultCryptoService.enrollMlKeySlot(_keyring!, vmk);
    await _persistKeyringAndSync();
    return mlKeyJson;
  }

  Future<RescueKitResult> generateRescueKit() async {
    final vmk = await _ensureVmk();
    final kit =
        await VaultCryptoService.enrollRescueKitSlots(_keyring!, vmk);
    await _persistKeyringAndSync();
    return kit;
  }

  Future<Map<String, dynamic>> configurePin({
    required String? pin,
    required bool enabled,
  }) async {
    final vmk = await _ensureVmk();
    return _pinManager.configurePin(
      keyring: _keyring!,
      vmk: vmk,
      pin: pin,
      enabled: enabled,
      persistAndSync: _persistKeyringAndSync,
    );
  }

  Future<Map<String, dynamic>> verifyPin(String pin) => _pinManager.verifyPin(
        keyring: _keyring,
        pin: pin,
        onVmkUnlocked: (vmk) => _cachedVmk = vmk,
      );

  Future<Map<String, dynamic>> recoverPin({
    required VaultUnlockCredential credential,
    String? newPin,
    bool disablePin = false,
  }) =>
      _pinManager.recoverPin(
        keyring: _keyring,
        dpapiService: dpapiService,
        credential: credential,
        newPin: newPin,
        disablePin: disablePin,
        onVmkUnlocked: (vmk) => _cachedVmk = vmk,
        persistAndSync: _persistKeyringAndSync,
      );

  bool isPinEnabled() => _pinManager.isPinEnabled(_keyring);

  bool isSessionValid(String? token) =>
      _pinManager.isSessionValid(_keyring, token);

  void revokeSession(String? token) => _pinManager.revokeSession(token);

  // =================== NUBE LOCAL Y CONFIGURACIÓN ===================

  static String? validateCloudSyncDirectoryPath(
    String? rawPath, {
    String? projectRootDir,
    String? mirrorDir,
  }) =>
      PathSecurity.validateCloudSyncDirectoryPath(
        rawPath,
        projectRootDir: projectRootDir,
        mirrorDir: mirrorDir,
      );

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
}
