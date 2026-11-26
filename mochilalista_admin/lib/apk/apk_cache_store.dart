import 'dart:convert';
import 'dart:io';

import '../core/path_security.dart';

/// Entrada serializable de metadatos inspeccionados para un archivo `.apk`.
class CachedApkMetadata {
  final String canonicalPath;
  final int sizeBytes;
  final int modifiedMicros;
  final String inspectedAt;
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

  const CachedApkMetadata({
    required this.canonicalPath,
    required this.sizeBytes,
    required this.modifiedMicros,
    required this.inspectedAt,
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

  Map<String, dynamic> toJson() => {
        'canonical_path': canonicalPath,
        'size_bytes': sizeBytes,
        'modified_micros': modifiedMicros,
        'inspected_at': inspectedAt,
        'package_name': packageName,
        'version_name': versionName,
        'version_code': versionCode,
        'abi_variant': abiVariant,
        'sha256': sha256,
        'signature_status': signatureStatus,
        'signature_verified': signatureVerified,
        'signer_sha256': signerSha256,
        'signer_dn': signerDn,
        'signature_detail': signatureDetail,
        'db_schema_version': dbSchemaVersion,
        'min_required_version': minRequiredVersion,
        'min_sdk': minSdk,
        'target_sdk': targetSdk,
        'size_mb': sizeMb,
        'suggested_release_type': suggestedReleaseType,
      };

  static CachedApkMetadata? fromJson(
    Map<String, dynamic> json, {
    String? fallbackPath,
  }) {
    final rawCanon =
        (json['canonical_path'] as String? ?? fallbackPath ?? '').trim();
    final sizeBytes = (json['size_bytes'] as num?)?.toInt();
    final modifiedMicros = (json['modified_micros'] as num?)?.toInt();
    final sha256 = (json['sha256'] as String? ?? '').trim();
    final sizeMb = (json['size_mb'] as String? ?? '').trim();
    final rawAbi =
        (json['abi_variant'] as String? ?? 'UNIVERSAL').trim().toUpperCase();
    final abiVariant = rawAbi == 'ARM64' ? 'ARM64' : 'UNIVERSAL';
    final sigStatus =
        (json['signature_status'] as String? ?? 'UNVERIFIED').trim();

    if (rawCanon.isEmpty ||
        sizeBytes == null ||
        sizeBytes < 0 ||
        modifiedMicros == null ||
        modifiedMicros <= 0 ||
        sha256.isEmpty ||
        sizeMb.isEmpty ||
        sigStatus.isEmpty) {
      return null;
    }

    return CachedApkMetadata(
      canonicalPath: PathSecurity.canonicalizePath(rawCanon),
      sizeBytes: sizeBytes,
      modifiedMicros: modifiedMicros,
      inspectedAt: (json['inspected_at'] as String? ?? '').trim(),
      sizeMb: sizeMb,
      sha256: sha256,
      packageName: json['package_name'] as String?,
      versionName: json['version_name'] as String?,
      versionCode: (json['version_code'] as num?)?.toInt(),
      abiVariant: abiVariant,
      dbSchemaVersion: (json['db_schema_version'] as num?)?.toInt() ?? 36,
      minRequiredVersion:
          (json['min_required_version'] as String? ?? '9.0.0').trim(),
      minSdk: json['min_sdk'] as String?,
      targetSdk: json['target_sdk'] as String?,
      signatureVerified: json['signature_verified'] is bool
          ? json['signature_verified'] as bool
          : null,
      signatureStatus: sigStatus,
      signatureDetail: json['signature_detail'] as String?,
      signerSha256: json['signer_sha256'] as String?,
      signerDn: json['signer_dn'] as String?,
      suggestedReleaseType:
          (json['suggested_release_type'] as String? ?? 'FEATURE_RELEASE')
              .trim(),
    );
  }
}

/// Almacén LRU en memoria y persistencia atómica serializada en `.apk_inspection_cache.json`.
class ApkCacheStore {
  static const int cacheVersion = 1;
  static const int maxDiskCacheEntries = 200;

  final String? cacheFilePath;
  final Map<String, CachedApkMetadata> _liveCache = {};
  bool _diskCacheLoaded = false;
  Future<void> _diskWriteQueue = Future<void>.value();

  ApkCacheStore({this.cacheFilePath});

  bool get diskCacheLoaded => _diskCacheLoaded;
  int get liveCount => _liveCache.length;
  bool get hasDiskBacking => cacheFilePath?.trim().isNotEmpty ?? false;

  void clear() => _liveCache.clear();

  /// Retorna la entrada fresca y promueve su posición LRU sin re-escribir disco.
  CachedApkMetadata? getFresh(
    String cacheKey, {
    required int sizeBytes,
    required int modifiedMicros,
  }) {
    final cached = _liveCache[cacheKey];
    if (cached != null &&
        cached.sizeBytes == sizeBytes &&
        cached.modifiedMicros == modifiedMicros) {
      _liveCache.remove(cacheKey);
      _liveCache[cacheKey] = cached;
      return cached;
    }
    return null;
  }

  CachedApkMetadata? remove(String cacheKey) => _liveCache.remove(cacheKey);

  void put(String cacheKey, CachedApkMetadata meta) {
    _liveCache.remove(cacheKey);
    while (_liveCache.length >= maxDiskCacheEntries) {
      _liveCache.remove(_liveCache.keys.first);
    }
    _liveCache[cacheKey] = meta;
  }

  /// Precarga de forma segura la caché persistente desde `cacheFilePath`.
  Future<void> loadDiskCache({bool force = false}) async {
    final rawPath = cacheFilePath?.trim() ?? '';
    if (rawPath.isEmpty) {
      _diskCacheLoaded = true;
      return;
    }
    if (_diskCacheLoaded && !force) return;
    _diskCacheLoaded = true;
    if (force) {
      _liveCache.clear();
    }

    try {
      final cacheFile = File(PathSecurity.canonicalizePath(rawPath));
      if (!await cacheFile.exists()) return;
      final content = await cacheFile.readAsString();
      if (content.trim().isEmpty) return;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return;
      final version = (decoded['cache_version'] as num?)?.toInt();
      if (version != cacheVersion) return;
      final entries = decoded['entries'];
      if (entries is! Map) return;

      for (final item in entries.entries) {
        if (item.value is! Map) continue;
        final meta = CachedApkMetadata.fromJson(
          Map<String, dynamic>.from(item.value as Map),
          fallbackPath: item.key.toString(),
        );
        if (meta == null) continue;
        final key = PathSecurity.cacheKeyForPath(meta.canonicalPath);
        _liveCache.remove(key);
        _liveCache[key] = meta;
      }

      while (_liveCache.length > maxDiskCacheEntries) {
        _liveCache.remove(_liveCache.keys.first);
      }
    } catch (_) {
      // Silencio seguro ante JSON corrupto o ilegible; se reconstruirá en la próxima inspección.
      _liveCache.clear();
    }
  }

  Future<void> persistDiskCache() {
    final rawPath = cacheFilePath?.trim() ?? '';
    if (rawPath.isEmpty) return Future<void>.value();

    _diskWriteQueue = _diskWriteQueue.catchError((_) {}).then((_) async {
      File? tmpFile;
      try {
        final staleKeys = <String>[];
        for (final entry in _liveCache.entries) {
          if (!File(entry.value.canonicalPath).existsSync()) {
            staleKeys.add(entry.key);
          }
        }
        for (final k in staleKeys) {
          _liveCache.remove(k);
        }

        while (_liveCache.length > maxDiskCacheEntries) {
          _liveCache.remove(_liveCache.keys.first);
        }

        final cacheFile = File(PathSecurity.canonicalizePath(rawPath));
        await cacheFile.parent.create(recursive: true);

        final serializedEntries = <String, dynamic>{
          for (final meta in _liveCache.values)
            meta.canonicalPath: meta.toJson(),
        };
        final payload = {
          'cache_version': cacheVersion,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'entries': serializedEntries,
        };

        final stamp = DateTime.now().microsecondsSinceEpoch;
        tmpFile = File('${cacheFile.path}.$pid.$stamp.tmp');
        await tmpFile.writeAsString(jsonEncode(payload), flush: true);
        await tmpFile.rename(cacheFile.path);
        tmpFile = null;
      } catch (_) {
        // Nunca interrumpir flujos de inspección por error transitorio de I/O en caché.
      } finally {
        if (tmpFile != null && tmpFile.existsSync()) {
          try {
            tmpFile.deleteSync();
          } catch (_) {}
        }
      }
    });
    return _diskWriteQueue;
  }
}
