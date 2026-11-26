import 'dart:io';

import '../core/path_security.dart';
import '../core/semver_utils.dart';
import 'apk_companion_notes_reader.dart';
import 'apk_models.dart';

export 'apk_companion_notes_reader.dart' show ApkBatchNotesContext, ApkVersionMeta;

class ApkScanCandidate {
  final File file;
  final String sourceLabel;
  final String rootPath;
  final DateTime modified;
  final int priority;
  final String? inferredVersion;

  ApkScanCandidate({
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

class ApkDirScanResult {
  final String canonicalPath;
  final bool exists;
  final bool readable;
  final List<ApkScanCandidate> candidates;

  const ApkDirScanResult({
    required this.canonicalPath,
    required this.exists,
    required this.readable,
    required this.candidates,
  });
}

class ApkCandidateSelection {
  final List<Map<String, dynamic>> perDirStats;
  final List<ApkScanCandidate> selectedCandidates;
  final List<String> activeSearchDirPaths;

  const ApkCandidateSelection({
    required this.perDirStats,
    required this.selectedCandidates,
    required this.activeSearchDirPaths,
  });
}

/// Escáner BFS acotado de directorios APK y lector de notas compañeras (`*_atp.txt` / `*_cambios.txt`).
class ApkDirectoryScanner {
  ApkDirectoryScanner._();

  /// Directorios pesados o sensibles excluidos durante el escaneo recursivo acotado.
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

  /// Infiere versión tolerante a 2 o 3 números (ej. `v9.35_atp.apk -> 9.35.0`).
  static ApkVersionMeta inferVersionFromName(String fileName) {
    final clean = fileName.toLowerCase();
    final match = RegExp(r'(?:v)?(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(clean);
    if (match != null) {
      final major = match.group(1)!;
      final minor = match.group(2)!;
      final patch = match.group(3) ?? '0';
      return ApkVersionMeta(
        versionName: '$major.$minor.$patch',
        versionCode: null,
      );
    }
    return const ApkVersionMeta(versionName: null, versionCode: null);
  }

  /// Sondea rápidamente una ruta de búsqueda (recursivo BFS acotado).
  static ApkDirScanResult scanDirectoryForApks(
    ApkSearchDirConfig dirCfg, {
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
  }) {
    final canonRoot = PathSecurity.canonicalizePath(dirCfg.path);
    final rootDir = Directory(canonRoot);
    if (canonRoot.isEmpty || !rootDir.existsSync()) {
      return ApkDirScanResult(
        canonicalPath: canonRoot,
        exists: false,
        readable: false,
        candidates: const [],
      );
    }

    final candidates = <ApkScanCandidate>[];
    final seenFiles = <String>{};
    final seenDirs = <String>{};
    bool readable = true;
    int visitedEntries = 0;

    seenDirs.add(PathSecurity.cacheKeyForPath(canonRoot));

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
            final canonFile = PathSecurity.canonicalizePath(entity.path);
            final key = PathSecurity.cacheKeyForPath(canonFile);
            if (seenFiles.add(key)) {
              final stat = File(canonFile).statSync();
              final fileName = File(canonFile).uri.pathSegments.isNotEmpty
                  ? File(canonFile).uri.pathSegments.last
                  : '';
              final inferred = inferVersionFromName(fileName);
              candidates.add(ApkScanCandidate(
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
            final canonSub = PathSecurity.canonicalizePath(entity.path);
            final dirKey = PathSecurity.cacheKeyForPath(canonSub);
            if (seenDirs.add(dirKey)) {
              queue.add(_DirQueueItem(Directory(canonSub), current.depth + 1));
            }
          } catch (_) {}
        }
      }
    }

    return ApkDirScanResult(
      canonicalPath: canonRoot,
      exists: true,
      readable: readable,
      candidates: candidates,
    );
  }

  /// Devuelve métricas rápidas (existencia, legibilidad y conteo `.apk`) de una carpeta.
  static Map<String, dynamic> probeSearchDirStats(
    ApkSearchDirConfig dirCfg, {
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
  }) {
    final scan = scanDirectoryForApks(
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

  /// Recolecta candidatos con cuota equilibrada entre rutas configuradas.
  static ApkCandidateSelection collectBalancedCandidates(
    List<ApkSearchDirConfig> configuredDirs, {
    required int effectiveLimit,
    int maxDepth = 3,
    int maxEntriesPerRoot = 1500,
  }) {
    final perDirStats = <Map<String, dynamic>>[];
    final perRootCandidates = <List<ApkScanCandidate>>[];
    final seenGlobalFiles = <String>{};
    final activeSearchDirPaths = <String>[];

    for (final dirCfg in configuredDirs) {
      final scan = scanDirectoryForApks(
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

      final rootList = <ApkScanCandidate>[];
      for (final cand in scan.candidates) {
        final fKey = PathSecurity.cacheKeyForPath(cand.file.path);
        if (seenGlobalFiles.add(fKey)) {
          rootList.add(cand);
        }
      }

      rootList.sort((a, b) {
        final cmpDate = b.modified.compareTo(a.modified);
        if (cmpDate != 0) return cmpDate;
        final cmpVer = SemVerUtils.compare(b.inferredVersion, a.inferredVersion);
        if (cmpVer != 0) return cmpVer;
        return a.priority.compareTo(b.priority);
      });
      if (rootList.isNotEmpty) {
        perRootCandidates.add(rootList);
      }
    }

    final inspectLimit = (effectiveLimit * 4).clamp(24, 200);
    final selectedCandidates = <ApkScanCandidate>[];
    final selectedKeys = <String>{};

    if (perRootCandidates.isNotEmpty) {
      final perRootQuota = (inspectLimit / perRootCandidates.length)
          .ceil()
          .clamp(4, inspectLimit);
      for (final rootList in perRootCandidates) {
        for (final c in rootList.take(perRootQuota)) {
          final k = PathSecurity.cacheKeyForPath(c.file.path);
          if (selectedKeys.add(k)) {
            selectedCandidates.add(c);
          }
        }
      }
    }

    final remaining = <ApkScanCandidate>[];
    for (final rootList in perRootCandidates) {
      for (final c in rootList) {
        final k = PathSecurity.cacheKeyForPath(c.file.path);
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
      final k = PathSecurity.cacheKeyForPath(c.file.path);
      if (selectedKeys.add(k)) {
        selectedCandidates.add(c);
      }
    }

    return ApkCandidateSelection(
      perDirStats: perDirStats,
      selectedCandidates: selectedCandidates,
      activeSearchDirPaths: activeSearchDirPaths,
    );
  }

  /// Lee de forma segura (UTF-8 con tolerancia BOM) notas compañeras de versión siempre vivas.
  static Future<Map<String, dynamic>> readCompanionNotes(
    String versionName, {
    String? apkPath,
    String? apkLibraryDir,
    List<Object> extraSearchDirs = const [],
    bool fallbackRegistryChangelog = false,
    ApkBatchNotesContext? batchContext,
  }) =>
      ApkCompanionNotesReader.readCompanionNotes(
        versionName,
        apkPath: apkPath,
        apkLibraryDir: apkLibraryDir,
        extraSearchDirs: extraSearchDirs,
        fallbackRegistryChangelog: fallbackRegistryChangelog,
        batchContext: batchContext,
      );

  /// Infiere la versión de esquema SQLite buscando en `app_movil/`.
  static Future<int> inferDbSchemaVersion() =>
      ApkCompanionNotesReader.inferDbSchemaVersion();

  /// Lee versión y código de build de `app_movil/pubspec.yaml`.
  static Future<ApkVersionMeta> readPubspecVersion() =>
      ApkCompanionNotesReader.readPubspecVersion();
}
