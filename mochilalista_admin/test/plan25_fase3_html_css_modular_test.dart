@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/apk_inspector_service.dart';
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
  group('PLAN MAESTRO 25 - FASE 3: Capas CSS, Parciales HTML y ?v=25', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_plan25_fase3_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

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

    test('1. Paridad HTML, ensamblado sin @PARTIAL pendientes, límites de línea y cero emojis crudos',
        () async {
      final webRoot = WebBundleLoader.resolveWebRoot();
      final indexFile = WebBundleLoader.resolveWebAssetFile('index.html');
      expect(indexFile.existsSync(), isTrue);

      final indexLines = indexFile.readAsLinesSync().length;
      expect(
        indexLines,
        lessThan(250),
        reason: 'web/index.html tiene $indexLines líneas (>= 250)',
      );

      final partialsDir = Directory('${webRoot.path}/partials');
      expect(partialsDir.existsSync(), isTrue);
      final partialFiles = partialsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'))
          .toList();
      expect(partialFiles.length, greaterThanOrEqualTo(15));
      for (final file in partialFiles) {
        final lc = file.readAsLinesSync().length;
        expect(
          lc,
          lessThan(700),
          reason: '${file.path} supera el límite de 700 líneas: $lc',
        );
      }

      final assembled = await HtmlTemplateAssembler.assemble(webRoot.path);
      expect(assembled, isNotNull);
      expect(assembled!, equals(WebBundleLoader.loadHtml()));
      expect(assembled, isNot(contains('<!-- @PARTIAL:')));

      // Las 8 pestañas, Drawer 360, Kit A4 y modales clave presentes
      for (final requiredId in [
        'tabDashboard',
        'tabClients',
        'tabLicenseStudio',
        'tabReleaseManager',
        'tabInspector',
        'tabFinancesAndBackups',
        'tabSettings',
        'tabSecurityVault',
        'drawerClient360',
        'printableEmergencyKit',
        'modalCreateClient',
        'modalEditClient',
        'modalClientHistory',
        'modalManualPayment',
        'modalPaymentReceipt',
        'modalSyncReported',
        'modalGlobalClientSync',
        'modalMigrateDevice',
        'modalConfirmLicenseEmission',
        'modalConfirm',
        'modalWaComposer',
        'modalQuickQr',
        'modalCreateRelease',
        'modalEditRelease',
        'modalFixClientVersion',
        'modalUnsavedSettings',
        'modalResetSettingsScope',
        'modalCommercialConfigSync',
        'modalImportVault',
        'modalAutoRecovery',
        'modalVaultAuditReport',
        'modalBackupPreview',
        'vaultPinLockOverlay',
      ]) {
        expect(
          assembled,
          contains('id="$requiredId"'),
          reason: 'Falta elemento crítico #$requiredId tras ensamblar parciales',
        );
      }

      // Conteos base mínimos intactos (901 ids, 8 names, 87 onclick, 266 svg)
      final uniqueIds = RegExp(r'\bid="([^"]+)"')
          .allMatches(assembled)
          .map((m) => m.group(1)!)
          .toSet();
      expect(uniqueIds.length, greaterThanOrEqualTo(901));
      expect(RegExp(r'\bonclick=').allMatches(assembled).length,
          greaterThanOrEqualTo(87));
      expect(RegExp(r'<svg\b').allMatches(assembled).length,
          greaterThanOrEqualTo(266));

      const bannedEmojis = ['✅', '⬇️', '📁', '✏️', '🗑️', '📲', 'ℹ️', '🚀', '📦'];
      for (final emoji in bannedEmojis) {
        expect(assembled, isNot(contains(emoji)),
            reason: 'HTML ensamblado contiene emoji crudo prohibido: $emoji');
      }
    });

    test('2. Cascada CSS estricta, caché-busting ?v=25 unificado, retiro de styles.css y límites < 700 L',
        () {
      final webRoot = WebBundleLoader.resolveWebRoot();
      expect(
        File('${webRoot.path}/css/styles.css').existsSync(),
        isFalse,
        reason: 'El monolito css/styles.css debe haber sido retirado en Fase 3',
      );

      final rawIndex =
          WebBundleLoader.resolveWebAssetFile('index.html').readAsStringSync();
      expect(rawIndex, isNot(contains('?v=23')));

      final linkHrefs = RegExp(
        r'''<link\b[^>]*rel=["\x27]stylesheet["\x27][^>]*href=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();
      expect(linkHrefs, isNotEmpty);
      for (final href in linkHrefs) {
        expect(href, endsWith('?v=25'),
            reason: 'Stylesheet $href debe usar ?v=25');
      }

      final scriptSrcs = RegExp(
        r'''<script\b[^>]*src=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();
      expect(scriptSrcs.length, greaterThanOrEqualTo(3));
      for (final src in scriptSrcs) {
        expect(src, endsWith('?v=25'),
            reason: 'Script $src debe usar ?v=25');
      }

      // Correspondencia 1:1 con WebBundleLoader.cssFilePaths() y orden estricto
      final loaderPaths = WebBundleLoader.cssFilePaths();
      final indexCleanPaths = linkHrefs
          .map((h) => WebBundleLoader.resolveWebAssetPath(h.split('?').first))
          .toList();
      expect(loaderPaths, equals(indexCleanPaths));

      final normNames = linkHrefs.map((h) => h.split('?').first).toList();
      expect(normNames.first, equals('css/00_tokens.css'));
      final lastModuleIdx =
          normNames.lastIndexWhere((n) => n.startsWith('css/modules/'));
      final firstLightIdx =
          normNames.indexWhere((n) => n.startsWith('css/90_light_theme'));
      final respIdx = normNames.indexOf('css/95_responsive.css');
      final printIdx = normNames.indexOf('css/99_print.css');

      expect(lastModuleIdx, greaterThan(0));
      expect(firstLightIdx, greaterThan(lastModuleIdx));
      expect(respIdx, greaterThan(firstLightIdx));
      expect(printIdx, equals(normNames.length - 1));

      for (final path in loaderPaths) {
        final f = File(path);
        expect(f.existsSync(), isTrue);
        final lines = f.readAsLinesSync().length;
        expect(lines, lessThan(700),
            reason: 'Hoja CSS $path excede 700 líneas: $lines');
      }

      final concatCss = WebBundleLoader.loadCss();
      expect(
        RegExp(r'\[data-theme=["\x27]light["\x27]\]')
            .allMatches(concatCss)
            .length,
        greaterThanOrEqualTo(144),
      );
      expect(RegExp(r'@media\s+print\b').allMatches(concatCss).length,
          equals(2));
      expect(RegExp(r'@media\b').allMatches(concatCss).length,
          greaterThanOrEqualTo(11));
    });

    test('3. Servicio HTTP real: GET /, /index.html, CSS modulares ?v=25 y bloqueo traversal hacia partials/ o fuera de web/',
        () async {
      final adminRoot = WebBundleLoader.resolveAdminRoot();
      final webRoot = WebBundleLoader.resolveWebRoot();

      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final bkpDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      final db = DatabaseService(
        dataDir: dataDir.path,
        backupDir: bkpDir.path,
        releasesDir: '${tempDir.path}/releases_apks',
      );
      await db.init();
      final cfg = ConfigService(dataDirectory: dataDir, backupsDirectory: bkpDir);
      await cfg.init();
      final signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => (i + 9) % 256));
      final excel = ExcelExportService(dbService: db, configService: cfg);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dpapiService: MockDpapiService('UNIT-P25-F3'),
        dbService: db,
        configService: cfg,
        signer: signer,
      );
      await vault.initialize();

      // Archivo secreto fuera de webRoot temporal para prueba ApiRouter + handleRequest
      await File('${tempDir.path}/secret_outside.txt').writeAsString('TOP_SECRET');

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final prevCwd = Directory.current;
      Directory.current = adminRoot;
      try {
        server.listen((req) {
          if (req.uri.path == '/__check_apirouter') {
            ApiRouter.handleRequest(
              req,
              db,
              signer,
              cfg,
              excel,
              vault,
              webRoot: webRoot.path,
            );
          } else {
            admin_server.handleRequest(
              req,
              db,
              signer,
              cfg,
              excel,
              vault,
              apkInspectorService: ApkInspectorService(
                cacheFilePath: '${tempDir.path}/data/.apk_cache.json',
              ),
            );
          }
        });

        for (final route in ['/', '/index.html']) {
          final respRaw = await sendRawHttp(
            server.port,
            'GET $route HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
          );
          expect(respRaw, contains('200 OK'));
          expect(respRaw.toLowerCase(), contains('text/html'));
          expect(respRaw, contains('id="tabDashboard"'));
          expect(respRaw, contains('id="modalCommercialConfigSync"'));
          expect(respRaw, isNot(contains('<!-- @PARTIAL:')));
        }

        for (final cssRoute in [
          '/css/00_tokens.css?v=25',
          '/css/90_light_theme_base.css?v=25',
          '/css/99_print.css?v=25',
        ]) {
          final cssRaw = await sendRawHttp(
            server.port,
            'GET $cssRoute HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
          );
          expect(cssRaw, contains('200 OK'));
          expect(cssRaw.toLowerCase(), contains('text/css'));
        }

        // Bloqueo hacia partials/ directos y path traversal
        for (final blockedPath in [
          '/partials/tabs/tab_clients.html',
          '/../partials/tabs/tab_clients.html',
          '/%2e%2e/server.dart',
          r'/..\server.dart',
        ]) {
          final blockedRaw = await sendRawHttp(
            server.port,
            'GET $blockedPath HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
          );
          final firstLine = blockedRaw.split('\r\n').first;
          expect(
            firstLine.contains('403') || firstLine.contains('404'),
            isTrue,
            reason: 'Ruta bloqueada $blockedPath devolvió: $firstLine',
          );
          expect(blockedRaw, isNot(contains('Future<void> handleRequest')));
        }
      } finally {
        Directory.current = prevCwd;
        await server.close(force: true);
      }
    });
  });
}
