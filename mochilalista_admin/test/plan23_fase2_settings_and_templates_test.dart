import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

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
  final end = source.indexOf(endMarker);
  if (start < 0 || end < 0 || end <= start) {
    throw StateError(
        'No se encontraron marcadores "$startMarker" -> "$endMarker"');
  }
  return source.substring(start, end);
}

void main() {
  group('PLAN MAESTRO 23 - FASE 2: Configuración (#tabSettings), Plantillas, Preferencias y Dirty Guard', () {
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

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_p23_fase2_');
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
          .initWithSeed(List<int>.generate(32, (i) => (i * 19 + 3) % 256));

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
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. ConfigService: updates_window_months=12, descripciones, 9 plantillas canónicas y preservación de rutas APK', () async {
      // 1A. Defaults de catálogo
      expect(configService.getPlanUpdatesMonths('PERPETUO_LIBERADO'), equals(12));
      expect(configService.getPlanUpdatesMonths('PASE_ACTUALIZACION_ANUAL'), equals(12));
      expect(configService.catalog['PERPETUO_LIBERADO']['updates_window_months'], equals(12));
      expect(configService.catalog['PERPETUO_LIBERADO']['updates_months'], equals(12));
      expect(configService.catalog['PASE_ACTUALIZACION_ANUAL']['updates_window_months'], equals(12));

      for (final entry in configService.catalog.entries) {
        final item = entry.value as Map<String, dynamic>;
        expect(
          (item['description'] as String? ?? '').trim(),
          isNotEmpty,
          reason: '${entry.key} debe tener descripción comercial predeterminada',
        );
      }

      // 1B. 9 plantillas canónicas presentes
      for (final key in [
        'license_issued',
        'expiring_reminder',
        'trial_welcome',
        'prospect',
        'ai_bonus',
        'courtesy_extension',
        'apk_update_eligible',
        'apk_update_quote',
        'device_migration',
      ]) {
        expect(
          (configService.templates[key] as String? ?? '').trim(),
          isNotEmpty,
          reason: 'Debe existir plantilla canónica "$key"',
        );
      }

      // 1C. Renderizador acepta alias del compositor WhatsApp y {codigo_licencia}
      final aliasRendered = configService.renderTemplate('welcome', {
        'titular': 'Lucía Torres',
        'negocio': 'Bazar Arcoíris',
        'device_id': 'ML-4455',
        'vencimiento': '2026-12-30',
        'codigo_licencia': 'ML9-TOK-ALIAS-123',
      });
      expect(aliasRendered, contains('Lucía Torres'));
      expect(aliasRendered, contains('Bazar Arcoíris'));
      expect(aliasRendered, contains('ML9-TOK-ALIAS-123'));

      // 1D. Configurar rutas APK custom y luego guardar parcial sin apk_search_dirs -> debe preservarse 100%
      final customApkDir = Directory('${tempDir.path}/custom_apks')
        ..createSync(recursive: true);
      await configService.saveApkSearchDirs([
        {
          'path': customApkDir.path,
          'label': 'Mi Carpeta Custom',
          'enabled': true,
          'is_default': false,
          'kind': 'custom',
        }
      ]);

      final updatedCatalog = Map<String, dynamic>.from(configService.catalog);
      updatedCatalog['PERPETUO_LIBERADO'] = {
        ...Map<String, dynamic>.from(updatedCatalog['PERPETUO_LIBERADO'] as Map),
        'updates_window_months': 24,
        'description': 'Descripción personalizada Perpetua 24m',
      };

      await configService.saveConfig({
        'catalog': updatedCatalog,
        'legal_identity': {
          'author_full_name': 'María Elena Rojas',
          'commercial_name': 'Papelería Sol',
          'support_phone': '+51 988 111 222',
        },
        'system': {
          'default_mode': 'prod',
          'theme': 'light',
          'table_density': 'compact',
        },
      });

      // Bidirectional sync updates_window_months <-> updates_months
      expect(configService.catalog['PERPETUO_LIBERADO']['updates_window_months'], equals(24));
      expect(configService.catalog['PERPETUO_LIBERADO']['updates_months'], equals(24));
      expect(
        configService.catalog['PERPETUO_LIBERADO']['description'],
        equals('Descripción personalizada Perpetua 24m'),
      );

      // Propagación de legal_identity -> receipt_config si no fue personalizado aparte
      expect(configService.receiptConfig['issuer_name'], equals('María Elena Rojas'));
      expect(configService.receiptConfig['commercial_name'], equals('Papelería Sol'));
      expect(configService.receiptConfig['issuer_phone'], equals('+51 988 111 222'));

      // Preservación de apk_search_dirs al guardar sin enviar apk_search_dirs
      final dirsAfter = configService.getEffectiveApkSearchDirs();
      expect(dirsAfter.any((d) => d.path.contains('custom_apks')), isTrue);
    });

    test('2. Reset selectivo por scope (pricing/templates/payment/preferences/all) y startup mode del servidor', () async {
      // Preparar cambios en todas las secciones + ruta APK personalizada
      final customApkDir = Directory('${tempDir.path}/apk_vault_custom')
        ..createSync(recursive: true);
      await configService.saveApkSearchDirs([
        {
          'path': customApkDir.path,
          'label': 'Custom APKs',
          'enabled': true,
          'is_default': false,
          'kind': 'custom',
        }
      ]);

      final modifiedCat = Map<String, dynamic>.from(configService.catalog);
      modifiedCat['MENSUAL'] = {
        ...Map<String, dynamic>.from(modifiedCat['MENSUAL'] as Map),
        'price': 99.0,
      };
      await configService.saveConfig({
        'catalog': modifiedCat,
        'templates': {'license_issued': 'PLANTILLA_CUSTOM_999'},
        'legal_identity': {'author_full_name': 'Titular Custom'},
        'system': {
          'default_mode': 'prod',
          'theme': 'light',
          'table_density': 'compact',
        },
      });

      // Verificar startup helper aplica 'prod' al DatabaseService
      final appliedProd = await applyStartupModeFromConfig(dbService, configService);
      expect(appliedProd, equals('prod'));
      expect(dbService.currentMode, equals('prod'));

      // Reset solo 'pricing' -> MENSUAL vuelve a 35.0, templates y preferences siguen custom
      await configService.resetToDefaults(scope: 'pricing');
      expect(configService.getPlanPrice('MENSUAL'), equals(35.0));
      expect(configService.templates['license_issued'], equals('PLANTILLA_CUSTOM_999'));
      expect(configService.system['default_mode'], equals('prod'));
      expect(configService.system['theme'], equals('light'));

      // Reset solo 'preferences' -> mode/theme/density vuelven a fábrica, templates siguen custom y apk_search_dirs intacto
      await configService.resetToDefaults(scope: 'preferences');
      expect(configService.system['default_mode'], equals('sandbox'));
      expect(configService.system['theme'], equals('dark'));
      expect(configService.system['table_density'], equals('comfortable'));
      expect(configService.templates['license_issued'], equals('PLANTILLA_CUSTOM_999'));
      expect(
        configService.getEffectiveApkSearchDirs().any((d) => d.path.contains('apk_vault_custom')),
        isTrue,
      );

      final appliedSandbox = await applyStartupModeFromConfig(dbService, configService);
      expect(appliedSandbox, equals('sandbox'));
      expect(dbService.currentMode, equals('sandbox'));

      // Prueba HTTP POST /api/config/reset con scope válido e inválido
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            dbService,
            signer,
            configService,
            excelService,
            vaultStorage,
          ));
      final http = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';
      try {
        final badRes = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/reset'),
          body: {'scope': 'invalid_scope_xyz'},
        );
        expect(badRes['status'], equals(400));

        final tplResetRes = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/reset'),
          body: {'scope': 'templates'},
        );
        expect(tplResetRes['status'], equals(200));
        expect(tplResetRes['body']['scope'], equals('templates'));
        expect(configService.templates['license_issued'], isNot(equals('PLANTILLA_CUSTOM_999')));
        expect(configService.legalIdentity['author_full_name'], equals('Titular Custom'));

        final payResetRes = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/reset'),
          body: {'scope': 'payment'},
        );
        expect(payResetRes['status'], equals(200));
        expect(
          configService.legalIdentity['author_full_name'],
          equals('Julio Angello Vasquez Navarro'),
        );
      } finally {
        http.close(force: true);
        await server.close(force: true);
      }
    });

    test('3. Auditoría HTML/CSS: ?v=25, grilla 2x2, 9 plantillas, tooltips, sin reset duplicado ni emojis crudos', () {
      final html = WebBundleLoader.loadHtml();
      final css = WebBundleLoader.loadCss();
      final js = WebBundleLoader.loadJs();

      // Cache bust ?v=25 unificado en hojas CSS modulares y JS
      expect(html, contains('href="css/00_tokens.css?v=25"'));
      expect(html, contains('href="css/99_print.css?v=25"'));
      expect(html, contains('src="js/bootstrap.js?v=25"'));
      expect(html, contains('src="js/modules/settings_core_and_dirty.js?v=25"'));

      // Controles nuevos en cabecera y Tab 2/3/4
      expect(html, contains('id="settingsDirtyBadge"'));
      expect(html, contains('id="btnSaveSettingsTab"'));
      expect(html, contains('id="btnSaveSettings"'));
      expect(html, contains('id="btnResetSettings"'));
      expect(html, isNot(contains('id="btnTriggerResetSettings"')));

      // Tab 2: 9 plantillas + copiar vista previa + guía markdown + tooltips
      for (final val in [
        'value="license_issued"',
        'value="expiring_reminder"',
        'value="trial_welcome"',
        'value="prospect"',
        'value="ai_bonus"',
        'value="courtesy_extension"',
        'value="apk_update_eligible"',
        'value="apk_update_quote"',
        'value="device_migration"',
      ]) {
        expect(html, contains(val));
      }
      expect(html, contains('id="btnCopyWaPreview"'));
      expect(html, contains('class="wa-markdown-guide"'));
      expect(html, contains('id="templateVarTooltipText"'));
      expect(html, contains('title="Nombre del titular o representante del negocio"'));

      // Tab 3: Grilla 2x2 equilibrada
      final paymentSectionHtml = _extractSection(html, 'id="stabPayment"', 'id="stabPreferences"');
      expect(paymentSectionHtml, contains('class="settings-payment-grid"'));
      expect(paymentSectionHtml, isNot(contains('repeat(auto-fit, minmax(320px, 1fr))')));
      expect(css, contains('.settings-payment-grid'));
      expect(css, contains('grid-template-columns: repeat(2, minmax(0, 1fr))'));
      expect(css, contains('@media (max-width: 900px)'));

      // Tab 4: Tarjetas explicativas + resumen de rutas APK + modales Fase 2
      expect(html, contains('class="settings-preferences-grid"'));
      expect(html, contains('id="settingsApkDirsCard"'));
      expect(html, contains('id="settingsApkDirsSummary"'));
      expect(html, contains('id="btnGoToApkSearchDirs"'));
      expect(html, contains('id="modalUnsavedSettings"'));
      expect(html, contains('id="modalResetSettingsScope"'));
      expect(html, contains('id="btnResetScopeCurrentTab"'));
      expect(html, contains('id="btnResetScopeAll"'));

      // Tema claro completo en styles.css
      expect(css, contains('[data-theme="light"] .settings-dirty-pill'));
      expect(css, contains('[data-theme="light"] .settings-subcard'));
      expect(css, contains('[data-theme="light"] .btn-wa-copy-preview'));
      expect(css, contains('.stab-dirty-dot.visible'));

      // Cero emojis crudos prohibidos en UI y en renderCredentialCanvas
      const bannedUiEmojis = ['✅', '⬇️', '📁', '✏️', '🗑️', '📲', 'ℹ️', '🚀', '📦', '📅', '⚡'];
      for (final emoji in bannedUiEmojis) {
        expect(html, isNot(contains(emoji)), reason: 'HTML no debe tener emoji crudo $emoji');
        expect(css, isNot(contains(emoji)), reason: 'CSS no debe tener emoji crudo $emoji');
      }
      final canvasSection = _extractSection(
        js,
        'function renderCredentialCanvas(',
        'function downloadCredential(',
      );
      expect(canvasSection, isNot(contains('📅')));
      expect(canvasSection, isNot(contains('⚡')));

      // Preservar bloque de funciones puras de admin_app.js
      expect(js.indexOf('function formatApkSizeMb('), greaterThan(0));
      expect(
        js.indexOf('function renderSignatureStatusBadge('),
        greaterThan(js.indexOf('function formatApkSizeMb(')),
      );
    });

    test('4. Ejecución JS en Node.js: Borrador multi-plantilla, tarifa de migración en vivo, sincronización WA y Dirty Guard', () async {
      final js = WebBundleLoader.loadJs();
      final canvasSection = _extractSection(
        js,
        'function renderCredentialCanvas(',
        'function downloadCredential(',
      );
      final themeSection = _extractSection(
        js,
        'function initTheme()',
        '// =================== FASE 1: ARQUITECTURA',
      );
      final fmtPlanSection = _extractSection(
        js,
        'const CANONICAL_PLAN_LABELS = {',
        'function normalizePlanToSlug(',
      );
      final waSection = _extractSection(
        js,
        '// =================== 3B. COMPOSITOR UNIVERSAL DE WHATSAPP',
        '// =================== 4. RELEASE MANAGER',
      );
      final settingsSection = _extractSection(
        js,
        '// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL',
        '// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL',
      );

      final harnessFile = File('${tempDir.path}/p23_fase2_settings_test.js');
      await harnessFile.writeAsString('''
const assert = require('assert');
const fs = require('fs');

class MockClassList {
  constructor() { this.set = new Set(); }
  add(...c) { c.forEach(x => this.set.add(x)); }
  remove(...c) { c.forEach(x => this.set.delete(x)); }
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

class MockOption {
  constructor(value, text, attrs = {}) {
    this.value = value;
    this.textContent = text;
    this.attrs = { ...attrs };
  }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k]; }
}

class MockElement {
  constructor(id = '', classes = [], dataset = {}) {
    this.id = id;
    this.classList = new MockClassList();
    classes.forEach(c => this.classList.add(c));
    this.dataset = { ...dataset };
    this.style = {};
    this.value = '';
    this.textContent = '';
    this._innerHTML = '';
    this.options = [];
    this.listeners = {};
    this.selectionStart = 0;
    this.selectionEnd = 0;
    this.attrs = {};
    this.children = [];
  }
  set innerHTML(v) {
    this._innerHTML = String(v);
    if (v === '') this.children = [];
  }
  get innerHTML() { return this._innerHTML; }
  appendChild(ch) { this.children.push(ch); return ch; }
  addEventListener(evt, fn) {
    this.listeners[evt] = this.listeners[evt] || [];
    this.listeners[evt].push(fn);
  }
  dispatch(evt, targetEl = this) {
    (this.listeners[evt] || []).forEach(fn => fn({ target: targetEl }));
  }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k]; }
  focus() {}
}

const elMap = {};
function el(id, classes = [], dataset = {}) {
  if (!elMap[id]) elMap[id] = new MockElement(id, classes, dataset);
  return elMap[id];
}

// Registrar IDs del DOM requeridos
[
  'tabSettings', 'settingsDirtyBadge', 'settingsDirtyBadgeText',
  'btnSaveSettingsTab', 'btnSaveSettings', 'btnResetSettings',
  'catalogConfigTableBody', 'cfgMigrationFee',
  'cfgTemplateSelect', 'cfgTemplateContent', 'waBubbleContent', 'templateVarTooltipText', 'btnCopyWaPreview',
  'cfgLegalOwner', 'cfgBrandName', 'cfgSupportPhone',
  'cfgYapePhone', 'cfgYapeHolder', 'cfgBcpHolder', 'cfgBcpAccount', 'cfgBcpCci',
  'cfgBbvaHolder', 'cfgBbvaAccount', 'cfgBbvaCci',
  'cfgDefaultEnv', 'cfgDefaultTheme', 'cfgTableDensity',
  'settingsApkDirsSummary', 'btnGoToApkSearchDirs',
  'modalUnsavedSettings', 'unsavedSettingsList', 'btnCloseUnsavedSettingsModal',
  'btnUnsavedKeepEditing', 'btnUnsavedDiscardAndContinue', 'btnUnsavedSaveAndContinue',
  'modalResetSettingsScope', 'resetCurrentTabLabel', 'btnResetScopeCurrentTab',
  'btnResetScopeAll', 'btnResetScopeCancel', 'btnCloseResetScopeModal',
  'migFee', 'licCode', 'licClientSelect', 'credentialCanvas',
  'waCompMessage', 'waCompCharCounter', 'modalWaComposer',
  'waCompBizName', 'waCompOwnerName', 'waCompPlanBadge', 'waCompDeviceId',
  'waCompPhoneDisplay', 'waCompPhoneWarning', 'btnWaCompSend', 'btnWaCompOpenEmpty',
  'waApkDispatchPanel', 'waStandardFooterActions', 'waApkDispatchFooterActions',
  'waApkCopySuccessHint', 'btnThemeToggle'
].forEach(id => el(id));

// Mock Selects dependientes
const licPlanSel = el('licPlanSelect');
licPlanSel.options = [
  new MockOption('MENSUAL', 'Mensual'),
  new MockOption('PERPETUO_LIBERADO', 'Perpetuo'),
  new MockOption('PASE_ACTUALIZACION_ANUAL', 'Pase'),
];
const manualPresetSel = el('manualPayPlanPreset');
manualPresetSel.options = [
  new MockOption('MENSUAL', 'Plan Mensual (S/ 35.00)'),
  new MockOption('SERVICIO_MIGRACION', 'Servicio Migración (S/ 40.00)'),
];
const drawerPlanSel = el('drawerEditPlanSelect');
drawerPlanSel.options = [
  new MockOption('ANUAL', 'ANUAL (S/ 300.00)'),
];

// Mock credential canvas context
el('credentialCanvas').getContext = () => ({
  createLinearGradient: () => ({ addColorStop: () => {} }),
  fillRect: () => {},
  strokeRect: () => {},
  beginPath: () => {},
  moveTo: () => {},
  lineTo: () => {},
  closePath: () => {},
  stroke: () => {},
  save: () => {},
  restore: () => {},
  fillText: () => {},
  drawImage: () => {},
});
el('credentialCanvas').width = 900;
el('credentialCanvas').height = 520;

const authorSealEl = new MockElement('', ['author-name']);
const stabBtns = ['stabPricing', 'stabTemplates', 'stabPayment', 'stabPreferences'].map((id, i) => {
  const b = new MockElement('', i === 0 ? ['settings-tab-btn', 'active'] : ['settings-tab-btn'], { stab: id });
  return b;
});
const dirtyDots = ['stabPricing', 'stabTemplates', 'stabPayment', 'stabPreferences'].map(
  id => new MockElement('', ['stab-dirty-dot'], { dirtyFor: id })
);
const dataTable1 = new MockElement('', ['data-table']);
const dataTable2 = new MockElement('', ['data-table']);

// Subir dinámicamente inputs simulados de filas del catálogo después de populateSettingsForm
let catalogInputsByClassAndSlug = {};
function syncCatalogInputsFromTable() {
  catalogInputsByClassAndSlug = {};
  const tbody = el('catalogConfigTableBody');
  const slugs = Object.keys(ownerConfig?.catalog || {});
  const html = tbody.children.map(tr => tr.innerHTML).join('\\n');
  slugs.forEach(slug => {
    const item = ownerConfig.catalog[slug];
    const extractInput = (cls, fallbackVal) => {
      const m = html.match(new RegExp(`class="\${cls}"[^>]*data-slug="\${slug}"[^>]*value="([^"]*)"`));
      const inp = new MockElement('', [cls], { slug });
      inp.value = m ? m[1] : String(fallbackVal ?? '');
      catalogInputsByClassAndSlug[`\${cls}::\${slug}`] = inp;
    };
    extractInput('cfg-plan-label', item.label);
    extractInput('cfg-plan-price', Number(item.price || 0).toFixed(2));
    extractInput('cfg-plan-days', item.days || 0);
    extractInput('cfg-plan-ai', item.ai_credits || 0);
    extractInput('cfg-plan-updates', item.updates_window_months ?? item.updates_months ?? 0);
    extractInput('cfg-plan-desc', item.description || '');
  });
}

global.window = { open: () => {} };
global.localStorage = {
  _s: {},
  getItem(k) { return this._s[k] ?? null; },
  setItem(k, v) { this._s[k] = String(v); },
};

global.document = {
  documentElement: {
    _attrs: { 'data-theme': 'dark' },
    setAttribute(k, v) { this._attrs[k] = v; },
    getAttribute(k) { return this._attrs[k]; },
  },
  getElementById(id) { return elMap[id] || null; },
  createElement(tag) { return new MockElement('', [tag]); },
  querySelector(sel) {
    if (sel === '.author-name') return authorSealEl;
    if (sel === '.settings-tab-btn.active') return stabBtns.find(b => b.classList.contains('active')) || stabBtns[0];
    const mDirty = sel.match(/^\\.stab-dirty-dot\\[data-dirty-for="([^"]+)"\\]\$/);
    if (mDirty) return dirtyDots.find(d => d.dataset.dirtyFor === mDirty[1]) || null;
    const mCat = sel.match(/^\\.(cfg-plan-[a-z]+)\\[data-slug="([^"]+)"\\]\$/);
    if (mCat) return catalogInputsByClassAndSlug[`\${mCat[1]}::\${mCat[2]}`] || null;
    return null;
  },
  querySelectorAll(sel) {
    if (sel === '.settings-tab-btn') return stabBtns;
    if (sel === '.data-table') return [dataTable1, dataTable2];
    if (sel === '.cfg-plan-price') {
      return Object.keys(catalogInputsByClassAndSlug)
        .filter(k => k.startsWith('cfg-plan-price::'))
        .map(k => catalogInputsByClassAndSlug[k]);
    }
    if (sel === '.var-chip' || sel === '.settings-pane' || sel === '.wa-template-btn' || sel === '.wa-insert-chip') return [];
    return [];
  }
};

let ownerConfig = null;
let templatePreviewTimer = null;
let currentSelectedGeneratorCode = null;
let globalClients = [{ id: 'c1', business_name: 'Tienda Uno', owner_name: 'Ana', phone: '999888777', current_device_id: 'DEV-1', license_type: 'MENSUAL' }];
let globalReleaseMatrix = [];
let globalReleases = [];
const openedModals = [];
const closedModals = [];
const putPayloads = [];
const resetBodies = [];
const toasts = [];
let planProjectionCalls = 0;

function showToast(m, t = 'info') { toasts.push({ m, t }); }
function openModal(id) { openedModals.push(id); }
function closeModal(id) { closedModals.push(id); }
function updatePlanImpactAndProjection() { planProjectionCalls++; }
function formatApkSizeMb(x) { return String(x || ''); }
function getLatestPublishedVersion() { return '9.41.0'; }
function compareSemVer() { return 0; }
function getClientStatusBadge() { return { className: 'badge', text: 'Activa', isProspect: false, isPerp: false }; }
function copyPlainTextToClipboard(text, msg) { toasts.push({ copied: text, m: msg, t: 'success' }); }
function escapeHtml(s) { return String(s ?? ''); }

const serverStateConfig = {
  system: {
    default_mode: 'prod',
    theme: 'light',
    table_density: 'compact',
    apk_library_dir: 'C:\\\\APKs\\\\Oficial',
    apk_search_dirs: [
      { path: 'C:\\\\APKs\\\\Oficial', label: 'Oficial', enabled: true, is_default: true, kind: 'official_library' },
      { path: 'C:\\\\Builds\\\\Custom', label: 'Custom', enabled: true, is_default: false, kind: 'custom' }
    ]
  },
  legal_identity: {
    author_full_name: 'Autor Test',
    commercial_name: 'Marca Test',
    support_phone: '+51 900 111 222'
  },
  payment_methods: {
    yape_plin_phone: '900111222',
    yape_plin_holder: 'Autor Test',
    bcp_account_holder: '', bcp_account_number: '', bcp_cci: '',
    bbva_account_holder: '', bbva_account_number: '', bbva_cci: ''
  },
  catalog: {
    MENSUAL: { price: 35, days: 30, ai_credits: 50, updates_window_months: 0, updates_months: 0, label: 'Plan Mensual', description: 'Desc M' },
    ANUAL: { price: 280, days: 365, ai_credits: 1200, updates_window_months: 0, updates_months: 0, label: 'Plan Anual', description: 'Desc A' },
    PERPETUO_LIBERADO: { price: 850, days: 99999, ai_credits: 200, updates_window_months: 12, updates_months: 12, label: 'Perpetuo', description: 'Desc P' },
    PASE_ACTUALIZACION_ANUAL: { price: 150, days: 0, ai_credits: 100, updates_window_months: 12, updates_months: 12, label: 'Pase Anual', description: 'Desc U' },
    HARDWARE_MIGRATION_FEE: { price: 40, days: 0, ai_credits: 0, updates_window_months: 0, updates_months: 0, label: 'Tarifa Migración', description: 'Desc Mig' }
  },
  templates: {
    license_issued: 'Plantilla oficial {codigo}',
    expiring_reminder: 'Recordatorio oficial {yape_phone}',
    trial_welcome: 'Bienvenida oficial {negocio}',
    prospect: 'Seguimiento oficial {titular}',
    ai_bonus: 'Bono IA +{creditos_ia}',
    courtesy_extension: 'Cortesía {dias}',
    apk_update_eligible: 'APK gratis {version}',
    apk_update_quote: 'Cotización pase {precio_pase}',
    device_migration: 'Migración {device_id}'
  },
  receipt_config: {
    commercial_name: 'Marca Test',
    issuer_name: 'Autor Test',
    issuer_phone: '+51 900 111 222'
  }
};

global.fetch = async (url, opts = {}) => {
  if (url === '/api/config' && (!opts.method || opts.method === 'GET')) {
    return { ok: true, status: 200, json: async () => JSON.parse(JSON.stringify(serverStateConfig)) };
  }
  if (url === '/api/config' && opts.method === 'PUT') {
    const sent = JSON.parse(opts.body);
    putPayloads.push(sent);
    return { ok: true, status: 200, json: async () => sent };
  }
  if (url === '/api/config/reset' && opts.method === 'POST') {
    resetBodies.push(JSON.parse(opts.body || '{}'));
    return { ok: true, status: 200, json: async () => ({ ok: true, config: JSON.parse(JSON.stringify(serverStateConfig)), message: 'Reset OK' }) };
  }
  if (url === '/api/config/preview-template') {
    const b = JSON.parse(opts.body || '{}');
    return { ok: true, status: 200, json: async () => ({ ok: true, rendered: b.template || '' }) };
  }
  return { ok: true, status: 200, json: async () => ({}) };
};

${themeSection}
${fmtPlanSection}
${waSection}
${canvasSection}
${settingsSection}

const _origPopulate = populateSettingsForm;
populateSettingsForm = function(cfg) {
  _origPopulate(cfg);
  syncCatalogInputsFromTable();
  savedSettingsSnapshot = buildNormalizedSettingsSnapshotFromConfig(cfg);
  updateSettingsDirtyState();
};

(async () => {
  initSettingsEvents();
  await loadConfig();

  // A) Startup theme y density aplicados + rutas APK cargadas + sin dirty inicial
  assert.strictEqual(document.documentElement.getAttribute('data-theme'), 'light');
  assert.strictEqual(dataTable1.classList.contains('table-compact'), true);
  assert.strictEqual(dataTable2.classList.contains('table-compact'), true);
  assert.ok(el('settingsApkDirsSummary').innerHTML.includes('C:\\\\Builds\\\\Custom'));
  assert.strictEqual(getDirtySettingsTabs().length, 0);
  assert.strictEqual(el('settingsDirtyBadge').style.display, 'none');

  // B) Botón rápido Tema de sesión NO dispara Dirty Guard
  applyTheme('dark', { syncSelect: false });
  assert.strictEqual(document.documentElement.getAttribute('data-theme'), 'dark');
  assert.strictEqual(getDirtySettingsTabs().length, 0);

  // C) Sincronización bidireccional en vivo de Tarifa de Migración y guardado scope='pricing'
  el('cfgMigrationFee').value = '55.00';
  el('cfgMigrationFee').dispatch('input', el('cfgMigrationFee'));
  assert.strictEqual(catalogInputsByClassAndSlug['cfg-plan-price::HARDWARE_MIGRATION_FEE'].value, '55.00');
  catalogInputsByClassAndSlug['cfg-plan-price::HARDWARE_MIGRATION_FEE'].value = '65.00';
  el('catalogConfigTableBody').dispatch('input', catalogInputsByClassAndSlug['cfg-plan-price::HARDWARE_MIGRATION_FEE']);
  assert.strictEqual(el('cfgMigrationFee').value, '65.00');
  assert.deepStrictEqual(getDirtySettingsTabs(), ['stabPricing']);
  assert.strictEqual(dirtyDots.find(d => d.dataset.dirtyFor === 'stabPricing').classList.contains('visible'), true);

  // D) Editar Tab 2 múltiples plantillas sin perder borrador al cambiar #cfgTemplateSelect
  el('cfgTemplateSelect').value = 'license_issued';
  el('cfgTemplateSelect').dispatch('change');
  el('cfgTemplateContent').value = 'Licencia custom v2 {codigo}';
  el('cfgTemplateContent').dispatch('input', el('cfgTemplateContent'));

  el('cfgTemplateSelect').value = 'expiring_reminder';
  el('cfgTemplateSelect').dispatch('change');
  assert.strictEqual(el('cfgTemplateContent').value, 'Recordatorio oficial {yape_phone}');
  el('cfgTemplateContent').value = 'Aviso custom {yape_phone}';
  el('cfgTemplateContent').dispatch('input', el('cfgTemplateContent'));

  el('cfgTemplateSelect').value = 'license_issued';
  el('cfgTemplateSelect').dispatch('change');
  assert.strictEqual(el('cfgTemplateContent').value, 'Licencia custom v2 {codigo}');
  assert.deepStrictEqual(getDirtySettingsTabs().sort(), ['stabPricing', 'stabTemplates'].sort());

  // E) Guardar solo 'pricing' deja intacto borrador sucio en Tab 2 y preserva apk_search_dirs
  stabBtns[0].classList.add('active');
  const savedPriceOk = await saveOwnerConfig({ scope: 'pricing' });
  assert.strictEqual(savedPriceOk, true);
  assert.strictEqual(putPayloads.length, 1);
  assert.strictEqual(putPayloads[0].catalog.HARDWARE_MIGRATION_FEE.price, 65);
  assert.strictEqual(putPayloads[0].system.apk_search_dirs.length, 2);
  assert.strictEqual(el('migFee').value, '65.00');
  assert.strictEqual(manualPresetSel.options[1].getAttribute('data-price'), '65.00');
  // stabTemplates sigue sucio porque guardamos solo pricing
  assert.deepStrictEqual(getDirtySettingsTabs(), ['stabTemplates']);

  // F) Guardar 'templates' sincroniza bidireccionalmente con WA_TEMPLATES y Compositor CRM
  await saveOwnerConfig({ scope: 'templates' });
  assert.strictEqual(WA_TEMPLATES.license.text, 'Licencia custom v2 {codigo}');
  assert.strictEqual(WA_TEMPLATES.expiring.text, 'Aviso custom {yape_phone}');
  assert.deepStrictEqual(getDirtySettingsTabs(), []);

  // Verificar que renderWaTemplateBaseText lee la plantilla sincronizada + renderCredentialCanvas() con 0 args no lanza
  currentWaComposerClientId = 'c1';
  assert.strictEqual(renderWaTemplateBaseText('expiring'), 'Aviso custom 900111222');
  el('licCode').value = 'ML9-ABC-123';
  currentSelectedGeneratorCode = { token: 'ML9-ABC-123', plan: 'MENSUAL', device_id: 'DEV-1' };
  renderCredentialCanvas();

  // G) Dirty Guard: modificar Tab 3 -> intentar salir abre #modalUnsavedSettings; descartar revierte y navega
  el('cfgBrandName').value = 'Nueva Marca Dirty';
  el('cfgBrandName').dispatch('input', el('cfgBrandName'));
  assert.deepStrictEqual(getDirtySettingsTabs(), ['stabPayment']);
  let escaped = false;
  const immediate = guardSettingsExit(() => { escaped = true; });
  assert.strictEqual(immediate, false);
  assert.strictEqual(escaped, false);
  assert.ok(openedModals.includes('modalUnsavedSettings'));
  el('btnUnsavedDiscardAndContinue').dispatch('click');
  assert.strictEqual(escaped, true);
  assert.deepStrictEqual(getDirtySettingsTabs(), []);

  console.log('PLAN23_FASE2_JS_TESTS_OK');
})();
''');

      final res = await Process.run('node', [harnessFile.path]);
      expect(
        res.exitCode,
        equals(0),
        reason: 'Node test Fase 2 falló:\nSTDOUT: ${res.stdout}\nSTDERR: ${res.stderr}',
      );
      expect(res.stdout.toString(), contains('PLAN23_FASE2_JS_TESTS_OK'));
    });
  });
}
