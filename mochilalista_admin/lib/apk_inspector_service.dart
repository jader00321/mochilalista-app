import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Configuración de una carpeta de búsqueda de APKs locales
class ApkSearchDirConfig {
  final String path;
  final String label;
  final bool enabled;
  final bool isDefault;
  final String kind; // 'official_library' | 'custom' | 'flutter_build'

  const ApkSearchDirConfig({
    required this.path,
    required this.label,
    this.enabled = true,
    this.isDefault = false,
    this.kind = 'custom',
  });

  int get priority {
    if (kind == 'official_library') return 0;
    if (kind == 'custom') return 1;
    return 2; // flutter_build
  }

  ApkSearchDirConfig copyWith({
    String? path,
    String? label,
    bool? enabled,
    bool? isDefault,
    String? kind,
  }) {
    return ApkSearchDirConfig(
      path: path ?? this.path,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      isDefault: isDefault ?? this.isDefault,
      kind: kind ?? this.kind,
    );
  }

  factory ApkSearchDirConfig.fromJson(Map<String, dynamic> json) {
    final rawKind = (json['kind'] as String? ?? 'custom').trim();
    final kind = (rawKind == 'official_library' ||
            rawKind == 'flutter_build' ||
            rawKind == 'custom')
        ? rawKind
        : 'custom';
    final rawLabel = (json['label'] as String? ?? '').trim();
    return ApkSearchDirConfig(
      path: (json['path'] as String? ?? '').trim(),
      label: rawLabel.isNotEmpty
          ? rawLabel
          : (kind == 'official_library'
              ? 'Biblioteca Oficial'
              : (kind == 'flutter_build'
                  ? 'Compilación Local (app_movil/build)'
                  : 'Carpeta Personalizada')),
      enabled: json['enabled'] != false,
      isDefault: json['is_default'] == true,
      kind: kind,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'label': label,
        'enabled': enabled,
        'is_default': isDefault,
        'kind': kind,
      };
}

/// Reporte completo de autodetección local incluyendo métricas por directorio
class ApkDetectionReport {
  final List<ApkInspectionResult> results;
  final List<Map<String, dynamic>> perDirStats;
  final int totalUniqueFound;
  final int totalAllUnique;
  final int totalReturned;

  const ApkDetectionReport({
    required this.results,
    required this.perDirStats,
    required this.totalUniqueFound,
    required this.totalAllUnique,
    required this.totalReturned,
  });
}

/// Resultado estructurado de la inspección de un archivo .apk
class ApkInspectionResult {
  final bool success;
  final String? errorMessage;
  final String fileName;
  final String filePath;
  final String? sourceLabel;
  final DateTime? modifiedAt;
  final int sizeBytes;
  final String sizeMb;
  final String sha256;
  final String? packageName;
  final String? versionName;
  final int? versionCode;
  final String abiVariant; // 'ARM64' | 'UNIVERSAL'
  final int dbSchemaVersion;
  final String minRequiredVersion;
  final String? minSdk;
  final String? targetSdk;
  final bool?
      signatureVerified; // true: oficial, false: no oficial / debug, null: tool no disponible o no verificable
  final String
      signatureStatus; // 'OFFICIAL_RELEASE' | 'UNOFFICIAL_SIGNATURE' | 'UNVERIFIED'
  final String? signatureDetail;
  final String? signerSha256;
  final String? signerDn;
  final String suggestedChangelog;
  final String suggestedInternalNotes;
  final String suggestedReleaseType; // 'FEATURE_RELEASE' | 'HOTFIX'
  final List<String> duplicatePaths;

  const ApkInspectionResult({
    required this.success,
    this.errorMessage,
    required this.fileName,
    required this.filePath,
    this.sourceLabel,
    this.modifiedAt,
    required this.sizeBytes,
    required this.sizeMb,
    required this.sha256,
    this.packageName,
    this.versionName,
    this.versionCode,
    required this.abiVariant,
    this.dbSchemaVersion = 36,
    this.minRequiredVersion = '9.0.0',
    this.minSdk,
    this.targetSdk,
    this.signatureVerified,
    required this.signatureStatus,
    this.signatureDetail,
    this.signerSha256,
    this.signerDn,
    this.suggestedChangelog = '',
    this.suggestedInternalNotes = '',
    this.suggestedReleaseType = 'FEATURE_RELEASE',
    this.duplicatePaths = const [],
  });

  ApkInspectionResult copyWith({
    List<String>? duplicatePaths,
    String? sourceLabel,
    String? filePath,
  }) {
    return ApkInspectionResult(
      success: success,
      errorMessage: errorMessage,
      fileName: fileName,
      filePath: filePath ?? this.filePath,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      modifiedAt: modifiedAt,
      sizeBytes: sizeBytes,
      sizeMb: sizeMb,
      sha256: sha256,
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      abiVariant: abiVariant,
      dbSchemaVersion: dbSchemaVersion,
      minRequiredVersion: minRequiredVersion,
      minSdk: minSdk,
      targetSdk: targetSdk,
      signatureVerified: signatureVerified,
      signatureStatus: signatureStatus,
      signatureDetail: signatureDetail,
      signerSha256: signerSha256,
      signerDn: signerDn,
      suggestedChangelog: suggestedChangelog,
      suggestedInternalNotes: suggestedInternalNotes,
      suggestedReleaseType: suggestedReleaseType,
      duplicatePaths: duplicatePaths ?? this.duplicatePaths,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (errorMessage != null) 'error_message': errorMessage,
        'file_name': fileName,
        'file_path': filePath,
        if (sourceLabel != null) 'source_label': sourceLabel,
        if (modifiedAt != null)
          'modified_at': modifiedAt!.toUtc().toIso8601String(),
        'size_bytes': sizeBytes,
        'size_mb': sizeMb,
        'sha256': sha256,
        'package_name': packageName,
        'version_name': versionName,
        'version_code': versionCode,
        'abi_variant': abiVariant,
        'db_schema_version': dbSchemaVersion,
        'min_required_version': minRequiredVersion,
        'min_sdk': minSdk,
        'target_sdk': targetSdk,
        'signature_verified': signatureVerified,
        'signature_status': signatureStatus,
        if (signatureDetail != null) 'signature_detail': signatureDetail,
        'signer_sha256': signerSha256,
        'signer_dn': signerDn,
        'suggested_changelog': suggestedChangelog,
        'suggested_internal_notes': suggestedInternalNotes,
        'suggested_release_type': suggestedReleaseType,
        'duplicate_paths': duplicatePaths,
      };
}

/// Servicio de Inspección Forense de APKs, Extracción Determinista y Escudo Anti-debug.apk
class ApkInspectorService {
  /// Huella SHA-256 oficial del certificado comercial de Julio Angello Vasquez Navarro
  static const String officialSignerSha256 =
      '7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20';

