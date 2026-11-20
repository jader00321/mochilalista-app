import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/core/utils/backup_crypto_helper.dart';
import 'package:app_movil/core/utils/backup_manager.dart';

/// Cliente HTTP ligero propio para inyectar credenciales OAuth 2.0 de Google
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Implementación de producción del servicio de copias de seguridad en Google Drive
class GoogleDriveBackupService implements IGoogleDriveBackupService {
  static final GoogleDriveBackupService instance = GoogleDriveBackupService();

  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;
  final Connectivity _connectivity;
  final drive.DriveApi? _injectedDriveApi;

  static const String configStorageKey = 'mochilalista_drive_backup_config_v1';
  static const String userCacheStorageKey = 'mochilalista_drive_user_cache_v1';

  GoogleDriveUser? _currentUser;

  GoogleDriveBackupService({
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
    Connectivity? connectivity,
    drive.DriveApi? driveApi,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [drive.DriveApi.driveAppdataScope],
            ),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _connectivity = connectivity ?? Connectivity(),
        _injectedDriveApi = driveApi;

  /// Obtiene o inicializa la instancia autenticada de DriveApi
  Future<drive.DriveApi> _getDriveApi() async {
    if (_injectedDriveApi != null) return _injectedDriveApi;

    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();

    if (account == null) {
      throw Exception("Usuario de Google no autenticado.");
    }

    final headers = await account.authHeaders;
    final authClient = GoogleAuthClient(headers);
    return drive.DriveApi(authClient);
  }

  @override
  Future<GoogleDriveUser?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      _currentUser = GoogleDriveUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );

      await _secureStorage.write(
        key: userCacheStorageKey,
        value: jsonEncode(_currentUser!.toMap()),
      );

      // Si no estaba habilitado, habilitar automáticamente al vincular
      final currentConfig = await getConfig();
      if (!currentConfig.isEnabled) {
        await saveConfig(currentConfig.copyWith(isEnabled: true));
      }

