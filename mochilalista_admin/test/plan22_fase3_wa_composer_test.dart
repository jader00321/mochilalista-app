import 'dart:io';
import 'package:test/test.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 22 - FASE 3: Compositor Universal de WhatsApp (#modalWaComposer)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p22_fase3_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. Auditoría HTML/CSS/JS: estructura, SVGs explícitos y cero emojis crudos
    // =========================================================================
    test('1. HTML y CSS: #modalWaComposer completo, .wa-insert-chip.active, >100 MB warning y cero emojis crudos', () {
      final html = WebBundleLoader.loadHtml();
      final css = WebBundleLoader.loadCss();
      final js = WebBundleLoader.loadJs();

      // Bloque completo del modal en index.html
      final modalStart = html.indexOf('id="modalWaComposer"');
      final modalEnd = html.indexOf('id="modalQuickQr"');
      expect(modalStart, greaterThan(0));
      expect(modalEnd, greaterThan(modalStart));
      final modalHtml = html.substring(modalStart, modalEnd);

      // IDs y elementos requeridos en Phase 3 y compatibilidad histórica
      expect(modalHtml, contains('id="waApkDispatchPanel"'));
      expect(modalHtml, contains('id="waApkVersionTitle"'));
      expect(modalHtml, contains('id="waApkVersionSelect"'));
      expect(modalHtml, contains('onchange="onChangeDispatchReleaseVersion(this.value)"'));
      expect(modalHtml, contains('id="waApkSigBadge"'));
      expect(modalHtml, contains('id="waApkSizeWarning"'));
      expect(modalHtml, contains('id="waApkWarningSizeLabel"'));
      expect(modalHtml, contains('id="waApkWarningAdvice"'));
      expect(modalHtml, contains('id="waVariantSelectorGrid"'));
      expect(modalHtml, contains('id="waApkCopySuccessHint"'));
      expect(modalHtml, contains('id="waApkCopySuccessText"'));
      expect(modalHtml, contains('id="btnWaReCopyApk"'));
      expect(modalHtml, contains('id="btnWaCopyTextOnly"'));
      expect(modalHtml, contains('Copiar Solo Texto'));
      expect(modalHtml, contains('id="waStandardFooterActions"'));
      expect(modalHtml, contains('id="waApkDispatchFooterActions"'));

      // 4 chips Insertar: con data-snippet y check SVG integrado
      for (final key in ['payment', 'device', 'expiration', 'token']) {
        expect(modalHtml, contains('data-snippet="$key"'));
      }
      expect(modalHtml, contains('wa-chip-base-icon'));
      expect(modalHtml, contains('wa-chip-check-icon'));

      // Todo <svg> en #modalWaComposer debe declarar width y height explícitos
      final svgTags = RegExp(r'<svg\b[^>]*>').allMatches(modalHtml);
      expect(svgTags.isNotEmpty, isTrue);
      for (final m in svgTags) {
        final tag = m.group(0)!;
        expect(tag, contains('width='), reason: 'SVG sin width explícito en #modalWaComposer: $tag');
        expect(tag, contains('height='), reason: 'SVG sin height explícito en #modalWaComposer: $tag');
      }

      // CSS Fase 3
      final cssWaStart = css.indexOf('.modal-wa-dialog');
      final cssWaEnd = css.indexOf('.wa-variant-selector-grid');
      expect(cssWaStart, greaterThan(0));
      expect(cssWaEnd, greaterThan(cssWaStart));
      final cssWaSection = css.substring(cssWaStart, cssWaEnd);

      expect(cssWaSection, contains('max-width: 760px'));
      expect(cssWaSection, contains('.wa-insert-chip.active'));
      expect(cssWaSection, contains('#25d366'));
      expect(css, contains('[data-theme="light"] .wa-insert-chip.active'));
      expect(
        css.indexOf('[data-theme="light"] .wa-insert-chip.active'),
        greaterThan(cssWaStart),
      );
      expect(cssWaSection, contains('flex-wrap: wrap'));
      expect(cssWaSection, contains('.wa-apk-version-select'));
      expect(cssWaSection, contains('.wa-apk-size-warning'));
      expect(cssWaSection, contains('.wa-apk-copy-success-hint'));

      // Cadena exacta exigida por tests vigentes para portapapeles de WhatsApp
      expect(js, contains('Archivo .apk copiado: presiona Ctrl + V en WhatsApp'));

      // Cero emojis crudos en #modalWaComposer, su CSS y las funciones nuevas JS
      final bannedEmojis = ['✅', '❌', '⚠️', 'ℹ️', '⬇️', '📁', '✏️', '🗑️', '📲', '🚀', '📦', '🛡️', '🔍', '💳', '🖥️', '⏳', '🔑', '✕'];
      final snippetStart = js.indexOf('function buildWaSnippetBlock(');
      final snippetEnd = js.indexOf('function renderWaTemplateBaseText(');
      final dispatchStart = js.indexOf('function parseApkSizeMbNumber(');
      final dispatchEnd = js.indexOf('function revealCurrentDispatchApkFolder(');
      expect(snippetStart, greaterThan(0));
      expect(snippetEnd, greaterThan(snippetStart));
      expect(dispatchStart, greaterThan(0));
      expect(dispatchEnd, greaterThan(dispatchStart));

      for (final chunk in [
        modalHtml,
        cssWaSection,
        js.substring(snippetStart, snippetEnd),
        js.substring(dispatchStart, dispatchEnd),
      ]) {
        for (final emoji in bannedEmojis) {
          expect(chunk, isNot(contains(emoji)), reason: 'Emoji o símbolo crudo prohibido ($emoji) detectado en UI Fase 3');
        }
      }
    });

    // =========================================================================
    // 2. Motor JS real (Node.js): Toggle de plantillas + Chips Multi-Select Idempotentes
    // =========================================================================
    test('2. JS Node.js: Toggle off en plantillas preservando borrador/chips y multi-select idempotente', () async {
      final js = WebBundleLoader.loadJs();

      final helpers = _extractJsSlices(js);
      final harnessFile = File('${tempDir.path}/wa_phase3_templates_chips.js');
      await harnessFile.writeAsString('''
${_buildDomAndGlobalsPreamble()}
$helpers

async function runTests() {
  initWaComposerEvents();

  // Caso A: Abrir compositor en cliente c1 con token real y teléfono válido
  await openWhatsAppComposer('c1', 'welcome');
  assert.strictEqual(currentWaComposerTemplateKey, 'welcome');
  assert.strictEqual(tplButtons.find(b => b.dataset.tpl === 'welcome').classList.contains('active'), true);
  assert.strictEqual(getEl('waApkDispatchPanel').style.display, 'none');

  // Activar chips Yape/Plin y Hardware ID en 1er clic
  insertWaSnippet('payment');
  insertWaSnippet('device');
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'payment').classList.contains('active'), true);
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'device').classList.contains('active'), true);
  const textWithTwoChips = getEl('waCompMessage').value;
  assert.ok(textWithTwoChips.includes('*Datos de Pago Yape / Plin:*'));
  assert.ok(textWithTwoChips.includes('*Hardware ID:* `DEV-A1B2`'));

  // Cambiar a otra plantilla ("license"): reemplaza cuerpo base y conserva ambos chips SIN duplicarlos
  selectWaTemplate('license');
  assert.strictEqual(currentWaComposerTemplateKey, 'license');
  assert.strictEqual(tplButtons.find(b => b.dataset.tpl === 'license').classList.contains('active'), true);
  assert.strictEqual(tplButtons.find(b => b.dataset.tpl === 'welcome').classList.contains('active'), false);
  const licenseText = getEl('waCompMessage').value;
  assert.ok(licenseText.includes('Código de Activación'));
  assert.strictEqual(licenseText.split('*Datos de Pago Yape / Plin:*').length - 1, 1);
  assert.strictEqual(licenseText.split('*Hardware ID:* `DEV-A1B2`').length - 1, 1);

  // 2do clic sobre la misma plantilla activa ("license") -> desactiva píldora y conserva bloques Insertar activos
  selectWaTemplate('license');
  assert.strictEqual(currentWaComposerTemplateKey, null);
  assert.strictEqual(tplButtons.some(b => b.classList.contains('active')), false);
  const afterToggleOff = getEl('waCompMessage').value;
  assert.strictEqual(afterToggleOff.includes('Código de Activación'), false);
  assert.strictEqual(afterToggleOff.split('*Datos de Pago Yape / Plin:*').length - 1, 1);
  assert.strictEqual(afterToggleOff.split('*Hardware ID:* `DEV-A1B2`').length - 1, 1);
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'payment').classList.contains('active'), true);
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'device').classList.contains('active'), true);

  // 2do clic sobre chip "payment" -> retira solo Yape/Plin sin saltos triples y desactiva su clase
  insertWaSnippet('payment');
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'payment').classList.contains('active'), false);
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'device').classList.contains('active'), true);
  assert.strictEqual(getEl('waCompMessage').value.includes('*Datos de Pago Yape / Plin:*'), false);
  assert.ok(getEl('waCompMessage').value.includes('*Hardware ID:* `DEV-A1B2`'));
  assert.strictEqual(/\\n{3,}/.test(getEl('waCompMessage').value), false);

  // Borrador libre -> activar plantilla -> desactivar al 2do clic -> restaura borrador libre intacto
  insertWaSnippet('device'); // quitar device
  getEl('waCompMessage').value = 'Nota libre personalizada para el dueño';
  getEl('waCompMessage').triggerInput();
  selectWaTemplate('expiring');
  assert.ok(getEl('waCompMessage').value.includes('próxima a vencer'));
  selectWaTemplate('expiring');
  assert.strictEqual(getEl('waCompMessage').value, 'Nota libre personalizada para el dueño');
  assert.strictEqual(currentWaComposerTemplateKey, null);

  // Click en "Nueva Versión APK" desde modo CRM abre el panel APK; 2do clic lo cierra
  selectWaTemplate('update');
  assert.strictEqual(getEl('waApkDispatchPanel').style.display, 'block');
  assert.strictEqual(getEl('waApkVersionSelect').options.length, 3);
  assert.ok(getEl('waCompMessage').value.includes('9.40.0'));
  selectWaTemplate('update');
  assert.strictEqual(getEl('waApkDispatchPanel').style.display, 'none');
  assert.strictEqual(getEl('waCompMessage').value, 'Nota libre personalizada para el dueño');

  // Cliente sin token y sin hardware id -> alerta clara y NO activa chips
  await openWhatsAppComposer('c_pending', 'prospect');
  toasts.length = 0;
  insertWaSnippet('device');
  insertWaSnippet('token');
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'device').classList.contains('active'), false);
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'token').classList.contains('active'), false);
  assert.strictEqual(toasts.filter(t => t.type === 'warning').length, 2);
  assert.strictEqual(getEl('waCompMessage').value.includes('ML9-PENDIENTE'), false);

  // Edición manual borrando el texto + evento input apaga chips; + Último Token con token real funciona idempotentemente
  await openWhatsAppComposer('c1', 'welcome');
  insertWaSnippet('expiration');
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'expiration').classList.contains('active'), true);
  insertWaSnippet('token');
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'token').classList.contains('active'), true);
  assert.ok(getEl('waCompMessage').value.includes('ML9-REAL-TOK-2026'));
  insertWaSnippet('token');
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'token').classList.contains('active'), false);
  assert.strictEqual(getEl('waCompMessage').value.includes('ML9-REAL-TOK-2026'), false);
  getEl('waCompMessage').value = '';
  getEl('waCompMessage').triggerInput();
  assert.strictEqual(chipButtons.find(c => c.dataset.snippet === 'expiration').classList.contains('active'), false);

  console.log('PHASE3_TEMPLATES_AND_CHIPS_OK');
}

runTests().catch(err => {
  console.error(err);
  process.exit(1);
});
''');

      final res = await Process.run('node', [harnessFile.path]);
      expect(res.exitCode, equals(0), reason: 'Node test falló: ${res.stderr}\n${res.stdout}');
      expect(res.stdout.toString(), contains('PHASE3_TEMPLATES_AND_CHIPS_OK'));
    });

    // =========================================================================
    // 3. Motor JS real (Node.js): Selector Versión APK, Variantes, >100 MB y Copia .APK
    // =========================================================================
    test('3. JS Node.js: Selector dinámico versión APK, auto-variante, alerta >100 MB y copia .APK robusta', () async {
      final js = WebBundleLoader.loadJs();

      final helpers = _extractJsSlices(js);
      final harnessFile = File('${tempDir.path}/wa_phase3_apk_dispatch.js');
      await harnessFile.writeAsString('''
${_buildDomAndGlobalsPreamble()}
$helpers

async function runTests() {
  initWaComposerEvents();

  // Abrir compositor en modo Despacho Asistido desde Matriz en v9.40.0 (Universal 108.47 MB + ARM64 30.10 MB)
  openApkDispatchComposer('c1', '9.40.0', 'eligible');
  await new Promise(r => setTimeout(r, 20));
  assert.strictEqual(getEl('waApkDispatchPanel').style.display, 'block');
  assert.strictEqual(getEl('waApkDispatchFooterActions').style.display, 'flex');
  assert.strictEqual(getEl('waStandardFooterActions').style.display, 'none');
  assert.strictEqual(getEl('waApkVersionSelect').options[0].value, '9.40.0');
  assert.strictEqual(getEl('waApkVersionSelect').value, '9.40.0');
  assert.ok(getEl('waApkVersionTitle').textContent.includes('9.40.0'));
  assert.strictEqual(getEl('waApkSizeText').textContent, '108.47 MB');
  assert.ok(getEl('waApkSigBadge').innerHTML.includes('badge-official-sig'));
  // Universal >100 MB -> aviso visible recomendando ARM64 Ligero / Desktop
  assert.strictEqual(getEl('waApkSizeWarning').style.display, 'flex');
  assert.strictEqual(getEl('waApkWarningSizeLabel').textContent, '108.47 MB');
  assert.ok(getEl('waApkWarningAdvice').textContent.includes('ARM64 Ligero'));

  // Cambiar manualmente a variante ARM64 Ligero (30.10 MB <= 100 MB) -> oculta aviso
  setDispatchVariant('arm64');
  assert.strictEqual(currentDispatchVariant, 'arm64');
  assert.strictEqual(getEl('waApkSizeText').textContent, '30.10 MB');
  assert.strictEqual(getEl('waApkSizeWarning').style.display, 'none');

  // Activar un chip y cambiar de versión en #waApkVersionSelect hacia v9.39.5 (solo ARM64 32.50 MB, No Oficial)
  insertWaSnippet('payment');
  onChangeDispatchReleaseVersion('9.39.5');
  assert.strictEqual(currentDispatchRelease.version_name, '9.39.5');
  assert.ok(getEl('waApkVersionTitle').textContent.includes('v9.39.5'));
  assert.strictEqual(getEl('waApkDbSchema').textContent, 'Esquema v35');
  assert.ok(getEl('waApkSigBadge').innerHTML.includes('badge-unofficial-sig'));
  // v9.39.5 no tiene Universal -> deshabilita card universal y auto-selecciona arm64
  assert.strictEqual(getEl('waVariantCardUniversal').classList.contains('disabled'), true);
  assert.strictEqual(currentDispatchVariant, 'arm64');
  assert.strictEqual(getEl('waApkSizeText').textContent, '32.50 MB');
  assert.strictEqual(getEl('waApkSizeWarning').style.display, 'none');
  // Mensaje comercial refleja changelog de 9.39.5 y conserva chip payment activo sin duplicar
  assert.ok(getEl('waCompMessage').value.includes('Fix visor PDF'));
  assert.strictEqual(getEl('waCompMessage').value.split('*Datos de Pago Yape / Plin:*').length - 1, 1);

  // Cambiar a v9.38.0 (UNVERIFIED, sin archivo en disco)
  onChangeDispatchReleaseVersion('9.38.0');
  assert.ok(getEl('waApkSigBadge').innerHTML.includes('badge-unverified-sig'));
  assert.strictEqual(getEl('waApkDiskStatus').textContent, 'Sin Binario en Disco');

  // Volver a v9.40.0 para probar copia fallida vs copia exitosa
  onChangeDispatchReleaseVersion('9.40.0');
  setDispatchVariant('arm64');

  // Error HTTP 404 en copy-file -> error toast, NO abre WhatsApp, NO muestra hint ni marca enviado
  mockCopyResponse = { status: 404, body: { ok: false, error: 'Not found' } };
  toasts.length = 0;
  openedUrls.length = 0;
  sentRecords.length = 0;
  await copyApkAndOpenWhatsApp();
  assert.strictEqual(toasts.some(t => t.type === 'error'), true);
  assert.strictEqual(openedUrls.length, 0);
  assert.strictEqual(sentRecords.length, 0);
  assert.strictEqual(getEl('waApkCopySuccessHint').style.display, 'none');

  // Copia exitosa HTTP 200 -> toast exacto, hint visible, WhatsApp abierto y modal sigue abierto
  mockCopyResponse = { status: 200, body: { ok: true, file_name: 'mochilalista-v9.40.0-arm64.apk' } };
  toasts.length = 0;
  openedUrls.length = 0;
  sentRecords.length = 0;
  await copyApkAndOpenWhatsApp();
  assert.strictEqual(
    toasts.some(t => t.type === 'success' && t.msg.includes('Archivo .apk copiado: presiona Ctrl + V en WhatsApp')),
    true
  );
  assert.strictEqual(getEl('waApkCopySuccessHint').style.display, 'flex');
  assert.ok(getEl('waApkCopySuccessText').textContent.includes('mochilalista-v9.40.0-arm64.apk'));
  assert.strictEqual(sentRecords.length, 1);
  assert.strictEqual(openedUrls.length, 1);
  assert.ok(openedUrls[0].url.includes('https://api.whatsapp.com/send?phone=51987654321'));
  assert.strictEqual(closedModals.includes('modalWaComposer'), false);

  // Botón "Copiar Solo Texto"
  copiedPlainTexts.length = 0;
  copyWaComposerMessage();
  assert.strictEqual(copiedPlainTexts.length, 1);
  assert.ok(copiedPlainTexts[0].includes('9.40.0'));

  // Botón "Volver a Copiar .APK"
  toasts.length = 0;
  await reCopyCurrentDispatchApk();
  assert.strictEqual(
    toasts.some(t => t.type === 'success' && t.msg.includes('Archivo .apk copiado: presiona Ctrl + V en WhatsApp')),
    true
  );

  console.log('PHASE3_APK_DISPATCH_OK');
}

runTests().catch(err => {
  console.error(err);
  process.exit(1);
});
''');

      final res = await Process.run('node', [harnessFile.path]);
      expect(res.exitCode, equals(0), reason: 'Node test falló: ${res.stderr}\n${res.stdout}');
      expect(res.stdout.toString(), contains('PHASE3_APK_DISPATCH_OK'));
    });
  });
}

