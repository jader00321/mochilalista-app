import 'dart:convert';
import 'dart:io';

import '../core/path_security.dart';
import 'apk_directory_scanner.dart';

class ApkVersionMeta {
  final String? versionName;
  final int? versionCode;

  const ApkVersionMeta({this.versionName, this.versionCode});
}

class ApkBatchNotesContext {
  final Map<String, Map<String, File>> dirTxtByDirKey = {};
  final Map<String, List<Directory>> subDirsByBaseKey = {};
  int? dbSchemaVersion;
  bool registryFallbackChecked = false;
  String registryFallbackChangelog = '';
  String? resolvedAapt2;
  bool resolvedAapt2Checked = false;
  String? resolvedApksigner;
  bool resolvedApksignerChecked = false;
}

/// Lector de notas compañeras (`*_atp.txt` / `*_cambios.txt`) y metadatos de `app_movil`.
class ApkCompanionNotesReader {
  ApkCompanionNotesReader._();

  /// Lee de forma segura (UTF-8 con tolerancia BOM) notas compañeras de versión siempre vivas.
  static Future<Map<String, dynamic>> readCompanionNotes(
    String versionName, {
    String? apkPath,
    String? apkLibraryDir,
    List<Object> extraSearchDirs = const [],
    bool fallbackRegistryChangelog = false,
    ApkBatchNotesContext? batchContext,
  }) async {
    final baseDirs = <Directory>[];
    final seenBaseKeys = <String>{};

    void addBaseDir(Directory d) {
      final canon = PathSecurity.canonicalizePath(d.path);
      final key = PathSecurity.cacheKeyForPath(canon);
      if (canon.isNotEmpty && seenBaseKeys.add(key)) {
        baseDirs.add(Directory(canon));
      }
    }

    String? apkBaseName;
    if (apkPath != null && apkPath.trim().isNotEmpty) {
      final f = File(PathSecurity.canonicalizePath(apkPath));
      addBaseDir(f.parent);
      if (f.uri.pathSegments.isNotEmpty) {
        apkBaseName = f.uri.pathSegments.last
            .replaceAll(RegExp(r'\.apk$', caseSensitive: false), '');
      }
    }
    for (final entry in extraSearchDirs) {
      if (entry is Directory) {
        addBaseDir(entry);
      } else if (entry is String && entry.trim().isNotEmpty) {
        addBaseDir(Directory(entry.trim()));
      }
    }
    if (apkLibraryDir != null && apkLibraryDir.trim().isNotEmpty) {
      addBaseDir(Directory(apkLibraryDir));
    }

    final dirTxtIndex =
        batchContext?.dirTxtByDirKey ?? <String, Map<String, File>>{};
    final subDirsByBase =
        batchContext?.subDirsByBaseKey ?? <String, List<Directory>>{};

    Map<String, File> ensureTxtIndex(Directory dir) {
      final dirKey =
          PathSecurity.cacheKeyForPath(PathSecurity.canonicalizePath(dir.path));
      final existing = dirTxtIndex[dirKey];
      if (existing != null) return existing;

      final txtFiles = <String, File>{};
      final immediateSubs = <Directory>[];
      if (dir.existsSync()) {
        try {
          int subCount = 0;
          for (final entity in dir.listSync(followLinks: false)) {
            if (entity is File) {
              final segs =
                  entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
              final fname = segs.isNotEmpty ? segs.last : '';
              if (fname.toLowerCase().endsWith('.txt')) {
                txtFiles[fname.toLowerCase()] = entity;
              }
            } else if (entity is Directory && subCount < 30) {
              final segs =
                  entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
              final name = segs.isNotEmpty ? segs.last.toLowerCase() : '';
              if (name.isNotEmpty &&
                  !name.startsWith('.') &&
                  !ApkDirectoryScanner.ignoredScanDirNames.contains(name)) {
                immediateSubs
                    .add(Directory(PathSecurity.canonicalizePath(entity.path)));
                subCount++;
              }
            }
          }
        } catch (_) {}
      }
      dirTxtIndex[dirKey] = txtFiles;
      subDirsByBase[dirKey] = immediateSubs;
      return txtFiles;
    }

    final searchDirs = <Directory>[];
    final seenSearchKeys = <String>{};
    void addSearchDir(Directory d) {
      final canon = PathSecurity.canonicalizePath(d.path);
      final k = PathSecurity.cacheKeyForPath(canon);
      if (canon.isNotEmpty && seenSearchKeys.add(k)) {
        searchDirs.add(Directory(canon));
      }
    }

    for (final baseDir in baseDirs) {
      addSearchDir(baseDir);
      ensureTxtIndex(baseDir);
      final baseKey = PathSecurity.cacheKeyForPath(
          PathSecurity.canonicalizePath(baseDir.path));
      for (final sub in subDirsByBase[baseKey] ?? const <Directory>[]) {
        addSearchDir(sub);
      }
    }

    final cleanVer = versionName.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final shortVer = cleanVer.replaceFirst(RegExp(r'\.0$'), '');
    final verTags = <String>[
      if (cleanVer.isNotEmpty) cleanVer,
      if (shortVer.isNotEmpty && shortVer != cleanVer) shortVer,
    ];

    Future<String?> safeReadTxt(File f) async {
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
      final txtMap = ensureTxtIndex(dir);
      if (txtMap.isEmpty) continue;
      for (final name in changelogNames) {
        final candidate = txtMap[name.toLowerCase()];
        if (candidate == null) continue;
        final text = await safeReadTxt(candidate);
        if (text != null) {
          changelog = text;
          changelogSource = candidate.path;
          break outerChangelog;
        }
      }
    }

    if (changelog.isEmpty && fallbackRegistryChangelog) {
      if (batchContext != null && batchContext.registryFallbackChecked) {
        changelog = batchContext.registryFallbackChangelog;
      } else {
        String fallbackVal = '';
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
              fallbackVal = bullets.join('\n');
            }
          }
        } catch (_) {}
        if (batchContext != null) {
          batchContext.registryFallbackChecked = true;
          batchContext.registryFallbackChangelog = fallbackVal;
        }
        changelog = fallbackVal;
      }
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
      final txtMap = ensureTxtIndex(dir);
      if (txtMap.isEmpty) continue;
      for (final name in notesNames) {
        final lower = name.toLowerCase();
        if (lower.endsWith('_cambios.txt') ||
            lower.endsWith('_changelog.txt')) {
          continue;
        }
        final candidate = txtMap[lower];
        if (candidate == null) continue;
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

  /// Infiere la versión de esquema SQLite buscando en `app_movil/`.
  static Future<int> inferDbSchemaVersion() async {
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

  /// Lee versión y código de build de `app_movil/pubspec.yaml`.
  static Future<ApkVersionMeta> readPubspecVersion() async {
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
            return ApkVersionMeta(versionName: vName, versionCode: vCode);
          }
        }
      } catch (_) {}
    }
    return const ApkVersionMeta(versionName: '9.40.0', versionCode: 84);
  }
}
