import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

const String _officialSignerSha256 =
    '7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20';
const String _sentinelSecret = 'SUPER_SECRET_SENTINEL_999';

String _repoRootPath() {
  final cur = Directory.current.absolute.path;
  if (File('$cur/compilar_release_dual.bat').existsSync()) {
    return cur;
  }
  return Directory('${Directory.current.path}/..').absolute.path;
}

Future<ProcessResult> _runBat(
  List<String> args, {
  Map<String, String>? environment,
}) async {
  final root = _repoRootPath();
  final batPath = '$root\\compilar_release_dual.bat';
  return await Process.run(
    'cmd.exe',
    ['/c', batPath, ...args],
    workingDirectory: root,
    environment: environment,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  ).timeout(const Duration(seconds: 30));
}

Future<Map<String, String>> _prepareIsolatedFixture(
  Directory baseDir, {
  required String versionLine,
  required String tag,
  required int universalCode,
  required int arm64Code,
  bool createApks = true,
  bool includeDebuggable = false,
  String? signerShaOverride,
  String signerFormat = 'sdk37', // 'sdk37' | 'sdk36'
  String universalNativeCode = "'arm64-v8a' 'armeabi-v7a'",
}) async {
  final pubspec = File('${baseDir.path}\\pubspec.yaml')
    ..writeAsStringSync('name: app_movil\nversion: $versionLine\n');
  final jksFile = File('${baseDir.path}\\test-release.jks')
    ..writeAsStringSync('FAKE_JKS_BYTES');
  final keyProps = File('${baseDir.path}\\key.properties')
    ..writeAsStringSync(
      'storePassword=$_sentinelSecret\n'
      'keyPassword=${_sentinelSecret}_KEY\n'
      'keyAlias=mochilalista-key\n'
      'storeFile=test-release.jks\n',
    );
  final outDir = Directory('${baseDir.path}\\out_apks')..createSync(recursive: true);

  final univApk = File('${outDir.path}\\mochilalista_v${tag}_atp.apk');
  final armApk = File('${outDir.path}\\mochilalista_v${tag}_arm64_atp.apk');
  if (createApks) {
    univApk.writeAsBytesSync(List<int>.filled(4096, 0x55));
    armApk.writeAsBytesSync(List<int>.filled(1024, 0x41));
  }

  final verName = versionLine.split('+').first;
  final debuggableLine =
      includeDebuggable ? "application-debuggable\r\n" : '';

  final mockAapt2 = File('${baseDir.path}\\mock_aapt2.cmd')
    ..writeAsStringSync(
      '@echo off\r\n'
      'set "APK=%~3"\r\n'
      'echo %APK% | findstr /i "arm64" >nul\r\n'
      'if %errorlevel%==0 (\r\n'
      '  echo package: name=\'com.mochilalista.app\' versionCode=\'$arm64Code\' versionName=\'$verName\'\r\n'
      '  echo native-code: \'arm64-v8a\'\r\n'
      ') else (\r\n'
      '  echo package: name=\'com.mochilalista.app\' versionCode=\'$universalCode\' versionName=\'$verName\'\r\n'
      '  echo native-code: $universalNativeCode\r\n'
      ')\r\n'
      '${debuggableLine.isNotEmpty ? 'echo application-debuggable\r\n' : ''}'
      'exit /b 0\r\n',
    );

  final sha = signerShaOverride ?? _officialSignerSha256;
  final signerLines = signerFormat == 'sdk36'
      ? [
          'echo Verifies',
          'echo Verified using v2 scheme (APK Signature Scheme v2): true',
          'echo Signer #1 certificate DN: CN=Julio Angello Vasquez Navarro, C=PE',
          'echo Signer #1 certificate SHA-256 digest: $sha',
        ]
      : [
          'echo Verifies',
          'echo Verified using v2 scheme (APK Signature Scheme v2): true',
          'echo Verified for SourceStamp: false',
          'echo SourceStamp Signer certificate SHA-256 digest: ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          'echo V2 Signer: certificate DN: CN=Julio Angello Vasquez Navarro, C=PE',
          'echo V2 Signer: certificate SHA-256 digest: $sha',
        ];

  final mockSigner = File('${baseDir.path}\\mock_apksigner.cmd')
    ..writeAsStringSync('@echo off\r\n${signerLines.join('\r\n')}\r\nexit /b 0\r\n');

  expect(jksFile.existsSync(), isTrue);
  return {
    'ML_DUAL_PUBSPEC_PATH': pubspec.path,
    'ML_DUAL_KEY_PROPERTIES_PATH': keyProps.path,
    'ML_DUAL_AAPT2_PATH': mockAapt2.path,
    'ML_DUAL_APKSIGNER_PATH': mockSigner.path,
    'outDir': outDir.path,
  };
}

