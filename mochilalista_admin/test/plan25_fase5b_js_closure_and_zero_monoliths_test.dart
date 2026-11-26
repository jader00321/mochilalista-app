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
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart' as admin_server;
import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 25 - FASE 5B: Cierre JS Bloque 2B y Cero Monolitos en mochilalista_admin', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_plan25_fase5b_');
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

    test('1. Cero monolitos en todo mochilalista_admin/: retiro de admin_app.js y styles.css + límites por capa', () {
      final adminRoot = WebBundleLoader.resolveAdminRoot();
      final webRoot = WebBundleLoader.resolveWebRoot();

      expect(
        File('${webRoot.path}/js/admin_app.js').existsSync(),
        isFalse,
        reason: 'admin_app.js monolítico debe haberse eliminado definitivamente en Fase 5B',
      );
      expect(
        File('${webRoot.path}/css/styles.css').existsSync(),
        isFalse,
        reason: 'styles.css monolítico debe haberse eliminado en Fase 3',
      );

      final serverFile = File('${adminRoot.path}/server.dart');
      expect(serverFile.existsSync(), isTrue);
      final serverLines = serverFile.readAsLinesSync().length;
      expect(serverLines, lessThan(220),
          reason: 'server.dart debe permanecer < 220 L: $serverLines L');

      final indexFile = WebBundleLoader.resolveWebAssetFile('index.html');
      final indexLines = indexFile.readAsLinesSync().length;
      expect(indexLines, lessThan(250),
          reason: 'web/index.html debe permanecer < 250 L: $indexLines L');

      final bootstrapFile = WebBundleLoader.resolveWebAssetFile('js/bootstrap.js');
      expect(bootstrapFile.existsSync(), isTrue);
      final bootstrapLines = bootstrapFile.readAsLinesSync().length;
      expect(bootstrapLines, lessThan(250),
          reason: 'web/js/bootstrap.js debe ser < 250 L: $bootstrapLines L');

      // Todo lib/** < 600 L
      final libFiles = Directory('${adminRoot.path}/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(libFiles, isNotEmpty);
      for (final f in libFiles) {
        final lc = f.readAsLinesSync().length;
        expect(lc, lessThan(600),
            reason: '${f.path} supera el tope de 600 L en lib/: $lc L');
      }

      // 100% de los archivos productivos bajo web/ (excluyendo solo vendor minificados) < 650 L
      final webFiles = webRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
        final norm = f.path.replaceAll('\\', '/').toLowerCase();
        if (norm.endsWith('/js/qrcode.min.js') || norm.endsWith('/js/jsqr.min.js')) {
          return false;
        }
        return norm.endsWith('.html') || norm.endsWith('.css') || norm.endsWith('.js');
      }).toList();

      expect(webFiles.length, greaterThanOrEqualTo(60));
      var maxLines = 0;
      for (final f in webFiles) {
        final lc = f.readAsLinesSync().length;
        if (lc > maxLines) maxLines = lc;
        expect(lc, lessThan(650),
            reason: '${f.path} supera el tope de 650 L en web/: $lc L');
      }
      expect(maxLines, lessThan(650));

      // Verificar presencia de los 10 módulos Bloque 2B + bootstrap.js en web/index.html
      final rawIndex = indexFile.readAsStringSync();
      for (final expected in [
        'js/modules/finances_backups.js?v=25',
        'js/modules/modals_crud_clients.js?v=25',
        'js/modules/modals_history_and_migrate.js?v=25',
        'js/modules/settings_core_and_dirty.js?v=25',
        'js/modules/settings_form_and_templates.js?v=25',
        'js/modules/mlc1_sync_exporter.js?v=25',
        'js/modules/excel_export.js?v=25',
        'js/bootstrap.js?v=25',
        'js/modules/security_vault_health.js?v=25',
        'js/modules/security_vault_portability.js?v=25',
        'js/modules/security_vault_pin.js?v=25',
      ]) {
        expect(rawIndex, contains('src="$expected"'),
            reason: 'Falta script Bloque 2B en index.html: $expected');
      }
      expect(rawIndex, isNot(contains('admin_app.js')));
    });

    test('2. Integridad JS Zero-Bundler, DRY D-ADM-03/06, compareSemVer único y Node.js runtime Bloque 2B', () async {
      final rawIndex =
          WebBundleLoader.resolveWebAssetFile('index.html').readAsStringSync();
      final linkHrefs = RegExp(
        r'''<link\b[^>]*rel=["\x27]stylesheet["\x27][^>]*href=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();
      final scriptSrcs = RegExp(
        r'''<script\b[^>]*src=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();

      expect(linkHrefs, isNotEmpty);
      expect(scriptSrcs.length, greaterThanOrEqualTo(48));
      for (final h in linkHrefs) {
        expect(h, endsWith('?v=25'), reason: 'CSS debe llevar ?v=25: $h');
      }
      for (final s in scriptSrcs) {
        expect(s, endsWith('?v=25'), reason: 'Script debe llevar ?v=25: $s');
      }

      // node --check individual en todos los scripts y en bundle concatenado
      for (final vendorRel in ['js/qrcode.min.js', 'js/jsqr.min.js']) {
        final res = Process.runSync(
          'node',
          ['--check', WebBundleLoader.resolveWebAssetPath(vendorRel)],
        );
        expect(res.exitCode, equals(0), reason: 'node --check falló en $vendorRel');
      }
      for (final p in WebBundleLoader.jsFilePaths()) {
        final res = Process.runSync('node', ['--check', p]);
        expect(res.exitCode, equals(0), reason: 'node --check falló en $p: ${res.stderr}');
      }

      final bundleFile = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'plan25_fase5b_bundle.js',
      );
      final concatCheck = Process.runSync('node', ['--check', bundleFile.path]);
      expect(concatCheck.exitCode, equals(0),
          reason: 'node --check falló en bundle concatenado: ${concatCheck.stderr}');

      final fullJs = bundleFile.readAsStringSync();
      expect(
        RegExp(r'^\s*(?:async\s+)?function\s+compareSemVer\s*\(', multiLine: true)
            .allMatches(fullJs)
            .length,
        equals(1),
      );

      // DRY D-ADM-03 & D-ADM-06: 0 navigator.clipboard.write* en modules/ ni bootstrap.js, 0 api.whatsapp.com/send fuera de core/whatsapp.js
      final webRoot = WebBundleLoader.resolveWebRoot();
      final modFiles = Directory('${webRoot.path}/js/modules')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.js'))
          .toList()
        ..add(WebBundleLoader.resolveWebAssetFile('js/bootstrap.js'));

      for (final f in modFiles) {
        final content = f.readAsStringSync();
        expect(content, isNot(contains('navigator.clipboard.writeText')),
            reason: 'D-ADM-03 violado (writeText directo) en ${f.path}');
        expect(content, isNot(contains('navigator.clipboard.write(')),
            reason: 'D-ADM-03 violado (write directo) en ${f.path}');
        expect(content, isNot(contains('api.whatsapp.com/send')),
            reason: 'D-ADM-06 violado (URL WA manual) en ${f.path}');
      }

      // Paridad 100% handlers inline HTML vs declaraciones JS y ejecución DRY en Node.js
      final fullHtml = WebBundleLoader.loadHtml();
      const domBuiltins = {
        'getElementById',
        'if',
        'preventDefault',
        'stopPropagation',
        'closest',
        'focus',
        'reset',
      };
      final inlineFns = <String>{};
      for (final attr in ['onclick', 'onchange', 'oninput', 'onsubmit']) {
        final rx = RegExp('\\b$attr=["\']([^"\']+)["\']', caseSensitive: false);
        for (final m in rx.allMatches(fullHtml)) {
          for (final fnM in RegExp(r'\b([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(').allMatches(m.group(1)!)) {
            final name = fnM.group(1)!;
            if (!domBuiltins.contains(name)) inlineFns.add(name);
          }
        }
      }
      expect(inlineFns, isNotEmpty);
      for (final fn in inlineFns) {
        final okDecl = RegExp('(?:^|\\n)\\s*(?:async\\s+)?function\\s+$fn\\s*\\(').hasMatch(fullJs) ||
            RegExp('(?:^|\\n)\\s*window\\.$fn\\s*=').hasMatch(fullJs);
        expect(okDecl, isTrue, reason: 'Falta función JS invocada por HTML: $fn()');
      }

      // Ejecución Node real de utilidades DRY + formateadores Bloque 2B
      final runScript = File('${tempDir.path}/p25_fase5b_node_smoke.js');
      await runScript.writeAsString('''
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const paths = [
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/formatters.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/clipboard.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/whatsapp.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/modules/modals_history_and_migrate.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/modules/mlc1_sync_exporter.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/modules/security_vault_health.js'))},
];

const clipboardWrites = [];
const toasts = [];
const sandbox = {
  console, Date, Math, Array, Object, String, Number, Boolean, RegExp, JSON,
  Intl, encodeURIComponent, decodeURIComponent, parseFloat, parseInt, setTimeout,
  clearTimeout, Map, Set, Promise, Error,
  showToast: (m, t) => toasts.push({ m, t }),
  navigator: { clipboard: { writeText: async (txt) => clipboardWrites.push(txt) } },
  document: { getElementById: () => null, querySelector: () => null, querySelectorAll: () => [] },
  window: { open: () => {} },
};
vm.createContext(sandbox);
for (const p of paths) {
  vm.runInContext(fs.readFileSync(p, 'utf8'), sandbox, { filename: p });
}

(async () => {
  sandbox.copyTokenToClipboard('ML9-DRY-TOKEN');
  await new Promise(r => setTimeout(r, 10));
  assert.deepStrictEqual(clipboardWrites, ['ML9-DRY-TOKEN']);
  assert.strictEqual(sandbox.formatVaultBytes(1536), '1.5 KB');
  assert.ok(sandbox.buildSafePublicKitId().startsWith('MLVAULT-'));
  console.log('FASE5B_NODE_SMOKE_OK');
})();
''');
      final nodeRes = await Process.run('node', [runScript.path]);
      expect(nodeRes.exitCode, equals(0),
          reason: 'Node smoke Bloque 2B falló:\n${nodeRes.stdout}\n${nodeRes.stderr}');
      expect(nodeRes.stdout.toString(), contains('FASE5B_NODE_SMOKE_OK'));
    });

    test('3. Verificación HTTP integral vía handleRequest(): GET /, CSS y scripts ?v=25 = 200 OK, 404 en retirados y 403 en partials/', () async {
      final adminRoot = WebBundleLoader.resolveAdminRoot();
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final bkpDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final db = DatabaseService(
        dataDir: dataDir.path,
        backupDir: bkpDir.path,
        releasesDir: '${tempDir.path}/releases_apks',
      );
      await db.init();
      final cfg = ConfigService(dataDirectory: dataDir, backupsDirectory: bkpDir);
      await cfg.init();
      final signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => (i + 17) % 256));
      final excel = ExcelExportService(dbService: db, configService: cfg);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dpapiService: MockDpapiService('UNIT-P25-F5B'),
        dbService: db,
        configService: cfg,
        signer: signer,
      );
      await vault.initialize();

      final rawIndex =
          WebBundleLoader.resolveWebAssetFile('index.html').readAsStringSync();
      final linkHrefs = RegExp(
        r'''<link\b[^>]*rel=["\x27]stylesheet["\x27][^>]*href=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();
      final scriptSrcs = RegExp(
        r'''<script\b[^>]*src=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final prevCwd = Directory.current;
      Directory.current = adminRoot;
      try {
        server.listen((req) {
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
        });

        final homeRaw = await sendRawHttp(
          server.port,
          'GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
        );
        expect(homeRaw.split('\r\n').first, contains('200 OK'));
        expect(homeRaw.toLowerCase(), contains('text/html'));
        expect(homeRaw, isNot(contains('<!-- @PARTIAL:')));
        expect(homeRaw, contains('src="js/bootstrap.js?v=25"'));
        expect(homeRaw, isNot(contains('src="js/admin_app.js')));

        for (final cssRel in linkHrefs) {
          final raw = await sendRawHttp(
            server.port,
            'GET /$cssRel HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
          );
          final status = raw.split('\r\n').first;
          expect(status, contains('200 OK'), reason: 'CSS $cssRel respondió $status');
          expect(raw.toLowerCase(), contains('text/css'),
              reason: 'MIME incorrecto para $cssRel');
        }

        for (final jsRel in scriptSrcs) {
          final raw = await sendRawHttp(
            server.port,
            'GET /$jsRel HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
          );
          final status = raw.split('\r\n').first;
          expect(status, contains('200 OK'), reason: 'JS $jsRel respondió $status');
          expect(raw.toLowerCase(), contains('application/javascript'),
              reason: 'MIME incorrecto para $jsRel');
        }

        for (final retiredPath in ['/js/admin_app.js', '/css/styles.css']) {
          final raw = await sendRawHttp(
            server.port,
            'GET $retiredPath HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
          );
          expect(raw.split('\r\n').first, contains('404'),
              reason: 'Archivo retirado $retiredPath debe devolver 404');
        }

        final partialRaw = await sendRawHttp(
          server.port,
          'GET /partials/tabs/tab_dashboard.html HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
        );
        expect(partialRaw.split('\r\n').first, contains('403'));
      } finally {
        Directory.current = prevCwd;
        await server.close(force: true);
      }
    });
  });
}
