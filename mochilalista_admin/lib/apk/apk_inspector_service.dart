import 'dart:io';

import 'package:crypto/crypto.dart';

import '../core/commercial_constants.dart';
import '../core/path_security.dart';
import '../core/semver_utils.dart';
import 'apk_binary_tools.dart';
import 'apk_cache_store.dart';
import 'apk_directory_scanner.dart';
import 'apk_models.dart';

export 'apk_models.dart';

/// Servicio de Inspección Forense de APKs, Extracción Determinista y Escudo Anti-debug.apk.
class ApkInspectorService {
  /// Huella SHA-256 oficial del certificado comercial de Julio Angello Vasquez Navarro.
  static const String officialSignerSha256 =
      CommercialConstants.officialSignerSha256;

  static const int cacheVersion = ApkCacheStore.cacheVersion;
  static const int maxDiskCacheEntries = ApkCacheStore.maxDiskCacheEntries;
  static const Set<String> ignoredScanDirNames =
      ApkDirectoryScanner.ignoredScanDirNames;

  /// Inyección mockeable de ejecutor de procesos para pruebas unitarias.
  final Future<ProcessResult> Function(
      String executable, List<String> arguments)? processRunnerOverride;

  /// Inyección de raíces de búsqueda de SDK para pruebas unitarias.
  final List<String>? sdkSearchRootsOverride;

  /// Directorio opcional de compilación local (anula `../app_movil/build/...`).
  final Directory? defaultBuildOutputDir;

  /// Ruta opcional del archivo JSON de caché persistente en disco.
  final String? cacheFilePath;

  final ApkCacheStore _cacheStore;

  ApkInspectorService({
    this.processRunnerOverride,
    this.sdkSearchRootsOverride,
    this.defaultBuildOutputDir,
    this.cacheFilePath,
  }) : _cacheStore = ApkCacheStore(cacheFilePath: cacheFilePath);

  void clearInspectionCache() => _cacheStore.clear();

  int get liveCacheCount => _cacheStore.liveCount;

  Future<void> loadDiskCache({bool force = false}) =>
      _cacheStore.loadDiskCache(force: force);

  static String canonicalizePath(String rawPath) =>
      PathSecurity.canonicalizePath(rawPath);

  static String inferReleaseTypeFromVersion(String? versionName) =>
      SemVerUtils.inferReleaseTypeFromVersion(versionName);

  static int compareSemVer(String? a, String? b) => SemVerUtils.compare(a, b);

  static Map<String, dynamic> probeSearchDirStats(
    ApkSearchDirConfig dirCfg, {
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
  }) =>
      ApkDirectoryScanner.probeSearchDirStats(
        dirCfg,
        maxDepth: maxDepth,
        maxEntriesPerRoot: maxEntriesPerRoot,
      );

  /// Inspecciona exhaustivamente un archivo APK combinando Dart puro y herramientas Android SDK.
  Future<ApkInspectionResult> inspectApk(
    File apkFile, {
    String? sourceLabel,
    String? apkLibraryDir,
    List<Object> extraSearchDirs = const [],
    bool forceRefresh = false,
  }) =>
      _inspectApkInternal(
        apkFile,
        sourceLabel: sourceLabel,
        apkLibraryDir: apkLibraryDir,
        extraSearchDirs: extraSearchDirs,
        forceRefresh: forceRefresh,
      );

