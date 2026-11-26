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
import '../server.dart';
import 'apk_inspector_and_releases_test.dart' show createTestZip;
import 'support/web_bundle_loader.dart';

void main() {
  group(
      'PLAN MAESTRO 22.5 - FASE 2: Limpieza Determinista, APK Activo, Animaciones y Rutas en #modalCreateRelease',
      () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p22_5_fase2_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. HTML y CSS: Elementos de Pilar 1/2/3, temas oscuro/claro, SVGs y cero emojis
    // =========================================================================
    test(
        '1. HTML & CSS: controles Fase 2, soporte [data-theme="light"], SVGs acotados y cero emojis crudos',
        () {
      final html = WebBundleLoader.loadHtml();
      final css = WebBundleLoader.loadCss();

      // Controles HTML obligatorios de Fase 2
      final requiredHtmlIds = [
        'id="activeCreateApkCard"',
        'id="localBuildsToolbar"',
        'id="localBuildsAbiChips"',
        'id="inputLocalBuildsFilter"',
        'id="selectLocalBuildsLimit"',
        'id="btnToggleSearchDirsPanel"',
        'id="createSearchDirsPanel"',
        'id="createSearchDirsList"',
        'id="inputNewApkSearchDir"',
        'id="btnBrowseApkSearchDir"',
        'id="btnAddApkSearchDir"',
        'id="btnResetApkSearchDirs"',
      ];
      for (final marker in requiredHtmlIds) {
        expect(html, contains(marker), reason: 'Falta $marker en index.html');
      }

      // Clases y animaciones CSS obligatorias (oscuro + claro)
      final requiredCssMarkers = [
        '.apk-drop-zone.has-manual-apk',
        '[data-theme="light"] .apk-drop-zone.has-manual-apk',
        '@keyframes activeApkCardReveal',
        '.active-apk-card',
        '.active-apk-card.visible',
        '.badge-source-manual',
        '.badge-source-autodetect',
        '[data-theme="light"] .badge-source-manual',
        '[data-theme="light"] .badge-source-autodetect',
        '@keyframes activeApkPulse',
        '.local-build-card.is-selected',
        '[data-theme="light"] .local-build-card.is-selected',
        '.local-build-card.is-dimmed',
        '.local-build-selected-pill',
        '.btn-selected-apk',
        '.local-builds-toolbar',
        '.search-dirs-panel',
        '.badge-dir-exists',
        '.badge-dir-missing',
        '[data-theme="light"] .badge-dir-exists',
        '[data-theme="light"] .badge-dir-missing',
      ];
      for (final marker in requiredCssMarkers) {
        expect(css, contains(marker), reason: 'Falta $marker en styles.css');
      }

      // SVGs acotados y cero emojis en #modalCreateRelease
      final createStart = html.indexOf('id="modalCreateRelease"');
      final editStart = html.indexOf('id="modalEditRelease"');
      expect(createStart, greaterThan(0));
      expect(editStart, greaterThan(createStart));
      final createModalHtml = html.substring(createStart, editStart);

      final svgRegex = RegExp(r'<svg\b[^>]*>');
      for (final m in svgRegex.allMatches(createModalHtml)) {
        final tag = m.group(0)!;
        final hasBounds = tag.contains('width=') ||
            tag.contains('width:') ||
            tag.contains('icon-svg') ||
            tag.contains('btn-icon') ||
            tag.contains('search-icon');
        expect(hasBounds, isTrue,
            reason: 'SVG sin dimensiones explícitas en #modalCreateRelease: $tag');
      }

      const bannedEmojis = [
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
        '✓'
      ];
      for (final emoji in bannedEmojis) {
        expect(createModalHtml, isNot(contains(emoji)),
            reason: 'Emoji crudo $emoji detectado en #modalCreateRelease');
      }
    });

    // =========================================================================
    // 2. Node.js Ejecución Real sobre web/js/admin_app.js:
    //    resetCreateReleaseModalState, exclusión mutua manual/autodetect,
    //    clearSelectedCreateApk y saveOwnerConfig preservando apk_search_dirs
    // =========================================================================
    test(
        '2. JS Real (Node.js): resetCreateReleaseModalState, exclusión mutua manual/autodetect, clearSelectedCreateApk y saveOwnerConfig',
        () async {
      final jsPath = WebBundleLoader.writeConcatenatedJsTo(
        tempDir,
        filename: 'admin_bundle_p22_5_fase2.js',
      ).path;
      final testScriptFile = File('${tempDir.path}/run_js_fase2_test.js');
      await testScriptFile.writeAsString(r'''
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const jsCode = fs.readFileSync(process.argv[2], 'utf8');

class FakeClassList {
  constructor(el) {
    this.el = el;
    this.set = new Set();
  }
  _syncFromClassName(str) {
    this.set = new Set(String(str || '').split(/\s+/).filter(Boolean));
  }
  _syncToClassName() {
    this.el._className = Array.from(this.set).join(' ');
  }
  add(...names) {
    names.forEach(n => this.set.add(n));
    this._syncToClassName();
  }
  remove(...names) {
    names.forEach(n => this.set.delete(n));
    this._syncToClassName();
  }
  toggle(name, force) {
    if (force === true) this.set.add(name);
    else if (force === false) this.set.delete(name);
    else if (this.set.has(name)) this.set.delete(name);
    else this.set.add(name);
    this._syncToClassName();
  }
  contains(name) {
    return this.set.has(name);
  }
}

class FakeElement {
  constructor(id = '', tag = 'div') {
    this.id = id;
    this.tagName = tag.toUpperCase();
    this._className = '';
    this.classList = new FakeClassList(this);
    this.style = { display: '', width: '' };
    this.dataset = {};
    this._value = '';
    this.defaultValue = '';
    this.textContent = '';
    this._innerHTML = '';
    this.children = [];
    this.listeners = {};
    this.disabled = false;
    this.checked = false;
    this.files = [];
  }
  get className() { return this._className; }
  set className(v) {
    this._className = String(v || '');
    this.classList._syncFromClassName(this._className);
  }
  get value() { return this._value; }
  set value(v) { this._value = v === undefined || v === null ? '' : String(v); }
  get innerHTML() { return this._innerHTML; }
  set innerHTML(v) {
    this._innerHTML = String(v || '');
    if (this._innerHTML === '') this.children = [];
  }
  appendChild(child) {
    this.children.push(child);
    return child;
  }
  addEventListener(evt, fn) {
    this.listeners[evt] = this.listeners[evt] || [];
    this.listeners[evt].push(fn);
  }
  async trigger(evt, eventObj = {}) {
    const list = this.listeners[evt] || [];
    for (const fn of list) {
      await fn({ target: this, preventDefault: () => {}, ...eventObj });
    }
  }
  reset() {
    // Simular form.reset(): solo restaura inputs con defaultValue conocido, igual que el navegador
    this.children.forEach(c => { c.value = c.defaultValue || ''; });
  }
  focus() {}
  querySelector(sel) {
    const cls = sel.startsWith('.') ? sel.slice(1) : null;
    if (!cls) return null;
    if (this.classList.contains(cls)) return this;
    for (const ch of this.children) {
      if (ch.classList && ch.classList.contains(cls)) return ch;
      const nested = ch.querySelector && ch.querySelector(sel);
      if (nested) return nested;
    }
    if (this._innerHTML && this._innerHTML.includes(cls)) {
      const dummy = new FakeElement('', 'span');
      dummy.className = cls;
      return dummy;
    }
    return null;
  }
  querySelectorAll(sel) {
    if (sel === '.local-build-card') {
      return this.children.filter(c => c.classList.contains('local-build-card'));
    }
    if (sel === '.btn-import-local-build') {
      const found = [];
      this.children.forEach(c => {
        c.children.forEach(gc => {
          if (gc.classList.contains('btn-import-local-build')) found.push(gc);
        });
      });
      return found;
    }
    return [];
  }
}

const domMap = new Map();
function ensureEl(id, tag = 'div', defaultValue = '') {
  if (!domMap.has(id)) {
    const el = new FakeElement(id, tag);
    el.defaultValue = defaultValue;
    el.value = defaultValue;
    domMap.set(id, el);
  }
  return domMap.get(id);
}

// Registrar IDs clave de #modalCreateRelease y #tabSettings
[
  ['modalCreateRelease', 'div', ''],
  ['btnOpenCreateRelease', 'button', ''],
  ['btnSubmitCreateRelease', 'button', ''],
  ['apkDropZone', 'div', ''],
  ['apkDropZoneIcon', 'div', ''],
  ['apkDropZoneTitle', 'div', ''],
  ['apkDropZoneSubtitle', 'div', ''],
  ['apkFileInput', 'input', ''],
  ['apkUploadProgress', 'div', ''],
  ['apkProgressBar', 'div', ''],
  ['apkUploadStatusText', 'span', ''],
  ['activeCreateApkCard', 'div', ''],
  ['apkSignatureBanner', 'div', ''],
  ['detectApkStatus', 'p', ''],
  ['localBuildsToolbar', 'div', ''],
  ['inputLocalBuildsFilter', 'input', ''],
  ['selectLocalBuildsLimit', 'select', '6'],
  ['localBuildsGrid', 'div', ''],
  ['btnToggleSearchDirsPanel', 'button', ''],
  ['createSearchDirsPanel', 'div', ''],
  ['createSearchDirsList', 'div', ''],
  ['inputNewApkSearchDir', 'input', ''],
  ['btnBrowseApkSearchDir', 'button', ''],
  ['btnAddApkSearchDir', 'button', ''],
  ['btnResetApkSearchDirs', 'button', ''],
  ['formCreateRelease', 'form', ''],
  ['relUploadedPath', 'input', ''],
  ['relAbiVariant', 'input', 'UNIVERSAL'],
  ['relSignatureVerified', 'input', ''],
  ['relSignatureStatus', 'input', ''],
  ['relSignerSha256', 'input', ''],
  ['relSignerDn', 'input', ''],
  ['relVersionName', 'input', ''],
  ['relVersionCode', 'input', ''],
  ['relMinRequiredVersion', 'input', '9.0.0'],
  ['relDbSchema', 'input', '36'],
  ['relType', 'select', 'FEATURE_RELEASE'],
  ['relTypeInfoText', 'span', ''],
  ['relSizeMb', 'input', ''],
  ['badgeRelVariantDisplay', 'span', ''],
  ['relSha256', 'input', ''],
  ['relDownloadUrl', 'input', ''],
  ['relChangelog', 'textarea', ''],
  ['relInternalNotes', 'textarea', ''],
  ['cfgMigrationFee', 'input', '40'],
  ['cfgLegalOwner', 'input', 'Julio'],
  ['cfgBrandName', 'input', 'MochilaLista'],
  ['cfgSupportPhone', 'input', '+51 922 836 879'],
  ['cfgYapePhone', 'input', '922836879'],
  ['cfgYapeHolder', 'input', 'Julio'],
  ['cfgDefaultEnv', 'select', 'sandbox'],
  ['cfgDefaultTheme', 'select', 'light'],
  ['cfgTableDensity', 'select', 'compact'],
].forEach(([id, tag, def]) => ensureEl(id, tag, def));

const abiChips = ['ALL', 'UNIVERSAL', 'ARM64'].map(abi => {
  const c = new FakeElement('', 'button');
  c.className = abi === 'ALL' ? 'local-abi-chip active' : 'local-abi-chip';
  c.dataset.abi = abi;
  return c;
});

const fetchCalls = [];
async function mockFetch(url, opts = {}) {
  fetchCalls.push({ url, opts });
  if (url.startsWith('/api/releases/upload-apk')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        file_name: 'mochilalista_v9.40_atp.apk',
        file_path: 'releases_apks/sandbox/mochilalista_v9.40_atp.apk',
        version_name: '9.40.0',
        version_code: 84,
        db_schema_version: 36,
        min_required_version: '9.0.0',
        size_mb: '108.47 MB',
        sha256: '6b54045b3387a323c7dc51303ea9cb6e49e8442e0c06655265c9d73e53b86e2c',
        abi_variant: 'UNIVERSAL',
        signature_status: 'OFFICIAL_RELEASE',
        signature_verified: true,
        signer_sha256: '7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20',
        signer_dn: 'CN=Julio Angello Vasquez Navarro',
        suggested_changelog: 'Novedades manuales 9.40',
        suggested_internal_notes: 'Notas técnicas 9.40',
        suggested_release_type: 'FEATURE_RELEASE',
      }),
    };
  }
  if (url === '/api/releases/import-local-apk') {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        imported_path: 'releases_apks/sandbox/mochilalista_v9.39_atp.apk',
        file_name: 'mochilalista_v9.39_atp.apk',
        file_path: 'C:\\Builds\\mochilalista_v9.39_atp.apk',
        version_name: '9.39.0',
        version_code: 83,
        db_schema_version: 36,
        min_required_version: '9.0.0',
        size_mb: '108.20 MB',
        sha256: '67e7fceb66c0aaaa0000',
        abi_variant: 'UNIVERSAL',
        signature_status: 'OFFICIAL_RELEASE',
        signature_verified: true,
        suggested_release_type: 'FEATURE_RELEASE',
      }),
    };
  }
  if (url === '/api/releases' && opts.method === 'POST') {
    return { ok: true, status: 201, json: async () => ({ ok: true }) };
  }
  if (url === '/api/config' && opts.method === 'PUT') {
    const sent = JSON.parse(opts.body);
    return { ok: true, status: 200, json: async () => sent };
  }
  return { ok: true, status: 200, json: async () => ({}) };
}

const domListeners = {};
const sandbox = {
  console,
  setTimeout,
  clearTimeout,
  URLSearchParams,
  sessionStorage: { getItem: () => null, setItem: () => {} },
  navigator: {},
  window: { fetch: mockFetch, open: () => {} },
  fetch: mockFetch,
  document: {
    getElementById: (id) => domMap.get(id) || null,
    createElement: (tag) => new FakeElement('', tag),
    addEventListener: (evt, fn) => {
      domListeners[evt] = domListeners[evt] || [];
      domListeners[evt].push(fn);
    },
    querySelector: () => null,
    querySelectorAll: (sel) => {
      if (sel === '#localBuildsAbiChips .local-abi-chip') return abiChips;
      if (sel === '.modal-overlay.open') {
        const m = domMap.get('modalCreateRelease');
        return m && m.classList.contains('open') ? [m] : [];
      }
      return [];
    },
  },
};

const ctx = vm.createContext(sandbox);
vm.runInContext(jsCode, ctx);

vm.runInContext(`(async () => {
  const assert = require('assert');
  // Stub helpers UI no-relacionados para aislar el módulo de Fase 2
  showToast = () => {};
  loadReleases = async () => {};
  loadReleaseMatrix = async () => {};
  loadDashboard = async () => {};
  populateSettingsForm = () => {};
  applyConfigToUi = () => {};

  initReleaseUploadAndAutoDetect();
  initModalEvents();

  // 1. Renderizar 2 tarjetas autodetectadas
  availableLocalBuilds = [
    {
      file_name: 'mochilalista_v9.40_atp.apk',
      file_path: 'C:\\\\Builds\\\\mochilalista_v9.40_atp.apk',
      version_name: '9.40.0',
      version_code: 84,
      abi_variant: 'UNIVERSAL',
      size_mb: '108.47 MB',
      sha256: '6b54045b3387',
      signature_status: 'OFFICIAL_RELEASE',
      signature_verified: true,
      source_label: 'Biblioteca Oficial',
      duplicate_paths: [],
    },
    {
      file_name: 'mochilalista_v9.39_atp.apk',
      file_path: 'C:\\\\Builds\\\\mochilalista_v9.39_atp.apk',
      version_name: '9.39.0',
      version_code: 83,
      abi_variant: 'UNIVERSAL',
      size_mb: '108.20 MB',
      sha256: '67e7fceb66c0',
      signature_status: 'OFFICIAL_RELEASE',
      signature_verified: true,
      source_label: 'Carpeta Custom',
      duplicate_paths: [],
    },
  ];
  renderLocalBuildsGrid(availableLocalBuilds);

  // 2. Simular subida manual -> dropzone .has-manual-apk + tarjeta activa "Subido manualmente desde PC"
  await handleApkUpload({ name: 'mochilalista_v9.40_atp.apk', size: 113737958 });
  assert.strictEqual(activeCreateApkSource, 'manual');
  assert.ok(document.getElementById('apkDropZone').classList.contains('has-manual-apk'));
  assert.strictEqual(document.getElementById('apkProgressBar').style.width, '100%');
  assert.strictEqual(document.getElementById('activeCreateApkCard').style.display, 'flex');
  assert.ok(document.getElementById('activeCreateApkCard').innerHTML.includes('Subido manualmente desde PC'));
  assert.strictEqual(document.getElementById('localBuildsGrid').children[0].classList.contains('is-selected'), false);

  // 3. Seleccionar tarjeta autodetectada -> limpia dropzone manual y marca is-selected / is-dimmed
  document.getElementById('apkFileInput').value = 'C:\\\\fakepath\\\\mochilalista_v9.40_atp.apk';
  await importLocalApkDirectly('C:\\\\Builds\\\\mochilalista_v9.39_atp.apk', 1);
  assert.strictEqual(activeCreateApkSource, 'autodetect');
  assert.strictEqual(document.getElementById('apkDropZone').classList.contains('has-manual-apk'), false);
  assert.strictEqual(document.getElementById('apkUploadProgress').style.display, 'none');
  assert.strictEqual(document.getElementById('apkFileInput').value, '');
  assert.ok(document.getElementById('activeCreateApkCard').innerHTML.includes('Seleccionado desde Autodetección'));
  const cards = document.getElementById('localBuildsGrid').children;
  assert.strictEqual(cards[0].classList.contains('is-dimmed'), true);
  assert.strictEqual(cards[1].classList.contains('is-selected'), true);

  // 4. Botón "Cambiar / Quitar APK" (clearSelectedCreateApk) limpia binario sin cerrar modal ni borrar notas
  document.getElementById('modalCreateRelease').classList.add('open');
  document.getElementById('relChangelog').value = 'Texto personalizado del dueño';
  clearSelectedCreateApk();
  assert.strictEqual(activeCreateApkSource, null);
  assert.strictEqual(document.getElementById('activeCreateApkCard').style.display, 'none');
  assert.strictEqual(document.getElementById('relUploadedPath').value, '');
  assert.strictEqual(document.getElementById('relChangelog').value, 'Texto personalizado del dueño');
  assert.strictEqual(document.getElementById('modalCreateRelease').classList.contains('open'), true);
  assert.strictEqual(cards[1].classList.contains('is-selected'), false);

  // 5. Subir de nuevo y publicar -> resetCreateReleaseModalState() limpia 100% barra, texto y estado
  await handleApkUpload({ name: 'mochilalista_v9.40_atp.apk', size: 113737958 });
  assert.strictEqual(document.getElementById('apkUploadProgress').style.display, 'block');
  await document.getElementById('btnSubmitCreateRelease').trigger('click');
  assert.strictEqual(lastInspectedCreateData, null);
  assert.strictEqual(activeCreateApkSource, null);
  assert.strictEqual(document.getElementById('apkUploadProgress').style.display, 'none');
  assert.strictEqual(document.getElementById('apkProgressBar').style.width, '0%');
  assert.strictEqual(document.getElementById('apkFileInput').value, '');
  assert.strictEqual(document.getElementById('apkDropZone').classList.contains('has-manual-apk'), false);
  assert.strictEqual(document.getElementById('activeCreateApkCard').style.display, 'none');
  assert.strictEqual(document.getElementById('apkSignatureBanner').style.display, 'none');
  assert.strictEqual(document.getElementById('localBuildsGrid').style.display, 'none');
  assert.strictEqual(document.getElementById('relUploadedPath').value, '');
  assert.strictEqual(document.getElementById('relVersionName').value, '');

  // 6. Cierre vía closeModal también invoca resetCreateReleaseModalState
  await handleApkUpload({ name: 'mochilalista_v9.40_atp.apk', size: 113737958 });
  document.getElementById('modalCreateRelease').classList.add('open');
  closeModal('modalCreateRelease');
  assert.strictEqual(document.getElementById('apkUploadProgress').style.display, 'none');
  assert.strictEqual(document.getElementById('activeCreateApkCard').style.display, 'none');

  // 7. Fix saveOwnerConfig(): preserva apk_library_dir y apk_search_dirs dentro de system
  ownerConfig = {
    catalog: {},
    templates: {},
    legal_identity: {},
    payment_methods: {},
    system: {
      default_mode: 'sandbox',
      theme: 'dark',
      table_density: 'comfortable',
      version: '1.0.0',
      apk_library_dir: 'D:\\\\MisApksOficiales',
      apk_search_dirs: [
        { path: 'D:\\\\MisApksOficiales', label: 'Oficial', enabled: true, is_default: true, kind: 'official_library' },
        { path: 'E:\\\\ExtraApks', label: 'Extra', enabled: true, is_default: false, kind: 'custom' },
      ],
    },
  };
  await saveOwnerConfig();
  assert.strictEqual(ownerConfig.system.theme, 'light');
  assert.strictEqual(ownerConfig.system.table_density, 'compact');
  assert.strictEqual(ownerConfig.system.apk_library_dir, 'D:\\\\MisApksOficiales');
  assert.strictEqual(ownerConfig.system.apk_search_dirs.length, 2);
  assert.strictEqual(ownerConfig.system.apk_search_dirs[1].path, 'E:\\\\ExtraApks');
  console.log('NODE_FASE2_JS_OK');
})().catch(err => {
  console.error(err);
  process.exit(1);
});`, Object.assign(ctx, { require }));
''');

      final res =
          await Process.run('node', [testScriptFile.path, jsPath]);
      expect(res.exitCode, equals(0),
          reason: 'Error en prueba Node.js Fase 2:\nSTDOUT: ${res.stdout}\nSTDERR: ${res.stderr}');
      expect(res.stdout.toString(), contains('NODE_FASE2_JS_OK'));
    });

    // =========================================================================
    // 3. Integración HTTP rápida en aislamiento: rutas -> detect-local -> import
    // =========================================================================
    test(
        '3. Integración HTTP aislada: flujo PUT /search-dirs -> GET /detect-local-build -> POST /import-local-apk',
        () async {
      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final libDir = Directory('${tempDir.path}/apk_lib')
        ..createSync(recursive: true);
      final customDir = Directory('${tempDir.path}/custom_folder')
        ..createSync(recursive: true);

      final db = DatabaseService(
          dataDir: dataDir.path,
          backupDir: backupsDir.path,
          releasesDir: releasesDir);
      await db.init();
      final config =
          ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await config.init();
      await config.saveConfig({
        'system': {'apk_library_dir': libDir.path},
      });

      final signer = LicenseSigner();
      await signer
          .initWithSeed(List<int>.generate(32, (i) => (i * 13 + 7) % 256));
      final excel = ExcelExportService(dbService: db, configService: config);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dpapiService: MockDpapiService('TEST_P225_F2'),
        dbService: db,
        configService: config,
        signer: signer,
      );
      await vault.initialize();

      final inspector = ApkInspectorService(
        sdkSearchRootsOverride: const [],
        defaultBuildOutputDir:
            Directory('${tempDir.path}/empty_build')..createSync(recursive: true),
        processRunnerOverride: (cmd, args) async =>
            ProcessResult(1, 1, '', 'no tool'),
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
            apkInspectorService: inspector,
            onBrowseFolderOverride: () async => customDir.path,
          ));

      final http = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';
      try {
        final customApk = File('${customDir.path}/mochilalista_v9.41_atp.apk');
        await customApk.writeAsBytes(createTestZip(
            ['AndroidManifest.xml', 'lib/arm64-v8a/a.so', 'lib/armeabi-v7a/a.so']));

        // 1) Registrar carpeta custom vía PUT /search-dirs
        final putReq = await http
            .putUrl(Uri.parse('$baseUrl/api/releases/search-dirs'));
        putReq.headers.contentType = ContentType.json;
        putReq.write(jsonEncode({
          'search_dirs': [
            {
              'path': libDir.path,
              'label': 'Biblioteca',
              'enabled': true,
              'is_default': true,
              'kind': 'official_library',
            },
            {
              'path': customDir.path,
              'label': 'Carpeta Custom',
              'enabled': true,
              'is_default': false,
              'kind': 'custom',
            }
          ]
        }));
        final putRes = await putReq.close();
        expect(putRes.statusCode, equals(200));
        await putRes.drain();

        // 2) Detectar con abi=UNIVERSAL&limit=6
        final detRes = await (await http.getUrl(Uri.parse(
                '$baseUrl/api/releases/detect-local-build?abi=UNIVERSAL&limit=6')))
            .close();
        expect(detRes.statusCode, equals(200));
        final detJson =
            jsonDecode(await utf8.decodeStream(detRes)) as Map<String, dynamic>;
        expect(detJson['apk_found'], isTrue);
        final builds =
            (detJson['available_builds'] as List).cast<Map<String, dynamic>>();
        expect(builds.length, equals(1));
        expect(builds.first['version_name'], equals('9.41.0'));

        // 3) Importar directamente desde la carpeta custom
        final impReq = await http
            .postUrl(Uri.parse('$baseUrl/api/releases/import-local-apk'));
        impReq.headers.contentType = ContentType.json;
        impReq.write(jsonEncode({'source_path': builds.first['file_path']}));
        final impRes = await impReq.close();
        expect(impRes.statusCode, equals(200));
        final impJson =
            jsonDecode(await utf8.decodeStream(impRes)) as Map<String, dynamic>;
        expect(impJson['ok'], isTrue);
        expect(File(impJson['imported_path'] as String).existsSync(), isTrue);
      } finally {
        http.close(force: true);
        await server.close(force: true);
      }
    });
  });
}
