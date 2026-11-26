import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('FASE 2 - Plan Maestro 19: Reingeniería Visual y Funcional de Versiones APK', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p19_fase2_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. Paso 0 Backend: PUT actualiza todos los campos clave y reveal-file con variant
    // =========================================================================
    test('1. Backend: PUT /api/releases/:version actualiza version_code (24->79), esquema, notas y variantes', () async {
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final backupDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final db = DatabaseService(dataDir: dataDir.path, backupDir: backupDir.path, releasesDir: releasesDir);
      await db.init();

      final config = ConfigService(dataDirectory: dataDir, backupsDirectory: backupDir);
      await config.init();

      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 7 + 11) % 256);
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

      // Crear release inicial con error histórico (version_code 24 en vez de 79)
      await db.createRelease({
        'version_name': '9.35.0',
        'version_code': 24,
        'db_schema_version': 35,
        'min_required_version': '9.0.0',
        'type': 'FEATURE_RELEASE',
        'changelog': 'Changelog inicial',
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
          ));

      final client = HttpClient();
      final baseUrl = 'http://127.0.0.1:$port';

      try {
        // Enviar PUT para corregir version_code a 79 y actualizar esquema v36 y notas internas
        final putReq = await client.putUrl(Uri.parse('$baseUrl/api/releases/9.35.0'));
        putReq.headers.contentType = ContentType.json;
        putReq.write(jsonEncode({
          'version_code': 79,
          'db_schema_version': 36,
          'min_required_version': '9.0.0',
          'type': 'HOTFIX',
          'changelog': 'Changelog corregido para Plan Maestro 19.',
          'internal_notes': 'Hotfix de estabilidad y corrección de version_code histórico.',
          'universal_apk': {'file_path': '${tempDir.path}/universal.apk', 'size_mb': '109.05 MB'},
          'arm64_apk': {'file_path': '${tempDir.path}/arm64.apk', 'size_mb': '28.40 MB'},
          'signature_verified': true,
          'signature_status': 'OFFICIAL_RELEASE',
          'signer_sha256': '7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20',
        }));
        final putResp = await putReq.close();
        expect(putResp.statusCode, equals(HttpStatus.ok));
        final putBody = await utf8.decodeStream(putResp);
        final putJson = jsonDecode(putBody) as Map<String, dynamic>;

        expect(putJson['version_code'], equals(79));
        expect(putJson['db_schema_version'], equals(36));
        expect(putJson['type'], equals('HOTFIX'));
        expect(putJson['internal_notes'], contains('Hotfix de estabilidad'));
        expect(putJson['universal_apk'], isNotNull);
        expect(putJson['arm64_apk'], isNotNull);
        expect(putJson['signature_status'], equals('OFFICIAL_RELEASE'));

        // Verificar persistencia real en base de datos
        final fetched = await db.getReleaseByVersion('9.35.0');
        expect(fetched?['version_code'], equals(79));
        expect(fetched?['db_schema_version'], equals(36));
        expect(fetched?['internal_notes'], contains('Hotfix de estabilidad'));

        // Probar reveal-file con variant
        final arm64File = File('${tempDir.path}/arm64.apk');
        await arm64File.writeAsString('dummy-arm64');
        final revealReq = await client.postUrl(Uri.parse('$baseUrl/api/releases/reveal-file?variant=arm64'));
        revealReq.headers.contentType = ContentType.json;
        revealReq.write(jsonEncode({'version_name': '9.35.0'}));
        final revealResp = await revealReq.close();
        expect(revealResp.statusCode, equals(200));
        final revealBody = await utf8.decodeStream(revealResp);
        final revealJson = jsonDecode(revealBody) as Map<String, dynamic>;
        expect(revealJson['ok'], isTrue);
        expect(revealJson['variant'], equals('arm64'));
      } finally {
        client.close(force: true);
        await server.close(force: true);
      }
    });

    // =========================================================================
    // 2. Paso 0 Backend: apk_inspector_service prioriza local_db.dart
    // =========================================================================
    test('2. Backend: apk_inspector_service.dart prioriza local_db.dart como candidato', () async {
      final inspectorFile = File('lib/apk_inspector_service.dart');
      expect(await inspectorFile.exists(), isTrue);
      final content = await inspectorFile.readAsString();
      expect(content, contains('local_db.dart'));
      expect(content, contains('database_helper.dart'));
      final localDbIdx = content.indexOf('local_db.dart');
      final dbHelperIdx = content.indexOf('database_helper.dart');
      expect(localDbIdx, lessThan(dbHelperIdx));
    });

    // =========================================================================
    // 3. Inspección Estática de HTML (index.html)
    // =========================================================================
    test('3. UI HTML: Eliminación de (15-40 MB), versión dinámica de cliente y elementos de Fase 2', () async {
      final html = WebBundleLoader.loadHtml();
      expect(html, isNotEmpty);

      // Ausencia del texto obsoleto (15-40 MB)
      expect(html, isNot(contains('(15-40 MB)')));

      // Ausencia de value="9.36.0" en newInstalledVersion
      expect(html, isNot(contains('id="newInstalledVersion" value="9.36.0"')));

      // Presencia de elementos clave de la Fase 2
      expect(html, contains('id="releasesRolloutProgress"'));
      expect(html, contains('id="rolloutTotal"'));
      expect(html, contains('id="rolloutUpToDate"'));
      expect(html, contains('id="rolloutSent"'));
      expect(html, contains('id="rolloutPending"'));
      expect(html, contains('id="inputRelMatrixSearch"'));
      expect(html, contains('id="matrixFilterChips"'));
      expect(html, contains('id="apkSignatureBanner"'));
      expect(html, contains('id="localBuildsGrid"'));
      expect(html, contains('id="relTypeInfoCard"'));
      expect(html, contains('id="relInternalNotes"'));
      expect(html, contains('id="editRelVersionCode"'));
      expect(html, contains('id="editRelDbSchema"'));
      expect(html, contains('id="editRelInternalNotes"'));
      expect(html, contains('id="editRelVariantsContainer"'));

      // Ausencia de emojis crudos en el modal de crear release
      final createModalIdx = html.indexOf('id="modalCreateRelease"');
      final editModalIdx = html.indexOf('id="modalEditRelease"');
      expect(createModalIdx, greaterThan(0));
      expect(editModalIdx, greaterThan(createModalIdx));
      final createHtml = html.substring(createModalIdx, editModalIdx);
      final rawEmojis = ['✅', '⬇️', '📁', '✏️', '🗑️', '📲', 'ℹ️', '🚀', '📦'];
      for (final emoji in rawEmojis) {
        expect(createHtml, isNot(contains(emoji)), reason: 'El modal no debe contener el emoji crudo $emoji');
      }
    });

    // =========================================================================
    // 4. Inspección Estática de CSS (styles.css)
    // =========================================================================
    test('4. CSS: Ancho completo de selector, banner de firma y barra de rollout', () async {
      final css = WebBundleLoader.loadCss();
      expect(css, isNotEmpty);

      expect(css, contains('#relType'));
      expect(css, contains('#editRelType'));
      expect(css, contains('.release-type-info-card'));
      expect(css, contains('.apk-signature-banner'));
      expect(css, contains('.sig-official'));
      expect(css, contains('.sig-unofficial'));
      expect(css, contains('.local-build-card'));
      expect(css, contains('.rollout-card'));
      expect(css, contains('.rollout-segmented-bar'));
      expect(css, contains('.badge-arm64'));
      expect(css, contains('.badge-universal'));
      expect(css, contains('.badge-official-sig'));
      expect(css, contains('.badge-unofficial-sig'));
      expect(css, contains('.badge-ahead'));
      expect(css, contains('.badge-sent'));
    });

    // =========================================================================
    // 5. Inspección Estática y Lógica de JavaScript (admin_app.js)
    // =========================================================================
    test('5. JS: compareSemVer, ausencia de || 24, escudo anti-debug y consumo de endpoints', () async {
      final js = WebBundleLoader.loadJs();
      expect(js, isNotEmpty);

      // Ausencia del fallback obsoleto || 24 en código de build de releases
      expect(js, isNot(contains("document.getElementById('relVersionCode').value) || 24")));
      expect(js, isNot(contains("document.getElementById('relDbSchema').value) || 35")));

      // Presencia de funciones y constantes clave
      expect(js, contains('function compareSemVer'));
      expect(js, contains('setMatrixFilter'));
      expect(js, contains('updateRolloutProgress'));
      expect(js, contains('renderSignatureShieldBanner'));
      expect(js, contains('chkAcknowledgeUnofficialApk'));
      expect(js, contains('importLocalApkDirectly'));
      expect(js, contains('/api/releases/import-local-apk'));
      expect(js, contains('/api/releases/detect-local-build'));
      expect(js, contains('copyReleaseApkToClipboard'));
      expect(js, contains('/copy-file'));
      expect(js, contains('Archivo .apk copiado: presiona Ctrl + V en WhatsApp'));
      expect(js, contains('formatPeruvianPhoneDisplay'));

      // Estados de la matriz
      expect(js, contains("'OUTDATED'"));
      expect(js, contains("'SENT'"));
      expect(js, contains("'UP_TO_DATE'"));
      expect(js, contains("'AHEAD'"));
      expect(js, contains("'PROSPECT'"));

      // Verificación de sintaxis con Node.js sobre todos los módulos JS activos
      final jsBundle = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'admin_bundle_releases_ui.js',
      );
      final nodeCheck = await Process.run('node', ['--check', jsBundle.path]);
      expect(nodeCheck.exitCode, equals(0), reason: 'admin_app.js debe ser sintácticamente válido en JavaScript');
    });
  });
}