  /// Inyección mockeable de ejecutor de procesos para pruebas unitarias sin dependencias externas
  final Future<ProcessResult> Function(
      String executable, List<String> arguments)? processRunnerOverride;

  /// Inyección de raíces de búsqueda de SDK para pruebas unitarias
  final List<String>? sdkSearchRootsOverride;

  /// Directorio opcional de compilación local (anula ../app_movil/build/... para pruebas unitarias)
  final Directory? defaultBuildOutputDir;

  static const int _maxLiveCacheEntries = 256;
  final Map<String, _CachedApkMetadata> _liveInspectionCache = {};

  /// Limpia la caché en memoria de inspecciones APK por archivo
  void clearInspectionCache() => _liveInspectionCache.clear();

  ApkInspectorService({
    this.processRunnerOverride,
    this.sdkSearchRootsOverride,
    this.defaultBuildOutputDir,
  });

  /// Normaliza una ruta eliminando segmentos `..`, unificando separadores y resolviendo enlaces
  static String canonicalizePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return trimmed;
    try {
      final f = File(trimmed);
      if (f.existsSync()) {
        return f.resolveSymbolicLinksSync();
      }
      final d = Directory(trimmed);
      if (d.existsSync()) {
        return d.resolveSymbolicLinksSync();
      }
    } catch (_) {}

    final abs = File(trimmed).absolute.path;
    return _normalizeLexicalPath(abs);
  }

  static String _normalizeLexicalPath(String rawAbs) {
    final sep = Platform.pathSeparator;
    String path = rawAbs.replaceAll('/', sep).replaceAll('\\', sep);

    String prefix = '';
    if (Platform.isWindows) {
      if (path.startsWith(r'\\')) {
        prefix = r'\\';
        path = path.substring(2);
      } else if (path.length >= 2 && path[1] == ':') {
        prefix = '${path.substring(0, 2)}$sep';
        path = path.substring(2);
      }
    } else if (path.startsWith('/')) {
      prefix = '/';
      path = path.substring(1);
    }

    final resolved = <String>[];
    for (final seg in path.split(sep)) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else {
        resolved.add(seg);
      }
    }
    return '$prefix${resolved.join(sep)}';
  }

  /// Infiere tipo de lanzamiento sugerido desde SemVer:
  /// `patch > 0` -> `HOTFIX`, `patch == 0` -> `FEATURE_RELEASE`
  static String inferReleaseTypeFromVersion(String? versionName) {
    if (versionName == null || versionName.trim().isEmpty) {
      return 'FEATURE_RELEASE';
    }
    final clean = versionName
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    final parts = clean.split('.');
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return patch > 0 ? 'HOTFIX' : 'FEATURE_RELEASE';
  }

  /// Directorios pesados o sensibles excluidos durante el escaneo recursivo acotado
  static const Set<String> ignoredScanDirNames = {
    '.git',
    '.dart_tool',
    '.gradle',
    '.idea',
    '.vscode',
    'node_modules',
    'intermediates',
    'tmp',
    'temp',
    'obj',
    'bin',
    'symbols',
    'app_symbols',
    'private_keys',
    'backups',
    'data',
  };

