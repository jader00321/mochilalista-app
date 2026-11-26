@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 25 - FASE 4: JS Core DRY, State Store y Módulos Bloque 1', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_plan25_fase4_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Orden determinista ?v=25 en index.html, correspondencia WebBundleLoader y límites < 600 L', () {
      final rawIndex =
          WebBundleLoader.resolveWebAssetFile('index.html').readAsStringSync();
      final scriptSrcs = RegExp(
        r'''<script\b[^>]*src=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();

      expect(scriptSrcs.length, greaterThanOrEqualTo(18));
      for (final src in scriptSrcs) {
        expect(src, endsWith('?v=25'),
            reason: 'Todos los <script> deben llevar ?v=25: $src');
      }

      const vendorPrefix = [
        'js/qrcode.min.js',
        'js/jsqr.min.js',
      ];
      final cleanSrcs = scriptSrcs.map((s) => s.split('?').first).toList();
      expect(cleanSrcs.sublist(0, 2), equals(vendorPrefix));

      final appScripts = cleanSrcs.sublist(2);
      final loaderPaths = WebBundleLoader.jsFilePaths();
      expect(
        loaderPaths,
        equals(appScripts.map(WebBundleLoader.resolveWebAssetPath).toList()),
      );

      final coreIndices = <int>[];
      int? stateIdx;
      final moduleIndices = <int>[];
      int? bootstrapIdx;

      for (var i = 0; i < appScripts.length; i++) {
        final rel = appScripts[i];
        if (rel.startsWith('js/core/')) coreIndices.add(i);
        if (rel == 'js/state/app_store.js') stateIdx = i;
        if (rel.startsWith('js/modules/')) moduleIndices.add(i);
        if (rel == 'js/bootstrap.js') bootstrapIdx = i;
      }

      expect(appScripts, isNot(contains('js/admin_app.js')));
      expect(coreIndices.length, equals(9));
      expect(stateIdx, isNotNull);
      expect(moduleIndices.length, greaterThanOrEqualTo(4));
      expect(bootstrapIdx, isNotNull);
      expect(coreIndices.reduce((a, b) => a > b ? a : b), lessThan(stateIdx!));
      expect(moduleIndices.reduce((a, b) => a < b ? a : b), greaterThan(stateIdx));
      expect(bootstrapIdx!, greaterThan(stateIdx));

      for (final rel in appScripts) {
        final f = WebBundleLoader.resolveWebAssetFile(rel);
        expect(f.existsSync(), isTrue, reason: 'Falta archivo modular $rel');
        final lines = f.readAsLinesSync().length;
        expect(
          lines,
          lessThan(600),
          reason: 'Módulo $rel excede 600 líneas: $lines',
        );
      }

      // Contratos funcionales preservados intactos en el bundle JS
      final fullJs = WebBundleLoader.loadJs();
      expect(fullJs, contains('function formatApkSizeMb('));
      expect(fullJs, contains('function renderSignatureStatusBadge('));
      expect(fullJs, contains('let isVerifyAllCatalogRunning = false;'));
      expect(fullJs, contains('Carga notas compañeras'));
      expect(fullJs, contains('// =================== 5. INSPECTOR FORENSE DUAL'));
      expect(fullJs, contains('// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL'));
    });

    test('2. node --check individual y concatenado, única compareSemVer y cero colisiones let/const', () {
      for (final rel in ['js/qrcode.min.js', 'js/jsqr.min.js']) {
        final res = Process.runSync(
          'node',
          ['--check', WebBundleLoader.resolveWebAssetPath(rel)],
        );
        expect(res.exitCode, equals(0), reason: 'Error sintáctico en $rel: ${res.stderr}');
      }

      for (final absPath in WebBundleLoader.jsFilePaths()) {
        final res = Process.runSync('node', ['--check', absPath]);
        expect(res.exitCode, equals(0),
            reason: 'Error sintáctico en $absPath:\n${res.stderr}');
      }

      final bundleOut = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'plan25_fase4_full_bundle.js',
      );
      final concatRes = Process.runSync('node', ['--check', bundleOut.path]);
      expect(
        concatRes.exitCode,
        equals(0),
        reason: 'node --check falló en bundle concatenado:\n${concatRes.stderr}',
      );

      final concatJs = bundleOut.readAsStringSync();
      final compareDefs = RegExp(
        r'^\s*(?:async\s+)?function\s+compareSemVer\s*\(',
        multiLine: true,
      ).allMatches(concatJs).length;
      expect(compareDefs, equals(1),
          reason: 'D-ADM-01: Debe existir exactamente una definición de compareSemVer');

      final clientsJs =
          WebBundleLoader.resolveWebAssetFile('js/modules/clients_crm.js')
              .readAsStringSync();
      expect(clientsJs, contains('document.createDocumentFragment()'));
      expect(clientsJs, contains('copyPlainTextToClipboard('));
      expect(clientsJs, isNot(contains('navigator.clipboard.writeText')));

      final studioJs =
          WebBundleLoader.resolveWebAssetFile('js/modules/license_studio.js')
              .readAsStringSync();
      expect(studioJs, contains('copyPlainTextToClipboard('));
      expect(studioJs, contains('copyPngBlobToClipboard('));
      expect(studioJs, contains('buildWhatsAppSendUrl('));
      expect(studioJs, isNot(contains('navigator.clipboard.write')));
    });

    test('3. Ejecución Node.js real sobre js/core/* y renderClientsTable con DocumentFragment', () async {
      final bundleFile = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'plan25_fase4_core_exec.js',
      );
      final testJsFile = File('${tempDir.path}/run_fase4_checks.js');

      final scriptContent = '''
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const corePaths = [
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/semver.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/time_lima.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/formatters.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/clipboard.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/core/whatsapp.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/state/app_store.js'))},
  ${jsonEncode(WebBundleLoader.resolveWebAssetPath('js/modules/clients_crm.js'))},
];

const toasts = [];
let execCopyCalls = 0;
let clipboardWriteTextCalls = [];
let tbodyAppendCount = 0;
let createdFragmentsCount = 0;

class FakeNode {
  constructor(tag = 'div', id = '') {
    this.tagName = tag.toUpperCase();
    this.id = id;
    this.children = [];
    this.style = {};
    this.classList = { add() {}, remove() {} };
    this.textContent = '';
    this.value = '';
    this._innerHTML = '';
    this.listeners = {};
  }
  get innerHTML() { return this._innerHTML; }
  set innerHTML(v) {
    this._innerHTML = String(v || '');
    if (this._innerHTML === '') this.children = [];
  }
  appendChild(child) {
    if (child && child.tagName === '#DOCUMENT-FRAGMENT') {
      const moved = [...child.children];
      child.children = [];
      this.children.push(...moved);
    } else {
      this.children.push(child);
    }
    if (this.id === 'clientsTableBody') {
      tbodyAppendCount++;
    }
    return child;
  }
  remove() {}
  select() {}
  addEventListener(e, fn) { this.listeners[e] = fn; }
}

const elMap = {
  clientsTableBody: new FakeNode('tbody', 'clientsTableBody'),
  countAll: new FakeNode('span', 'countAll'),
  countActive: new FakeNode('span', 'countActive'),
  countExpiring: new FakeNode('span', 'countExpiring'),
  countExpired: new FakeNode('span', 'countExpired'),
  countPerpetual: new FakeNode('span', 'countPerpetual'),
  countProspect: new FakeNode('span', 'countProspect'),
  countOutdated: new FakeNode('span', 'countOutdated'),
  countTrial: new FakeNode('span', 'countTrial'),
  countPendingBonus: new FakeNode('span', 'countPendingBonus'),
  countFollowupDue: new FakeNode('span', 'countFollowupDue'),
};

const sandbox = {
  console, Date, Math, Array, Object, String, Number, Boolean, RegExp, Intl,
  JSON, Set, Map, Promise, Error, TextEncoder, URLSearchParams, parseInt,
  encodeURIComponent, decodeURIComponent,
  showToast: (msg, type = 'info') => toasts.push({ msg, type }),
  applyTableDensity: () => {},
  document: {
    body: new FakeNode('body', 'body'),
    getElementById: (id) => elMap[id] || null,
    createElement: (tag) => new FakeNode(tag),
    createDocumentFragment: () => {
      createdFragmentsCount++;
      return new FakeNode('#DOCUMENT-FRAGMENT');
    },
    execCommand: (cmd) => {
      if (cmd === 'copy') execCopyCalls++;
      return true;
    },
  },
  navigator: {
    clipboard: {
      writeText: async (txt) => { clipboardWriteTextCalls.push(txt); },
    },
  },
};
sandbox.window = sandbox;
sandbox.global = sandbox;
vm.createContext(sandbox);

for (const p of corePaths) {
  vm.runInContext(fs.readFileSync(p, 'utf8'), sandbox, { filename: p });
}

(async () => {
  // 1. D-ADM-01: única compareSemVer con soporte +build y v-prefix
  assert.ok(sandbox.compareSemVer('9.41.0+85', '9.41.0+84') > 0);
  assert.ok(sandbox.compareSemVer('9.41.0', '9.40.9') > 0);
  assert.strictEqual(sandbox.compareSemVer('v9.41.0-rc1', '9.41.0'), 0);
  assert.ok(sandbox.compareSemVer(null, '1.0.0') < 0);

  // 2. D-ADM-04: America/Lima GMT-5
  assert.strictEqual(
    sandbox.formatLimaDateTime('2026-11-26T02:30:00.000Z'),
    '25/11/2026 21:30:00 (Lima GMT-5)'
  );
  assert.strictEqual(sandbox.formatLimaIsoDate('2026-11-26T02:30:00.000Z'), '2026-11-25');
  assert.strictEqual(sandbox.formatLimaReceiptStamp('2026-11-26T02:30:00.000Z'), '25/11/2026 21:30');
  assert.strictEqual(sandbox.getLocalIsoDate(new Date('2026-11-26T02:30:00.000Z')), '2026-11-25');

  // 3. D-ADM-05: formatPlanHumanLabel + formatPlanLabel fuente única
  assert.strictEqual(sandbox.formatPlanHumanLabel('MENSUAL'), 'Plan Mensual');
  assert.strictEqual(sandbox.formatPlanLabel('MENSUAL'), 'Mensual');
  assert.strictEqual(sandbox.formatPlanLabel('TRIAL'), 'Trial Gratuito');
  assert.strictEqual(sandbox.formatPlanHumanLabel('PERPETUO_LIBERADO'), 'Licencia Perpetua');
  assert.strictEqual(sandbox.formatPlanLabel('PERPETUO_LIBERADO'), 'Perpetuo Liberado');
  assert.strictEqual(sandbox.normalizePeruPhone('987654321'), '+51987654321');
  assert.strictEqual(sandbox.formatPeruvianPhoneDisplay('51987654321'), '+51987654321');
  assert.strictEqual(sandbox.escapeHtml('<b>"x"</b>'), '&lt;b&gt;&quot;x&quot;&lt;/b&gt;');

  // 4. D-ADM-03: clipboard con navigator y fallback execCommand
  assert.strictEqual(await sandbox.copyPlainTextToClipboard('ABC-123', 'Copiado 1'), true);
  assert.deepStrictEqual(clipboardWriteTextCalls, ['ABC-123']);
  sandbox.navigator = {};
  assert.strictEqual(await sandbox.copyPlainTextToClipboard('XYZ-789', 'Copiado fallback'), true);
  assert.strictEqual(execCopyCalls, 1);

  // 5. D-ADM-06: constructor único de enlaces WhatsApp
  assert.strictEqual(
    sandbox.buildWhatsAppSendUrl('987654321', 'Hola Peru'),
    'https://api.whatsapp.com/send?phone=51987654321&text=Hola%20Peru'
  );
  assert.strictEqual(
    sandbox.buildWhatsAppSendUrl('', 'Solo ficha'),
    'https://api.whatsapp.com/send?text=Solo%20ficha'
  );
  assert.strictEqual(
    sandbox.buildWhatsAppSendUrl('51911222333'),
    'https://api.whatsapp.com/send?phone=51911222333'
  );

  // 6. D-ADM-10: renderClientsTable inserta filas usando un único DocumentFragment
  vm.runInContext(`
    globalClients = [
      { id: 'c1', business_name: 'Tienda A', owner_name: 'Ana', current_device_id: 'DEV-1', license_type: 'MENSUAL', license_expires: '2027-01-01', installed_version: '9.41.0' },
      { id: 'c2', business_name: 'Tienda B', owner_name: 'Luis', current_device_id: 'DEV-2', license_type: 'ANUAL', license_expires: '2027-06-01', installed_version: '9.41.0' },
      { id: 'c3', business_name: 'Tienda C', owner_name: 'Rosa', current_device_id: 'DEV-3', license_type: 'PERPETUO_LIBERADO', installed_version: '9.41.0' },
    ];
    globalReleases = [{ version_name: '9.41.0' }];
  `, sandbox);
  tbodyAppendCount = 0;
  createdFragmentsCount = 0;
  sandbox.renderClientsTable();
  assert.strictEqual(createdFragmentsCount, 1);
  assert.strictEqual(tbodyAppendCount, 1);
  assert.strictEqual(elMap.clientsTableBody.children.length, 3);

  assert.ok(fs.existsSync(${jsonEncode(bundleFile.path)}));
  console.log('PLAN25_FASE4_NODE_EXEC_OK');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
''';

      await testJsFile.writeAsString(scriptContent);
      final res = await Process.run('node', [testJsFile.path]);
      expect(
        res.exitCode,
        equals(0),
        reason: 'Fase 4 Node execution failed:\nSTDOUT:${res.stdout}\nSTDERR:${res.stderr}',
      );
      expect(res.stdout.toString(), contains('PLAN25_FASE4_NODE_EXEC_OK'));
    });
  });
}
