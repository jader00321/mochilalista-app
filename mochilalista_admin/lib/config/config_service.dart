import 'dart:convert';
import 'dart:io';

import '../apk/apk_models.dart';
import '../core/backup_rotation_helper.dart';
import '../core/commercial_constants.dart';
import '../core/path_security.dart';
import 'config_apk_dirs_helper.dart';
import 'config_defaults.dart';
import 'config_normalizer.dart';
import 'config_template_renderer.dart';

export 'config_apk_dirs_helper.dart' show InvalidApkSearchDirException;

/// Servicio de Configuración Desacoplada del Propietario (Plan 09 - Pilar 3).
/// Administra `data/owner_config.json`, plantillas oficiales de WhatsApp,
/// tarifario de licencias, cuentas de pago, rutas de búsqueda APK y respaldos automáticos.
class ConfigService {
  static const String defaultFlutterBuildDir =
      ConfigDefaults.defaultFlutterBuildDir;
  static const String defaultWindowsApkLibraryDir =
      ConfigDefaults.defaultWindowsApkLibraryDir;

  final Directory dataDirectory;
  final Directory backupsDirectory;
  final int maxAutoSnapshots;

  Map<String, dynamic> _config = {};

  /// Callback opcional disparado tras `saveConfig`, `resetToDefaults` o `incrementCommercialSyncRevision`.
  Future<void> Function()? onConfigChanged;

  ConfigService({
    Directory? dataDirectory,
    Directory? backupsDirectory,
    this.maxAutoSnapshots = BackupRotationHelper.defaultMaxAutoSnapshots,
  })  : dataDirectory = dataDirectory ?? Directory('data'),
        backupsDirectory = backupsDirectory ?? Directory('backups');

  File get configFile => File('${dataDirectory.path}/owner_config.json');

