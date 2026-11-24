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
  final bool? signatureVerified; // true: oficial, false: no oficial / debug, null: tool no disponible
  final String signatureStatus; // 'VERIFIED' | 'UNOFFICIAL_OR_DEBUG' | 'TOOL_UNAVAILABLE'
  final String? signerSha256;
  final String? signerDn;
  final String suggestedChangelog;

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
    this.signerSha256,
    this.signerDn,
    this.suggestedChangelog = '',
  });

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
        'signer_sha256': signerSha256,
        'signer_dn': signerDn,
        'suggested_changelog': suggestedChangelog,
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

  /// Inspecciona exhaustivamente un archivo APK combinando Dart puro y herramientas Android SDK
  Future<ApkInspectionResult> inspectApk(File apkFile, {String? sourceLabel}) async {
    if (!await apkFile.exists()) {
      return ApkInspectionResult(
        success: false,
        errorMessage: 'El archivo APK no existe en disco: ${apkFile.path}',
        fileName: apkFile.uri.pathSegments.isNotEmpty
            ? apkFile.uri.pathSegments.last
            : 'desconocido.apk',
        filePath: apkFile.path,
        sourceLabel: sourceLabel,
        sizeBytes: 0,
        sizeMb: '0.00 MB',
        sha256: '',
        abiVariant: 'UNIVERSAL',
        signatureStatus: 'TOOL_UNAVAILABLE',
      );
    }

    final stat = await apkFile.stat();
    final fileName = apkFile.uri.pathSegments.last;

    // 1. Capa 1: Tamaño y Hash Criptográfico SHA-256 determinista
    final fileLength = await apkFile.length();
    final sha256Digest = (await sha256.bind(apkFile.openRead()).first).toString().toLowerCase();
    final sizeMb = (fileLength / (1024 * 1024)).toStringAsFixed(2);
    final sizeMbStr = '$sizeMb MB';

    // 2. Capa 1: Detección ABI determinista en Dart puro inspeccionando el ZIP
    final detectedAbis = await _detectZipAbis(apkFile);
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
      final aaptRes = await _runProcess(aapt2Exe, ['dump', 'badging', apkFile.absolute.path]);
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

    // 4. Capa 3: Escudo Anti-debug.apk con apksigner
    bool? signatureVerified;
    String signatureStatus = 'UNVERIFIED';
    String? signerSha256;
    String? signerDn;

    final apksignerBin = await _findBuildTool('apksigner');
    if (apksignerBin != null) {
      final apkSignerRes = await _runProcess(
        apksignerBin,
        ['verify', '--verbose', '--print-certs', apkFile.absolute.path],
      );
      if (apkSignerRes.exitCode == 0) {
        final out = '${apkSignerRes.stdout}\n${apkSignerRes.stderr}';
        final parsedSig = _parseApksignerOutput(out);
        signerSha256 = parsedSig.signerSha256;
        signerDn = parsedSig.signerDn;

        if (parsedSig.signerSha256 != null &&
            parsedSig.signerSha256!.toLowerCase() == officialSignerSha256.toLowerCase()) {
          signatureVerified = true;
          signatureStatus = 'OFFICIAL_RELEASE';
        } else {
          signatureVerified = false;
          signatureStatus = 'UNOFFICIAL_SIGNATURE';
        }
      } else {
        signatureVerified = false;
        signatureStatus = 'UNVERIFIED';
      }
    }

    // 5. Capa 4: Sugerencia de Changelog Comercial limpio
    final suggestedChangelog = await _findSuggestedChangelog(apkFile, versionName);

    return ApkInspectionResult(
      success: true,
      fileName: fileName,
      filePath: apkFile.absolute.path,
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
      signerSha256: signerSha256,
      signerDn: signerDn,
      suggestedChangelog: suggestedChangelog,
    );
  }

  /// Escanea transparentemente la biblioteca oficial y outputs locales,
  /// limitando la inspección profunda a los 6 APKs más recientes
  Future<List<ApkInspectionResult>> detectLocalApks({
    required Directory apkLibraryDir,
    Directory? buildOutputDir,
    int maxCandidates = 6,
  }) async {
    final candidateFiles = <_ApkCandidate>[];

    // 1. Escanear directorio de la biblioteca oficial
    if (await apkLibraryDir.exists()) {
      try {
        final list = apkLibraryDir.listSync(followLinks: false);
        for (final entity in list) {
          if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
            candidateFiles.add(_ApkCandidate(
              file: entity,
              sourceLabel: 'Biblioteca Oficial (v-app-offline apks)',
              modified: entity.statSync().modified,
            ));
          }
        }
      } catch (_) {}
    }

    // 2. Escanear build/app/outputs/flutter-apk/ si existe
    final buildDir = buildOutputDir ??
        defaultBuildOutputDir ??
        Directory('../app_movil/build/app/outputs/flutter-apk');
    if (await buildDir.exists()) {
      try {
        final list = buildDir.listSync(followLinks: false);
        for (final entity in list) {
          if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
            candidateFiles.add(_ApkCandidate(
              file: entity,
              sourceLabel: 'Compilación Local (app_movil/build)',
              modified: entity.statSync().modified,
            ));
          }
        }
      } catch (_) {}
    }

    // Ordenar de más reciente a más antiguo por fecha de modificación
    candidateFiles.sort((a, b) => b.modified.compareTo(a.modified));

    // Limitar estrictamente a los candidatos más recientes para rendimiento instantáneo
    final selectedCandidates = candidateFiles.take(maxCandidates).toList();
    final results = <ApkInspectionResult>[];

    for (final c in selectedCandidates) {
      final res = await inspectApk(c.file, sourceLabel: c.sourceLabel);
      results.add(res);
    }

    return results;
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
  _ApkSignerResult _parseApksignerOutput(String output) {
    String? signerSha256;
    String? signerDn;

    final shaMatch = RegExp(
      r'Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F:]+)',
      caseSensitive: false,
    ).firstMatch(output);

    if (shaMatch != null) {
      signerSha256 = shaMatch.group(1)!.replaceAll(':', '').trim().toLowerCase();
    }

    final dnMatch = RegExp(
      r'Signer #1 certificate DN:\s*(.+)',
      caseSensitive: false,
    ).firstMatch(output);

    if (dnMatch != null) {
      signerDn = dnMatch.group(1)!.trim();
    }

    return _ApkSignerResult(signerSha256: signerSha256, signerDn: signerDn);
  }

  /// Sugiere un changelog comercial limpio leyendo `*_cambios.txt` o `app_changelog_registry.dart`
  Future<String> _findSuggestedChangelog(File apkFile, String? versionName) async {
    try {
      // 1. Buscar archivo compañero *_cambios.txt en la misma carpeta del APK
      final parentDir = apkFile.parent;
      final apkBaseName = apkFile.uri.pathSegments.last.replaceAll(RegExp(r'\.apk$', caseSensitive: false), '');
      
      final candidates = [
        File('${parentDir.path}/${apkBaseName}_cambios.txt'),
        File('${parentDir.path}/${apkBaseName.replaceAll('_atp', '')}_cambios.txt'),
        if (versionName != null) File('${parentDir.path}/mochilalista_v${versionName}_cambios.txt'),
        if (versionName != null) File('${parentDir.path}/mochilalista_v${versionName.replaceAll('.0', '')}_cambios.txt'),
      ];

      for (final f in candidates) {
        if (await f.exists()) {
          final text = (await f.readAsString()).trim();
          if (text.isNotEmpty) return text;
        }
      }

      // 2. Fallback a app_changelog_registry.dart si coincide la versión
      final changelogFile = File('../app_movil/lib/core/config/app_changelog_registry.dart');
      if (await changelogFile.exists()) {
        final content = await changelogFile.readAsString();
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
          return bullets.join('\n');
        }
      }
    } catch (_) {}

    return '';
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
            final vName = parts.isNotEmpty ? parts[0] : '9.38.0';
            final vCode = parts.length > 1 ? int.tryParse(parts[1]) ?? 82 : 82;
            return _VersionMeta(versionName: vName, versionCode: vCode);
          }
        }
      } catch (_) {}
    }
    return const _VersionMeta(versionName: '9.38.0', versionCode: 82);
  }

  /// Ubica la herramienta especificada (aapt2 o apksigner) en build-tools de Android SDK
  Future<String?> _findBuildTool(String toolName) async {
    final isWindows = Platform.isWindows;
    final exeName = isWindows
        ? (toolName == 'apksigner' ? '$toolName.bat' : '$toolName.exe')
        : toolName;

    // Raíces configuradas o por variables de entorno
    final searchRoots = sdkSearchRootsOverride ?? [
      if (Platform.environment['ANDROID_HOME'] != null)
        '${Platform.environment['ANDROID_HOME']}/build-tools',
      if (Platform.environment['ANDROID_SDK_ROOT'] != null)
        '${Platform.environment['ANDROID_SDK_ROOT']}/build-tools',
      if (isWindows && Platform.environment['LOCALAPPDATA'] != null)
        '${Platform.environment['LOCALAPPDATA']}/Android/Sdk/build-tools',
    ];

    for (final root in searchRoots) {
      final dir = Directory(root);
      if (await dir.exists()) {
        try {
          final entries = dir.listSync().whereType<Directory>().toList();
          // Ordenar descendente por nombre de versión (ej. 37.0.0 > 35.0.0)
          entries.sort((a, b) => b.path.compareTo(a.path));

          for (final verDir in entries) {
            final toolFile = File('${verDir.path}/$exeName');
            if (await toolFile.exists()) {
              return toolFile.absolute.path;
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

  _ApkCandidate({
    required this.file,
    required this.sourceLabel,
    required this.modified,
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
