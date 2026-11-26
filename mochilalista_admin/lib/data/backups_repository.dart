part of 'database_service.dart';

/// Repositorio de gestión de respaldos en disco (`list`, `createManual`, `preview`, `restore`, `purgeSandbox`).
mixin _BackupsRepositoryMixin on _DatabaseServiceBase {
  static String _detectBackupMode(String filename) {
    final isProd = filename.startsWith('prod_') || filename.contains('_prod_');
    final isSandbox =
        filename.startsWith('sandbox_') || filename.contains('_sandbox_');
    return isProd ? 'prod' : (isSandbox ? 'sandbox' : 'global');
  }

  static String _detectBackupScope(String filename, {dynamic decoded}) {
    final lower = filename.toLowerCase();
    if (lower.startsWith('owner_config') || lower.contains('config')) {
      return 'config';
    }
    if (lower.contains('releases')) return 'releases';
    if (lower.contains('clients')) return 'clients';

    if (decoded is Map<String, dynamic> &&
        (decoded.containsKey('catalog') ||
            decoded.containsKey('templates') ||
            decoded.containsKey('system'))) {
      return 'config';
    }
    if (decoded is List &&
        decoded.isNotEmpty &&
        decoded.first is Map &&
        (decoded.first as Map).containsKey('version_name')) {
      return 'releases';
    }
    if (decoded is List) {
      return 'clients';
    }
    return 'unknown';
  }

  /// Lista los respaldos físicos en disco duro (`backups/`) con hora Lima GMT-5 y metadatos.
  Future<List<Map<String, dynamic>>> listBackups() async {
    final dir = Directory(backupDir);
    if (!await dir.exists()) return [];

    final List<Map<String, dynamic>> result = [];
    final entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.last;
        final mode = _detectBackupMode(name);
        final scope = _detectBackupScope(name);
        final lower = name.toLowerCase();
        final isManual = lower.contains('manual');
        final isProtected = DatabaseService.isProtectedBackupFilename(name);

        result.add({
          'filename': name,
          'path': entity.path,
          'size_kb': (stat.size / 1024).toStringAsFixed(1),
          'size_bytes': stat.size,
          'modified_at': stat.modified.toUtc().toIso8601String(),
          'modified_lima': PeruTimeHelper.formatLimaDateTime(stat.modified),
          'mode': mode,
          'target_scope': scope,
          'is_manual': isManual,
          'is_protected': isProtected,
        });
      }
    }
    result.sort((a, b) {
      final cmp =
          (b['modified_at'] as String).compareTo(a['modified_at'] as String);
      if (cmp != 0) return cmp;
      return (b['filename'] as String).compareTo(a['filename'] as String);
    });
    return result;
  }

  /// Crea un snapshot manual inmediato en disco.
  Future<Map<String, dynamic>> createManualBackup() async {
    final now = DateTime.now();
    final timestamp = PeruTimeHelper.formatLimaFilenameTimestamp(now);
    final filenameClients = '${_mode}_clients_manual_$timestamp.json';
    final filenameReleases = '${_mode}_releases_manual_$timestamp.json';

    final destClients = File('$backupDir/$filenameClients');
    final destReleases = File('$backupDir/$filenameReleases');

    if (await _clientsFile.exists()) {
      await _clientsFile.copy(destClients.path);
    }
    if (await _releasesFile.exists()) {
      await _releasesFile.copy(destReleases.path);
    }

    return {
      'ok': true,
      'timestamp': now.toUtc().toIso8601String(),
      'timestamp_lima': PeruTimeHelper.formatLimaDateTime(now),
      'mode': _mode,
      'files': [filenameClients, filenameReleases],
      'message': 'Snapshot manual creado en disco exitosamente.',
    };
  }

  /// Inspecciona un snapshot antes de restaurar comparándolo contra el estado actual en disco.
  Future<Map<String, dynamic>?> previewBackup(
    String filename, {
    ConfigService? configService,
  }) async {
    if (!DatabaseService.isSafeBackupFilename(filename)) {
      throw ArgumentError('Nombre de archivo de respaldo inválido.');
    }

    final file = File('$backupDir/$filename');
    if (!await file.exists()) return null;

    final stat = await file.stat();
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);

    final environment = _detectBackupMode(filename);
    final scope = _detectBackupScope(filename, decoded: decoded);
    final targetMode = (environment == 'prod' || environment == 'sandbox')
        ? environment
        : _mode;

    Map<String, dynamic> snapshotSummary = {};
    Map<String, dynamic> currentSummary = {};

    if (scope == 'config') {
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'El respaldo de configuración no contiene un objeto JSON válido.');
      }
      final snapCatalog = (decoded['catalog'] as Map?) ?? {};
      final snapTemplates = (decoded['templates'] as Map?) ?? {};
      final snapSystem = (decoded['system'] as Map?) ?? {};
      snapshotSummary = {
        'catalog_plans_count': snapCatalog.length,
        'templates_count': snapTemplates.length,
        'default_mode': snapSystem['default_mode'] ?? 'sandbox',
        'theme': snapSystem['theme'] ?? 'dark',
        'table_density': snapSystem['table_density'] ?? 'comfortable',
      };

      final cfg = configService ??
          ConfigService(
            dataDirectory: Directory(dataDir),
            backupsDirectory: Directory(backupDir),
          );
      if (cfg.config.isEmpty) {
        await cfg.init();
      }
      currentSummary = {
        'catalog_plans_count': cfg.catalog.length,
        'templates_count': cfg.templates.length,
        'default_mode': cfg.system['default_mode'] ?? 'sandbox',
        'theme': cfg.system['theme'] ?? 'dark',
        'table_density': cfg.system['table_density'] ?? 'comfortable',
      };
    } else if (scope == 'releases') {
      if (decoded is! List) {
        throw const FormatException(
            'El respaldo de lanzamientos no contiene una lista JSON válida.');
      }
      final snapReleases = decoded.cast<Map<String, dynamic>>();
      snapshotSummary = {
        'releases_count': snapReleases.length,
        'latest_version': snapReleases.isNotEmpty
            ? (snapReleases.first['version_name'] ?? '-')
            : '-',
      };

      final curReleasesFile = File('$dataDir/${targetMode}_releases_db.json');
      List<Map<String, dynamic>> curReleases = [];
      if (await curReleasesFile.exists()) {
        curReleases = (jsonDecode(await curReleasesFile.readAsString()) as List)
            .cast<Map<String, dynamic>>();
      }
      currentSummary = {
        'releases_count': curReleases.length,
        'latest_version': curReleases.isNotEmpty
            ? (curReleases.first['version_name'] ?? '-')
            : '-',
      };
    } else {
      if (decoded is! List) {
        throw const FormatException(
            'El respaldo de clientes no contiene una lista JSON válida.');
      }
      final snapClients = decoded.cast<Map<String, dynamic>>();
      snapshotSummary = _summarizeClientsSnapshot(snapClients);

      final curClientsFile = File('$dataDir/${targetMode}_clients_db.json');
      List<Map<String, dynamic>> curClients = [];
      if (await curClientsFile.exists()) {
        curClients = (jsonDecode(await curClientsFile.readAsString()) as List)
            .cast<Map<String, dynamic>>();
      }
      currentSummary = _summarizeClientsSnapshot(curClients);
    }

    return {
      'ok': true,
      'filename': filename,
      'environment': environment,
      'target_mode': environment == 'global' ? 'global' : targetMode,
      'target_scope': scope,
      'is_protected': DatabaseService.isProtectedBackupFilename(filename),
      'size_bytes': stat.size,
      'size_kb': (stat.size / 1024).toStringAsFixed(1),
      'modified_at': stat.modified.toUtc().toIso8601String(),
      'modified_lima': PeruTimeHelper.formatLimaDateTime(stat.modified),
      'snapshot_summary': snapshotSummary,
      'current_summary': currentSummary,
    };
  }

  static Map<String, dynamic> _summarizeClientsSnapshot(
    List<Map<String, dynamic>> clients,
  ) {
    int paymentsCount = 0;
    double totalRevenue = 0.0;
    int perpetualCount = 0;

    for (final c in clients) {
      final status = (c['license_status'] as String? ?? '').toUpperCase();
      final plan = (c['license_type'] as String? ?? '').toUpperCase();
      if (status == 'PERPETUA' || plan.contains('PERPETU')) {
        perpetualCount++;
      }
      final payments = (c['payment_history'] as List? ?? []);
      paymentsCount += payments.length;
      for (final p in payments) {
        if (p is Map) {
          totalRevenue += (p['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    return {
      'clients_count': clients.length,
      'payments_count': paymentsCount,
      'total_revenue_pen': double.parse(totalRevenue.toStringAsFixed(2)),
      'perpetual_count': perpetualCount,
    };
  }

  /// Restaura de forma segura clientes, releases o `owner_config_backup_*.json`.
  Future<Map<String, dynamic>> restoreFromBackupWithDetails(
    String filename, {
    ConfigService? configService,
  }) async {
    if (!DatabaseService.isSafeBackupFilename(filename)) {
      throw ArgumentError('Nombre de archivo de respaldo inválido.');
    }

    final file = File('$backupDir/$filename');
    if (!await file.exists()) {
      return {
        'ok': false,
        'error': 'Archivo de respaldo no encontrado en backups/.',
      };
    }

    final rawContent = await file.readAsString();
    final dynamic decoded = jsonDecode(rawContent);

    final environment = _detectBackupMode(filename);
    final scope = _detectBackupScope(filename, decoded: decoded);
    final baseName = filename.replaceAll('.json', '');

    if (scope == 'config') {
      if (decoded is! Map<String, dynamic> ||
          (!decoded.containsKey('catalog') &&
              !decoded.containsKey('templates') &&
              !decoded.containsKey('system'))) {
        throw const FormatException(
            'El respaldo de configuración no tiene la estructura esperada.');
      }

      final cfg = configService ??
          ConfigService(
            dataDirectory: Directory(dataDir),
            backupsDirectory: Directory(backupDir),
          );
      if (cfg.config.isEmpty) {
        await cfg.init();
      }

      final ts = PeruTimeHelper.formatLimaFilenameTimestamp()
          .replaceAll('-', '')
          .replaceAll('T', '_');
      final preRestoreFile =
          File('$backupDir/owner_config_backup_${ts}_pre_restore.json');
      if (await cfg.configFile.exists()) {
        await cfg.configFile.copy(preRestoreFile.path);
      } else {
        await preRestoreFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(cfg.config),
        );
      }

      await cfg.configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(decoded),
      );
      await cfg.reload(notify: true);

      return {
        'ok': true,
        'restored_scope': 'config',
        'restored_mode': 'global',
        'filename': filename,
        'pre_restore_snapshot': preRestoreFile.uri.pathSegments.last,
        'message':
            'Configuración GLOBAL restaurada y recargada en caliente exitosamente.',
      };
    }

    if (decoded is! List) {
      throw const FormatException(
          'El archivo de respaldo no contiene una lista JSON válida.');
    }

    final targetMode = (environment == 'prod' || environment == 'sandbox')
        ? environment
        : _mode;

    await _createSnapshot(
      'pre_restore_$baseName',
      targetMode: targetMode,
    );

    if (scope == 'clients' || scope == 'releases') {
      final destFile = File('$dataDir/${targetMode}_${scope}_db.json');
      await file.copy(destFile.path);
      await reloadFromDisk();
      if (targetMode == 'prod' && onProductionDataChanged != null) {
        try {
          await onProductionDataChanged!();
        } catch (e) {
          stderr.writeln(
              'Warning: Error al ejecutar onProductionDataChanged tras restore $scope: $e');
        }
      }
      final label = scope == 'clients'
          ? 'Cartera de clientes'
          : 'Catálogo de versiones';
      return {
        'ok': true,
        'restored_scope': scope,
        'restored_mode': targetMode,
        'active_mode': _mode,
        'filename': filename,
        'message': '$label ($targetMode) restaurada y recargada exitosamente.',
      };
    }

    return {
      'ok': false,
      'error': 'Tipo de archivo de respaldo no reconocido.',
    };
  }

  /// Alias compatible booleano de restauración segura de respaldos.
  Future<bool> restoreFromBackup(
    String filename, {
    ConfigService? configService,
  }) async {
    final res = await restoreFromBackupWithDetails(
      filename,
      configService: configService,
    );
    return res['ok'] == true;
  }

  /// Purga de snapshots automáticos antiguos del entorno SANDBOX conservando los últimos [keepRecent].
  Future<Map<String, dynamic>> purgeSandboxBackups(
      {int keepRecent = 10}) async {
    final keep = keepRecent < 0 ? 0 : keepRecent;
    final dir = Directory(backupDir);
    if (!await dir.exists()) {
      return {
        'ok': true,
        'deleted_count': 0,
        'preserved_count': 0,
        'protected_count': 0,
        'freed_bytes': 0,
      };
    }

    final entities = await dir.list().toList();
    final List<File> candidateSandbox = [];
    int protectedCount = 0;

    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('sandbox_') ||
          DatabaseService.isProtectedBackupFilename(name)) {
        protectedCount++;
        continue;
      }
      candidateSandbox.add(entity);
    }

    final stats = <String, FileStat>{};
    for (final f in candidateSandbox) {
      stats[f.path] = await f.stat();
    }

    candidateSandbox.sort((a, b) {
      final cmp = stats[b.path]!.modified.compareTo(stats[a.path]!.modified);
      if (cmp != 0) return cmp;
      return b.path.compareTo(a.path);
    });

    final preserved = candidateSandbox.take(keep).toList();
    final toDelete = candidateSandbox.length > keep
        ? candidateSandbox.sublist(keep)
        : <File>[];

    int deletedCount = 0;
    int freedBytes = 0;
    for (final f in toDelete) {
      try {
        final sz = stats[f.path]?.size ?? 0;
        await f.delete();
        deletedCount++;
        freedBytes += sz;
      } catch (e) {
        stderr.writeln(
            'Warning: No se pudo purgar snapshot sandbox ${f.path}: $e');
      }
    }

    return {
      'ok': true,
      'deleted_count': deletedCount,
      'preserved_count': preserved.length,
      'protected_count': protectedCount,
      'freed_bytes': freedBytes,
    };
  }
}