void main() {
  group(
      'PLAN MAESTRO 23.5 - FASE 3: Compilador Dual Oficial Único y Guiado (compilar_release_dual.bat)',
      () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ml_p23_5_fase3_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        '1. --help --no-pause y --dry-run --no-pause en entorno real sin compilar ni filtrar secretos',
        () async {
      final helpRes = await _runBat(['--help', '--no-pause']);
      expect(helpRes.exitCode, equals(0),
          reason: 'STDERR: ${helpRes.stderr}\nSTDOUT: ${helpRes.stdout}');
      final helpOut = helpRes.stdout.toString();
      expect(helpOut, contains('APK Universal'));
      expect(helpOut, contains('APK ARM64 Ligero'));
      expect(helpOut, contains('--verify-only'));
      expect(helpOut, contains('--dry-run'));
      expect(helpOut, contains('--skip-analyze'));
      expect(helpOut, contains('--no-pause'));
      expect(helpOut, contains('--out-dir'));
      expect(helpOut, contains('PARÁMETROS DISPONIBLES:'));
      expect(helpOut, contains('QUÉ GENERA ESTE SCRIPT:'));
      expect(helpOut, isNot(contains('QUÃ')));
      expect(helpOut, isNot(contains('PARÃ')));

      final dryRes = await _runBat(['--dry-run', '--no-pause']);
      expect(dryRes.exitCode, equals(0),
          reason: 'STDERR: ${dryRes.stderr}\nSTDOUT: ${dryRes.stdout}');
      final dryOut = dryRes.stdout.toString();
      expect(dryOut, contains('[Paso 1/6]'));
      expect(dryOut, contains('v9.41.0+85'));
      expect(dryOut, contains('mochilalista_v9.41_atp.apk'));
      expect(dryOut, contains('mochilalista_v9.41_arm64_atp.apk'));
      expect(dryOut, contains('--target-platform android-arm64,android-arm'));
      expect(dryOut, contains('--obfuscate'));
      expect(dryOut, contains('--split-per-abi'));
      expect(dryOut, isNot(contains('storePassword')));
      expect(dryOut, isNot(contains('keyPassword')));
    });

    test(
        '2. --verify-only --no-pause sobre Biblioteca Oficial valida Universal ARM físico (< 95 MB) o rechaza x86_64 heredado en v9.41 intacto',
        () async {
      const offlineDir = r'C:\Users\vjuli\Documents\v-app-offline apks';
      final univFile = File('$offlineDir\\mochilalista_v9.41_atp.apk');
      final armFile = File('$offlineDir\\mochilalista_v9.41_arm64_atp.apk');
      if (!univFile.existsSync() || !armFile.existsSync()) {
        return;
      }

      final verRes = await _runBat(['--verify-only', '--no-pause']);
      final out = '${verRes.stdout}\n${verRes.stderr}';
      if (univFile.lengthSync() > 95 * 1024 * 1024) {
        expect(verRes.exitCode, isNot(equals(0)),
            reason:
                'Universal v9.41 heredado intacto contiene x86_64 y debe ser rechazado por la regla Fase 10.\n$out');
        expect(out, contains('x86_64'));
        expect(out, contains('QUÉ FALLÓ:'));
      } else {
        expect(verRes.exitCode, equals(0),
            reason: 'STDERR: ${verRes.stderr}\nSTDOUT: ${verRes.stdout}');
        expect(out, contains('[Paso 5/6]'));
        expect(out, contains('[Paso 6/6]'));
        expect(out, contains('mochilalista_v9.41_atp.apk'));
        expect(out, contains('mochilalista_v9.41_arm64_atp.apk'));
        expect(out, contains(_officialSignerSha256));
        expect(out, contains('CHECKLIST DE SIGUIENTES PASOS'));
      }
    });

    test(
        '3. Aislado en tempDir: SemVer patch==0 vs patch>0, formato apksigner SDK <=36 y SDK 37+, y cero fuga de secretos',
        () async {
      // 3A. Patch == 0 (9.41.0+85 -> v9.41) + SDK 37+ con SourceStamp distractor
      final dirA = Directory('${tempDir.path}\\caseA')..createSync();
      final envA = await _prepareIsolatedFixture(
        dirA,
        versionLine: '9.41.0+85',
        tag: '9.41',
        universalCode: 85,
        arm64Code: 2085,
        signerFormat: 'sdk37',
      );
      final resA = await _runBat(
        ['--verify-only', '--no-pause', '--out-dir', envA['outDir']!],
        environment: envA,
      );
      expect(resA.exitCode, equals(0),
          reason: 'STDOUT: ${resA.stdout}\nSTDERR: ${resA.stderr}');
      final outA = '${resA.stdout}\n${resA.stderr}';
      expect(outA, contains('mochilalista_v9.41_atp.apk'));
      expect(outA, contains('mochilalista_v9.41_arm64_atp.apk'));
      expect(outA, contains('75.00 %'));
      expect(outA, isNot(contains(_sentinelSecret)));
      expect(outA, isNot(contains('storePassword')));

      // 3B. Patch > 0 (9.41.2+87 -> v9.41.2) + SDK <= 36 (Signer #1)
      final dirB = Directory('${tempDir.path}\\caseB')..createSync();
      final envB = await _prepareIsolatedFixture(
        dirB,
        versionLine: '9.41.2+87',
        tag: '9.41.2',
        universalCode: 87,
        arm64Code: 2087,
        signerFormat: 'sdk36',
      );
      final resB = await _runBat(
        ['--verify-only', '--no-pause', '--out-dir', envB['outDir']!],
        environment: envB,
      );
      expect(resB.exitCode, equals(0),
          reason: 'STDOUT: ${resB.stdout}\nSTDERR: ${resB.stderr}');
      final outB = '${resB.stdout}\n${resB.stderr}';
      expect(outB, contains('mochilalista_v9.41.2_atp.apk'));
      expect(outB, contains('mochilalista_v9.41.2_arm64_atp.apk'));
      expect(outB, isNot(contains(_sentinelSecret)));
    });

    test(
        '4. Rechazos obligatorios con QUÉ FALLÓ + CÓMO SOLUCIONARLO: parámetro inválido, APKs faltantes, debuggable y firma ajena',
        () async {
      // 4A. Parámetro desconocido
      final badArgRes = await _runBat(['--flag-inventado', '--no-pause']);
      expect(badArgRes.exitCode, isNot(equals(0)));
      final badArgOut = '${badArgRes.stdout}\n${badArgRes.stderr}';
      expect(badArgOut, contains('QUÉ FALLÓ:'));
      expect(badArgOut, contains('CÓMO SOLUCIONARLO:'));

      // 4B. --verify-only sin APKs en outDir
      final dirMissing = Directory('${tempDir.path}\\missingApks')..createSync();
      final envMissing = await _prepareIsolatedFixture(
        dirMissing,
        versionLine: '9.41.0+85',
        tag: '9.41',
        universalCode: 85,
        arm64Code: 2085,
        createApks: false,
      );
      final missingRes = await _runBat(
        ['--verify-only', '--no-pause', '--out-dir', envMissing['outDir']!],
        environment: envMissing,
      );
      expect(missingRes.exitCode, isNot(equals(0)));
      final missingOut = '${missingRes.stdout}\n${missingRes.stderr}';
      expect(missingOut, contains('QUÉ FALLÓ:'));
      expect(missingOut, contains('CÓMO SOLUCIONARLO:'));
      expect(missingOut, isNot(contains(_sentinelSecret)));

      // 4C. APK con bandera application-debuggable -> aborta exit != 0
      final dirDebug = Directory('${tempDir.path}\\debugApk')..createSync();
      final envDebug = await _prepareIsolatedFixture(
        dirDebug,
        versionLine: '9.41.0+85',
        tag: '9.41',
        universalCode: 85,
        arm64Code: 2085,
        includeDebuggable: true,
      );
      final debugRes = await _runBat(
        ['--verify-only', '--no-pause', '--out-dir', envDebug['outDir']!],
        environment: envDebug,
      );
      expect(debugRes.exitCode, isNot(equals(0)));
      final debugOut = '${debugRes.stdout}\n${debugRes.stderr}';
      expect(debugOut, contains('application-debuggable'));
      expect(debugOut, contains('QUÉ FALLÓ:'));
      expect(debugOut, contains('CÓMO SOLUCIONARLO:'));
      expect(debugOut, isNot(contains(_sentinelSecret)));

      // 4D. APK con huella de firma ajena (posible debug keystore) -> aborta exit != 0
      final dirRogue = Directory('${tempDir.path}\\rogueSig')..createSync();
      final envRogue = await _prepareIsolatedFixture(
        dirRogue,
        versionLine: '9.41.0+85',
        tag: '9.41',
        universalCode: 85,
        arm64Code: 2085,
        signerShaOverride:
            '1111111111111111111111111111111111111111111111111111111111111111',
      );
      final rogueRes = await _runBat(
        ['--verify-only', '--no-pause', '--out-dir', envRogue['outDir']!],
        environment: envRogue,
      );
      expect(rogueRes.exitCode, isNot(equals(0)));
      final rogueOut = '${rogueRes.stdout}\n${rogueRes.stderr}';
      expect(rogueOut, contains('FIRMA NO OFICIAL'));
      expect(rogueOut, contains('QUÉ FALLÓ:'));
      expect(rogueOut, contains('CÓMO SOLUCIONARLO:'));
      expect(rogueOut, isNot(contains(_sentinelSecret)));

      // 4E. APK Universal con x86_64 -> aborta exit != 0
      final dirX86 = Directory('${tempDir.path}\\withX86')..createSync();
      final envX86 = await _prepareIsolatedFixture(
        dirX86,
        versionLine: '9.41.0+85',
        tag: '9.41',
        universalCode: 85,
        arm64Code: 2085,
        universalNativeCode: "'arm64-v8a' 'armeabi-v7a' 'x86_64'",
      );
      final x86Res = await _runBat(
        ['--verify-only', '--no-pause', '--out-dir', envX86['outDir']!],
        environment: envX86,
      );
      expect(x86Res.exitCode, isNot(equals(0)));
      final x86Out = '${x86Res.stdout}\n${x86Res.stderr}';
      expect(x86Out, contains('x86_64'));
      expect(x86Out, contains('QUÉ FALLÓ:'));

      // 4F. APK Universal sin armeabi-v7a -> aborta exit != 0
      final dirNoArmV7 = Directory('${tempDir.path}\\missingArmV7')
        ..createSync();
      final envNoArmV7 = await _prepareIsolatedFixture(
        dirNoArmV7,
        versionLine: '9.41.0+85',
        tag: '9.41',
        universalCode: 85,
        arm64Code: 2085,
        universalNativeCode: "'arm64-v8a'",
      );
      final noArmV7Res = await _runBat(
        ['--verify-only', '--no-pause', '--out-dir', envNoArmV7['outDir']!],
        environment: envNoArmV7,
      );
      expect(noArmV7Res.exitCode, isNot(equals(0)));
      final noArmV7Out = '${noArmV7Res.stdout}\n${noArmV7Res.stderr}';
      expect(noArmV7Out, contains('armeabi-v7a'));
      expect(noArmV7Out, contains('QUÉ FALLÓ:'));
    });
  });
}