  Map<String, dynamic> get config => _config;
  Map<String, dynamic> get system =>
      (_config['system'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get legalIdentity =>
      (_config['legal_identity'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get paymentMethods =>
      (_config['payment_methods'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get catalog =>
      (_config['catalog'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get templates =>
      (_config['templates'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get receiptConfig =>
      (_config['receipt_config'] as Map<String, dynamic>?) ?? {};

  /// Directorio de la biblioteca oficial local de APKs.
  String get apkLibraryDir {
    final configured = (system['apk_library_dir'] as String?) ??
        (_config['apk_library_dir'] as String?);
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return Platform.isWindows ? defaultWindowsApkLibraryDir : 'releases_apks';
  }

  /// Verifica si una ruta es insegura o prohibida para búsqueda de APKs.
  bool isForbiddenApkSearchDir(String rawPath) =>
      PathSecurity.isForbiddenApkSearchDir(
        rawPath,
        dataDirPath: dataDirectory.path,
        backupsDirPath: backupsDirectory.path,
      );

  List<ApkSearchDirConfig> buildDefaultApkSearchDirs({
    String? defaultBuildOutputDir,
  }) =>
      ConfigDefaults.buildDefaultApkSearchDirs(
        apkLibraryDir: apkLibraryDir,
        defaultBuildOutputDir: defaultBuildOutputDir,
      );

  /// Devuelve la lista efectiva y deduplicada de rutas de búsqueda configuradas.
  List<ApkSearchDirConfig> getEffectiveApkSearchDirs({
    String? defaultBuildOutputDir,
  }) =>
      ConfigApkDirsHelper.resolveEffectiveSearchDirs(
        rawList: system['apk_search_dirs'],
        apkLibraryDir: apkLibraryDir,
        defaultBuildOutputDir: defaultBuildOutputDir,
        isForbiddenDir: isForbiddenApkSearchDir,
      );

  List<String> getEffectiveApkSearchDirPaths({String? defaultBuildOutputDir}) {
    return getEffectiveApkSearchDirs(
      defaultBuildOutputDir: defaultBuildOutputDir,
    )
        .where((d) => d.enabled && d.path.trim().isNotEmpty)
        .map((d) => d.path)
        .toList();
  }

  Future<List<ApkSearchDirConfig>> saveApkSearchDirs(
    List<dynamic> rawDirs, {
    String? defaultBuildOutputDir,
  }) async {
    final validated = ConfigApkDirsHelper.validateAndBuildSearchDirEntries(
      rawDirs: rawDirs,
      isForbiddenDir: isForbiddenApkSearchDir,
    );

    final newConfig = Map<String, dynamic>.from(_config);
    final sysMap = Map<String, dynamic>.from(system);
    sysMap['apk_search_dirs'] = validated.entries;
    if (validated.syncedOfficialPath != null &&
        validated.syncedOfficialPath!.isNotEmpty) {
      sysMap['apk_library_dir'] = validated.syncedOfficialPath;
    }
    newConfig['system'] = sysMap;
    await saveConfig(newConfig);

    return getEffectiveApkSearchDirs(
      defaultBuildOutputDir: defaultBuildOutputDir,
    );
  }

  Future<List<ApkSearchDirConfig>> resetApkSearchDirsToDefaults({
    String? defaultBuildOutputDir,
  }) async {
    final defaultLib = ConfigApkDirsHelper.defaultLibraryDir();
    final defaultEntries = ConfigApkDirsHelper.buildDefaultResetEntries(
      defaultLib,
    );

    final newConfig = Map<String, dynamic>.from(_config);
    final sysMap = Map<String, dynamic>.from(system);
    sysMap['apk_library_dir'] = defaultLib;
    sysMap['apk_search_dirs'] = defaultEntries;
    newConfig['system'] = sysMap;
    await saveConfig(newConfig);

    return getEffectiveApkSearchDirs(
      defaultBuildOutputDir: defaultBuildOutputDir,
    );
  }

  double get migrationFee =>
      (catalog['HARDWARE_MIGRATION_FEE']?['price'] as num?)?.toDouble() ?? 40.0;

  int get commercialSyncRevision {
    final raw = (system['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    return raw < 0 ? 0 : raw;
  }

  Future<int> incrementCommercialSyncRevision() async {
    final nextRevision = commercialSyncRevision + 1;
    final sysMap = Map<String, dynamic>.from(system);
    sysMap['commercial_sync_revision'] = nextRevision;
    _config['system'] = sysMap;
    await _persistConfig();
    await _notifyConfigChanged('incrementCommercialSyncRevision');
    return nextRevision;
  }

  Future<void> init() async {
    if (!await dataDirectory.exists()) {
      await dataDirectory.create(recursive: true);
    }
    if (!await backupsDirectory.exists()) {
      await backupsDirectory.create(recursive: true);
    }

    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final parsed = jsonDecode(content) as Map<String, dynamic>;
        _config = ConfigDefaults.deepMerge(getDefaultConfig(), parsed);
        ConfigNormalizer.normalizeLoadedConfig(_config, parsed);
      } catch (_) {
        await _createBackupSnapshot('corrupted_recovery');
        _config = getDefaultConfig();
        await _persistConfig();
      }
    } else {
      _config = getDefaultConfig();
      await _persistConfig();
    }
  }

  static String canonicalTemplateKey(String key) =>
      ConfigDefaults.canonicalTemplateKey(key);

  static Map<String, dynamic> getDefaultConfig() =>
      ConfigDefaults.getDefaultConfig();

  int getNextReceiptCorrelative({
    required bool isSandbox,
    String voucherType = 'BOL',
  }) {
    final rc = receiptConfig;
    final isInvoice = voucherType.toUpperCase() == 'FAC';
    final key = isInvoice
        ? (isSandbox
            ? 'sandbox_next_invoice_correlative'
            : 'next_invoice_correlative')
        : (isSandbox ? 'sandbox_next_correlative' : 'next_correlative');
    return (rc[key] as num?)?.toInt() ?? 1;
  }

  Future<int> consumeReceiptCorrelative({
    required bool isSandbox,
    String voucherType = 'BOL',
  }) async {
    final rc = Map<String, dynamic>.from(receiptConfig);
    final isInvoice = voucherType.toUpperCase() == 'FAC';
    final key = isInvoice
        ? (isSandbox
            ? 'sandbox_next_invoice_correlative'
            : 'next_invoice_correlative')
        : (isSandbox ? 'sandbox_next_correlative' : 'next_correlative');
    final current = (rc[key] as num?)?.toInt() ?? 1;
    rc[key] = current + 1;
    final newConfig = Map<String, dynamic>.from(_config);
    newConfig['receipt_config'] = rc;
    await saveConfig(newConfig);
    return current;
  }

  Future<void> syncReceiptCorrelativeMin({
    required bool isSandbox,
    String voucherType = 'BOL',
    required int nextValue,
  }) async {
    final rc = Map<String, dynamic>.from(receiptConfig);
    final isInvoice = voucherType.toUpperCase() == 'FAC';
    final key = isInvoice
        ? (isSandbox
            ? 'sandbox_next_invoice_correlative'
            : 'next_invoice_correlative')
        : (isSandbox ? 'sandbox_next_correlative' : 'next_correlative');
    final current = (rc[key] as num?)?.toInt() ?? 1;
    if (nextValue > current) {
      rc[key] = nextValue;
      final newConfig = Map<String, dynamic>.from(_config);
      newConfig['receipt_config'] = rc;
      await saveConfig(newConfig);
    }
  }

  Map<String, dynamic>? getPlanConfig(String planSlug) {
    final norm = CommercialConstants.normalizePlanSlug(planSlug);
    final direct = planSlug.toUpperCase().trim();
    if (catalog.containsKey(direct)) {
      return catalog[direct] as Map<String, dynamic>;
    }
    if (catalog.containsKey(norm)) {
      return catalog[norm] as Map<String, dynamic>?;
    }
    return null;
  }

  double getPlanPrice(String planSlug, {double fallback = 35.0}) {
    final conf = getPlanConfig(planSlug);
    if (conf != null && conf['price'] is num) {
      return (conf['price'] as num).toDouble();
    }
    return fallback;
  }

  int getPlanDays(String planSlug, {int fallback = 30}) {
    final conf = getPlanConfig(planSlug);
    if (conf != null && conf['days'] is num) {
      return (conf['days'] as num).toInt();
    }
    return fallback;
  }

  int getPlanAiCredits(String planSlug, {int fallback = 50}) {
    final conf = getPlanConfig(planSlug);
    if (conf != null && conf['ai_credits'] is num) {
      return (conf['ai_credits'] as num).toInt();
    }
    return fallback;
  }

  int getPlanUpdatesMonths(String planSlug, {int fallback = 0}) {
    final conf = getPlanConfig(planSlug);
    if (conf != null) {
      final raw = conf['updates_window_months'] ?? conf['updates_months'];
      if (raw is num) {
        return raw.toInt() < 0 ? 0 : raw.toInt();
      }
    }
    return fallback;
  }

  Future<void> reloadFromDisk() async => init();

  Future<void> reload({bool notify = true}) async {
    await init();
    if (notify) {
      await _notifyConfigChanged('reload');
    }
  }

  Future<Map<String, dynamic>> saveConfig(
    Map<String, dynamic> rawNewConfig,
  ) async {
    final sanitized = ConfigNormalizer.sanitizeConfig(
      rawNewConfig,
      currentConfig: _config,
      currentLegalIdentity: legalIdentity,
      currentSystem: system,
      isForbiddenSearchDir: isForbiddenApkSearchDir,
    );

    await _createBackupSnapshot('pre_save');
    _config = sanitized;
    await _persistConfig();
    await _notifyConfigChanged('saveConfig');
    return _config;
  }

  Future<Map<String, dynamic>> resetToDefaults({String scope = 'all'}) async {
    final normScope = scope.trim().toLowerCase();
    const allowedScopes = {
      'all',
      'pricing',
      'templates',
      'payment',
      'preferences',
    };
    if (!allowedScopes.contains(normScope)) {
      throw ArgumentError.value(scope, 'scope', 'Alcance de reset inválido');
    }

    await _createBackupSnapshot('pre_reset');

    final defaults = getDefaultConfig();
    final currentCopy = _config.isNotEmpty
        ? jsonDecode(jsonEncode(_config)) as Map<String, dynamic>
        : jsonDecode(jsonEncode(defaults)) as Map<String, dynamic>;
    final prevLegal = Map<String, dynamic>.from(
        (currentCopy['legal_identity'] as Map?) ?? {});
    final curSystem =
        Map<String, dynamic>.from((currentCopy['system'] as Map?) ?? {});
    final preservedApkLib = curSystem['apk_library_dir'];
    final preservedSearchDirs = curSystem['apk_search_dirs'];
    final preservedSyncRevision = commercialSyncRevision;

    if (normScope == 'all') {
      _config = jsonDecode(jsonEncode(defaults)) as Map<String, dynamic>;
      final nextSys = Map<String, dynamic>.from(_config['system'] as Map);
      nextSys['commercial_sync_revision'] = preservedSyncRevision;
      if (preservedApkLib is String && preservedApkLib.trim().isNotEmpty) {
        nextSys['apk_library_dir'] = preservedApkLib;
      }
      if (preservedSearchDirs is List && preservedSearchDirs.isNotEmpty) {
        nextSys['apk_search_dirs'] = preservedSearchDirs;
      }
      _config['system'] = nextSys;
    } else if (normScope == 'pricing') {
      currentCopy['catalog'] = defaults['catalog'];
      currentCopy['migration_fee'] =
          (defaults['catalog']['HARDWARE_MIGRATION_FEE']['price'] as num)
              .toDouble();
      _config = _sanitizeSnapshotCopy(currentCopy);
    } else if (normScope == 'templates') {
      currentCopy['templates'] = defaults['templates'];
      _config = _sanitizeSnapshotCopy(currentCopy);
    } else if (normScope == 'payment') {
      currentCopy['legal_identity'] = defaults['legal_identity'];
      currentCopy['payment_methods'] = defaults['payment_methods'];
      ConfigNormalizer.propagateLegalIdentityToReceiptConfig(
        currentCopy,
        prevLegal: prevLegal,
      );
      _config = _sanitizeSnapshotCopy(currentCopy);
    } else if (normScope == 'preferences') {
      final defSys = Map<String, dynamic>.from(defaults['system'] as Map);
      curSystem['default_mode'] = defSys['default_mode'];
      curSystem['theme'] = defSys['theme'];
      curSystem['table_density'] = defSys['table_density'];
      curSystem['commercial_sync_revision'] = preservedSyncRevision;
      if (preservedApkLib is String && preservedApkLib.trim().isNotEmpty) {
        curSystem['apk_library_dir'] = preservedApkLib;
      }
      if (preservedSearchDirs is List && preservedSearchDirs.isNotEmpty) {
        curSystem['apk_search_dirs'] = preservedSearchDirs;
      }
      currentCopy['system'] = curSystem;
      currentCopy['preferences'] = {
        'default_environment': defSys['default_mode'],
        'default_theme': defSys['theme'],
        'table_density': defSys['table_density'],
      };
      _config = _sanitizeSnapshotCopy(currentCopy);
    }

    final finalSys =
        Map<String, dynamic>.from((_config['system'] as Map?) ?? {});
    final currentRevAfter =
        (finalSys['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    if (preservedSyncRevision > currentRevAfter) {
      finalSys['commercial_sync_revision'] = preservedSyncRevision;
      _config['system'] = finalSys;
    }

    await _persistConfig();
    await _notifyConfigChanged('resetToDefaults');
    return _config;
  }

  Map<String, dynamic> _sanitizeSnapshotCopy(Map<String, dynamic> copy) =>
      ConfigNormalizer.sanitizeConfig(
        copy,
        currentConfig: _config,
        currentLegalIdentity: legalIdentity,
        currentSystem: system,
        isForbiddenSearchDir: isForbiddenApkSearchDir,
      );

  /// Motor de Renderizado de Plantillas de WhatsApp con supresión inteligente bancaria.
  String renderTemplate(String templateKeyOrRaw, Map<String, dynamic> context) =>
      ConfigTemplateRenderer.render(
        templateKeyOrRaw: templateKeyOrRaw,
        context: context,
        templates: templates,
        paymentMethods: paymentMethods,
        legalIdentity: legalIdentity,
      );

  Future<File> _createBackupSnapshot(String reason) async {
    final dataToSave = _config.isNotEmpty ? _config : getDefaultConfig();
    final backupFile = await BackupRotationHelper.writeAtomicSnapshot(
      backupsDirectory: backupsDirectory,
      prefix: 'owner_config_backup',
      reason: reason,
      content: const JsonEncoder.withIndent('  ').convert(dataToSave),
    );
    await cleanOldSnapshots();
    return backupFile;
  }

  Future<void> cleanOldSnapshots({int? maxAutoSnapshots}) =>
      BackupRotationHelper.cleanOldSnapshots(
        backupsDirectory: backupsDirectory,
        autoPrefixes: const ['owner_config_backup_'],
        maxAutoSnapshots: maxAutoSnapshots ?? this.maxAutoSnapshots,
        protectedTokensList: BackupRotationHelper.autoRotationProtectedTokens,
      );

  Future<void> _persistConfig() async {
    await configFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(_config));
  }

  Future<void> _notifyConfigChanged(String origin) async {
    if (onConfigChanged != null) {
      try {
        await onConfigChanged!();
      } catch (e) {
        stderr.writeln(
          'Warning: Error al ejecutar onConfigChanged tras $origin: $e',
        );
      }
    }
  }
}
