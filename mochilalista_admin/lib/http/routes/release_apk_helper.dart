import 'dart:io';

import '../../apk_inspector_service.dart';
import '../../config_service.dart';

/// Helpers asíncronos compartidos para resolución de binarios APK y verificación forense (`D-ADM-10`).
class ReleaseApkHelper {
  ReleaseApkHelper._();

  /// Resuelve de forma asíncrona el archivo APK físico para [release] según [variant] (`arm64` / `universal`),
  /// evitando llamadas bloqueantes `existsSync()` y unificando `download`, `copy-file` y `reveal-file`.
  static Future<File?> resolveExistingReleaseApkFile(
    Map<String, dynamic>? release, {
    String? variant,
    List<String> fallbackCandidatePaths = const [],
  }) async {
    File? apkFile;

    if (release != null) {
      if (variant == 'arm64' && release['arm64_apk'] != null) {
        final p = (release['arm64_apk'] as Map<String, dynamic>)['file_path']
            as String?;
        if (p != null) {
          final f = File(p);
          if (await f.exists()) apkFile = f;
        }
      } else if (variant == 'universal' && release['universal_apk'] != null) {
        final p = (release['universal_apk']
            as Map<String, dynamic>)['file_path'] as String?;
        if (p != null) {
          final f = File(p);
          if (await f.exists()) apkFile = f;
        }
      }

      if (apkFile == null &&
          (release['apk_file_path'] as String? ?? '').isNotEmpty) {
        final f = File(release['apk_file_path'] as String);
        if (await f.exists()) apkFile = f;
      }
    }

    if (apkFile == null || !await apkFile.exists()) {
      for (final path in fallbackCandidatePaths) {
        final candidate = File(path);
        if (await candidate.exists()) {
          return candidate;
        }
      }
    }

    return apkFile;
  }

  /// Verifica variantes registradas y ruta raíz de un release contra disco duro y `apksigner`.
  static Future<Map<String, dynamic>> inspectAndComputeReleaseVerification(
    Map<String, dynamic> release, {
    required ApkInspectorService inspector,
    required ConfigService configService,
    bool forceRefresh = false,
    bool readCompanionNotes = false,
  }) async {
    final updates = <String, dynamic>{};
    final verifiedVariants = <String>[];
    ApkInspectionResult? primaryInspection;
    bool anyFileExists = false;
    final searchDirPaths = configService.getEffectiveApkSearchDirPaths(
      defaultBuildOutputDir: inspector.defaultBuildOutputDir?.path,
    );

    Future<Map<String, dynamic>?> verifyVariantPath(
      Map<String, dynamic>? existingVariant,
      String? rawPath,
      String label,
    ) async {
      if (rawPath == null || rawPath.trim().isEmpty) return null;
      final canon = ApkInspectorService.canonicalizePath(rawPath);
      final f = File(canon);
      if (!await f.exists()) {
        if (existingVariant != null) {
          final missingMap = Map<String, dynamic>.from(existingVariant);
          missingMap['file_path'] = canon;
          missingMap['file_exists'] = false;
          return missingMap;
        }
        return null;
      }

      anyFileExists = true;
      final res = await inspector.inspectApk(
        f,
        apkLibraryDir: configService.apkLibraryDir,
        extraSearchDirs: searchDirPaths,
        forceRefresh: forceRefresh,
      );
      verifiedVariants.add(label);
      primaryInspection ??= res;
      return {
        'file_path': res.filePath,
        'file_size_mb': res.sizeMb,
        'sha256': res.sha256,
        'signature_status': res.signatureStatus,
        'signature_verified': res.signatureVerified,
        if (res.signatureDetail != null) 'signature_detail': res.signatureDetail,
        'signer_sha256': res.signerSha256,
        'signer_dn': res.signerDn,
        'file_exists': true,
      };
    }

    final existingUniv = release['universal_apk'] as Map<String, dynamic>?;
    final existingArm = release['arm64_apk'] as Map<String, dynamic>?;
    final rawUnivPath = existingUniv?['file_path'] as String?;
    final rawArmPath = existingArm?['file_path'] as String?;
    final rawMainPath = release['apk_file_path'] as String?;

    final updatedUniv =
        await verifyVariantPath(existingUniv, rawUnivPath, 'universal');
    if (updatedUniv != null) {
      updates['universal_apk'] = updatedUniv;
    }

    final updatedArm = await verifyVariantPath(existingArm, rawArmPath, 'arm64');
    if (updatedArm != null) {
      updates['arm64_apk'] = updatedArm;
    }

    if (rawMainPath != null && rawMainPath.trim().isNotEmpty) {
      final mainCanon = ApkInspectorService.canonicalizePath(rawMainPath);
      final mainExists = await File(mainCanon).exists();
      if (mainExists) {
        if (primaryInspection == null) {
          await verifyVariantPath(null, mainCanon, 'primary');
        } else {
          anyFileExists = true;
        }
      }
    }

    if (primaryInspection != null) {
      final p = primaryInspection!;
      updates['apk_file_path'] = p.filePath;
      updates['file_size_mb'] = p.sizeMb;
      updates['apk_sha256'] = p.sha256;
      updates['signature_verified'] = p.signatureVerified;
      updates['signature_status'] = p.signatureStatus;
      updates['signature_detail'] = p.signatureDetail;
      updates['signer_sha256'] = p.signerSha256;
      updates['signer_dn'] = p.signerDn;
      updates['file_exists'] = true;
      if (p.versionCode != null) updates['version_code'] = p.versionCode;
      updates['db_schema_version'] = p.dbSchemaVersion;
      if (p.abiVariant == 'UNIVERSAL' && updatedUniv == null) {
        updates['universal_apk'] = {
          'file_path': p.filePath,
          'file_size_mb': p.sizeMb,
          'sha256': p.sha256,
          'signature_status': p.signatureStatus,
          'signature_verified': p.signatureVerified,
          if (p.signatureDetail != null) 'signature_detail': p.signatureDetail,
          'signer_sha256': p.signerSha256,
          'signer_dn': p.signerDn,
          'file_exists': true,
        };
      } else if (p.abiVariant == 'ARM64' && updatedArm == null) {
        updates['arm64_apk'] = {
          'file_path': p.filePath,
          'file_size_mb': p.sizeMb,
          'sha256': p.sha256,
          'signature_status': p.signatureStatus,
          'signature_verified': p.signatureVerified,
          if (p.signatureDetail != null) 'signature_detail': p.signatureDetail,
          'signer_sha256': p.signerSha256,
          'signer_dn': p.signerDn,
          'file_exists': true,
        };
      }
    } else {
      updates['file_exists'] = false;
      updates['signature_verified'] = null;
      updates['signature_status'] = 'UNVERIFIED';
      updates['signature_detail'] =
          'No se encontró ningún archivo físico APK registrado en disco.';
    }

    Map<String, dynamic>? companionNotes;
    if (readCompanionNotes) {
      companionNotes = await inspector.readCompanionNotesForVersion(
        release['version_name'] as String? ?? '',
        apkPath: (updates['apk_file_path'] as String?) ??
            rawMainPath ??
            rawUnivPath ??
            rawArmPath,
        apkLibraryDir: configService.apkLibraryDir,
        extraSearchDirs: searchDirPaths,
      );
    }

    return {
      'updates': updates,
      'file_exists': anyFileExists,
      'verified_variants': verifiedVariants,
      if (companionNotes != null) 'companion_notes': companionNotes,
    };
  }
}
