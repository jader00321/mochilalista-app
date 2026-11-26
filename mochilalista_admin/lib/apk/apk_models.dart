/// Configuración de una carpeta de búsqueda de APKs locales.
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

/// Reporte completo de autodetección local incluyendo métricas por directorio.
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

/// Resultado estructurado de la inspección de un archivo `.apk`.
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
      signatureVerified; // true: oficial, false: no oficial / debug, null: no verificable
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
