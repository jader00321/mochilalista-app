import 'dart:convert';
import 'dart:io';

/// Servicio de Configuración Desacoplada del Propietario (Plan 09 - Pilar 3)
/// Administra `data/owner_config.json`, plantillas oficiales de WhatsApp,
/// tarifario de licencias, cuentas de pago y generación de respaldos automáticos.
class ConfigService {
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
    final configured = system['apk_library_dir'] as String?;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return Platform.isWindows
        ? r'C:\Users\vjuli\Documents\v-app-offline apks'
        : 'releases_apks';
  }

  /// Tarifa técnica oficial de migración de hardware
  double get migrationFee =>
      (catalog['HARDWARE_MIGRATION_FEE']?['price'] as num?)?.toDouble() ?? 40.0;

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

  /// Retorna la configuración oficial de fábrica completa
  static Map<String, dynamic> getDefaultConfig() {
    return {
      'system': {
        'default_mode': 'sandbox',
        'theme': 'dark',
        'table_density': 'comfortable',
        'version': '1.0.0',
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
          'label': 'Prueba Gratuita',
        },
        'MENSUAL': {
          'price': 35.0,
          'days': 30,
          'ai_credits': 50,
          'label': 'Plan Mensual',
        },
        'TRIMESTRAL': {
          'price': 90.0,
          'days': 90,
          'ai_credits': 180,
          'label': 'Plan Trimestral',
        },
        'SEMESTRAL': {
          'price': 160.0,
          'days': 180,
          'ai_credits': 450,
          'label': 'Plan Semestral',
        },
        'ANUAL': {
          'price': 280.0,
          'days': 365,
          'ai_credits': 1200,
          'label': 'Plan Anual',
        },
        'PERPETUO_LIBERADO': {
          'price': 850.0,
          'days': 99999,
          'ai_credits': 200,
          'updates_months': 12,
          'label': 'Perpetuo Liberado',
        },
        'PASE_ACTUALIZACION_ANUAL': {
          'price': 150.0,
          'days': 0,
          'updates_months': 12,
          'ai_credits': 100,
          'label': 'Pase Anual de Updates',
        },
        'RECARGA_IA_150': {
          'price': 20.0,
          'days': 0,
          'ai_credits': 150,
          'label': 'Recarga Extra IA (+150)',
        },
        'EXTENSION_CORTESIA': {
          'price': 0.0,
          'days': 7,
          'ai_credits': 0,
          'label': 'Extensión de Cortesía',
        },
        'HARDWARE_MIGRATION_FEE': {
          'price': 40.0,
          'label': 'Tarifa Técnica de Migración',
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

  /// Recarga en memoria la configuración desde el archivo en disco
  Future<void> reloadFromDisk() async {
    await init();
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
  /// creando un snapshot de respaldo del estado previo.
  Future<Map<String, dynamic>> resetToDefaults() async {
    await _createBackupSnapshot('pre_reset');
    _config = getDefaultConfig();
    await _persistConfig();

    if (onConfigChanged != null) {
      try {
        await onConfigChanged!();
      } catch (e) {
        stderr.writeln('Warning: Error al ejecutar onConfigChanged tras resetToDefaults: $e');
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
    final now = DateTime.now();
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

        // Excluir respaldos protegidos (manuales, bóveda, pre_restore, pre_import)
        final isProtected = lower.contains('manual') ||
            lower.contains('vault') ||
            lower.contains('pre_restore') ||
            lower.contains('pre_import');
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

  /// Sanitiza y valida la configuración entrante
  Map<String, dynamic> _sanitizeConfig(Map<String, dynamic> raw) {
    final merged = _deepMerge(getDefaultConfig(), raw);

    // Sanitizar catálogo
    final rawCatalog = merged['catalog'];
    final catalogMap = rawCatalog is Map ? Map<String, dynamic>.from(rawCatalog) : <String, dynamic>{};
    catalogMap.forEach((k, v) {
      if (v is Map) {
        final vMap = Map<String, dynamic>.from(v);
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
        catalogMap[k] = vMap;
      }
    });
    merged['catalog'] = catalogMap;

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
