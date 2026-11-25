import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

import '../lib/commercial_config_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';

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
  group('PLAN MAESTRO 23 - FASE 3: Emisor Criptográfico Declarativo MLC1- (Ed25519), QR y Exportador Dart', () {
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
      tempDir = Directory.systemTemp.createTempSync('ml_p23_fase3_');
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
          .initWithSeed(List<int>.generate(32, (i) => (i * 23 + 11) % 256));

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

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Formato MLC1-, separación de dominio utf8(MLC1-payloadB64), redondeo/tipos y cota <= 8192 B', () async {
      final issued = await syncService.generateSignedToken(
        configService.config,
        revision: 1,
        signer: signer,
        nowUtc: DateTime.utc(2026, 11, 25, 16, 30, 0),
      );

      final token = issued['token'] as String;
      expect(token.startsWith('MLC1-'), isTrue);
      expect(token.contains('='), isFalse);
      final bodyParts = token.substring(5).split('.');
      expect(bodyParts.length, equals(2));
      expect(utf8.encode(token).length, lessThanOrEqualTo(8192));

      // Hora Lima UTC-5: 16:30 UTC -> 11:30 America/Lima
      expect(issued['issued_at_lima'], contains('2026-11-25 11:30:00'));

      // Verificación positiva con LicenseSigner
      final okRes = await syncService.verifySignedToken(token, signer: signer);
      expect(okRes['valid'], isTrue);
      expect(okRes['revision'], equals(1));
      final payload = okRes['payload'] as Map<String, dynamic>;
      expect(payload['v'], equals(1));
      expect(payload['ver'], equals(1));
      final products = payload['p'] as Map<String, dynamic>;
      expect(products.keys.toSet(), equals({
        'mensual',
        'trimestral',
        'semestral',
        'anual',
        'perpetua',
        'bolsa_extra_ia',
        'pase_anual_updates',
        'migracion',
      }));
      expect(products['perpetua']['um'], equals(12));
      expect(products['pase_anual_updates']['um'], equals(12));
      expect(products['migracion']['pr'], equals(40.0));

      // Prueba estricta de separación de dominio (Salvaguarda 1):
      // Una firma calculada solo sobre `payloadB64` SIN prefijo `MLC1-` DEBE FALLAR.
      final payloadB64 = bodyParts[0];
      final rawSigWithoutDomain = await signer.signRawMessage(utf8.encode(payloadB64));
      final forgedNoDomainToken =
          'MLC1-$payloadB64.${LicenseSigner.encodeBase64UrlSafe(rawSigWithoutDomain)}';
      final failNoDomain = await syncService.verifySignedToken(
        forgedNoDomainToken,
        signer: signer,
      );
      expect(failNoDomain['valid'], isFalse);
      expect(failNoDomain['status'], equals('INVALID_SIGNATURE'));

      // Rechazar token > 8192 B en verifySignedToken
      final oversizedFakeToken = 'MLC1-${'A' * 8200}.${bodyParts[1]}';
      final oversizeRes = await syncService.verifySignedToken(
        oversizedFakeToken,
        signer: signer,
      );
      expect(oversizeRes['valid'], isFalse);
      expect(oversizeRes['status'], equals('EXCEEDS_MAX_SIZE'));

      // Rechazar precio negativo y días negativos en buildCanonicalPayload
      final negConfig = jsonDecode(jsonEncode(configService.config)) as Map<String, dynamic>;
      (negConfig['catalog']['MENSUAL'] as Map)['price'] = -5.0;
      expect(
        () => syncService.buildCanonicalPayload(negConfig, revision: 1),
        throwsA(isA<CommercialConfigSyncException>()),
      );
      final negDaysConfig = jsonDecode(jsonEncode(configService.config)) as Map<String, dynamic>;
      (negDaysConfig['catalog']['MENSUAL'] as Map)['days'] = -1;
      expect(
        () => syncService.buildCanonicalPayload(negDaysConfig, revision: 1),
        throwsA(isA<CommercialConfigSyncException>()),
      );
    });

    test('2. Detección de manipulación (1 char en payload/firma), clave distinta y rechazo de esquema no autorizado', () async {
      final issued = await syncService.generateSignedToken(
        configService.config,
        revision: 4,
        signer: signer,
      );
      final token = issued['token'] as String;
      final parts = token.substring(5).split('.');
      final payloadB64 = parts[0];
      final sigB64 = parts[1];

      // 2A. Alterar 1 carácter en payload
      final flipChar = payloadB64[10] == 'A' ? 'B' : 'A';
      final tamperedPayload =
          '${payloadB64.substring(0, 10)}$flipChar${payloadB64.substring(11)}';
      final tamperedToken1 = 'MLC1-$tamperedPayload.$sigB64';
      final res1 = await syncService.verifySignedToken(tamperedToken1, signer: signer);
      expect(res1['valid'], isFalse);
      expect(res1['status'], equals('INVALID_SIGNATURE'));

      // 2B. Alterar 1 carácter en firma
      final flipSigChar = sigB64[5] == 'C' ? 'D' : 'C';
      final tamperedSig =
          '${sigB64.substring(0, 5)}$flipSigChar${sigB64.substring(6)}';
      final tamperedToken2 = 'MLC1-$payloadB64.$tamperedSig';
      final res2 = await syncService.verifySignedToken(tamperedToken2, signer: signer);
      expect(res2['valid'], isFalse);

      // 2C. Verificar con clave pública Ed25519 distinta -> falla
      final otherKeyPair = await Ed25519().newKeyPairFromSeed(
        List<int>.generate(32, (i) => (i * 31 + 5) % 256),
      );
      final otherPub = await otherKeyPair.extractPublicKey();
      final resOtherKey = await syncService.verifySignedToken(
        token,
        publicKey: otherPub,
      );
      expect(resOtherKey['valid'], isFalse);
      expect(resOtherKey['status'], equals('INVALID_SIGNATURE'));

      // 2D. Token firmado pero con clave ejecutable no autorizada ("script") en JSON -> rechazado por esquema
      final injectedJson = jsonEncode({
        'v': 1,
        'ver': 1,
        'iat': 1795600000,
        'sup': '+51 922 836 879',
        'yh': 'Test',
        'yp': '922836879',
        'bcp': {'h': '', 'acc': '', 'cci': ''},
        'bbva': {'h': '', 'acc': '', 'cci': ''},
        'script': 'eval(1)',
        'p': syncService.buildCanonicalPayload(configService.config, revision: 1)['p'],
      });
      final injB64 = LicenseSigner.encodeBase64UrlSafe(utf8.encode(injectedJson));
      final injSig = await signer.signRawMessage(utf8.encode('MLC1-$injB64'));
      final injToken = 'MLC1-$injB64.${LicenseSigner.encodeBase64UrlSafe(injSig)}';
      final resInjected = await syncService.verifySignedToken(injToken, signer: signer);
      expect(resInjected['valid'], isFalse);
      expect(resInjected['status'], equals('INVALID_SCHEMA'));
    });

    test('3. Monotonicidad de system.commercial_sync_revision (POST emite 1->2->3, GET no altera, reset conserva ver) y Exportador Dart', () async {
      expect(configService.commercialSyncRevision, equals(0));

      // Personalizar precios y cuentas BCP/BBVA con caracteres especiales para probar escape Dart
      final customCatalog = jsonDecode(jsonEncode(configService.catalog)) as Map<String, dynamic>;
      (customCatalog['MENSUAL'] as Map)['price'] = 39.5;
      (customCatalog['MENSUAL'] as Map)['description'] = "Plan 'Promo' \$39.50";
      (customCatalog['HARDWARE_MIGRATION_FEE'] as Map)['price'] = 45.0;

      await configService.saveConfig({
        'catalog': customCatalog,
        'legal_identity': {
          'author_full_name': 'Julio Angello Vasquez Navarro',
          'commercial_name': 'MochilaLista',
          'support_phone': '+51 999 000 111',
        },
        'payment_methods': {
          'yape_plin_holder': 'Julio Angello Vasquez Navarro',
          'yape_plin_phone': '999000111',
          'bcp_account_holder': 'Julio Vasquez',
          'bcp_account_number': '191-55566677-0-99',
          'bcp_cci': '002-191-005556667709-99',
          'bbva_account_holder': '',
          'bbva_account_number': '',
          'bbva_cci': '',
        },
      });

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
      final http = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';

      try {
        // 3A. GET /api/config/dart-defaults-snippet es solo lectura y NO incrementa revision (0)
        final getRes1 = await _httpJson(
          http,
          'GET',
          Uri.parse('$baseUrl/api/config/dart-defaults-snippet'),
        );
        expect(getRes1['status'], equals(200));
        expect(getRes1['body']['ok'], isTrue);
        expect(getRes1['body']['revision'], equals(0));
        expect(configService.commercialSyncRevision, equals(0));

        final snippet = getRes1['body']['dart_snippet'] as String;
        expect(snippet, contains("static const String supportPhone = '+51 999 000 111';"));
        expect(snippet, contains("static const String yapePlinPhone = '999000111';"));
        expect(snippet, contains("static const String bcpAccountNumber = '191-55566677-0-99';"));
        expect(snippet, contains("static const String bcpCciNumber = '002-191-005556667709-99';"));
        expect(snippet, contains("'mensual': {"));
        expect(snippet, contains("'pr': 39.50,"));
        expect(snippet, contains(r"Plan \'Promo\' \$39.50"));

        // 3B. Tres llamadas POST /api/config/generate-sync-token -> 1, 2, 3
        for (int expectedRev = 1; expectedRev <= 3; expectedRev++) {
          final postRes = await _httpJson(
            http,
            'POST',
            Uri.parse('$baseUrl/api/config/generate-sync-token'),
            body: {},
          );
          expect(postRes['status'], equals(200));
          final b = postRes['body'] as Map<String, dynamic>;
          expect(b['ok'], isTrue);
          expect(b['revision'], equals(expectedRev));
          final tok = b['token'] as String;
          expect(tok.startsWith('MLC1-'), isTrue);
          final verify = await syncService.verifySignedToken(tok, signer: signer);
          expect(verify['valid'], isTrue);
          expect(verify['revision'], equals(expectedRev));
        }
        expect(configService.commercialSyncRevision, equals(3));

        // 3C. GET nuevamente NO cambia la revisión 3
        final getRes2 = await _httpJson(
          http,
          'GET',
          Uri.parse('$baseUrl/api/config/dart-defaults-snippet'),
        );
        expect(getRes2['body']['revision'], equals(3));

        // 3D. Guardar intentando bajar commercial_sync_revision a 1 -> bloqueo anti-downgrade mantiene 3
        await configService.saveConfig({
          'system': {'commercial_sync_revision': 1},
        });
        expect(configService.commercialSyncRevision, equals(3));

        // 3E. resetToDefaults(scope: 'all') CONSERVA commercial_sync_revision == 3 (anti-downgrade)
        final resetRes = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/reset'),
          body: {'scope': 'all'},
        );
        expect(resetRes['status'], equals(200));
        expect(configService.getPlanPrice('MENSUAL'), equals(35.0));
        expect(configService.commercialSyncRevision, equals(3));

        // Siguiente POST emite revisión 4 con los precios reseteados a 35.0
        final postRes4 = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/generate-sync-token'),
          body: {},
        );
        expect(postRes4['status'], equals(200));
        expect(postRes4['body']['revision'], equals(4));
        expect(postRes4['body']['payload']['p']['mensual']['pr'], equals(35.0));
      } finally {
        http.close(force: true);
        await server.close(force: true);
      }
    });

    test('4. Auditoría HTML/CSS/JS y Ejecución Node.js: Dirty Guard pre-emisión, Vía 1 (MLC1+QR+WA) y Vía 2 (Dart sin incremento)', () async {
      final html = File('web/index.html').readAsStringSync();
      final css = File('web/css/styles.css').readAsStringSync();
      final js = File('web/js/admin_app.js').readAsStringSync();

      // Presencia UI y estilos Dark/Light
      expect(html, contains('id="btnOpenCommercialSyncModal"'));
      expect(html, contains('id="modalCommercialConfigSync"'));
      expect(html, contains('id="btnGenerateMlc1Token"'));
      expect(html, contains('id="mlc1TokenOutput"'));
      expect(html, contains('id="mlc1QrContainer"'));
      expect(html, contains('id="btnDownloadMlc1Qr"'));
      expect(html, contains('id="btnCopyMlc1Qr"'));
      expect(html, contains('id="btnSendMlc1Whatsapp"'));
      expect(html, contains('id="mlc1DartSnippetOutput"'));
      expect(html, contains('id="btnCopyMlc1Dart"'));

      expect(css, contains('.btn-sync-mlc1'));
      expect(css, contains('[data-theme="light"] .btn-sync-mlc1'));
      expect(css, contains('[data-theme="light"] .mlc1-security-banner'));
      expect(css, contains('[data-theme="light"] .mlc1-code-textarea'));
      expect(css, contains('.mlc1-qr-white-box'));

      // Cero emojis crudos prohibidos
      const bannedEmojis = ['✅', '⬇️', '📁', '✏️', '🗑️', '📲', 'ℹ️', '🚀', '📦', '📅', '⚡'];
      for (final emoji in bannedEmojis) {
        expect(html, isNot(contains(emoji)), reason: 'HTML no debe tener emoji $emoji');
        expect(css, isNot(contains(emoji)), reason: 'CSS no debe tener emoji $emoji');
      }

      // Bloque puro entre formatApkSizeMb y renderSignatureStatusBadge intacto
      expect(js.indexOf('function formatApkSizeMb('), greaterThan(0));
      expect(
        js.indexOf('function renderSignatureStatusBadge('),
        greaterThan(js.indexOf('function formatApkSizeMb(')),
      );

      // Prueba real en Node.js de openCommercialConfigSyncModal, Dirty Guard y generateMlc1SyncToken
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

      final harnessFile = File('${tempDir.path}/p23_fase3_mlc1_ui_test.js');
      await harnessFile.writeAsString('''
const assert = require('assert');

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
    this.listeners = {};
    this.disabled = false;
    this.options = [];
    this.children = [];
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
  setAttribute() {}
  getAttribute() { return ''; }
  focus() {}
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
  'mlc1QrContainer', 'btnDownloadMlc1Qr', 'btnCopyMlc1Qr',
  'mlc1DartSnippetOutput', 'btnCopyMlc1Dart',
  'cfgMigrationFee', 'cfgTemplateSelect', 'cfgTemplateContent',
  'cfgLegalOwner', 'cfgBrandName', 'cfgSupportPhone', 'cfgYapePhone', 'cfgYapeHolder',
  'cfgBcpHolder', 'cfgBcpAccount', 'cfgBcpCci',
  'cfgBbvaHolder', 'cfgBbvaAccount', 'cfgBbvaCci',
  'cfgDefaultEnv', 'cfgDefaultTheme', 'cfgTableDensity',
  'settingsDirtyBadge', 'settingsDirtyBadgeText', 'catalogConfigTableBody'
].forEach(id => el(id));

const mlc1TabBtns = ['mlc1PaneToken', 'mlc1PaneDart'].map((id, idx) =>
  new MockElement('', idx === 0 ? ['mlc1-tab-btn', 'active'] : ['mlc1-tab-btn'], { mlc1Tab: id })
);

let confirmModalCalls = 0;
let lastConfirmCallback = null;
const openedModals = [];
const closedModals = [];
const openedUrls = [];
const copiedTexts = [];
const qrRenderCalls = [];
const downloadQrCalls = [];
const fetchCalls = [];
let mockDirtyTabs = [];
let mockRevision = 2;

global.window = {
  open(url, target) { openedUrls.push({ url, target }); }
};
global.document = {
  documentElement: { setAttribute() {}, getAttribute() { return 'dark'; } },
  getElementById(id) { return elMap[id] || null; },
  createElement(tag) { return new MockElement('', [tag]); },
  querySelector() { return null; },
  querySelectorAll(sel) {
    if (sel === '.mlc1-tab-btn') return mlc1TabBtns;
    if (sel === '.mlc1-tab-pane') return [el('mlc1PaneToken'), el('mlc1PaneDart')];
    return [];
  }
};

let ownerConfig = {
  system: { default_mode: 'sandbox', theme: 'dark', table_density: 'comfortable', commercial_sync_revision: 2 },
  legal_identity: { commercial_name: 'MochilaLista', support_phone: '+51 922 836 879', author_full_name: 'Autor Oficial' },
  payment_methods: { yape_plin_phone: '922836879', yape_plin_holder: 'Autor Oficial' },
  catalog: { MENSUAL: { price: 35, days: 30, ai_credits: 50, updates_window_months: 0, label: 'Plan Mensual' } },
  templates: {}
};

function showToast() {}
function openModal(id) { openedModals.push(id); }
function closeModal(id) { closedModals.push(id); }
function showConfirmModal(title, msg, cb) { confirmModalCalls++; lastConfirmCallback = cb; }
function copyPlainTextToClipboard(txt) { copiedTexts.push(txt); }
function downloadQrWithQuietZone(selector, name, margin) { downloadQrCalls.push({ selector, name, margin }); }
function renderSafeQrCode(container, text, size, dark, light) {
  qrRenderCalls.push({ id: container?.id || container, text, size, dark, light });
}
function escapeHtml(s) { return String(s ?? ''); }
function formatApkSizeMb(s) { return String(s ?? ''); }
function getLatestPublishedVersion() { return '9.40.0'; }
function compareSemVer() { return 0; }
function getClientStatusBadge() { return { className: 'badge', text: 'Activa', isProspect: false, isPerp: false }; }
function updatePlanImpactAndProjection() {}
function applyTheme() {}

global.fetch = async (url, opts = {}) => {
  fetchCalls.push({ url, method: opts.method || 'GET' });
  if (url === '/api/config/dart-defaults-snippet') {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        revision: mockRevision,
        dart_snippet: '// DART REV ' + mockRevision,
        summary: {
          revision: mockRevision,
          support_phone: '+51 922 836 879',
          yape_phone: '922836879',
          yape_holder: 'Autor Oficial',
          bcp_configured: false,
          bbva_configured: false,
          plans: [{ id: 'mensual', label: 'Plan Mensual', price: 35, days: 30, ai_credits: 50, updates_months: 0 }]
        }
      })
    };
  }
  if (url === '/api/config/generate-sync-token') {
    mockRevision++;
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        token: 'MLC1-PAYLOADB64TEST.SIGB64TEST',
        revision: mockRevision,
        issued_at: '2026-11-25T16:40:00Z',
        issued_at_lima: '2026-11-25 11:40:00 (Lima GMT-5)',
        payload_bytes: 1280,
        token_bytes: 1810,
        dart_snippet: '// DART REV ' + mockRevision,
        summary: {
          revision: mockRevision,
          support_phone: '+51 922 836 879',
          yape_phone: '922836879',
          yape_holder: 'Autor Oficial',
          bcp_configured: false,
          bbva_configured: false,
          plans: [{ id: 'mensual', label: 'Plan Mensual', price: 35, days: 30, ai_credits: 50, updates_months: 0 }]
        },
        config: { ...ownerConfig, system: { ...ownerConfig.system, commercial_sync_revision: mockRevision } }
      })
    };
  }
  return { ok: true, status: 200, json: async () => ({}) };
};

$waSection
$settingsSection

// Interceptar getDirtySettingsTabs después de evaluar settingsSection
getDirtySettingsTabs = () => mockDirtyTabs;
saveOwnerConfig = async () => { mockDirtyTabs = []; return true; };

(async () => {
  initSettingsEvents();

  // 1. Con cambios sin guardar -> Dirty Guard intercepta y NO abre el modal todavía
  mockDirtyTabs = ['stabPricing'];
  const openedImmediate = openCommercialConfigSyncModal();
  assert.strictEqual(openedImmediate, false);
  assert.strictEqual(confirmModalCalls, 1);
  assert.strictEqual(openedModals.length, 0);

  // Al confirmar "guardar y continuar", guarda y abre el modal vía GET (revision 2 sin incrementar)
  await lastConfirmCallback();
  assert.ok(openedModals.includes('modalCommercialConfigSync'));
  assert.strictEqual(mockRevision, 2);
  assert.strictEqual(el('mlc1RevisionBadge').textContent, 'Revisión #2');
  assert.strictEqual(el('mlc1DartSnippetOutput').value, '// DART REV 2');
  assert.strictEqual(el('mlc1TokenResultContainer').style.display, 'none');

  // 2. Emitir token firmado vía POST /api/config/generate-sync-token -> Rev #3 + QR + WhatsApp
  await generateMlc1SyncToken();
  assert.strictEqual(mockRevision, 3);
  assert.strictEqual(el('mlc1RevisionBadge').textContent, 'Revisión #3');
  assert.strictEqual(el('mlc1TokenOutput').value, 'MLC1-PAYLOADB64TEST.SIGB64TEST');
  assert.strictEqual(el('mlc1TokenResultContainer').style.display, 'grid');
  assert.strictEqual(el('mlc1DartSnippetOutput').value, '// DART REV 3');
  assert.strictEqual(qrRenderCalls.length, 1);
  assert.strictEqual(qrRenderCalls[0].text, 'MLC1-PAYLOADB64TEST.SIGB64TEST');
  assert.strictEqual(qrRenderCalls[0].dark, '#0f172a');
  assert.strictEqual(qrRenderCalls[0].light, '#ffffff');

  // Descargar QR PNG aplica quiet zone 32px
  el('btnDownloadMlc1Qr').dispatch('click');
  assert.strictEqual(downloadQrCalls.length, 1);
  assert.strictEqual(downloadQrCalls[0].selector, '#mlc1QrContainer');
  assert.strictEqual(downloadQrCalls[0].margin, 32);

  // Enviar por WhatsApp incluye el token MLC1 limpio y copia texto
  el('btnSendMlc1Whatsapp').dispatch('click');
  assert.strictEqual(openedUrls.length, 1);
  assert.ok(openedUrls[0].url.includes('https://api.whatsapp.com/send?text='));
  assert.ok(copiedTexts.some(t => t.includes('MLC1-PAYLOADB64TEST.SIGB64TEST')));

  // Cambiar a pestaña Vía 2 (Dart) y copiar snippet
  mlc1TabBtns[1].dispatch('click');
  assert.strictEqual(el('mlc1PaneDart').classList.contains('active'), true);
  el('btnCopyMlc1Dart').dispatch('click');
  assert.ok(copiedTexts.includes('// DART REV 3'));

  console.log('PLAN23_FASE3_UI_NODE_OK');
})();
''');

      final res = await Process.run('node', [harnessFile.path]);
      expect(
        res.exitCode,
        equals(0),
        reason: 'Node test Fase 3 falló:\nSTDOUT: ${res.stdout}\nSTDERR: ${res.stderr}',
      );
      expect(res.stdout.toString(), contains('PLAN23_FASE3_UI_NODE_OK'));
    });
  });
}