  /// Comparador SemVer numérico determinista para ordenar versiones descendentes
  static int compareSemVer(String? a, String? b) {
    final aEmpty = a == null || a.trim().isEmpty;
    final bEmpty = b == null || b.trim().isEmpty;
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return -1;
    if (bEmpty) return 1;

    List<int> parseParts(String raw) {
      final clean = raw
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first;
      final segs = clean.split('.');
      return [
        segs.isNotEmpty ? (int.tryParse(segs[0]) ?? 0) : 0,
        segs.length > 1 ? (int.tryParse(segs[1]) ?? 0) : 0,
        segs.length > 2 ? (int.tryParse(segs[2]) ?? 0) : 0,
      ];
    }

    final pa = parseParts(a);
    final pb = parseParts(b);
    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  /// Inspecciona exhaustivamente un archivo APK combinando Dart puro y herramientas Android SDK
  Future<ApkInspectionResult> inspectApk(
    File apkFile, {
    String? sourceLabel,
    String? apkLibraryDir,
    List<Object> extraSearchDirs = const [],
  }) async {
    final canonicalApkPath = canonicalizePath(apkFile.path);
    final canonicalFile = File(canonicalApkPath);
    final cacheKey =
        Platform.isWindows ? canonicalApkPath.toLowerCase() : canonicalApkPath;

    if (!await canonicalFile.exists()) {
      _liveInspectionCache.remove(cacheKey);
      return ApkInspectionResult(
        success: false,
        errorMessage: 'El archivo APK no existe en disco: $canonicalApkPath',
        fileName: canonicalFile.uri.pathSegments.isNotEmpty
            ? canonicalFile.uri.pathSegments.last
            : 'desconocido.apk',
        filePath: canonicalApkPath,
        sourceLabel: sourceLabel,
        sizeBytes: 0,
        sizeMb: '0.00 MB',
        sha256: '',
        abiVariant: 'UNIVERSAL',
        signatureVerified: null,
        signatureStatus: 'UNVERIFIED',
        signatureDetail: 'El archivo APK no existe en disco.',
      );
    }

    final stat = await canonicalFile.stat();
    final modifiedMicros = stat.modified.microsecondsSinceEpoch;
    final fileName = canonicalFile.uri.pathSegments.isNotEmpty
        ? canonicalFile.uri.pathSegments.last
        : 'app-release.apk';

    Future<ApkInspectionResult> materializeWithNotes(_CachedApkMetadata meta) async {
      final notes = await readCompanionNotesForVersion(
        meta.versionName ?? '',
        apkPath: canonicalApkPath,
        apkLibraryDir: apkLibraryDir,
        extraSearchDirs: extraSearchDirs,
        fallbackRegistryChangelog: true,
      );
      return ApkInspectionResult(
        success: true,
        fileName: fileName,
        filePath: canonicalApkPath,
        sourceLabel: sourceLabel,
        modifiedAt: stat.modified,
        sizeBytes: meta.sizeBytes,
        sizeMb: meta.sizeMb,
        sha256: meta.sha256,
        packageName: meta.packageName ?? 'com.mochilalista.app',
        versionName: meta.versionName ?? '9.38.0',
        versionCode: meta.versionCode ?? 82,
        abiVariant: meta.abiVariant,
        dbSchemaVersion: meta.dbSchemaVersion,
        minRequiredVersion: meta.minRequiredVersion,
        minSdk: meta.minSdk,
        targetSdk: meta.targetSdk,
        signatureVerified: meta.signatureVerified,
        signatureStatus: meta.signatureStatus,
        signatureDetail: meta.signatureDetail,
        signerSha256: meta.signerSha256,
        signerDn: meta.signerDn,
        suggestedChangelog: (notes['suggested_changelog'] as String?) ?? '',
        suggestedInternalNotes:
            (notes['suggested_internal_notes'] as String?) ?? '',
        suggestedReleaseType: meta.suggestedReleaseType,
      );
    }

    final cachedMeta = _liveInspectionCache[cacheKey];
    if (cachedMeta != null &&
        cachedMeta.sizeBytes == stat.size &&
        cachedMeta.modifiedMicros == modifiedMicros) {
      return materializeWithNotes(cachedMeta);
    }

    // 1. Capa 1: Tamaño y Hash Criptográfico SHA-256 determinista
    final fileLength = await canonicalFile.length();
    final sha256Digest = (await sha256.bind(canonicalFile.openRead()).first)
        .toString()
        .toLowerCase();
    final sizeMb = (fileLength / (1024 * 1024)).toStringAsFixed(2);
    final sizeMbStr = '$sizeMb MB';

    // 2. Capa 1: Detección ABI determinista en Dart puro inspeccionando el ZIP
    final detectedAbis = await _detectZipAbis(canonicalFile);
    final isArm64Only =
        detectedAbis.length == 1 && detectedAbis.contains('arm64-v8a');
    final abiVariant = isArm64Only ? 'ARM64' : 'UNIVERSAL';

    // Inferencia de fallback por nombre de archivo
    final nameInference = _inferVersionFromName(fileName);

    // Inferencia de esquema SQLite desde el código fuente si está disponible
    final dbSchemaVersion = await _inferDbSchemaVersion();

    // 3. Capa 2: Extracción profunda con aapt2 si está disponible
    String? packageName;
    String? versionName = nameInference.versionName;
    int? versionCode = nameInference.versionCode;
    String? minSdk;
    String? targetSdk;

    final aapt2Exe = await _findBuildTool('aapt2');
    if (aapt2Exe != null) {
      final aaptRes =
          await _runProcess(aapt2Exe, ['dump', 'badging', canonicalApkPath]);
      if (aaptRes.exitCode == 0) {
        final out = aaptRes.stdout.toString();
        final parsed = _parseAapt2Badging(out);
        if (parsed.packageName != null) packageName = parsed.packageName;
        if (parsed.versionName != null) versionName = parsed.versionName;
        if (parsed.versionCode != null) versionCode = parsed.versionCode;
        if (parsed.minSdk != null) minSdk = parsed.minSdk;
        if (parsed.targetSdk != null) targetSdk = parsed.targetSdk;
      }
    }

    // Fallback complementario desde pubspec.yaml si aún faltan datos
    if (versionName == null || versionCode == null) {
      final pubspecMeta = await _readPubspecVersion();
      versionName ??= pubspecMeta.versionName;
      versionCode ??= pubspecMeta.versionCode;
    }

    // 4. Capa 3: Escudo Anti-debug.apk con apksigner (compatible SDK <=36 y 37+)
    bool? signatureVerified;
    String signatureStatus = 'UNVERIFIED';
    String? signatureDetail;
    String? signerSha256;
    String? signerDn;

    final apksignerBin = await _findBuildTool('apksigner');
    if (apksignerBin == null) {
      signatureVerified = null;
      signatureStatus = 'UNVERIFIED';
      signatureDetail = 'apksigner no disponible en el SDK de Android.';
    } else {
      final apkSignerRes = await _runProcess(
        apksignerBin,
        ['verify', '--verbose', '--print-certs', canonicalApkPath],
      );
      if (apkSignerRes.exitCode == 0) {
        final out = '${apkSignerRes.stdout}\n${apkSignerRes.stderr}';
        final parsedSig = _parseApksignerOutput(out);
        signerSha256 = parsedSig.signerSha256;
        signerDn = parsedSig.signerDn;

        if (parsedSig.signerSha256 == null) {
          signatureVerified = null;
          signatureStatus = 'UNVERIFIED';
          signatureDetail =
              'apksigner finalizó correctamente pero no devolvió una huella SHA-256 legible.';
        } else if (parsedSig.signerSha256!.toLowerCase() ==
            officialSignerSha256.toLowerCase()) {
          signatureVerified = true;
          signatureStatus = 'OFFICIAL_RELEASE';
          signatureDetail = 'Certificado oficial RSA-4096 verificado.';
        } else {
          signatureVerified = false;
          signatureStatus = 'UNOFFICIAL_SIGNATURE';
          signatureDetail =
              'La huella del certificado (${parsedSig.signerSha256}) no coincide con la oficial.';
        }
      } else {
        signatureVerified = null;
        signatureStatus = 'UNVERIFIED';
        final errOut = apkSignerRes.stderr.toString().trim();
        signatureDetail = errOut.isNotEmpty
            ? 'No se pudo verificar con apksigner (${apkSignerRes.exitCode}): $errOut'
            : 'apksigner no pudo completar la verificación (código ${apkSignerRes.exitCode}).';
      }
    }

    final meta = _CachedApkMetadata(
      sizeBytes: fileLength,
      modifiedMicros: modifiedMicros,
      sizeMb: sizeMbStr,
      sha256: sha256Digest,
      packageName: packageName ?? 'com.mochilalista.app',
      versionName: versionName ?? '9.38.0',
      versionCode: versionCode ?? 82,
      abiVariant: abiVariant,
      dbSchemaVersion: dbSchemaVersion,
      minRequiredVersion: '9.0.0',
      minSdk: minSdk,
      targetSdk: targetSdk,
      signatureVerified: signatureVerified,
      signatureStatus: signatureStatus,
      signatureDetail: signatureDetail,
      signerSha256: signerSha256,
      signerDn: signerDn,
      suggestedReleaseType: inferReleaseTypeFromVersion(versionName),
    );
    if (_liveInspectionCache.length >= _maxLiveCacheEntries &&
        !_liveInspectionCache.containsKey(cacheKey)) {
      _liveInspectionCache.remove(_liveInspectionCache.keys.first);
    }
    _liveInspectionCache[cacheKey] = meta;

    return materializeWithNotes(meta);
  }

  /// Sondea rápidamente una ruta de búsqueda (recursivo acotado) para estadísticas de UI
  static _DirScanResult _scanDirectoryForApks(
    ApkSearchDirConfig dirCfg, {
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
  }) {
    final canonRoot = canonicalizePath(dirCfg.path);
    final rootDir = Directory(canonRoot);
    if (canonRoot.isEmpty || !rootDir.existsSync()) {
      return _DirScanResult(
        canonicalPath: canonRoot,
        exists: false,
        readable: false,
        candidates: const [],
      );
    }

    final candidates = <_ApkCandidate>[];
    final seenFiles = <String>{};
    final seenDirs = <String>{};
    bool readable = true;
    int visitedEntries = 0;

    final rootKey = Platform.isWindows ? canonRoot.toLowerCase() : canonRoot;
    seenDirs.add(rootKey);

    // Recorrido BFS acotado por profundidad para priorizar niveles cercanos a la raíz
    final queue = <_DirQueueItem>[_DirQueueItem(rootDir, 0)];
    while (queue.isNotEmpty && visitedEntries < maxEntriesPerRoot) {
      final current = queue.removeAt(0);
      List<FileSystemEntity> entries;
      try {
        entries = current.dir.listSync(followLinks: false);
      } catch (_) {
        if (current.depth == 0) readable = false;
        continue;
      }

      for (final entity in entries) {
        if (visitedEntries >= maxEntriesPerRoot) break;
        visitedEntries++;

        if (entity is File) {
          if (!entity.path.toLowerCase().endsWith('.apk')) continue;
          try {
            final canonFile = canonicalizePath(entity.path);
            final key =
                Platform.isWindows ? canonFile.toLowerCase() : canonFile;
            if (seenFiles.add(key)) {
              final stat = File(canonFile).statSync();
              final fileName = File(canonFile).uri.pathSegments.isNotEmpty
                  ? File(canonFile).uri.pathSegments.last
                  : '';
              final inferred = _inferVersionFromNameStatic(fileName);
              candidates.add(_ApkCandidate(
                file: File(canonFile),
                sourceLabel: dirCfg.label,
                rootPath: canonRoot,
                modified: stat.modified,
                priority: dirCfg.priority,
                inferredVersion: inferred.versionName,
              ));
            }
          } catch (_) {}
        } else if (entity is Directory && current.depth < maxDepth) {
          final segs =
              entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
          final baseName = segs.isNotEmpty ? segs.last.toLowerCase() : '';
          if (baseName.isEmpty ||
              baseName.startsWith('.') ||
              ignoredScanDirNames.contains(baseName)) {
            continue;
          }
          try {
            final canonSub = canonicalizePath(entity.path);
            final dirKey =
                Platform.isWindows ? canonSub.toLowerCase() : canonSub;
            if (seenDirs.add(dirKey)) {
              queue.add(_DirQueueItem(Directory(canonSub), current.depth + 1));
            }
          } catch (_) {}
        }
      }
    }

    return _DirScanResult(
      canonicalPath: canonRoot,
      exists: true,
      readable: readable,
      candidates: candidates,
    );
  }

  /// Devuelve métricas rápidas (existencia, legibilidad y conteo .apk) de una carpeta configurada
  static Map<String, dynamic> probeSearchDirStats(
    ApkSearchDirConfig dirCfg, {
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
  }) {
    final scan = _scanDirectoryForApks(
      dirCfg,
      maxDepth: maxDepth,
      maxEntriesPerRoot: maxEntriesPerRoot,
    );
    return {
      'path': dirCfg.path,
      'canonical_path': scan.canonicalPath,
      'label': dirCfg.label,
      'kind': dirCfg.kind,
      'enabled': dirCfg.enabled,
      'is_default': dirCfg.isDefault,
      'exists': scan.exists,
      'readable': scan.readable,
      'apk_count': scan.candidates.length,
    };
  }

  /// Escanea transparentemente las rutas configuradas (recursivo acotado),
  /// deduplicando por SHA-256 (prioriza Biblioteca Oficial > Personalizada > build/)
  /// y ordenando con ranking híbrido (SemVer descendente + Build + Fecha).
  Future<ApkDetectionReport> detectLocalApksWithStats({
    Directory? apkLibraryDir,
    Directory? buildOutputDir,
    List<ApkSearchDirConfig>? searchDirs,
    int maxCandidates = 6,
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
    String abiFilter = 'ALL',
    String query = '',
    int? limit,
  }) async {
    final effectiveLimit = (limit ?? maxCandidates).clamp(1, 50);
    final configuredDirs = searchDirs ??
        [
          ApkSearchDirConfig(
            path: apkLibraryDir?.path ??
                (Platform.isWindows
                    ? r'C:\Users\vjuli\Documents\v-app-offline apks'
                    : 'releases_apks'),
            label: 'Biblioteca Oficial (v-app-offline apks)',
            enabled: true,
            isDefault: true,
            kind: 'official_library',
          ),
          ApkSearchDirConfig(
            path: (buildOutputDir ??
                    defaultBuildOutputDir ??
                    Directory('../app_movil/build/app/outputs/flutter-apk'))
                .path,
            label: 'Compilación Local (app_movil/build)',
            enabled: true,
            isDefault: true,
            kind: 'flutter_build',
          ),
        ];

    final perDirStats = <Map<String, dynamic>>[];
    final perRootCandidates = <List<_ApkCandidate>>[];
    final seenGlobalFiles = <String>{};
    final activeSearchDirPaths = <String>[];

    for (final dirCfg in configuredDirs) {
      final scan = _scanDirectoryForApks(
        dirCfg,
        maxDepth: maxDepth,
        maxEntriesPerRoot: maxEntriesPerRoot,
      );
      perDirStats.add({
        'path': dirCfg.path,
        'canonical_path': scan.canonicalPath,
        'label': dirCfg.label,
        'kind': dirCfg.kind,
        'enabled': dirCfg.enabled,
        'is_default': dirCfg.isDefault,
        'exists': scan.exists,
        'readable': scan.readable,
        'apk_count': scan.candidates.length,
      });

      if (!dirCfg.enabled || !scan.exists) continue;
      if (scan.canonicalPath.isNotEmpty) {
        activeSearchDirPaths.add(scan.canonicalPath);
      }

      final rootList = <_ApkCandidate>[];
      for (final cand in scan.candidates) {
        final fKey =
            Platform.isWindows ? cand.file.path.toLowerCase() : cand.file.path;
        if (seenGlobalFiles.add(fKey)) {
          rootList.add(cand);
        }
      }

      rootList.sort((a, b) {
        final cmpDate = b.modified.compareTo(a.modified);
        if (cmpDate != 0) return cmpDate;
        final cmpVer = compareSemVer(b.inferredVersion, a.inferredVersion);
        if (cmpVer != 0) return cmpVer;
        return a.priority.compareTo(b.priority);
      });
      if (rootList.isNotEmpty) {
        perRootCandidates.add(rootList);
      }
    }

    // Selección equilibrada entre todas las rutas activas (evita que una carpeta antigua eclipse builds nuevos)
    final inspectLimit = (effectiveLimit * 4).clamp(24, 36);
    final selectedCandidates = <_ApkCandidate>[];
    final selectedKeys = <String>{};

    if (perRootCandidates.isNotEmpty) {
      final perRootQuota = (inspectLimit / perRootCandidates.length)
          .ceil()
          .clamp(4, inspectLimit);
      for (final rootList in perRootCandidates) {
        for (final c in rootList.take(perRootQuota)) {
          final k =
              Platform.isWindows ? c.file.path.toLowerCase() : c.file.path;
          if (selectedKeys.add(k)) {
            selectedCandidates.add(c);
          }
        }
      }
    }

    final remaining = <_ApkCandidate>[];
    for (final rootList in perRootCandidates) {
      for (final c in rootList) {
        final k = Platform.isWindows ? c.file.path.toLowerCase() : c.file.path;
        if (!selectedKeys.contains(k)) {
          remaining.add(c);
        }
      }
    }
    remaining.sort((a, b) {
      final cmpDate = b.modified.compareTo(a.modified);
      if (cmpDate != 0) return cmpDate;
      return a.priority.compareTo(b.priority);
    });
    for (final c in remaining) {
      if (selectedCandidates.length >= inspectLimit) break;
      final k = Platform.isWindows ? c.file.path.toLowerCase() : c.file.path;
      if (selectedKeys.add(k)) {
        selectedCandidates.add(c);
      }
    }

    final libPath = canonicalizePath(
      apkLibraryDir?.path ??
          configuredDirs
              .firstWhere(
                (d) => d.kind == 'official_library',
                orElse: () => configuredDirs.first,
              )
              .path,
    );

    final uniqueItems = <_InspectedCandidateItem>[];
    final indexBySha = <String, int>{};

    for (final c in selectedCandidates) {
      final res = await inspectApk(
        c.file,
        sourceLabel: c.sourceLabel,
        apkLibraryDir: libPath,
        extraSearchDirs: activeSearchDirPaths,
      );
      if (res.sha256.isEmpty) {
        uniqueItems.add(_InspectedCandidateItem(res, c.priority));
        continue;
      }

      final existingIdx = indexBySha[res.sha256];
      if (existingIdx == null) {
        indexBySha[res.sha256] = uniqueItems.length;
        uniqueItems.add(_InspectedCandidateItem(res, c.priority));
      } else {
        final existingItem = uniqueItems[existingIdx];
        if (c.priority < existingItem.priority) {
          final mergedDups = <String>[
            ...existingItem.result.duplicatePaths,
            existingItem.result.filePath,
          ];
          uniqueItems[existingIdx] = _InspectedCandidateItem(
            res.copyWith(duplicatePaths: mergedDups),
            c.priority,
          );
        } else {
          final mergedDups = <String>[
            ...existingItem.result.duplicatePaths,
            res.filePath,
          ];
          uniqueItems[existingIdx] = _InspectedCandidateItem(
            existingItem.result.copyWith(duplicatePaths: mergedDups),
            existingItem.priority,
          );
        }
      }
    }

    // Ranking híbrido: SemVer desc -> versionCode desc -> modifiedAt desc -> priority asc -> ABI
    uniqueItems.sort((a, b) {
      final semCmp = compareSemVer(b.result.versionName, a.result.versionName);
      if (semCmp != 0) return semCmp;
      final vcCmp =
          (b.result.versionCode ?? 0).compareTo(a.result.versionCode ?? 0);
      if (vcCmp != 0) return vcCmp;
      final dateA =
          a.result.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          b.result.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCmp = dateB.compareTo(dateA);
      if (dateCmp != 0) return dateCmp;
      final prioCmp = a.priority.compareTo(b.priority);
      if (prioCmp != 0) return prioCmp;
      return a.result.abiVariant.compareTo(b.result.abiVariant);
    });

    final totalAllUnique = uniqueItems.length;
    final normAbi = abiFilter.trim().toUpperCase();
    final normQuery = query.trim().toLowerCase();

    final filtered = uniqueItems.map((e) => e.result).where((res) {
      if (normAbi == 'ARM64' && res.abiVariant != 'ARM64') return false;
      if (normAbi == 'UNIVERSAL' && res.abiVariant == 'ARM64') return false;
      if (normQuery.isNotEmpty) {
        final haystack = [
          res.versionName ?? '',
          '${res.versionCode ?? ''}',
          res.fileName,
          res.filePath,
          res.sourceLabel ?? '',
          res.sha256,
          res.abiVariant,
        ].join(' ').toLowerCase();
        if (!haystack.contains(normQuery)) return false;
      }
      return true;
    }).toList();

    final limited = filtered.take(effectiveLimit).toList();
    return ApkDetectionReport(
      results: limited,
      perDirStats: perDirStats,
      totalUniqueFound: filtered.length,
      totalAllUnique: totalAllUnique,
      totalReturned: limited.length,
    );
  }

  /// Wrapper retrocompatible que retorna directamente la lista de resultados detectados
  Future<List<ApkInspectionResult>> detectLocalApks({
    required Directory apkLibraryDir,
    Directory? buildOutputDir,
    List<ApkSearchDirConfig>? searchDirs,
    int maxCandidates = 6,
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
    String abiFilter = 'ALL',
    String query = '',
    int? limit,
  }) async {
    final report = await detectLocalApksWithStats(
      apkLibraryDir: apkLibraryDir,
      buildOutputDir: buildOutputDir,
      searchDirs: searchDirs,
      maxCandidates: maxCandidates,
      maxDepth: maxDepth,
      maxEntriesPerRoot: maxEntriesPerRoot,
      abiFilter: abiFilter,
      query: query,
      limit: limit,
    );
    return report.results;
  }

  // =================== MÉTODOS AUXILIARES DETERMINISTAS ===================

  /// Lector en Dart puro del directorio central de un archivo ZIP/APK
  /// para detectar las arquitecturas bajo `lib/` sin dependencias externas
  Future<Set<String>> _detectZipAbis(File file) async {
    final abis = <String>{};
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final len = await raf.length();
      if (len < 22) return abis;

      // Buscar el End of Central Directory (EOCD: 0x06054b50) en los últimos 65KB
      final searchLen = len > 65557 ? 65557 : len;
      await raf.setPosition(len - searchLen);
      final tail = await raf.read(searchLen);

      int eocdOffset = -1;
      for (int i = tail.length - 22; i >= 0; i--) {
        if (tail[i] == 0x50 &&
            tail[i + 1] == 0x4b &&
            tail[i + 2] == 0x05 &&
            tail[i + 3] == 0x06) {
          eocdOffset = len - searchLen + i;
          break;
        }
      }

      if (eocdOffset == -1) return abis;

      await raf.setPosition(eocdOffset);
      final eocd = await raf.read(22);
      final bd = ByteData.sublistView(eocd);
      final totalEntries = bd.getUint16(10, Endian.little);
      final cdOffset = bd.getUint32(16, Endian.little);

      await raf.setPosition(cdOffset);
      for (int i = 0; i < totalEntries; i++) {
        final header = await raf.read(46);
        if (header.length < 46) break;
        final hbd = ByteData.sublistView(header);
        final fnLen = hbd.getUint16(28, Endian.little);
        final efLen = hbd.getUint16(30, Endian.little);
        final fcLen = hbd.getUint16(32, Endian.little);

        final fnBytes = await raf.read(fnLen);
        final fn = String.fromCharCodes(fnBytes);
        if (fn.startsWith('lib/')) {
          final parts = fn.split('/');
          if (parts.length > 1 && parts[1].isNotEmpty) {
            abis.add(parts[1]);
          }
        }

        if (efLen + fcLen > 0) {
          await raf.setPosition(await raf.position() + efLen + fcLen);
        }
      }
    } catch (_) {
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
    return abis;
  }

  /// Infiere versión tolerante a 2 o 3 números (ej. v9.35_atp.apk -> 9.35.0, v9.37.0 -> 9.37.0)
  _VersionMeta _inferVersionFromName(String fileName) =>
      _inferVersionFromNameStatic(fileName);

  static _VersionMeta _inferVersionFromNameStatic(String fileName) {
    final clean = fileName.toLowerCase();
    final match = RegExp(r'(?:v)?(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(clean);
    if (match != null) {
      final major = match.group(1)!;
      final minor = match.group(2)!;
      final patch = match.group(3) ?? '0';
      return _VersionMeta(
          versionName: '$major.$minor.$patch', versionCode: null);
    }
    return const _VersionMeta(versionName: null, versionCode: null);
  }

  /// Parsea la salida oficial de aapt2 dump badging
  _AaptBadgingResult _parseAapt2Badging(String badgingOutput) {
    String? packageName;
    String? versionName;
    int? versionCode;
    String? minSdk;
    String? targetSdk;

    final pkgMatch =
        RegExp(r"package:\s*name='([^']+)'").firstMatch(badgingOutput);
    if (pkgMatch != null) packageName = pkgMatch.group(1);

    final vcMatch = RegExp(r"versionCode='(\d+)'").firstMatch(badgingOutput);
    if (vcMatch != null) versionCode = int.tryParse(vcMatch.group(1)!);

    final vnMatch = RegExp(r"versionName='([^']+)'").firstMatch(badgingOutput);
    if (vnMatch != null) versionName = vnMatch.group(1);

    final minSdkMatch = RegExp(r"(?:minSdkVersion|sdkVersion):\s*'([^']+)'")
        .firstMatch(badgingOutput);
    if (minSdkMatch != null) minSdk = minSdkMatch.group(1);

    final targetSdkMatch =
        RegExp(r"(?:targetSdkVersion|targetSdk):\s*'([^']+)'")
            .firstMatch(badgingOutput);
    if (targetSdkMatch != null) targetSdk = targetSdkMatch.group(1);

    return _AaptBadgingResult(
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      minSdk: minSdk,
      targetSdk: targetSdk,
    );
  }

  /// Parsea la salida oficial de apksigner verify --verbose --print-certs
  /// Compatible con Build-Tools <= 36 (`Signer #1 certificate ...`) y 37+ (`V2 Signer: certificate ...`),
  /// excluyendo líneas de `SourceStamp`.
  _ApkSignerResult _parseApksignerOutput(String output) {
    final shaLineRegex = RegExp(
      r'^(?:V\d+(?:\.\d+)?\s+Signer:|Signer\s*#\d+)\s*certificate\s+SHA-256\s+digest:\s*([0-9a-fA-F:]+)',
      caseSensitive: false,
    );
    final dnLineRegex = RegExp(
      r'^(?:V\d+(?:\.\d+)?\s+Signer:|Signer\s*#\d+)\s*certificate\s+DN:\s*(.+)',
      caseSensitive: false,
    );

    final extracted = <_ApkSignerResult>[];
    String? currentDn;
    String? firstDn;

    for (final rawLine in LineSplitter.split(output)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.toLowerCase().contains('sourcestamp')) continue;

      final dnMatch = dnLineRegex.firstMatch(line);
      if (dnMatch != null) {
        currentDn = dnMatch.group(1)!.trim();
        firstDn ??= currentDn;
        continue;
      }

      final shaMatch = shaLineRegex.firstMatch(line);
      if (shaMatch != null) {
        final normalizedSha =
            shaMatch.group(1)!.replaceAll(':', '').trim().toLowerCase();
        extracted.add(_ApkSignerResult(
          signerSha256: normalizedSha,
          signerDn: currentDn,
        ));
      }
    }

    if (extracted.isEmpty) {
      return _ApkSignerResult(signerSha256: null, signerDn: firstDn);
    }

    for (final entry in extracted) {
      if (entry.signerSha256 == officialSignerSha256.toLowerCase()) {
        return entry;
      }
    }
    return extracted.first;
  }

  /// Lee de forma segura (UTF-8 con tolerancia BOM/caracteres) notas compañeras de versión:
  /// - `suggested_changelog`: `*_cambios.txt` / `*_changelog.txt`
  /// - `suggested_internal_notes`: `*_atp.txt` / `<apkBase>.txt` (excluyendo `_cambios`/`_changelog`)
  Future<Map<String, dynamic>> readCompanionNotesForVersion(
    String versionName, {
    String? apkPath,
    String? apkLibraryDir,
    List<Object> extraSearchDirs = const [],
    bool fallbackRegistryChangelog = false,
  }) async {
    final searchDirs = <Directory>[];
    final seenDirs = <String>{};

    void addDir(Directory d) {
      final canon = canonicalizePath(d.path);
      final key = Platform.isWindows ? canon.toLowerCase() : canon;
      if (canon.isNotEmpty && seenDirs.add(key)) {
        searchDirs.add(Directory(canon));
      }
    }

    String? apkBaseName;
    if (apkPath != null && apkPath.trim().isNotEmpty) {
      final f = File(canonicalizePath(apkPath));
      addDir(f.parent);
      if (f.uri.pathSegments.isNotEmpty) {
        apkBaseName = f.uri.pathSegments.last
            .replaceAll(RegExp(r'\.apk$', caseSensitive: false), '');
      }
    }
    for (final entry in extraSearchDirs) {
      if (entry is Directory) {
        addDir(entry);
      } else if (entry is String && entry.trim().isNotEmpty) {
        addDir(Directory(entry.trim()));
      }
    }
    if (apkLibraryDir != null && apkLibraryDir.trim().isNotEmpty) {
      addDir(Directory(apkLibraryDir));
    }

    // Incluir subcarpetas inmediatas (nivel 1 acotado) para carpetas organizadas por versión
    final baseDirsSnapshot = List<Directory>.from(searchDirs);
    for (final baseDir in baseDirsSnapshot) {
      if (!baseDir.existsSync()) continue;
      try {
        int subCount = 0;
        for (final entity in baseDir.listSync(followLinks: false)) {
          if (subCount >= 30) break;
          if (entity is Directory) {
            final segs =
                entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
            final name = segs.isNotEmpty ? segs.last.toLowerCase() : '';
            if (name.isNotEmpty &&
                !name.startsWith('.') &&
                !ignoredScanDirNames.contains(name)) {
              addDir(entity);
              subCount++;
            }
          }
        }
      } catch (_) {}
    }

    final cleanVer = versionName.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final shortVer = cleanVer.replaceFirst(RegExp(r'\.0$'), '');
    final verTags = <String>[
      if (cleanVer.isNotEmpty) cleanVer,
      if (shortVer.isNotEmpty && shortVer != cleanVer) shortVer,
    ];

    Future<String?> safeReadTxt(File f) async {
      if (!await f.exists()) return null;
      try {
        final bytes = await f.readAsBytes();
        final decoded = utf8.decode(bytes, allowMalformed: true);
        final cleaned = decoded.replaceFirst('\uFEFF', '').trim();
        return cleaned.isEmpty ? null : cleaned;
      } catch (_) {
        return null;
      }
    }

    String changelog = '';
    String? changelogSource;
    final changelogNames = <String>[
      if (apkBaseName != null && apkBaseName.isNotEmpty) ...[
        '${apkBaseName}_cambios.txt',
        '${apkBaseName.replaceAll('_atp', '')}_cambios.txt',
        '${apkBaseName.replaceAll('_atp', '')}_atp_cambios.txt',
      ],
      for (final tag in verTags) ...[
        'mochilalista_v${tag}_atp_cambios.txt',
        'mochilalista_v${tag}_cambios.txt',
        'mochilalista_v${tag}_changelog.txt',
        '${tag}_cambios.txt',
      ],
    ];

    outerChangelog:
    for (final dir in searchDirs) {
      for (final name in changelogNames) {
        final candidate =
            File(canonicalizePath('${dir.path}${Platform.pathSeparator}$name'));
        final text = await safeReadTxt(candidate);
        if (text != null) {
          changelog = text;
          changelogSource = candidate.path;
          break outerChangelog;
        }
      }
    }

    if (changelog.isEmpty && fallbackRegistryChangelog) {
      try {
        final registryFile =
            File('../app_movil/lib/core/config/app_changelog_registry.dart');
        if (await registryFile.exists()) {
          final content = await registryFile.readAsString();
          final matches = RegExp(
            r'title:\s*["\x27](.+?)["\x27],\s*description:\s*["\x27](.+?)["\x27]',
            dotAll: true,
          ).allMatches(content);

          final bullets = <String>[];
          for (final m in matches) {
            final title = m.group(1)?.trim() ?? '';
            final desc =
                m.group(2)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
            if (title.isNotEmpty) {
              bullets.add('• $title: $desc');
            }
            if (bullets.length >= 4) break;
          }
          if (bullets.isNotEmpty) {
            changelog = bullets.join('\n');
          }
        }
      } catch (_) {}
    }

    String internalNotes = '';
    String? internalNotesSource;
    final notesNames = <String>[
      if (apkBaseName != null && apkBaseName.isNotEmpty) ...[
        '$apkBaseName.txt',
        '${apkBaseName.replaceAll('_atp', '')}_atp.txt',
      ],
      for (final tag in verTags) ...[
        'mochilalista_v${tag}_atp.txt',
        'mochilalista_v$tag.txt',
      ],
    ];

    outerNotes:
    for (final dir in searchDirs) {
      for (final name in notesNames) {
        final lower = name.toLowerCase();
        if (lower.endsWith('_cambios.txt') ||
            lower.endsWith('_changelog.txt')) {
          continue;
        }
        final candidate =
            File(canonicalizePath('${dir.path}${Platform.pathSeparator}$name'));
        final text = await safeReadTxt(candidate);
        if (text != null) {
          internalNotes = text;
          internalNotesSource = candidate.path;
          break outerNotes;
        }
      }
    }

    return {
      'ok': true,
      'version_name': versionName,
      'suggested_changelog': changelog,
      'suggested_internal_notes': internalNotes,
      if (changelogSource != null) 'changelog_source': changelogSource,
      if (internalNotesSource != null)
        'internal_notes_source': internalNotesSource,
    };
  }

  /// Infiere la versión de esquema SQLite buscando en local_db.dart / database_helper.dart en app_movil
  Future<int> _inferDbSchemaVersion() async {
    final candidateFiles = [
      File('../app_movil/lib/core/database/local_db.dart'),
      File('../app_movil/lib/core/database/database_helper.dart'),
      File('../app_movil/lib/core/utils/backup_manager.dart'),
    ];

    for (final f in candidateFiles) {
      if (await f.exists()) {
        try {
          final content = await f.readAsString();
          final match = RegExp(r'(?:version|schema_version)\s*[:=]\s*(\d+)')
              .firstMatch(content);
          if (match != null) {
            return int.tryParse(match.group(1)!) ?? 36;
          }
        } catch (_) {}
      }
    }
    return 36;
  }

  /// Lee versión y código de build de app_movil/pubspec.yaml
  Future<_VersionMeta> _readPubspecVersion() async {
    final pubspec = File('../app_movil/pubspec.yaml');
    if (await pubspec.exists()) {
      try {
        final lines = await pubspec.readAsLines();
        for (final line in lines) {
          if (line.trim().startsWith('version:')) {
            final vPart = line.replaceFirst('version:', '').trim();
            final parts = vPart.split('+');
            final vName = parts.isNotEmpty ? parts[0] : '9.40.0';
            final vCode = parts.length > 1 ? int.tryParse(parts[1]) ?? 84 : 84;
            return _VersionMeta(versionName: vName, versionCode: vCode);
          }
        }
      } catch (_) {}
    }
    return const _VersionMeta(versionName: '9.40.0', versionCode: 84);
  }

  /// Compara nombres de carpetas de build-tools numéricamente (ej. 37.0.0 > 36.1.0)
  int _compareVersionFolderNames(String a, String b) {
    final nameA = a.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
    final nameB = b.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
    final partsA = nameA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = nameB.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return nameA.compareTo(nameB);
  }

  /// Ubica la herramienta especificada (aapt2 o apksigner) en build-tools de Android SDK
  Future<String?> _findBuildTool(String toolName) async {
    final isWindows = Platform.isWindows;
    final exeName = isWindows
        ? (toolName == 'apksigner' ? '$toolName.bat' : '$toolName.exe')
        : toolName;

    // Raíces configuradas o por variables de entorno
    final rawRoots = sdkSearchRootsOverride ??
        [
          if (Platform.environment['ANDROID_HOME'] != null)
            '${Platform.environment['ANDROID_HOME']}${Platform.pathSeparator}build-tools',
          if (Platform.environment['ANDROID_SDK_ROOT'] != null)
            '${Platform.environment['ANDROID_SDK_ROOT']}${Platform.pathSeparator}build-tools',
          if (isWindows && Platform.environment['LOCALAPPDATA'] != null)
            '${Platform.environment['LOCALAPPDATA']}\\Android\\Sdk\\build-tools',
        ];

    for (final rawRoot in rawRoots) {
      final dir = Directory(canonicalizePath(rawRoot));
      if (await dir.exists()) {
        try {
          final entries = dir.listSync().whereType<Directory>().toList();
          // Ordenar descendente numéricamente (37.0.0 > 36.1.0)
          entries.sort((a, b) => _compareVersionFolderNames(b.path, a.path));

          for (final verDir in entries) {
            final candidatePath = canonicalizePath(
                '${verDir.path}${Platform.pathSeparator}$exeName');
            final toolFile = File(candidatePath);
            if (await toolFile.exists()) {
              return canonicalizePath(toolFile.path);
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Ejecución protegida de procesos con timeout estricto de 15 segundos
  Future<ProcessResult> _runProcess(
      String executable, List<String> args) async {
    try {
      if (processRunnerOverride != null) {
        return await processRunnerOverride!(executable, args);
      }
      return await Process.run(
        executable,
        args,
        runInShell: Platform.isWindows && executable.endsWith('.bat'),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      return ProcessResult(-1, -1, '', 'Error ejecutando $executable: $e');
    }
  }
}

class _ApkCandidate {
  final File file;
  final String sourceLabel;
  final String rootPath;
  final DateTime modified;
  final int priority;
  final String? inferredVersion;

  _ApkCandidate({
    required this.file,
    required this.sourceLabel,
    required this.rootPath,
    required this.modified,
    this.priority = 1,
    this.inferredVersion,
  });
}

class _DirQueueItem {
  final Directory dir;
  final int depth;

  const _DirQueueItem(this.dir, this.depth);
}

class _DirScanResult {
  final String canonicalPath;
  final bool exists;
  final bool readable;
  final List<_ApkCandidate> candidates;

  const _DirScanResult({
    required this.canonicalPath,
    required this.exists,
    required this.readable,
    required this.candidates,
  });
}

class _InspectedCandidateItem {
  final ApkInspectionResult result;
  final int priority;

  const _InspectedCandidateItem(this.result, this.priority);
}

class _VersionMeta {
  final String? versionName;
  final int? versionCode;

  const _VersionMeta({this.versionName, this.versionCode});
}

class _AaptBadgingResult {
  final String? packageName;
  final String? versionName;
  final int? versionCode;
  final String? minSdk;
  final String? targetSdk;

  const _AaptBadgingResult({
    this.packageName,
    this.versionName,
    this.versionCode,
    this.minSdk,
    this.targetSdk,
  });
}

class _ApkSignerResult {
  final String? signerSha256;
  final String? signerDn;

  const _ApkSignerResult({this.signerSha256, this.signerDn});
}

class _CachedApkMetadata {
  final int sizeBytes;
  final int modifiedMicros;
  final String sizeMb;
  final String sha256;
  final String? packageName;
  final String? versionName;
  final int? versionCode;
  final String abiVariant;
  final int dbSchemaVersion;
  final String minRequiredVersion;
  final String? minSdk;
  final String? targetSdk;
  final bool? signatureVerified;
  final String signatureStatus;
  final String? signatureDetail;
  final String? signerSha256;
  final String? signerDn;
  final String suggestedReleaseType;

  const _CachedApkMetadata({
    required this.sizeBytes,
    required this.modifiedMicros,
    required this.sizeMb,
    required this.sha256,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.abiVariant,
    required this.dbSchemaVersion,
    required this.minRequiredVersion,
    required this.minSdk,
    required this.targetSdk,
    required this.signatureVerified,
    required this.signatureStatus,
    required this.signatureDetail,
    required this.signerSha256,
    required this.signerDn,
    required this.suggestedReleaseType,
  });
}
