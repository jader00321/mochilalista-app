import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../lib/commercial_config_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';
import 'support/web_bundle_loader.dart';

class _TestDpapiService implements DpapiService {
  @override
  bool get isSupported => true;

  @override
  Future<Uint8List?> protect(Uint8List data, {Uint8List? entropy}) async =>
      Uint8List.fromList(data.map((b) => b ^ 0x5A).toList());

  @override
  Future<Uint8List?> unprotect(Uint8List encryptedData,
          {Uint8List? entropy}) async =>
      Uint8List.fromList(encryptedData.map((b) => b ^ 0x5A).toList());
}

Future<Map<String, dynamic>> _httpJson(
  HttpClient client,
  String method,
  Uri uri, {
  Map<String, dynamic>? body,
}) async {
  final req = await client.openUrl(method, uri);
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  final raw = await utf8.decodeStream(res);
  final decoded = raw.trim().isNotEmpty ? jsonDecode(raw) : null;
  return {
    'status': res.statusCode,
    'body': decoded,
    'raw': raw,
  };
}

String _extractSection(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + 1);
  if (start < 0 || end < 0 || end <= start) {
    throw StateError(
        'No se encontraron marcadores "$startMarker" -> "$endMarker"');
  }
  return source.substring(start, end);
}

void main() {
  group(
      'PLAN MAESTRO 24 - FASE 3: Exportador Dart Completo OwnerCommercialDefaults y Vía 2 (#mlc1PaneDart)',
      () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late Directory mirrorDir;
    late String releasesDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late LicenseSigner signer;
    late ExcelExportService excelService;
    late VaultStorageService vaultStorage;
    late CommercialConfigSyncService syncService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p24_fase3_');
      dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      mirrorDir = Directory('${tempDir.path}/mirror')
        ..createSync(recursive: true);
      releasesDir = '${tempDir.path}/releases_apks';
      Directory(releasesDir).createSync(recursive: true);

      dbService = DatabaseService(
        dataDir: dataDir.path,
        backupDir: backupsDir.path,
        releasesDir: releasesDir,
      );
      await dbService.init();

      configService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await configService.init();

      signer = LicenseSigner();
      await signer
          .initWithSeed(List<int>.generate(32, (i) => (i * 29 + 3) % 256));

      excelService = ExcelExportService(
        dbService: dbService,
        configService: configService,
      );

      vaultStorage = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: mirrorDir.path,
        dpapiService: _TestDpapiService(),
        dbService: dbService,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();

      syncService = CommercialConfigSyncService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        '1. GET /api/config/dart-defaults-snippet y POST /api/config/generate-sync-token generan owner_commercial_defaults.dart válido y certificado con dart analyze',
        () async {
      final patchedCfg =
          jsonDecode(jsonEncode(configService.config)) as Map<String, dynamic>;
      patchedCfg['legal_identity']['support_phone'] = '+51 987 654 321';
      patchedCfg['payment_methods']['yape_plin_phone'] = '987654321';
      patchedCfg['payment_methods']['yape_plin_holder'] =
          r"O'Connor $Corp \ Peru";
      patchedCfg['payment_methods']['bcp_account_holder'] =
          'Titular BCP Oficial';
      patchedCfg['payment_methods']['bcp_account_number'] = '191-55566677-0-99';
      patchedCfg['payment_methods']['bcp_cci'] = '002-191-005556667709-99';
      patchedCfg['payment_methods']['bbva_account_holder'] =
          'Titular BBVA Oficial';
      patchedCfg['payment_methods']['bbva_account_number'] =
          '0011-0123-0200456789';
      patchedCfg['payment_methods']['bbva_cci'] = '011-123-000200456789-34';
      patchedCfg['catalog']['MENSUAL']['price'] = 39.50;
      patchedCfg['catalog']['MENSUAL']['label'] = r"Plan 'Promo' $39.50";
      patchedCfg['catalog']['PERPETUO_LIBERADO']['updates_window_months'] = 0;
      patchedCfg['catalog']['PASE_ACTUALIZACION_ANUAL']['updates_window_months'] =
          0;
      await configService.saveConfig(patchedCfg);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            dbService,
            signer,
            configService,
            excelService,
            vaultStorage,
            commercialSyncService: syncService,
          ));
      final baseUrl = 'http://127.0.0.1:${server.port}';
      final http = HttpClient();

      try {
        // 1A. GET es solo lectura y NO incrementa revisión (0)
        final getRes = await _httpJson(
          http,
          'GET',
          Uri.parse('$baseUrl/api/config/dart-defaults-snippet'),
        );
        expect(getRes['status'], equals(200));
        final bodyGet = getRes['body'] as Map<String, dynamic>;
        expect(bodyGet['ok'], isTrue);
        expect(bodyGet['revision'], equals(0));
        expect(configService.commercialSyncRevision, equals(0));
        expect(
          bodyGet['target_file_path'],
          equals('app_movil/lib/core/config/owner_commercial_defaults.dart'),
        );
        expect(
          bodyGet['download_filename'],
          equals('owner_commercial_defaults.dart'),
        );

        final snippetGet = bodyGet['dart_snippet'] as String;
        expect(snippetGet, contains('class OwnerCommercialDefaults {'));
        expect(
          snippetGet,
          contains('static const int commercialSyncDefaultRevision = 0;'),
        );
        expect(
          snippetGet,
          contains(r"static const String yapePlinHolder = 'O\'Connor \$Corp \\ Peru';"),
        );
        expect(
          snippetGet,
          contains(r"Plan \'Promo\' \$39.50"),
        );
        expect(
          snippetGet,
          contains("static const String bcpAccountHolder = 'Titular BCP Oficial';"),
        );
        expect(
          snippetGet,
          contains("static const String bbvaAccountNumber = '0011-0123-0200456789';"),
        );
        expect(
          snippetGet,
          contains('static const Map<String, Map<String, Object>> defaultCommercialPlans = {'),
        );
        for (final id in CommercialConfigSyncService.catalogSlugToSyncId.values) {
          expect(snippetGet, contains("'$id': {"));
        }
        // Ambos con updates=12 saneados automáticamente
        final perpetuaSection = _extractSection(
          snippetGet,
          "'perpetua': {",
          "'bolsa_extra_ia': {",
        );
        expect(perpetuaSection, contains("'um': 12,"));
        final paseSection = _extractSection(
          snippetGet,
          "'pase_anual_updates': {",
          "'migracion': {",
        );
        expect(paseSection, contains("'um': 12,"));
        expect(snippetGet.trimRight().endsWith('}'), isTrue);

        // 1B. POST /api/config/generate-sync-token retorna metadata Vía 2 y revisión #1
        final postRes = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/generate-sync-token'),
          body: {},
        );
        expect(postRes['status'], equals(200));
        final bodyPost = postRes['body'] as Map<String, dynamic>;
        expect(bodyPost['revision'], equals(1));
        expect(
          bodyPost['target_file_path'],
          equals('app_movil/lib/core/config/owner_commercial_defaults.dart'),
        );
        expect(
          bodyPost['download_filename'],
          equals('owner_commercial_defaults.dart'),
        );
        final snippetPost = bodyPost['dart_snippet'] as String;
        expect(
          snippetPost,
          contains('static const int commercialSyncDefaultRevision = 1;'),
        );

        // 1C. Verificar con dart analyze real sobre archivo guardado en tempDir
        final pkgDir = Directory('${tempDir.path}/dart_pkg')
          ..createSync(recursive: true);
        Directory('${pkgDir.path}/lib').createSync(recursive: true);
        File('${pkgDir.path}/pubspec.yaml').writeAsStringSync('''
name: dart_defaults_verify
environment:
  sdk: ^3.0.0
''');
        final dartOutFile =
            File('${pkgDir.path}/lib/owner_commercial_defaults.dart');
        dartOutFile.writeAsStringSync(snippetPost, flush: true);

        final analyzeRes = await Process.run(
          'dart',
          ['analyze'],
          workingDirectory: pkgDir.path,
        );
        expect(
          analyzeRes.exitCode,
          equals(0),
          reason:
              'dart analyze falló en archivo generado:\nSTDOUT: ${analyzeRes.stdout}\nSTDERR: ${analyzeRes.stderr}',
        );
        expect(analyzeRes.stdout.toString(), contains('No issues found!'));

        // 1D. Paridad estructural con el archivo real en app_movil/
        final mobileDefaultsFile = File(
          '../app_movil/lib/core/config/owner_commercial_defaults.dart',
        );
        expect(mobileDefaultsFile.existsSync(), isTrue);
        final mobileSrc = mobileDefaultsFile.readAsStringSync();
        expect(mobileSrc, contains('class OwnerCommercialDefaults {'));
        for (final field in [
          'commercialSyncDefaultRevision',
          'authorFullName',
          'appCommercialName',
          'legalFrameworkNotice',
          'personalDataLawNotice',
          'supportPhone',
          'supportWhatsAppUrl',
          'officialWebsite',
          'yapePlinHolder',
          'yapePlinPhone',
          'bcpAccountHolder',
          'bcpAccountNumber',
          'bcpCciNumber',
          'bbvaAccountHolder',
          'bbvaAccountNumber',
          'bbvaCciNumber',
          'defaultCommercialPlans',
        ]) {
          expect(mobileSrc, contains(field), reason: 'Falta campo $field en móvil');
          expect(snippetPost, contains(field),
              reason: 'Falta campo $field en archivo generado');
        }
      } finally {
        http.close(force: true);
        await server.close(force: true);
      }
    });

    test(
        '2. Auditoría HTML/CSS/JS de Vía 2 (#mlc1PaneDart) + Node.js downloadMlc1DartDefaultsFile()',
        () async {
      final html = WebBundleLoader.loadHtml();
      final css = WebBundleLoader.loadCss();
      final js = WebBundleLoader.loadJs();

      final dartPaneHtml = _extractSection(
        html,
        'id="mlc1PaneDart"',
        '<div class="modal-footer"',
      );
      expect(
        dartPaneHtml,
        contains('app_movil/lib/core/config/owner_commercial_defaults.dart'),
      );
      expect(dartPaneHtml, contains('id="mlc1DartTargetPath"'));
      expect(dartPaneHtml, contains('Paso 1:'));
      expect(dartPaneHtml, contains('Paso 2:'));
      expect(dartPaneHtml, contains('Ctrl+A'));
      expect(dartPaneHtml, contains('Ctrl+V'));
      expect(dartPaneHtml, contains('compilar_release_dual.bat'));
      expect(dartPaneHtml, contains('id="btnCopyMlc1Dart"'));
      expect(dartPaneHtml, contains('Copiar Archivo Completo (.dart)'));
      expect(dartPaneHtml, contains('id="btnDownloadMlc1Dart"'));
      expect(dartPaneHtml, contains('Descargar archivo .dart'));

      // SVGs acotados y cero emojis en #mlc1PaneDart + CSS Vía 2 + JS Sección 8B
      for (final match in RegExp(r'<svg\b[^>]*>').allMatches(dartPaneHtml)) {
        final tag = match.group(0)!;
        expect(
          tag.contains('width=') && tag.contains('height='),
          isTrue,
          reason: 'SVG sin width/height en #mlc1PaneDart: $tag',
        );
      }

      final dartCss = _extractSection(
        css,
        '.mlc1-dart-target-box',
        '/* 5. Densidad Compacta de Tablas',
      );
      final afterDartCss = css.substring(css.indexOf('.mlc1-dart-target-box'));
      expect(dartCss, contains('.mlc1-dart-path-code'));
      expect(afterDartCss, contains('[data-theme="light"] .mlc1-dart-target-box'));
      expect(afterDartCss, contains('[data-theme="light"] .mlc1-dart-path-code'));

      final sec8bJs = _extractSection(
        js,
        '// =================== 8B. EMISOR DECLARATIVO MLC1-',
        '// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL',
      );
      expect(sec8bJs, contains('function downloadMlc1DartDefaultsFile('));

      // Bloques contractuales intactos
      expect(js.indexOf('function formatApkSizeMb('), greaterThan(0));
      expect(
        js.indexOf('function renderSignatureStatusBadge('),
        greaterThan(js.indexOf('function formatApkSizeMb(')),
      );
      expect(
        js.indexOf('let isVerifyAllCatalogRunning = false;'),
        greaterThan(0),
      );
      expect(
        js.indexOf('// =================== 5. INSPECTOR FORENSE DUAL'),
        greaterThan(0),
      );

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      for (final chunk in [dartPaneHtml, dartCss, sec8bJs]) {
        expect(emojiRegex.hasMatch(chunk), isFalse);
      }

      // Prueba Node.js de loadAndOpenCommercialSyncModal, Copiar y Descargar .dart
      final settingsSection = _extractSection(
        js,
        '// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL',
        '// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL',
      );
      final harnessFile = File('${tempDir.path}/p24_fase3_dart_download.js');
      await harnessFile.writeAsString('''
const assert = require('assert');
const vm = require('vm');

class MockClassList {
  constructor() { this.set = new Set(); }
  add(c) { this.set.add(c); }
  remove(c) { this.set.delete(c); }
  toggle(c, f) { if (f) this.set.add(c); else this.set.delete(c); }
  contains(c) { return this.set.has(c); }
}

const elMap = {};
const createdLinks = [];
function el(id) {
  if (!elMap[id]) {
    elMap[id] = {
      id,
      classList: new MockClassList(),
      style: {},
      value: '',
      textContent: '',
      innerHTML: '',
      listeners: {},
      disabled: false,
      addEventListener(e, fn) { (this.listeners[e] = this.listeners[e] || []).push(fn); },
      dispatch(e) { (this.listeners[e] || []).forEach(fn => fn({ target: this })); }
    };
  }
  return elMap[id];
}

[
  'modalCommercialConfigSync', 'mlc1PaneToken', 'mlc1PaneDart',
  'mlc1RevisionBadge', 'mlc1IssuedAtLimaBadge', 'mlc1PayloadSizeBadge',
  'mlc1AccountsSummary', 'mlc1PlansSummaryBody', 'mlc1EmptyResultHint',
  'mlc1TokenResultContainer', 'mlc1TokenOutput', 'mlc1QrContainer',
  'btnAuditMlc1InInspector', 'mlc1QrMetaBadge',
  'mlc1DartTargetPath', 'mlc1DartSnippetOutput',
  'btnCopyMlc1Dart', 'btnDownloadMlc1Dart'
].forEach(id => el(id));

const createdBlobs = [];
const revokedUrls = [];
const copiedTexts = [];
const toasts = [];

class MockBlob {
  constructor(parts, opts) {
    this.parts = parts;
    this.type = opts?.type || '';
    createdBlobs.push(this);
  }
}

const sandbox = {
  console, Blob: MockBlob, setTimeout,
  URL: {
    createObjectURL(blob) { return 'blob:mock-' + createdBlobs.length; },
    revokeObjectURL(url) { revokedUrls.push(url); }
  },
  document: {
    documentElement: { setAttribute() {}, getAttribute() { return 'dark'; } },
    body: {
      appendChild(node) { createdLinks.push({ appended: node }); },
      removeChild() {}
    },
    getElementById(id) { return elMap[id] || null; },
    createElement(tag) {
      if (tag === 'a') {
        const anchor = {
          tagName: 'A', href: '', download: '', style: {}, clicked: 0, removed: 0,
          click() { this.clicked++; },
          remove() { this.removed++; }
        };
        createdLinks.push(anchor);
        return anchor;
      }
      return el('dyn_' + tag);
    },
    querySelectorAll() { return []; },
    querySelector() { return null; }
  },
  ownerConfig: { system: { commercial_sync_revision: 0 }, catalog: {}, templates: {} },
  openModal() {},
  closeModal() {},
  showToast: (m, t) => toasts.push({ m, t }),
  copyPlainTextToClipboard: (txt, msg) => copiedTexts.push({ txt, msg }),
  escapeHtml: (s) => String(s ?? ''),
  fetch: async (url) => {
    if (url === '/api/config/dart-defaults-snippet') {
      return {
        ok: true, status: 200,
        json: async () => ({
          ok: true,
          revision: 4,
          target_file_path: 'app_movil/lib/core/config/owner_commercial_defaults.dart',
          download_filename: 'owner_commercial_defaults.dart',
          dart_snippet: '\\uFEFF// Archivo completo\\nclass OwnerCommercialDefaults {}\\n',
          summary: { support_phone: '+51 922 836 879', yape_phone: '922836879', yape_holder: 'Titular', plans: [] }
        })
      };
    }
    return { ok: true, status: 200, json: async () => ({}) };
  }
};
sandbox.window = sandbox;
sandbox.self = sandbox;
sandbox.global = sandbox;

vm.createContext(sandbox);
vm.runInContext(${jsonEncode(settingsSection)}, sandbox);

(async () => {
  sandbox.initSettingsEvents();
  await sandbox.loadAndOpenCommercialSyncModal();

  assert.strictEqual(
    el('mlc1DartTargetPath').textContent,
    'app_movil/lib/core/config/owner_commercial_defaults.dart'
  );
  assert.ok(el('mlc1DartSnippetOutput').value.includes('class OwnerCommercialDefaults'));

  // Copiar archivo completo (.dart)
  el('btnCopyMlc1Dart').dispatch('click');
  assert.strictEqual(copiedTexts.length, 1);
  assert.ok(copiedTexts[0].txt.includes('class OwnerCommercialDefaults'));

  // Descargar archivo .dart (UTF-8 sin BOM, nombre exacto)
  el('btnDownloadMlc1Dart').dispatch('click');
  assert.strictEqual(createdBlobs.length, 1);
  assert.strictEqual(createdBlobs[0].type, 'text/plain;charset=utf-8');
  assert.strictEqual(createdBlobs[0].parts[0].startsWith('\\uFEFF'), false);
  const anchor = createdLinks.find(x => x.tagName === 'A');
  assert.ok(anchor && anchor.download === 'owner_commercial_defaults.dart');
  assert.strictEqual(anchor.clicked, 1);
  assert.ok(toasts.some(t => t.t === 'success' && t.m.includes('owner_commercial_defaults.dart')));

  console.log('PLAN24_FASE3_UI_NODE_OK');
})();
''');

      final res = await Process.run('node', [harnessFile.path]);
      expect(
        res.exitCode,
        equals(0),
        reason: 'Node test Fase 3 falló:\nSTDOUT: ${res.stdout}\nSTDERR: ${res.stderr}',
      );
      expect(res.stdout.toString(), contains('PLAN24_FASE3_UI_NODE_OK'));
    });
  });
}
