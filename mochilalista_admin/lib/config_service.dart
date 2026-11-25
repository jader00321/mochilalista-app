import 'dart:convert';
import 'dart:io';
import 'apk_inspector_service.dart';
import 'time_utils.dart';

/// Excepción lanzada cuando el propietario intenta registrar una ruta prohibida o inválida
class InvalidApkSearchDirException implements Exception {
  final String message;
  const InvalidApkSearchDirException(this.message);

  @override
  String toString() => message;
}

/// Servicio de Configuración Desacoplada del Propietario (Plan 09 - Pilar 3)
/// Administra `data/owner_config.json`, plantillas oficiales de WhatsApp,
/// tarifario de licencias, cuentas de pago, rutas de búsqueda APK y respaldos automáticos.
class ConfigService {
  static const String defaultFlutterBuildDir =
      '../app_movil/build/app/outputs/flutter-apk';
  static const String defaultWindowsApkLibraryDir =
      r'C:\Users\vjuli\Documents\v-app-offline apks';

  final Directory dataDirectory;
  final Directory backupsDirectory;
  final int maxAutoSnapshots;

  Map<String, dynamic> _config = {};

  /// Callback opcional disparado tras saveConfig o resetToDefaults
  Future<void> Function()? onConfigChanged;

  ConfigService({
    Directory? dataDirectory,
    Directory? backupsDirectory,
    this.maxAutoSnapshots = 30,
  })  : dataDirectory = dataDirectory ?? Directory('data'),
        backupsDirectory = backupsDirectory ?? Directory('backups');

  File get configFile => File('${dataDirectory.path}/owner_config.json');

