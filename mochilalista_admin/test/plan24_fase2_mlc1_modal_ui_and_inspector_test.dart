import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

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
      'PLAN MAESTRO 24 - FASE 2: Rediseño UX Vía 1 en #modalCommercialConfigSync y Auditoría 1-Clic en Inspector',
      () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p24_fase2_ui_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        '1. Auditoría estática HTML/CSS/JS: tabs horizontales, tabla 8 productos sin 0 d, guía cliente, #mlc1QrMetaBadge, #btnAuditMlc1InInspector, Dark/Light y 0 emojis',
        () {
      final html = File('web/index.html').readAsStringSync();
      final css = File('web/css/styles.css').readAsStringSync();
      final js = File('web/js/admin_app.js').readAsStringSync();

      // Sección exacta del modal MLC1 en index.html
      final modalHtml = _extractSection(
        html,
        'id="modalCommercialConfigSync"',
        '<script src="js/admin_app.js',
      );

      // Pestañas Vía 1 y Vía 2
      expect(modalHtml, contains('class="mlc1-tabs-bar"'));
      expect(modalHtml, contains('Vía 1: Ficha Firmada MLC1 (Offline)'));
      expect(
        modalHtml,
        contains('Vía 2: Archivo Dart Completo (Futuros APKs)'),
      );

      // Encabezados de tabla claros y sin límite apretado max-height: 185px
      expect(modalHtml, contains('<th>Producto</th>'));
      expect(modalHtml, contains('>Precio</th>'));
      expect(modalHtml, contains('>Vigencia</th>'));
      expect(modalHtml, contains('>Bolsa IA</th>'));
      expect(modalHtml, contains('>Updates</th>'));
      expect(modalHtml, isNot(contains('max-height: 185px')));

      // Guía 3 pasos cliente, badge QR y botón 1-clic Inspector
      expect(modalHtml, contains('class="mlc1-client-steps-box"'));
      expect(
        modalHtml,
        contains('Cómo aplica esta ficha el cliente en su celular'),
      );
      expect(
        modalHtml,
        contains('Perfil &gt; Licencia y Activación'),
      );
      expect(modalHtml, contains('Aplicar Tarifas Oficiales'));
      expect(modalHtml, contains('id="mlc1QrMetaBadge"'));
      expect(modalHtml, contains('id="btnAuditMlc1InInspector" disabled'));
      expect(modalHtml, contains('Auditar esta ficha en Inspector'));

      // Todo <svg> del modal con dimensiones acotadas
      final svgTagRegex = RegExp(r'<svg\b[^>]*>');
      for (final match in svgTagRegex.allMatches(modalHtml)) {
        final tag = match.group(0)!;
        final hasBounds = tag.contains('width=') ||
            tag.contains('height=') ||
            tag.contains('btn-icon') ||
            tag.contains('icon-svg');
        expect(hasBounds, isTrue,
            reason: 'SVG sin dimensiones acotadas en #modalCommercialConfigSync: $tag');
      }

      // CSS Dark + Light + grid horizontal lado a lado + preview 220px pixelated
      final modalCss = _extractSection(
        css,
        '.mlc1-security-banner',
        '/* 5. Densidad Compacta de Tablas',
      );
      expect(modalCss, contains('display: grid;'));
      expect(
        modalCss,
        contains('grid-template-columns: repeat(2, minmax(0, 1fr));'),
      );
      expect(modalCss, contains('@media (max-width: 640px)'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-tab-btn'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-tab-btn.active'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-summary-card'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-plans-mini-table'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-client-steps-box'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-qr-card'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-qr-meta-badge.is-ready'));
      expect(modalCss, contains('[data-theme="light"] .mlc1-qr-meta-badge.is-error'));
      expect(modalCss, contains('width: 220px !important;'));
      expect(modalCss, contains('image-rendering: pixelated;'));

      // 4 bloques contractuales intactos en admin_app.js
      final fmtIdx = js.indexOf('function formatApkSizeMb(');
      final sigIdx = js.indexOf('function renderSignatureStatusBadge(');
      expect(fmtIdx, isPositive);
      expect(sigIdx, greaterThan(fmtIdx));

      final sec5Start = js.indexOf('// =================== 5. INSPECTOR FORENSE DUAL');
      final sec6Start = js.indexOf('// =================== 6. FINANZAS');
      expect(sec5Start, isPositive);
      expect(sec6Start, greaterThan(sec5Start));

      final verifyStart = js.indexOf('let isVerifyAllCatalogRunning = false;');
      final verifyEnd = js.indexOf('/**\n * Carga notas compañeras', verifyStart + 1);
      expect(verifyStart, isPositive);
      expect(verifyEnd, greaterThan(verifyStart));

      final sec8Start = js.indexOf('// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL');
      final sec9Start = js.indexOf('// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL');
      expect(sec8Start, isPositive);
      expect(sec9Start, greaterThan(sec8Start));

      final sec8bJs = _extractSection(
        js,
        '// =================== 8B. EMISOR DECLARATIVO MLC1-',
        '// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL',
      );

      // Cero emojis crudos ni símbolos prohibidos
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      const bannedSymbols = [
        '✅', '❌', '⚠️', 'ℹ️', '⬇️', '📁', '✏️', '🗑️', '📲', '🚀', '📦',
        '🛡️', '🔍', '💡', '🔐', '📄', '📋', '🪪', '📱', '✕', '✓', '📅', '⚡',
      ];
      for (final chunk in [modalHtml, modalCss, sec8bJs]) {
        expect(emojiRegex.hasMatch(chunk), isFalse,
            reason: 'Emoji Unicode prohibido encontrado en UI MLC1 Fase 2');
        for (final sym in bannedSymbols) {
          expect(chunk.contains(sym), isFalse,
              reason: 'Símbolo prohibido ($sym) detectado en UI MLC1 Fase 2');
        }
      }
    });

    test(
        '2. Ejecución Node.js real: renderMlc1CommercialSummary sin 0 d (8 productos + 12 meses), generateMlc1SyncToken QR 512px y auditMlc1TokenInInspector()',
        () async {
      final js = File('web/js/admin_app.js').readAsStringSync();
      final qrCodeSrc = File('web/js/qrcode.min.js').readAsStringSync();
      final jsQrSrc = File('web/js/jsqr.min.js').readAsStringSync();

      final safeQrSnippet = _extractSection(
        js,
        'function getUtf8ByteLength(',
        'let globalClients = [];',
      );
      final settingsSection = _extractSection(
        js,
        '// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL',
        '// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL',
      );

      final harnessFile = File('${tempDir.path}/p24_fase2_mlc1_ui_test.js');
      await harnessFile.writeAsString('''
const assert = require('assert');
const vm = require('vm');

class MockClassList {
  constructor(initial = []) { this.set = new Set(initial); }
  add(...cls) { cls.forEach(c => this.set.add(c)); }
  remove(...cls) { cls.forEach(c => this.set.delete(c)); }
  toggle(c, f) {
    if (f === undefined) {
      if (this.set.has(c)) { this.set.delete(c); return false; }
      this.set.add(c); return true;
    }
    if (f) this.set.add(c); else this.set.delete(c);
    return !!f;
  }
  contains(c) { return this.set.has(c); }
}

function parseColor(colorStr) {
  const s = String(colorStr || '').trim().toLowerCase();
  if (s === 'white' || s === '#fff' || s === '#ffffff') return [255, 255, 255, 255];
  if (s === 'black' || s === '#000' || s === '#000000') return [0, 0, 0, 255];
  if (s.startsWith('#') && s.length === 7) {
    return [parseInt(s.slice(1, 3), 16), parseInt(s.slice(3, 5), 16), parseInt(s.slice(5, 7), 16), 255];
  }
  return [15, 23, 42, 255];
}

function makeMockCanvas() {
  return {
    tagName: 'CANVAS',
    width: 0,
    height: 0,
    style: {},
    _rgba: new Uint8ClampedArray(0),
    _initBuffer() {
      this._rgba = new Uint8ClampedArray(Math.max(0, Math.floor(this.width)) * Math.max(0, Math.floor(this.height)) * 4);
    },
    getContext(kind) {
      if (kind !== '2d') return null;
      const self = this;
      if (self._rgba.length !== self.width * self.height * 4) self._initBuffer();
      return {
        fillStyle: '#000000',
        imageSmoothingEnabled: true,
        fillRect(x, y, w, h) {
          if (self._rgba.length !== self.width * self.height * 4) self._initBuffer();
          const [r, g, b, a] = parseColor(this.fillStyle);
          const x0 = Math.max(0, Math.round(x)), y0 = Math.max(0, Math.round(y));
          const x1 = Math.min(self.width, Math.round(x + w)), y1 = Math.min(self.height, Math.round(y + h));
          for (let py = y0; py < y1; py++) {
            for (let px = x0; px < x1; px++) {
              const idx = (py * self.width + px) * 4;
              self._rgba[idx] = r; self._rgba[idx + 1] = g; self._rgba[idx + 2] = b; self._rgba[idx + 3] = a;
            }
          }
        }
      };
    },
    toDataURL() { return 'data:image/png;base64,MOCK'; }
  };
}

class MockElement {
  constructor(id = '', classes = [], dataset = {}, tagName = 'DIV') {
    this.id = id;
    this.tagName = tagName;
    this.classList = new MockClassList(classes);
    this.dataset = { ...dataset };
    this.style = {};
    this.value = '';
    this.textContent = '';
    this._innerHTML = '';
    this.listeners = {};
    this.disabled = false;
    this.children = [];
  }
  set innerHTML(v) {
    this._innerHTML = String(v);
    if (v === '') this.children = [];
  }
  get innerHTML() { return this._innerHTML; }
  appendChild(c) { this.children.push(c); return c; }
  querySelector(sel) {
    if (sel === 'canvas') return this.children.find(c => c.tagName === 'CANVAS') || null;
    if (sel.startsWith('.')) {
      const cls = sel.slice(1);
      return this.children.find(c => String(c.className || '').split(/\\s+/).includes(cls)) || null;
    }
    return null;
  }
  addEventListener(evt, fn) {
    this.listeners[evt] = this.listeners[evt] || [];
    this.listeners[evt].push(fn);
  }
  dispatch(evt, target = this) {
    return (this.listeners[evt] || []).map(fn => fn({ target }));
  }
  setAttribute() {}
  getAttribute() { return ''; }
}

const elMap = {};
function el(id, classes = [], dataset = {}) {
  if (!elMap[id]) elMap[id] = new MockElement(id, classes, dataset);
  return elMap[id];
}

[
  'btnOpenCommercialSyncModal', 'modalCommercialConfigSync',
  'btnCloseCommercialSyncModal', 'btnDismissCommercialSyncModal',
  'mlc1PaneToken', 'mlc1PaneDart', 'mlc1RevisionBadge', 'mlc1IssuedAtLimaBadge',
  'mlc1PayloadSizeBadge', 'btnGenerateMlc1Token', 'mlc1AccountsSummary',
  'mlc1PlansSummaryBody', 'mlc1EmptyResultHint', 'mlc1TokenResultContainer',
  'mlc1TokenOutput', 'btnCopyMlc1Token', 'btnSendMlc1Whatsapp',
  'btnAuditMlc1InInspector', 'mlc1QrMetaBadge',
  'mlc1QrContainer', 'btnDownloadMlc1Qr', 'btnCopyMlc1Qr',
  'mlc1DartSnippetOutput', 'btnCopyMlc1Dart',
  'currentViewName', 'inspectTokenInput', 'tabSettings', 'tabInspector',
  'cfgMigrationFee', 'cfgTemplateSelect', 'cfgTemplateContent',
  'cfgLegalOwner', 'cfgBrandName', 'cfgSupportPhone', 'cfgYapePhone', 'cfgYapeHolder',
  'cfgBcpHolder', 'cfgBcpAccount', 'cfgBcpCci',
  'cfgBbvaHolder', 'cfgBbvaAccount', 'cfgBbvaCci',
  'cfgDefaultEnv', 'cfgDefaultTheme', 'cfgTableDensity',
  'settingsDirtyBadge', 'settingsDirtyBadgeText', 'catalogConfigTableBody'
].forEach(id => el(id));

el('btnAuditMlc1InInspector').disabled = true;
el('tabSettings', ['tab-pane', 'active']);
el('tabInspector', ['tab-pane']);

const navTabs = [
  new MockElement('navTabSettings', ['nav-tab', 'active'], { tab: 'tabSettings' }),
  new MockElement('navTabInspector', ['nav-tab'], { tab: 'tabInspector' }),
];
const tabPanes = [el('tabSettings'), el('tabInspector')];
const mlc1TabBtns = ['mlc1PaneToken', 'mlc1PaneDart'].map((id, idx) =>
  new MockElement('', idx === 0 ? ['mlc1-tab-btn', 'active'] : ['mlc1-tab-btn'], { mlc1Tab: id })
);

const b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
let sampleMlc1Token = 'MLC1-';
for (let i = 0; i < 1985; i++) sampleMlc1Token += b64[(i * 11 + 5) % b64.length];

const eightPlans = [
  { id: 'mensual', label: 'Plan Mensual', price: 35, days: 30, ai_credits: 50, updates_months: 0 },
  { id: 'trimestral', label: 'Plan Trimestral', price: 90, days: 90, ai_credits: 180, updates_months: 0 },
  { id: 'semestral', label: 'Plan Semestral', price: 160, days: 180, ai_credits: 450, updates_months: 0 },
  { id: 'anual', label: 'Plan Anual', price: 280, days: 365, ai_credits: 1200, updates_months: 0 },
  { id: 'perpetua', label: 'Perpetuo Liberado', price: 850, days: 99999, ai_credits: 200, updates_months: 12 },
  { id: 'bolsa_extra_ia', label: 'Recarga Extra IA (+150)', price: 20, days: 0, ai_credits: 150, updates_months: 0 },
  { id: 'pase_anual_updates', label: 'Pase Anual de Updates', price: 150, days: 0, ai_credits: 100, updates_months: 12 },
  { id: 'migracion', label: 'Tarifa Técnica de Migración', price: 40, days: 0, ai_credits: 0, updates_months: 0 },
];

const openedModals = [];
const closedModals = [];
const downloadCalls = [];
const inspectCalls = [];
const toasts = [];
let mockRev = 1;

const sandbox = {
  console, TextEncoder, Uint8Array, Uint8ClampedArray, Math, Error, Array, Number, String, parseInt, Object, Set, URLSearchParams,
  open() {},
  document: {
    documentElement: { setAttribute() {}, getAttribute() { return 'dark'; } },
    getElementById(id) { return elMap[id] || null; },
    createElement(tag) {
      return String(tag).toLowerCase() === 'canvas' ? makeMockCanvas() : new MockElement('', [], {}, tag.toUpperCase());
    },
    querySelector(sel) {
      if (sel === '[data-tab="tabInspector"]') return navTabs[1];
      return null;
    },
    querySelectorAll(sel) {
      if (sel === '.mlc1-tab-btn') return mlc1TabBtns;
      if (sel === '.mlc1-tab-pane') return [el('mlc1PaneToken'), el('mlc1PaneDart')];
      if (sel === '.nav-tab') return navTabs;
      if (sel === '.tab-pane') return tabPanes;
      return [];
    }
  },
  ownerConfig: {
    system: { default_mode: 'sandbox', theme: 'dark', table_density: 'comfortable', commercial_sync_revision: 1 },
    legal_identity: { commercial_name: 'MochilaLista', support_phone: '+51 922 836 879', author_full_name: 'Julio Angello Vasquez Navarro' },
    payment_methods: { yape_plin_phone: '922836879', yape_plin_holder: 'Julio Angello Vasquez Navarro' },
    catalog: {
      MENSUAL: { label: 'Plan Mensual', price: 35, days: 30, ai_credits: 50, updates_window_months: 0 },
      PERPETUO_LIBERADO: { label: 'Perpetuo Liberado', price: 850, days: 99999, ai_credits: 200, updates_window_months: 0 },
      PASE_ACTUALIZACION_ANUAL: { label: 'Pase Anual de Updates', price: 150, days: 0, ai_credits: 100, updates_window_months: 0 }
    },
    templates: {}
  },
  showToast: (m, t) => toasts.push({ m, t }),
  openModal: (id) => openedModals.push(id),
  closeModal: (id) => closedModals.push(id),
  showConfirmModal: () => {},
  copyPlainTextToClipboard: () => {},
  downloadQrWithQuietZone: (sel, name, margin) => downloadCalls.push({ sel, name, margin }),
  escapeHtml: (s) => String(s ?? ''),
  formatApkSizeMb: (s) => String(s ?? ''),
  getLatestPublishedVersion: () => '9.41.0',
  compareSemVer: () => 0,
  getClientStatusBadge: () => ({ className: 'badge', text: 'Activa', isProspect: false, isPerp: false }),
  updatePlanImpactAndProjection: () => {},
  applyTheme: () => {},
  inspectToken: async () => { inspectCalls.push(el('inspectTokenInput').value); },
  fetch: async (url) => {
    if (url === '/api/config/dart-defaults-snippet') {
      return {
        ok: true, status: 200,
        json: async () => ({
          ok: true, revision: mockRev, dart_snippet: '// DART REV ' + mockRev,
          summary: {
            revision: mockRev, support_phone: '+51 922 836 879',
            yape_phone: '922836879', yape_holder: 'Julio Angello Vasquez Navarro',
            bcp_configured: false, bbva_configured: false, plans: eightPlans,
          }
        })
      };
    }
    if (url === '/api/config/generate-sync-token') {
      mockRev++;
      return {
        ok: true, status: 200,
        json: async () => ({
          ok: true, token: sampleMlc1Token, revision: mockRev,
          issued_at: '2026-11-25T17:45:00Z', issued_at_lima: '2026-11-25 12:45:00 (Lima GMT-5)',
          payload_bytes: 1423, token_bytes: Buffer.byteLength(sampleMlc1Token, 'utf8'),
          dart_snippet: '// DART REV ' + mockRev,
          summary: {
            revision: mockRev, support_phone: '+51 922 836 879',
            yape_phone: '922836879', yape_holder: 'Julio Angello Vasquez Navarro',
            bcp_configured: false, bbva_configured: false, plans: eightPlans,
          },
          config: sandbox.ownerConfig
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
vm.runInContext(${jsonEncode(qrCodeSrc)}, sandbox);
vm.runInContext(${jsonEncode(jsQrSrc)}, sandbox);
vm.runInContext(${jsonEncode(safeQrSnippet)}, sandbox);
vm.runInContext(${jsonEncode(settingsSection)}, sandbox);
vm.runInContext('getDirtySettingsTabs = () => [];', sandbox);

(async () => {
  sandbox.initSettingsEvents();

  // 1. populateSettingsForm aplica fallback preventivo 12 cuando PERPETUO_LIBERADO/PASE_ACTUALIZACION_ANUAL vienen en 0
  sandbox.populateSettingsForm(sandbox.ownerConfig);
  const rowsHtml = el('catalogConfigTableBody').children.map(c => c.innerHTML).join('\\n');
  assert.ok(rowsHtml.includes('value="12"'), 'Fallback preventivo 12 debe aplicarse en tabla settings');

  // 2. Abrir modal -> Vía 1 activa, 8 productos sin "0 d", Inspector deshabilitado y QR pendiente
  await sandbox.loadAndOpenCommercialSyncModal();
  assert.ok(openedModals.includes('modalCommercialConfigSync'));
  assert.strictEqual(el('btnAuditMlc1InInspector').disabled, true);
  assert.strictEqual(el('mlc1QrMetaBadge').textContent, 'QR pendiente de emisión');

  const summaryHtml = el('mlc1PlansSummaryBody').innerHTML;
  assert.strictEqual(/>0\\s*d</.test(summaryHtml), false, 'No debe mostrarse celda con 0 d');
  assert.ok(summaryHtml.includes('Vitalicia'));
  assert.ok(summaryHtml.includes('Recarga'));
  assert.ok(summaryHtml.includes('Pase anual'));
  assert.ok(summaryHtml.includes('Único'));
  assert.ok(summaryHtml.includes('30 días'));
  assert.ok(summaryHtml.includes('12 meses'));

  // 3. Emitir token -> QR 512x512 real decodificable, badge ready y botón Inspector habilitado
  await sandbox.generateMlc1SyncToken();
  assert.strictEqual(el('btnAuditMlc1InInspector').disabled, false);
  assert.ok(el('mlc1QrMetaBadge').classList.contains('is-ready'));
  assert.ok(el('mlc1QrMetaBadge').textContent.includes('QR 512 px'));
  assert.ok(el('mlc1QrMetaBadge').textContent.includes('Nivel L'));
  const qrCanvas = el('mlc1QrContainer').querySelector('canvas');
  assert.ok(qrCanvas && qrCanvas.width === 512 && qrCanvas.height === 512);
  const decoded = sandbox.jsQR(qrCanvas._rgba, qrCanvas.width, qrCanvas.height, { inversionAttempts: 'attemptBoth' });
  assert.ok(decoded && decoded.data === sampleMlc1Token, 'QR generado en modal debe decodificarse idéntico al token');

  // Descargar PNG invoca quiet zone 32px
  el('btnDownloadMlc1Qr').dispatch('click');
  assert.strictEqual(downloadCalls.length, 1);
  assert.strictEqual(downloadCalls[0].margin, 32);

  // 4. Clic en Auditar esta ficha en Inspector -> cierra modal, abre #tabInspector, pega token e invoca inspectToken()
  await el('btnAuditMlc1InInspector').dispatch('click')[0];
  assert.ok(closedModals.includes('modalCommercialConfigSync'));
  assert.strictEqual(navTabs[0].classList.contains('active'), false);
  assert.strictEqual(navTabs[1].classList.contains('active'), true);
  assert.strictEqual(el('tabSettings').classList.contains('active'), false);
  assert.strictEqual(el('tabInspector').classList.contains('active'), true);
  assert.strictEqual(el('currentViewName').textContent, 'Inspector Forense (ML9 / MLS1 / MLC1)');
  assert.strictEqual(el('inspectTokenInput').value, sampleMlc1Token);
  assert.strictEqual(inspectCalls.length, 1);
  assert.strictEqual(inspectCalls[0], sampleMlc1Token);

  console.log('PLAN24_FASE2_UI_NODE_OK');
})();
''');

      final res = await Process.run('node', [harnessFile.path]);
      expect(
        res.exitCode,
        equals(0),
        reason: 'Node test Fase 2 falló:\nSTDOUT: ${res.stdout}\nSTDERR: ${res.stderr}',
      );
      expect(res.stdout.toString(), contains('PLAN24_FASE2_UI_NODE_OK'));
    });
  });
}
