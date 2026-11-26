import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../config_service.dart';
import '../core/backup_rotation_helper.dart';
import '../core/csv_utils.dart';
import '../core/semver_utils.dart';
import '../core/time_utils.dart';
import '../license_signer.dart';

part 'clients_repository.dart';
part 'clients_lifecycle_repository.dart';
part 'payments_receipts_repository.dart';
part 'finances_export_repository.dart';
part 'backups_repository.dart';
part 'releases_repository.dart';
part 'sandbox_seed_data.dart';

/// Excepción de protección anti-sobreescritura para fichas de sincronización cronológicamente desfasadas.
class StaleSyncException implements Exception {
  final String message;
  final DateTime syncTimestamp;
  final DateTime lastSyncAt;

  StaleSyncException(
    this.message, {
    required this.syncTimestamp,
    required this.lastSyncAt,
  });

  @override
  String toString() => message;
}

abstract class _DatabaseServiceBase {
  String get dataDir;
  String get backupDir;
  String get releasesDir;
  int get maxAutoSnapshots;

  String get _mode;

  String get currentMode;
  Future<void> Function()? get onProductionDataChanged;

  File get _clientsFile;
  File get _releasesFile;

  Future<void> _createSnapshot(String reason, {String? targetMode});
  Future<void> reloadFromDisk();

  Future<List<Map<String, dynamic>>> getClients();
  Future<void> saveClients(
    List<Map<String, dynamic>> clients, {
    String reason = 'update_clients',
  });
  Future<Map<String, dynamic>?> getClientById(String id);
  Future<Map<String, dynamic>?> updateClient(
    String id,
    Map<String, dynamic> updates,
  );

  Future<List<Map<String, dynamic>>> getReleases();
  Future<void> saveReleases(
    List<Map<String, dynamic>> releases, {
    String reason = 'update_releases',
  });
  void applyReleaseUpdatesToMap(
    Map<String, dynamic> release,
    Map<String, dynamic> updates,
  );
}