  Map<String, dynamic> get config => _config;
  Map<String, dynamic> get system => (_config['system'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get legalIdentity => (_config['legal_identity'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get paymentMethods => (_config['payment_methods'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get catalog => (_config['catalog'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get templates => (_config['templates'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get receiptConfig => (_config['receipt_config'] as Map<String, dynamic>?) ?? {};

  /// Directorio de la biblioteca oficial local de APKs
  String get apkLibraryDir {
    final configured = (system['apk_library_dir'] as String?) ??
        (_config['apk_library_dir'] as String?);
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return Platform.isWindows
        ? defaultWindowsApkLibraryDir
        : 'releases_apks';
  }

  /// Verifica si una ruta es insegura o prohibida para búsqueda de APKs
  /// (bloquea unidades raíz completas C:\ / D:\ / /, carpetas sensibles y rutas del sistema OS)
  bool isForbiddenApkSearchDir(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return true;

    // 1. Salvaguarda Paso 0: bloquear unidades raíz completas (ej: C:\, D:\, /) o UNC sin subcarpeta
    final slashNorm = trimmed.replaceAll('\\', '/').trim();
    if (RegExp(r'^[A-Za-z]:/?$').hasMatch(slashNorm)) return true;
    if (slashNorm == '/' || RegExp(r'^//[^/]+/?$').hasMatch(slashNorm)) return true;

    final canon = ApkInspectorService.canonicalizePath(trimmed);
    if (canon.isEmpty) return true;
    final canonSlash = canon.replaceAll('\\', '/').trim();
    if (RegExp(r'^[A-Za-z]:/?$').hasMatch(canonSlash)) return true;
    if (canonSlash == '/' || RegExp(r'^//[^/]+/?$').hasMatch(canonSlash)) return true;

    final cmp = Platform.isWindows ? canonSlash.toLowerCase() : canonSlash;
    final segments = cmp.split('/').where((s) => s.isNotEmpty).toList();

    // 2. Segmentos intrínsecamente prohibidos en cualquier ubicación
    if (segments.contains('private_keys') || segments.contains('.git')) {
      return true;
    }

    bool isSameOrChild(String target, String rootRaw) {
      final rootCanon =
          ApkInspectorService.canonicalizePath(rootRaw).replaceAll('\\', '/');
      if (rootCanon.isEmpty) return false;
      final rootCmp = Platform.isWindows ? rootCanon.toLowerCase() : rootCanon;
      return target == rootCmp || target.startsWith('$rootCmp/');
    }

    // 3. Carpetas sensibles de producción / proyecto
    final forbiddenProjectRoots = <String>[
      dataDirectory.path,
      backupsDirectory.path,
      'data',
      'backups',
      'private_keys',
      '../app_movil/android',
      'app_movil/android',
    ];
    for (final root in forbiddenProjectRoots) {
      if (isSameOrChild(cmp, root)) return true;
    }

    // 4. Rutas críticas del sistema operativo
    if (Platform.isWindows) {
      final sysRoot =
          (Platform.environment['SystemRoot'] ?? r'C:\Windows').replaceAll('\\', '/').toLowerCase();
      if (cmp == sysRoot || cmp.startsWith('$sysRoot/')) return true;
      if (cmp == 'c:/windows' || cmp.startsWith('c:/windows/')) return true;
    } else {
      const posixSystemRoots = ['/etc', '/usr', '/bin', '/sbin', '/var', '/proc', '/sys', '/dev', '/system'];
      for (final pRoot in posixSystemRoots) {
        if (cmp == pRoot || cmp.startsWith('$pRoot/')) return true;
      }
    }

    return false;
  }

  /// Construye la lista por defecto de rutas de búsqueda a partir de [apkLibraryDir]
  List<ApkSearchDirConfig> buildDefaultApkSearchDirs({String? defaultBuildOutputDir}) {
    final flutterPath = (defaultBuildOutputDir != null && defaultBuildOutputDir.trim().isNotEmpty)
        ? defaultBuildOutputDir.trim()
        : defaultFlutterBuildDir;
    return [
      ApkSearchDirConfig(
        path: apkLibraryDir,
        label: 'Biblioteca Oficial (v-app-offline apks)',
        enabled: true,
        isDefault: true,
        kind: 'official_library',
      ),
      ApkSearchDirConfig(
        path: flutterPath,
        label: 'Compilación Local (app_movil/build)',
        enabled: true,
        isDefault: true,
        kind: 'flutter_build',
      ),
    ];
  }

  /// Devuelve la lista efectiva y deduplicada de rutas de búsqueda configuradas.
  /// Mantiene 100% retrocompatibilidad cuando `apk_search_dirs` aún no existe en JSON.
  List<ApkSearchDirConfig> getEffectiveApkSearchDirs({String? defaultBuildOutputDir}) {
    final rawList = system['apk_search_dirs'];
    if (rawList is! List || rawList.isEmpty) {
      return buildDefaultApkSearchDirs(defaultBuildOutputDir: defaultBuildOutputDir);
    }

    final parsed = <ApkSearchDirConfig>[];
    final seen = <String>{};

    for (final item in rawList) {
      ApkSearchDirConfig? cfg;
      if (item is Map) {
        cfg = ApkSearchDirConfig.fromJson(Map<String, dynamic>.from(item));
      } else if (item is String && item.trim().isNotEmpty) {
        cfg = ApkSearchDirConfig(
          path: item.trim(),
          label: 'Carpeta Personalizada',
          enabled: true,
          isDefault: false,
          kind: 'custom',
        );
      }
      if (cfg == null || cfg.path.isEmpty) continue;

      if (cfg.kind == 'flutter_build' &&
          cfg.isDefault &&
          defaultBuildOutputDir != null &&
          defaultBuildOutputDir.trim().isNotEmpty) {
        cfg = cfg.copyWith(path: defaultBuildOutputDir.trim());
      }

      if (isForbiddenApkSearchDir(cfg.path)) continue;

      final canon = ApkInspectorService.canonicalizePath(cfg.path);
      final key = Platform.isWindows ? canon.toLowerCase() : canon;
      if (seen.add(key)) {
        parsed.add(cfg);
      }
    }

    if (parsed.isEmpty) {
      return buildDefaultApkSearchDirs(defaultBuildOutputDir: defaultBuildOutputDir);
    }

    return parsed;
  }

  /// Devuelve las rutas activas (habilitadas) como cadenas listas para `extraSearchDirs`
  List<String> getEffectiveApkSearchDirPaths({String? defaultBuildOutputDir}) {
    return getEffectiveApkSearchDirs(defaultBuildOutputDir: defaultBuildOutputDir)
        .where((d) => d.enabled && d.path.trim().isNotEmpty)
        .map((d) => d.path)
        .toList();
  }

  /// Valida, normaliza, deduplica y persiste la lista de rutas de búsqueda APK
  Future<List<ApkSearchDirConfig>> saveApkSearchDirs(
    List<dynamic> rawDirs, {
    String? defaultBuildOutputDir,
  }) async {
    final cleanList = <Map<String, dynamic>>[];
    final seen = <String>{};
    String? syncedOfficialPath;

    for (final item in rawDirs) {
      ApkSearchDirConfig cfg;
      if (item is ApkSearchDirConfig) {
        cfg = item;
      } else if (item is Map) {
        cfg = ApkSearchDirConfig.fromJson(Map<String, dynamic>.from(item));
      } else if (item is String) {
        cfg = ApkSearchDirConfig(
          path: item.trim(),
          label: 'Carpeta Personalizada',
          enabled: true,
          isDefault: false,
          kind: 'custom',
        );
      } else {
        continue;
      }

      final trimmedPath = cfg.path.trim();
      if (trimmedPath.isEmpty) {
        throw const InvalidApkSearchDirException(
            'La ruta de búsqueda no puede estar vacía.');
      }
      if (isForbiddenApkSearchDir(trimmedPath)) {
        throw InvalidApkSearchDirException(
            'Ruta prohibida por seguridad o demasiado amplia: "$trimmedPath".');
      }

      final storedPath = (cfg.kind == 'flutter_build' && cfg.isDefault)
          ? trimmedPath
          : ApkInspectorService.canonicalizePath(trimmedPath);
      final canonKeyRaw = ApkInspectorService.canonicalizePath(storedPath);
      final key = Platform.isWindows ? canonKeyRaw.toLowerCase() : canonKeyRaw;
      if (!seen.add(key)) continue;

      final normalizedCfg = cfg.copyWith(path: storedPath);
      if (normalizedCfg.kind == 'official_library' && syncedOfficialPath == null) {
        syncedOfficialPath = normalizedCfg.path;
      }
      cleanList.add(normalizedCfg.toJson());
    }

    if (cleanList.isEmpty) {
      throw const InvalidApkSearchDirException(
          'Debe permanecer al menos una ruta de búsqueda válida.');
    }

    final newConfig = Map<String, dynamic>.from(_config);
    final sysMap = Map<String, dynamic>.from(system);
    sysMap['apk_search_dirs'] = cleanList;
    if (syncedOfficialPath != null && syncedOfficialPath.isNotEmpty) {
      sysMap['apk_library_dir'] = syncedOfficialPath;
    }
    newConfig['system'] = sysMap;
    await saveConfig(newConfig);

    return getEffectiveApkSearchDirs(defaultBuildOutputDir: defaultBuildOutputDir);
  }

  /// Restablece las rutas de búsqueda APK a sus valores de fábrica oficiales
  Future<List<ApkSearchDirConfig>> resetApkSearchDirsToDefaults({
    String? defaultBuildOutputDir,
  }) async {
    final defaultLib = Platform.isWindows
        ? defaultWindowsApkLibraryDir
        : 'releases_apks';
    final defaultEntries = [
      ApkSearchDirConfig(
        path: defaultLib,
        label: 'Biblioteca Oficial (v-app-offline apks)',
        enabled: true,
        isDefault: true,
        kind: 'official_library',
      ).toJson(),
      const ApkSearchDirConfig(
        path: defaultFlutterBuildDir,
        label: 'Compilación Local (app_movil/build)',
        enabled: true,
        isDefault: true,
        kind: 'flutter_build',
      ).toJson(),
    ];

    final newConfig = Map<String, dynamic>.from(_config);
    final sysMap = Map<String, dynamic>.from(system);
    sysMap['apk_library_dir'] = defaultLib;
    sysMap['apk_search_dirs'] = defaultEntries;
    newConfig['system'] = sysMap;
    await saveConfig(newConfig);

    return getEffectiveApkSearchDirs(defaultBuildOutputDir: defaultBuildOutputDir);
  }

  /// Tarifa técnica oficial de migración de hardware
  double get migrationFee =>
      (catalog['HARDWARE_MIGRATION_FEE']?['price'] as num?)?.toDouble() ?? 40.0;

  /// Revisión monotónica de sincronización comercial `MLC1-...` (nunca retrocede).
  int get commercialSyncRevision {
    final raw = (system['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    return raw < 0 ? 0 : raw;
  }

  /// Incrementa atómicamente `system.commercial_sync_revision` y persiste en disco.
  Future<int> incrementCommercialSyncRevision() async {
    final nextRevision = commercialSyncRevision + 1;
    final sysMap = Map<String, dynamic>.from(system);
    sysMap['commercial_sync_revision'] = nextRevision;
    _config['system'] = sysMap;
    await _persistConfig();

    if (onConfigChanged != null) {
      try {
        await onConfigChanged!();
      } catch (e) {
        stderr.writeln(
            'Warning: Error al ejecutar onConfigChanged tras incrementCommercialSyncRevision: $e');
      }
    }
    return nextRevision;
  }

  /// Inicializa el servicio: crea directorios si no existen y carga o crea la configuración de fábrica
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
        _config = _deepMerge(getDefaultConfig(), parsed);
        _normalizeLoadedConfig(_config, parsed);
      } catch (e) {
        // En caso de corrupción, respaldar y restaurar de fábrica
        await _createBackupSnapshot('corrupted_recovery');
        _config = getDefaultConfig();
        await _persistConfig();
      }
    } else {
      _config = getDefaultConfig();
      await _persistConfig();
    }
  }

  /// Normaliza alias canónicos entre claves de `templates` (`welcome` <-> `trial_welcome`, etc.).
  static String canonicalTemplateKey(String key) {
    switch (key.trim()) {
      case 'welcome':
        return 'trial_welcome';
      case 'expiring':
        return 'expiring_reminder';
      case 'license':
        return 'license_issued';
      case 'update':
        return 'apk_update_eligible';
      default:
        return key.trim();
    }
  }

  /// Retorna la configuración oficial de fábrica completa
  static Map<String, dynamic> getDefaultConfig() {
    return {
      'system': {
        'default_mode': 'sandbox',
        'theme': 'dark',
        'table_density': 'comfortable',
        'version': '1.0.0',
        'commercial_sync_revision': 0,
        'apk_library_dir': r'C:\Users\vjuli\Documents\v-app-offline apks',
      },
      'legal_identity': {
        'author_full_name': 'Julio Angello Vasquez Navarro',
        'commercial_name': 'MochilaLista',
        'support_phone': '+51 922 836 879',
        'support_whatsapp_url': 'https://wa.me/51922836879',
        'official_website': 'https://mochilalista.com',
        'legal_framework': 'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI Perú',
        'personal_data_law': 'Ley N° 29733 (Ley de Protección de Datos Personales)',
      },
      'payment_methods': {
        'yape_plin_holder': 'Julio Angello Vasquez Navarro',
        'yape_plin_phone': '922836879',
        'bcp_account_holder': '',
        'bcp_account_number': '',
        'bcp_cci': '',
        'bbva_account_holder': '',
        'bbva_account_number': '',
        'bbva_cci': '',
      },
      'catalog': {
        'TRIAL': {
          'price': 0.0,
          'days': 30,
          'ai_credits': 50,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Prueba Gratuita',
          'description':
              'Evaluación gratuita de 30 días con funciones POS completas e IA.',
        },
        'MENSUAL': {
          'price': 35.0,
          'days': 30,
          'ai_credits': 50,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Mensual',
          'description':
              'Suscripción mensual flexible 100% offline con respaldo de base local.',
        },
        'TRIMESTRAL': {
          'price': 90.0,
          'days': 90,
          'ai_credits': 180,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Trimestral',
          'description':
              'Suscripción trimestral de 90 días con bolsa IA ampliada (+180 escaneos).',
        },
        'SEMESTRAL': {
          'price': 160.0,
          'days': 180,
          'ai_credits': 450,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Semestral',
          'description':
              'Suscripción semestral de 180 días con +450 escaneos IA acumulados.',
        },
        'ANUAL': {
          'price': 280.0,
          'days': 365,
          'ai_credits': 1200,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Anual',
          'description':
              'Suscripción anual prioritaria con +1,200 escaneos IA vitalicios incluidos.',
        },
        'PERPETUO_LIBERADO': {
          'price': 850.0,
          'days': 99999,
          'ai_credits': 200,
          'updates_window_months': 12,
          'updates_months': 12,
          'label': 'Perpetuo Liberado',
          'description':
              'Licencia vitalicia para tu negocio con 12 meses de actualizaciones incluidos.',
        },
        'PASE_ACTUALIZACION_ANUAL': {
          'price': 150.0,
          'days': 0,
          'updates_window_months': 12,
          'updates_months': 12,
          'ai_credits': 100,
          'label': 'Pase Anual de Updates',
          'description':
              'Renovación anual de versiones APK (+12 meses de actualizaciones y +100 IA).',
        },
        'RECARGA_IA_150': {
          'price': 20.0,
          'days': 0,
          'ai_credits': 150,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Recarga Extra IA (+150)',
          'description':
              'Bolsa adicional de +150 escaneos de IA acumulativos sin vencimiento.',
        },
        'EXTENSION_CORTESIA': {
          'price': 0.0,
          'days': 7,
          'ai_credits': 0,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Extensión de Cortesía',
          'description':
              'Extensión temporal de gracia sin costo (S/ 0.00) por 7 días.',
        },
        'HARDWARE_MIGRATION_FEE': {
          'price': 40.0,
          'days': 0,
          'ai_credits': 0,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Tarifa Técnica de Migración',
          'description':
              'Servicio técnico de traslado y re-emisión de licencia a un nuevo celular.',
        },
      },
      'templates': {
        'license_issued':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            '¡Tu licencia para *{negocio}* ha sido emitida exitosamente!\n\n'
            '⭐ *Plan:* {plan} ({dias} días)\n'
            '📱 *Dispositivo Vinculado:* {device_id}\n'
            '📅 *Vigencia hasta:* {vencimiento}\n'
            '⚡ *Escáner IA:* +{creditos_ia} escaneos acumulados acreditados\n\n'
            '🔑 *Tu Código de Activación Oficial:*\n'
            '{codigo}\n\n'
            'Para activarlo en tu app:\n'
            '1. Abre MochilaLista en tu teléfono.\n'
            '2. Ve a Menú > Licencia y Activación.\n'
            '3. Pega el código de arriba o escanea la credencial oficial adjunta.\n\n'
            '¡Gracias por tu confianza y éxito en tus ventas!',
        'expiring_reminder':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Te recordamos que la licencia de tu negocio *{negocio}* vence en *{dias_restantes} días* ({vencimiento}).\n\n'
            'Para renovar tu servicio sin interrupciones en tus ventas:\n'
            '💳 Yape / Plin: {yape_phone} ({yape_titular}){bloque_banco_bcp}{bloque_banco_bbva}\n\n'
            'Quedo a tu disposición para emitir tu renovación inmediata.',
        'trial_welcome':
            '¡Bienvenido a MochilaLista, {titular}!\n\n'
            'Hemos activado tu periodo de prueba gratuita de 30 días para *{negocio}* con 50 escaneos inteligentes de IA incluidos.\n\n'
            '📱 *Dispositivo:* {device_id}\n'
            '📅 *Vence el:* {vencimiento}\n\n'
            '🔑 *Tu Código de Activación:*\n'
            '{codigo}\n\n'
            '¡Comienza a registrar tus ventas e inventario hoy mismo!',
        'prospect':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Nos comunicamos para hacer seguimiento a la evaluación del sistema de punto de venta en tu negocio *{negocio}*.\n\n'
            '¿Has tenido oportunidad de revisar las funciones de cobro rápido, inventario e IA offline?\n'
            'Con gusto podemos coordinar una breve demostración o habilitarte una activación personalizada adaptada al ritmo de tu negocio.\n\n'
            'Quedamos a tu orden.',
        'ai_bonus':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Tu recarga de escaneos de Inteligencia Artificial para *{negocio}* ha sido acreditada con éxito.\n\n'
            '*Detalle de la Recarga:*\n'
            '• Créditos IA Otorgados: +{creditos_ia} escaneos vitalicios\n'
            '• Hardware ID Vinculado: `{device_id}`\n\n'
            '*Token de Activación IA:*\n'
            '{codigo}\n\n'
            'Ingresa este código o escanea el QR en tu app para sumarlos de inmediato a tu saldo disponible.',
        'courtesy_extension':
            'Estimado(a) {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Te confirmamos la habilitación de una extensión de cortesía por *{dias} día(s)* adicionales para *{negocio}*.\n\n'
            '• Nueva vigencia temporal: *{vencimiento}*\n'
            '• Hardware ID: `{device_id}`\n\n'
            '*Código de Activación:*\n'
            '{codigo}\n\n'
            'Ingresa este código en tu aplicación para continuar operando sin interrupciones.',
        'apk_update_eligible':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            '¡Tenemos lista una nueva actualización oficial para *{negocio}*!\n\n'
            '📦 *Versión:* MochilaLista v{version}\n'
            '✨ *Novedades:*\n'
            '{changelog}\n\n'
            '📥 *Enlace de Descarga Directa:*\n'
            '{link_descarga}\n\n'
            '🛡️ *Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.',
        'apk_update_quote':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Acabamos de lanzar la versión oficial *v{version}* con mejoras avanzadas.\n'
            'Tu negocio *{negocio}* cuenta con la versión v{version_actual}.\n\n'
            'Para acceder a este paquete de nuevas funciones, puedes adquirir tu *Pase Anual de Actualizaciones* por solo S/ {precio_pase}.\n'
            '¿Deseas que te emita el pase hoy mismo?',
        'device_migration':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Hemos completado la migración de tu licencia al nuevo teléfono para *{negocio}*.\n\n'
            '📱 *Nuevo Dispositivo:* {device_id}\n'
            '📅 *Vencimiento Preservado:* {vencimiento}\n'
            '⚡ *Saldo IA Preservado:* +{creditos_ia} escaneos disponibles\n\n'
            '🔑 *Tu Nuevo Código de Activación:*\n'
            '{codigo}\n\n'
            'Actívalo en tu nuevo teléfono para continuar operando sin contratiempos.',
      },
      'receipt_config': {
        'title': 'BOLETA DE PAGO ADMINISTRATIVA',
        'commercial_name': 'MochilaLista',
        'issuer_name': 'Julio Angello Vasquez Navarro',
        'issuer_doc': 'D.N.I. / R.U.C. Registrado',
        'issuer_phone': '+51 922 836 879',
        'issuer_city': 'Piura, Perú',
        'show_logo': true,
        'accent_color': '#2563eb',
        'footer_notes':
            'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.',
        'signature_text': 'Administración Comercial — MochilaLista',
        'next_correlative': 1,
        'sandbox_next_correlative': 1,
        'next_invoice_correlative': 1,
        'sandbox_next_invoice_correlative': 1,
        'show_igv_breakdown': false,
        'show_issuer_doc': true,
        'show_issuer_phone': true,
        'show_client_doc': true,
        'show_hardware_id': true,
        'show_operation_number': true,
        'show_observation': true,
        'show_signature': true,
        'show_footer_notes': true,
      },
    };
  }

  /// Retorna el siguiente número correlativo disponible según el tipo de comprobante y modo activo
  int getNextReceiptCorrelative({required bool isSandbox, String voucherType = 'BOL'}) {
    final rc = receiptConfig;
    final isInvoice = voucherType.toUpperCase() == 'FAC';
    final key = isInvoice
        ? (isSandbox ? 'sandbox_next_invoice_correlative' : 'next_invoice_correlative')
        : (isSandbox ? 'sandbox_next_correlative' : 'next_correlative');
    return (rc[key] as num?)?.toInt() ?? 1;
  }

  /// Consume atómicamente el correlativo actual para emitir un comprobante (BOL o FAC) y lo incrementa en +1
  Future<int> consumeReceiptCorrelative({required bool isSandbox, String voucherType = 'BOL'}) async {
    final rc = Map<String, dynamic>.from(receiptConfig);
    final isInvoice = voucherType.toUpperCase() == 'FAC';
    final key = isInvoice
        ? (isSandbox ? 'sandbox_next_invoice_correlative' : 'next_invoice_correlative')
        : (isSandbox ? 'sandbox_next_correlative' : 'next_correlative');
    final current = (rc[key] as num?)?.toInt() ?? 1;
    rc[key] = current + 1;
    final newConfig = Map<String, dynamic>.from(_config);
    newConfig['receipt_config'] = rc;
    await saveConfig(newConfig);
    return current;
  }

  /// Sincroniza atómicamente el correlativo para que sea como mínimo [nextValue] (Blindaje Anti-Colisión Plan 18.5)
  Future<void> syncReceiptCorrelativeMin({
    required bool isSandbox,
    String voucherType = 'BOL',
    required int nextValue,
  }) async {
    final rc = Map<String, dynamic>.from(receiptConfig);
    final isInvoice = voucherType.toUpperCase() == 'FAC';
    final key = isInvoice
        ? (isSandbox ? 'sandbox_next_invoice_correlative' : 'next_invoice_correlative')
        : (isSandbox ? 'sandbox_next_correlative' : 'next_correlative');
    final current = (rc[key] as num?)?.toInt() ?? 1;
    if (nextValue > current) {
      rc[key] = nextValue;
      final newConfig = Map<String, dynamic>.from(_config);
      newConfig['receipt_config'] = rc;
      await saveConfig(newConfig);
    }
  }

  /// Consulta la configuración de un plan específico del catálogo
  Map<String, dynamic>? getPlanConfig(String planSlug) {
    final norm = planSlug.toUpperCase().trim();
    if (catalog.containsKey(norm)) {
      return catalog[norm] as Map<String, dynamic>;
    }
    // Alias tolerantes
    if (norm == 'PASE_UPDATES_12M' || norm == 'PASE_ANUAL_UPDATES') {
      return catalog['PASE_ACTUALIZACION_ANUAL'] as Map<String, dynamic>?;
    }
    if (norm == 'PERPETUO' || norm == 'PERPETUA') {
      return catalog['PERPETUO_LIBERADO'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Retorna el precio oficial configurado para un plan
  double getPlanPrice(String planSlug, {double fallback = 35.0}) {
    final conf = getPlanConfig(planSlug);
    if (conf != null && conf['price'] is num) {
      return (conf['price'] as num).toDouble();
    }
    return fallback;
  }

  /// Retorna los días de vigencia oficiales configurados para un plan
  int getPlanDays(String planSlug, {int fallback = 30}) {
    final conf = getPlanConfig(planSlug);
    if (conf != null && conf['days'] is num) {
      return (conf['days'] as num).toInt();
    }
    return fallback;
  }

  /// Retorna los créditos IA acumulativos oficiales configurados para un plan
  int getPlanAiCredits(String planSlug, {int fallback = 50}) {
    final conf = getPlanConfig(planSlug);
    if (conf != null && conf['ai_credits'] is num) {
      return (conf['ai_credits'] as num).toInt();
    }
    return fallback;
  }

  /// Retorna los meses de ventana de actualizaciones configurados para un plan
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

  /// Recarga en memoria la configuración desde el archivo en disco
  Future<void> reloadFromDisk() async {
    await init();
  }

  /// Recarga la configuración desde disco tras restaurar un respaldo GLOBAL y notifica oyentes si [notify] es true.
  Future<void> reload({bool notify = true}) async {
    await init();
    if (notify && onConfigChanged != null) {
      try {
        await onConfigChanged!();
      } catch (e) {
        stderr.writeln(
            'Warning: Error al ejecutar onConfigChanged tras reload: $e');
      }
    }
  }

  /// Valida, respalda automáticamente en `backups/` y persiste los cambios de configuración
  Future<Map<String, dynamic>> saveConfig(Map<String, dynamic> rawNewConfig) async {
    final sanitized = _sanitizeConfig(rawNewConfig);

    // Crear respaldo automático del estado actual previo a la modificación
    await _createBackupSnapshot('pre_save');

    _config = sanitized;
    await _persistConfig();

    if (onConfigChanged != null) {
      try {
        await onConfigChanged!();
      } catch (e) {
        stderr.writeln('Warning: Error al ejecutar onConfigChanged tras saveConfig: $e');
      }
    }
    return _config;
  }

  /// Restaura la configuración a los valores de fábrica de MochilaLista
  /// según [scope] (`all`, `pricing`, `templates`, `payment`, `preferences`),
  /// creando un snapshot de respaldo `pre_reset` del estado previo y preservando
  /// `system.apk_library_dir` y `system.apk_search_dirs`.
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
      _config = _sanitizeConfig(currentCopy);
    } else if (normScope == 'templates') {
      currentCopy['templates'] = defaults['templates'];
      _config = _sanitizeConfig(currentCopy);
    } else if (normScope == 'payment') {
      currentCopy['legal_identity'] = defaults['legal_identity'];
      currentCopy['payment_methods'] = defaults['payment_methods'];
      _propagateLegalIdentityToReceiptConfig(
        currentCopy,
        prevLegal: prevLegal,
      );
      _config = _sanitizeConfig(currentCopy);
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
      _config = _sanitizeConfig(currentCopy);
    }

    // Doble garantía anti-downgrade en todos los alcances de reset
    final finalSys =
        Map<String, dynamic>.from((_config['system'] as Map?) ?? {});
    final currentRevAfter =
        (finalSys['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    if (preservedSyncRevision > currentRevAfter) {
      finalSys['commercial_sync_revision'] = preservedSyncRevision;
      _config['system'] = finalSys;
    }

    await _persistConfig();

    if (onConfigChanged != null) {
      try {
        await onConfigChanged!();
      } catch (e) {
        stderr.writeln(
            'Warning: Error al ejecutar onConfigChanged tras resetToDefaults: $e');
      }
    }
    return _config;
  }

  /// Motor de Renderizado de Plantillas de WhatsApp (Plan 09 - Sección 5.3)
  /// Aplica supresión inteligente de cuentas bancarias vacías y variables dinámicas.
  String renderTemplate(String templateKeyOrRaw, Map<String, dynamic> context) {
    String template = templateKeyOrRaw;
    if (templates.containsKey(templateKeyOrRaw)) {
      template = templates[templateKeyOrRaw] as String;
    } else {
      final canonKey = canonicalTemplateKey(templateKeyOrRaw);
      if (templates.containsKey(canonKey)) {
        template = templates[canonKey] as String;
      }
    }

    final pm = paymentMethods;
    final li = legalIdentity;

    // 1. Supresión Inteligente de Cuentas Bancarias Vacías
    final bcpAccount = (pm['bcp_account_number'] as String? ?? '').trim();
    final bcpHolder = (pm['bcp_account_holder'] as String? ?? '').trim();
    final bcpCci = (pm['bcp_cci'] as String? ?? '').trim();

    String bcpBlock = '';
    if (bcpAccount.isNotEmpty) {
      final cciPart = bcpCci.isNotEmpty ? ' (CCI: $bcpCci)' : '';
      final holderPart = bcpHolder.isNotEmpty ? ' - $bcpHolder' : '';
      bcpBlock = '\n🏦 BCP: $bcpAccount$cciPart$holderPart';
    }

    final bbvaAccount = (pm['bbva_account_number'] as String? ?? '').trim();
    final bbvaHolder = (pm['bbva_account_holder'] as String? ?? '').trim();
    final bbvaCci = (pm['bbva_cci'] as String? ?? '').trim();

    String bbvaBlock = '';
    if (bbvaAccount.isNotEmpty) {
      final cciPart = bbvaCci.isNotEmpty ? ' (CCI: $bbvaCci)' : '';
      final holderPart = bbvaHolder.isNotEmpty ? ' - $bbvaHolder' : '';
      bbvaBlock = '\n🏦 BBVA: $bbvaAccount$cciPart$holderPart';
    }

    // 2. Diccionario consolidado de variables
    final Map<String, String> vars = {
      '{autor}': li['author_full_name'] as String? ?? 'Julio Angello Vasquez Navarro',
      '{yape_phone}': pm['yape_plin_phone'] as String? ?? '922836879',
      '{yape_titular}': pm['yape_plin_holder'] as String? ?? 'Julio Angello Vasquez Navarro',
      '{bloque_banco_bcp}': bcpBlock,
      '{bloque_banco_bbva}': bbvaBlock,
      '{commercial_name}': li['commercial_name'] as String? ?? 'MochilaLista',
      '{support_phone}': li['support_phone'] as String? ?? '+51 922 836 879',
    };

    // Añadir contexto específico provisto en la invocación
    context.forEach((key, val) {
      final cleanKey = key.startsWith('{') && key.endsWith('}') ? key : '{$key}';
      vars[cleanKey] = val?.toString() ?? '';
    });
    if (vars.containsKey('{codigo}') && !vars.containsKey('{codigo_licencia}')) {
      vars['{codigo_licencia}'] = vars['{codigo}']!;
    } else if (vars.containsKey('{codigo_licencia}') && !vars.containsKey('{codigo}')) {
      vars['{codigo}'] = vars['{codigo_licencia}']!;
    }
    if (vars.containsKey('{commercial_name}') && !vars.containsKey('{brand_name}')) {
      vars['{brand_name}'] = vars['{commercial_name}']!;
    }

    // 3. Sustitución secuencial
    String result = template;
    vars.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    return result;
  }

  /// Crea un snapshot de respaldo en disco dentro de `backups/`
  Future<File> _createBackupSnapshot(String reason) async {
    if (!await backupsDirectory.exists()) {
      await backupsDirectory.create(recursive: true);
    }
    final now = PeruTimeHelper.toLimaDateTime(DateTime.now());
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    final us = now.microsecond.toString().padLeft(3, '0');
    final filename = 'owner_config_backup_${y}${m}${d}_${h}${min}${s}_${ms}${us}_$reason.json';

    final backupFile = File('${backupsDirectory.path}/$filename');
    final dataToSave = _config.isNotEmpty ? _config : getDefaultConfig();
    await backupFile.writeAsString(const JsonEncoder.withIndent('  ').convert(dataToSave));
    await _cleanOldSnapshots();
    return backupFile;
  }

  /// Limpia los respaldos automáticos antiguos de configuración, conservando los últimos [maxAutoSnapshots] (default: 30).
  /// Excluye explícitamente cualquier respaldo manual, de bóveda o de pre-restauración/importación.
  Future<void> _cleanOldSnapshots({int? maxAutoSnapshots}) async {
    final limit = maxAutoSnapshots ?? this.maxAutoSnapshots;
    if (!await backupsDirectory.exists()) return;

    final List<File> autoSnapshots = [];
    final entities = await backupsDirectory.list().toList();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = entity.uri.pathSegments.last;
        final lower = filename.toLowerCase();

        // Prefijo oficial de snapshot automático de configuración
        if (!filename.startsWith('owner_config_backup_')) continue;

        // Excluir respaldos protegidos (manuales, bóveda, pre_restore, before_restore, pre_import, pre_reset)
        final isProtected = lower.contains('manual') ||
            lower.contains('vault') ||
            lower.contains('pre_restore') ||
            lower.contains('before_restore') ||
            lower.contains('pre_import') ||
            lower.contains('pre_reset');
        if (isProtected) continue;

        autoSnapshots.add(entity);
      }
    }

    if (autoSnapshots.length <= limit) return;

    final fileStats = <String, FileStat>{};
    for (final file in autoSnapshots) {
      fileStats[file.path] = await file.stat();
    }

    autoSnapshots.sort((a, b) {
      final statA = fileStats[a.path]!;
      final statB = fileStats[b.path]!;
      final cmp = statB.modified.compareTo(statA.modified);
      if (cmp != 0) return cmp;
      return b.path.compareTo(a.path);
    });

    final toDelete = autoSnapshots.sublist(limit);
    for (final file in toDelete) {
      try {
        await file.delete();
      } catch (e) {
        stderr.writeln('Warning: Error eliminando snapshot de configuración antiguo ${file.path}: $e');
      }
    }
  }

  /// Método público para forzar o parametrizar la limpieza de snapshots de configuración
  Future<void> cleanOldSnapshots({int? maxAutoSnapshots}) =>
      _cleanOldSnapshots(maxAutoSnapshots: maxAutoSnapshots);

  /// Escribe el archivo físico `owner_config.json` con formato legible
  Future<void> _persistConfig() async {
    await configFile.writeAsString(const JsonEncoder.withIndent('  ').convert(_config));
  }

  /// Normaliza en memoria configuraciones históricas leídas desde disco sin sobrescribir datos del usuario.
  void _normalizeLoadedConfig(
    Map<String, dynamic> merged,
    Map<String, dynamic> rawParsed,
  ) {
    _normalizeCatalogEntries(
      merged,
      rawCatalog: rawParsed['catalog'] is Map ? rawParsed['catalog'] as Map : null,
    );
    _normalizeTemplatesMap(merged, rawParsed['templates'] as Map?);
    _normalizeSystemPreferences(merged);
  }

  /// Propaga cambios de `legal_identity` hacia `receipt_config` cuando los campos de boleta
  /// aún reflejaban la identidad anterior o venían vacíos.
  void _propagateLegalIdentityToReceiptConfig(
    Map<String, dynamic> target, {
    required Map<String, dynamic> prevLegal,
  }) {
    final newLegal =
        (target['legal_identity'] as Map?)?.cast<String, dynamic>() ?? {};
    final rcRaw = target['receipt_config'];
    if (rcRaw is! Map) return;
    final rc = Map<String, dynamic>.from(rcRaw);

    final prevAuthor = (prevLegal['author_full_name'] as String? ?? '').trim();
    final newAuthor = (newLegal['author_full_name'] as String? ?? '').trim();
    final curIssuer = (rc['issuer_name'] as String? ?? '').trim();
    if (newAuthor.isNotEmpty &&
        (curIssuer.isEmpty || curIssuer == prevAuthor)) {
      rc['issuer_name'] = newAuthor;
    }

    final prevBrand = (prevLegal['commercial_name'] as String? ??
            prevLegal['brand_name'] as String? ??
            '')
        .trim();
    final newBrand = (newLegal['commercial_name'] as String? ??
            newLegal['brand_name'] as String? ??
            '')
        .trim();
    final curComm = (rc['commercial_name'] as String? ?? '').trim();
    if (newBrand.isNotEmpty && (curComm.isEmpty || curComm == prevBrand)) {
      rc['commercial_name'] = newBrand;
    }

    final curSig = (rc['signature_text'] as String? ?? '').trim();
    if (newBrand.isNotEmpty &&
        (curSig.isEmpty || curSig == 'Administración Comercial — $prevBrand')) {
      rc['signature_text'] = 'Administración Comercial — $newBrand';
    }

    final prevPhone = (prevLegal['support_phone'] as String? ?? '').trim();
    final newPhone = (newLegal['support_phone'] as String? ?? '').trim();
    final curPhone = (rc['issuer_phone'] as String? ?? '').trim();
    if (newPhone.isNotEmpty && (curPhone.isEmpty || curPhone == prevPhone)) {
      rc['issuer_phone'] = newPhone;
    }

    target['receipt_config'] = rc;
  }

  void _normalizeCatalogEntries(
    Map<String, dynamic> target, {
    Map? rawCatalog,
  }) {
    final defaultsCatalog =
        (getDefaultConfig()['catalog'] as Map).cast<String, dynamic>();
    final rawTargetCat = target['catalog'];
    final catalogMap = rawTargetCat is Map
        ? Map<String, dynamic>.from(rawTargetCat)
        : <String, dynamic>{};

    catalogMap.forEach((k, v) {
      if (v is Map) {
        final vMap = Map<String, dynamic>.from(v);
        final rawEntry = rawCatalog != null && rawCatalog[k] is Map
            ? rawCatalog[k] as Map
            : null;
        final defEntry = defaultsCatalog[k] is Map
            ? defaultsCatalog[k] as Map
            : null;

        if (vMap.containsKey('price')) {
          final p = (vMap['price'] as num?)?.toDouble() ?? 0.0;
          vMap['price'] = p < 0 ? 0.0 : p;
        }
        if (vMap.containsKey('days')) {
          final d = (vMap['days'] as num?)?.toInt() ?? 0;
          vMap['days'] = d < 0 ? 0 : d;
        }
        if (vMap.containsKey('ai_credits')) {
          final c = (vMap['ai_credits'] as num?)?.toInt() ?? 0;
          vMap['ai_credits'] = c < 0 ? 0 : c;
        }

        // Unificación bidireccional updates_window_months <-> updates_months
        int? resolvedUpdates;
        if (rawEntry != null && rawEntry.containsKey('updates_window_months')) {
          resolvedUpdates =
              (rawEntry['updates_window_months'] as num?)?.toInt() ?? 0;
        } else if (rawEntry != null && rawEntry.containsKey('updates_months')) {
          resolvedUpdates = (rawEntry['updates_months'] as num?)?.toInt() ?? 0;
        } else if (vMap.containsKey('updates_window_months')) {
          resolvedUpdates =
              (vMap['updates_window_months'] as num?)?.toInt() ?? 0;
        } else if (vMap.containsKey('updates_months')) {
          resolvedUpdates = (vMap['updates_months'] as num?)?.toInt() ?? 0;
        } else if (defEntry != null) {
          resolvedUpdates =
              (defEntry['updates_window_months'] as num?)?.toInt() ??
                  (defEntry['updates_months'] as num?)?.toInt() ??
                  0;
        }
        final safeUpdates = (resolvedUpdates ?? 0) < 0 ? 0 : (resolvedUpdates ?? 0);
        vMap['updates_window_months'] = safeUpdates;
        vMap['updates_months'] = safeUpdates;

        // Descripción comercial predeterminada si falta o quedó vacía
        final curDesc = (vMap['description'] as String? ?? '').trim();
        if (curDesc.isNotEmpty) {
          vMap['description'] = curDesc;
        } else if (defEntry != null && defEntry['description'] is String) {
          vMap['description'] = defEntry['description'];
        } else {
          vMap['description'] = '';
        }

        catalogMap[k] = vMap;
      }
    });
    target['catalog'] = catalogMap;
  }

  void _normalizeTemplatesMap(
    Map<String, dynamic> target,
    Map? rawTemplates,
  ) {
    final rawTargetTpl = target['templates'];
    final tplMap = rawTargetTpl is Map
        ? Map<String, dynamic>.from(rawTargetTpl)
        : <String, dynamic>{};

    const aliasToCanon = {
      'welcome': 'trial_welcome',
      'expiring': 'expiring_reminder',
      'license': 'license_issued',
      'update': 'apk_update_eligible',
    };

    aliasToCanon.forEach((alias, canon) {
      final hasRawAlias =
          rawTemplates != null && rawTemplates.containsKey(alias);
      final hasRawCanon =
          rawTemplates != null && rawTemplates.containsKey(canon);
      final rawAliasVal = hasRawAlias ? rawTemplates[alias]?.toString() : null;
      final rawCanonVal = hasRawCanon ? rawTemplates[canon]?.toString() : null;

      if (hasRawAlias && (rawAliasVal?.trim().isNotEmpty ?? false)) {
        // Conservar el alias explícito por retrocompatibilidad y sincronizar la clave canónica
        tplMap[alias] = rawAliasVal;
        if (!hasRawCanon || (rawCanonVal?.trim().isEmpty ?? true)) {
          tplMap[canon] = rawAliasVal;
        }
      } else if (hasRawCanon &&
          (rawCanonVal?.trim().isNotEmpty ?? false) &&
          tplMap.containsKey(alias)) {
        tplMap[alias] = rawCanonVal;
      } else if (tplMap.containsKey(alias)) {
        final curCanon = tplMap[canon]?.toString() ?? '';
        final curAlias = tplMap[alias]?.toString() ?? '';
        if (curAlias.isNotEmpty && curCanon.isEmpty) {
          tplMap[canon] = curAlias;
        } else if (curCanon.isNotEmpty && curAlias != curCanon) {
          tplMap[alias] = curCanon;
        }
      }
    });

    target['templates'] = tplMap;
  }

  void _normalizeSystemPreferences(Map<String, dynamic> target) {
    final sys = target['system'] is Map
        ? Map<String, dynamic>.from(target['system'] as Map)
        : <String, dynamic>{};

    final rawMode = (sys['default_mode'] as String? ?? 'sandbox').trim().toLowerCase();
    sys['default_mode'] = rawMode == 'prod' ? 'prod' : 'sandbox';

    final rawTheme = (sys['theme'] as String? ?? 'dark').trim().toLowerCase();
    sys['theme'] = rawTheme == 'light' ? 'light' : 'dark';

    final rawDensity =
        (sys['table_density'] as String? ?? 'comfortable').trim().toLowerCase();
    sys['table_density'] = rawDensity == 'compact' ? 'compact' : 'comfortable';

    final rawRev = (sys['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    sys['commercial_sync_revision'] = rawRev < 0 ? 0 : rawRev;

    target['system'] = sys;
  }

  /// Sanitiza y valida la configuración entrante preservando `apk_library_dir` y `apk_search_dirs`
  Map<String, dynamic> _sanitizeConfig(Map<String, dynamic> raw) {
    final prevLegal = Map<String, dynamic>.from(legalIdentity);
    final prevSystem = Map<String, dynamic>.from(system);
    final prevRev =
        (prevSystem['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    final merged = _deepMerge(getDefaultConfig(), raw);

    // Sincronizar ruta de biblioteca si vino en raíz por retrocompatibilidad
    final rawSystem = raw['system'];
    final hasRawSystemLib = rawSystem is Map &&
        rawSystem.containsKey('apk_library_dir') &&
        (rawSystem['apk_library_dir']?.toString().trim().isNotEmpty ?? false);
    final hasRawSearchDirs = rawSystem is Map &&
        rawSystem.containsKey('apk_search_dirs') &&
        rawSystem['apk_search_dirs'] is List &&
        (rawSystem['apk_search_dirs'] as List).isNotEmpty;

    final sysMap = merged['system'] is Map
        ? Map<String, dynamic>.from(merged['system'] as Map)
        : <String, dynamic>{};

    // Guardián anti-downgrade de commercial_sync_revision
    final incomingRev =
        (sysMap['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    final safePrevRev = prevRev < 0 ? 0 : prevRev;
    final safeIncomingRev = incomingRev < 0 ? 0 : incomingRev;
    sysMap['commercial_sync_revision'] =
        safePrevRev > safeIncomingRev ? safePrevRev : safeIncomingRev;

    if (!hasRawSystemLib &&
        raw['apk_library_dir'] is String &&
        (raw['apk_library_dir'] as String).trim().isNotEmpty) {
      sysMap['apk_library_dir'] = (raw['apk_library_dir'] as String).trim();
      merged.remove('apk_library_dir');
    } else if (!hasRawSystemLib &&
        prevSystem['apk_library_dir'] is String &&
        (prevSystem['apk_library_dir'] as String).trim().isNotEmpty) {
      sysMap['apk_library_dir'] = (prevSystem['apk_library_dir'] as String).trim();
    }

    if (!hasRawSearchDirs &&
        prevSystem['apk_search_dirs'] is List &&
        (prevSystem['apk_search_dirs'] as List).isNotEmpty) {
      sysMap['apk_search_dirs'] =
          jsonDecode(jsonEncode(prevSystem['apk_search_dirs']));
    }

    // Si se actualizó apk_library_dir sin enviar apk_search_dirs explícitos,
    // sincronizar la entrada official_library en lugar de arrastrar rutas previas
    if (!hasRawSearchDirs && sysMap['apk_search_dirs'] is List) {
      final newLib = (sysMap['apk_library_dir'] as String? ?? '').trim();
      final updatedList = <Map<String, dynamic>>[];
      for (final item in (sysMap['apk_search_dirs'] as List)) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          if (m['kind'] == 'official_library' && newLib.isNotEmpty) {
            m['path'] = newLib;
          }
          updatedList.add(m);
        }
      }
      sysMap['apk_search_dirs'] = updatedList;
    }

    if (sysMap['apk_search_dirs'] is List) {
      final rawList = sysMap['apk_search_dirs'] as List;
      final cleanDirs = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final item in rawList) {
        ApkSearchDirConfig? cfg;
        if (item is Map) {
          cfg = ApkSearchDirConfig.fromJson(Map<String, dynamic>.from(item));
        } else if (item is String && item.trim().isNotEmpty) {
          cfg = ApkSearchDirConfig(path: item.trim(), label: 'Carpeta Personalizada');
        }
        if (cfg == null || cfg.path.isEmpty || isForbiddenApkSearchDir(cfg.path)) {
          continue;
        }
        final canon = ApkInspectorService.canonicalizePath(cfg.path);
        final key = Platform.isWindows ? canon.toLowerCase() : canon;
        if (seen.add(key)) {
          cleanDirs.add(cfg.toJson());
          if (cfg.kind == 'official_library' && !hasRawSystemLib) {
            sysMap['apk_library_dir'] = cfg.path;
          }
        }
      }
      sysMap['apk_search_dirs'] = cleanDirs;
    }

    merged['system'] = sysMap;
    _normalizeSystemPreferences(merged);

    // Sanitizar catálogo (incluyendo updates_window_months / updates_months y descripciones)
    _normalizeCatalogEntries(
      merged,
      rawCatalog: raw['catalog'] is Map ? raw['catalog'] as Map : null,
    );

    // Sincronizar migration_fee en raíz si existe catálogo
    final rawCat = merged['catalog'] as Map<String, dynamic>;
    if (rawCat['HARDWARE_MIGRATION_FEE'] is Map) {
      merged['migration_fee'] =
          (rawCat['HARDWARE_MIGRATION_FEE']['price'] as num?)?.toDouble() ??
              40.0;
    }

    // Normalizar claves de plantillas WhatsApp
    _normalizeTemplatesMap(
      merged,
      raw['templates'] is Map ? raw['templates'] as Map : null,
    );

    // Propagar cambios de identidad legal hacia receipt_config cuando no fueron personalizados aparte
    if (_config.isNotEmpty) {
      _propagateLegalIdentityToReceiptConfig(merged, prevLegal: prevLegal);
    }

    // Sanitizar receipt_config
    if (merged.containsKey('receipt_config') && merged['receipt_config'] is Map) {
      final rc = Map<String, dynamic>.from(merged['receipt_config'] as Map);
      if (rc.containsKey('next_correlative')) {
        final nc = (rc['next_correlative'] as num?)?.toInt() ?? 1;
        rc['next_correlative'] = nc < 1 ? 1 : nc;
      }
      if (rc.containsKey('sandbox_next_correlative')) {
        final snc = (rc['sandbox_next_correlative'] as num?)?.toInt() ?? 1;
        rc['sandbox_next_correlative'] = snc < 1 ? 1 : snc;
      }
      if (rc.containsKey('next_invoice_correlative')) {
        final nic = (rc['next_invoice_correlative'] as num?)?.toInt() ?? 1;
        rc['next_invoice_correlative'] = nic < 1 ? 1 : nic;
      }
      if (rc.containsKey('sandbox_next_invoice_correlative')) {
        final snic = (rc['sandbox_next_invoice_correlative'] as num?)?.toInt() ?? 1;
        rc['sandbox_next_invoice_correlative'] = snic < 1 ? 1 : snic;
      }
      merged['receipt_config'] = rc;
    }

    return merged;
  }

  /// Helper de fusión profunda recursiva (preserva subclaves por defecto si faltan en el input)
  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> overrides,
  ) {
    final result = <String, dynamic>{};
    base.forEach((key, value) {
      if (value is Map) {
        result[key] = _deepMerge(Map<String, dynamic>.from(value), {});
      } else {
        result[key] = value;
      }
    });
    overrides.forEach((key, value) {
      if (value is Map && result[key] is Map) {
        result[key] = _deepMerge(
          Map<String, dynamic>.from(result[key] as Map),
          Map<String, dynamic>.from(value),
        );
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