String _extractJsSlices(String js) {
  final fmtPlanStart = js.indexOf('const CANONICAL_PLAN_LABELS = {');
  final fmtPlanEnd = js.indexOf('function normalizePlanToSlug(');
  final semverStart = js.indexOf('function compareSemVer(a, b)');
  final semverEnd = js.indexOf('function getLatestPublishedVersion(');
  final waCoreStart = js.indexOf('function sanitizeWhatsAppDigits(');
  final waCoreEnd = js.indexOf('// =================== UTILIDADES QR VECTORIALES');
  final sec3bStart = js.indexOf('// =================== 3B. COMPOSITOR UNIVERSAL DE WHATSAPP');
  final sec4Start = js.indexOf('// =================== 4. RELEASE MANAGER');
  final fmtStart = js.indexOf('function formatApkSizeMb(');
  final sigEnd = js.indexOf('/**\n * Carga el catálogo de versiones publicadas');
  final dispatchStart = js.indexOf('function parseApkSizeMbNumber(');
  final dispatchEnd = js.indexOf('function revealCurrentDispatchApkFolder(');

  assert(fmtPlanStart >= 0 && fmtPlanEnd > fmtPlanStart);
  assert(semverStart >= 0 && semverEnd > semverStart);
  assert(waCoreStart >= 0 && waCoreEnd > waCoreStart);
  assert(sec3bStart > 0 && sec4Start > sec3bStart);
  assert(fmtStart > 0 && sigEnd > fmtStart);
  assert(dispatchStart > 0 && dispatchEnd > dispatchStart);

  return [
    'let currentWaComposerClientId = null;',
    js.substring(fmtPlanStart, fmtPlanEnd),
    js.substring(semverStart, semverEnd),
    js.substring(waCoreStart, waCoreEnd),
    js.substring(fmtStart, sigEnd),
    js.substring(sec3bStart, sec4Start),
    js.substring(dispatchStart, dispatchEnd),
  ].join('\n\n');
}

