import 'dart:io';
import 'package:test/test.dart';
import 'support/web_bundle_loader.dart';

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
      'PLAN MAESTRO 23.5 - FASE 2: Frontend #tabInspector Tri-Protocolo, Guía Visual y Resiliencia QR MLC1',
      () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p23_5_fase2_ui_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        '1. Auditoría estática HTML/CSS/JS: guía 3 protocolos, #inspectMlc1AuditCard, Dark/Light, SVG acotados, 0 emojis y contratos intactos',
        () {
      final html = WebBundleLoader.loadHtml();
      final css = WebBundleLoader.loadCss();
      final js = WebBundleLoader.loadJs();

      // Sidebar y títulos tri-protocolo
      expect(
        html,
        contains('title="Inspector Forense Tri-Protocolo (ML9 / MLS1 / MLC1)"'),
      );
      expect(
        js,
        contains("tabInspector: 'Inspector Forense (ML9 / MLS1 / MLC1)'"),
      );

      // HTML #tabInspector completo
      final tabHtml = _extractSection(
        html,
        'id="tabInspector"',
        'id="tabFinancesAndBackups"',
      );
      expect(tabHtml, contains('id="btnToggleInspectorGuide"'));
      expect(tabHtml, contains('id="inspectorProtocolGuide"'));
      expect(tabHtml, contains('id="inspectMlc1AuditCard"'));
      expect(tabHtml, contains('id="inspectSyncAuditCard"'));
      expect(tabHtml, contains('ML9-...'));
      expect(tabHtml, contains('MLS1-... / .mlsync'));
      expect(tabHtml, contains('MLC1-...'));
      expect(tabHtml, contains('Lector Óptico QR'));
      expect(tabHtml, contains('4 Estados de Nonce'));
      expect(tabHtml, contains('Copiar Informe Forense'));
      expect(tabHtml, contains('Historial de Sesión'));

      // Todo <svg> en #tabInspector con width/height explícitos o clase acotada
      final svgTagRegex = RegExp(r'<svg\b[^>]*>');
      for (final match in svgTagRegex.allMatches(tabHtml)) {
        final tag = match.group(0)!;
        final hasBounds = tag.contains('width=') ||
            tag.contains('width:') ||
            tag.contains('icon-svg') ||
            tag.contains('btn-icon');
        expect(hasBounds, isTrue,
            reason: 'SVG sin dimensiones acotadas en #tabInspector: $tag');
      }

      // CSS Dark + [data-theme="light"] + QR 512px escalado visualmente a 196px
      expect(css, contains('.badge-mlc1'));
      expect(css, contains('[data-theme="light"] .badge-mlc1'));
      expect(css, contains('.inspector-protocol-guide'));
      expect(css, contains('[data-theme="light"] .inspector-protocol-guide'));
      expect(css, contains('.mlc1-audit-guidance-banner'));
      expect(css, contains('[data-theme="light"] .mlc1-audit-guidance-banner.is-current'));
      expect(css, contains('[data-theme="light"] .mlc1-audit-guidance-banner.is-invalid'));
      expect(css, contains('.inspect-mlc1-meta-card'));
      expect(css, contains('[data-theme="light"] .inspect-mlc1-meta-card'));
      expect(css, contains('.inspect-mlc1-channel-card'));
      expect(css, contains('[data-theme="light"] .inspect-mlc1-channel-card'));
      expect(css, contains('.inspect-mlc1-diagnostic-box'));
      expect(css, contains('[data-theme="light"] .inspect-mlc1-diagnostic-box'));
      expect(css, contains('.mlc1-qr-white-box canvas'));

      // Contratos JS intactos de planes previos
      final fmtIdx = js.indexOf('function formatApkSizeMb(');
      final sigIdx = js.indexOf('function renderSignatureStatusBadge(');
      expect(fmtIdx, isPositive);
      expect(sigIdx, greaterThan(fmtIdx));

      final verifyStart = js.indexOf('let isVerifyAllCatalogRunning = false;');
      final verifyEnd = js.indexOf('/**\n * Carga notas compañeras', verifyStart + 1);
      expect(verifyStart, isPositive);
      expect(verifyEnd, greaterThan(verifyStart));

      final sec5Start = js.indexOf('// =================== 5. INSPECTOR FORENSE DUAL');
      final sec6Start = js.indexOf('// =================== 6. FINANZAS');
      expect(sec5Start, isPositive);
      expect(sec6Start, greaterThan(sec5Start));
      final sec5Js = js.substring(sec5Start, sec6Start);

      // QR 512 px en #modalCommercialConfigSync (Salvaguarda 2)
      expect(
        js,
        contains("renderSafeQrCode(qrContainer, data.token, 512, '#0f172a', '#ffffff')"),
      );
      expect(js, contains('sourceEl.width || sourceEl.naturalWidth || 512'));

      // Cero emojis crudos en #tabInspector (HTML), sección 5 JS y CSS Fase 2
      final cssPhase2 = css.substring(
        css.indexOf('PLAN MAESTRO 23.5 - FASE 2:'),
      );
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      const bannedSymbols = [
        '✅', '❌', '⚠️', 'ℹ️', '⬇️', '📁', '✏️', '🗑️', '📲', '🚀', '📦',
        '🛡️', '🔍', '💡', '🔐', '📄', '📋', '🪪', '📱', '✕', '✓',
      ];
      for (final chunk in [tabHtml, sec5Js, cssPhase2]) {
        expect(emojiRegex.hasMatch(chunk), isFalse,
            reason: 'Se encontró emoji Unicode prohibido en UI de Fase 2');
        for (final sym in bannedSymbols) {
          expect(chunk.contains(sym), isFalse,
              reason: 'Símbolo crudo prohibido ($sym) detectado en UI Fase 2');
        }
      }
    });

    test(
        '2. Ejecución Node.js real: guía desplegable, MLC1 válido/diferencias/inválido, informe forense, #tabSettings, historial MLC1 y upscale jsQR',
        () async {
      final js = WebBundleLoader.loadJs();
      final fmtLimaSlice = _extractSection(
        js,
        'function formatLimaDateTime(',
        'function formatLimaIsoDate(',
      );
      final inspSection = _extractSection(
        js,
        '// =================== 5. INSPECTOR FORENSE DUAL',
        '// =================== 6. FINANZAS',
      );
      final mlc1Section = _extractSection(
        js,
        '// =================== 8B. EMISOR DECLARATIVO MLC1-',
        '// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL',
      );

      final harness = File('${tempDir.path}/p23_5_fase2_ui_test.js');
      await harness.writeAsString('''
const assert = require('assert');

class MockClassList {
  constructor(initial = []) { this.set = new Set(initial); }
  add(...c) { c.forEach(x => this.set.add(x)); }
  remove(...c) { c.forEach(x => this.set.delete(x)); }
  toggle(c, force) {
    if (force === undefined) {
      if (this.set.has(c)) { this.set.delete(c); return false; }
      this.set.add(c); return true;
    }
    if (force) this.set.add(c); else this.set.delete(c);
    return !!force;
  }
  contains(c) { return this.set.has(c); }
}

class MockCanvasContext {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.imageSmoothingEnabled = true;
    this.fillStyle = '';
    this.filledRects = [];
    this.drawnImages = [];
  }
  getImageData(x, y, w, h) {
    return { data: new Uint8ClampedArray(w * h * 4), width: w, height: h };
  }
  fillRect(x, y, w, h) { this.filledRects.push({ x, y, w, h, fillStyle: this.fillStyle }); }
  drawImage(src, x, y, w, h) { this.drawnImages.push({ srcW: src.width, x, y, w, h }); }
}

class MockElement {
  constructor(id = '', classes = [], dataset = {}) {
    this.id = id;
    this.classList = new MockClassList(classes);
    this.dataset = { ...dataset };
    this.style = { display: 'none' };
    this.value = '';
    this.textContent = '';
    this._innerHTML = '';
    this.children = [];
    this.listeners = {};
    this.attrs = {};
    this.disabled = false;
    this.width = 0;
    this.height = 0;
    this._ctx = null;
  }
  set innerHTML(v) {
    this._innerHTML = String(v);
    if (v === '') this.children = [];
  }
  get innerHTML() { return this._innerHTML; }
  appendChild(c) { this.children.push(c); return c; }
  addEventListener(evt, fn) {
    this.listeners[evt] = this.listeners[evt] || [];
    this.listeners[evt].push(fn);
  }
  dispatch(evt, target = this) {
    (this.listeners[evt] || []).forEach(fn => fn({ target }));
  }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] || ''; }
  getContext(type) {
    if (type === '2d') {
      if (!this._ctx) this._ctx = new MockCanvasContext(this.width, this.height);
      return this._ctx;
    }
    return null;
  }
  querySelector() { return null; }
  querySelectorAll() { return []; }
}

const elMap = {};
function el(id, classes = [], dataset = {}) {
  if (!elMap[id]) elMap[id] = new MockElement(id, classes, dataset);
  return elMap[id];
}

[
  'btnToggleInspectorGuide', 'inspectorProtocolGuide',
  'inspectTokenInput', 'btnInspectToken', 'btnClearInspectToken',
  'inspectResultContainer', 'inspectStatusBadge',
  'inspectMlc1AuditCard', 'inspectSyncAuditCard',
  'inspectLicenseClaimsWrapper', 'inspectClaimsTableBody', 'inspectMatchingClientBox',
  'qrOpticalDropZone', 'qrOpticalFileInput',
  'inspectorSessionHistoryPanel', 'inspectorSessionHistoryList', 'inspectorHistoryCount',
  'currentViewName', 'tabInspector', 'tabSettings',
  'mlc1TokenOutput', 'mlc1RevisionBadge', 'mlc1IssuedAtLimaBadge',
  'mlc1PayloadSizeBadge', 'mlc1DartSnippetOutput', 'mlc1TokenResultContainer',
  'mlc1EmptyResultHint', 'mlc1QrContainer', 'btnGenerateMlc1Token'
].forEach(id => el(id));

// Botones dinámicos capturados al asignar innerHTML dentro de inspectMlc1AuditCard
Object.defineProperty(el('inspectMlc1AuditCard'), 'innerHTML', {
  get() { return this._innerHTML || ''; },
  set(v) {
    this._innerHTML = String(v);
    if (this._innerHTML.includes('btnInspectMlc1CopyReport')) el('btnInspectMlc1CopyReport');
    if (this._innerHTML.includes('btnInspectMlc1OpenSettings')) el('btnInspectMlc1OpenSettings');
  }
});

const navTabs = [
  new MockElement('navInspector', ['nav-tab', 'active'], { tab: 'tabInspector' }),
  new MockElement('navSettings', ['nav-tab'], { tab: 'tabSettings' })
];
const tabPanes = [el('tabInspector', ['tab-pane', 'active']), el('tabSettings', ['tab-pane'])];
const createdCanvases = [];

global.document = {
  getElementById(id) { return elMap[id] || null; },
  querySelector(sel) {
    if (sel === '[data-tab="tabSettings"]') return navTabs[1];
    return null;
  },
  querySelectorAll(sel) {
    if (sel === '.nav-tab') return navTabs;
    if (sel === '.tab-pane') return tabPanes;
    return [];
  },
  createElement(tag) {
    const m = new MockElement('', [tag]);
    if (tag === 'canvas') createdCanvases.push(m);
    return m;
  }
};

const sessionStore = {};
global.sessionStorage = {
  getItem(k) { return Object.prototype.hasOwnProperty.call(sessionStore, k) ? sessionStore[k] : null; },
  setItem(k, v) { sessionStore[k] = String(v); },
  removeItem(k) { delete sessionStore[k]; }
};

const toasts = [];
const copiedTexts = [];
const qrRenderCalls = [];
let mockInspectResponse = {};
let ownerConfig = { catalog: { MENSUAL: { price: 35 } }, system: { commercial_sync_revision: 3 } };

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
function showToast(msg, type = 'info') { toasts.push({ msg, type }); }
function copyPlainTextToClipboard(text) { copiedTexts.push(text); }
function openClient360Drawer() {}
function openWhatsAppComposer() {}
function openModal() {}
function closeModal() {}
function openMigrateModal() {}
function renderSafeQrCode(container, text, size, dark, light) {
  qrRenderCalls.push({ id: container?.id || container, text, size, dark, light });
}
function renderSyncDiffTable() { return '<div>syncDiff</div>'; }
function humanizeSyncFieldValue(f, v) { return String(v); }
async function loadClients() {}
async function loadDashboard() {}
async function loadReleaseMatrix() {}
async function loadConfig() {}

global.fetch = async (url, opts) => {
  if (url === '/api/licenses/inspect') {
    return { ok: true, status: 200, json: async () => mockInspectResponse };
  }
  if (url === '/api/config/generate-sync-token') {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        token: 'MLC1-TEST512QR.SIGTEST',
        revision: 4,
        issued_at_lima: '2026-11-25 16:00:00',
        payload_bytes: 1200,
        token_bytes: 1750,
        dart_snippet: '// dart',
        summary: { support_phone: '+51 922 836 879', yape_phone: '922836879', yape_holder: 'Julio', plans: [] }
      })
    };
  }
  return { ok: true, status: 200, json: async () => ({ ok: true }) };
};

$fmtLimaSlice
$inspSection
$mlc1Section

async function runTests() {
  initInspectorEvents();

  // 1) Toggle guía de 3 protocolos
  assert.strictEqual(el('inspectorProtocolGuide').style.display, 'none');
  el('btnToggleInspectorGuide').dispatch('click');
  assert.strictEqual(el('inspectorProtocolGuide').style.display, 'block');
  assert.strictEqual(el('btnToggleInspectorGuide').getAttribute('aria-expanded'), 'true');
  el('btnToggleInspectorGuide').dispatch('click');
  assert.strictEqual(el('inspectorProtocolGuide').style.display, 'none');
  assert.strictEqual(el('btnToggleInspectorGuide').getAttribute('aria-expanded'), 'false');

  // 2) Inspección MLC1 válida SUPERSEDED con diferencias en productos y canales
  el('inspectTokenInput').value = 'MLC1-VALIDREV1.SIG1';
  mockInspectResponse = {
    ok: true,
    input_kind: 'COMMERCIAL_CONFIG',
    token_kind: 'MLC1',
    valid: true,
    isValid: true,
    status: 'VALID',
    domain_separated: true,
    revision: 1,
    issued_at: '2026-11-25T16:40:00.000Z',
    issued_at_lima: '2026-11-25 11:40:00',
    payload_bytes: 1320,
    token_bytes: 1850,
    max_payload_bytes: 8192,
    current_config_comparison: {
      local_revision: 3,
      token_revision: 1,
      revision_status: 'SUPERSEDED',
      revision_status_label: 'Revisión anterior a la local',
      recommendation: 'Revisión anterior — Los celulares que ya aplicaron la Rev. #3 la rechazarán por protección anti-downgrade.',
      diff_vs_current: {
        matches_current: false,
        total_differences: 2,
        products_diff: [
          {
            id: 'mensual',
            label: 'Plan Mensual',
            token_values: { pr: 35.0, d: 30, ai: 50, um: 0 },
            current_values: { pr: 42.0, d: 30, ai: 80, um: 0 },
            changed_fields: ['pr', 'ai'],
            matches: false
          },
          {
            id: 'anual',
            label: 'Plan Anual',
            token_values: { pr: 280.0, d: 365, ai: 1200, um: 0 },
            current_values: { pr: 280.0, d: 365, ai: 1200, um: 0 },
            changed_fields: [],
            matches: true
          }
        ],
        channels_diff: [
          { key: 'sup', label: 'Teléfono Soporte', token_value: '+51 922 836 879', current_value: '+51 922 836 879', matches: true },
          { key: 'bcp', label: 'Cuenta BCP', token_value: 'Omitido', current_value: '191-55500011-0-88', matches: false }
        ]
      }
    }
  };
  await inspectToken();

  assert.strictEqual(el('inspectMlc1AuditCard').style.display, 'block');
  assert.strictEqual(el('inspectSyncAuditCard').style.display, 'none');
  assert.strictEqual(el('inspectLicenseClaimsWrapper').style.display, 'none');
  assert.strictEqual(el('inspectMatchingClientBox').style.display, 'none');

  const cardHtml = el('inspectMlc1AuditCard').innerHTML;
  assert.ok(cardHtml.includes('Revisión #1'));
  assert.ok(cardHtml.includes('Admin local actual: Rev. #3'));
  assert.ok(cardHtml.includes('anti-downgrade'));
  assert.ok(cardHtml.includes('Difiere de Config actual'));
  assert.ok(cardHtml.includes('Coincide'));
  assert.ok(cardHtml.includes('191-55500011-0-88'));

  // Informe forense MLC1
  copiedTexts.length = 0;
  el('btnInspectMlc1CopyReport').dispatch('click');
  assert.strictEqual(copiedTexts.length, 1);
  assert.ok(copiedTexts[0].includes('INFORME FORENSE MOCHILALISTA (MLC1)'));
  assert.ok(copiedTexts[0].includes('SUPERSEDED'));
  assert.ok(copiedTexts[0].includes('Producto mensual'));

  // Historial incluye MLC1 con badge-mlc1
  assert.strictEqual(inspectorSessionHistory[0].kind, 'MLC1');
  assert.ok(el('inspectorSessionHistoryList').children[0].innerHTML.includes('badge-mlc1'));

  // Abrir Configuración (#tabSettings)
  el('btnInspectMlc1OpenSettings').dispatch('click');
  assert.strictEqual(el('tabSettings').classList.contains('active'), true);
  assert.strictEqual(navTabs[1].classList.contains('active'), true);
  assert.strictEqual(el('currentViewName').textContent, 'Configuración y Personalización');

  // 3) Inspección MLC1 inválida con lectura diagnóstica NO CONFIABLE
  el('inspectTokenInput').value = 'MLC1-TAMPERED.SIG';
  mockInspectResponse = {
    ok: false,
    input_kind: 'COMMERCIAL_CONFIG',
    token_kind: 'MLC1',
    valid: false,
    isValid: false,
    status: 'INVALID_SIGNATURE',
    error: 'Firma Ed25519 inválida.',
    security_alert: 'FIRMA ED25519 INVÁLIDA O FICHA ALTERADA — No compartir ni aplicar; regenera una ficha oficial desde Configuración',
    diagnostic_only: true,
    payload: null,
    diagnostic_payload: { v: 1, ver: 99, sup: '+51 999', script: 'eval(1)' },
    diagnostic_summary: { revision: 99, support_phone: '+51 999', unexpected_keys: ['script'] }
  };
  await inspectToken();
  const badHtml = el('inspectMlc1AuditCard').innerHTML;
  assert.ok(el('inspectStatusBadge').innerHTML.includes('FIRMA ED25519 INVÁLIDA'));
  assert.ok(badHtml.includes('Lectura Diagnóstica (NO CONFIABLE'));
  assert.ok(badHtml.includes('Claves no autorizadas detectadas: script'));
  assert.strictEqual(inspectorSessionHistory[0].statusText, 'Firma inválida');

  // 4) Limpiar oculta resultado e inspectMlc1AuditCard
  el('btnClearInspectToken').dispatch('click');
  assert.strictEqual(el('inspectResultContainer').style.display, 'none');
  assert.strictEqual(el('inspectMlc1AuditCard').style.display, 'none');

  // 5) Helper tryDecodeQrCanvasWithUpscale reintenta con 2x sin suavizado y padding blanco
  const srcCanvas = new MockElement('srcCanvas');
  srcCanvas.width = 196;
  srcCanvas.height = 196;
  let attempts = 0;
  const decoded = tryDecodeQrCanvasWithUpscale(srcCanvas, (data, w, h, opts) => {
    attempts++;
    assert.strictEqual(opts.inversionAttempts, 'attemptBoth');
    if (attempts === 1) return null; // falla en 196x196
    assert.strictEqual(w, 196 * 2 + 48);
    assert.strictEqual(h, 196 * 2 + 48);
    return { data: 'MLC1-DECODED-2X.SIG' };
  });
  assert.strictEqual(decoded, 'MLC1-DECODED-2X.SIG');
  assert.strictEqual(attempts, 2);
  assert.strictEqual(createdCanvases[0]._ctx.imageSmoothingEnabled, false);

  // 6) Emisor MLC1 genera QR a 512px
  await generateMlc1SyncToken();
  assert.strictEqual(qrRenderCalls.length, 1);
  assert.strictEqual(qrRenderCalls[0].size, 512);

  console.log('PLAN23_5_FASE2_UI_NODE_OK');
}

runTests().catch(err => {
  console.error(err);
  process.exit(1);
});
''');

      final res = await Process.run('node', [harness.path]);
      expect(
        res.exitCode,
        equals(0),
        reason: 'Node test Fase 2 falló:\nSTDOUT: ${res.stdout}\nSTDERR: ${res.stderr}',
      );
      expect(res.stdout.toString(), contains('PLAN23_5_FASE2_UI_NODE_OK'));
    });
  });
}
