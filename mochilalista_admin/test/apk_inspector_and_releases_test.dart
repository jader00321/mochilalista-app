import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';

import '../lib/apk_inspector_service.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';

/// Helper para generar archivos ZIP válidos en memoria con entradas arbitrarias
List<int> createTestZip(List<String> entryNames) {
  final out = BytesBuilder();
  final centralDir = BytesBuilder();
  int localOffset = 0;

  for (final name in entryNames) {
    final nameBytes = utf8.encode(name);
    final data = utf8.encode('fake-binary-content-for-$name');
    final crc = 0;

    final localHeader = BytesBuilder();
    localHeader.add([0x50, 0x4B, 0x03, 0x04]);
    localHeader.add([20, 0]);
    localHeader.add([0, 0]);
    localHeader.add([0, 0]);
    localHeader.add([0, 0, 0, 0]);
    localHeader.add([
      crc & 0xFF,
      (crc >> 8) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 24) & 0xFF
    ]);
    localHeader.add([data.length & 0xFF, (data.length >> 8) & 0xFF, 0, 0]);
    localHeader.add([data.length & 0xFF, (data.length >> 8) & 0xFF, 0, 0]);
    localHeader.add([nameBytes.length & 0xFF, (nameBytes.length >> 8) & 0xFF]);
    localHeader.add([0, 0]);
    localHeader.add(nameBytes);
    localHeader.add(data);

    final localBlock = localHeader.takeBytes();
    out.add(localBlock);

    centralDir.add([0x50, 0x4B, 0x01, 0x02]);
    centralDir.add([20, 0]);
    centralDir.add([20, 0]);
    centralDir.add([0, 0]);
    centralDir.add([0, 0]);
    centralDir.add([0, 0, 0, 0]);
    centralDir.add([
      crc & 0xFF,
      (crc >> 8) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 24) & 0xFF
    ]);
    centralDir.add([data.length & 0xFF, (data.length >> 8) & 0xFF, 0, 0]);
    centralDir.add([data.length & 0xFF, (data.length >> 8) & 0xFF, 0, 0]);
    centralDir.add([nameBytes.length & 0xFF, (nameBytes.length >> 8) & 0xFF]);
    centralDir.add([0, 0]);
    centralDir.add([0, 0]);
    centralDir.add([0, 0]);
    centralDir.add([0, 0]);
    centralDir.add([0, 0, 0, 0]);
    centralDir.add([
      localOffset & 0xFF,
      (localOffset >> 8) & 0xFF,
      (localOffset >> 16) & 0xFF,
      (localOffset >> 24) & 0xFF,
    ]);
    centralDir.add(nameBytes);

    localOffset += localBlock.length;
  }

  final cdBytes = centralDir.takeBytes();
  final cdOffset = out.length;
  out.add(cdBytes);

  final eocd = BytesBuilder();
  eocd.add([0x50, 0x4B, 0x05, 0x06]);
  eocd.add([0, 0]);
  eocd.add([0, 0]);
  eocd.add([entryNames.length & 0xFF, (entryNames.length >> 8) & 0xFF]);
  eocd.add([entryNames.length & 0xFF, (entryNames.length >> 8) & 0xFF]);
  eocd.add([
    cdBytes.length & 0xFF,
    (cdBytes.length >> 8) & 0xFF,
    (cdBytes.length >> 16) & 0xFF,
    (cdBytes.length >> 24) & 0xFF,
  ]);
  eocd.add([
    cdOffset & 0xFF,
    (cdOffset >> 8) & 0xFF,
    (cdOffset >> 16) & 0xFF,
    (cdOffset >> 24) & 0xFF,
  ]);
  eocd.add([0, 0]);
  out.add(eocd.takeBytes());

  return out.takeBytes();
}

