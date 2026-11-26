import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

import '../lib/client_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('FASE 4 - Plan Maestro 19: Protocolo Dual .mlsync/MLS1, Sincronización Offline y Rescate PENDIENTE_MIGRACION', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p19_fase4_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. Vector Determinista HMAC-SHA256 (Paridad 1:1 con Flutter en Fase 5)
    // =========================================================================
    test('1. Vector Determinista HMAC-SHA256: generación compacta, verificación y escudo anti-manipulación', () {
      final syncService = ClientSyncService();

      final canonicalPayload = {
        'v': 1,
        'hw': 'ML-7K9A',
        'bhw': null,
        'mod': 'Samsung Galaxy A54 5G',
        'os': 'Android 14 (API 34)',
        'av': '9.38.0',
        'bc': 82,
        'db': 36,
        'pl': 'MENSUAL',
        'st': 'ACTIVA',
        'exp': '2026-12-31',
        'dr': 38,
        'n': 5,
        'ai': 42,
        'aiu': 18,
        'byok': false,
        'pc': 1,
        'drv': true,
        'bh': 'OK',
        'lb': '2026-11-23T10:00:00Z',
        'ts': 1795430000000,
      };

      final token = syncService.generateSyncToken(canonicalPayload);
      expect(token, startsWith('MLS1-'));
      expect(token, contains('.'));

      // Imprimir vector determinista para replicación byte a byte en Fase 5
      // ignore: avoid_print
      print('\n[VECTOR DETERMINISTA PARIDAD FASE 5]');
      // ignore: avoid_print
      print('Token MLS1: $token\n');

      // Verificación exitosa
      final parseOk = syncService.parseRawInput(token);
      expect(parseOk.valid, isTrue);
      expect(parseOk.errorCode, isNull);
      expect(parseOk.payload?['hw'], equals('ML-7K9A'));
      expect(parseOk.payload?['ai'], equals(42));
      expect(parseOk.payload?['av'], equals('9.38.0'));

      // Escudo anti-manipulación: modificar 1 carácter del payload
      final parts = token.split('.');
      final tamperedPayloadB64 = parts[0].replaceFirst('e', 'f');
      final tamperedToken = '$tamperedPayloadB64.${parts[1]}';
      final parseTampered = syncService.parseRawInput(tamperedToken);
      expect(parseTampered.valid, isFalse);
      expect(parseTampered.errorCode, equals('INVALID_SIGNATURE'));

      // Modificar 1 carácter del tag HMAC
      final tamperedTagB64 = parts[1].replaceFirst(parts[1][0], parts[1][0] == 'A' ? 'B' : 'A');
      final tamperedTagToken = '${parts[0]}.$tamperedTagB64';
      final parseTamperedTag = syncService.parseRawInput(tamperedTagToken);
      expect(parseTamperedTag.valid, isFalse);
      expect(parseTamperedTag.errorCode, equals('INVALID_SIGNATURE'));
    });

    // =========================================================================
    // 2. Parser Universal: Texto libre de WhatsApp, token directo y archivo .mlsync
    // =========================================================================
    test('2. Parser Universal: decodifica token directo, archivo .mlsync y mensaje completo de WhatsApp', () {
      final syncService = ClientSyncService();
      final payload = {
        'v': 1,
        'hw': 'ML-5P3X',
        'bhw': null,
        'mod': 'Xiaomi Redmi Note 13',
        'os': 'Android 13',
        'av': '9.38.0',
        'bc': 82,
        'db': 36,
        'pl': 'SEMESTRAL',
        'st': 'ACTIVA',
        'exp': '2027-05-20',
        'dr': 178,
        'n': 8,
        'ai': 85,
        'aiu': 30,
        'byok': false,
        'pc': 2,
        'drv': true,
        'bh': 'OK',
        'lb': '2026-11-23T12:00:00Z',
        'ts': 1795431000000,
      };

      final token = syncService.generateSyncToken(payload);

      // A) Mensaje completo pegado desde WhatsApp con saludos, saltos de línea y texto
      final waPastedMessage = '''
¡Hola Julio! Buenas tardes 👋
Te paso el reporte técnico de mi celular para que verifiques la actualización:

$token

Por favor confírmame si llegó bien. ¡Muchas gracias!
''';

      final parseWa = syncService.parseRawInput(waPastedMessage);
      expect(parseWa.valid, isTrue);
      expect(parseWa.payload?['hw'], equals('ML-5P3X'));
      expect(parseWa.payload?['pl'], equals('SEMESTRAL'));

      // B) Archivo .mlsync (formato JSON oficial serializado)
      final mlsyncMap = syncService.generateMlsyncFileContent(payload);
      final mlsyncContent = jsonEncode(mlsyncMap);
      expect(mlsyncContent, contains('"format":"MLSYNC_V1"'));
      expect(mlsyncContent, contains(token));

      final parseFile = syncService.parseRawInput(mlsyncContent);
      expect(parseFile.valid, isTrue);
      expect(parseFile.payload?['hw'], equals('ML-5P3X'));
      expect(parseFile.payload?['mod'], equals('Xiaomi Redmi Note 13'));

      // C) Texto sin token reconocible
      final invalidInput = 'Hola, no te envié ningún token';
      final parseInvalid = syncService.parseRawInput(invalidInput);
      expect(parseInvalid.valid, isFalse);
      expect(parseInvalid.errorCode, equals('NO_TOKEN_FOUND'));
    });

    // =========================================================================
    // 3. Endpoints REST /api/sync/parse y /api/sync/apply con loopback real
    // =========================================================================
    test('3. Endpoints REST: parse, apply con transición a UP_TO_DATE en matriz, HTTP 409 stale y HTTP 400 corrupt', () async {
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
      final syncService = ClientSyncService();

      // Crear archivo simulado de release y registrar versión v9.38.0 en catálogo
      final apkFile = File('${tempDir.path}/mochilalista_v9.38.0.apk');
      await apkFile.writeAsBytes(List.filled(1024, 0x50));
      await db.createRelease({
        'version_name': '9.38.0',
        'version_code': 82,
        'type': 'FEATURE_RELEASE',
        'min_required_version': '9.0.0',
        'db_schema_version': 36,
        'apk_file_path': apkFile.path,
        'file_size_mb': '32.5 MB',
        'sha256': 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'changelog': 'Sincronización Offline y Rescate de Migración',
        'universal_apk': {
          'file_path': apkFile.path,
          'file_size_mb': '32.5 MB',
          'sha256': 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          'signature_status': 'OFFICIAL_RELEASE',
          'signature_verified': true,
        },
      });

      // Crear cliente en DB desactualizado y con saldo 69
      final client = await db.createClient({
        'business_name': 'Bodega La Unión',
        'owner_name': 'Carlos Gomez',
        'document_id': '10456789012',
        'phone': '987654321',
        'current_device_id': 'ML-7K9A',
        'device_model': 'Samsung Antiguo',
        'installed_version': '9.35.0',
        'license_type': 'MENSUAL',
        'license_expires': '2026-12-31T23:59:59Z',
        'ai_reported_balance': 69,
        'ai_credits_used_total': 10,
        'last_sync_at': null,
      });

      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
            clientSyncService: syncService,
          ));

      final clientHttp = HttpClient();

      try {
        // Payload de celular con versión 9.38.0 y saldo 42
        final syncPayload = {
          'v': 1,
          'hw': 'ML-7K9A',
          'bhw': null,
          'mod': 'Samsung Galaxy A54 5G',
          'os': 'Android 14',
          'av': '9.38.0',
          'bc': 82,
          'db': 36,
          'pl': 'MENSUAL',
          'st': 'ACTIVA',
          'exp': '2026-12-31',
          'dr': 38,
          'n': 5,
          'ai': 42,
          'aiu': 28,
          'byok': false,
          'pc': 1,
          'drv': true,
          'bh': 'OK',
          'lb': '2026-11-23T10:00:00Z',
          'ts': 1795430000000,
        };
        final syncToken = syncService.generateSyncToken(syncPayload);

        // A) POST /api/sync/parse
        final parseReq = await clientHttp.post('127.0.0.1', server.port, '/api/sync/parse');
        parseReq.headers.contentType = ContentType.json;
        parseReq.write(jsonEncode({'raw_input': syncToken, 'expected_client_id': client['id']}));
        final parseRes = await parseReq.close();
        expect(parseRes.statusCode, equals(200));

        final parseData = jsonDecode(await utf8.decoder.bind(parseRes).join());
        expect(parseData['valid'], isTrue);
        expect(parseData['match_type'], equals('EXACT_HARDWARE'));
        expect(parseData['matched_client']['id'], equals(client['id']));

        final changes = (parseData['changes'] as List);
        final aiChange = changes.firstWhere((c) => c['field'] == 'ai_reported_balance');
        expect(aiChange['before'], equals(69));
        expect(aiChange['after'], equals(42));
        expect(aiChange['changed'], isTrue);

        final avChange = changes.firstWhere((c) => c['field'] == 'installed_version');
        expect(avChange['before'], equals('9.35.0'));
        expect(avChange['after'], equals('9.38.0'));
        expect(avChange['changed'], isTrue);

        // B) POST /api/sync/apply
        final applyReq = await clientHttp.post('127.0.0.1', server.port, '/api/sync/apply');
        applyReq.headers.contentType = ContentType.json;
        applyReq.write(jsonEncode({
          'client_id': client['id'],
          'raw_input': syncToken,
          'force_older': false,
        }));
        final applyRes = await applyReq.close();
        expect(applyRes.statusCode, equals(200));

        final applyData = jsonDecode(await utf8.decoder.bind(applyRes).join());
        expect(applyData['client']['ai_reported_balance'], equals(42));
        expect(applyData['client']['installed_version'], equals('9.38.0'));
        expect(applyData['client']['device_model'], equals('Samsung Galaxy A54 5G'));
        expect(applyData['client']['backup_drive_linked'], isTrue);
        expect(applyData['client']['backup_health_status'], equals('OK'));
        expect(applyData['client']['last_sync_at'], isNotNull);

        // C) Verificar actualización automática de la matriz de versiones (releases_matrix)
        final matrix = await db.getUpdateDistributionMatrix();
        final clientRow = matrix.firstWhere((r) => r['client_id'] == client['id']);
        expect(clientRow['update_status'], equals('UP_TO_DATE'));
        expect(clientRow['is_up_to_date'], isTrue);

        // D) Anti-sobreescritura: intentar aplicar un reporte más antiguo sin force_older -> HTTP 409
        final olderPayload = Map<String, dynamic>.from(syncPayload);
        olderPayload['ts'] = 1795400000000; // Epoch menor que 1795430000000
        olderPayload['ai'] = 99;
        final olderToken = syncService.generateSyncToken(olderPayload);

        final staleReq = await clientHttp.post('127.0.0.1', server.port, '/api/sync/apply');
        staleReq.headers.contentType = ContentType.json;
        staleReq.write(jsonEncode({
          'client_id': client['id'],
          'raw_input': olderToken,
          'force_older': false,
        }));
        final staleRes = await staleReq.close();
        expect(staleRes.statusCode, equals(409));

        final staleData = jsonDecode(await utf8.decoder.bind(staleRes).join());
        expect(staleData['error'], contains('anterior a la última'));

        // Con force_older: true sí aplica
        final forceReq = await clientHttp.post('127.0.0.1', server.port, '/api/sync/apply');
        forceReq.headers.contentType = ContentType.json;
        forceReq.write(jsonEncode({
          'client_id': client['id'],
          'raw_input': olderToken,
          'force_older': true,
        }));
        final forceRes = await forceReq.close();
        expect(forceRes.statusCode, equals(200));

        final updatedClient = await db.getClientById(client['id']);
        expect(updatedClient?['ai_reported_balance'], equals(99));

        // E) Enviar token corrupto -> HTTP 400
        final corruptReq = await clientHttp.post('127.0.0.1', server.port, '/api/sync/apply');
        corruptReq.headers.contentType = ContentType.json;
        corruptReq.write(jsonEncode({
          'client_id': client['id'],
          'raw_input': 'MLS1-invalido.firmafalsa',
          'force_older': false,
        }));
        final corruptRes = await corruptReq.close();
        expect(corruptRes.statusCode, equals(400));
      } finally {
        clientHttp.close(force: true);
        await server.close(force: true);
      }
    });

    // =========================================================================
    // 4. Rescate de PENDIENTE_MIGRACION por Hardware Origen (bhw)
    // =========================================================================
    test('4. Rescate PENDIENTE_MIGRACION: identifica cliente origen por bhw y pre-mapea RESTORED_BACKUP', () async {
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final backupDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final db = DatabaseService(dataDir: dataDir.path, backupDir: backupDir.path, releasesDir: releasesDir);
      await db.init();

      final syncService = ClientSyncService();

      // Cliente original registrado en CRM con equipo antiguo ML-OLD1
      final originalClient = await db.createClient({
        'business_name': 'Bazar y Librería Central',
        'owner_name': 'Rosa Perez',
        'document_id': '10876543210',
        'phone': '912345678',
        'current_device_id': 'ML-OLD1',
        'device_model': 'Samsung Galaxy J7',
        'installed_version': '9.35.0',
        'license_type': 'ANUAL',
      });

      // Ficha exportada por la app en nuevo celular con estado PENDIENTE_MIGRACION y bhw=ML-OLD1
      final rescuePayload = {
        'v': 1,
        'hw': 'ML-NEW1',
        'bhw': 'ML-OLD1',
        'mod': 'Xiaomi Redmi Note 13',
        'os': 'Android 14',
        'av': '9.38.0',
        'bc': 82,
        'db': 36,
        'pl': 'ANUAL',
        'st': 'PENDIENTE_MIGRACION',
        'exp': '2027-08-15',
        'dr': 265,
        'n': 3,
        'ai': 50,
        'aiu': 20,
        'byok': false,
        'pc': 1,
        'drv': true,
        'bh': 'OK',
        'lb': '2026-11-23T11:00:00Z',
        'ts': 1795432000000,
      };

      final allClients = await db.getClients();
      final analysis = syncService.analyzeForClients(rescuePayload, allClients);

      expect(analysis['match_type'], equals('MIGRATION_SOURCE'));
      expect(analysis['matched_client']['id'], equals(originalClient['id']));
      expect(analysis['matched_client']['business_name'], equals('Bazar y Librería Central'));

      final mr = analysis['migration_rescue'] as Map<String, dynamic>;
      expect(mr['detected'], isTrue);
      expect(mr['old_hardware_id'], equals('ML-OLD1'));
      expect(mr['new_hardware_id'], equals('ML-NEW1'));
      expect(mr['device_model'], equals('Xiaomi Redmi Note 13'));
      expect(mr['suggested_scenario'], equals('RESTORED_BACKUP'));
    });

    // =========================================================================
    // 5. Inspector Forense Dual (/api/licenses/inspect): LICENSE_TOKEN vs CLIENT_SYNC
    // =========================================================================
    test('5. Inspector Forense Dual: audita tokens Ed25519 (LICENSE_TOKEN) y fichas de sincronización (CLIENT_SYNC)', () async {
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
      final syncService = ClientSyncService();

      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
            clientSyncService: syncService,
          ));

      final clientHttp = HttpClient();

      try {
        // A) Token de Licencia Ed25519 tradicional ML9-...
        final licenseToken = await signer.generateLicenseToken(
          deviceFingerprint: 'ML-8X2B',
          plan: 'MENSUAL',
          daysToAdd: 30,
          nonce: 1,
          businessTag: 'Ferretería El Tornillo',
        );

        final reqLic = await clientHttp.post('127.0.0.1', server.port, '/api/licenses/inspect');
        reqLic.headers.contentType = ContentType.json;
        reqLic.write(jsonEncode({'token': licenseToken}));
        final resLic = await reqLic.close();
        expect(resLic.statusCode, equals(200));

        final dataLic = jsonDecode(await utf8.decoder.bind(resLic).join());
        expect(dataLic['input_kind'], equals('LICENSE_TOKEN'));
        expect(dataLic['valid'], isTrue);
        expect(dataLic['payload']['d'], equals('ML-8X2B'));

        // B) Ficha de Sincronización MLS1-...
        final syncPayload = {
          'v': 1,
          'hw': 'ML-8X2B',
          'bhw': null,
          'mod': 'Motorola Edge 40',
          'os': 'Android 14',
          'av': '9.38.0',
          'bc': 82,
          'db': 36,
          'pl': 'MENSUAL',
          'st': 'ACTIVA',
          'exp': '2026-12-23',
          'dr': 30,
          'n': 1,
          'ai': 20,
          'aiu': 5,
          'byok': false,
          'pc': 1,
          'drv': false,
          'bh': 'OK',
          'lb': null,
          'ts': 1795433000000,
        };
        final syncToken = syncService.generateSyncToken(syncPayload);

        final reqSync = await clientHttp.post('127.0.0.1', server.port, '/api/licenses/inspect');
        reqSync.headers.contentType = ContentType.json;
        reqSync.write(jsonEncode({'token': syncToken}));
        final resSync = await reqSync.close();
        expect(resSync.statusCode, equals(200));

        final dataSync = jsonDecode(await utf8.decoder.bind(resSync).join());
        expect(dataSync['input_kind'], equals('CLIENT_SYNC'));
        expect(dataSync['valid'], isTrue);
        expect(dataSync['payload']['hw'], equals('ML-8X2B'));
        expect(dataSync['payload']['mod'], equals('Motorola Edge 40'));

        // C) Archivo .mlsync JSON enviado como token al inspector
        final mlsyncMap = syncService.generateMlsyncFileContent(syncPayload);
        final mlsyncJson = jsonEncode(mlsyncMap);
        final reqFile = await clientHttp.post('127.0.0.1', server.port, '/api/licenses/inspect');
        reqFile.headers.contentType = ContentType.json;
        reqFile.write(jsonEncode({'token': mlsyncJson}));
        final resFile = await reqFile.close();
        expect(resFile.statusCode, equals(200));

        final dataFile = jsonDecode(await utf8.decoder.bind(resFile).join());
        expect(dataFile['input_kind'], equals('CLIENT_SYNC'));
        expect(dataFile['valid'], isTrue);
      } finally {
        clientHttp.close(force: true);
        await server.close(force: true);
      }
    });

    // =========================================================================
    // 6. Inspección Estática Frontend: 3 Puntos de Entrada, Rescate y Cero Emojis
    // =========================================================================
    test('6. Inspección Estática Frontend: 3 puntos de entrada, rescate 1-clic y CERO emojis crudos', () {
      final indexHtml = WebBundleLoader.loadHtml();
      final stylesCss = WebBundleLoader.loadCss();
      final adminAppJs = WebBundleLoader.loadJs();

      // Punto 1: modalSyncReported con tabs y comparador
      expect(indexHtml, contains('id="modalSyncReported"'));
      expect(indexHtml, contains('id="tabBtnSyncImport"'));
      expect(indexHtml, contains('id="tabBtnSyncManual"'));
      expect(indexHtml, contains('id="syncPaneImport"'));
      expect(indexHtml, contains('id="syncPaneManual"'));
      expect(indexHtml, contains('id="syncDropZone"'));
      expect(indexHtml, contains('id="syncRawInput"'));
      expect(indexHtml, contains('id="btnAnalyzeSyncReported"'));
      expect(indexHtml, contains('id="btnApplySyncReported"'));
      expect(indexHtml, contains('id="btnSyncRescueMigrate"'));

      // Punto 2: Botón global en Cartera CRM y modalGlobalClientSync
      expect(indexHtml, contains('id="btnImportClientSync"'));
      expect(indexHtml, contains('id="modalGlobalClientSync"'));
      expect(indexHtml, contains('id="globalSyncDropZone"'));
      expect(indexHtml, contains('id="globalSyncRawInput"'));
      expect(indexHtml, contains('id="btnAnalyzeGlobalSync"'));
      expect(indexHtml, contains('id="btnApplyGlobalSync"'));

      // Punto 3: Inspector dual con soporte .mlsync y tarjeta especializada
      expect(indexHtml, contains('id="inspectSyncAuditCard"'));
      expect(indexHtml, contains('id="inspectLicenseClaimsWrapper"'));

      // Ficha 360° Resumen
      expect(indexHtml, contains('id="drawerLastSync"'));
      expect(indexHtml, contains('id="drawerBackupDrive"'));

      // Estilos CSS para Fase 4
      expect(stylesCss, contains('.sync-drop-zone'));
      expect(stylesCss, contains('.sync-hmac-badge'));
      expect(stylesCss, contains('.sync-migration-rescue-card'));
      expect(stylesCss, contains('.sync-diff-table'));

      // Lógica JS en admin_app.js
      expect(adminAppJs, contains('function initClientSyncEvents()'));
      expect(adminAppJs, contains('function openSyncReportedModal('));
      expect(adminAppJs, contains('function switchSyncReportedTab('));
      expect(adminAppJs, contains('function renderSyncDiffTable('));
      expect(adminAppJs, contains('function analyzeSyncReported()'));
      expect(adminAppJs, contains('function applySyncReported()'));
      expect(adminAppJs, contains('function openGlobalClientSyncModal()'));
      expect(adminAppJs, contains('function analyzeGlobalSync()'));
      expect(adminAppJs, contains('function applyGlobalSync()'));
      expect(adminAppJs, contains('function renderInspectClientSync('));
      expect(adminAppJs, contains('options.scenario || \'RESTORED_BACKUP\''));

      // Certificación estricta: CERO emojis gráficos crudos en componentes nuevos de Fase 4
      final forbiddenEmojis = ['✅', '❌', '🏢', '⚡', 'ℹ️', '📲', '📦', '🚀', '🔒', '🔑', '📱'];
      
      final modalSyncIdx = indexHtml.indexOf('id="modalSyncReported"');
      final modalGlobalIdx = indexHtml.indexOf('id="modalGlobalClientSync"');
      final tabInspectorIdx = indexHtml.indexOf('id="tabInspector"');
      final phase4HtmlChunks = [
        indexHtml.substring(modalSyncIdx, modalSyncIdx + 2500),
        indexHtml.substring(modalGlobalIdx, modalGlobalIdx + 2500),
        indexHtml.substring(tabInspectorIdx, tabInspectorIdx + 3000),
      ];

      for (final chunk in phase4HtmlChunks) {
        for (final emoji in forbiddenEmojis) {
          expect(
            chunk.contains(emoji),
            isFalse,
            reason: 'Se encontró emoji prohibido $emoji en componente nuevo de Fase 4 de index.html',
          );
        }
      }

      // Verificar que los nuevos módulos en admin_app.js también estén libres de emojis prohibidos
      final clientSyncEventsIdx = adminAppJs.indexOf('function initClientSyncEvents()');
      final inspectClientSyncIdx = adminAppJs.indexOf('function renderInspectClientSync(');
      final phase4JsChunks = [
        adminAppJs.substring(clientSyncEventsIdx, clientSyncEventsIdx + 3500),
        adminAppJs.substring(inspectClientSyncIdx, inspectClientSyncIdx + 3500),
      ];
      for (final chunk in phase4JsChunks) {
        for (final emoji in forbiddenEmojis) {
          expect(
            chunk.contains(emoji),
            isFalse,
            reason: 'Se encontró emoji prohibido $emoji en componente nuevo de Fase 4 de admin_app.js',
          );
        }
      }

      // ignore: avoid_print
      print('\n[CERTIFICACIÓN ESTÁTICA FRONTEND FASE 4: EXITOSA]');
      // ignore: avoid_print
      print('• 3 Puntos de Entrada verificados en index.html y admin_app.js');
      // ignore: avoid_print
      print('• Rescate 1-Clic PENDIENTE_MIGRACION verificado');
      // ignore: avoid_print
      print('• CERO emojis crudos verificado');
    });
  });
}
