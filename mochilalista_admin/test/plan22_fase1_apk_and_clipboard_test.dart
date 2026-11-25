import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

import '../lib/apk_inspector_service.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';
import 'apk_inspector_and_releases_test.dart' show createTestZip;

void main() {
  group('PLAN MAESTRO 22 - FASE 1: Backend APK 37+, Dedup, Verify, Portapapeles -STA y Nonces', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p22_fase1_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. Parser apksigner Build-Tools 37.0.0+ vs 36.1.0 + SourceStamp + 3 Estados Honestos
    // =========================================================================
    test('1. apksigner Build-Tools 37+ (V2 Signer:), SourceStamp excluido y 3 estados honestos', () async {
      final officialSha = ApkInspectorService.officialSignerSha256;
      final dummySdk = Directory('${tempDir.path}/sdk/37.0.0')..createSync(recursive: true);
      final exeName = Platform.isWindows ? 'apksigner.bat' : 'apksigner';
      await File('${dummySdk.path}/$exeName').writeAsString('echo mock');

      final apk = File('${tempDir.path}/mochilalista_v9.40_atp.apk');
      await apk.writeAsBytes(createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/libapp.so']));

      // A) Salida real Build-Tools 37.0.0 (incluyendo línea SourceStamp distractiva)
      final inspector37 = ApkInspectorService(
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('apksigner')) {
            return ProcessResult(
              1,
              0,
              '''
Verifies
Verified using v2 scheme (APK Signature Scheme v2): true
Verified for SourceStamp: true
Number of signers: 1
SourceStamp Signer: certificate SHA-256 digest: 0000000000000000000000000000000000000000000000000000000000000000
V2 Signer: certificate DN: CN=Julio Angello Vasquez Navarro, OU=MochilaLista Core Development, O=MochilaLista, L=Piura, ST=Piura, C=PE
V2 Signer: certificate SHA-256 digest: $officialSha
V2 Signer: public key SHA-256 digest: acfbf0b7fafd956c7d7eee56e9d4eaffc9191f6f44e61346fc2a8377bd647426
''',
              '',
            );
          }
          return ProcessResult(2, 1, '', 'no aapt2');
        },
      );

      final res37 = await inspector37.inspectApk(apk);
      expect(res37.signatureStatus, equals('OFFICIAL_RELEASE'));
      expect(res37.signatureVerified, isTrue);
      expect(res37.signerSha256, equals(officialSha));
      expect(res37.signerDn, contains('Julio Angello Vasquez Navarro'));
      expect(res37.suggestedReleaseType, equals('FEATURE_RELEASE'));

      // B) Build-Tools <=36 (Signer #1 ...) con firma NO oficial -> UNOFFICIAL_SIGNATURE (false)
      final inspectorDebug = ApkInspectorService(
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('apksigner')) {
            return ProcessResult(
              1,
              0,
              'Signer #1 certificate DN: CN=Android Debug, O=Android\n'
              'Signer #1 certificate SHA-256 digest: aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899\n',
              '',
            );
          }
          return ProcessResult(2, 1, '', 'no aapt2');
        },
      );

      final resDebug = await inspectorDebug.inspectApk(apk);
      expect(resDebug.signatureStatus, equals('UNOFFICIAL_SIGNATURE'));
      expect(resDebug.signatureVerified, isFalse);

      // C) Tool salió 0 sin emitir SHA-256 legible -> UNVERIFIED (null), NUNCA debug.apk
      final inspectorUnparseable = ApkInspectorService(
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('apksigner')) {
            return ProcessResult(1, 0, 'Verifies\nOutput truncated without cert digest\n', '');
          }
          return ProcessResult(2, 1, '', 'no aapt2');
        },
      );

      final resUnparseable = await inspectorUnparseable.inspectApk(apk);
      expect(resUnparseable.signatureStatus, equals('UNVERIFIED'));
      expect(resUnparseable.signatureVerified, isNull);
      expect(resUnparseable.signatureDetail, isNotEmpty);

      // D) Sin herramienta en SDK -> UNVERIFIED (null)
      final inspectorNoSdk = ApkInspectorService(sdkSearchRootsOverride: const []);
      final resNoSdk = await inspectorNoSdk.inspectApk(apk);
      expect(resNoSdk.signatureStatus, equals('UNVERIFIED'));
      expect(resNoSdk.signatureVerified, isNull);
    });

    // =========================================================================
    // 2. Canonicalización de rutas, dedup SHA-256, SemVer y lectura dual .txt
    // =========================================================================
    test('2. Canonicalización sin .., deduplicación SHA-256, SemVer HOTFIX/FEATURE y notas *_atp.txt', () async {
      final libDir = Directory('${tempDir.path}/v-app-offline apks')..createSync(recursive: true);
      final buildDir = Directory('${tempDir.path}/app_movil/build/app/outputs/flutter-apk')
        ..createSync(recursive: true);

      final bytesSame = createTestZip(['AndroidManifest.xml', 'classes.dex']);
      final bytesPatch = createTestZip(['AndroidManifest.xml', 'assets/hotfix.txt']);

      final libApk = File('${libDir.path}/mochilalista_v9.40_atp.apk');
      await libApk.writeAsBytes(bytesSame);
      final buildApk = File('${buildDir.path}/app-release.apk');
      await buildApk.writeAsBytes(bytesSame);

      final patchApk = File('${libDir.path}/mochilalista_v9.40.1_atp.apk');
      await patchApk.writeAsBytes(bytesPatch);

      // Notas compañeras UTF-8 (comerciales + ingeniería técnica)
      await File('${libDir.path}/mochilalista_v9.40_atp_cambios.txt')
          .writeAsString('• Mejora comercial v9.40\n• Nuevo catálogo');
      await File('${libDir.path}/mochilalista_v9.40_atp.txt')
          .writeAsString('FICHA TÉCNICA v9.40.0+84\nOfuscación activada y zero issues.');

      // Normalización de rutas con segmentos ..
      final messyBuildDir = Directory('${libDir.path}/../app_movil/build/app/outputs/flutter-apk');
      final canon = ApkInspectorService.canonicalizePath(messyBuildDir.path);
      expect(canon.contains('..'), isFalse);

      final inspector = ApkInspectorService(
        sdkSearchRootsOverride: const [],
        processRunnerOverride: (cmd, args) async => ProcessResult(1, 1, '', 'no tools'),
      );

      final detected = await inspector.detectLocalApks(
        apkLibraryDir: libDir,
        buildOutputDir: messyBuildDir,
      );

      // 3 archivos en disco -> 2 únicos tras deduplicar el binario idéntico
      expect(detected.length, equals(2));

      final v940 = detected.firstWhere((r) => r.versionName == '9.40.0');
      expect(v940.sourceLabel, contains('Biblioteca Oficial'));
      expect(v940.filePath.contains('..'), isFalse);
      expect(v940.duplicatePaths, hasLength(1));
      expect(v940.suggestedReleaseType, equals('FEATURE_RELEASE'));
      expect(v940.suggestedChangelog, contains('Mejora comercial v9.40'));
      expect(v940.suggestedInternalNotes, contains('FICHA TÉCNICA v9.40.0+84'));

      final v9401 = detected.firstWhere((r) => r.versionName == '9.40.1');
      expect(v9401.suggestedReleaseType, equals('HOTFIX'));
    });

    // =========================================================================
    // 3. Constructor seguro de comando PowerShell CF_HDROP (-STA + System.Windows.Forms)
    // =========================================================================
    test('3. Command builder Windows clipboard usa -STA, System.Windows.Forms y escapa comillas', () {
      final args = buildWindowsClipboardPsArgs(r"C:\Temp\O'Brien APKs\mochilalista_v9.40_atp.apk");
      expect(args, contains('-NoProfile'));
      expect(args, contains('-STA'));
      final script = args.last;
      expect(script, contains('Add-Type -AssemblyName System.Windows.Forms'));
      expect(script, contains(r"C:\Temp\O''Brien APKs\mochilalista_v9.40_atp.apk"));
      expect(script, contains('Test-Path -LiteralPath'));
      expect(script, contains('SetFileDropList'));
      expect(script, contains('Preferred DropEffect'));
      expect(script, contains('SetDataObject(\$dataObj, \$true, 10, 50)'));
    });

    // =========================================================================
    // 4. Endpoints HTTP: verify, companion-notes, import-local (con ..), mark-updated force y nonces inspect
    // =========================================================================
    test('4. HTTP Endpoints: verify, companion-notes, import con .., mark-updated force y nonces inspect', () async {
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final libDir = Directory('${tempDir.path}/apk_lib')..createSync(recursive: true);

      final db = DatabaseService(dataDir: dataDir.path, backupDir: backupsDir.path, releasesDir: releasesDir);
      await db.init();

      final config = ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await config.init();
      await config.saveConfig({'apk_library_dir': libDir.path});

      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 9 + 1) % 256);
      await signer.initWithSeed(testSeed);

      final excel = ExcelExportService(dbService: db, configService: config);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dbService: db,
        configService: config,
        signer: signer,
      );
      await vault.initialize();

      // Crear SDK mock con firma oficial Build-Tools 37.0.0
      final sdkDir = Directory('${tempDir.path}/sdk/37.0.0')..createSync(recursive: true);
      final exeName = Platform.isWindows ? 'apksigner.bat' : 'apksigner';
      await File('${sdkDir.path}/$exeName').writeAsString('echo mock');

      final inspector = ApkInspectorService(
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        defaultBuildOutputDir: Directory('${tempDir.path}/empty_build')..createSync(recursive: true),
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('apksigner')) {
            return ProcessResult(
              1,
              0,
              'V2 Signer: certificate DN: CN=Julio Angello Vasquez Navarro\n'
              'V2 Signer: certificate SHA-256 digest: ${ApkInspectorService.officialSignerSha256}\n',
              '',
            );
          }
          return ProcessResult(2, 1, '', 'no aapt2');
        },
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
            apkInspectorService: inspector,
            onCopyFileOverride: (_) async => true,
          ));

      final httpClient = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';

      try {
        // Preparar APK + notas en biblioteca y subcarpeta para probar ruta con ..
        final subFolder = Directory('${libDir.path}/sub')..createSync(recursive: true);
        final apkOnDisk = File('${libDir.path}/mochilalista_v9.40_atp.apk');
        await apkOnDisk.writeAsBytes(createTestZip(['AndroidManifest.xml', 'assets/a.txt']));
        await File('${libDir.path}/mochilalista_v9.40_atp_cambios.txt').writeAsString('• Cambio comercial 9.40');
        await File('${libDir.path}/mochilalista_v9.40_atp.txt').writeAsString('Notas ingeniería 9.40');

        // A) Import-local-apk con segmentos .. debe normalizarse y resolver 200 OK
        final messyApkPath = '${subFolder.path}${Platform.pathSeparator}..${Platform.pathSeparator}mochilalista_v9.40_atp.apk';
        final impReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/releases/import-local-apk'));
        impReq.headers.contentType = ContentType.json;
        impReq.write(jsonEncode({'source_path': messyApkPath}));
        final impRes = await impReq.close();
        expect(impRes.statusCode, equals(200));
        final impJson = jsonDecode(await utf8.decodeStream(impRes)) as Map<String, dynamic>;
        expect(impJson['ok'], isTrue);
        expect(impJson['signature_status'], equals('OFFICIAL_RELEASE'));
        expect(impJson['signature_verified'], isTrue);
        expect(impJson['suggested_internal_notes'], contains('Notas ingeniería 9.40'));

        // B) Release legacy guardado "Sin Verificar" -> POST /verify debe verificar firma, tamaño y devolver notas
        await db.createRelease({
          'version_name': '9.40.0',
          'version_code': 84,
          'type': 'FEATURE_RELEASE',
          'apk_file_path': apkOnDisk.path,
          'file_size_mb': '',
          'signature_status': 'UNVERIFIED',
          'signature_verified': null,
        });

        final verReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/releases/9.40.0/verify'));
        final verRes = await verReq.close();
        expect(verRes.statusCode, equals(200));
        final verJson = jsonDecode(await utf8.decodeStream(verRes)) as Map<String, dynamic>;
        expect(verJson['ok'], isTrue);
        expect(verJson['file_exists'], isTrue);
        expect(verJson['release']['signature_status'], equals('OFFICIAL_RELEASE'));
        expect(verJson['release']['signature_verified'], isTrue);
        expect(verJson['release']['file_size_mb'], endsWith(' MB'));
        expect(verJson['suggested_changelog'], contains('Cambio comercial 9.40'));
        expect(verJson['suggested_internal_notes'], contains('Notas ingeniería 9.40'));

        // C) GET companion-notes
        final notesReq = await httpClient.getUrl(Uri.parse('$baseUrl/api/releases/9.40.0/companion-notes'));
        final notesRes = await notesReq.close();
        expect(notesRes.statusCode, equals(200));
        final notesJson = jsonDecode(await utf8.decodeStream(notesRes)) as Map<String, dynamic>;
        expect(notesJson['suggested_changelog'], contains('Cambio comercial 9.40'));
        expect(notesJson['suggested_internal_notes'], contains('Notas ingeniería 9.40'));

        // D) mark-updated con force: false (no degrada) vs force: true (corrige y guarda previous_installed_version)
        final cli = await db.createClient({
          'business_name': 'Luzam Test',
          'owner_name': 'Angello',
          'phone': '922836879',
          'current_device_id': 'ML-379E',
          'installed_version': '9.40.0',
          'license_type': 'TRIAL',
        });
        final cid = cli['id'] as String;

        final noForceReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/clients/$cid/mark-updated'));
        noForceReq.headers.contentType = ContentType.json;
        noForceReq.write(jsonEncode({'version_name': '9.32.0', 'force': false}));
        final noForceRes = await noForceReq.close();
        final noForceJson = jsonDecode(await utf8.decodeStream(noForceRes)) as Map<String, dynamic>;
        expect(noForceJson['installed_version'], equals('9.40.0'));

        final forceReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/clients/$cid/mark-updated'));
        forceReq.headers.contentType = ContentType.json;
        forceReq.write(jsonEncode({'version_name': '9.32.0', 'force': true}));
        final forceRes = await forceReq.close();
        final forceJson = jsonDecode(await utf8.decodeStream(forceRes)) as Map<String, dynamic>;
        expect(forceJson['installed_version'], equals('9.32.0'));
        expect(forceJson['previous_installed_version'], equals('9.40.0'));
        expect(forceJson['force_applied'], isTrue);

        // E) Enriquecimiento de matching_client en POST /api/licenses/inspect con next_nonce y ultimo_nonce
        final token = await signer.generateLicenseToken(
          deviceFingerprint: 'ML-379E',
          plan: 'BONO_IA_PERSONALIZADO',
          daysToAdd: 0,
          nonce: 1,
          aiExtraCredits: 20,
        );
        await db.recordCodeEmission(
          clientId: cid,
          token: token,
          plan: 'BONO_IA_PERSONALIZADO',
          daysToAdd: 0,
          paymentAmount: 0,
          paymentMethod: 'Cortesía',
          paymentRef: 'REF-1',
          updatesUntil: null,
          aiExtraCredits: 20,
        );
        await db.applyClientSyncSnapshot(cid, {
          'v': 1,
          'hw': 'ML-379E',
          'n': 1,
          'ai': 69,
          'aiu': 12,
          'av': '9.38.0',
          'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
        });

        final inspReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/licenses/inspect'));
        inspReq.headers.contentType = ContentType.json;
        inspReq.write(jsonEncode({'token': token}));
        final inspRes = await inspReq.close();
        expect(inspRes.statusCode, equals(200));
        final inspJson = jsonDecode(await utf8.decodeStream(inspRes)) as Map<String, dynamic>;
        expect(inspJson['valid'], isTrue);
        final mc = inspJson['matching_client'] as Map<String, dynamic>?;
        expect(mc, isNotNull);
        expect(mc!['next_nonce'], equals(2));
        expect(mc['ultimo_nonce'], equals(1));
        expect(mc['last_sync_at'], isNotNull);
        expect(mc['ai_reported_balance'], equals(69));
        expect(mc['ai_credits_used_total'], equals(12));
      } finally {
        httpClient.close(force: true);
        await server.close(force: true);
      }
    });
  });
}
