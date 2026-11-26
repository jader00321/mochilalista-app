import 'dart:io';
import 'package:test/test.dart';

import '../lib/client_sync_service.dart';
import '../lib/database_service.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 22 - FASE 4: Sync .mlsync, Ficha 360°, Inspector Dual y Cero Emojis UI', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p22_fase4_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. Backend .mlsync: Cero bucle TRIAL -> ACTIVA, telemetría dr/aiu/pc, delta IA y all_unchanged
    // =========================================================================
    test('1. Backend .mlsync: separa Plan Comercial vs Vigencia (cero bucle TRIAL -> ACTIVA), dr/aiu/pc, delta IA y all_unchanged', () async {
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final backupDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';

      final db = DatabaseService(
        dataDir: dataDir.path,
        backupDir: backupDir.path,
        releasesDir: releasesDir,
      );
      await db.init();
      final syncService = ClientSyncService();

      // Cliente TRIAL vigente creado en CRM
      final client = await db.createClient({
        'business_name': 'Bodega Trial Feliz',
        'owner_name': 'María Torres',
        'document_id': '10445566778',
        'phone': '987111222',
        'current_device_id': 'ML-TRL1',
        'device_model': 'Samsung A54',
        'installed_version': '9.38.0',
        'license_type': 'TRIAL',
        'trial_days_remaining': 25,
        'ai_reported_balance': 50,
      });

      // Ajustar valores iniciales conocidos de telemetría previa en DB
      await db.updateClient(client['id'] as String, {
        'android_version': 'Android 14',
        'ai_credits_used_total': 12,
        'profiles_count': 1,
        'backup_health_status': 'OK',
        'backup_drive_linked': true,
        'last_backup_at': '2026-11-20T15:00:00Z',
        'uses_byok': false,
        'ultimo_nonce': 1,
      });

      // Primer análisis: celular TRIAL vigente reporta st: 'ACTIVA', pl: 'TRIAL', consumió +6 IA (12 -> 18) y creó 2do perfil
      final syncPayload = {
        'v': 1,
        'hw': 'ML-TRL1',
        'bhw': null,
        'mod': 'Samsung A54',
        'os': 'Android 14',
        'av': '9.38.0',
        'bc': 82,
        'db': 36,
        'pl': 'TRIAL',
        'st': 'ACTIVA',
        'exp': client['license_expires'].toString().substring(0, 10),
        'dr': 20,
        'n': 2,
        'ai': 42,
        'aiu': 18,
        'byok': false,
        'pc': 2,
        'drv': true,
        'bh': 'OK',
        'lb': '2026-11-22T06:14:02.071Z',
        'ts': 1795430000000,
      };

      var allClients = await db.getClients();
      final analysis1 = syncService.analyzeForClients(
        syncPayload,
        allClients,
        expectedClientId: client['id'] as String,
      );

      final changes1 = (analysis1['changes'] as List).cast<Map<String, dynamic>>();
      final planRow1 = changes1.firstWhere((c) => c['field'] == 'license_type');
      final statusRow1 = changes1.firstWhere((c) => c['field'] == 'license_status');
      final drRow1 = changes1.firstWhere((c) => c['field'] == 'trial_days_remaining');
      final aiuRow1 = changes1.firstWhere((c) => c['field'] == 'ai_credits_used_total');
      final pcRow1 = changes1.firstWhere((c) => c['field'] == 'profiles_count');

      // Plan Comercial y Estado de Vigencia son filas independientes y NO hay bucle TRIAL -> ACTIVA
      expect(planRow1['label'], equals('Plan Comercial'));
      expect(planRow1['before'], equals('TRIAL'));
      expect(planRow1['after'], equals('TRIAL'));
      expect(planRow1['is_different'], isFalse);

      expect(statusRow1['label'], equals('Estado de Vigencia'));
      expect(statusRow1['before'], equals('ACTIVA'));
      expect(statusRow1['after'], equals('ACTIVA'));
      expect(statusRow1['is_different'], isFalse);

      // Telemetría dr, aiu (+delta 6) y pc expuestos correctamente
      expect(drRow1['before'], equals(25));
      expect(drRow1['after'], equals(20));
      expect(drRow1['is_different'], isTrue);

      expect(aiuRow1['before'], equals(12));
      expect(aiuRow1['after'], equals(18));
      expect(aiuRow1['delta'], equals(6));
      expect(analysis1['ai_credits_used_delta'], equals(6));

      expect(pcRow1['before'], equals(1));
      expect(pcRow1['after'], equals(2));
      expect(pcRow1['is_different'], isTrue);

      expect(analysis1['all_unchanged'], isFalse);
      expect(analysis1['same_timestamp'], isFalse);

      // Aplicar snapshot en DB y verificar persistencia completa sin sobrescribir license_type
      final updated = await db.applyClientSyncSnapshot(client['id'] as String, syncPayload);
      expect(updated, isNotNull);
      expect(updated!['license_type'], equals('TRIAL'));
      expect(updated['ai_credits_used_total'], equals(18));
      expect(updated['ai_credits_used_delta'], equals(6));
      expect(updated['profiles_count'], equals(2));
      expect(updated['trial_days_remaining'], equals(20));
      expect(updated['last_sync_ts'], equals(1795430000000));

      // Re-analizar EXACTAMENTE el mismo reporte -> 100% Sin cambios + same_timestamp == true
      allClients = await db.getClients();
      final analysis2 = syncService.analyzeForClients(
        syncPayload,
        allClients,
        expectedClientId: client['id'] as String,
      );

      expect(analysis2['all_unchanged'], isTrue);
      expect(analysis2['same_timestamp'], isTrue);
      expect(analysis2['is_older_than_last_sync'], isFalse);
      final changes2 = (analysis2['changes'] as List).cast<Map<String, dynamic>>();
      for (final row in changes2) {
        expect(row['is_different'], isFalse, reason: 'Campo ${row['field']} no debería mostrar diff tras aplicar snapshot');
      }
    });

    // =========================================================================
    // 2. Equivalencia EXPIRADA / VENCIDA y estados PROSPECTO / PERPETUA
    // =========================================================================
    test('2. Equivalencia EXPIRADA / VENCIDA, PROSPECTO y PERPETUA en _computeAuthoritativeClientStatus', () {
      final syncService = ClientSyncService();

      final expiredClient = <String, dynamic>{
        'id': 'c_exp',
        'current_device_id': 'ML-EXP1',
        'license_type': 'MENSUAL',
        'license_status': 'ACTIVA',
        'license_expires': '2020-01-01T00:00:00Z',
        'installed_version': '9.38.0',
      };

      final basePayload = <String, dynamic>{
        'v': 1,
        'hw': 'ML-EXP1',
        'av': '9.38.0',
        'pl': 'MENSUAL',
        'dr': 0,
        'n': 1,
        'ai': 0,
        'aiu': 0,
        'pc': 1,
        'ts': 1795430000000,
      };

      // st: 'EXPIRADA' vs cliente vencido -> Sin cambios
      final resExpirada = syncService.analyzeForClients(
        {...basePayload, 'st': 'EXPIRADA'},
        [expiredClient],
      );
      final rowExpirada = (resExpirada['changes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['field'] == 'license_status');
      expect(rowExpirada['before'], equals('EXPIRADA'));
      expect(rowExpirada['after'], equals('EXPIRADA'));
      expect(rowExpirada['is_different'], isFalse);

      // st: 'VENCIDA' vs cliente vencido -> Sin falso diff
      final resVencida = syncService.analyzeForClients(
        {...basePayload, 'st': 'VENCIDA'},
        [expiredClient],
      );
      final rowVencida = (resVencida['changes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['field'] == 'license_status');
      expect(rowVencida['before'], equals('EXPIRADA'));
      expect(rowVencida['after'], equals('EXPIRADA'));
      expect(rowVencida['is_different'], isFalse);

      // Cliente PERPETUO vigente con st: 'ACTIVA' -> Sin cambios
      final perpClient = <String, dynamic>{
        'id': 'c_perp',
        'current_device_id': 'ML-PRP1',
        'license_type': 'PERPETUO_LIBERADO',
        'license_status': 'PERPETUA',
        'license_expires': '2299-12-31T00:00:00Z',
      };
      final resPerp = syncService.analyzeForClients(
        {...basePayload, 'hw': 'ML-PRP1', 'pl': 'PERPETUO_LIBERADO', 'st': 'ACTIVA'},
        [perpClient],
      );
      final rowPerp = (resPerp['changes'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['field'] == 'license_status');
      expect(rowPerp['is_different'], isFalse);
    });

    // =========================================================================
    // 3. Validación JS real en Node.js: Lima GMT-5, humanización, Nonce 4 estados e historial
    // =========================================================================
    test('3. JS Node.js: formatLimaDateTime, humanizeSyncFieldValue, 4 estados Nonce (Luzam), acciones e historial', () async {
      final js = WebBundleLoader.loadJs();
      final extracted = _extractPhase4JsSlices(js);

      final harness = File('${tempDir.path}/phase4_inspector_and_sync_test.js');
      await harness.writeAsString('''
${_buildPhase4DomPreamble()}
$extracted

async function runTests() {
  initInspectorEvents();

  // 1) formatLimaDateTime UTC -> America/Lima (GMT-5)
  assert.strictEqual(
    formatLimaDateTime('2026-11-22T06:14:02.071Z'),
    '22/11/2026 01:14:02 (Lima GMT-5)'
  );
  assert.ok(formatLimaDateTime(1795430000000).endsWith('(Lima GMT-5)'));
  assert.strictEqual(formatLimaDateTime(null), '-');

  // 2) humanizeSyncFieldValue
  assert.strictEqual(humanizeSyncFieldValue('backup_drive_linked', true), 'Sí');
  assert.strictEqual(humanizeSyncFieldValue('uses_byok', false), 'No');
  assert.strictEqual(humanizeSyncFieldValue('backup_health_status', 'OK'), 'Óptimo');
  assert.strictEqual(humanizeSyncFieldValue('backup_health_status', 'OPTIMAL'), 'Óptimo');
  assert.strictEqual(humanizeSyncFieldValue('backup_health_status', 'ATTENTION'), 'Requiere atención');
  assert.strictEqual(humanizeSyncFieldValue('backup_health_status', 'CRITICAL'), 'Crítico');
  assert.strictEqual(humanizeSyncFieldValue('backup_health_status', 'NONE'), 'Sin respaldo');
  assert.strictEqual(
    humanizeSyncFieldValue('last_backup_at', '2026-11-22T06:14:02.071Z'),
    '22/11/2026 01:14:02 (Lima GMT-5)'
  );

  // 3) renderSyncDiffTable con banner verde all_unchanged + humanización + delta IA
  const htmlUnchanged = renderSyncDiffTable([
    { field: 'backup_drive_linked', label: 'Google Drive Vinculado', before: true, after: true, is_different: false, changed: false },
    { field: 'backup_health_status', label: 'Salud de Respaldo', before: 'ATTENTION', after: 'ATTENTION', is_different: false, changed: false },
    { field: 'ai_credits_used_total', label: 'Escaneos IA Consumidos (Histórico)', before: 12, after: 18, delta: 6, is_different: false, changed: false }
  ], { allUnchanged: true, sameTimestamp: true });
  assert.ok(htmlUnchanged.includes('La ficha coincide al 100% con el estado actual del CRM — Sin cambios por aplicar'));
  assert.ok(htmlUnchanged.includes('Requiere atención'));
  assert.ok(htmlUnchanged.includes('(+6 desde última sync)'));

  // 4) Matriz de 4 Estados de Nonce en Inspector Forense
  // 4a. Caso real Luzam: tNonce = 1, ultimo_nonce = 1, next_nonce = 2 -> Canjeado en celular (NUNCA Nonce futuro)
  const luzamState = reconcileInspectorNonceStatus(1, { next_nonce: 2, ultimo_nonce: 1 });
  assert.strictEqual(luzamState.state, 'REDEEMED_SYNCED');
  assert.strictEqual(luzamState.badgeClass, 'badge badge-green');
  assert.strictEqual(luzamState.label, 'Canjeado en celular (Verificado por .mlsync #1)');

  // Incluso si next_nonce estuviera desfasado en 1 mientras ultimo_nonce ya reportó 1 -> sigue siendo Canjeado en celular
  const luzamDesync = reconcileInspectorNonceStatus(1, { next_nonce: 1, ultimo_nonce: 1 });
  assert.strictEqual(luzamDesync.state, 'REDEEMED_SYNCED');

  // 4b. Emitido — Pendiente de canje en celular (tNonce === cNonce - 1 sin sync reciente)
  const pendingState = reconcileInspectorNonceStatus(2, { next_nonce: 3, ultimo_nonce: 1 });
  assert.strictEqual(pendingState.state, 'EMITTED_PENDING');
  assert.strictEqual(pendingState.badgeClass, 'badge badge-blue');
  assert.strictEqual(pendingState.label, 'Emitido — Pendiente de canje en celular (Sin .mlsync reciente)');

  // 4c. Nonce futuro listo para canje (solo si tNonce >= next_nonce y > ultimo_nonce)
  const futureState = reconcileInspectorNonceStatus(3, { next_nonce: 3, ultimo_nonce: 1 });
  assert.strictEqual(futureState.state, 'FUTURE_READY');
  assert.strictEqual(futureState.badgeClass, 'badge badge-yellow');
  assert.strictEqual(futureState.label, 'Nonce futuro listo para canje');

  // 4d. Superado / Histórico (tNonce < next_nonce - 1 y sin confirmación ultimo_nonce)
  const oldState = reconcileInspectorNonceStatus(1, { next_nonce: 4, ultimo_nonce: null });
  assert.strictEqual(oldState.state, 'HISTORICAL_SUPERSEDED');
  assert.strictEqual(oldState.badgeClass, 'badge badge-purple');
  assert.strictEqual(oldState.label, 'Superado / Histórico');

  // 5) Flujo completo inspectToken() en modo ML9 (Luzam) + botones de acción + Copiar Informe Forense
  getEl('inspectTokenInput').value = 'ML9-LUZAM-TOK-1';
  mockInspectResponse = {
    input_kind: 'LICENSE_TOKEN',
    isValid: true,
    valid: true,
    payload: { d: 'ML-LUZ1', p: 'ANUAL', y: 365, n: 1, v: 9, e: '2026-11-22T06:14:02.071Z', u: '2027-11-22', b: 'Luzam SAC', c: 100 },
    matching_client: {
      id: 'cli_luzam',
      business_name: 'Luzam SAC',
      owner_name: 'Luis Zamora',
      phone: '999000111',
      installed_version: '9.40.0',
      license_type: 'ANUAL',
      next_nonce: 2,
      ultimo_nonce: 1,
      last_sync_at: '2026-11-22T06:14:02.071Z'
    }
  };
  await inspectToken();
  const matchHtml = getEl('inspectMatchingClientBox').innerHTML;
  assert.ok(matchHtml.includes('Canjeado en celular (Verificado por .mlsync #1)'));
  assert.ok(matchHtml.includes('Abrir Ficha 360°'));
  assert.ok(matchHtml.includes('Abrir WhatsApp'));
  assert.ok(matchHtml.includes('Copiar Informe Forense'));

  copiedTexts.length = 0;
  copyInspectorForensicReport();
  assert.strictEqual(copiedTexts.length, 1);
  assert.ok(copiedTexts[0].includes('Canjeado en celular (Verificado por .mlsync #1)'));
  assert.ok(copiedTexts[0].includes('Luzam SAC'));

  // 6) Flujo CLIENT_SYNC en Inspector: reutiliza renderSyncDiffTable + banner Sin cambios + Lima
  getEl('inspectTokenInput').value = 'MLS1-DEMO-1';
  mockInspectResponse = {
    input_kind: 'CLIENT_SYNC',
    valid: true,
    isValid: true,
    match_type: 'EXACT_HARDWARE',
    all_unchanged: true,
    same_timestamp: false,
    payload: {
      v: 1, hw: 'ML-LUZ1', mod: 'Galaxy A54', os: 'Android 14', av: '9.40.0', bc: 84, db: 36,
      pl: 'TRIAL', st: 'ACTIVA', dr: 25, n: 1, ai: 50, aiu: 12, byok: false, pc: 2,
      drv: true, bh: 'ATTENTION', lb: '2026-11-22T06:14:02.071Z', ts: 1795430000000
    },
    changes: [
      { field: 'backup_health_status', label: 'Salud de Respaldo', before: 'ATTENTION', after: 'ATTENTION', is_different: false, changed: false }
    ],
    matched_client: {
      id: 'cli_luzam',
      business_name: 'Luzam SAC',
      owner_name: 'Luis Zamora',
      phone: '999000111',
      current_device_id: 'ML-LUZ1',
      license_type: 'TRIAL'
    }
  };
  await inspectToken();
  const syncCardHtml = getEl('inspectSyncAuditCard').innerHTML;
  assert.ok(syncCardHtml.includes('Requiere atención'));
  assert.ok(syncCardHtml.includes('22/11/2026 01:14:02 (Lima GMT-5)'));
  assert.ok(syncCardHtml.includes('inspectSyncDiffSection'));
  assert.ok(syncCardHtml.includes('La ficha coincide al 100% con el estado actual del CRM — Sin cambios por aplicar'));

  // 7) Historial de sesión acotado a máximo 10 auditorías + clearInspectorSessionHistory
  for (let i = 1; i <= 12; i++) {
    recordInspectorSessionEntry({
      kind: 'ML9',
      summaryLabel: 'Cliente ' + i,
      hardwareId: 'ML-H' + i,
      statusText: 'Válido',
      rawInput: 'ML9-ITEM-' + i
    });
  }
  assert.strictEqual(inspectorSessionHistory.length, 10);
  assert.strictEqual(inspectorSessionHistory[0].rawInput, 'ML9-ITEM-12');
  assert.strictEqual(getEl('inspectorHistoryCount').textContent, '10');
  assert.strictEqual(getEl('inspectorSessionHistoryPanel').style.display, 'block');

  clearInspectorSessionHistory();
  assert.strictEqual(inspectorSessionHistory.length, 0);
  assert.strictEqual(getEl('inspectorSessionHistoryPanel').style.display, 'none');

  console.log('PHASE4_JS_INSPECTOR_AND_SYNC_OK');
}

runTests().catch(err => {
  console.error(err);
  process.exit(1);
});
''');

      final res = await Process.run('node', [harness.path]);
      expect(res.exitCode, equals(0), reason: 'Node test Fase 4 falló: ${res.stderr}\n${res.stdout}');
      expect(res.stdout.toString(), contains('PHASE4_JS_INSPECTOR_AND_SYNC_OK'));
    });

    // =========================================================================
    // 4. Auditoría HTML/CSS/JS: Elementos Fase 4 y cero emojis crudos en controles UI
    // =========================================================================
    test('4. HTML/CSS/JS: Controles Fase 4 completos, #inspectSyncAuditCard intacto y CERO emojis crudos en controles UI', () {
      final html = WebBundleLoader.loadHtml();
      final css = WebBundleLoader.loadCss();
      final js = WebBundleLoader.loadJs();

      // HTML requerido
      expect(html, contains('id="inspectSyncAuditCard"'));
      expect(html, contains('id="inspectMatchingClientBox"'));
      expect(html, contains('id="inspectorSessionHistoryPanel"'));
      expect(html, contains('id="inspectorHistoryCount"'));
      expect(html, contains('id="inspectorSessionHistoryList"'));
      expect(html, contains('id="btnClearInspectorHistory"'));
      expect(html, contains('id="drawerProfilesCount"'));
      expect(html, contains('id="drawerUltimoNonce"'));

      // CSS requerido
      expect(css, contains('.badge-blue'));
      expect(css, contains('.sync-all-unchanged-banner'));
      expect(css, contains('.sync-diff-delta-pill'));
      expect(css, contains('.inspector-actions-bar'));
      expect(css, contains('.inspector-history-panel'));
      expect(css, contains('.inspector-history-item'));

      // JS requerido
      expect(js, contains('function formatLimaDateTime('));
      expect(js, contains('function humanizeSyncFieldValue('));
      expect(js, contains('function reconcileInspectorNonceStatus('));
      expect(js, contains('Abrir Ficha 360°'));
      expect(js, contains('Abrir WhatsApp'));
      expect(js, contains('Copiar Informe Forense'));

      // Cero emojis crudos en componentes UI HTML y JS intervenidos
      final forbiddenUiEmojis = [
        '✅', '❌', '⚠️', 'ℹ️', '⬇️', '📁', '✏️', '🗑️', '📲', '🚀', '📦',
        '🛡️', '🔍', '💡', '🔐', '📄', '📋', '🪪', '📱', '✕', '✓',
      ];

      final inspectorHtmlStart = html.indexOf('id="tabInspector"');
      final inspectorHtmlEnd = html.indexOf('id="tabFinancesAndBackups"');
      final modalSyncStart = html.indexOf('id="modalSyncReported"');
      final modalMigrateStart = html.indexOf('id="modalMigrateDevice"');
      final drawerStart = html.indexOf('id="drawerClient360"');
      final drawerEnd = html.indexOf('id="drawerTabQr"');
      final settingsTipsIdx = html.indexOf('Regla de Supresión Automática');
      final vaultWarnIdx = html.indexOf('id="vaultRecoveryWarning"');
      final vaultEndIdx = html.indexOf('id="btnOpenRescueKitModal"');

      for (final chunk in [
        html.substring(inspectorHtmlStart, inspectorHtmlEnd),
        html.substring(modalSyncStart, modalMigrateStart),
        html.substring(drawerStart, drawerEnd),
        html.substring(settingsTipsIdx - 150, settingsTipsIdx + 300),
        html.substring(vaultWarnIdx - 50, vaultEndIdx),
      ]) {
        for (final emoji in forbiddenUiEmojis) {
          expect(chunk, isNot(contains(emoji)), reason: 'Emoji/símbolo crudo prohibido ($emoji) detectado en HTML UI de Fase 4');
        }
      }

      final toastStart = js.indexOf('function showToast(');
      final toastEnd = js.indexOf('let confirmCallback = null;');
      final drawerJsStart = js.indexOf('async function openClient360Drawer(');
      final drawerJsEnd = js.indexOf("document.getElementById('drawerEditNotes')", drawerJsStart);
      final limaJsStart = js.indexOf('function formatLimaDateTime(');
      final limaJsEnd = js.indexOf('function formatLimaReceiptStamp(');
      final syncJsStart = js.indexOf('function openSyncReportedModal(');
      final syncJsEnd = js.indexOf('// =================== 3B.');
      final inspJsStart = js.indexOf('// =================== 5. INSPECTOR FORENSE DUAL');
      final inspJsEnd = js.indexOf('// =================== 6. FINANZAS');
      final modalHistStart = js.indexOf("payBody.innerHTML = '';");
      final modalHistEnd = js.indexOf('const hwBody = document.getElementById(\'historyHardwareBody\')');

      for (final chunk in [
        js.substring(toastStart, toastEnd),
        js.substring(drawerJsStart, drawerJsEnd),
        js.substring(limaJsStart, limaJsEnd),
        js.substring(syncJsStart, syncJsEnd),
        js.substring(inspJsStart, inspJsEnd),
        js.substring(modalHistStart, modalHistEnd),
      ]) {
        for (final emoji in forbiddenUiEmojis) {
          expect(chunk, isNot(contains(emoji)), reason: 'Emoji/símbolo crudo prohibido ($emoji) detectado en JS UI de Fase 4');
        }
      }
    });
  });
}

String _extractPhase4JsSlices(String js) {
  final limaStart = js.indexOf('function formatLimaDateTime(');
  final limaEnd = js.indexOf('function formatLimaReceiptStamp(');
  final rescueStart = js.indexOf('function renderMigrationRescueCard(');
  final rescueEnd = js.indexOf('function openSyncReportedModal(');
  final syncStart = js.indexOf('function humanizeSyncFieldValue(');
  final renderDiffEnd = js.indexOf('/**\n * Analizar Ficha de Sincronización');
  final altRenderDiffEnd = js.indexOf('async function analyzeSyncReported(');
  final inspStart = js.indexOf('// =================== 5. INSPECTOR FORENSE DUAL');
  final inspEnd = js.indexOf('// =================== 6. FINANZAS');

  final effectiveSyncEnd = renderDiffEnd > syncStart ? renderDiffEnd : altRenderDiffEnd;
  assert(limaStart >= 0 && limaEnd > limaStart);
  assert(rescueStart >= 0 && rescueEnd > rescueStart);
  assert(syncStart > 0 && effectiveSyncEnd > syncStart);
  assert(inspStart > 0 && inspEnd > inspStart);

  return [
    js.substring(limaStart, limaEnd),
    js.substring(rescueStart, rescueEnd),
    js.substring(syncStart, effectiveSyncEnd),
    js.substring(inspStart, inspEnd),
  ].join('\n\n');
}

String _buildPhase4DomPreamble() {
  return r'''
const assert = require('assert');

class MockClassList {
  constructor(initial = []) { this.set = new Set(initial); }
  add(...names) { names.forEach(n => this.set.add(n)); }
  remove(...names) { names.forEach(n => this.set.delete(n)); }
  toggle(name, force) {
    if (force === undefined) {
      if (this.set.has(name)) { this.set.delete(name); return false; }
      this.set.add(name); return true;
    }
    if (force) this.set.add(name); else this.set.delete(name);
    return !!force;
  }
  contains(name) { return this.set.has(name); }
}

class MockElement {
  constructor(id = '') {
    this.id = id;
    this.classList = new MockClassList();
    this.dataset = {};
    this.style = {};
    this.value = '';
    this.textContent = '';
    this.innerHTML = '';
    this.children = [];
    this.listeners = {};
  }
  addEventListener(evt, fn) {
    this.listeners[evt] = this.listeners[evt] || [];
    this.listeners[evt].push(fn);
  }
  appendChild(child) {
    this.children.push(child);
    return child;
  }
}

const elements = {};
function getEl(id) {
  if (!elements[id]) elements[id] = new MockElement(id);
  return elements[id];
}

[
  'inspectTokenInput', 'btnInspectToken', 'btnClearInspectToken',
  'inspectResultContainer', 'inspectStatusBadge', 'inspectSyncAuditCard',
  'inspectLicenseClaimsWrapper', 'inspectClaimsTableBody', 'inspectMatchingClientBox',
  'qrOpticalDropZone', 'qrOpticalFileInput',
  'inspectorSessionHistoryPanel', 'inspectorSessionHistoryList', 'inspectorHistoryCount',
  'btnInspectOpenDrawer360', 'btnInspectOpenWa', 'btnInspectCopyReport', 'btnInspectApplySync'
].forEach(id => getEl(id));

Object.defineProperty(elements['inspectSessionHistoryList'] || getEl('inspectorSessionHistoryList'), 'innerHTML', {
  get() { return this._html || ''; },
  set(v) {
    this._html = v;
    if (v === '') this.children = [];
  }
});

global.document = {
  getElementById(id) { return elements[id] || null; },
  querySelectorAll() { return []; },
  querySelector() { return null; },
  createElement(tag) { return new MockElement(''); }
};

const sessionStore = {};
global.sessionStorage = {
  getItem(k) { return Object.prototype.hasOwnProperty.call(sessionStore, k) ? sessionStore[k] : null; },
  setItem(k, v) { sessionStore[k] = String(v); },
  removeItem(k) { delete sessionStore[k]; }
};

const toasts = [];
const copiedTexts = [];
let mockInspectResponse = {};

function escapeHtml(s) { return String(s == null ? '' : s); }
function showToast(msg, type = 'info') { toasts.push({ msg, type }); }
function copyPlainTextToClipboard(text, msg) {
  copiedTexts.push(text);
  showToast(msg, 'success');
}
function openClient360Drawer() {}
function openWhatsAppComposer() {}
function openModal() {}
function openMigrateModal() {}
async function loadClients() {}
async function loadDashboard() {}
async function loadReleaseMatrix() {}

global.fetch = async (url, opts) => {
  if (url === '/api/licenses/inspect') {
    return {
      ok: true,
      status: 200,
      json: async () => mockInspectResponse
    };
  }
  return { ok: true, status: 200, json: async () => ({ ok: true }) };
};
''';
}