void main() {
  group('FASE 1 - Plan Maestro 19: Reingeniería del Gestor de Versiones APK',
      () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p19_fase1_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. Detección de Arquitectura / ABI en ZIP en Dart puro
    // =========================================================================
    test('1. ABI Detection en ZIP puro: ARM64 vs UNIVERSAL vs sin lib/',
        () async {
      final inspector = ApkInspectorService(
        processRunnerOverride: (cmd, args) async =>
            ProcessResult(1, 1, '', 'not used'),
      );

      // ARM64 exclusivo
      final arm64File = File('${tempDir.path}/app-arm64.apk');
      await arm64File.writeAsBytes(
          createTestZip(['lib/arm64-v8a/libapp.so', 'AndroidManifest.xml']));
      final resArm64 = await inspector.inspectApk(arm64File);
      expect(resArm64.abiVariant, equals('ARM64'));

      // Universal (múltiples arquitecturas)
      final univFile = File('${tempDir.path}/app-universal.apk');
      await univFile.writeAsBytes(createTestZip([
        'lib/arm64-v8a/libapp.so',
        'lib/armeabi-v7a/libapp.so',
        'AndroidManifest.xml'
      ]));
      final resUniv = await inspector.inspectApk(univFile);
      expect(resUniv.abiVariant, equals('UNIVERSAL'));

      // Sin carpeta lib/ -> Universal
      final noLibFile = File('${tempDir.path}/app-no-lib.apk');
      await noLibFile.writeAsBytes(
          createTestZip(['assets/index.html', 'AndroidManifest.xml']));
      final resNoLib = await inspector.inspectApk(noLibFile);
      expect(resNoLib.abiVariant, equals('UNIVERSAL'));
    });

    // =========================================================================
    // 2. Escudo Anti-debug.apk y Certificación Criptográfica (apksigner mock)
    // =========================================================================
    test(
        '2. Escudo Anti-debug.apk: Verificado Oficial vs No Oficial vs Sin Herramienta',
        () async {
      final officialSha = ApkInspectorService.officialSignerSha256;

      // Mock Oficial
      final officialInspector = ApkInspectorService(
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('apksigner')) {
            return ProcessResult(
              1,
              0,
              'Signer #1 certificate SHA-256 digest: $officialSha\n'
                  'Signer #1 certificate DN: CN=Julio Angello Vasquez Navarro, O=MochilaLista\n',
              '',
            );
          }
          return ProcessResult(2, 1, '', 'tool not found');
        },
      );

      final officialApk = File('${tempDir.path}/mochilalista_v9.38.0.apk');
      await officialApk.writeAsBytes(createTestZip(['AndroidManifest.xml']));
      final offResult = await officialInspector.inspectApk(officialApk);
      expect(offResult.signatureStatus, equals('OFFICIAL_RELEASE'));
      expect(offResult.signatureVerified, isTrue);
      expect(offResult.signerSha256, equals(officialSha));

      // Mock Unofficial (ej. Debug Keystore)
      final debugSha =
          'a1b2c3d4e5f600112233445566778899aabbccddeeff00112233445566778899';
      final unofficialInspector = ApkInspectorService(
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('apksigner')) {
            return ProcessResult(
              1,
              0,
              'Signer #1 certificate SHA-256 digest: $debugSha\n'
                  'Signer #1 certificate DN: CN=Android Debug, O=Android\n',
              '',
            );
          }
          return ProcessResult(2, 1, '', 'tool not found');
        },
      );
      final unoffResult = await unofficialInspector.inspectApk(officialApk);
      expect(unoffResult.signatureStatus, equals('UNOFFICIAL_SIGNATURE'));
      expect(unoffResult.signatureVerified, isFalse);

      // Mock sin apksigner disponible
      final noToolInspector = ApkInspectorService(
        processRunnerOverride: (cmd, args) async {
          throw const ProcessException('apksigner', [], 'Executable not found');
        },
      );
      final noToolResult = await noToolInspector.inspectApk(officialApk);
      expect(noToolResult.signatureStatus, equals('UNVERIFIED'));
      expect(noToolResult.signatureVerified, isNull);
    });

    // =========================================================================
    // 3. Introspección aapt2 + Fallback Determinista y Lectura de *_cambios.txt
    // =========================================================================
    test(
        '3. aapt2 parsea metadatos y fallback por nombre lee cambios.txt compañero',
        () async {
      // Mock con aapt2 exitoso
      final aaptInspector = ApkInspectorService(
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('aapt2')) {
            return ProcessResult(
              1,
              0,
              "package: name='com.mochilalista.app' versionCode='82' versionName='9.38.0' compileSdkVersion='34'\n"
                  "sdkVersion:'21'\ntargetSdkVersion:'34'\n",
              '',
            );
          }
          return ProcessResult(2, 1, '', 'apksigner omitted');
        },
      );

      final apkFile = File('${tempDir.path}/app_release.apk');
      await apkFile.writeAsBytes(createTestZip(['AndroidManifest.xml']));
      final aaptResult = await aaptInspector.inspectApk(apkFile);
      expect(aaptResult.packageName, equals('com.mochilalista.app'));
      expect(aaptResult.versionName, equals('9.38.0'));
      expect(aaptResult.versionCode, equals(82));
      expect(aaptResult.minSdk, equals('21'));
      expect(aaptResult.targetSdk, equals('34'));

      // Fallback sin aapt2: nombre mochilalista_v9.35_atp.apk y archivo compañero _cambios.txt
      final fallbackInspector = ApkInspectorService(
        processRunnerOverride: (cmd, args) async =>
            ProcessResult(1, 1, '', 'fail'),
      );

      final atpFile = File('${tempDir.path}/mochilalista_v9.35_atp.apk');
      await atpFile.writeAsBytes(createTestZip(['AndroidManifest.xml']));
      final changelogFile =
          File('${tempDir.path}/mochilalista_v9.35_atp_cambios.txt');
      await changelogFile.writeAsString(
          '• Parche ATP crítico\n• Mejoras de estabilidad en sincronización\n');

      final fallbackResult = await fallbackInspector.inspectApk(atpFile);
      expect(fallbackResult.versionName, equals('9.35.0'));
      expect(fallbackResult.suggestedChangelog, contains('Parche ATP crítico'));
    });

    // =========================================================================
    // 4. Semver, Matriz Inteligente, Anti-Degradación y Trazabilidad mark-sent
    // =========================================================================
    test(
        '4. Semver determinista, anti-degradación y matriz con estados de distribución',
        () async {
      // Comparador SemVer
      expect(DatabaseService.compareSemVer('9.38.0', '9.35.0'), greaterThan(0));
      expect(DatabaseService.compareSemVer('9.32.0', '9.32.1'), lessThan(0));
      expect(DatabaseService.compareSemVer('v9.35.0+79', '9.35.0'), equals(0));
      expect(DatabaseService.compareSemVer('9.35', '9.35.0'), equals(0));
      expect(DatabaseService.compareSemVer(null, '9.0.0'), lessThan(0));

      final dataDir = '${tempDir.path}/data';
      final backupDir = '${tempDir.path}/backups';
      final releasesDir = '${tempDir.path}/releases_apks';
      final db = DatabaseService(
          dataDir: dataDir, backupDir: backupDir, releasesDir: releasesDir);
      await db.init();

      // Cliente inicial con versión 9.35.0
      final clients = await db.getClients();
      final targetClient = clients.first;
      final clientId = targetClient['id'] as String;

      await db.markClientUpdated(clientId, '9.35.0', force: true);

      // Intento de degradación sin force a versión 9.32.0 -> debe ser ignorado
      final notDegraded =
          await db.markClientUpdated(clientId, '9.32.0', force: false);
      expect(notDegraded?['installed_version'], equals('9.35.0'));

      // Trazabilidad de despacho APK
      final dispatched =
          await db.recordApkDispatched(clientId, '9.38.0', variant: 'arm64');
      expect(dispatched?['last_apk_sent_version'], equals('9.38.0'));
      expect(dispatched?['last_apk_sent_variant'], equals('arm64'));
      expect(dispatched?['last_apk_sent_at'], isNotNull);

      // Crear release 9.38.0 y verificar matriz
      await db.createRelease({
        'version_name': '9.38.0',
        'version_code': 82,
        'type': 'FEATURE_RELEASE',
        'apk_file_path':
            '${tempDir.path}/releases_apks/sandbox/mochilalista-v9.38.0.apk',
      });

      final matrix = await db.getUpdateDistributionMatrix();
      expect(matrix, isNotEmpty);
      final clientRow =
          matrix.firstWhere((row) => row['client_id'] == clientId);
      expect(clientRow['update_status'], equals('SENT'));
    });

    // =========================================================================
    // 5. Endpoints HTTP de Releases en Loopback (100% aislados)
    // =========================================================================
    test(
        '5. Endpoints HTTP: upload-apk, detect-local, import-local, copy-file, mark-sent y PUT',
        () async {
      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final libDir = '${tempDir.path}/apk_library';
      await Directory(libDir).create(recursive: true);

      final db = DatabaseService(
          dataDir: dataDir.path,
          backupDir: backupsDir.path,
          releasesDir: releasesDir);
      await db.init();

      final config =
          ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await config.init();
      await config.saveConfig({'apk_library_dir': libDir});

      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 5 + 3) % 256);
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

      String? lastCopiedPath;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      final testInspector = ApkInspectorService(
        processRunnerOverride: (cmd, args) async =>
            ProcessResult(1, 1, '', 'fallback-test'),
        defaultBuildOutputDir: Directory('${tempDir.path}/empty_build')..createSync(recursive: true),
        sdkSearchRootsOverride: const [],
      );

      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
            apkInspectorService: testInspector,
            onCopyFileOverride: (p) async {
              lastCopiedPath = p;
              return true;
            },
          ));

      final client = HttpClient();
      final baseUrl = 'http://127.0.0.1:$port';

      try {
        // A) Upload APK directo
        final dummyApkBytes =
            createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/libtest.so']);
        final uploadReq = await client.postUrl(Uri.parse(
            '$baseUrl/api/releases/upload-apk?filename=mochilalista_v9.38.0_arm64.apk'));
        uploadReq.add(dummyApkBytes);
        final uploadResp = await uploadReq.close();
        expect(uploadResp.statusCode, equals(200));
        final uploadBody = await utf8.decodeStream(uploadResp);
        final uploadJson = jsonDecode(uploadBody) as Map<String, dynamic>;
        expect(uploadJson['ok'], isTrue);
        expect(uploadJson['abi_variant'], equals('ARM64'));

        // B) Detect Local Build (con archivo preparado en libDir)
        final localApk = File('$libDir/mochilalista_v9.38.0_prod.apk');
        await localApk.writeAsBytes(dummyApkBytes);
        final detectReq = await client
            .getUrl(Uri.parse('$baseUrl/api/releases/detect-local-build'));
        final detectResp = await detectReq.close();
        expect(detectResp.statusCode, equals(200));
        final detectBody = await utf8.decodeStream(detectResp);
        final detectJson = jsonDecode(detectBody) as Map<String, dynamic>;
        expect(detectJson['ok'], isTrue);
        expect(detectJson['apk_found'], isTrue);
        expect(detectJson['total_found'], greaterThanOrEqualTo(1));

        // C) Import Local APK (copia atómica al entorno)
        final importReq = await client
            .postUrl(Uri.parse('$baseUrl/api/releases/import-local-apk'));
        importReq.headers.contentType = ContentType.json;
        importReq.write(jsonEncode({'source_path': localApk.path}));
        final importResp = await importReq.close();
        expect(importResp.statusCode, equals(200));
        final importBody = await utf8.decodeStream(importResp);
        final importJson = jsonDecode(importBody) as Map<String, dynamic>;
        expect(importJson['ok'], isTrue);
        expect(
            File(importJson['imported_path'] as String).existsSync(), isTrue);

        // Path Traversal Security Test: denegado o no encontrado fuera de carpetas permitidas
        final badImportReq = await client
            .postUrl(Uri.parse('$baseUrl/api/releases/import-local-apk'));
        badImportReq.headers.contentType = ContentType.json;
        badImportReq
            .write(jsonEncode({'source_path': 'C:/Windows/System32/calc.apk'}));
        final badImportResp = await badImportReq.close();
        expect(badImportResp.statusCode,
            isIn([HttpStatus.notFound, HttpStatus.forbidden]));
        await badImportResp.drain();

        // D) Crear Release y luego PUT para editar changelog
        final createReq =
            await client.postUrl(Uri.parse('$baseUrl/api/releases'));
        createReq.headers.contentType = ContentType.json;
        createReq.write(jsonEncode({
          'version_name': '9.38.0',
          'version_code': 82,
          'type': 'FEATURE_RELEASE',
          'apk_file_path': localApk.path,
          'changelog': 'Changelog inicial',
        }));
        final createResp = await createReq.close();
        expect(createResp.statusCode, equals(HttpStatus.created));
        await createResp.drain();

        final putReq =
            await client.putUrl(Uri.parse('$baseUrl/api/releases/9.38.0'));
        putReq.headers.contentType = ContentType.json;
        putReq.write(jsonEncode({
          'changelog':
              'Changelog actualizado oficialmente con Plan Maestro 19.',
          'type': 'HOTFIX',
        }));
        final putResp = await putReq.close();
        expect(putResp.statusCode, equals(HttpStatus.ok));
        final putBody = await utf8.decodeStream(putResp);
        final putJson = jsonDecode(putBody) as Map<String, dynamic>;
        expect(putJson['changelog'], contains('Plan Maestro 19'));
        expect(putJson['type'], equals('HOTFIX'));

        // E) Copy File binario al portapapeles (hook onCopyFileOverride)
        final copyReq = await client
            .postUrl(Uri.parse('$baseUrl/api/releases/9.38.0/copy-file'));
        final copyResp = await copyReq.close();
        expect(copyResp.statusCode, equals(200));
        final copyBody = await utf8.decodeStream(copyResp);
        final copyJson = jsonDecode(copyBody) as Map<String, dynamic>;
        expect(copyJson['ok'], isTrue);
        expect(lastCopiedPath, equals(localApk.absolute.path));

        // F) Mark Sent
        final clients = await db.getClients();
        final firstClientId = clients.isNotEmpty
            ? clients.first['id'] as String
            : await db.createClient({
                'business_name': 'Cliente Test releases',
                'installed_version': '9.30.0',
              });
        final markSentReq =
            await client.postUrl(Uri.parse('$baseUrl/api/releases/mark-sent'));
        markSentReq.headers.contentType = ContentType.json;
        markSentReq.write(jsonEncode({
          'client_id': firstClientId,
          'version': '9.38.0',
          'variant': 'ARM64',
        }));
        final markSentResp = await markSentReq.close();
        expect(markSentResp.statusCode, equals(200));
        final markSentBody = await utf8.decodeStream(markSentResp);
        final markSentJson = jsonDecode(markSentBody) as Map<String, dynamic>;
        expect(markSentJson['ok'], isTrue);
        expect(markSentJson['version'], equals('9.38.0'));
      } finally {
        client.close(force: true);
        await server.close(force: true);
      }
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