  Future<ApkInspectionResult> _inspectApkInternal(
    File apkFile, {
    String? sourceLabel,
    String? apkLibraryDir,
    List<Object> extraSearchDirs = const [],
    bool forceRefresh = false,
    ApkBatchNotesContext? batchContext,
  }) async {
    if (!_cacheStore.diskCacheLoaded && _cacheStore.hasDiskBacking) {
      await _cacheStore.loadDiskCache();
    }

    final canonicalApkPath = canonicalizePath(apkFile.path);
    final canonicalFile = File(canonicalApkPath);
    final cacheKey = PathSecurity.cacheKeyForPath(canonicalApkPath);

    if (!await canonicalFile.exists()) {
      final removed = _cacheStore.remove(cacheKey);
      if (removed != null && _cacheStore.hasDiskBacking) {
        await _cacheStore.persistDiskCache();
      }
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

    Future<ApkInspectionResult> materializeWithNotes(
      CachedApkMetadata meta,
    ) async {
      final notes = await ApkDirectoryScanner.readCompanionNotes(
        meta.versionName ?? '',
        apkPath: canonicalApkPath,
        apkLibraryDir: apkLibraryDir,
        extraSearchDirs: extraSearchDirs,
        fallbackRegistryChangelog: true,
        batchContext: batchContext,
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

    if (!forceRefresh) {
      final cachedMeta = _cacheStore.getFresh(
        cacheKey,
        sizeBytes: stat.size,
        modifiedMicros: modifiedMicros,
      );
      if (cachedMeta != null) {
        return materializeWithNotes(cachedMeta);
      }
    }

    // 1. Capa 1: Tamaño y Hash Criptográfico SHA-256 determinista
    final fileLength = await canonicalFile.length();
    final sha256Digest = (await sha256.bind(canonicalFile.openRead()).first)
        .toString()
        .toLowerCase();
    final sizeMb = (fileLength / (1024 * 1024)).toStringAsFixed(2);
    final sizeMbStr = '$sizeMb MB';

    // 2. Capa 1: Detección ABI determinista en Dart puro inspeccionando el ZIP
    final detectedAbis = await ApkBinaryTools.detectZipAbis(canonicalFile);
    final isArm64Only =
        detectedAbis.length == 1 && detectedAbis.contains('arm64-v8a');
    final abiVariant = isArm64Only ? 'ARM64' : 'UNIVERSAL';

    final nameInference = ApkDirectoryScanner.inferVersionFromName(fileName);

    final dbSchemaVersion = batchContext?.dbSchemaVersion ??
        await ApkDirectoryScanner.inferDbSchemaVersion();
    if (batchContext != null) {
      batchContext.dbSchemaVersion ??= dbSchemaVersion;
    }

    // 3. Capa 2: Extracción profunda con aapt2 si está disponible
    String? packageName;
    String? versionName = nameInference.versionName;
    int? versionCode = nameInference.versionCode;
    String? minSdk;
    String? targetSdk;

    final aapt2Exe = await _resolveBuildToolCached('aapt2', batchContext);
    if (aapt2Exe != null) {
      final aaptRes = await ApkBinaryTools.runProcess(
        aapt2Exe,
        ['dump', 'badging', canonicalApkPath],
        processRunnerOverride: processRunnerOverride,
      );
      if (aaptRes.exitCode == 0) {
        final parsed = ApkBinaryTools.parseAapt2Badging(
          aaptRes.stdout.toString(),
        );
        if (parsed.packageName != null) packageName = parsed.packageName;
        if (parsed.versionName != null) versionName = parsed.versionName;
        if (parsed.versionCode != null) versionCode = parsed.versionCode;
        if (parsed.minSdk != null) minSdk = parsed.minSdk;
        if (parsed.targetSdk != null) targetSdk = parsed.targetSdk;
      }
    }

    if (versionName == null || versionCode == null) {
      final pubspecMeta = await ApkDirectoryScanner.readPubspecVersion();
      versionName ??= pubspecMeta.versionName;
      versionCode ??= pubspecMeta.versionCode;
    }

    // 4. Capa 3: Escudo Anti-debug.apk con apksigner (SDK <=36 y 37+)
    bool? signatureVerified;
    String signatureStatus = 'UNVERIFIED';
    String? signatureDetail;
    String? signerSha256;
    String? signerDn;

    final apksignerBin =
        await _resolveBuildToolCached('apksigner', batchContext);
    if (apksignerBin == null) {
      signatureVerified = null;
      signatureStatus = 'UNVERIFIED';
      signatureDetail = 'apksigner no disponible en el SDK de Android.';
    } else {
      final apkSignerRes = await ApkBinaryTools.runProcess(
        apksignerBin,
        ['verify', '--verbose', '--print-certs', canonicalApkPath],
        processRunnerOverride: processRunnerOverride,
      );
      if (apkSignerRes.exitCode == 0) {
        final out = '${apkSignerRes.stdout}\n${apkSignerRes.stderr}';
        final parsedSig = ApkBinaryTools.parseApksignerOutput(
          out,
          officialSignerSha256: officialSignerSha256,
        );
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

    final meta = CachedApkMetadata(
      canonicalPath: canonicalApkPath,
      sizeBytes: fileLength,
      modifiedMicros: modifiedMicros,
      inspectedAt: DateTime.now().toUtc().toIso8601String(),
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
    _cacheStore.put(cacheKey, meta);
    if (_cacheStore.hasDiskBacking) {
      await _cacheStore.persistDiskCache();
    }

    return materializeWithNotes(meta);
  }

  Future<String?> _resolveBuildToolCached(
    String toolName,
    ApkBatchNotesContext? batchContext,
  ) async {
    if (batchContext == null) {
      return ApkBinaryTools.findBuildTool(
        toolName,
        sdkSearchRootsOverride: sdkSearchRootsOverride,
      );
    }
    if (toolName == 'aapt2') {
      if (!batchContext.resolvedAapt2Checked) {
        batchContext.resolvedAapt2 = await ApkBinaryTools.findBuildTool(
          'aapt2',
          sdkSearchRootsOverride: sdkSearchRootsOverride,
        );
        batchContext.resolvedAapt2Checked = true;
      }
      return batchContext.resolvedAapt2;
    }
    if (!batchContext.resolvedApksignerChecked) {
      batchContext.resolvedApksigner = await ApkBinaryTools.findBuildTool(
        'apksigner',
        sdkSearchRootsOverride: sdkSearchRootsOverride,
      );
      batchContext.resolvedApksignerChecked = true;
    }
    return batchContext.resolvedApksigner;
  }

  /// Escanea rutas configuradas, deduplica por SHA-256 y ordena con ranking híbrido.
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
    if (!_cacheStore.diskCacheLoaded && _cacheStore.hasDiskBacking) {
      await _cacheStore.loadDiskCache();
    }
    final batchContext = ApkBatchNotesContext();

    final effectiveLimit = (limit ?? maxCandidates).clamp(1, 200);
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

    final selection = ApkDirectoryScanner.collectBalancedCandidates(
      configuredDirs,
      effectiveLimit: effectiveLimit,
      maxDepth: maxDepth,
      maxEntriesPerRoot: maxEntriesPerRoot,
    );

    final libPath = canonicalizePath(
      apkLibraryDir?.path ??
          configuredDirs
              .firstWhere(
                (d) => d.kind == 'official_library',
                orElse: () => configuredDirs.first,
              )
              .path,
    );

    final uniqueItems = <InspectedCandidateItem>[];
    final indexBySha = <String, int>{};

    for (final c in selection.selectedCandidates) {
      final res = await _inspectApkInternal(
        c.file,
        sourceLabel: c.sourceLabel,
        apkLibraryDir: libPath,
        extraSearchDirs: selection.activeSearchDirPaths,
        batchContext: batchContext,
      );
      if (res.sha256.isEmpty) {
        uniqueItems.add(InspectedCandidateItem(res, c.priority));
        continue;
      }

      final existingIdx = indexBySha[res.sha256];
      if (existingIdx == null) {
        indexBySha[res.sha256] = uniqueItems.length;
        uniqueItems.add(InspectedCandidateItem(res, c.priority));
      } else {
        final existingItem = uniqueItems[existingIdx];
        if (c.priority < existingItem.priority) {
          final mergedDups = <String>[
            ...existingItem.result.duplicatePaths,
            existingItem.result.filePath,
          ];
          uniqueItems[existingIdx] = InspectedCandidateItem(
            res.copyWith(duplicatePaths: mergedDups),
            c.priority,
          );
        } else {
          final mergedDups = <String>[
            ...existingItem.result.duplicatePaths,
            res.filePath,
          ];
          uniqueItems[existingIdx] = InspectedCandidateItem(
            existingItem.result.copyWith(duplicatePaths: mergedDups),
            existingItem.priority,
          );
        }
      }
    }

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
      perDirStats: selection.perDirStats,
      totalUniqueFound: filtered.length,
      totalAllUnique: totalAllUnique,
      totalReturned: limited.length,
    );
  }

  /// Wrapper retrocompatible que retorna directamente la lista de resultados detectados.
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

  Future<Map<String, dynamic>> readCompanionNotesForVersion(
    String versionName, {
    String? apkPath,
    String? apkLibraryDir,
    List<Object> extraSearchDirs = const [],
    bool fallbackRegistryChangelog = false,
  }) =>
      ApkDirectoryScanner.readCompanionNotes(
        versionName,
        apkPath: apkPath,
        apkLibraryDir: apkLibraryDir,
        extraSearchDirs: extraSearchDirs,
        fallbackRegistryChangelog: fallbackRegistryChangelog,
      );
}
