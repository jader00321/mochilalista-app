import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/path_security.dart';
import '../core/semver_utils.dart';
import 'apk_models.dart';

class AaptBadgingResult {
  final String? packageName;
  final String? versionName;
  final int? versionCode;
  final String? minSdk;
  final String? targetSdk;

  const AaptBadgingResult({
    this.packageName,
    this.versionName,
    this.versionCode,
    this.minSdk,
    this.targetSdk,
  });
}

class ApkSignerResult {
  final String? signerSha256;
  final String? signerDn;

  const ApkSignerResult({this.signerSha256, this.signerDn});
}

class InspectedCandidateItem {
  final ApkInspectionResult result;
  final int priority;

  const InspectedCandidateItem(this.result, this.priority);
}

/// Utilidades de bajo nivel para inspección binaria de APKs (ZIP central directory,
/// salida `aapt2 dump badging`, verificación `apksigner` y resolución de build-tools).
class ApkBinaryTools {
  ApkBinaryTools._();

  /// Lector en Dart puro del directorio central ZIP/APK para detectar ABIs en `lib/`.
  static Future<Set<String>> detectZipAbis(File file) async {
    final abis = <String>{};
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final len = await raf.length();
      if (len < 22) return abis;

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

  static AaptBadgingResult parseAapt2Badging(String badgingOutput) {
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

    return AaptBadgingResult(
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      minSdk: minSdk,
      targetSdk: targetSdk,
    );
  }

  static ApkSignerResult parseApksignerOutput(
    String output, {
    required String officialSignerSha256,
  }) {
    final shaLineRegex = RegExp(
      r'^(?:V\d+(?:\.\d+)?\s+Signer:|Signer\s*#\d+)\s*certificate\s+SHA-256\s+digest:\s*([0-9a-fA-F:]+)',
      caseSensitive: false,
    );
    final dnLineRegex = RegExp(
      r'^(?:V\d+(?:\.\d+)?\s+Signer:|Signer\s*#\d+)\s*certificate\s+DN:\s*(.+)',
      caseSensitive: false,
    );

    final extracted = <ApkSignerResult>[];
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
        extracted.add(ApkSignerResult(
          signerSha256: normalizedSha,
          signerDn: currentDn,
        ));
      }
    }

    if (extracted.isEmpty) {
      return ApkSignerResult(signerSha256: null, signerDn: firstDn);
    }

    for (final entry in extracted) {
      if (entry.signerSha256 == officialSignerSha256.toLowerCase()) {
        return entry;
      }
    }
    return extracted.first;
  }

  static Future<String?> findBuildTool(
    String toolName, {
    List<String>? sdkSearchRootsOverride,
  }) async {
    final isWindows = Platform.isWindows;
    final exeName = isWindows
        ? (toolName == 'apksigner' ? '$toolName.bat' : '$toolName.exe')
        : toolName;

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
      final dir = Directory(PathSecurity.canonicalizePath(rawRoot));
      if (await dir.exists()) {
        try {
          final entries = dir.listSync().whereType<Directory>().toList();
          entries.sort(
            (a, b) => SemVerUtils.compareVersionFolderNames(b.path, a.path),
          );

          for (final verDir in entries) {
            final candidatePath = PathSecurity.canonicalizePath(
                '${verDir.path}${Platform.pathSeparator}$exeName');
            final toolFile = File(candidatePath);
            if (await toolFile.exists()) {
              return PathSecurity.canonicalizePath(toolFile.path);
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  static Future<ProcessResult> runProcess(
    String executable,
    List<String> args, {
    Future<ProcessResult> Function(String executable, List<String> arguments)?
        processRunnerOverride,
  }) async {
    try {
      if (processRunnerOverride != null) {
        return await processRunnerOverride(executable, args);
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
