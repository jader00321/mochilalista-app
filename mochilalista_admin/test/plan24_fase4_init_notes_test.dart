import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

bool _hasUtf8Bom(List<int> bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
}

Future<Map<String, String>> _prepareIsolatedFixture(
  Directory baseDir, {
  required String versionLine,
  required String tag,
  required int universalCode,
  required int arm64Code,
}) async {
  final pubspec = File('${baseDir.path}\\pubspec.yaml')
    ..writeAsStringSync('name: app_movil\nversion: $versionLine\n');
  File('${baseDir.path}\\test-release.jks').writeAsStringSync('FAKE_JKS_BYTES');
  final keyProps = File('${baseDir.path}\\key.properties')
    ..writeAsStringSync(
      'storePassword=$_sentinelSecret\n'
      'keyPassword=${_sentinelSecret}_KEY\n'
      'keyAlias=mochilalista-key\n'
      'storeFile=test-release.jks\n',
    );
  final outDir = Directory('${baseDir.path}\\out_apks')
    ..createSync(recursive: true);

  final univApk = File('${outDir.path}\\mochilalista_v${tag}_atp.apk')
    ..writeAsBytesSync(List<int>.filled(4096, 0x55));
  final armApk = File('${outDir.path}\\mochilalista_v${tag}_arm64_atp.apk')
    ..writeAsBytesSync(List<int>.filled(1024, 0x41));

  final univSha =
      sha256.convert(univApk.readAsBytesSync()).toString().toLowerCase();
  final armSha =
      sha256.convert(armApk.readAsBytesSync()).toString().toLowerCase();

  final verName = versionLine.split('+').first;
  final mockAapt2 = File('${baseDir.path}\\mock_aapt2.cmd')
    ..writeAsStringSync(
      '@echo off\r\n'
      'set "APK=%~3"\r\n'
      'echo %APK% | findstr /i "arm64" >nul\r\n'
      'if %errorlevel%==0 (\r\n'
      '  echo package: name=\'com.mochilalista.app\' versionCode=\'$arm64Code\' versionName=\'$verName\'\r\n'
      '  echo sdkVersion:\'24\'\r\n'
      '  echo targetSdkVersion:\'36\'\r\n'
      '  echo native-code: \'arm64-v8a\'\r\n'
      ') else (\r\n'
      '  echo package: name=\'com.mochilalista.app\' versionCode=\'$universalCode\' versionName=\'$verName\'\r\n'
      '  echo sdkVersion:\'24\'\r\n'
      '  echo targetSdkVersion:\'36\'\r\n'
      '  echo native-code: \'arm64-v8a\' \'armeabi-v7a\' \'x86_64\'\r\n'
      ')\r\n'
      'exit /b 0\r\n',
    );

  final mockSigner = File('${baseDir.path}\\mock_apksigner.cmd')
    ..writeAsStringSync(
      '@echo off\r\n'
      'echo Verifies\r\n'
      'echo Verified using v2 scheme (APK Signature Scheme v2): true\r\n'
      'echo V2 Signer: certificate DN: CN=Julio Angello Vasquez Navarro, OU=MochilaLista Core Development, C=PE\r\n'
      'echo V2 Signer: certificate SHA-256 digest: $_officialSignerSha256\r\n'
      'exit /b 0\r\n',
    );

  return {
    'ML_DUAL_PUBSPEC_PATH': pubspec.path,
    'ML_DUAL_KEY_PROPERTIES_PATH': keyProps.path,
    'ML_DUAL_AAPT2_PATH': mockAapt2.path,
    'ML_DUAL_APKSIGNER_PATH': mockSigner.path,
    'outDir': outDir.path,
    'univSha': univSha,
    'armSha': armSha,
  };
}