String _buildDomAndGlobalsPreamble() {
  return r'''
const assert = require('assert');

class MockClassList {
  constructor(initial = []) {
    this.set = new Set(initial);
  }
  add(...names) { names.forEach(n => this.set.add(n)); }
  remove(...names) { names.forEach(n => this.set.delete(n)); }
  toggle(name, force) {
    if (force === undefined) {
      if (this.set.has(name)) { this.set.delete(name); return false; }
      this.set.add(name); return true;
    }
    if (force) this.set.add(name);
    else this.set.delete(name);
    return !!force;
  }
  contains(name) { return this.set.has(name); }
}

class MockElement {
  constructor(id = '', initialClasses = [], dataset = {}) {
    this.id = id;
    this.classList = new MockClassList(initialClasses);
    this.dataset = { ...dataset };
    this.style = {};
    this.value = '';
    this.textContent = '';
    this.innerHTML = '';
    this.href = '';
    this.disabled = false;
    this.options = [];
    this.listeners = {};
  }
  addEventListener(evt, fn) {
    this.listeners[evt] = this.listeners[evt] || [];
    this.listeners[evt].push(fn);
  }
  triggerInput() {
    (this.listeners['input'] || []).forEach(fn => fn());
  }
  appendChild(child) {
    this.options.push(child);
    return child;
  }
  focus() {}
}

const elements = {};
function getEl(id) {
  if (!elements[id]) elements[id] = new MockElement(id);
  return elements[id];
}

// Registrar IDs esperados del compositor
[
  'modalWaComposer', 'waCompBizName', 'waCompOwnerName', 'waCompPlanBadge', 'waCompDeviceId',
  'waCompPhoneDisplay', 'waCompPhoneWarning', 'btnWaCompSend', 'btnWaCompOpenEmpty',
  'waCompCharCounter', 'waCompMessage', 'waApkDispatchPanel', 'waStandardFooterActions',
  'waApkDispatchFooterActions', 'waApkCopySuccessHint', 'waApkCopySuccessText', 'btnWaReCopyApk',
  'btnWaCopyApkAndSend', 'waApkSizeWarning', 'waApkWarningSizeLabel', 'waApkWarningAdvice',
  'waApkVersionSelect', 'waApkVersionTitle', 'waApkSizeText', 'waApkDbSchema', 'waApkDiskStatus',
  'waApkSigBadge', 'waVariantCardUniversal', 'waVariantCardArm64', 'waVariantDescUniversal',
  'waVariantDescArm64'
].forEach(id => getEl(id));

// Reset innerHTML setter on select so options array resets properly
Object.defineProperty(elements['waApkVersionSelect'], 'innerHTML', {
  get() { return this._html || ''; },
  set(v) {
    this._html = v;
    if (v === '') this.options = [];
  }
});

const tplButtons = ['welcome', 'expiring', 'prospect', 'license', 'update', 'empty'].map(
  k => new MockElement('', ['wa-template-btn'], { tpl: k })
);
const chipButtons = ['payment', 'device', 'expiration', 'token'].map(
  k => new MockElement('', ['wa-insert-chip'], { snippet: k })
);

global.document = {
  getElementById(id) { return elements[id] || null; },
  querySelectorAll(sel) {
    if (sel === '.wa-template-btn') return tplButtons;
    if (sel === '.wa-insert-chip') return chipButtons;
    return [];
  },
  createElement(tag) { return new MockElement(''); }
};

const toasts = [];
const openModals = [];
const closedModals = [];
const openedUrls = [];
const sentRecords = [];
const copiedPlainTexts = [];
let mockCopyResponse = { status: 200, body: { ok: true, file_name: 'mochilalista-v9.40.0.apk' } };

global.window = {
  open(url, target) { openedUrls.push({ url, target }); }
};

function showToast(msg, type = 'info') { toasts.push({ msg, type }); }
function openModal(id) { openModals.push(id); }
function closeModal(id) { closedModals.push(id); }
function escapeHtml(s) { return String(s || ''); }
function getClientStatusBadge(client) {
  const isProspect = String(client.license_type || '').toUpperCase() === 'PROSPECTO';
  const isPerp = String(client.license_type || '').toUpperCase().includes('PERPETUO');
  return { className: 'badge badge-green', text: isProspect ? 'Prospecto' : 'Activa', isProspect, isPerp };
}
function getLatestPublishedVersion() { return '9.40.0'; }
function copyPlainTextToClipboard(text, msg) {
  copiedPlainTexts.push(text);
  showToast(msg, 'success');
}
async function recordApkSent(clientId, versionName, variant) {
  sentRecords.push({ clientId, versionName, variant });
}
async function loadReleaseMatrix() {}

global.fetch = async (url, opts) => {
  if (url.includes('/history')) {
    if (url.includes('/c1/')) {
      return { ok: true, status: 200, json: async () => ({ codes: [{ token: 'ML9-REAL-TOK-2026' }] }) };
    }
    return { ok: true, status: 200, json: async () => ({ codes: [] }) };
  }
  if (url.includes('/copy-file')) {
    return {
      ok: mockCopyResponse.status >= 200 && mockCopyResponse.status < 300,
      status: mockCopyResponse.status,
      json: async () => mockCopyResponse.body
    };
  }
  return { ok: true, status: 200, json: async () => ({ ok: true }) };
};

let globalClients = [
  {
    id: 'c1',
    business_name: 'Libreria Norte',
    owner_name: 'Carlos Ruiz',
    phone: '987654321',
    current_device_id: 'DEV-A1B2',
    license_type: 'ANUAL',
    license_expires: '2027-06-30T00:00:00.000Z',
    installed_version: '9.38.0'
  },
  {
    id: 'c_pending',
    business_name: 'Bodega Sur',
    owner_name: 'Elena Diaz',
    phone: '',
    current_device_id: 'PENDIENTE',
    license_type: 'PROSPECTO'
  }
];
let globalReleaseMatrix = [];
let globalReleases = [
  {
    version_name: '9.40.0',
    version_code: 84,
    db_schema_version: 36,
    type: 'FEATURE_RELEASE',
    file_size_mb: '108.47 MB',
    file_exists: true,
    apk_file_path: 'releases_apks/9.40.0/universal.apk',
    universal_apk: { file_size_mb: '108.47 MB', file_path: 'releases_apks/9.40.0/universal.apk' },
    arm64_apk: { file_size_mb: '30.10 MB', file_path: 'releases_apks/9.40.0/arm64.apk' },
    changelog: 'Mejoras v9.40.0 de velocidad e inventario.',
    signature_status: 'OFFICIAL_RELEASE',
    signature_verified: true
  },
  {
    version_name: '9.39.5',
    version_code: 83,
    db_schema_version: 35,
    type: 'HOTFIX',
    file_size_mb: '32.50 MB',
    file_exists: true,
    arm64_apk: { file_size_mb: '32.50 MB', file_path: 'releases_apks/9.39.5/arm64.apk' },
    changelog: 'Fix visor PDF en tickets térmicos.',
    signature_status: 'UNOFFICIAL_SIGNATURE',
    signature_verified: false
  },
  {
    version_name: '9.38.0',
    version_code: 82,
    db_schema_version: 34,
    type: 'FEATURE_RELEASE',
    file_size_mb: '95.00 MB',
    file_exists: false,
    changelog: 'Release base 9.38.0.',
    signature_status: 'UNVERIFIED',
    signature_verified: null
  }
];
let ownerConfig = {
  payment_methods: { yape_plin_phone: '922836879', yape_plin_holder: 'Titular Oficial' },
  legal_identity: { author_full_name: 'Autor Oficial' },
  catalog: { PASE_ACTUALIZACION_ANUAL: { price: 150 } },
  templates: {}
};
''';
}
