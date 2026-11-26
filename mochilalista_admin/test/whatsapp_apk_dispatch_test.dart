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
  group('FASE 3 - Plan Maestro 19: Despacho Asistido de APK por WhatsApp y Portapapeles', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p19_fase3_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. Flujo REST completo de despacho: copy-file, mark-sent y mark-updated
    // =========================================================================
    test('1. Flujo REST: copy-file con doble variante (Universal y ARM64), mark-sent a SENT y mark-updated a UP_TO_DATE', () async {
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final backupDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final db = DatabaseService(dataDir: dataDir.path, backupDir: backupDir.path, releasesDir: releasesDir);
      await db.init();

      final config = ConfigService(dataDirectory: dataDir, backupsDirectory: backupDir);
      await config.init();

      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 13 + 5) % 256);
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

      // Crear binarios simulados en disco para ambas variantes
      final univFile = File('${tempDir.path}/mochilalista_v9.38_universal.apk');
      await univFile.writeAsBytes(List.filled(1024, 0x50));
      final arm64File = File('${tempDir.path}/mochilalista_v9.38_arm64.apk');
      await arm64File.writeAsBytes(List.filled(512, 0x51));

      // Crear release con variantes registradas
      await db.createRelease({
        'version_name': '9.38.0',
        'version_code': 82,
        'db_schema_version': 36,
        'min_required_version': '9.0.0',
        'type': 'FEATURE_RELEASE',
        'apk_file_path': univFile.path,
        'file_size_mb': '109.05 MB',
        'universal_apk': {
          'file_path': univFile.path,
          'file_size_mb': '109.05 MB',
          'sha256': 'a1b2c3d4e5f6',
          'signature_status': 'OFFICIAL_RELEASE',
          'signature_verified': true,
        },
        'arm64_apk': {
          'file_path': arm64File.path,
          'file_size_mb': '28.40 MB',
          'sha256': 'f6e5d4c3b2a1',
          'signature_status': 'OFFICIAL_RELEASE',
          'signature_verified': true,
        },
        'changelog': 'Plan Maestro 19: Soporte de variantes y despacho asistido.',
      });

      // Crear cliente desactualizado en v9.32.0
      final clients = await db.getClients();
      final targetClient = clients.first;
      final clientId = targetClient['id'] as String;
      await db.markClientUpdated(clientId, '9.32.0', force: true);

      // Rastreador de rutas copiadas al portapapeles sin tocar portapapeles real de Windows
      final copiedPaths = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
            onCopyFileOverride: (filePath) async {
              copiedPaths.add(filePath);
              return true;
            },
          ));

      final client = HttpClient();
      final baseUrl = 'http://127.0.0.1:$port';

      try {
        // A) Copiar binario Universal al portapapeles
        final copyUnivReq = await client.postUrl(Uri.parse('$baseUrl/api/releases/9.38.0/copy-file?variant=universal'));
        final copyUnivResp = await copyUnivReq.close();
        expect(copyUnivResp.statusCode, equals(HttpStatus.ok));
        final copyUnivBody = await utf8.decodeStream(copyUnivResp);
        final copyUnivJson = jsonDecode(copyUnivBody) as Map<String, dynamic>;
        expect(copyUnivJson['ok'], isTrue);
        expect(copyUnivJson['variant'], equals('universal'));
        expect(copiedPaths, contains(univFile.path));

        // B) Copiar binario ARM64 al portapapeles
        final copyArmReq = await client.postUrl(Uri.parse('$baseUrl/api/releases/9.38.0/copy-file?variant=arm64'));
        final copyArmResp = await copyArmReq.close();
        expect(copyArmResp.statusCode, equals(HttpStatus.ok));
        final copyArmBody = await utf8.decodeStream(copyArmResp);
        final copyArmJson = jsonDecode(copyArmBody) as Map<String, dynamic>;
        expect(copyArmJson['ok'], isTrue);
        expect(copyArmJson['variant'], equals('arm64'));
        expect(copiedPaths, contains(arm64File.path));

        // C) Registrar despacho (mark-sent) para trazabilidad comercial
        final markSentReq = await client.postUrl(Uri.parse('$baseUrl/api/releases/mark-sent'));
        markSentReq.headers.contentType = ContentType.json;
        markSentReq.write(jsonEncode({
          'client_id': clientId,
          'version': '9.38.0',
          'variant': 'arm64',
        }));
        final markSentResp = await markSentReq.close();
        expect(markSentResp.statusCode, equals(HttpStatus.ok));
        final markSentBody = await utf8.decodeStream(markSentResp);
        final markSentJson = jsonDecode(markSentBody) as Map<String, dynamic>;
        expect(markSentJson['ok'], isTrue);
        expect(markSentJson['variant'], equals('arm64'));

        // D) Verificar que la matriz de distribución refleja el estado SENT
        final matrixReq = await client.getUrl(Uri.parse('$baseUrl/api/releases/matrix'));
        final matrixResp = await matrixReq.close();
        expect(matrixResp.statusCode, equals(HttpStatus.ok));
        final matrixBody = await utf8.decodeStream(matrixResp);
        final matrixList = jsonDecode(matrixBody) as List;
        final clientRow = matrixList.firstWhere((r) => r['client_id'] == clientId);
        expect(clientRow['update_status'], equals('SENT'));
        expect(clientRow['last_apk_sent_version'], equals('9.38.0'));
        expect(clientRow['last_apk_sent_at'], isNotNull);

        // E) Marcar actualizado tras confirmación del cliente
        final markUpReq = await client.postUrl(Uri.parse('$baseUrl/api/clients/$clientId/mark-updated'));
        markUpReq.headers.contentType = ContentType.json;
        markUpReq.write(jsonEncode({'version_name': '9.38.0'}));
        final markUpResp = await markUpReq.close();
        expect(markUpResp.statusCode, equals(HttpStatus.ok));

        // F) Matriz ahora muestra UP_TO_DATE
        final matrixReq2 = await client.getUrl(Uri.parse('$baseUrl/api/releases/matrix'));
        final matrixResp2 = await matrixReq2.close();
        final matrixBody2 = await utf8.decodeStream(matrixResp2);
        final matrixList2 = jsonDecode(matrixBody2) as List;
        final clientRow2 = matrixList2.firstWhere((r) => r['client_id'] == clientId);
        expect(clientRow2['update_status'], equals('UP_TO_DATE'));
        expect(clientRow2['installed_version'], equals('9.38.0'));
      } finally {
        client.close();
        await server.close(force: true);
      }
    });

    // =========================================================================
    // 2. Manejo defensivo 404 cuando el APK físico no existe en disco
    // =========================================================================
    test('2. Manejo defensivo 404: copy-file y reveal-file responden 404 sin crasheos si el archivo no existe', () async {
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final backupDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final db = DatabaseService(dataDir: dataDir.path, backupDir: backupDir.path, releasesDir: releasesDir);
      await db.init();

      final config = ConfigService(dataDirectory: dataDir, backupsDirectory: backupDir);
      await config.init();

      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => i);
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
        // Petición a versión no existente
        final notFoundReq = await client.postUrl(Uri.parse('$baseUrl/api/releases/9.99.9/copy-file'));
        final notFoundResp = await notFoundReq.close();
        expect(notFoundResp.statusCode, equals(HttpStatus.notFound));
        final notFoundBody = await utf8.decodeStream(notFoundResp);
        final notFoundJson = jsonDecode(notFoundBody) as Map<String, dynamic>;
        expect(notFoundJson['error'], contains('No se encontró'));

        // Reveal file de versión no existente
        final revealReq = await client.postUrl(Uri.parse('$baseUrl/api/releases/reveal-file'));
        revealReq.headers.contentType = ContentType.json;
        revealReq.write(jsonEncode({'version_name': '9.99.9'}));
        final revealResp = await revealReq.close();
        expect(revealResp.statusCode, equals(HttpStatus.notFound));
      } finally {
        client.close();
        await server.close(force: true);
      }
    });

    // =========================================================================
    // 3. Inspección estática de Frontend (index.html, admin_app.js, styles.css)
    // =========================================================================
    test('3. Inspección Frontend: Panel waApkDispatchPanel, selectores de variante, botones copy y cero localhost:8080', () {
      final html = WebBundleLoader.loadHtml();
      expect(html, isNotEmpty);

      // Elementos del panel de despacho en el modal de WhatsApp
      expect(html, contains('id="waApkDispatchPanel"'));
      expect(html, contains('id="waApkVersionTitle"'));
      expect(html, contains('id="waApkSizeText"'));
      expect(html, contains('id="waApkDbSchema"'));
      expect(html, contains('id="waApkDiskStatus"'));
      expect(html, contains('id="waVariantSelectorGrid"'));
      expect(html, contains('id="waVariantCardUniversal"'));
      expect(html, contains('id="waVariantCardArm64"'));

      // Botones de acción de despacho asistido
      expect(html, contains('id="btnWaCopyApkAndSend"'));
      expect(html, contains('id="btnWaRevealApkFolder"'));
      expect(html, contains('id="btnWaSendTextOnly"'));
      expect(html, contains('id="waApkDispatchFooterActions"'));
      expect(html, contains('id="waStandardFooterActions"'));

      // Inputs de variantes en modal de edición
      expect(html, contains('id="editRelUniversalInput"'));
      expect(html, contains('id="editRelArm64Input"'));
      expect(html, contains('id="editRelVariantsContainer"'));

      // Verificación en admin_app.js
      final js = WebBundleLoader.loadJs();
      expect(js, isNotEmpty);

      expect(js, contains('function openApkDispatchComposer'));
      expect(js, contains('function setDispatchVariant'));
      expect(js, contains('function copyApkAndOpenWhatsApp'));
      expect(js, contains('function revealCurrentDispatchApkFolder'));
      expect(js, contains('function sendWaDispatchTextOnly'));
      expect(js, contains('function renderEditReleaseVariants'));
      expect(js, contains('function handleVariantFileSelected'));
      expect(js, contains('function triggerVariantUpload'));

      // Cero enlaces a localhost:8080 en el despacho de clientes
      expect(js, isNot(contains('http://localhost:8080/api/releases/download')));

      // Verificación en styles.css
      final css = WebBundleLoader.loadCss();
      expect(css, isNotEmpty);
      expect(css, contains('.wa-variant-selector-grid'));
      expect(css, contains('.wa-variant-card'));
      expect(css, contains('.wa-variant-card.active'));
      expect(css, contains('.wa-variant-card.disabled'));
      expect(css, contains('.variant-btn-group'));

      // Cero emojis gráficos prohibidos en HTML y CSS
      final bannedEmojis = ['✅', '⬇️', '📁', '✏️', '🗑️', '📲', 'ℹ️', '🚀', '📦'];
      for (final emoji in bannedEmojis) {
        expect(html, isNot(contains(emoji)), reason: 'Se encontró emoji prohibido $emoji en index.html');
        expect(css, isNot(contains(emoji)), reason: 'Se encontró emoji prohibido $emoji en styles.css');
      }
    });
  });
}