/// Servicio de Persistencia Real en Disco Duro con Arquitectura de Doble Estado.
/// Soporta `'sandbox'` (Modo Pruebas) y `'prod'` (Modo Producción Real).
class DatabaseService extends _DatabaseServiceBase
    with
        _ClientsRepositoryMixin,
        _ClientsLifecycleMixin,
        _PaymentsReceiptsRepositoryMixin,
        _FinancesExportRepositoryMixin,
        _BackupsRepositoryMixin,
        _ReleasesRepositoryMixin,
        _SandboxSeedDataMixin {
  @override
  final String dataDir;
  @override
  final String backupDir;
  @override
  final String releasesDir;
  @override
  final int maxAutoSnapshots;

  @override
  String _mode = 'sandbox';

  /// Callback opcional no bloqueante disparado únicamente cuando se guardan datos en modo `'prod'`.
  @override
  Future<void> Function()? onProductionDataChanged;

  DatabaseService({
    this.dataDir = 'data',
    this.backupDir = 'backups',
    this.releasesDir = 'releases_apks',
    this.maxAutoSnapshots = 30,
  });

  @override
  String get currentMode => _mode;

  void setMode(String newMode) {
    if (newMode != 'sandbox' && newMode != 'prod') {
      throw ArgumentError('Modo no válido. Use "sandbox" o "prod".');
    }
    _mode = newMode;
  }

  @override
  File get _clientsFile => File('$dataDir/${_mode}_clients_db.json');
  @override
  File get _releasesFile => File('$dataDir/${_mode}_releases_db.json');
  Directory get currentReleasesApkDir => Directory('$releasesDir/$_mode');

  static final RegExp _safeBackupFilenameRegex =
      RegExp(r'^[A-Za-z0-9._-]+\.json$');

  /// Valida estrictamente el nombre de archivo de respaldo contra path traversal y secuencias inseguras.
  static bool isSafeBackupFilename(String? rawFilename) {
    if (rawFilename == null) return false;
    final filename = rawFilename.trim();
    if (filename.isEmpty) return false;
    if (filename.contains('/') ||
        filename.contains(r'\') ||
        filename.contains('..') ||
        filename.contains('\x00')) {
      return false;
    }
    return _safeBackupFilenameRegex.hasMatch(filename);
  }

  /// Determina si un archivo de respaldo está protegido contra purgas y rotaciones automáticas.
  static bool isProtectedBackupFilename(String filename) =>
      BackupRotationHelper.isProtectedBackupFilename(filename);

  /// Normalización estándar de teléfonos WhatsApp Perú (`+51`).
  static String normalizePeruPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    if (hasPlus) {
      return '+$digits';
    }
    if (digits.length == 9 && digits.startsWith('9')) {
      return '+51$digits';
    }
    if (digits.length == 11 && digits.startsWith('519')) {
      return '+$digits';
    }
    return digits;
  }

  /// Helper oficial para consultar la cuota IA base acumulativa por plan.
  static int getCumulativeScansForPlan(String planName) =>
      LicenseSigner.getCumulativeScansForPlan(planName);

  /// Infiere días otorgados coherentes por plan/concepto cuando un pago histórico no registra `days_added` explícito.
  static int inferDefaultDaysForPlan(String? rawPlan) =>
      _FinancesExportHelper.inferDefaultDaysForPlan(rawPlan);

  /// Infiere créditos IA otorgados por plan/concepto cuando un pago histórico no registra `ai_extra_credits` explícito.
  static int inferDefaultAiForPlan(String? rawPlan) =>
      _FinancesExportHelper.inferDefaultAiForPlan(rawPlan);

  /// Comparador SemVer numérico determinista (ignora prefijos `'v'` y desempata `+build`).
  static int compareSemVer(String? a, String? b) =>
      SemVerUtils.compare(a, b, compareBuild: true);

  /// Inicializa directorios y archivos si no existen.
  Future<void> init() async {
    await Directory(dataDir).create(recursive: true);
    await Directory(backupDir).create(recursive: true);
    await Directory('$releasesDir/sandbox').create(recursive: true);
    await Directory('$releasesDir/prod').create(recursive: true);

    final sandboxClientsFile = File('$dataDir/sandbox_clients_db.json');
    final sandboxReleasesFile = File('$dataDir/sandbox_releases_db.json');

    if (!await sandboxClientsFile.exists()) {
      final legacyClients = File('$dataDir/clients_db.json');
      if (await legacyClients.exists()) {
        await legacyClients.copy(sandboxClientsFile.path);
      } else {
        await sandboxClientsFile.writeAsString(
          const JsonEncoder.withIndent('  ')
              .convert(_getInitialSandboxClients()),
        );
      }
    }

    if (!await sandboxReleasesFile.exists()) {
      final legacyReleases = File('$dataDir/releases_db.json');
      if (await legacyReleases.exists()) {
        await legacyReleases.copy(sandboxReleasesFile.path);
      } else {
        await sandboxReleasesFile.writeAsString(
          const JsonEncoder.withIndent('  ')
              .convert(_getInitialSandboxReleases()),
        );
      }
    }

    final prodClientsFile = File('$dataDir/prod_clients_db.json');
    final prodReleasesFile = File('$dataDir/prod_releases_db.json');

    if (!await prodClientsFile.exists()) {
      await prodClientsFile.writeAsString('[]');
    }
    if (!await prodReleasesFile.exists()) {
      await prodReleasesFile.writeAsString('[]');
    }
  }

  /// Restablece los datos del entorno de pruebas a su estado inicial.
  Future<void> resetSandbox() async {
    final oldMode = _mode;
    _mode = 'sandbox';
    try {
      await _createSnapshot('before_reset_sandbox');
      await _clientsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_getInitialSandboxClients()),
      );
      await _releasesFile.writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert(_getInitialSandboxReleases()),
      );
      await _createSnapshot('after_reset_sandbox');
    } finally {
      _mode = oldMode;
    }
  }

  @override
  Future<void> _createSnapshot(String reason, {String? targetMode}) async {
    final effectiveMode = targetMode ?? _mode;
    final clientsFile = File('$dataDir/${effectiveMode}_clients_db.json');
    final releasesFile = File('$dataDir/${effectiveMode}_releases_db.json');
    final backupsDirectory = Directory(backupDir);
    final now = DateTime.now();

    await BackupRotationHelper.copyFileAsSnapshot(
      sourceFile: clientsFile,
      backupsDirectory: backupsDirectory,
      prefix: '${effectiveMode}_clients',
      reason: reason,
      timestamp: now,
    );
    await BackupRotationHelper.copyFileAsSnapshot(
      sourceFile: releasesFile,
      backupsDirectory: backupsDirectory,
      prefix: '${effectiveMode}_releases',
      reason: reason,
      timestamp: now,
    );
    await _cleanOldSnapshots();
  }

  Future<void> _cleanOldSnapshots({int? maxAutoSnapshots}) =>
      BackupRotationHelper.cleanOldSnapshots(
        backupsDirectory: Directory(backupDir),
        autoPrefixes: const ['sandbox_', 'prod_'],
        maxAutoSnapshots: maxAutoSnapshots ?? this.maxAutoSnapshots,
        protectedTokensList: BackupRotationHelper.autoRotationProtectedTokens,
      );

  /// Método público para forzar o parametrizar la limpieza de snapshots automáticos.
  Future<void> cleanOldSnapshots({int? maxAutoSnapshots}) =>
      _cleanOldSnapshots(maxAutoSnapshots: maxAutoSnapshots);

  /// Refresca en memoria los registros de producción y releases desde disco.
  @override
  Future<void> reloadFromDisk() async {
    await Directory(dataDir).create(recursive: true);
    await Directory(backupDir).create(recursive: true);
    await getClients();
    await getReleases();
  }
}
