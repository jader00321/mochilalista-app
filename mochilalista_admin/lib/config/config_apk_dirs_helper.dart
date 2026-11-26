import 'dart:io';

import '../apk/apk_models.dart';
import '../core/path_security.dart';
import 'config_defaults.dart';

/// Excepción lanzada cuando el propietario intenta registrar una ruta prohibida o inválida.
class InvalidApkSearchDirException implements Exception {
  final String message;
  const InvalidApkSearchDirException(this.message);

  @override
  String toString() => message;
}

class ValidatedApkSearchDirs {
  final List<Map<String, dynamic>> entries;
  final String? syncedOfficialPath;

  const ValidatedApkSearchDirs({
    required this.entries,
    required this.syncedOfficialPath,
  });
}

/// Helper cohesivo para normalizar, deduplicar y validar rutas de búsqueda de APKs.
class ConfigApkDirsHelper {
  ConfigApkDirsHelper._();

  static List<ApkSearchDirConfig> resolveEffectiveSearchDirs({
    required dynamic rawList,
    required String apkLibraryDir,
    required String? defaultBuildOutputDir,
    required bool Function(String rawPath) isForbiddenDir,
  }) {
    if (rawList is! List || rawList.isEmpty) {
      return ConfigDefaults.buildDefaultApkSearchDirs(
        apkLibraryDir: apkLibraryDir,
        defaultBuildOutputDir: defaultBuildOutputDir,
      );
    }

    final parsed = <ApkSearchDirConfig>[];
    final seen = <String>{};

    for (final item in rawList) {
      final cfg = _parseRawSearchDirItem(item);
      if (cfg == null || cfg.path.isEmpty) continue;

      var normalized = cfg;
      if (normalized.kind == 'flutter_build' &&
          normalized.isDefault &&
          defaultBuildOutputDir != null &&
          defaultBuildOutputDir.trim().isNotEmpty) {
        normalized = normalized.copyWith(path: defaultBuildOutputDir.trim());
      }

      if (isForbiddenDir(normalized.path)) continue;

      final canon = PathSecurity.canonicalizePath(normalized.path);
      final key = PathSecurity.cacheKeyForPath(canon);
      if (seen.add(key)) {
        parsed.add(normalized);
      }
    }

    if (parsed.isEmpty) {
      return ConfigDefaults.buildDefaultApkSearchDirs(
        apkLibraryDir: apkLibraryDir,
        defaultBuildOutputDir: defaultBuildOutputDir,
      );
    }

    return parsed;
  }

  static ValidatedApkSearchDirs validateAndBuildSearchDirEntries({
    required List<dynamic> rawDirs,
    required bool Function(String rawPath) isForbiddenDir,
  }) {
    final cleanList = <Map<String, dynamic>>[];
    final seen = <String>{};
    String? syncedOfficialPath;

    for (final item in rawDirs) {
      final cfg = _parseRawSearchDirItem(item, allowEmptyString: true);
      if (cfg == null) continue;

      final trimmedPath = cfg.path.trim();
      if (trimmedPath.isEmpty) {
        throw const InvalidApkSearchDirException(
          'La ruta de búsqueda no puede estar vacía.',
        );
      }
      if (isForbiddenDir(trimmedPath)) {
        throw InvalidApkSearchDirException(
          'Ruta prohibida por seguridad o demasiado amplia: "$trimmedPath".',
        );
      }

      final storedPath = (cfg.kind == 'flutter_build' && cfg.isDefault)
          ? trimmedPath
          : PathSecurity.canonicalizePath(trimmedPath);
      final canonKeyRaw = PathSecurity.canonicalizePath(storedPath);
      final key = PathSecurity.cacheKeyForPath(canonKeyRaw);
      if (!seen.add(key)) continue;

      final normalizedCfg = cfg.copyWith(path: storedPath);
      if (normalizedCfg.kind == 'official_library' &&
          syncedOfficialPath == null) {
        syncedOfficialPath = normalizedCfg.path;
      }
      cleanList.add(normalizedCfg.toJson());
    }

    if (cleanList.isEmpty) {
      throw const InvalidApkSearchDirException(
        'Debe permanecer al menos una ruta de búsqueda válida.',
      );
    }

    return ValidatedApkSearchDirs(
      entries: cleanList,
      syncedOfficialPath: syncedOfficialPath,
    );
  }

  static List<Map<String, dynamic>> buildDefaultResetEntries(String defaultLib) {
    return [
      ApkSearchDirConfig(
        path: defaultLib,
        label: 'Biblioteca Oficial (v-app-offline apks)',
        enabled: true,
        isDefault: true,
        kind: 'official_library',
      ).toJson(),
      const ApkSearchDirConfig(
        path: ConfigDefaults.defaultFlutterBuildDir,
        label: 'Compilación Local (app_movil/build)',
        enabled: true,
        isDefault: true,
        kind: 'flutter_build',
      ).toJson(),
    ];
  }

  static String defaultLibraryDir() =>
      Platform.isWindows ? ConfigDefaults.defaultWindowsApkLibraryDir : 'releases_apks';

  static ApkSearchDirConfig? _parseRawSearchDirItem(
    dynamic item, {
    bool allowEmptyString = false,
  }) {
    if (item is ApkSearchDirConfig) return item;
    if (item is Map) {
      return ApkSearchDirConfig.fromJson(Map<String, dynamic>.from(item));
    }
    if (item is String && (allowEmptyString || item.trim().isNotEmpty)) {
      return ApkSearchDirConfig(
        path: item.trim(),
        label: 'Carpeta Personalizada',
        enabled: true,
        isDefault: false,
        kind: 'custom',
      );
    }
    return null;
  }
}
