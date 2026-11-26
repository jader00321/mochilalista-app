import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../apk_inspector_service.dart';
import '../../config_service.dart';
import '../http_context.dart';
import '../windows_shell_helpers.dart';
import 'release_apk_helper.dart';

/// Sub-router para rutas de archivos locales APK, búsqueda en disco, carga/importación,
/// descarga, portapapeles (`CF_HDROP`) y apertura en Explorador (`/api/releases/*`).
class ReleasesFilesRoutes {
  ReleasesFilesRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;

    if (path == '/api/releases/search-dirs' && method == 'GET') {
      final dirs = ctx.configService.getEffectiveApkSearchDirs(
        defaultBuildOutputDir: ctx.inspector.defaultBuildOutputDir?.path,
      );
      final stats =
          dirs.map((d) => ApkInspectorService.probeSearchDirStats(d)).toList();
      await ctx.sendJson({
        'ok': true,
        'search_dirs': stats,
        'apk_library_dir': ctx.configService.apkLibraryDir,
      });
      return true;
    }

    if (path == '/api/releases/search-dirs' && method == 'PUT') {
      final decoded = jsonDecode(await ctx.readBody());
      final List<dynamic> rawDirs;
      if (decoded is Map<String, dynamic> && decoded['search_dirs'] is List) {
        rawDirs = decoded['search_dirs'] as List<dynamic>;
      } else if (decoded is List) {
        rawDirs = decoded;
      } else {
        await ctx.sendJson(
          {'ok': false, 'error': 'Se requiere una lista "search_dirs" válida.'},
          statusCode: HttpStatus.badRequest,
        );
        return true;
      }

      try {
        final savedDirs = await ctx.configService.saveApkSearchDirs(
          rawDirs,
          defaultBuildOutputDir: ctx.inspector.defaultBuildOutputDir?.path,
        );
        final stats = savedDirs
            .map((d) => ApkInspectorService.probeSearchDirStats(d))
            .toList();
        await ctx.sendJson({
          'ok': true,
          'search_dirs': stats,
          'apk_library_dir': ctx.configService.apkLibraryDir,
        });
      } on InvalidApkSearchDirException catch (e) {
        await ctx.sendJson(
          {'ok': false, 'error': e.message},
          statusCode: HttpStatus.badRequest,
        );
      }
      return true;
    }

    if (path == '/api/releases/search-dirs/reset' && method == 'POST') {
      final restoredDirs = await ctx.configService.resetApkSearchDirsToDefaults(
        defaultBuildOutputDir: ctx.inspector.defaultBuildOutputDir?.path,
      );
      final stats = restoredDirs
          .map((d) => ApkInspectorService.probeSearchDirStats(d))
          .toList();
      await ctx.sendJson({
        'ok': true,
        'search_dirs': stats,
        'apk_library_dir': ctx.configService.apkLibraryDir,
      });
      return true;
    }

    if (path == '/api/releases/browse-search-dir' && method == 'POST') {
      await _handleBrowseSearchDir(ctx);
      return true;
    }

    if (path == '/api/releases/upload-apk' && method == 'POST') {
      await _handleUploadApk(ctx);
      return true;
    }

    if (path == '/api/releases/detect-local-build' && method == 'GET') {
      await _handleDetectLocalBuild(ctx);
      return true;
    }

    if (path == '/api/releases/import-local-apk' && method == 'POST') {
      await _handleImportLocalApk(ctx);
      return true;
    }

    if (path.startsWith('/api/releases/download/') && method == 'GET') {
      await _handleDownloadApk(ctx);
      return true;
    }

    final copyFileMatch =
        RegExp(r'^/api/releases/([^/]+)/copy-file$').firstMatch(path);
    if (copyFileMatch != null && method == 'POST') {
      await _handleCopyApkFile(
        ctx,
        Uri.decodeComponent(copyFileMatch.group(1)!),
      );
      return true;
    }

    if (path == '/api/releases/reveal-file' && method == 'POST') {
      await _handleRevealApkFile(ctx);
      return true;
    }

