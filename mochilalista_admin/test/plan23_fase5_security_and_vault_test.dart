import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

Future<Map<String, dynamic>> _httpRaw(
  HttpClient client,
  String method,
  Uri uri, {
  Map<String, dynamic>? body,
  String? token,
  String? cookieHeader,
  String mode = 'prod',
}) async {
  final req = await client.openUrl(method, uri);
  req.headers.add('X-App-Mode', mode);
  if (token != null) {
    req.headers.add('X-Vault-Session-Token', token);
  }
  if (cookieHeader != null) {
    req.headers.add('Cookie', cookieHeader);
  }
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  final raw = await utf8.decodeStream(res);
  dynamic decoded;
  try {
    decoded = raw.trim().isNotEmpty ? jsonDecode(raw) : null;
  } catch (_) {
    decoded = raw;
  }
  return {
    'status': res.statusCode,
    'headers': res.headers,
    'cookies': res.cookies,
    'body': decoded,
    'raw': raw,
  };
}

String _extractHtmlSection(String html, String startMarker, String endMarker) {
  final start = html.indexOf(startMarker);
  final end = html.indexOf(endMarker, start + 1);
  if (start < 0 || end < 0 || end <= start) {
    throw StateError('No se encontraron marcadores HTML "$startMarker" -> "$endMarker"');
  }
  return html.substring(start, end);
}

String _extractJsBetween(String js, String startMarker, String endMarker) {
  final start = js.indexOf(startMarker);
  final end = js.indexOf(endMarker, start + 1);
  if (start < 0 || end < 0 || end <= start) {
    throw StateError('No se encontraron marcadores JS "$startMarker" -> "$endMarker"');
  }
  return js.substring(start, end);
}