void main() {
  group('PLAN MAESTRO 24 - FASE 4: Flag --init-notes No Destructivo en Compilador Dual',
      () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ml_p24_fase4_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        '1. --help documenta --init-notes y --dry-run --init-notes simula sin crear archivos en disco',
        () async {
      final helpRes = await _runBat(['--help', '--no-pause']);
      expect(helpRes.exitCode, equals(0),
          reason: 'STDERR: ${helpRes.stderr}\nSTDOUT: ${helpRes.stdout}');
      final helpOut = helpRes.stdout.toString();
      expect(helpOut, contains('--init-notes'));
      expect(
        helpOut,
        contains('compilar_release_dual.bat --verify-only --init-notes --no-pause'),
      );

      final fix = await _prepareIsolatedFixture(
        tempDir,
        versionLine: '9.42.0+86',
        tag: '9.42',
        universalCode: 86,
        arm64Code: 2086,
      );
      final outDir = fix['outDir']!;
      final env = {
        'ML_DUAL_PUBSPEC_PATH': fix['ML_DUAL_PUBSPEC_PATH']!,
        'ML_DUAL_KEY_PROPERTIES_PATH': fix['ML_DUAL_KEY_PROPERTIES_PATH']!,
        'ML_DUAL_AAPT2_PATH': fix['ML_DUAL_AAPT2_PATH']!,
        'ML_DUAL_APKSIGNER_PATH': fix['ML_DUAL_APKSIGNER_PATH']!,
      };

      final dryRes = await _runBat(
        ['--dry-run', '--init-notes', '--no-pause', '--out-dir', outDir],
        environment: env,
      );
      expect(dryRes.exitCode, equals(0),
          reason: 'STDERR: ${dryRes.stderr}\nSTDOUT: ${dryRes.stdout}');
      final dryOut = dryRes.stdout.toString();
      expect(dryOut, contains('--init-notes'));
      expect(dryOut, contains('mochilalista_v9.42_atp.txt'));
      expect(dryOut, contains('mochilalista_v9.42_atp_cambios.txt'));
      expect(File('$outDir\\mochilalista_v9.42_atp.txt').existsSync(), isFalse);
      expect(
        File('$outDir\\mochilalista_v9.42_atp_cambios.txt').existsSync(),
        isFalse,
      );
    });

    test(
        '2. --verify-only --init-notes crea ambas notas en UTF-8 sin BOM cuando faltan, con métricas reales y 0 secretos',
        () async {
      final fix = await _prepareIsolatedFixture(
        tempDir,
        versionLine: '9.42.0+86',
        tag: '9.42',
        universalCode: 86,
        arm64Code: 2086,
      );
      final outDir = fix['outDir']!;
      final env = {
        'ML_DUAL_PUBSPEC_PATH': fix['ML_DUAL_PUBSPEC_PATH']!,
        'ML_DUAL_KEY_PROPERTIES_PATH': fix['ML_DUAL_KEY_PROPERTIES_PATH']!,
        'ML_DUAL_AAPT2_PATH': fix['ML_DUAL_AAPT2_PATH']!,
        'ML_DUAL_APKSIGNER_PATH': fix['ML_DUAL_APKSIGNER_PATH']!,
      };

      final res = await _runBat(
        ['--verify-only', '--init-notes', '--no-pause', '--out-dir', outDir],
        environment: env,
      );
      expect(res.exitCode, equals(0),
          reason: 'STDERR: ${res.stderr}\nSTDOUT: ${res.stdout}');
      final out = res.stdout.toString();
      expect(out, contains('Creada plantilla técnica en UTF-8 sin BOM'));
      expect(out, contains('Creada plantilla de cambios en UTF-8 sin BOM'));
      expect(out, isNot(contains(_sentinelSecret)));

      final atpFile = File('$outDir\\mochilalista_v9.42_atp.txt');
      final chgFile = File('$outDir\\mochilalista_v9.42_atp_cambios.txt');
      expect(atpFile.existsSync(), isTrue);
      expect(chgFile.existsSync(), isTrue);

      final atpBytes = atpFile.readAsBytesSync();
      final chgBytes = chgFile.readAsBytesSync();
      expect(_hasUtf8Bom(atpBytes), isFalse,
          reason: '*_atp.txt no debe tener BOM UTF-8');
      expect(_hasUtf8Bom(chgBytes), isFalse,
          reason: '*_atp_cambios.txt no debe tener BOM UTF-8');

      final atpText = utf8.decode(atpBytes);
      final chgText = utf8.decode(chgBytes);

      expect(atpText, contains('v9.42.0+86'));
      expect(atpText, contains('America/Lima GMT-5'));
      expect(atpText, contains('4,096 bytes'));
      expect(atpText, contains('1,024 bytes'));
      expect(atpText, contains('-75.00 %'));
      expect(atpText, contains(fix['univSha']!));
      expect(atpText, contains(fix['armSha']!));
      expect(atpText, contains(_officialSignerSha256));
      expect(atpText, contains('Target SDK: 36 | Min SDK: 24'));
      expect(atpText, contains('SQLite: v36'));
      expect(atpText, contains('application-debuggable AUSENTE'));
      expect(atpText, isNot(contains(_sentinelSecret)));
      expect(atpText, isNot(contains('storePassword')));
      expect(atpText, isNot(contains('keyPassword')));

      expect(chgText, contains('• '));
      expect(chgText, contains('v9.42.0'));
      expect(chgText, isNot(contains(_sentinelSecret)));

      // Cero emojis crudos en ambas plantillas
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      expect(emojiRegex.hasMatch(atpText), isFalse);
      expect(emojiRegex.hasMatch(chgText), isFalse);
    });

    test(
        '3. --verify-only --init-notes jamás sobrescribe archivos existentes y reporta Ya existe en disco — respetada sin sobrescribir',
        () async {
      final fix = await _prepareIsolatedFixture(
        tempDir,
        versionLine: '9.42.0+86',
        tag: '9.42',
        universalCode: 86,
        arm64Code: 2086,
      );
      final outDir = fix['outDir']!;
      final env = {
        'ML_DUAL_PUBSPEC_PATH': fix['ML_DUAL_PUBSPEC_PATH']!,
        'ML_DUAL_KEY_PROPERTIES_PATH': fix['ML_DUAL_KEY_PROPERTIES_PATH']!,
        'ML_DUAL_AAPT2_PATH': fix['ML_DUAL_AAPT2_PATH']!,
        'ML_DUAL_APKSIGNER_PATH': fix['ML_DUAL_APKSIGNER_PATH']!,
      };

      final atpFile = File('$outDir\\mochilalista_v9.42_atp.txt')
        ..writeAsStringSync('NOTA TÉCNICA PERSONALIZADA DEL PROPIETARIO\r\nNo sobrescribir.\r\n');
      final chgFile = File('$outDir\\mochilalista_v9.42_atp_cambios.txt')
        ..writeAsStringSync('• Mi cambio personalizado de cliente.\r\n');

      final beforeAtpHash = sha256.convert(atpFile.readAsBytesSync()).toString();
      final beforeChgHash = sha256.convert(chgFile.readAsBytesSync()).toString();

      final res = await _runBat(
        ['--verify-only', '--init-notes', '--no-pause', '--out-dir', outDir],
        environment: env,
      );
      expect(res.exitCode, equals(0),
          reason: 'STDERR: ${res.stderr}\nSTDOUT: ${res.stdout}');
      final out = res.stdout.toString();

      expect(
        'Ya existe en disco — respetada sin sobrescribir'
            .allMatches(out)
            .length,
        equals(2),
      );
      expect(
        sha256.convert(atpFile.readAsBytesSync()).toString(),
        equals(beforeAtpHash),
      );
      expect(
        sha256.convert(chgFile.readAsBytesSync()).toString(),
        equals(beforeChgHash),
      );
    });

    test(
        '4. Integridad BOM: compilar_release_dual.ps1 conserva UTF-8 BOM (EF BB BF) y Plan 24 v1.4 sin BOM',
        () {
      final root = _repoRootPath();
      final ps1Bytes =
          File('$root/scripts/compilar_release_dual.ps1').readAsBytesSync();
      expect(_hasUtf8Bom(ps1Bytes), isTrue,
          reason: 'scripts/compilar_release_dual.ps1 DEBE conservar BOM UTF-8');

      final plan24Bytes = File(
        '$root/informe_proyecto/24_PLAN_MAESTRO_REPARACION_MLC1_QR_EXPORT_DART_Y_INIT_NOTES.md',
      ).readAsBytesSync();
      expect(_hasUtf8Bom(plan24Bytes), isFalse,
          reason: '24_PLAN_MAESTRO_...md NO debe llevar BOM UTF-8');
    });
  });
}
