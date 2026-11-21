import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/backup/google_drive_backup_service.dart';
import 'package:app_movil/core/utils/app_logger.dart';

/// Estados de salud del semáforo de respaldos en Google Drive
enum BackupHealthStatus {
  optimal,
  attention,
  none,
}

/// DTO representativo del estado de salud visual para la interfaz
class BackupHealthInfo {
  final BackupHealthStatus status;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const BackupHealthInfo({
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

/// Provider de Estado Reactivo en Memoria RAM para Copias de Seguridad en Google Drive
///
/// Actúa como Fuente Única de Verdad (Single Source of Truth) para la vinculación,
/// configuración y listado de copias de seguridad de Google Drive.
///
/// Implementa el patrón Stale-While-Revalidate con TTL configurable (5 minutos por defecto)
/// para erradicar recargas destructivas, saltos visuales y spinners bloqueantes al navegar
/// o hacer scroll en la aplicación.
class GoogleDriveBackupProvider extends ChangeNotifier {
  final IGoogleDriveBackupService service;
  final Duration cacheTtl;

  GoogleDriveUser? _currentUser;
  DriveBackupConfig _config = const DriveBackupConfig(isEnabled: false);
  List<GoogleDriveBackupMetadata> _backups = [];
  DateTime? _lastSyncedAt;
  String? _lastError;

  bool _isInitialLoading = false;
  bool _isInitializingCache = false;
  bool _isSyncingSilently = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isSigningIn = false;
  bool _hasInitialized = false;

  GoogleDriveBackupProvider({
    IGoogleDriveBackupService? service,
    this.cacheTtl = const Duration(minutes: 5),
  }) : service = service ?? GoogleDriveBackupService.instance;

  // ==========================================
  // GETTERS DE ESTADO
  // ==========================================
  GoogleDriveUser? get currentUser => _currentUser;
  bool get isConnected => _currentUser != null;
  DriveBackupConfig get config => _config;
  List<GoogleDriveBackupMetadata> get backups => List.unmodifiable(_backups);
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;

  bool get isInitialLoading => _isInitialLoading;
  bool get isSyncingSilently => _isSyncingSilently;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  bool get isSigningIn => _isSigningIn;
  bool get hasInitialized => _hasInitialized;

  /// Semáforo de salud de respaldos calculado a partir de la lista en memoria
  BackupHealthInfo get healthInfo => computeHealthInfo(backups: _backups);

  /// Helper puro y testeable para determinar el estado de salud sin huecos
  static BackupHealthInfo computeHealthInfo({
    required List<GoogleDriveBackupMetadata> backups,
    DateTime? referenceNow,
    bool isDark = false,
  }) {
    if (backups.isEmpty) {
      final color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      return BackupHealthInfo(
        status: BackupHealthStatus.none,
        label: "Sin copias en la nube",
        icon: Icons.cloud_off_outlined,
        color: color,
        backgroundColor: color.withValues(alpha: 0.12),
      );
    }

    final now = referenceNow ?? DateTime.now();
    DateTime latest = backups.first.createdAt;
    for (final b in backups) {
      if (b.createdAt.isAfter(latest)) {
        latest = b.createdAt;
      }
    }

    final diff = now.difference(latest);
    if (diff <= const Duration(hours: 24)) {
      final color = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      return BackupHealthInfo(
        status: BackupHealthStatus.optimal,
        label: "Al día • ${backups.length}/5 copias",
        icon: Icons.verified_user_rounded,
        color: color,
        backgroundColor: color.withValues(alpha: 0.12),
      );
    } else {
      final days = diff.inDays;
      final label = days <= 1
          ? "Hace 1 día • Respalda pronto"
          : "Hace $days días • Respalda pronto";
      final color = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      return BackupHealthInfo(
        status: BackupHealthStatus.attention,
        label: label,
        icon: Icons.schedule_rounded,
        color: color,
        backgroundColor: color.withValues(alpha: 0.12),
      );
    }
  }

  // ==========================================
  // INICIALIZACIÓN Y STALE-WHILE-REVALIDATE
  // ==========================================

  /// Carga instantánea desde almacenamiento local / caché para pintar la UI al instante
  ///
  /// Soporta coordinación opcional con [LicenseProvider] para asegurar que en instalaciones
  /// limpias no se lean claves residuales antes de que concluya la purga de SQLite/Keystore.
  Future<void> initializeFromCache({
    LicenseProvider? licenseProvider,
    bool force = false,
  }) async {
    if ((_hasInitialized || _isInitializingCache) && !force) {
      return;
    }

    _isInitializingCache = true;

    // Coordinación anti-carrera en arranque
    if (licenseProvider != null && !licenseProvider.isInitialized) {
      try {
        await licenseProvider.checkLicense();
      } catch (e) {
        AppLogger.w('GoogleDriveBackupProvider', 'Fallo al esperar LicenseProvider: $e');
      }
    }

    _isInitialLoading = true;
    notifyListeners();

    try {
      final user = await service.getCurrentUser();
      final conf = await service.getConfig();

      _currentUser = user;
      _config = conf;
      _hasInitialized = true;
      _isInitialLoading = false;
      _isInitializingCache = false;
      notifyListeners();

      // Si existe usuario conectado en caché y aún no tenemos copias o venció el TTL,
      // revalidar silenciosamente en segundo plano sin bloquear la UI
      if (_currentUser != null) {
        final now = DateTime.now();
        final shouldSync = _backups.isEmpty ||
            _lastSyncedAt == null ||
            now.difference(_lastSyncedAt!) >= cacheTtl;
        if (shouldSync) {
          unawaited(syncBackupsSilently());
        }
      }
    } catch (e) {
      AppLogger.w('GoogleDriveBackupProvider', 'Error inicializando desde caché: $e');
      _hasInitialized = true;
      _isInitialLoading = false;
      _isInitializingCache = false;
      notifyListeners();
    }
  }

  Future<void>? _pendingSync;

  /// Sincroniza la lista de copias en segundo plano respetando el TTL de caché
  ///
  /// - Nunca colapsa la UI ni destruye las copias previas existentes en RAM (0 saltos visuales).
  /// - Si la conexión falla, preserva la lista previa y expone [lastError] de forma no invasiva.
  Future<void> syncBackupsSilently({bool force = false}) async {
    if (!isConnected) {
      return;
    }

    if (_isSyncingSilently) {
      if (_pendingSync != null) {
        await _pendingSync;
      }
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastSyncedAt != null &&
        now.difference(_lastSyncedAt!) < cacheTtl &&
        _backups.isNotEmpty) {
      // TTL vigente: se evita llamada redundante a Google Drive API
      return;
    }

    _isSyncingSilently = true;
    notifyListeners();

    _pendingSync = _performSync();
    await _pendingSync;
  }

  Future<void> _performSync() async {
    try {
      final fetchedBackups = await service.listBackups();
      final fetchedConfig = await service.getConfig();
      _backups = fetchedBackups;
      _config = fetchedConfig;
      _lastSyncedAt = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      AppLogger.w('GoogleDriveBackupProvider', 'Revalidación silenciosa falló: $e');
    } finally {
      _isSyncingSilently = false;
      _pendingSync = null;
      notifyListeners();
    }
  }

  // ==========================================
  // ACCIONES OPERATIVAS
  // ==========================================

  /// Inicia sesión con Google OAuth 2.0 y puebla el estado en RAM
  Future<GoogleDriveUser?> signIn({String? licenseHardwareId}) async {
    _isSigningIn = true;
    _lastError = null;
    notifyListeners();

    try {
      final user = await service.signIn();
      if (user != null) {
        _currentUser = user;
        _config = await service.getConfig();

        if (licenseHardwareId != null && licenseHardwareId.isNotEmpty) {
          unawaited(service.registerTrialMarker(licenseHardwareId));
        }

        try {
          _backups = await service.listBackups();
          _lastSyncedAt = DateTime.now();
        } catch (_) {}
      }
      return user;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  /// Cierra la sesión activa en Google Drive y purga el estado de memoria RAM
  Future<void> signOut() async {
    _lastError = null;
    try {
      await service.signOut();
    } finally {
      _currentUser = null;
      _backups = [];
      _lastSyncedAt = null;
      _isSyncingSilently = false;
      notifyListeners();
    }
  }

  /// Realiza un respaldo manual inmediato a Google Drive y refresca la lista de copias
  Future<GoogleDriveBackupMetadata?> performBackupNow({String? customPassphrase}) async {
    _isBackingUp = true;
    _lastError = null;
    notifyListeners();

    try {
      final meta = await service.uploadEncryptedBackup(customPassphrase: customPassphrase);
      _backups = await service.listBackups();
      _config = await service.getConfig();
      _lastSyncedAt = DateTime.now();
      return meta;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  /// Restaura una copia de seguridad fechada desde Google Drive
  Future<DriveRestoreResult> restoreBackup(
    GoogleDriveBackupMetadata backup, {
    String? customPassphrase,
  }) async {
    _isRestoring = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await service.downloadAndRestoreBackup(
        backup.fileId,
        customPassphrase: customPassphrase,
      );
      return result;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Actualiza y persiste la configuración de respaldos
  Future<void> updateConfig(DriveBackupConfig newConfig) async {
    _config = newConfig;
    notifyListeners();

    try {
      await service.saveConfig(newConfig);
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Purga el estado en RAM para instalaciones limpias coordinadas
  void resetForCleanInstall() {
    _currentUser = null;
    _config = const DriveBackupConfig(isEnabled: false);
    _backups = [];
    _lastSyncedAt = null;
    _lastError = null;
    _isInitialLoading = false;
    _isInitializingCache = false;
    _isSyncingSilently = false;
    _isBackingUp = false;
    _isRestoring = false;
    _isSigningIn = false;
    _hasInitialized = true;
    notifyListeners();
  }
}