    return false;
  }

  static Future<void> _handleBrowseSearchDir(AdminHttpContext ctx) async {
    String? initialPath;
    try {
      final bodyStr = await ctx.readBody();
      if (bodyStr.trim().isNotEmpty) {
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        initialPath = body['initial_path'] as String?;
      }
    } catch (_) {}

    final pickRes = await WindowsShellHelpers.pickFolder(
      initialPath: initialPath,
      onBrowseFolderOverride: ctx.onBrowseFolderOverride,
    );

    if (!pickRes.supported) {
      await ctx.sendJson({
        'ok': false,
        'supported': false,
        'cancelled': false,
        'error':
            'El selector nativo solo está disponible en Windows. Ingresa la ruta manualmente.',
      });
      return;
    }

    if (pickRes.failed) {
      await ctx.sendJson(
        {
          'ok': false,
          'supported': true,
          'error': pickRes.error ??
              'No se pudo abrir el selector de carpetas de Windows.',
        },
        statusCode: HttpStatus.internalServerError,
      );
      return;
    }

    final pickedPath = pickRes.path;
    if (pickedPath == null || pickedPath.trim().isEmpty) {
      await ctx.sendJson({
        'ok': true,
        'supported': true,
        'cancelled': true,
        'path': null,
      });
      return;
    }

    final cleanPicked = ApkInspectorService.canonicalizePath(pickedPath);
    if (ctx.configService.isForbiddenApkSearchDir(cleanPicked)) {
      await ctx.sendJson(
        {
          'ok': false,
          'supported': true,
          'cancelled': false,
          'path': cleanPicked,
          'error':
              'La carpeta seleccionada está restringida por seguridad o es una unidad raíz completa ($cleanPicked).',
        },
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    await ctx.sendJson({
      'ok': true,
      'supported': true,
      'cancelled': false,
      'path': cleanPicked,
    });
  }

  static Future<void> _handleUploadApk(AdminHttpContext ctx) async {
    final queryName = ctx.request.uri.queryParameters['filename'] ??
        ctx.request.headers.value('X-File-Name') ??
        'mochilalista-uploaded.apk';
    final safeFileName = queryName.replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '_');

    final targetDir = ctx.dbService.currentReleasesApkDir;
    await targetDir.create(recursive: true);
    final targetFile = File('${targetDir.path}/$safeFileName');

    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in ctx.request) {
      bytesBuilder.add(chunk);
    }
    await targetFile.writeAsBytes(bytesBuilder.takeBytes());

    final searchDirPaths = ctx.configService.getEffectiveApkSearchDirPaths(
      defaultBuildOutputDir: ctx.inspector.defaultBuildOutputDir?.path,
    );

    final inspection = await ctx.inspector.inspectApk(
      targetFile,
      apkLibraryDir: ctx.configService.apkLibraryDir,
      extraSearchDirs: searchDirPaths,
    );

    await ctx.sendJson({
      'ok': inspection.success,
      ...inspection.toJson(),
    });
  }

  static Future<void> _handleDetectLocalBuild(AdminHttpContext ctx) async {
    final limit =
        (int.tryParse(ctx.request.uri.queryParameters['limit'] ?? '') ?? 6)
            .clamp(1, 50);
    final abiFilter =
        (ctx.request.uri.queryParameters['abi'] ?? 'ALL').trim().toUpperCase();
    final query = (ctx.request.uri.queryParameters['q'] ?? '').trim();
    final maxDepth =
        (int.tryParse(ctx.request.uri.queryParameters['max_depth'] ?? '') ?? 3)
            .clamp(0, 4);

    final searchDirs = ctx.configService.getEffectiveApkSearchDirs(
      defaultBuildOutputDir: ctx.inspector.defaultBuildOutputDir?.path,
    );
    final libDir = Directory(ctx.configService.apkLibraryDir);

    final report = await ctx.inspector.detectLocalApksWithStats(
      apkLibraryDir: libDir,
      buildOutputDir: ctx.inspector.defaultBuildOutputDir,
      searchDirs: searchDirs,
      maxCandidates: limit,
      limit: limit,
      maxDepth: maxDepth,
      abiFilter: abiFilter,
      query: query,
    );

    final candidates = report.results;
    final hasApk = candidates.isNotEmpty;
    final top = hasApk ? candidates.first : null;

    await ctx.sendJson({
      'ok': true,
      'apk_found': hasApk,
      'version_name': top?.versionName ?? '9.40.0',
      'version_code': top?.versionCode ?? 84,
      'db_schema_version': top?.dbSchemaVersion ?? 36,
      'min_required_version': top?.minRequiredVersion ?? '9.0.0',
      'file_name': top?.fileName,
      'file_path': top?.filePath,
      'file_size_mb': top?.sizeMb,
      'sha256': top?.sha256,
      'signature_verified': top?.signatureVerified,
      'signature_status': top?.signatureStatus,
      'signature_detail': top?.signatureDetail,
      'signer_sha256': top?.signerSha256,
      'signer_dn': top?.signerDn,
      'suggested_changelog': top?.suggestedChangelog ?? '',
      'suggested_internal_notes': top?.suggestedInternalNotes ?? '',
      'suggested_release_type': top?.suggestedReleaseType ?? 'FEATURE_RELEASE',
      'available_builds': candidates.map((c) => c.toJson()).toList(),
      'total_found': candidates.length,
      'total_returned': report.totalReturned,
      'total_unique_found': report.totalUniqueFound,
      'total_all_unique': report.totalAllUnique,
      'per_dir_stats': report.perDirStats,
      if (!hasApk)
        'message':
            'No se encontraron archivos APK en las rutas de búsqueda configuradas.',
    });
  }

  static Future<void> _handleImportLocalApk(AdminHttpContext ctx) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    final rawSourcePath = (body['source_path'] as String? ?? '').trim();

    if (rawSourcePath.isEmpty ||
        !rawSourcePath.toLowerCase().endsWith('.apk')) {
      await ctx.sendJson(
        {'error': 'Ruta de archivo .apk inválida'},
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    final normalizedSource =
        ApkInspectorService.canonicalizePath(rawSourcePath);
    final sourceFile = File(normalizedSource);
    if (!await sourceFile.exists()) {
      await ctx.sendJson(
        {
          'error':
              'El archivo APK de origen no existe en disco: $normalizedSource',
        },
        statusCode: HttpStatus.notFound,
      );
      return;
    }

    final canonicalSource = await sourceFile.resolveSymbolicLinks();
    final sourceCmp =
        Platform.isWindows ? canonicalSource.toLowerCase() : canonicalSource;
    final configuredRoots = ctx.configService.getEffectiveApkSearchDirPaths(
      defaultBuildOutputDir: ctx.inspector.defaultBuildOutputDir?.path,
    );
    final rawRoots = <String>[
      ...configuredRoots,
      ctx.configService.apkLibraryDir,
      '../app_movil/build',
      'releases_apks',
      Directory.systemTemp.path,
    ];
    final sep = Platform.pathSeparator;
    final inAllowedRoot = rawRoots.any((r) {
      final canonRoot = ApkInspectorService.canonicalizePath(r);
      final rootCmp = Platform.isWindows ? canonRoot.toLowerCase() : canonRoot;
      if (rootCmp.isEmpty) return false;
      return sourceCmp == rootCmp || sourceCmp.startsWith('$rootCmp$sep');
    });
    final isAllowed = inAllowedRoot &&
        !ctx.configService.isForbiddenApkSearchDir(sourceFile.parent.path);

    if (!isAllowed) {
      await ctx.sendJson(
        {
          'error':
              'Acceso denegado: el archivo debe residir en una ruta de búsqueda autorizada o directorio de build.',
        },
        statusCode: HttpStatus.forbidden,
      );
      return;
    }

    final targetDir = ctx.dbService.currentReleasesApkDir;
    await targetDir.create(recursive: true);
    final safeFileName = sourceFile.uri.pathSegments.last
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '_');
    final destFile = File('${targetDir.path}/$safeFileName');
    await sourceFile.copy(destFile.path);

    final inspection = await ctx.inspector.inspectApk(
      destFile,
      apkLibraryDir: ctx.configService.apkLibraryDir,
      extraSearchDirs: <String>[
        sourceFile.parent.path,
        ...configuredRoots,
      ],
    );

    await ctx.sendJson({
      'ok': true,
      'imported_path': inspection.filePath,
      ...inspection.toJson(),
    });
  }

  static Future<void> _handleDownloadApk(AdminHttpContext ctx) async {
    final versionName =
        ctx.path.replaceFirst('/api/releases/download/', '').trim();
    final variant = ctx.request.uri.queryParameters['variant']?.toLowerCase();
    final release = await ctx.dbService.getReleaseByVersion(versionName);

    final apkFile = await ReleaseApkHelper.resolveExistingReleaseApkFile(
      release,
      variant: variant,
      fallbackCandidatePaths: [
        'releases_apks/${ctx.dbService.currentMode}/mochilalista-v$versionName.apk',
        'releases_apks/${ctx.dbService.currentMode}/mochilalista-$versionName.apk',
        '../app_movil/build/app/outputs/flutter-apk/app-release.apk',
      ],
    );

    if (apkFile == null || !await apkFile.exists()) {
      await ctx.sendJson(
        {
          'error':
              'Archivo APK no encontrado en disco para la versión $versionName',
        },
        statusCode: HttpStatus.notFound,
      );
      return;
    }

    ctx.request.response.headers.contentType =
        ContentType('application', 'vnd.android.package-archive');
    ctx.request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="${apkFile.uri.pathSegments.last}"',
    );
    await apkFile.openRead().pipe(ctx.request.response);
  }

  static Future<void> _handleCopyApkFile(
    AdminHttpContext ctx,
    String versionName,
  ) async {
    final variant = ctx.request.uri.queryParameters['variant']?.toLowerCase();
    final release = await ctx.dbService.getReleaseByVersion(versionName);

    final apkFile = await ReleaseApkHelper.resolveExistingReleaseApkFile(
      release,
      variant: variant,
      fallbackCandidatePaths: [
        'releases_apks/${ctx.dbService.currentMode}/mochilalista-v$versionName.apk',
      ],
    );

    if (apkFile == null || !await apkFile.exists()) {
      await ctx.sendJson(
        {
          'error':
              'No se encontró archivo APK en disco para copiar al portapapeles',
        },
        statusCode: HttpStatus.notFound,
      );
      return;
    }

    final rawFullPath = apkFile.absolute.path;
    final canonicalFullPath = ApkInspectorService.canonicalizePath(rawFullPath);
    bool copiedOk = false;
    String? clipboardError;

    if (ctx.onCopyFileOverride != null) {
      copiedOk = await ctx.onCopyFileOverride!(rawFullPath);
    } else if (Platform.isWindows) {
      try {
        final psArgs = buildWindowsClipboardPsArgs(canonicalFullPath);
        final proc = await Process.run('powershell', psArgs)
            .timeout(const Duration(seconds: 12));
        copiedOk = proc.exitCode == 0;
        if (!copiedOk) {
          final err = proc.stderr.toString().trim();
          final out = proc.stdout.toString().trim();
          clipboardError = err.isNotEmpty
              ? err
              : (out.isNotEmpty ? out : 'PowerShell exitCode ${proc.exitCode}');
        }
      } catch (e) {
        copiedOk = false;
        clipboardError = e.toString();
      }
    } else {
      copiedOk = true;
    }

    if (!copiedOk) {
      await ctx.sendJson(
        {
          'ok': false,
          'error': clipboardError ??
              'No se pudo copiar el archivo .APK al portapapeles de Windows.',
          'copied_path': canonicalFullPath,
          'file_name': apkFile.uri.pathSegments.last,
          'variant': variant ?? 'universal',
        },
        statusCode: HttpStatus.internalServerError,
      );
      return;
    }

    await ctx.sendJson({
      'ok': true,
      'copied_path': canonicalFullPath,
      'file_name': apkFile.uri.pathSegments.last,
      'variant': variant ?? 'universal',
    });
  }

  static Future<void> _handleRevealApkFile(AdminHttpContext ctx) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    final versionName = body['version_name'] as String? ?? '';
    final variant =
        (ctx.request.uri.queryParameters['variant'] ?? body['variant'] as String?)
            ?.toLowerCase();
    final release = await ctx.dbService.getReleaseByVersion(versionName);

    final apkFile = await ReleaseApkHelper.resolveExistingReleaseApkFile(
      release,
      variant: variant,
      fallbackCandidatePaths: [
        'releases_apks/${ctx.dbService.currentMode}/mochilalista-v$versionName.apk',
      ],
    );

    if (apkFile != null && await apkFile.exists()) {
      final fullPath = apkFile.path;
      if (Platform.isWindows) {
        try {
          Process.run(
              'explorer.exe', ['/select,', apkFile.absolute.path]);
        } catch (_) {}
      }
      await ctx.sendJson({
        'ok': true,
        'path': fullPath,
        'variant': variant ?? 'universal',
      });
    } else {
      await ctx.sendJson(
        {'error': 'No se encontró archivo físico para esta versión'},
        statusCode: HttpStatus.notFound,
      );
    }
  }
}
