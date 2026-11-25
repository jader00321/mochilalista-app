import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

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
  final bool? signatureVerified; // true: oficial, false: no oficial / debug, null: tool no disponible o no verificable
  final String signatureStatus; // 'OFFICIAL_RELEASE' | 'UNOFFICIAL_SIGNATURE' | 'UNVERIFIED'
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
        if (modifiedAt != null) 'modified_at': modifiedAt!.toUtc().toIso8601String(),
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
  final Future<ProcessResult> Function(String executable, List<String> arguments)?
      processRunnerOverride;

  /// Inyección de raíces de búsqueda de SDK para pruebas unitarias
  final List<String>? sdkSearchRootsOverride;

  /// Directorio opcional de compilación local (anula ../app_movil/build/... para pruebas unitarias)
  final Directory? defaultBuildOutputDir;

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

  /// Inspecciona exhaustivamente un archivo APK combinando Dart puro y herramientas Android SDK
  Future<ApkInspectionResult> inspectApk(
    File apkFile, {
    String? sourceLabel,
    String? apkLibraryDir,
    List<Directory> extraSearchDirs = const [],
  }) async {
    final canonicalApkPath = canonicalizePath(apkFile.path);
    final canonicalFile = File(canonicalApkPath);

    if (!await canonicalFile.exists()) {
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
    final fileName = canonicalFile.uri.pathSegments.isNotEmpty
        ? canonicalFile.uri.pathSegments.last
        : 'app-release.apk';

    // 1. Capa 1: Tamaño y Hash Criptográfico SHA-256 determinista
    final fileLength = await canonicalFile.length();
    final sha256Digest =
        (await sha256.bind(canonicalFile.openRead()).first).toString().toLowerCase();
    final sizeMb = (fileLength / (1024 * 1024)).toStringAsFixed(2);
    final sizeMbStr = '$sizeMb MB';

    // 2. Capa 1: Detección ABI determinista en Dart puro inspeccionando el ZIP
    final detectedAbis = await _detectZipAbis(canonicalFile);
    final isArm64Only = detectedAbis.length == 1 && detectedAbis.contains('arm64-v8a');
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
      final aaptRes = await _runProcess(aapt2Exe, ['dump', 'badging', canonicalApkPath]);
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

    // 5. Capa 4: Notas compañeras (Changelog comercial y Notas Técnicas *_atp.txt) + SemVer
    final notes = await readCompanionNotesForVersion(
      versionName ?? '',
      apkPath: canonicalApkPath,
      apkLibraryDir: apkLibraryDir,
      extraSearchDirs: extraSearchDirs,
      fallbackRegistryChangelog: true,
    );
    final suggestedChangelog = (notes['suggested_changelog'] as String?) ?? '';
    final suggestedInternalNotes = (notes['suggested_internal_notes'] as String?) ?? '';
    final suggestedReleaseType = inferReleaseTypeFromVersion(versionName);

    return ApkInspectionResult(
      success: true,
      fileName: fileName,
      filePath: canonicalApkPath,
      sourceLabel: sourceLabel,
      modifiedAt: stat.modified,
      sizeBytes: fileLength,
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
      suggestedChangelog: suggestedChangelog,
      suggestedInternalNotes: suggestedInternalNotes,
      suggestedReleaseType: suggestedReleaseType,
    );
  }

  /// Escanea transparentemente la biblioteca oficial y outputs locales,
  /// deduplicando por SHA-256 (prioriza Biblioteca Oficial sobre build/)
  Future<List<ApkInspectionResult>> detectLocalApks({
    required Directory apkLibraryDir,
    Directory? buildOutputDir,
    int maxCandidates = 6,
  }) async {
    final candidateFiles = <_ApkCandidate>[];
    final seenPaths = <String>{};

    void addCandidateDir(Directory dir, String label, int priority) {
      final canonDirPath = canonicalizePath(dir.path);
      final canonDir = Directory(canonDirPath);
      if (!canonDir.existsSync()) return;
      try {
        final list = canonDir.listSync(followLinks: false);
        for (final entity in list) {
          if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
            final canonFile = canonicalizePath(entity.path);
            final key = Platform.isWindows ? canonFile.toLowerCase() : canonFile;
            if (seenPaths.add(key)) {
              candidateFiles.add(_ApkCandidate(
                file: File(canonFile),
                sourceLabel: label,
                modified: entity.statSync().modified,
                priority: priority,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // 1. Escanear directorio de la biblioteca oficial (prioridad 0)
    addCandidateDir(apkLibraryDir, 'Biblioteca Oficial (v-app-offline apks)', 0);

    // 2. Escanear build/app/outputs/flutter-apk/ si existe (prioridad 1)
    final buildDir = buildOutputDir ??
        defaultBuildOutputDir ??
        Directory('../app_movil/build/app/outputs/flutter-apk');
    addCandidateDir(buildDir, 'Compilación Local (app_movil/build)', 1);

    // Ordenar de más reciente a más antiguo; ante igualdad de fecha, priorizar Biblioteca Oficial
    candidateFiles.sort((a, b) {
      final cmp = b.modified.compareTo(a.modified);
      if (cmp != 0) return cmp;
      return a.priority.compareTo(b.priority);
    });

    // Inspeccionar ventana ampliada (12) para absorber duplicados y devolver hasta maxCandidates únicos
    final inspectLimit = maxCandidates * 2;
    final selectedCandidates = candidateFiles.take(inspectLimit).toList();
    final uniqueResults = <ApkInspectionResult>[];
    final indexBySha = <String, int>{};
    final libPath = canonicalizePath(apkLibraryDir.path);

    for (final c in selectedCandidates) {
      final res = await inspectApk(
        c.file,
        sourceLabel: c.sourceLabel,
        apkLibraryDir: libPath,
      );
      if (res.sha256.isEmpty) {
        uniqueResults.add(res);
        continue;
      }

      final existingIdx = indexBySha[res.sha256];
      if (existingIdx == null) {
        indexBySha[res.sha256] = uniqueResults.length;
        uniqueResults.add(res);
      } else {
        final existing = uniqueResults[existingIdx];
        final isNewOfficialLib = c.priority == 0 &&
            existing.sourceLabel != 'Biblioteca Oficial (v-app-offline apks)';
        if (isNewOfficialLib) {
          final mergedDups = <String>[...existing.duplicatePaths, existing.filePath];
          uniqueResults[existingIdx] = res.copyWith(duplicatePaths: mergedDups);
        } else {
          final mergedDups = <String>[...existing.duplicatePaths, res.filePath];
          uniqueResults[existingIdx] = existing.copyWith(duplicatePaths: mergedDups);
        }
      }
    }

    return uniqueResults.take(maxCandidates).toList();
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
  _VersionMeta _inferVersionFromName(String fileName) {
    final clean = fileName.toLowerCase();
    final match = RegExp(r'(?:v)?(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(clean);
    if (match != null) {
      final major = match.group(1)!;
      final minor = match.group(2)!;
      final patch = match.group(3) ?? '0';
      return _VersionMeta(versionName: '$major.$minor.$patch', versionCode: null);
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

    final pkgMatch = RegExp(r"package:\s*name='([^']+)'").firstMatch(badgingOutput);
    if (pkgMatch != null) packageName = pkgMatch.group(1);

    final vcMatch = RegExp(r"versionCode='(\d+)'").firstMatch(badgingOutput);
    if (vcMatch != null) versionCode = int.tryParse(vcMatch.group(1)!);

    final vnMatch = RegExp(r"versionName='([^']+)'").firstMatch(badgingOutput);
    if (vnMatch != null) versionName = vnMatch.group(1);

    final minSdkMatch = RegExp(r"(?:minSdkVersion|sdkVersion):\s*'([^']+)'").firstMatch(badgingOutput);
    if (minSdkMatch != null) minSdk = minSdkMatch.group(1);

    final targetSdkMatch = RegExp(r"(?:targetSdkVersion|targetSdk):\s*'([^']+)'").firstMatch(badgingOutput);
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
    List<Directory> extraSearchDirs = const [],
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
    for (final d in extraSearchDirs) {
      addDir(d);
    }
    if (apkLibraryDir != null && apkLibraryDir.trim().isNotEmpty) {
      addDir(Directory(apkLibraryDir));
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
        final candidate = File(canonicalizePath('${dir.path}${Platform.pathSeparator}$name'));
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
        final registryFile = File('../app_movil/lib/core/config/app_changelog_registry.dart');
        if (await registryFile.exists()) {
          final content = await registryFile.readAsString();
          final matches = RegExp(
            r'title:\s*["\x27](.+?)["\x27],\s*description:\s*["\x27](.+?)["\x27]',
            dotAll: true,
          ).allMatches(content);

          final bullets = <String>[];
          for (final m in matches) {
            final title = m.group(1)?.trim() ?? '';
            final desc = m.group(2)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
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
        if (lower.endsWith('_cambios.txt') || lower.endsWith('_changelog.txt')) {
          continue;
        }
        final candidate = File(canonicalizePath('${dir.path}${Platform.pathSeparator}$name'));
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
      if (internalNotesSource != null) 'internal_notes_source': internalNotesSource,
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
          final match = RegExp(r'(?:version|schema_version)\s*[:=]\s*(\d+)').firstMatch(content);
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
    final rawRoots = sdkSearchRootsOverride ?? [
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
            final candidatePath =
                canonicalizePath('${verDir.path}${Platform.pathSeparator}$exeName');
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
  Future<ProcessResult> _runProcess(String executable, List<String> args) async {
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
  final DateTime modified;
  final int priority;

  _ApkCandidate({
    required this.file,
    required this.sourceLabel,
    required this.modified,
    this.priority = 1,
  });
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