void main() {
  group('PLAN MAESTRO 23 - FASE 5: Seguridad, Auditoría, Cookies PIN y #tabSecurityVault', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late Directory mirrorDir;
    late Directory cloudDir;
    late Directory releasesDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late LicenseSigner signer;
    late ExcelExportService excelService;
    late VaultStorageService vaultStorage;
    late CommercialConfigSyncService commercialSyncService;
    late HttpServer server;
    late HttpClient httpClient;
    late Uri baseUri;
    String? mockPickedFolder;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_p23_fase5_');
      dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      mirrorDir = Directory('${tempDir.path}/vault_mirror')
        ..createSync(recursive: true);
      cloudDir = Directory('${tempDir.path}/cloud_sync')
        ..createSync(recursive: true);
      releasesDir = Directory('${tempDir.path}/releases_apks')
        ..createSync(recursive: true);

      // Sembrar clave Ed25519 temporal aislada
      final privDir = Directory('${tempDir.path}/private_keys')
        ..createSync(recursive: true);
      final seed = List<int>.generate(32, (i) => (i * 19 + 7) % 256);
      await File('${privDir.path}/ed25519_master.key').writeAsString(jsonEncode({
        'format': 'ED25519_SEED',
        'seed': seed,
      }));

      dbService = DatabaseService(
        dataDir: dataDir.path,
        backupDir: backupsDir.path,
        releasesDir: releasesDir.path,
      );
      await dbService.init();
      dbService.setMode('prod');

      configService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await configService.init();

      signer = LicenseSigner();
      await signer.loadMasterKey(keyPath: '${privDir.path}/ed25519_master.key');

      excelService = ExcelExportService(
        dbService: dbService,
        configService: configService,
      );
      commercialSyncService = CommercialConfigSyncService();

      vaultStorage = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: mirrorDir.path,
        dpapiService: _TestDpapiService(),
        dbService: dbService,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();

      // Inicializar prod_releases_db.json mínimo para auditoría de 5 archivos
      await dbService.createRelease({
        'version_name': '9.41.0',
        'version_code': 85,
        'release_notes': 'Fase 5 Test',
      });

      mockPickedFolder = cloudDir.path;

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://127.0.0.1:${server.port}');
      server.listen((req) {
        handleRequest(
          req,
          dbService,
          signer,
          configService,
          excelService,
          vaultStorage,
          onBrowseFolderOverride: () async => mockPickedFolder,
          commercialSyncService: commercialSyncService,
        );
      });

      httpClient = HttpClient();
      httpClient.autoUncompress = true;
    });

    tearDown(() async {
      httpClient.close(force: true);
      await server.close(force: true);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Índice de protección unificado (25% x 4 factores) + GET /api/vault/audit con paridad SHA-256', () async {
      // Añadir cliente real para producir prod_clients_db.json en espejo
      await dbService.createClient({
        'business_name': 'Librería Pacífico',
        'owner_name': 'Ana Paredes',
        'phone': '+51 944000111',
        'license_type': 'ANUAL',
      });
      await vaultStorage.syncMirror();

      // 1/4 factores (solo DPAPI = 25%) + configurar nube secundaria NO debe inflar el score
      await vaultStorage.setCloudSyncPath(cloudDir.path);
      final h1 = await _httpRaw(httpClient, 'GET', baseUri.resolve('/api/vault/health'));
      expect(h1['status'], equals(200));
      expect(h1['body']['security_score'], equals(25));
      expect(h1['body']['active_factors_count'], equals(1));
      expect(h1['body']['cloud_mirror_active'], isTrue);
      expect(h1['body']['mirror']['last_sync_lima'], isNotEmpty);

      // Enrolar .mlkey -> 2/4 = 50%
      await _httpRaw(httpClient, 'GET', baseUri.resolve('/api/vault/download-mlkey'));
      final h2 = await _httpRaw(httpClient, 'GET', baseUri.resolve('/api/vault/health'));
      expect(h2['body']['security_score'], equals(50));
      expect(h2['body']['active_factors_count'], equals(2));

      // Enrolar Kit de Rescate -> 3/4 = 75%
      await _httpRaw(httpClient, 'POST', baseUri.resolve('/api/vault/generate-rescue-kit'), body: {});
      final h3 = await _httpRaw(httpClient, 'GET', baseUri.resolve('/api/vault/health'));
      expect(h3['body']['security_score'], equals(75));
      expect(h3['body']['active_factors_count'], equals(3));

      // Configurar PIN -> 4/4 = 100%
      final pinCfg = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/pin/configure'),
        body: {'enabled': true, 'pin': '5678'},
      );
      expect(pinCfg['status'], equals(200));
      final sessionToken = pinCfg['body']['session_token'] as String;

      // Auditoría integral autenticada con session_token
      final auditRes = await _httpRaw(
        httpClient,
        'GET',
        baseUri.resolve('/api/vault/audit'),
        token: sessionToken,
      );
      expect(auditRes['status'], equals(200));
      final audit = auditRes['body'] as Map<String, dynamic>;
      expect(audit['ok'], isTrue);
      expect(audit['security_score'], equals(100));
      expect(audit['active_factors_count'], equals(4));
      expect(audit['dpapi']['valid'], isTrue);
      expect(audit['keyring']['valid'], isTrue);
      expect(audit['cloud_mirror_active'], isTrue);
      expect(audit['matched_files_count'], equals(5));
      expect(audit['total_critical_files'], equals(5));

      final files = audit['files'] as Map<String, dynamic>;
      for (final key in ['clients_db', 'releases_db', 'owner_config', 'master_key', 'vault_keyring']) {
        final f = files[key] as Map<String, dynamic>;
        expect(f['exists'], isTrue, reason: '$key debe existir en disco');
        expect((f['size_bytes'] as num).toInt(), greaterThan(0));
        expect(f['modified_lima'], isNotEmpty);
        expect(f['sha256'], isNotEmpty);
        expect(f['mirror_sha256'], equals(f['sha256']));
        expect(f['mirror_parity'], isTrue);
      }
      expect(audit['recommendations'], isEmpty);
    });

    test('2. POST /api/vault/cloud-path/browse soporta override y bloquea rutas prohibidas', () async {
      // Ruta válida externa
      mockPickedFolder = cloudDir.path;
      final okRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/cloud-path/browse'),
        body: {},
      );
      expect(okRes['status'], equals(200));
      expect(okRes['body']['ok'], isTrue);
      expect(okRes['body']['cancelled'], isFalse);
      expect(okRes['body']['path'], equals(cloudDir.path));

      // Raíz de disco C:\ -> 400
      mockPickedFolder = r'C:\';
      final rootRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/cloud-path/browse'),
        body: {},
      );
      expect(rootRes['status'], equals(400));
      expect(rootRes['body']['ok'], isFalse);

      // Carpeta sensible private_keys -> 400
      mockPickedFolder = '${tempDir.path}/private_keys';
      final privRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/cloud-path/browse'),
        body: {},
      );
      expect(privRes['status'], equals(400));
      expect(privRes['body']['ok'], isFalse);

      // Carpeta interna data -> 400 en browse y set-cloud-path
      mockPickedFolder = dataDir.path;
      final dataRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/cloud-path/browse'),
        body: {},
      );
      expect(dataRes['status'], equals(400));

      final setBlocked = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/set-cloud-path'),
        body: {'cloud_path': dataDir.path},
      );
      expect(setBlocked['status'], equals(400));

      // Cancelación limpia -> 200 con cancelled: true
      mockPickedFolder = null;
      final cancelRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/cloud-path/browse'),
        body: {},
      );
      expect(cancelRes['status'], equals(200));
      expect(cancelRes['body']['cancelled'], isTrue);
    });

    test('3. Flujo PIN completo: cero auto-423, Set-Cookie HttpOnly, descargas con cookie y bloqueo real 423', () async {
      await dbService.createClient({
        'business_name': 'Bazar Aurora',
        'owner_name': 'Luis Díaz',
        'phone': '+51 955111222',
        'license_type': 'MENSUAL',
      });
      await dbService.createManualBackup();
      final backups = await dbService.listBackups();
      final backupName = backups.firstWhere(
        (b) => (b['filename'] as String).contains('clients_manual'),
      )['filename'] as String;

      // Activar PIN -> devuelve session_token + Set-Cookie HttpOnly inmediato
      final cfgRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/pin/configure'),
        body: {'enabled': true, 'pin': '4321'},
      );
      expect(cfgRes['status'], equals(200));
      expect(cfgRes['body']['ok'], isTrue);
      expect(cfgRes['body']['pin_enabled'], isTrue);
      final token = cfgRes['body']['session_token'] as String?;
      expect(token, isNotNull);
      expect(token, isNotEmpty);

      final cfgCookies = cfgRes['cookies'] as List<Cookie>;
      final sessionCookie = cfgCookies.firstWhere((c) => c.name == 'vault_session_token');
      expect(sessionCookie.value, equals(token));
      expect(sessionCookie.httpOnly, isTrue);

      // Petición inmediata a /api/vault/health o /api/vault/audit con token -> 200 OK (sin auto-423)
      final immediateAudit = await _httpRaw(
        httpClient,
        'GET',
        baseUri.resolve('/api/vault/audit'),
        token: token,
      );
      expect(immediateAudit['status'], equals(200));

      // Sin token ni cookie -> HTTP 423 en descargas y shutdown
      final lockedCsv = await _httpRaw(
        httpClient,
        'GET',
        baseUri.resolve('/api/clients/export-csv'),
      );
      expect(lockedCsv['status'], equals(423));

      final lockedBackup = await _httpRaw(
        httpClient,
        'GET',
        baseUri.resolve('/api/backups/download/$backupName'),
      );
      expect(lockedBackup['status'], equals(423));

      final lockedShutdown = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/system/shutdown'),
        body: {},
      );
      expect(lockedShutdown['status'], equals(423));

      // Con SOLO la cookie HttpOnly vault_session_token -> descargas responden 200 OK
      final okCsv = await _httpRaw(
        httpClient,
        'GET',
        baseUri.resolve('/api/clients/export-csv'),
        cookieHeader: 'vault_session_token=$token',
      );
      expect(okCsv['status'], equals(200));
      expect(okCsv['raw'].toString(), contains('Bazar Aurora'));

      final okBackup = await _httpRaw(
        httpClient,
        'GET',
        baseUri.resolve('/api/backups/download/$backupName'),
        cookieHeader: 'vault_session_token=$token',
      );
      expect(okBackup['status'], equals(200));
      expect(okBackup['raw'].toString(), contains('Bazar Aurora'));

      // Lock manual revoca sesión y expira cookie (Max-Age=0)
      final lockRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/pin/lock'),
        body: {},
        token: token,
      );
      expect(lockRes['status'], equals(200));
      final clearedCookies = lockRes['cookies'] as List<Cookie>;
      final expiredCookie = clearedCookies.firstWhere((c) => c.name == 'vault_session_token');
      expect(expiredCookie.maxAge, equals(0));

      final afterLockCsv = await _httpRaw(
        httpClient,
        'GET',
        baseUri.resolve('/api/clients/export-csv'),
        cookieHeader: 'vault_session_token=$token',
      );
      expect(afterLockCsv['status'], equals(423));

      // Verificar verifyPin y recoverPin emiten cookie HttpOnly
      final verifyRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/pin/verify'),
        body: {'pin': '4321'},
      );
      expect(verifyRes['status'], equals(200));
      final verifyCookies = verifyRes['cookies'] as List<Cookie>;
      expect(verifyCookies.any((c) => c.name == 'vault_session_token' && c.httpOnly && c.value.isNotEmpty), isTrue);
    });

    test('4. POST /api/vault/inspect expone version, created_at_lima y stats reales + export v9.41.0+85', () async {
      await dbService.createClient({
        'business_name': 'Papelería Norte',
        'owner_name': 'María Solís',
        'phone': '+51 966222333',
        'license_type': 'SEMESTRAL',
      });
      await dbService.createClient({
        'business_name': 'Librería Sur',
        'owner_name': 'Pedro Rojas',
        'phone': '+51 977333444',
        'license_type': 'ANUAL',
      });

      final exportRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/export'),
        body: {'include_master_key': true},
      );
      expect(exportRes['status'], equals(200));
      final vaultJson = exportRes['body']['vault_json'] as String;

      final inspectRes = await _httpRaw(
        httpClient,
        'POST',
        baseUri.resolve('/api/vault/inspect'),
        body: {'vault_json': vaultJson},
      );
      expect(inspectRes['status'], equals(200));
      final meta = inspectRes['body']['metadata'] as Map<String, dynamic>;
      expect(meta['version'], equals('1.1.0'));
      expect(meta['app_version'], equals('9.41.0+85'));
      expect(meta['created_at_lima'], isNotEmpty);
      expect(meta['includes_private_key'], isTrue);
      expect(meta['stats']['clients_count'], equals(2));
      expect(meta['stats']['releases_count'], equals(1));
    });

    test('5. Auditoría HTML/CSS/JS y ejecución real en Node.js de #tabSecurityVault', () async {
      final html = File('web/index.html').readAsStringSync();
      final css = File('web/css/styles.css').readAsStringSync();
      final js = File('web/js/admin_app.js').readAsStringSync();

      // A. Verificar 0 emojis crudos (ni Dingbats ✕) en sección seguridad y modales bóveda
      final tabHtml = _extractHtmlSection(
        html,
        '<section id="tabSecurityVault"',
        '</section>',
      );
      final importModalHtml = _extractHtmlSection(
        html,
        '<div class="modal-overlay" id="modalImportVault">',
        '<div class="modal-overlay" id="modalAutoRecovery">',
      );
      final kitModalHtml = _extractHtmlSection(
        html,
        '<div class="modal-overlay" id="printableEmergencyKit">',
        '<!-- MODAL EJECUTIVO: AUDITORÍA INTEGRAL',
      );
      final auditModalHtml = _extractHtmlSection(
        html,
        '<div class="modal-overlay" id="modalVaultAuditReport">',
        '<!-- DRAWER LATERAL DESLIZABLE',
      );

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      for (final chunk in [tabHtml, importModalHtml, kitModalHtml, auditModalHtml]) {
        expect(emojiRegex.hasMatch(chunk), isFalse,
            reason: 'No debe haber emojis crudos ni Dingbats en UI de Seguridad');
      }

      // Verificar elementos HTML obligatorios Fase 5
      expect(tabHtml, contains('id="btnBrowseCloudSyncPath"'));
      expect(tabHtml, contains('id="pathCloudDir"'));
      expect(tabHtml, contains('id="btnCopyCloudPath"'));
      expect(tabHtml, contains('id="vaultSecondaryMirrorSummary"'));
      expect(auditModalHtml, contains('id="tbodyVaultAuditFiles"'));
      expect(auditModalHtml, contains('id="vaultAuditRecommendations"'));

      // Verificar CSS Fase 5 (ellipsis, spinner, print A4 limpio, tema claro)
      expect(css, contains('#txtMirrorPath'));
      expect(css, contains('text-overflow: ellipsis'));
      expect(css, contains('.btn.is-spinning svg'));
      expect(css, contains('height: auto !important;'));
      expect(css, contains('overflow: visible !important;'));
      expect(css, contains('[data-theme="light"] .vault-path-card'));

      // B. Preservar bloque puro APK intacto entre formatApkSizeMb y renderSignatureStatusBadge
      final apkStart = js.indexOf('function formatApkSizeMb(');
      final apkEnd = js.indexOf('function renderSignatureStatusBadge(');
      expect(apkStart, isPositive);
      expect(apkEnd, greaterThan(apkStart));

      // C. Extraer helpers JS y probar comportamiento real en Node.js
      final formatLimaJs = _extractJsBetween(
        js,
        'function formatLimaDateTime(',
        'function formatLimaIsoDate(',
      );
      final vaultStart = js.indexOf(
        '// ==========================================================================\n// FASE 3 PLAN MAESTRO 10 & PLAN MAESTRO 23 FASE 5: BÓVEDA Y PORTABILIDAD (#tabSecurityVault)',
      );
      expect(vaultStart, isPositive);
      final vaultJs = js.substring(vaultStart);
      expect(emojiRegex.hasMatch(vaultJs), isFalse,
          reason: 'No debe haber emojis crudos en bloque JS de bóveda');

      final harnessFile = File('${tempDir.path}/fase5_ui_test.js');
      harnessFile.writeAsStringSync('''
const assert = require('assert');

class MockClassList {
  constructor() { this.set = new Set(); }
  add(c) { this.set.add(c); }
  remove(c) { this.set.delete(c); }
  contains(c) { return this.set.has(c); }
}

class MockElement {
  constructor(id = '', tag = 'div') {
    this.id = id;
    this.tagName = tag.toUpperCase();
    this.value = '';
    this.checked = false;
    this.disabled = false;
    this.textContent = '';
    this.innerHTML = '';
    this.title = '';
    this.style = {};
    this.dataset = {};
    this.attrs = {};
    this.children = [];
    this.listeners = {};
    this.classList = new MockClassList();
  }
  addEventListener(ev, fn) {
    if (!this.listeners[ev]) this.listeners[ev] = [];
    this.listeners[ev].push(fn);
  }
  async dispatch(ev, extra = {}) {
    const fns = this.listeners[ev] || [];
    for (const fn of fns) {
      await fn({ target: this, preventDefault() {}, stopPropagation() {}, ...extra });
    }
  }
  appendChild(child) { this.children.push(child); return child; }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] || null; }
  click() {}
  remove() {}
  focus() {}
  closest() { return null; }
}

const elMap = {};
function el(id, tag = 'div') {
  if (!elMap[id]) elMap[id] = new MockElement(id, tag);
  return elMap[id];
}

// Registrar IDs esperados
[
  'btnRefreshVaultHealth', 'btnForceSyncMirrorTop', 'btnSyncMirrorNow', 'btnVaultAuditSyncNow',
  'btnCopyLocalPath', 'btnCopyMirrorPath', 'btnCopyCloudPath', 'btnBrowseCloudSyncPath',
  'btnSaveCloudSyncPath', 'btnDownloadMlKey', 'btnOpenRescueKitModal', 'btnEmergencyPrint',
  'btnCopyRescueCodes', 'btnExportVault', 'btnOpenImportVaultModal', 'btnSubmitImportVault',
  'btnAutoRecoverNow', 'txtLocalPath', 'txtMirrorPath', 'inputCloudSyncPath', 'pathCloudDir',
  'vaultHealthScore', 'vaultProgressBar', 'vaultHealthStatusText', 'vaultHealthBadge',
  'vaultSecondaryMirrorSummary', 'vaultRecoveryWarning', 'factorMirrorStatus', 'factorKeyStatus',
  'factorRescueStatus', 'factorPinStatus', 'badgeStep1Status', 'badgeStep2Status',
  'badgeStep3Status', 'mirrorLastSyncLabel', 'tbodyVaultFiles', 'chkEnablePin',
  'btnLockConsoleNow', 'pinSetupContainer', 'inputVaultPin', 'inputVaultPinConfirm',
  'btnSavePinConfig', 'formUnlockPin', 'vaultPinInput', 'vaultPinBackoffNotice',
  'linkForgotPin', 'vaultPinRecoveryPanel', 'recoveryKeyFileInput', 'btnRecoveryDpapi',
  'btnSubmitRecovery', 'modalVaultAuditReport', 'vaultAuditScoreBadge', 'vaultAuditTimestamp',
  'vaultAuditDpapiStatus', 'vaultAuditKeyringStatus', 'vaultAuditMirrorStatus',
  'vaultAuditMirrorTime', 'vaultAuditCloudStatus', 'vaultAuditCloudPath',
  'tbodyVaultAuditFiles', 'vaultAuditRecommendations', 'metaVaultVersion', 'metaVaultCreated',
  'metaVaultClients', 'metaVaultHasKey', 'metaVaultSlots', 'vaultInspectSummary',
  'vaultUnlockFactorSection', 'kitGeneratedDate', 'kitVaultId', 'rescueCodesGrid', 'rescueQrContainer'
].forEach(id => el(id));

const openedModals = [];
const closedModals = [];
const confirmCalls = [];
let copiedTexts = [];
let bootstrapCalls = 0;
let mockPinEnabled = false;
let mockFactors = { dpapi_enrolled: true, mlkey_enrolled: true, rescue_kit_enrolled: true, pin_enabled: false };
let mockCloudPath = '';

const store = {};
global.sessionStorage = {
  getItem: k => store[k] ?? null,
  setItem: (k, v) => { store[k] = String(v); },
  removeItem: k => { delete store[k]; },
};
global.navigator = { clipboard: { writeText: async txt => { copiedTexts.push(txt); } } };
global.URL = { createObjectURL: () => 'blob:mock', revokeObjectURL: () => {} };
global.Blob = class MockBlob { constructor(parts, opts) { this.parts = parts; this.opts = opts; } };
global.window = { URL: global.URL, print() {} };
global.document = {
  getElementById: id => elMap[id] || null,
  createElement: tag => new MockElement('', tag),
  querySelector: () => null,
  querySelectorAll: () => [],
  body: new MockElement('body', 'body'),
};

let ownerConfig = { system: { table_density: 'comfortable' } };
function showToast() {}
function openModal(id) { openedModals.push(id); }
function closeModal(id) { closedModals.push(id); }
function applyTableDensity() {}
function renderSafeQrCode() {}
function escapeHtml(s) { return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
async function bootstrapAuthenticatedWorkspace() { bootstrapCalls++; }
function showConfirmModal(title, msg, onConfirm, isDanger = false, onCancel = null) {
  confirmCalls.push({ title, msg, onConfirm, onCancel });
}

global.fetch = async (url, opts = {}) => {
  if (url === '/api/vault/health') {
    const score = ((mockFactors.dpapi_enrolled ? 1 : 0) + (mockFactors.mlkey_enrolled ? 1 : 0) + (mockFactors.rescue_kit_enrolled ? 1 : 0) + (mockPinEnabled ? 1 : 0)) * 25;
    return {
      ok: true,
      status: 200,
      json: async () => ({
        status: 'healthy',
        security_score: score,
        active_factors_count: score / 25,
        recovery_available: false,
        primary_storage_path: './data',
        mirror_storage_path: 'C:\\\\Users\\\\Test\\\\AppData\\\\Roaming\\\\MochilaListaAdminVault',
        mirror_exists: true,
        cloud_sync_path: mockCloudPath || null,
        cloud_mirror_active: !!mockCloudPath,
        keyring_info: {
          active_slots: [
            ...(mockFactors.dpapi_enrolled ? ['dpapi'] : []),
            ...(mockFactors.mlkey_enrolled ? ['mlkey'] : []),
            ...(mockFactors.rescue_kit_enrolled ? ['rescue_code'] : []),
            ...(mockPinEnabled ? ['pin'] : []),
          ],
        },
        factors: { ...mockFactors, pin_enabled: mockPinEnabled },
        mirror: { mirror_exists: true, mlvault_exists: true, last_sync: '2026-11-25T18:00:00.000Z' },
        cloud: { configured: !!mockCloudPath, accessible: !!mockCloudPath, cloud_path: mockCloudPath || null },
        files: {
          clients_db: { exists: true, size_bytes: 9984, modified: '2026-11-25T18:00:00.000Z', sha256: 'abc1234567890fedcba' },
          releases_db: { exists: true, size_bytes: 512, modified: '2026-11-25T18:00:00.000Z', sha256: 'def1234567890fedcba' },
          owner_config: { exists: true, size_bytes: 4096, modified: '2026-11-25T18:00:00.000Z', sha256: 'ghi1234567890fedcba' },
          master_key: { exists: true, size_bytes: 256, modified: '2026-11-25T18:00:00.000Z', sha256: 'jkl1234567890fedcba' },
          vault_keyring: { exists: true, size_bytes: 2048, modified: '2026-11-25T18:00:00.000Z', sha256: 'mno1234567890fedcba' },
        },
      }),
    };
  }
  if (url === '/api/vault/pin/status') {
    return { ok: true, status: 200, json: async () => ({ pin_enabled: mockPinEnabled, locked: false }) };
  }
  if (url === '/api/vault/audit') {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        audited_at: '2026-11-25T18:05:00.000Z',
        security_score: 75,
        active_factors_count: 3,
        matched_files_count: 5,
        total_critical_files: 5,
        dpapi: { valid: true },
        keyring: { version: '1.1.0', active_slots: ['dpapi', 'mlkey', 'rescue_code'] },
        mirror: { all_files_matched: true, last_sync: '2026-11-25T18:00:00.000Z' },
        cloud: { configured: false },
        files: {
          clients_db: { label: 'Cartera de Clientes', relative_path: 'data/prod_clients_db.json', exists: true, size_bytes: 9984, modified: '2026-11-25T18:00:00.000Z', sha256: 'abc1234567890fedcba', mirror_sha256: 'abc1234567890fedcba', mirror_parity: true },
        },
        recommendations: ['Recomendado: vincula nube local.'],
      }),
    };
  }
  if (url === '/api/vault/sync-mirror') {
    return { ok: true, status: 200, json: async () => ({ ok: true }) };
  }
  if (url === '/api/vault/generate-rescue-kit') {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        codes: ['ML-1111-2222-3333', 'ML-4444-5555-6666'],
        qr_key: 'MLQR-SECRET_MUST_NEVER_LEAK_INTO_KIT_ID',
      }),
    };
  }
  if (url === '/api/vault/inspect') {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        ok: true,
        metadata: {
          version: '1.1.0',
          created_at: '2026-11-25T18:00:00.000Z',
          includes_private_key: true,
          has_master_key: true,
          available_slots: ['dpapi', 'mlkey'],
          stats: { clients_count: 7, releases_count: 3 },
        },
      }),
    };
  }
  if (url === '/api/vault/pin/verify') {
    return { ok: true, status: 200, json: async () => ({ ok: true, session_token: 'TOKEN_PIN_OK' }) };
  }
  return { ok: true, status: 200, json: async () => ({ ok: true }) };
};

$formatLimaJs
$vaultJs

(async () => {
  initVaultEvents();

  // 1. Verificar loadVaultHealth + 6 <td> por fila + badges Step 1..3 + Cloud disabled
  await loadVaultHealth();
  assert.strictEqual(el('vaultHealthScore').textContent, '75%');
  assert.strictEqual(el('vaultHealthStatusText').textContent, '3 de 4 Factores Activos (Alta Protección)');
  assert.strictEqual(el('pathCloudDir').textContent, 'No configurada');
  assert.strictEqual(el('btnCopyCloudPath').disabled, true);
  assert.strictEqual(el('badgeStep1Status').textContent, 'Bóveda Espejo Activa');
  assert.strictEqual(el('badgeStep2Status').textContent, 'Llave Generada y Activa');
  assert.strictEqual(el('badgeStep3Status').textContent, '8 Códigos Activos');
  assert.ok(!el('mirrorLastSyncLabel').textContent.includes('Verificando...'));
  assert.ok(el('mirrorLastSyncLabel').textContent.includes('Lima GMT-5'));

  const tbody = el('tbodyVaultFiles');
  assert.strictEqual(tbody.children.length, 5);
  tbody.children.forEach(tr => {
    const tdCount = (tr.innerHTML.match(/<td[ >]/g) || []).length;
    assert.strictEqual(tdCount, 6, 'Cada fila de #tbodyVaultFiles debe tener 6 <td>');
  });
  assert.ok(tbody.children[0].innerHTML.includes('9.8 KB'));
  assert.ok(tbody.children[0].innerHTML.includes('Lima GMT-5'));
  assert.ok(tbody.children[0].innerHTML.includes('Base comercial de clientes'));

  // 2. Auditar Estado (#btnRefreshVaultHealth) abre modal ejecutivo
  await el('btnRefreshVaultHealth').dispatch('click');
  assert.ok(openedModals.includes('modalVaultAuditReport'));
  assert.strictEqual(el('vaultAuditScoreBadge').textContent, '75% · 3/4 Factores');

  // 3. Con nube activa, #btnCopyCloudPath se habilita y Paso 1 muestra Bóveda Espejo + Nube
  mockCloudPath = 'C:\\\\Users\\\\Test\\\\Dropbox\\\\ML';
  await loadVaultHealth();
  assert.strictEqual(el('pathCloudDir').textContent, mockCloudPath);
  assert.strictEqual(el('btnCopyCloudPath').disabled, false);

  // 4. Confirmación protectora anti-sobrescritura al regenerar .mlkey y Kit de Rescate
  await el('btnDownloadMlKey').dispatch('click');
  assert.strictEqual(confirmCalls.length, 1);
  assert.ok(confirmCalls[0].title.includes('Regenerar'));

  await el('btnOpenRescueKitModal').dispatch('click');
  assert.strictEqual(confirmCalls.length, 2);
  // Ejecutar confirmación del Kit y verificar que kitVaultId jamás incluya qr_key
  await confirmCalls[1].onConfirm();
  assert.ok(el('kitVaultId').textContent.startsWith('MLVAULT-'));
  assert.ok(!el('kitVaultId').textContent.includes('MLQR-'));
  assert.ok(!el('kitVaultId').textContent.includes('SECRET'));

  // 5. Fix metadata .mlvault en inspectLoadedVault()
  loadedVaultJson = '{"mock":true}';
  await inspectLoadedVault();
  assert.strictEqual(el('metaVaultVersion').textContent, '1.1.0');
  assert.strictEqual(el('metaVaultClients').textContent, '7 clientes · 3 lanzamientos');
  assert.ok(el('metaVaultCreated').textContent.includes('Lima GMT-5'));

  // 6. Cancelar desactivación de PIN revierte chkEnablePin.checked = true y submit PIN recarga workspace
  el('chkEnablePin').checked = false;
  await el('chkEnablePin').dispatch('change');
  assert.strictEqual(confirmCalls.length, 3);
  confirmCalls[2].onCancel();
  assert.strictEqual(el('chkEnablePin').checked, true);

  el('vaultPinInput').value = '4321';
  await el('formUnlockPin').dispatch('submit');
  assert.strictEqual(sessionStorage.getItem('ml_vault_session_token'), 'TOKEN_PIN_OK');
  assert.strictEqual(bootstrapCalls, 1);

  console.log('PLAN23_FASE5_UI_NODE_OK');
})();
''');

      final nodeRes = await Process.run('node', [harnessFile.path]);
      expect(
        nodeRes.exitCode,
        equals(0),
        reason: 'Node UI test Fase 5 falló:\nSTDOUT: ${nodeRes.stdout}\nSTDERR: ${nodeRes.stderr}',
      );
      expect(nodeRes.stdout.toString(), contains('PLAN23_FASE5_UI_NODE_OK'));
    });
  });
}
