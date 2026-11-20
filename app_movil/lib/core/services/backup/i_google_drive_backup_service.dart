import 'package:intl/intl.dart';

/// Modelo de usuario autenticado en Google para respaldos en Drive
class GoogleDriveUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const GoogleDriveUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory GoogleDriveUser.fromMap(Map<String, dynamic> map) {
    return GoogleDriveUser(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
    );
  }

  @override
  String toString() => 'GoogleDriveUser($email, id: $id)';
}

/// Frecuencia programada de respaldo en la nube
enum BackupFrequency {
  daily,
  weekly,
  monthly,
  manual;

  String get label {
    switch (this) {
      case BackupFrequency.daily:
        return 'Diario (24h)';
      case BackupFrequency.weekly:
        return 'Semanal (7 días)';
      case BackupFrequency.monthly:
        return 'Mensual (30 días)';
      case BackupFrequency.manual:
        return 'Manual';
    }
  }

  int? get intervalHours {
    switch (this) {
      case BackupFrequency.daily:
        return 24;
      case BackupFrequency.weekly:
        return 168;
      case BackupFrequency.monthly:
        return 720;
      case BackupFrequency.manual:
        return null;
    }
  }

  static BackupFrequency fromString(String? val) {
    if (val == null) return BackupFrequency.daily;
    return BackupFrequency.values.firstWhere(
      (e) => e.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => BackupFrequency.daily,
    );
  }
}

/// Configuración de respaldos en Google Drive
class DriveBackupConfig {
  final bool isEnabled;
  final BackupFrequency frequency;
  final bool wifiOnly;
  final DateTime? lastBackupAt;
  final String? customPassphrase;

  const DriveBackupConfig({
    this.isEnabled = false,
    this.frequency = BackupFrequency.daily,
    this.wifiOnly = true,
    this.lastBackupAt,
    this.customPassphrase,
  });

  DriveBackupConfig copyWith({
    bool? isEnabled,
    BackupFrequency? frequency,
    bool? wifiOnly,
    DateTime? lastBackupAt,
    String? customPassphrase,
    bool clearPassphrase = false,
  }) {
    return DriveBackupConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      frequency: frequency ?? this.frequency,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      customPassphrase: clearPassphrase ? null : (customPassphrase ?? this.customPassphrase),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'frequency': frequency.name,
      'wifiOnly': wifiOnly,
      'lastBackupAt': lastBackupAt?.toIso8601String(),
      'customPassphrase': customPassphrase,
    };
  }

  factory DriveBackupConfig.fromMap(Map<String, dynamic> map) {
    return DriveBackupConfig(
      isEnabled: map['isEnabled'] as bool? ?? false,
      frequency: BackupFrequency.fromString(map['frequency'] as String?),
      wifiOnly: map['wifiOnly'] as bool? ?? true,
      lastBackupAt: map['lastBackupAt'] != null
          ? DateTime.tryParse(map['lastBackupAt'] as String)
          : null,
      customPassphrase: map['customPassphrase'] as String?,
    );
  }
}

/// Metadatos de un archivo de respaldo fechado en Google Drive
class GoogleDriveBackupMetadata {
  final String fileId;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  const GoogleDriveBackupMetadata({
    required this.fileId,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      final kb = sizeBytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final local = createdAt.toLocal();
    final formatter = DateFormat('dd/MM/yyyy • hh:mm a');
    return formatter.format(local);
  }

  Map<String, dynamic> toMap() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'createdAt': createdAt.toIso8601String(),
      'sizeBytes': sizeBytes,
    };
  }

  factory GoogleDriveBackupMetadata.fromMap(Map<String, dynamic> map) {
    return GoogleDriveBackupMetadata(
      fileId: map['fileId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Resultado de una operación de restauración desde Google Drive
class DriveRestoreResult {
  final bool isSuccess;
  final bool isSameDevice;
  final bool requiresLicenseMigration;
  final String? oldDeviceId;
  final String? newDeviceId;
  final String message;

  const DriveRestoreResult({
    required this.isSuccess,
    required this.isSameDevice,
    required this.requiresLicenseMigration,
    this.oldDeviceId,
    this.newDeviceId,
    required this.message,
  });

  factory DriveRestoreResult.successSameDevice({String? deviceId}) {
    return DriveRestoreResult(
      isSuccess: true,
      isSameDevice: true,
      requiresLicenseMigration: false,
      oldDeviceId: deviceId,
      newDeviceId: deviceId,
      message: 'Base de datos y licencia restauradas exitosamente desde Google Drive.',
    );
  }

  factory DriveRestoreResult.successDifferentDevice({
    required String? oldDeviceId,
    required String? newDeviceId,
  }) {
    return DriveRestoreResult(
      isSuccess: true,
      isSameDevice: false,
      requiresLicenseMigration: true,
      oldDeviceId: oldDeviceId,
      newDeviceId: newDeviceId,
      message:
          'Datos comerciales restaurados al 100% en este nuevo dispositivo. Se requiere migración de licencia.',
    );
  }

  factory DriveRestoreResult.failure(String error) {
    return DriveRestoreResult(
      isSuccess: false,
      isSameDevice: false,
      requiresLicenseMigration: false,
      message: error,
    );
  }
}

/// Interfaz abstracta del servicio de copias de seguridad en Google Drive
abstract class IGoogleDriveBackupService {
  /// Inicia el flujo de autenticación interactivo de Google OAuth 2.0
  Future<GoogleDriveUser?> signIn();

  /// Intenta iniciar sesión silenciosamente sin desplegar diálogo
  Future<GoogleDriveUser?> signInSilently();

  /// Cierra la sesión activa en Google Drive
  Future<void> signOut();

  /// Retorna el usuario actualmente conectado (o null)
  Future<GoogleDriveUser?> getCurrentUser();

  /// Obtiene la configuración de respaldos actual
  Future<DriveBackupConfig> getConfig();

  /// Guarda una nueva configuración de respaldos
  Future<void> saveConfig(DriveBackupConfig config);

  /// Sube un respaldo cifrado AES-256-GCM a appDataFolder y aplica rotación FIFO a 5 copias
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({String? customPassphrase});

  /// Lista las últimas copias fechadas disponibles en appDataFolder (ordenadas por fecha descendente)
  Future<List<GoogleDriveBackupMetadata>> listBackups();

  /// Descarga el respaldo por fileId, descifra y ejecuta el Protocolo de Restauración en Caliente
  Future<DriveRestoreResult> downloadAndRestoreBackup(String fileId, {String? customPassphrase});

  /// Evalúa el intervalo y Wi-Fi para disparar respaldo periódico si corresponde
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected});
}
