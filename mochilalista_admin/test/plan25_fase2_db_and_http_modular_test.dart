@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/apk_inspector_service.dart';
import '../lib/client_sync_service.dart';
import '../lib/commercial_config_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/http/api_router.dart';
import '../lib/http/html_assembler.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart' as admin_server;
import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 25 - FASE 2: Modularización DB & HTTP + Seguridad', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_plan25_fase2_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    Future<({
      DatabaseService db,
      ConfigService cfg,
      LicenseSigner signer,
      ExcelExportService excel,
      VaultStorageService vault,
    })> buildTempServices() async {
      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final bkpDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      final mirrorDir = Directory('${tempDir.path}/mirror')
        ..createSync(recursive: true);
      final relDir = '${tempDir.path}/releases_apks';

      final db = DatabaseService(
        dataDir: dataDir.path,
        backupDir: bkpDir.path,
        releasesDir: relDir,
      );
      await db.init();

      final cfg = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: bkpDir,
      );
      await cfg.init();

      final signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => (i * 5 + 3) % 256));

      final excel = ExcelExportService(dbService: db, configService: cfg);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: mirrorDir.path,
        dpapiService: MockDpapiService('UNIT-P25-F2'),
        dbService: db,
        configService: cfg,
        signer: signer,
      );
      await vault.initialize();

      return (db: db, cfg: cfg, signer: signer, excel: excel, vault: vault);
    }

    Future<String> sendRawHttp(int port, String rawRequest) async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.write(rawRequest);
      await socket.flush();
      final bytes = await socket.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      socket.destroy();
      return utf8.decode(bytes, allowMalformed: true);
    }

    test('1. Middleware PIN (HTTP 423 Locked) protege todos los sub-routers',
        () async {
      final svc = await buildTempServices();
      final pinSetup = await svc.vault.configurePin(pin: '246810', enabled: true);
      expect(pinSetup['ok'], isTrue);
      svc.vault.revokeSession(pinSetup['session_token'] as String?);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      try {
        server.listen(
          (req) => admin_server.handleRequest(
            req,
            svc.db,
            svc.signer,
            svc.cfg,
            svc.excel,
            svc.vault,
            onExitOverride: (_) {},
            apkInspectorService: ApkInspectorService(
              cacheFilePath: '${tempDir.path}/data/.apk_cache.json',
            ),
            clientSyncService: ClientSyncService(),
            commercialSyncService: CommercialConfigSyncService(),
          ),
        );

        final baseUrl = 'http://127.0.0.1:${server.port}';

        Future<(int, Map<String, dynamic>)> callJson(
          String method,
          String route, {
          String? headerToken,
          String? cookieHeader,
          Map<String, dynamic>? body,
        }) async {
          final req = await client.openUrl(method, Uri.parse('$baseUrl$route'));
          if (headerToken != null) {
            req.headers.set('X-Vault-Session-Token', headerToken);
          }
          if (cookieHeader != null) {
            req.headers.set('Cookie', cookieHeader);
          }
          if (body != null) {
            req.headers.contentType = ContentType.json;
            req.write(jsonEncode(body));
          }
          final resp = await req.close();
          final raw = await utf8.decodeStream(resp);
          return (resp.statusCode, jsonDecode(raw) as Map<String, dynamic>);
        }

        // Rutas exentas permanecen accesibles (200 OK) sin sesión
        final (healthCode, _) = await callJson('GET', '/api/vault/health');
        expect(healthCode, equals(200));
        final (pinStatusCode, pinStatusJson) =
            await callJson('GET', '/api/vault/pin/status');
        expect(pinStatusCode, equals(200));
        expect(pinStatusJson['pin_enabled'], isTrue);
        expect(pinStatusJson['locked'], isTrue);

        // Todos los sub-routers protegidos devuelven 423 Locked sin token/cookie
        final protectedEndpoints = <(String, String, Map<String, dynamic>?)>[
          ('GET', '/api/dashboard', null),
          ('GET', '/api/clients', null),
          ('GET', '/api/finances', null),
          ('GET', '/api/backups', null),
          ('GET', '/api/releases', null),
          ('GET', '/api/releases/search-dirs', null),
          ('GET', '/api/config', null),
          ('GET', '/api/system/mode', null),
          ('POST', '/api/system/shutdown', null),
          ('GET', '/api/vault/audit', null),
          ('POST', '/api/licenses/inspect', {'token': 'ML9-INVALID'}),
        ];

        for (final (m, route, payload) in protectedEndpoints) {
          final req = await client.openUrl(m, Uri.parse('$baseUrl$route'));
          if (payload != null) {
            req.headers.contentType = ContentType.json;
            req.write(jsonEncode(payload));
          }
          final resp = await req.close();
          final body = await utf8.decodeStream(resp);
          expect(
            resp.statusCode,
            equals(423),
            reason: 'Ruta $m $route debe bloquear con 423 Locked sin PIN',
          );
          expect(jsonDecode(body)['locked'], isTrue);
        }

        // Autenticación vía /api/vault/pin/verify emite cookie HttpOnly y token válido
        final verifyReq =
            await client.postUrl(Uri.parse('$baseUrl/api/vault/pin/verify'));
        verifyReq.headers.contentType = ContentType.json;
        verifyReq.write(jsonEncode({'pin': '246810'}));
        final verifyResp = await verifyReq.close();
        expect(verifyResp.statusCode, equals(200));
        final verifyJson =
            jsonDecode(await utf8.decodeStream(verifyResp)) as Map<String, dynamic>;
        final sessionToken = verifyJson['session_token'] as String;
        expect(sessionToken, isNotEmpty);

        final sessionCookie = verifyResp.cookies.firstWhere(
          (c) => c.name == 'vault_session_token',
        );
        expect(sessionCookie.httpOnly, isTrue);
        expect(sessionCookie.value, equals(sessionToken));

        // Desbloqueo con Header X-Vault-Session-Token y con Cookie HttpOnly
        for (final route in [
          '/api/dashboard',
          '/api/clients',
          '/api/finances',
          '/api/releases',
          '/api/config',
          '/api/vault/audit',
        ]) {
          final reqHdr = await client.getUrl(Uri.parse('$baseUrl$route'));
          reqHdr.headers.set('X-Vault-Session-Token', sessionToken);
          final respHdr = await reqHdr.close();
          await respHdr.drain<void>();
          expect(respHdr.statusCode, equals(200),
              reason: '$route debe responder 200 con X-Vault-Session-Token');

          final reqCok = await client.getUrl(Uri.parse('$baseUrl$route'));
          reqCok.headers.set('Cookie', 'vault_session_token=$sessionToken');
          final respCok = await reqCok.close();
          await respCok.drain<void>();
          expect(respCok.statusCode, equals(200),
              reason: '$route debe responder 200 con Cookie HttpOnly');
        }
      } finally {
        client.close(force: true);
        await server.close(force: true);
      }
    });

    test('2. Fix D-ADM-09 en StaticHandler y ensamblado seguro HtmlTemplateAssembler',
        () async {
      final svc = await buildTempServices();
      final webRoot = Directory('${tempDir.path}/web')
        ..createSync(recursive: true);
      Directory('${webRoot.path}/partials').createSync(recursive: true);
      await File('${webRoot.path}/partials/banner.html')
          .writeAsString('<div id="partialBanner">OK_PARTIAL</div>');
      await File('${webRoot.path}/index.html').writeAsString(
        '<!doctype html><html><body><!-- @PARTIAL:partials/banner.html --><main>ADMIN_SHELL</main></body></html>',
      );
      await File('${webRoot.path}/app.js').writeAsString('console.log("ok");');

      // Archivos sensibles FUERA de webRoot que jamás deben exponerse
      await File('${tempDir.path}/server.dart')
          .writeAsString('SECRET_SERVER_CODE');
      await File('${tempDir.path}/data/prod_clients_db.json')
          .writeAsString('{"secret":"PROD_DB_LEAK"}');

      final assembled = await HtmlTemplateAssembler.assemble(webRoot.path);
      expect(assembled, contains('<div id="partialBanner">OK_PARTIAL</div>'));
      expect(assembled, contains('ADMIN_SHELL'));

      // Bloqueo de escape en @PARTIAL
      final badWebDir = Directory('${tempDir.path}/bad_web')
        ..createSync(recursive: true);
      await File('${badWebDir.path}/index.html').writeAsString(
        '<html><!-- @PARTIAL:../server.dart --></html>',
      );
      await expectLater(
        HtmlTemplateAssembler.assemble(badWebDir.path),
        throwsA(isA<FormatException>()),
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      try {
        server.listen(
          (req) => ApiRouter.handleRequest(
            req,
            svc.db,
            svc.signer,
            svc.cfg,
            svc.excel,
            svc.vault,
            webRoot: webRoot.path,
          ),
        );

        // GET / sirve index.html ensamblado con 200 OK
        final okRaw = await sendRawHttp(
          server.port,
          'GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
        );
        expect(okRaw, contains('200 OK'));
        expect(okRaw, contains('OK_PARTIAL'));

        // Ataques Path-Traversal rechazados (403/404) sin fuga alguna
        final traversalPaths = [
          '/../server.dart',
          '/%2e%2e/data/prod_clients_db.json',
          r'/..\server.dart',
          r'/..\pubspec.yaml',
          '/../../data/prod_clients_db.json',
          '/no_existe.json',
        ];
        for (final attackPath in traversalPaths) {
          final respRaw = await sendRawHttp(
            server.port,
            'GET $attackPath HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
          );
          final firstLine = respRaw.split('\r\n').first;
          expect(
            firstLine.contains('403') || firstLine.contains('404'),
            isTrue,
            reason: 'Attack $attackPath obtuvo status inesperado: $firstLine',
          );
          expect(respRaw, isNot(contains('SECRET_SERVER_CODE')));
          expect(respRaw, isNot(contains('PROD_DB_LEAK')));
        }
      } finally {
        await server.close(force: true);
      }
    });

    test('3. Censo completo Bloque I (< 600 L backend, server < 220 L) y paridad DatabaseService',
        () async {
      final adminRoot = WebBundleLoader.resolveAdminRoot();

      final serverFile = File('${adminRoot.path}/server.dart');
      expect(serverFile.existsSync(), isTrue);
      final serverLines = serverFile.readAsLinesSync().length;
      expect(
        serverLines,
        lessThan(220),
        reason: 'server.dart tiene $serverLines líneas (>= 220)',
      );

      final dbBarrel = File('${adminRoot.path}/lib/database_service.dart');
      expect(dbBarrel.existsSync(), isTrue);
      final barrelLines = dbBarrel.readAsLinesSync();
      expect(barrelLines.length, lessThan(20));
      expect(
        barrelLines.every((l) => l.trim().isEmpty || l.trim().startsWith('export ')),
        isTrue,
      );

      // Todos los archivos .dart bajo lib/ deben tener < 600 líneas (0 monolitos)
      final libDir = Directory('${adminRoot.path}/lib');
      final allLibDart = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(allLibDart.length, greaterThanOrEqualTo(40));
      for (final file in allLibDart) {
        final count = file.readAsLinesSync().length;
        expect(
          count,
          lessThan(600),
          reason: '${file.path} supera el tope (< 600 L): $count líneas',
        );
      }

      // Paridad de firmas estáticas compartidas en server.dart y DatabaseService
      expect(admin_server.compareSemVer('9.41.0', '9.40.1'), greaterThan(0));
      expect(DatabaseService.compareSemVer('9.41.0', '9.40.1'), greaterThan(0));
      expect(
        admin_server.buildWindowsClipboardPsArgs(r'C:\tmp\app.apk'),
        contains('-STA'),
      );
      expect(
        admin_server.buildWindowsFolderPickerPsArgs(),
        contains('-STA'),
      );

      // Round-trip DatabaseService sobre tempDir
      final svc = await buildTempServices();
      final created = await svc.db.createClient({
        'business_name': 'Librería Central, SAC',
        'owner_name': 'Ana Torres',
        'phone': '987654321',
        'license_type': 'MENSUAL',
      });
      expect(created['id'], startsWith('CLI-'));
      await svc.db.addManualPayment(created['id'] as String, {
        'amount': 35.0,
        'method': 'Yape',
        'plan': 'MENSUAL',
      });
      final finances = await svc.db.getConsolidatedFinances();
      expect(finances, isNotEmpty);
      final csvClients = await svc.db.exportClientsToCsv();
      expect(csvClients, contains('"Librería Central, SAC"'));
      final backup = await svc.db.createManualBackup();
      expect(backup['ok'], isTrue);
    });
  });
}
