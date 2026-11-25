import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mochilalista_admin/apk_inspector_service.dart';
import 'package:mochilalista_admin/config_service.dart';
import 'package:mochilalista_admin/database_service.dart';
import 'package:test/test.dart';

File _resolveRepoFile(String relativeInsideAdmin) {
  final direct = File(relativeInsideAdmin);
  if (direct.existsSync()) return direct;
  return File('mochilalista_admin/$relativeInsideAdmin');
}

/// Construye un archivo .apk (ZIP) mínimo válido con entradas lib/<abi>/libapp.so
void _createFakeApkZip(
  String filePath, {
  bool includeArm64 = true,
  bool includeArmV7 = true,
}) {
  final file = File(filePath);
  file.parent.createSync(recursive: true);

  final entries = <String, List<int>>{
    'AndroidManifest.xml': utf8.encode('manifest_stub'),
  };
  if (includeArm64) {
    entries['lib/arm64-v8a/libapp.so'] = utf8.encode('arm64_binary_stub');
  }
  if (includeArmV7) {
    entries['lib/armeabi-v7a/libapp.so'] = utf8.encode('armv7_binary_stub');
  }

  final out = BytesBuilder();
  final centralDirectory = BytesBuilder();
  var offset = 0;

  void writeUint16(BytesBuilder b, int v) {
    b.add([v & 0xFF, (v >> 8) & 0xFF]);
  }

  void writeUint32(BytesBuilder b, int v) {
    b.add([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);
  }

  entries.forEach((name, data) {
    final nameBytes = utf8.encode(name);
    final localHeader = BytesBuilder();
    writeUint32(localHeader, 0x04034b50);
    writeUint16(localHeader, 20);
    writeUint16(localHeader, 0);
    writeUint16(localHeader, 0);
    writeUint16(localHeader, 0);
    writeUint16(localHeader, 0);
    writeUint32(localHeader, 0);
    writeUint32(localHeader, data.length);
    writeUint32(localHeader, data.length);
    writeUint16(localHeader, nameBytes.length);
    writeUint16(localHeader, 0);
    localHeader.add(nameBytes);
    localHeader.add(data);

    final chunk = localHeader.toBytes();
    out.add(chunk);

    writeUint32(centralDirectory, 0x02014b50);
    writeUint16(centralDirectory, 20);
    writeUint16(centralDirectory, 20);
    writeUint16(centralDirectory, 0);
    writeUint16(centralDirectory, 0);
    writeUint16(centralDirectory, 0);
    writeUint16(centralDirectory, 0);
    writeUint32(centralDirectory, 0);
    writeUint32(centralDirectory, data.length);
    writeUint32(centralDirectory, data.length);
    writeUint16(centralDirectory, nameBytes.length);
    writeUint16(centralDirectory, 0);
    writeUint16(centralDirectory, 0);
    writeUint16(centralDirectory, 0);
    writeUint16(centralDirectory, 0);
    writeUint32(centralDirectory, 0);
    writeUint32(centralDirectory, offset);
    centralDirectory.add(nameBytes);

    offset += chunk.length;
  });

  final cdBytes = centralDirectory.toBytes();
  out.add(cdBytes);

  writeUint32(out, 0x06054b50);
  writeUint16(out, 0);
  writeUint16(out, 0);
  writeUint16(out, entries.length);
  writeUint16(out, entries.length);
  writeUint32(out, cdBytes.length);
  writeUint32(out, offset);
  writeUint16(out, 0);

  file.writeAsBytesSync(out.toBytes());
}

void main() {
  test(
    '1. Auditoría HTML/CSS Fase 3: 4 expandables, contadores, estilos tema claro/oscuro, SVGs acotados y cero emojis',
    () {
      final indexHtml = _resolveRepoFile('web/index.html').readAsStringSync();
      final stylesCss = _resolveRepoFile('web/css/styles.css').readAsStringSync();

      for (final id in [
        'relChangelog',
        'relInternalNotes',
        'editRelChangelog',
        'editRelInternalNotes',
      ]) {
        expect(indexHtml, contains('id="${id}" class="expandable-textarea"'));
        expect(indexHtml, contains('id="${id}Counter" class="textarea-meta-counter"'));
        expect(
          indexHtml,
          contains('class="btn btn-outline btn-xs btn-toggle-textarea" data-target="$id" aria-expanded="false"'),
        );
      }

      for (final marker in [
        'id="editSearchDirsPanel"',
        'id="editSearchDirsList"',
        'id="inputEditNewApkSearchDir"',
        'id="btnEditBrowseApkSearchDir"',
        'id="btnEditAddApkSearchDir"',
        'id="btnEditResetApkSearchDirs"',
        'id="btnCloseEditSearchDirsPanel"',
      ]) {
        expect(indexHtml, contains(marker));
      }

      // Cero emojis prohibidos en #modalCreateRelease .. #modalEditRelease
      final startIdx = indexHtml.indexOf('id="modalCreateRelease"');
      final endIdx = indexHtml.indexOf('id="modalConfirmLicenseEmission"');
      expect(startIdx, greaterThan(0));
      expect(endIdx, greaterThan(startIdx));
      final modalSlice = indexHtml.substring(startIdx, endIdx);
      for (final emoji in [
        '✅',
        '❌',
        '⚠️',
        'ℹ️',
        '⬇️',
        '📁',
        '✏️',
        '🗑️',
        '📲',
        '🚀',
        '📦',
        '🛡️',
        '🔍',
        '✓',
      ]) {
        expect(modalSlice.contains(emoji), isFalse, reason: 'Emoji encontrado en HTML: $emoji');
      }

      // Todos los <svg> en esa franja tienen dimensiones explícitas o clase acotada
      final svgMatches = RegExp(r'<svg\b[^>]*>', caseSensitive: false).allMatches(modalSlice);
      for (final m in svgMatches) {
        final tag = m.group(0)!;
        final hasBounds = tag.contains('width=') ||
            tag.contains('width:') ||
            tag.contains('icon-svg') ||
            tag.contains('btn-icon') ||
            tag.contains('search-icon');
        expect(hasBounds, isTrue, reason: 'SVG sin tamaño explícito en HTML: $tag');
      }

      for (final cssMarker in [
        '.textarea-meta-counter',
        '.btn-toggle-textarea[aria-expanded="true"]',
        '.expandable-textarea',
        '.expandable-textarea.is-expanded',
        '.badge-variant-optional',
        '.edit-variant-optional-note',
        '.edit-variant-missing-note',
        '.edit-picker-header-actions',
        '[data-theme="light"] .textarea-meta-counter',
        '[data-theme="light"] .badge-variant-optional',
        '[data-theme="light"] .edit-variant-missing-note',
      ]) {
        expect(stylesCss, contains(cssMarker));
      }
    },
  );

  test(
    '2. JS Real (Node.js): textareas expandibles independientes, contadores, fix #btnEditLoadAtpTxt, 3 estados de variante, guard ABI, Desvincular seguro y sync #modalWaComposer',
    () async {
      final adminJsFile = _resolveRepoFile('web/js/admin_app.js');
      final jsPathJson = jsonEncode(adminJsFile.absolute.path);

      final script = '''
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const code = fs.readFileSync($jsPathJson, 'utf8');

function makeClassList(initial = []) {
  const set = new Set(initial);
  return {
    add: (...names) => names.forEach(n => set.add(n)),
    remove: (...names) => names.forEach(n => set.delete(n)),
    toggle: (name, force) => {
      if (force === undefined) {
        if (set.has(name)) { set.delete(name); return false; }
        set.add(name); return true;
      }
      if (force) set.add(name); else set.delete(name);
      return !!force;
    },
    contains: (name) => set.has(name),
    toString: () => Array.from(set).join(' '),
  };
}

function makeEl(id, tag = 'div') {
  const listeners = {};
  const attrs = {};
  const el = {
    id,
    tagName: tag.toUpperCase(),
    style: { display: '' },
    dataset: {},
    value: '',
    checked: false,
    disabled: false,
    title: '',
    textContent: '',
    innerHTML: '',
    files: [],
    children: [],
    options: [],
    _listeners: listeners,
    classList: makeClassList(),
    set className(v) {
      el.classList = makeClassList(String(v || '').split(/\\s+/).filter(Boolean));
    },
    get className() {
      return el.classList.toString();
    },
    addEventListener: (ev, fn) => {
      if (!listeners[ev]) listeners[ev] = [];
      listeners[ev].push(fn);
    },
    dispatchEvent: (evObj) => {
      const ev = typeof evObj === 'string' ? { type: evObj, target: el, preventDefault: () => {} } : evObj;
      if (!ev.target) ev.target = el;
      const fns = listeners[ev.type] || [];
      for (const fn of fns) fn(ev);
    },
    click: () => el.dispatchEvent({ type: 'click', target: el, preventDefault: () => {} }),
    setAttribute: (k, v) => { attrs[k] = String(v); },
    getAttribute: (k) => (k in attrs ? attrs[k] : (k === 'data-target' ? el.dataset.target : null)),
    appendChild: (c) => {
      el.children.push(c);
      if (tag.toUpperCase() === 'SELECT') el.options.push(c);
    },
    querySelector: (sel) => {
      if (sel === '.btn-toggle-textarea-label') return el._labelEl || null;
      if (sel === 'svg') return el._svgEl || null;
      if (sel === '#btnLinkLocalBuild_arm64') return elements['btnLinkLocalBuild_arm64'] || null;
      return null;
    },
    querySelectorAll: () => [],
    closest: () => null,
    reset: () => {},
    focus: () => {},
    scrollIntoView: () => {},
  };
  return el;
}

const elements = {};
function ensureEl(id, tag = 'div', initialClasses = []) {
  const el = makeEl(id, tag);
  initialClasses.forEach(c => el.classList.add(c));
  elements[id] = el;
  return el;
}

// Modals & textareas
ensureEl('modalCreateRelease', 'div');
ensureEl('modalEditRelease', 'div');
ensureEl('modalWaComposer', 'div');
ensureEl('formCreateRelease', 'form');

const toggleBtns = [];
for (const tid of ['relChangelog', 'relInternalNotes', 'editRelChangelog', 'editRelInternalNotes']) {
  ensureEl(tid, 'textarea', ['expandable-textarea']);
  ensureEl(tid + 'Counter', 'span');
  const btn = ensureEl('btnToggle_' + tid, 'button');
  btn.dataset.target = tid;
  btn.setAttribute('aria-expanded', 'false');
  btn._labelEl = { textContent: 'Expandir' };
  btn._svgEl = { innerHTML: '' };
  toggleBtns.push(btn);
}

// Companion load buttons + Create inputs
ensureEl('btnEditLoadCambiosTxt', 'button');
ensureEl('btnEditLoadAtpTxt', 'button');
ensureEl('btnCreateLoadCambiosTxt', 'button');
ensureEl('btnCreateLoadAtpTxt', 'button');

for (const id of [
  'relUploadedPath', 'relAbiVariant', 'relSignatureVerified', 'relSignatureStatus',
  'relSignerSha256', 'relSignerDn', 'relVersionName', 'relVersionCode',
  'relMinRequiredVersion', 'relDbSchema', 'relType', 'relSizeMb',
  'relSha256', 'relDownloadUrl', 'badgeRelVariantDisplay', 'relTypeInfoText',
  'activeCreateApkCard', 'apkSignatureBanner', 'apkDropZone', 'apkFileInput',
  'apkDropZoneIcon', 'apkDropZoneTitle', 'apkDropZoneSubtitle',
  'apkUploadProgress', 'apkProgressBar', 'apkUploadStatusText',
  'localBuildsGrid', 'localBuildsToolbar', 'inputLocalBuildsFilter',
  'selectLocalBuildsLimit', 'detectApkStatus', 'createSearchDirsPanel',
  'createSearchDirsList', 'btnToggleSearchDirsPanel', 'inputNewApkSearchDir',
  'btnDetectLocalBuild',
]) {
  ensureEl(id, 'input');
}

// Edit release fields & variant container
for (const id of [
  'editRelVersionName', 'editRelVersionDisplay', 'editRelVersionCode',
  'editRelDbSchema', 'editRelMinRequiredVersion', 'editRelType',
  'editRelDownloadUrl', 'editRelTypeInfoText', 'editRelVariantsContainer',
  'editRelUniversalInput', 'editRelArm64Input', 'btnSubmitEditRelease',
  'editSearchDirsPanel', 'editSearchDirsList', 'inputEditNewApkSearchDir',
  'btnEditBrowseApkSearchDir', 'btnEditAddApkSearchDir',
  'btnEditResetApkSearchDirs', 'btnCloseEditSearchDirsPanel',
  'waVariantCardUniversal', 'waVariantCardArm64',
  'waVariantDescUniversal', 'waVariantDescArm64',
  'waApkCopySuccessHint', 'waApkVersionSelect',
]) {
  ensureEl(id, id.includes('Input') ? 'input' : 'div');
}

const confirmQueue = [];
const fetchCalls = [];
const toasts = [];

let serverReleaseState = {
  version_name: '9.40.0',
  version_code: 84,
  db_schema_version: 36,
  min_required_version: '9.0.0',
  type: 'FEATURE_RELEASE',
  abi_variant: 'UNIVERSAL',
  apk_file_path: 'C:/releases/mochilalista_v9.40_atp.apk',
  file_size_mb: '108.47 MB',
  apk_sha256: '6b54045b3387a323c7dc51303ea9cb6e',
  signature_status: 'OFFICIAL_RELEASE',
  signature_verified: true,
  file_exists: true,
  changelog: 'Linea 1',
  internal_notes: 'Nota previa en textarea',
  universal_apk: {
    file_path: 'C:/releases/mochilalista_v9.40_atp.apk',
    file_size_mb: '108.47 MB',
    sha256: '6b54045b3387a323c7dc51303ea9cb6e',
    signature_status: 'OFFICIAL_RELEASE',
    signature_verified: true,
    file_exists: true,
  },
  arm64_apk: null,
};

let detectLocalBuildsResponse = { apk_found: false, available_builds: [] };
let uploadInspectorResponse = {
  ok: true,
  file_path: 'C:/releases/mochilalista_v9.40_arm64.apk',
  file_name: 'mochilalista_v9.40_arm64.apk',
  size_mb: '30.25 MB',
  abi_variant: 'ARM64',
  sha256: 'arm64sha256hash123456',
  signature_status: 'OFFICIAL_RELEASE',
  signature_verified: true,
  signature_detail: 'RSA-4096 Verified',
  signer_sha256: 'signer123',
  signer_dn: 'CN=Julio',
};

const documentMock = {
  addEventListener: () => {},
  getElementById: (id) => elements[id] || null,
  querySelector: (sel) => {
    const m = /^\\.btn-toggle-textarea\\[data-target="([^"]+)"\\]\$/.exec(sel);
    if (m) return toggleBtns.find(b => b.dataset.target === m[1]) || null;
    return null;
  },
  querySelectorAll: (sel) => {
    if (sel === '.btn-toggle-textarea') return toggleBtns;
    if (sel === '#localBuildsAbiChips .local-abi-chip') return [];
    if (sel === '.modal-overlay.open') {
      return ['modalCreateRelease', 'modalEditRelease', 'modalWaComposer']
        .map(id => elements[id])
        .filter(m => m.classList.contains('open'));
    }
    return [];
  },
  createElement: (tag) => makeEl('dyn_' + Math.random().toString(36).slice(2), tag),
};

const sandbox = {
  console,
  setTimeout,
  clearTimeout,
  URLSearchParams,
  encodeURIComponent,
  decodeURIComponent,
  document: documentMock,
  window: {},
  navigator: {},
  localStorage: { getItem: () => null, setItem: () => {} },
  sessionStorage: { getItem: () => null, setItem: () => {} },
  fetch: async (url, opts = {}) => {
    const method = (opts.method || 'GET').toUpperCase();
    const body = opts.body && typeof opts.body === 'string' ? JSON.parse(opts.body) : null;
    fetchCalls.push({ method, url, body });

    if (url.startsWith('/api/releases/9.40.0/companion-notes')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({
          suggested_changelog: 'Changelog ATP comercial',
          suggested_internal_notes: 'FICHA ATP 9.40.0\\nCommit: abc123',
        }),
      };
    }
    if (url.startsWith('/api/releases/detect-local-build')) {
      return { ok: true, status: 200, json: async () => detectLocalBuildsResponse };
    }
    if (url.startsWith('/api/releases/search-dirs')) {
      return { ok: true, status: 200, json: async () => ({ ok: true, search_dirs: [] }) };
    }
    if (url.startsWith('/api/releases/upload-apk')) {
      return { ok: true, status: 200, json: async () => uploadInspectorResponse };
    }
    if (url.startsWith('/api/releases/import-local-apk')) {
      return { ok: true, status: 200, json: async () => uploadInspectorResponse };
    }
    if (url === '/api/releases/9.40.0' && method === 'PUT') {
      if ('arm64_apk' in body) {
        serverReleaseState = { ...serverReleaseState, arm64_apk: body.arm64_apk };
      }
      if ('universal_apk' in body) {
        serverReleaseState = { ...serverReleaseState, universal_apk: body.universal_apk };
      }
      if ('changelog' in body) {
        serverReleaseState = { ...serverReleaseState, changelog: body.changelog };
      }
      if ('internal_notes' in body) {
        serverReleaseState = { ...serverReleaseState, internal_notes: body.internal_notes };
      }
      return { ok: true, status: 200, json: async () => serverReleaseState };
    }
    if (url === '/api/releases') {
      return { ok: true, status: 200, json: async () => [serverReleaseState] };
    }
    return { ok: true, status: 200, json: async () => ({ ok: true }) };
  },
};
sandbox.window = sandbox;

vm.createContext(sandbox);
vm.runInContext(
  code +
  '\\nfunction __setTestGlobals(o) { if ("globalReleases" in o) globalReleases = o.globalReleases; if ("isApkDispatchMode" in o) isApkDispatchMode = o.isApkDispatchMode; if ("currentDispatchRelease" in o) currentDispatchRelease = o.currentDispatchRelease; }' +
  '\\nfunction __getTestGlobals() { return { globalReleases, isApkDispatchMode, currentDispatchRelease }; }',
  sandbox
);

// Stub UI globals no ligados al DOM real del navegador
sandbox.showToast = (msg, type = 'info') => toasts.push({ msg, type });
sandbox.loadReleases = async () => { sandbox.__setTestGlobals({ globalReleases: [serverReleaseState] }); };
sandbox.loadReleaseMatrix = async () => {};
sandbox.populateWaApkVersionSelect = () => {};
sandbox.showConfirmModal = (title, msg, onConfirm) => {
  confirmQueue.push({ title, msg, onConfirm });
};

sandbox.initReleaseUploadAndAutoDetect();
sandbox.__setTestGlobals({ globalReleases: [serverReleaseState] });

async function runTests() {
  // ---- SUITE A: Pilar 4 Textareas Expandables, Contadores & Fix #btnEditLoadAtpTxt ----
  assert.strictEqual(elements.relChangelogCounter.textContent, '0 lín. · 0 car.');
  assert.strictEqual(elements.relInternalNotesCounter.textContent, '0 lín. · 0 car.');

  // Expandir solo relChangelog
  const btnRelChangelog = toggleBtns.find(b => b.dataset.target === 'relChangelog');
  const btnRelNotes = toggleBtns.find(b => b.dataset.target === 'relInternalNotes');
  btnRelChangelog.click();
  assert.strictEqual(elements.relChangelog.classList.contains('is-expanded'), true);
  assert.strictEqual(btnRelChangelog.getAttribute('aria-expanded'), 'true');
  assert.strictEqual(btnRelChangelog._labelEl.textContent, 'Contraer');
  // relInternalNotes permanece compacto e independiente
  assert.strictEqual(elements.relInternalNotes.classList.contains('is-expanded'), false);
  assert.strictEqual(btnRelNotes.getAttribute('aria-expanded'), 'false');

  // Escribir 3 líneas en relChangelog y contraer: preserva texto y actualiza contador
  elements.relChangelog.value = 'Linea 1\\nLinea 2\\nLinea 3';
  elements.relChangelog.dispatchEvent({ type: 'input', target: elements.relChangelog });
  assert.strictEqual(elements.relChangelogCounter.textContent, '3 lín. · 23 car.');
  elements.relChangelog.style.height = '320px';
  btnRelChangelog.click();
  assert.strictEqual(elements.relChangelog.classList.contains('is-expanded'), false);
  assert.strictEqual(elements.relChangelog.style.height, '');
  assert.strictEqual(elements.relChangelog.value, 'Linea 1\\nLinea 2\\nLinea 3');

  // Cerrar/limpiar Create Modal colapsa ambos y resetea contadores a 0
  btnRelChangelog.click();
  sandbox.closeModal('modalCreateRelease');
  assert.strictEqual(elements.relChangelog.classList.contains('is-expanded'), false);
  assert.strictEqual(elements.relChangelog.value, '');
  assert.strictEqual(elements.relChangelogCounter.textContent, '0 lín. · 0 car.');

  // Abrir Modal Edit con textos multilinea -> contadores exactos y estado inicial compacto
  serverReleaseState.changelog = 'Cambio A\\nCambio B';
  serverReleaseState.internal_notes = 'Solo nota previa';
  sandbox.openEditReleaseModal('9.40.0');
  assert.strictEqual(elements.editRelChangelog.classList.contains('is-expanded'), false);
  assert.strictEqual(elements.editRelChangelogCounter.textContent, '2 lín. · 17 car.');
  assert.strictEqual(elements.editRelInternalNotesCounter.textContent, '1 lín. · 16 car.');

  // Expandir editRelInternalNotes no expande editRelChangelog
  const btnEditNotes = toggleBtns.find(b => b.dataset.target === 'editRelInternalNotes');
  btnEditNotes.click();
  assert.strictEqual(elements.editRelInternalNotes.classList.contains('is-expanded'), true);
  assert.strictEqual(elements.editRelChangelog.classList.contains('is-expanded'), false);

  // Fix oculto #btnEditLoadAtpTxt: debe usar editRelVersionName ('9.40.0') y NO editRelInternalNotes ('Solo nota previa')
  fetchCalls.length = 0;
  await elements.btnEditLoadAtpTxt.click();
  await new Promise(r => setTimeout(r, 20));
  const atpCall = fetchCalls.find(c => c.url.includes('/companion-notes'));
  assert.ok(atpCall, 'Debe consultar /companion-notes');
  assert.ok(atpCall.url.includes('/api/releases/9.40.0/companion-notes'), 'Debe consultar versión real 9.40.0, url=' + atpCall.url);
  assert.strictEqual(elements.editRelInternalNotes.value, 'FICHA ATP 9.40.0\\nCommit: abc123');
  assert.strictEqual(elements.editRelInternalNotesCounter.textContent, '2 lín. · 31 car.');

  // Cerrar modalEditRelease colapsa expandables y oculta editSearchDirsPanel
  elements.editSearchDirsPanel.style.display = 'flex';
  sandbox.closeModal('modalEditRelease');
  assert.strictEqual(elements.editRelInternalNotes.classList.contains('is-expanded'), false);
  assert.strictEqual(elements.editSearchDirsPanel.style.display, 'none');

  // ---- SUITE B: Tarjetas de Variantes (3 estados honestos) ----
  const htmlState1 = sandbox.buildEditVariantCardHtml(
    serverReleaseState, 'arm64', 'ARM64 Ligero (~30 MB)', 'badge-arm64', null, { canUnlink: false }
  );
  assert.ok(htmlState1.includes('Sin archivo adjunto'));
  assert.ok(htmlState1.includes('No adjuntado (Opcional)'));
  assert.ok(!htmlState1.includes('Archivo extraviado en disco'));
  assert.ok(!htmlState1.includes('No encontrado'));
  assert.ok(!htmlState1.includes('Sin Verificar'));
  assert.ok(!htmlState1.includes('Re-verificar'));

  // Universal único válido no permite Desvincular
  const canUnlinkUnivOnly = sandbox.canUnlinkEditVariantSlot(serverReleaseState, 'universal');
  assert.strictEqual(canUnlinkUnivOnly.allowed, false);
  const htmlUnivSafe = sandbox.buildEditVariantCardHtml(
    serverReleaseState, 'universal', 'Universal (~110 MB)', 'badge-universal', serverReleaseState.universal_apk, { canUnlink: canUnlinkUnivOnly.allowed }
  );
  assert.ok(!htmlUnivSafe.includes('Desvincular'));

  // Archivo extraviado en disco (file_exists === false): conserva 'No encontrado' en detalle, muestra badge rojo y permite Desvincular
  const brokenRel = {
    ...serverReleaseState,
    universal_apk: { ...serverReleaseState.universal_apk, file_exists: false },
  };
  const canUnlinkBroken = sandbox.canUnlinkEditVariantSlot(brokenRel, 'universal');
  assert.strictEqual(canUnlinkBroken.allowed, true);
  const htmlMissing = sandbox.buildEditVariantCardHtml(
    brokenRel, 'universal', 'Universal (~110 MB)', 'badge-universal', brokenRel.universal_apk, { canUnlink: canUnlinkBroken.allowed }
  );
  assert.ok(htmlMissing.includes('Archivo extraviado en disco'));
  assert.ok(htmlMissing.includes('No encontrado'));
  assert.ok(htmlMissing.includes('Re-verificar'));
  assert.ok(htmlMissing.includes('Desvincular'));

  // ---- SUITE C: Bloqueo estricto ABI, picker filtrado, Desvincular y Sync WhatsApp Composer ----
  assert.strictEqual(sandbox.validateApkAbiForVariantSlot('UNIVERSAL', 'arm64').ok, false);
  assert.strictEqual(sandbox.validateApkAbiForVariantSlot('ARM64', 'universal').ok, false);
  assert.strictEqual(sandbox.validateApkAbiForVariantSlot('ARM64', 'arm64').ok, true);
  assert.strictEqual(sandbox.validateApkAbiForVariantSlot('UNIVERSAL', 'universal').ok, true);

  // Picker ARM64 vacío -> solicita ?abi=ARM64, deshabilita Vincular y muestra guía compilar_apk_arm64.bat
  elements['editVariantLocalPicker_arm64'] = ensureEl('editVariantLocalPicker_arm64');
  elements['editVariantLocalPicker_arm64'].style.display = 'none';
  elements['editVariantLocalStatus_arm64'] = ensureEl('editVariantLocalStatus_arm64');
  elements['editVariantLocalSelect_arm64'] = ensureEl('editVariantLocalSelect_arm64', 'select');
  elements['btnLinkLocalBuild_arm64'] = ensureEl('btnLinkLocalBuild_arm64', 'button');
  elements['editVariantLocalEmptyHint_arm64'] = ensureEl('editVariantLocalEmptyHint_arm64');

  fetchCalls.length = 0;
  detectLocalBuildsResponse = { apk_found: false, available_builds: [] };
  await sandbox.toggleEditVariantLocalPicker('arm64', '9.40.0');
  const detectCall = fetchCalls.find(c => c.url.includes('/api/releases/detect-local-build'));
  assert.ok(detectCall && detectCall.url.includes('abi=ARM64'));
  assert.strictEqual(elements['btnLinkLocalBuild_arm64'].disabled, true);
  assert.ok(elements['editVariantLocalEmptyHint_arm64'].textContent.includes('compilar_apk_arm64.bat'));

  // Bloqueo hard en subida PC si el archivo subido es UNIVERSAL hacia la tarjeta ARM64
  fetchCalls.length = 0;
  uploadInspectorResponse = {
    ok: true,
    file_path: 'C:/releases/wrong_universal.apk',
    file_name: 'wrong_universal.apk',
    size_mb: '108.00 MB',
    abi_variant: 'UNIVERSAL',
    sha256: 'badsha',
    signature_status: 'OFFICIAL_RELEASE',
    signature_verified: true,
  };
  await sandbox.handleVariantFileSelected({ name: 'wrong_universal.apk' }, 'arm64', '9.40.0');
  assert.strictEqual(
    fetchCalls.some(c => c.method === 'PUT' && c.url.includes('/api/releases/9.40.0')),
    false,
    'No debe mutar el release si la ABI es incompatible'
  );
  assert.ok(toasts[toasts.length - 1].msg.includes('Arquitectura incompatible'));

  // Abrir composer WhatsApp y luego subir ARM64 válido -> sincroniza al instante
  sandbox.openEditReleaseModal('9.40.0');
  elements.modalWaComposer.classList.add('open');
  sandbox.__setTestGlobals({
    isApkDispatchMode: true,
    currentDispatchRelease: serverReleaseState,
  });

  uploadInspectorResponse = {
    ok: true,
    file_path: 'C:/releases/mochilalista_v9.40_arm64.apk',
    file_name: 'mochilalista_v9.40_arm64.apk',
    size_mb: '30.25 MB',
    abi_variant: 'ARM64',
    sha256: 'goodarm64sha',
    signature_status: 'OFFICIAL_RELEASE',
    signature_verified: true,
  };
  await sandbox.handleVariantFileSelected({ name: 'mochilalista_v9.40_arm64.apk' }, 'arm64', '9.40.0');
  assert.ok(serverReleaseState.arm64_apk !== null);
  assert.strictEqual(elements.waVariantCardArm64.classList.contains('disabled'), false);
  assert.ok(elements.waVariantDescArm64.textContent.includes('30.25 MB'));

  // Estando ARM64 y Universal sanos, ambos permiten Desvincular; al desvincular ARM64 se sincroniza modal y WA Composer
  assert.strictEqual(sandbox.canUnlinkEditVariantSlot(serverReleaseState, 'universal').allowed, true);
  assert.strictEqual(sandbox.canUnlinkEditVariantSlot(serverReleaseState, 'arm64').allowed, true);

  confirmQueue.length = 0;
  sandbox.unlinkReleaseVariant('9.40.0', 'arm64');
  assert.strictEqual(confirmQueue.length, 1);
  await confirmQueue[0].onConfirm();
  assert.strictEqual(serverReleaseState.arm64_apk, null);
  assert.strictEqual(elements.waVariantCardArm64.classList.contains('disabled'), true);
  assert.ok(elements.editRelVariantsContainer.innerHTML.includes('No adjuntado (Opcional)'));

  // Controles de Rutas y Cerrar en el selector local de #modalEditRelease
  await sandbox.openEditSearchDirsPanel();
  assert.strictEqual(elements.editSearchDirsPanel.style.display, 'flex');
  sandbox.closeEditVariantLocalPicker('arm64');
  assert.strictEqual(elements['editVariantLocalPicker_arm64'].style.display, 'none');

  // Sincronización de cambio de changelog hacia #modalWaComposer (currentDispatchRelease)
  const updatedChangelogRel = {
    ...serverReleaseState,
    changelog: 'Changelog Editado en Modal',
  };
  await sandbox.syncReleaseAcrossUiAndComposer('9.40.0', updatedChangelogRel, { forceSyncWaComposer: true });
  assert.strictEqual(sandbox.__getTestGlobals().currentDispatchRelease.changelog, 'Changelog Editado en Modal');

  console.log('NODE_PHASE3_OK');
}

runTests().catch(err => {
  console.error(err);
  process.exit(1);
});
''';

      final tempDir = Directory.systemTemp.createTempSync('ml_plan22_5_fase3_node_');
      try {
        final scriptFile = File('${tempDir.path}/verify_phase3.js');
        scriptFile.writeAsStringSync(script);
        final res = await Process.run('node', [scriptFile.path]);
        expect(res.exitCode, equals(0), reason: 'stderr:\n${res.stderr}\nstdout:\n${res.stdout}');
        expect(res.stdout.toString(), contains('NODE_PHASE3_OK'));
      } finally {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    },
  );

  group('3. Aislamiento en systemTemp: Contrato backend Desvincular (null) y Filtro estricto ABI', () {
    late Directory tempRoot;
    late Directory configDir;
    late Directory backupsDir;
    late Directory libDir;
    late Directory buildDir;
    late String releasesDir;
    late ConfigService cfg;
    late DatabaseService db;
    late ApkInspectorService inspector;

    setUp(() async {
      tempRoot = Directory.systemTemp.createTempSync('ml_plan22_5_fase3_backend_');
      configDir = Directory('${tempRoot.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempRoot.path}/backups')..createSync(recursive: true);
      libDir = Directory('${tempRoot.path}/library')..createSync(recursive: true);
      buildDir = Directory('${tempRoot.path}/build')..createSync(recursive: true);
      releasesDir = '${tempRoot.path}/releases_apks';

      cfg = ConfigService(
        dataDirectory: configDir,
        backupsDirectory: backupsDir,
      );
      await cfg.init();
      await cfg.saveConfig({
        'system': {'apk_library_dir': libDir.path},
      });

      db = DatabaseService(
        dataDir: configDir.path,
        backupDir: backupsDir.path,
        releasesDir: releasesDir,
      );
      await db.init();

      inspector = ApkInspectorService(
        sdkSearchRootsOverride: const [],
        defaultBuildOutputDir: buildDir,
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('Desvincular arm64_apk con null preserva universal_apk y detectLocalApksWithStats filtra ABI estricto', () async {
      final univPath = '${libDir.path}/mochilalista_v9.40_atp.apk';
      final arm64Path = '${libDir.path}/mochilalista_v9.40_arm64.apk';
      _createFakeApkZip(univPath, includeArm64: true, includeArmV7: true);
      _createFakeApkZip(arm64Path, includeArm64: true, includeArmV7: false);

      await db.createRelease({
        'version_name': '9.40.0',
        'version_code': 84,
        'db_schema_version': 36,
        'min_required_version': '9.0.0',
        'type': 'FEATURE_RELEASE',
        'abi_variant': 'UNIVERSAL',
        'apk_file_path': univPath,
        'file_size_mb': '108.47 MB',
        'universal_apk': {
          'file_path': univPath,
          'file_size_mb': '108.47 MB',
          'sha256': 'univsha',
          'file_exists': true,
        },
        'arm64_apk': {
          'file_path': arm64Path,
          'file_size_mb': '30.25 MB',
          'sha256': 'arm64sha',
          'file_exists': true,
        },
      });

      final afterUnlink = await db.updateRelease('9.40.0', {'arm64_apk': null});
      expect(afterUnlink, isNotNull);
      expect(afterUnlink!.containsKey('arm64_apk'), isFalse);
      expect(afterUnlink['universal_apk'], isNotNull);
      expect(afterUnlink['apk_file_path'], equals(univPath));

      final searchDirs = cfg.getEffectiveApkSearchDirs(defaultBuildOutputDir: buildDir.path);
      final arm64Report = await inspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: searchDirs,
        limit: 24,
        abiFilter: 'ARM64',
      );
      expect(arm64Report.results, isNotEmpty);
      expect(arm64Report.results.every((b) => b.abiVariant == 'ARM64'), isTrue);

      final univReport = await inspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: searchDirs,
        limit: 24,
        abiFilter: 'UNIVERSAL',
      );
      expect(univReport.results, isNotEmpty);
      expect(univReport.results.every((b) => b.abiVariant == 'UNIVERSAL'), isTrue);
    });
  });
}
