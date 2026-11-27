import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:app_movil/core/config/owner_legal_identity.dart';

String _resolveAppMovilRoot() {
  final dir = Directory.current.path.replaceAll('\\', '/');
  if (dir.endsWith('/app_movil')) {
    return dir;
  }
  return '$dir/app_movil';
}

String _resolveRepoRoot() {
  final appDir = Directory(_resolveAppMovilRoot());
  return appDir.parent.path.replaceAll('\\', '/');
}

void main() {
  group('PLAN MAESTRO 25 - FASE 10: Optimización Segura APK y Assets Lossless', () {
    test(
      '1. pubspec.yaml/lock retiran cupertino_icons sin usos residuales en lib/ ni test/',
      () {
        final appRoot = _resolveAppMovilRoot();
        final pubspecYaml = File('$appRoot/pubspec.yaml').readAsStringSync();
        final pubspecLock = File('$appRoot/pubspec.lock').readAsStringSync();

        expect(pubspecYaml.contains('cupertino_icons'), isFalse);
        expect(pubspecLock.contains('  cupertino_icons:'), isFalse);
        expect(pubspecYaml.contains('mobile_scanner:'), isTrue);
        expect(OwnerLegalIdentity.currentAppVersionWithBuild, '9.41.0+85');

        final cupertinoImportPattern = RegExp(
          r'package:flutter/cupertino\.dart|\bCupertinoIcons\b|cupertino_icons',
        );
        final offendingFiles = <String>[];

        for (final folderName in const ['lib', 'test']) {
          final dir = Directory('$appRoot/$folderName');
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is! File || !entity.path.endsWith('.dart')) {
              continue;
            }
            final normalizedPath = entity.path.replaceAll('\\', '/');
            if (normalizedPath.endsWith(
              'plan25_fase10_apk_optimization_test.dart',
            )) {
              continue;
            }
            final content = entity.readAsStringSync();
            if (cupertinoImportPattern.hasMatch(content)) {
              offendingFiles.add(normalizedPath);
            }
          }
        }

        expect(offendingFiles, isEmpty);
      },
    );

    test(
      '2. Assets PNG (logo + mipmaps) optimizados lossless con dimensiones y firma intactas',
      () {
        final appRoot = _resolveAppMovilRoot();
        const expectedAssets =
            <String, ({int width, int height, int maxBytes})>{
              'assets/logo.png': (width: 256, height: 256, maxBytes: 73718),
              'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': (
                width: 48,
                height: 48,
                maxBytes: 2879,
              ),
              'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': (
                width: 72,
                height: 72,
                maxBytes: 5593,
              ),
              'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': (
                width: 96,
                height: 96,
                maxBytes: 9260,
              ),
              'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': (
                width: 144,
                height: 144,
                maxBytes: 18987,
              ),
              'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': (
                width: 192,
                height: 192,
                maxBytes: 32771,
              ),
            };

        const pngMagic = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        var totalOptimizedBytes = 0;

        for (final entry in expectedAssets.entries) {
          final file = File('$appRoot/${entry.key}');
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Falta PNG esperado: ${entry.key}',
          );

          final bytes = file.readAsBytesSync();
          expect(bytes.length, greaterThan(8));
          expect(
            bytes.sublist(0, 8),
            equals(pngMagic),
            reason: 'Header PNG inválido: ${entry.key}',
          );
          expect(
            bytes.length,
            lessThanOrEqualTo(entry.value.maxBytes),
            reason:
                'Regresión de peso en ${entry.key}: ${bytes.length} > ${entry.value.maxBytes}',
          );

          final decoded = img.decodePng(bytes);
          expect(decoded, isNotNull, reason: 'PNG corrupto: ${entry.key}');
          expect(decoded!.width, equals(entry.value.width));
          expect(decoded.height, equals(entry.value.height));

          var hasOpaquePixels = false;
          for (final pixel in decoded) {
            if (pixel.a > 0) {
              hasOpaquePixels = true;
              break;
            }
          }
          expect(
            hasOpaquePixels,
            isTrue,
            reason: 'PNG vacío/transparente: ${entry.key}',
          );
          totalOptimizedBytes += bytes.length;
        }

        expect(totalOptimizedBytes, lessThanOrEqualTo(143208));
      },
    );

    test(
      '3. Compilador dual y build.gradle.kts filtran x86_64 en Universal ARM sin romper R8 ni split-per-abi',
      () {
        final repoRoot = _resolveRepoRoot();
        final psFile = File('$repoRoot/scripts/compilar_release_dual.ps1');
        expect(psFile.existsSync(), isTrue);

        final rawBytes = psFile.readAsBytesSync();
        expect(rawBytes.length, greaterThanOrEqualTo(6));
        expect(rawBytes[0], 0xEF);
        expect(rawBytes[1], 0xBB);
        expect(rawBytes[2], 0xBF);
        expect(
          rawBytes[3] == 0xEF && rawBytes[4] == 0xBB && rawBytes[5] == 0xBF,
          isFalse,
          reason: 'El script .ps1 no debe tener doble BOM UTF-8.',
        );

        final psContent = psFile.readAsStringSync();
        expect(RegExp(r'(?<!\r)\n').hasMatch(psContent), isFalse);
        expect(
          psContent.contains('--target-platform android-arm64,android-arm'),
          isTrue,
        );
        expect(psContent.contains('--split-per-abi'), isTrue);
        expect(psContent.contains("--out-dir"), isTrue);
        expect(
          psContent.contains(r"!$abisText.Contains('arm64-v8a')"),
          isFalse,
        );
        expect(
          psContent.contains(
            r"if (-not $abisText.Contains('arm64-v8a') -or -not $abisText.Contains('armeabi-v7a') -or $abisText.Contains('x86_64'))",
          ),
          isTrue,
        );

        final gradleFile = File(
          '$repoRoot/app_movil/android/app/build.gradle.kts',
        );
        expect(gradleFile.existsSync(), isTrue);
        final gradleContent = gradleFile.readAsStringSync();
        expect(gradleContent.contains('isMinifyEnabled = true'), isTrue);
        expect(gradleContent.contains('isShrinkResources = true'), isTrue);
        expect(gradleContent.contains('"proguard-rules.pro"'), isTrue);
        expect(
          gradleContent.contains(
            'if (!project.hasProperty("split-per-abi") && project.hasProperty("target-platform"))',
          ),
          isTrue,
        );
        expect(
          gradleContent.contains('"android-arm" to "armeabi-v7a"'),
          isTrue,
        );
        expect(
          gradleContent.contains('"android-arm64" to "arm64-v8a"'),
          isTrue,
        );
        expect(gradleContent.contains('"android-x64" to "x86_64"'), isTrue);
      },
    );
  });
}
