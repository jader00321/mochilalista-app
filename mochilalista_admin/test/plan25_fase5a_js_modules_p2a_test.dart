@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 25 - FASE 5A: Extracción JS Bloque 2A y Consolidación D-ADM-07', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_plan25_fase5a_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Orden determinista ?v=25, topes < 650 L, adelgazamiento de admin_app.js y marcadores intactos', () {
      final rawIndex =
          WebBundleLoader.resolveWebAssetFile('index.html').readAsStringSync();
      final scriptSrcs = RegExp(
        r'''<script\b[^>]*src=["\x27]([^"\x27]+)["\x27]''',
        caseSensitive: false,
      ).allMatches(rawIndex).map((m) => m.group(1)!).toList();

      expect(scriptSrcs.length, greaterThanOrEqualTo(38));
      for (final src in scriptSrcs) {
        expect(src, endsWith('?v=25'),
            reason: 'Todos los <script> deben llevar ?v=25: $src');
      }

      final cleanSrcs = scriptSrcs.map((s) => s.split('?').first).toList();
      final appScripts = cleanSrcs.sublist(2);
      expect(
        WebBundleLoader.jsFilePaths(),
        equals(appScripts.map(WebBundleLoader.resolveWebAssetPath).toList()),
      );
      expect(appScripts, isNot(contains('js/admin_app.js')));

      // Secuencia cronológica estricta de módulos Bloque 2A -> Sección 6 en finances_backups.js
      for (final expectedModule in [
        'js/modules/receipts_preview_and_canvas.js',
        'js/modules/receipts_canvas_render.js',
        'js/modules/receipts_export_and_events.js',
        'js/modules/drawer_360_core.js',
        'js/modules/drawer_360_profile_tab.js',
        'js/modules/drawer_360_payments.js',
        'js/modules/client_sync_reported.js',
        'js/modules/client_sync_global.js',
        'js/modules/whatsapp_templates.js',
        'js/modules/whatsapp_composer.js',
        'js/modules/releases_catalog.js',
        'js/modules/releases_edit_and_verify.js',
        'js/modules/releases_matrix.js',
        'js/modules/releases_wa_dispatch.js',
        'js/modules/releases_upload_and_dual_guide.js',
        'js/modules/releases_create_and_local_builds.js',
        'js/modules/releases_search_dirs_and_upload.js',
        'js/modules/inspector_history_and_qr.js',
        'js/modules/inspector_mlc1_render.js',
        'js/modules/inspector_sync_and_dispatch.js',
      ]) {
        expect(appScripts, contains(expectedModule),
            reason: 'Falta registrar $expectedModule en web/index.html');
      }

      final waIdx = appScripts.indexOf('js/modules/whatsapp_templates.js');
      final relIdx = appScripts.indexOf('js/modules/releases_catalog.js');
      final inspIdx = appScripts.indexOf('js/modules/inspector_history_and_qr.js');
      final finIdx = appScripts.indexOf('js/modules/finances_backups.js');
      expect(waIdx, lessThan(relIdx));
      expect(relIdx, lessThan(inspIdx));
      expect(inspIdx, lessThan(finIdx));

      for (final rel in appScripts) {
        final f = WebBundleLoader.resolveWebAssetFile(rel);
        expect(f.existsSync(), isTrue, reason: 'Debe existir $rel');
        final lc = f.readAsLinesSync().length;
        expect(lc, lessThan(650),
            reason: '$rel supera el tope de 650 líneas: $lc L');
      }

      final finRem =
          WebBundleLoader.resolveWebAssetFile('js/modules/finances_backups.js')
              .readAsStringSync();
      expect(
        finRem.trimLeft(),
        startsWith('// =================== 6. FINANZAS & RESPALDOS'),
        reason: 'finances_backups.js debe iniciar en Sección 6 para aislar Sección 5',
      );
      final fullJsEarly = WebBundleLoader.loadJs();
      expect(fullJsEarly, contains('// =================== 7. MODALES Y CRUD'));
      expect(fullJsEarly, contains('// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL'));
      expect(fullJsEarly, contains('// =================== 8B. EMISOR DECLARATIVO MLC1-'));
      expect(fullJsEarly, contains('document.addEventListener(\'DOMContentLoaded\''));

      // Contratos intactos en el bundle completo
      final fullJs = WebBundleLoader.loadJs();
      final s3b = fullJs.indexOf('// =================== 3B. COMPOSITOR UNIVERSAL DE WHATSAPP');
      final s4 = fullJs.indexOf('// =================== 4. RELEASE MANAGER');
      final s5 = fullJs.indexOf('// =================== 5. INSPECTOR FORENSE DUAL');
      final s6 = fullJs.indexOf('// =================== 6. FINANZAS');
      expect(s3b, greaterThan(0));
      expect(s4, greaterThan(s3b));
      expect(s5, greaterThan(s4));
      expect(s6, greaterThan(s5));

      final fmtIdx = fullJs.indexOf('function formatApkSizeMb(');
      final sigIdx = fullJs.indexOf('function renderSignatureStatusBadge(');
      final verifyIdx = fullJs.indexOf('let isVerifyAllCatalogRunning = false;');
      final companionIdx = fullJs.indexOf('/**\n * Carga notas compañeras');
      expect(sigIdx, greaterThan(fmtIdx));
      expect(companionIdx, greaterThan(verifyIdx));
    });

    test('2. node --check individual y concatenado, única compareSemVer y cero colisiones let/const', () {
      for (final rel in ['js/qrcode.min.js', 'js/jsqr.min.js']) {
        final res = Process.runSync(
          'node',
          ['--check', WebBundleLoader.resolveWebAssetPath(rel)],
        );
        expect(res.exitCode, equals(0), reason: 'node --check falló en $rel: ${res.stderr}');
      }

      for (final absPath in WebBundleLoader.jsFilePaths()) {
        final res = Process.runSync('node', ['--check', absPath]);
        expect(res.exitCode, equals(0),
            reason: 'node --check falló en $absPath:\n${res.stderr}');
      }

      final bundleOut = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'plan25_fase5a_bundle.js',
      );
      final concatRes = Process.runSync('node', ['--check', bundleOut.path]);
      expect(concatRes.exitCode, equals(0),
          reason: 'node --check falló en bundle concatenado:\n${concatRes.stderr}');

      final concatJs = bundleOut.readAsStringSync();
      final compareDefs = RegExp(
        r'^\s*(?:async\s+)?function\s+compareSemVer\s*\(',
        multiLine: true,
      ).allMatches(concatJs).length;
      expect(compareDefs, equals(1));
    });

    test('3. Paridad 100% handlers inline HTML + DRY D-ADM-07 renderMigrationRescueCard en Node.js', () async {
      final html = WebBundleLoader.loadHtml();
      final fullJs = WebBundleLoader.loadJs();

      // A. Validar que toda función llamada desde onclick/onchange exista en el bundle JS
      const domBuiltins = {
        'getElementById',
        'if',
        'preventDefault',
        'stopPropagation',
        'closest',
        'focus',
        'reset',
      };
      final invokedFns = <String>{};
      for (final attr in ['onclick', 'onchange']) {
        final attrRx = RegExp('\\b$attr=["\']([^"\']+)["\']', caseSensitive: false);
        for (final match in attrRx.allMatches(html)) {
          final body = match.group(1)!;
          for (final fnMatch in RegExp(r'\b([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(').allMatches(body)) {
            final name = fnMatch.group(1)!;
            if (!domBuiltins.contains(name)) {
              invokedFns.add(name);
            }
          }
        }
      }
      expect(invokedFns, isNotEmpty);

      for (final fnName in invokedFns) {
        final hasDecl = RegExp('(?:^|\\n)\\s*(?:async\\s+)?function\\s+$fnName\\s*\\(').hasMatch(fullJs) ||
            RegExp('(?:^|\\n)\\s*window\\.$fnName\\s*=').hasMatch(fullJs);
        expect(hasDecl, isTrue,
            reason: 'Falta función JS invocada por handler inline HTML: $fnName()');
      }

      // B. DRY D-ADM-07: una sola plantilla sync-migration-rescue-card dentro de renderMigrationRescueCard
      expect(
        'sync-migration-rescue-card'.allMatches(fullJs).length,
        equals(1),
        reason: 'D-ADM-07: sync-migration-rescue-card debe vivir una sola vez en renderMigrationRescueCard()',
      );

      final clientSyncGlobal =
          WebBundleLoader.resolveWebAssetFile('js/modules/client_sync_global.js')
              .readAsStringSync();
      final inspectorSync =
          WebBundleLoader.resolveWebAssetFile('js/modules/inspector_sync_and_dispatch.js')
              .readAsStringSync();
      expect(clientSyncGlobal, contains('renderMigrationRescueCard('));
      expect(inspectorSync, contains('renderMigrationRescueCard('));
      expect(clientSyncGlobal, isNot(contains('class="sync-rescue-header"')));
      expect(inspectorSync, isNot(contains('class="sync-rescue-header"')));

      // D-ADM-04 en Recibos
      final receiptsPreview =
          WebBundleLoader.resolveWebAssetFile('js/modules/receipts_preview_and_canvas.js')
              .readAsStringSync();
      final receiptsCanvas =
          WebBundleLoader.resolveWebAssetFile('js/modules/receipts_canvas_render.js')
              .readAsStringSync();
      expect(receiptsPreview, contains('formatLimaReceiptStamp('));
      expect(receiptsCanvas, contains('formatLimaReceiptStamp('));
      expect(receiptsPreview, isNot(contains('toLocaleDateString')));
      expect(receiptsCanvas, isNot(contains('toLocaleDateString')));

      // C. Ejecución Node.js real sobre renderMigrationRescueCard
      final rescueHelper = fullJs.substring(
        fullJs.indexOf('function renderMigrationRescueCard('),
        fullJs.indexOf('function openSyncReportedModal('),
      );
      final testJs = File('${tempDir.path}/p25_fase5a_dry_rescue.js');
      await testJs.writeAsString('''
const assert = require('assert');
function escapeHtml(s) {
  if (!s) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
$rescueHelper

const cardGlobal = renderMigrationRescueCard({
  migrationRescue: {
    old_hardware_id: 'ML-OLD1',
    new_hardware_id: 'ML-NEW2',
    device_model: 'Samsung <Galaxy>'
  },
  matchedClient: { business_name: 'Tienda & Café', owner_name: 'Ana' },
  buttonId: 'btnGlobalSyncRescueMigrate',
  marginBottom: '0',
});
assert.ok(cardGlobal.includes('class="sync-migration-rescue-card"'));
assert.ok(cardGlobal.includes('id="btnGlobalSyncRescueMigrate"'));
assert.ok(cardGlobal.includes('Tienda &amp; Café (Ana)'));
assert.ok(cardGlobal.includes('Samsung &lt;Galaxy&gt;'));
assert.ok(cardGlobal.includes('ML-OLD1') && cardGlobal.includes('ML-NEW2'));

const cardInsp = renderMigrationRescueCard({
  migrationRescue: { old_hardware_id: 'HW1', new_hardware_id: 'HW2' },
  matchedClient: null,
  buttonId: 'btnInspectRescueMigrate',
});
assert.ok(cardInsp.includes('id="btnInspectRescueMigrate"'));
assert.ok(cardInsp.includes('Cliente Origen'));
console.log('FASE5A_DRY_RESCUE_OK');
''');
      final nodeRes = await Process.run('node', [testJs.path]);
      expect(nodeRes.exitCode, equals(0),
          reason: 'Node DRY check failed:\n${nodeRes.stdout}\n${nodeRes.stderr}');
      expect(nodeRes.stdout.toString(), contains('FASE5A_DRY_RESCUE_OK'));
    });
  });
}
