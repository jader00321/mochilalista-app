import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';
import '../lib/license_signer.dart';
import '../lib/excel_export_service.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('Plan Maestro 18 - Fase 1: Lanzador Windows y Prioridad Google Chrome', () {
    final projectRoot = Directory.current.parent;
    final batFile = File('${projectRoot.path}/Iniciar_MochilaLista_Admin.bat');
    final ps1File = File('${projectRoot.path}/Crear_Acceso_Directo_Escritorio.ps1');

    test('1.1. Iniciar_MochilaLista_Admin.bat tiene formato estricto CRLF y ASCII puro', () {
      expect(batFile.existsSync(), isTrue, reason: 'El archivo .bat debe existir en la raiz');

      final bytes = batFile.readAsBytesSync();
      expect(bytes, isNotEmpty);

      // Validar ASCII puro (bytes <= 127)
      for (int i = 0; i < bytes.length; i++) {
        expect(
          bytes[i] <= 127,
          isTrue,
          reason: 'Byte no-ASCII encontrado en offset $i: ${bytes[i]} (debe ser <= 127)',
        );
      }

      // Validar CRLF estricto (\r\n) y cero LF huerfanos (\n sin \r previo)
      bool hasCRLF = false;
      int bareLFCount = 0;
      for (int i = 0; i < bytes.length; i++) {
        if (bytes[i] == 10) {
          if (i > 0 && bytes[i - 1] == 13) {
            hasCRLF = true;
          } else {
            bareLFCount++;
          }
        }
      }

      expect(hasCRLF, isTrue, reason: 'El archivo debe contener saltos de linea CRLF');
      expect(bareLFCount, equals(0), reason: 'El archivo NO debe contener saltos LF sueltos');
    });

    test('1.2. Iniciar_MochilaLista_Admin.bat prioriza Google Chrome, soporta --app y sondeo HTTP', () {
      final content = batFile.readAsStringSync();

      // Debe verificar el sondeo HTTP real contra /api/vault/health
      expect(content.contains('/api/vault/health'), isTrue);

      // Prioridad 1 debe ser Google Chrome
      final chromeIndex = content.indexOf(r'Google\Chrome\Application\chrome.exe');
      final edgeIndex = content.indexOf(r'Microsoft\Edge\Application\msedge.exe');
      expect(chromeIndex, isNonNegative, reason: 'Debe buscar Google Chrome');
      expect(edgeIndex, isNonNegative, reason: 'Debe buscar Microsoft Edge como respaldo');
      expect(chromeIndex < edgeIndex, isTrue, reason: 'Google Chrome debe preceder a Edge');

      // Modos de ejecucion con soporte determinista ?mode=app
      expect(content.contains('--app=http://localhost:8080/?mode=app'), isTrue);
      expect(content.contains('--browser'), isTrue);
      expect(content.contains('-b'), isTrue);

      // Plan 18.5: Cero bloques parentizados if (...) ( ... ) en todo el archivo .bat
      final lines = content.split('\r\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('if ') || trimmed.startsWith('if/i ')) {
          expect(
            trimmed.endsWith('('),
            isFalse,
            reason: 'Prohibido usar bloques if parentizados en .bat por colisiones de parser: "$trimmed"',
          );
        }
      }

      // Uso de flag /D "%ADMIN_DIR%" para evitar comillas anidadas en start
      expect(content.contains('/D "%ADMIN_DIR%"'), isTrue);
    });

    test('1.3. Crear_Acceso_Directo_Escritorio.ps1 tiene codificacion valida y propiedades oficiales', () {
      expect(ps1File.existsSync(), isTrue, reason: 'El script .ps1 debe existir en la raiz');
      final ps1Content = ps1File.readAsStringSync();

      expect(ps1Content.contains('Iniciar_MochilaLista_Admin.bat'), isTrue);
      expect(ps1Content.contains('favicon.ico'), isTrue);
      expect(ps1Content.contains('WindowStyle = 7'), isTrue);
    });
  });

  group('Plan Maestro 18 - Fase 1: Endpoint POST /api/system/open-browser y Exencion PIN', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late LicenseSigner signer;
    late ExcelExportService excelService;
    late VaultStorageService vaultStorage;
    late HttpServer server;
    late HttpClient client;

    String? openedUrl;

    setUp(() async {
      openedUrl = null;
      tempDir = Directory.systemTemp.createTempSync('plan18_fase1_test_');
      dataDir = Directory('${tempDir.path}/data');
      backupsDir = Directory('${tempDir.path}/backups');
      await dataDir.create(recursive: true);
      await backupsDir.create(recursive: true);

      final sandboxClients = File('${dataDir.path}/sandbox_clients_db.json');
      await sandboxClients.writeAsString('[]');
      final sandboxReleases = File('${dataDir.path}/sandbox_releases_db.json');
      await sandboxReleases.writeAsString('[]');

      dbService = DatabaseService(dataDir: dataDir.path, backupDir: backupsDir.path);
      dbService.setMode('sandbox');
      await dbService.init();

      configService = ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await configService.init();

      signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 3 + 7) % 256);
      await signer.initWithSeed(testSeed);

      excelService = ExcelExportService(dbService: dbService, configService: configService);
      vaultStorage = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dbService: dbService,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            dbService,
            signer,
            configService,
            excelService,
            vaultStorage,
            onOpenBrowserOverride: (url) async {
              openedUrl = url;
            },
          ));

      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1.4. POST /api/system/open-browser invoca callback inyectado con URL local y responde 200 OK', () async {
      final req = await client.postUrl(Uri.parse('http://localhost:${server.port}/api/system/open-browser'));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final bodyStr = await res.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;
      expect(json['ok'], isTrue);
      expect(json['url'], equals('http://localhost:8080'));
      expect(openedUrl, equals('http://localhost:8080'));
    });

    test('1.5. GET /api/vault/health y POST /api/system/open-browser estan exentos de bloqueo PIN (HTTP 200)', () async {
      // Activar bloqueo PIN real
      await vaultStorage.configurePin(enabled: true, pin: '730568');

      // 1. /api/vault/health debe responder 200 OK para no congelar el lanzador .bat
      final healthReq = await client.getUrl(Uri.parse('http://localhost:${server.port}/api/vault/health'));
      final healthRes = await healthReq.close();
      expect(healthRes.statusCode, equals(HttpStatus.ok));
      final healthBody = jsonDecode(await healthRes.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(healthBody['status'], isNotNull);

      // 2. /api/system/open-browser debe responder 200 OK incluso si esta bloqueado
      final openReq = await client.postUrl(Uri.parse('http://localhost:${server.port}/api/system/open-browser'));
      final openRes = await openReq.close();
      expect(openRes.statusCode, equals(HttpStatus.ok));
      expect(openedUrl, equals('http://localhost:8080'));

      // 3. Otro endpoint protegido debe responder 423 Locked
      final lockReq = await client.getUrl(Uri.parse('http://localhost:${server.port}/api/clients'));
      final lockRes = await lockReq.close();
      expect(lockRes.statusCode, equals(423));
    });
  });

  group('Plan Maestro 18 - Fase 1: UI Web (#btnOpenInChrome, SVG Limpio y Tooltip)', () {
    test('1.6. index.html contiene el boton #btnOpenInChrome con icono SVG vectorial (sin emojis)', () {
      final html = WebBundleLoader.loadHtml();
      expect(html, isNotEmpty);

      expect(html.contains('id="btnOpenInChrome"'), isTrue);
      expect(html.contains('class="btn-open-in-chrome"'), isTrue);
      expect(html.contains('Abrir en Chrome'), isTrue);

      // Verificar que esta ubicado dentro de .sidebar-footer antes de #btnShutdownServer
      final btnOpenIdx = html.indexOf('id="btnOpenInChrome"');
      final btnShutdownIdx = html.indexOf('id="btnShutdownServer"');
      expect(btnOpenIdx, isNonNegative);
      expect(btnShutdownIdx, isNonNegative);
      expect(btnOpenIdx < btnShutdownIdx, isTrue, reason: '#btnOpenInChrome debe preceder a #btnShutdownServer');

      // Verificar que el boton usa SVG puro y cero emojis crudos
      final buttonSlice = html.substring(btnOpenIdx, btnShutdownIdx);
      expect(buttonSlice.contains('<svg'), isTrue);
      expect(buttonSlice.contains('<circle'), isTrue);
      expect(buttonSlice.contains('<line'), isTrue);
    });

    test('1.7. styles.css define estilos de .btn-open-in-chrome, maquetacion vertical y modo colapsado', () {
      final css = WebBundleLoader.loadCss();
      expect(css, isNotEmpty);

      expect(css.contains('.btn-open-in-chrome'), isTrue);
      expect(css.contains('.app-sidebar.collapsed .btn-open-in-chrome'), isTrue);
      expect(css.contains('[data-theme="light"] .btn-open-in-chrome'), isTrue);

      // Plan 18.5: .sidebar-footer estructurado verticalmente con height auto
      expect(css.contains('flex-direction: column'), isTrue);
      expect(css.contains('height: auto'), isTrue);
      expect(css.contains('width: 38px'), isTrue, reason: 'Modo colapsado debe usar botones cuadrados centrados');
    });

    test('1.8. admin_app.js contiene isDesktopAppMode y visibilidad contextual para #btnOpenInChrome', () {
      final js = WebBundleLoader.loadJs();
      expect(js, isNotEmpty);

      expect(js.contains("document.getElementById('btnOpenInChrome')"), isTrue);
      expect(js.contains("fetch('/api/system/open-browser'"), isTrue);
      expect(js.contains("window.open('http://localhost:8080', '_blank')"), isTrue);
      expect(js.contains("'Abrir en Google Chrome'"), isTrue);

      // Plan 18.5: Helper isDesktopAppMode con deteccion de ?mode=app y display-mode standalone
      expect(js.contains('function isDesktopAppMode()'), isTrue);
      expect(js.contains("get('mode') === 'app'"), isTrue);
      expect(js.contains("'(display-mode: standalone)'"), isTrue);
      expect(js.contains("isDesktopAppMode() ? 'flex' : 'none'"), isTrue);
    });
  });
}