      AppLogger.info(
        'GoogleDriveBackupService',
        'Sesión vinculada con cuenta: ${_currentUser!.email}',
      );
      return _currentUser;
    } catch (e, stack) {
      AppLogger.error('GoogleDriveBackupService.signIn', e, stack);
      final errStr = e.toString();
      if (errStr.contains('ApiException: 10') ||
          errStr.contains('code: 10') ||
          errStr.contains('DEVELOPER_ERROR') ||
          errStr.contains('status code 10')) {
        throw Exception(
          "Configuración OAuth pendiente: Registra la huella SHA-1 de este APK en Google Cloud Console para autorizar Google Drive.",
        );
      } else if (errStr.contains('network') ||
          errStr.contains('SocketException') ||
          errStr.contains('ApiException: 7') ||
          errStr.contains('NETWORK_ERROR')) {
        throw Exception(
          "Sin conexión a internet. Verifica tu red Wi-Fi o datos móviles para vincular tu cuenta de Google.",
        );
      }
      rethrow;
    }
  }

  @override
  Future<GoogleDriveUser?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = GoogleDriveUser(
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
        );
        await _secureStorage.write(
          key: userCacheStorageKey,
          value: jsonEncode(_currentUser!.toMap()),
        );
        return _currentUser;
      }

      // Fallback a caché local si la sesión silenciosa no respondió
      return await getCurrentUser();
    } catch (e) {
      debugPrint('ℹ️ [GoogleDriveBackupService] signInSilently falló o no disponible: $e');
      return await getCurrentUser();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      await _secureStorage.delete(key: userCacheStorageKey);
      AppLogger.info('GoogleDriveBackupService', 'Sesión de Google Drive desvinculada.');
    } catch (e, stack) {
      AppLogger.error('GoogleDriveBackupService.signOut', e, stack);
    }
  }

  @override
  Future<GoogleDriveUser?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    try {
      final raw = await _secureStorage.read(key: userCacheStorageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _currentUser = GoogleDriveUser.fromMap(map);
        return _currentUser;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<DriveBackupConfig> getConfig() async {
    try {
      final raw = await _secureStorage.read(key: configStorageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return DriveBackupConfig.fromMap(map);
      }
    } catch (_) {}
    return const DriveBackupConfig(isEnabled: false);
  }

  @override
  Future<void> saveConfig(DriveBackupConfig config) async {
    try {
      await _secureStorage.write(
        key: configStorageKey,
        value: jsonEncode(config.toMap()),
      );
    } catch (e, stack) {
      AppLogger.error('GoogleDriveBackupService.saveConfig', e, stack);
    }
  }

  @override
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({String? customPassphrase}) async {
    var user = await getCurrentUser();
    user ??= await signInSilently();
    if (user == null) {
      throw Exception("Debes iniciar sesión con tu cuenta de Google para respaldar.");
    }

    final config = await getConfig();
    final derivedPassword = BackupCryptoHelper.deriveDrivePassword(
      googleUserId: user.id,
      customPassphrase: customPassphrase ?? config.customPassphrase,
    );

    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'mochilalista_backup_$dateStr.mlbg';

    File? backupFile;
    try {
      // 1. Crear contenedor oficial .mlbg cifrado con AES-256-GCM y 100,000 iteraciones
      backupFile = await BackupManager.createBackupFile(
        password: derivedPassword,
        pbkdf2Iterations: BackupCryptoHelper.drivePbkdf2Iterations,
        customFileName: fileName,
      );

      final fileSize = await backupFile.length();
      final driveApi = await _getDriveApi();

      // 2. Preparar subida exclusiva a appDataFolder
      final driveFile = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];

      final media = drive.Media(backupFile.openRead(), fileSize);
      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      final metadata = GoogleDriveBackupMetadata(
        fileId: uploadedFile.id ?? '',
        fileName: fileName,
        createdAt: now,
        sizeBytes: fileSize,
      );

      // 3. Rotación FIFO: conservar estrictamente las últimas 5 copias
      await _pruneOldBackups(driveApi);

      // 4. Actualizar timestamp de último respaldo
      await saveConfig(config.copyWith(lastBackupAt: now));

      AppLogger.info(
        'GoogleDriveBackupService',
        'Respaldo exitoso en Google Drive: $fileName ($fileSize bytes)',
      );
      return metadata;
    } catch (e, stack) {
      AppLogger.error('GoogleDriveBackupService.uploadEncryptedBackup', e, stack);
      rethrow;
    } finally {
      // Limpiar archivo temporal si existe
      if (backupFile != null && await backupFile.exists()) {
        try {
          await backupFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Política FIFO: conserva las últimas 5 copias fechadas y elimina las excedentes
  Future<void> _pruneOldBackups(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "trashed = false and name contains 'mochilalista_backup_'",
        $fields: 'files(id, name, createdTime, size)',
      );

      final files = fileList.files ?? [];
      if (files.length <= 5) return;

      // Ordenar descendente (más recientes primero)
      files.sort((a, b) {
        final aTime = a.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      // Eliminar de la 5ta en adelante
      for (int i = 5; i < files.length; i++) {
        final oldFile = files[i];
        if (oldFile.id != null) {
          try {
            await driveApi.files.delete(oldFile.id!);
            AppLogger.info(
              'GoogleDriveBackupService',
              'Rotación FIFO: eliminada copia antigua ${oldFile.name}',
            );
          } catch (e) {
            AppLogger.warning('GoogleDriveBackupService', 'No se pudo eliminar copia antigua: $e');
          }
        }
      }
    } catch (e) {
      AppLogger.warning('GoogleDriveBackupService', 'Error durante rotación FIFO: $e');
    }
  }

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async {
    try {
      final driveApi = await _getDriveApi();
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "trashed = false and name contains 'mochilalista_backup_'",
        $fields: 'files(id, name, createdTime, size)',
      );

      final files = fileList.files ?? [];
      final result = <GoogleDriveBackupMetadata>[];

      for (var f in files) {
        if (f.id != null && f.name != null) {
          DateTime created = f.createdTime ?? DateTime.now();
          // Intentar parsear fecha desde el nombre de archivo si createdTime es nulo
          if (f.createdTime == null) {
            try {
              final rawDate = f.name!.replaceAll('mochilalista_backup_', '').replaceAll('.mlbg', '');
              created = DateFormat('yyyyMMdd_HHmmss').parse(rawDate);
            } catch (_) {}
          }

          result.add(
            GoogleDriveBackupMetadata(
              fileId: f.id!,
              fileName: f.name!,
              createdAt: created,
              sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
            ),
          );
        }
      }

      // Ordenar más recientes primero
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (e, stack) {
      AppLogger.error('GoogleDriveBackupService.listBackups', e, stack);
      return [];
    }
  }

  @override
  Future<DriveRestoreResult> downloadAndRestoreBackup(
    String fileId, {
    String? customPassphrase,
  }) async {
    File? tempFile;
    try {
      var user = await getCurrentUser();
      user ??= await signInSilently();
      if (user == null) {
        return DriveRestoreResult.failure("Debes iniciar sesión con la cuenta de Google propietaria.");
      }

      final driveApi = await _getDriveApi();

      // 1. Descargar el archivo .mlbg desde appDataFolder
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        p.join(tempDir.path, 'drive_restore_${DateTime.now().millisecondsSinceEpoch}.mlbg'),
      );
      final sink = tempFile.openWrite();
      await response.stream.pipe(sink);
      await sink.flush();
      await sink.close();

      // 2. Derivar clave de descifrado con googleUser.id
      final config = await getConfig();
      final derivedPassword = BackupCryptoHelper.deriveDrivePassword(
        googleUserId: user.id,
        customPassphrase: customPassphrase ?? config.customPassphrase,
      );

      // 3. Ejecutar protocolo de restauración en caliente
      final restoreRes = await BackupManager.restoreBackupFromFilePath(
        tempFile.path,
        password: derivedPassword,
        pbkdf2Iterations: BackupCryptoHelper.drivePbkdf2Iterations,
      );

      if (!restoreRes.isSuccess) {
        return DriveRestoreResult.failure(restoreRes.message);
      }

      if (restoreRes.isSameDevice) {
        return DriveRestoreResult.successSameDevice(deviceId: restoreRes.newDeviceId);
      } else {
        return DriveRestoreResult.successDifferentDevice(
          oldDeviceId: restoreRes.oldDeviceId,
          newDeviceId: restoreRes.newDeviceId,
        );
      }
    } catch (e, stack) {
      AppLogger.error('GoogleDriveBackupService.downloadAndRestoreBackup', e, stack);
      return DriveRestoreResult.failure("Error restaurando copia: ${e.toString().replaceAll('Exception:', '').trim()}");
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected}) async {
    try {
      final config = await getConfig();
      if (!config.isEnabled) return false;
      if (config.frequency == BackupFrequency.manual) return false;

      final hours = config.frequency.intervalHours;
      if (hours != null && config.lastBackupAt != null) {
        final elapsed = DateTime.now().difference(config.lastBackupAt!).inHours;
        if (elapsed < hours) return false;
      }

      // Validar filtro Wi-Fi
      if (config.wifiOnly) {
        bool isWifi = isWifiConnected ?? false;
        if (isWifiConnected == null) {
          try {
            final conn = await _connectivity.checkConnectivity();
            isWifi = (conn == ConnectivityResult.wifi);
          } catch (_) {
            isWifi = false;
          }
        }
        if (!isWifi) {
          debugPrint('ℹ️ [GoogleDriveBackupService] Respaldo omitido: esperando conexión Wi-Fi.');
          return false;
        }
      }

      // Autenticación silenciosa en primer plano no bloqueante
      final user = await signInSilently();
      if (user == null) {
        debugPrint('ℹ️ [GoogleDriveBackupService] Respaldo omitido: sesión silenciosa no disponible.');
        return false;
      }

      // Ejecutar respaldo
      await uploadEncryptedBackup();
      return true;
    } catch (e) {
      debugPrint('⚠️ [GoogleDriveBackupService] Error en respaldo periódico silencioso: $e');
      return false;
    }
  }
}
