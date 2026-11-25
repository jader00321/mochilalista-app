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

void main() {
  group('PLAN MAESTRO 23 - FASE 6: Caché APK Persistente, Verify-All e Higiene Git', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p23_fase6_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test(
        '1. Persistencia en disco (cache_version: 1), 2.ª instancia sin re-insp., invalidación size/mtime/forceRefresh, poda de ausentes, notas .txt vivas y JSON corrupto',
        () async {
      final apksDir = Directory('${tempDir.path}/apks')
        ..createSync(recursive: true);
      final sdkDir = Directory('${tempDir.path}/sdk/37.0.0')
        ..createSync(recursive: true);
      await File(
              '${sdkDir.path}/${Platform.isWindows ? 'aapt2.exe' : 'aapt2'}')
          .writeAsString('stub-aapt2');
      await File(
              '${sdkDir.path}/${Platform.isWindows ? 'apksigner.bat' : 'apksigner'}')
          .writeAsString('stub-apksigner');

      final cachePath = '${tempDir.path}/cache/.apk_inspection_cache.json';
      final apkA = File('${apksDir.path}/mochilalista_v9.41_atp.apk');
      await apkA.writeAsBytes(createTestZip([
        'AndroidManifest.xml',
        'lib/arm64-v8a/libapp.so',
        'lib/armeabi-v7a/libapp.so',
      ]));
      final apkB = File('${apksDir.path}/mochilalista_v9.40_atp.apk');
      await apkB.writeAsBytes(createTestZip([
        'AndroidManifest.xml',
        'lib/arm64-v8a/libapp.so',
      ]));

      final cambiosFile =
          File('${apksDir.path}/mochilalista_v9.41_atp_cambios.txt');
      await cambiosFile.writeAsString('Versión inicial 9.41 cambios v1');
      final atpNotesFile = File('${apksDir.path}/mochilalista_v9.41_atp.txt');
      await atpNotesFile.writeAsString('Notas técnicas internas v1');

      int toolCalls = 0;
      Future<ProcessResult> fakeRunner(String exe, List<String> args) async {
        toolCalls++;
        if (exe.contains('aapt2')) {
          final target = args.last;
          if (target.contains('9.41')) {
            return ProcessResult(
              1,
              0,
              "package: name='com.mochilalista.app' versionCode='85' versionName='9.41.0'\n"
              "sdkVersion:'24'\ntargetSdkVersion:'35'\n",
              '',
            );
          }
          return ProcessResult(
            1,
            0,
            "package: name='com.mochilalista.app' versionCode='84' versionName='9.40.0'\n"
            "sdkVersion:'24'\ntargetSdkVersion:'35'\n",
            '',
          );
        }
        return ProcessResult(
          1,
          0,
          'V2 Signer: certificate DN: CN=Julio Angello Vasquez Navarro\n'
          'V2 Signer: certificate SHA-256 digest: ${ApkInspectorService.officialSignerSha256}\n',
          '',
        );
      }

      // Instancia 1 (arranque en frío): inspecciona A y B y persiste cache JSON
      final firstInstance = ApkInspectorService(
        cacheFilePath: cachePath,
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        processRunnerOverride: fakeRunner,
      );
      await firstInstance.loadDiskCache();

      final resA1 = await firstInstance.inspectApk(apkA);
      final resB1 = await firstInstance.inspectApk(apkB);
      expect(resA1.success, isTrue);
      expect(resA1.versionName, equals('9.41.0'));
      expect(resA1.versionCode, equals(85));
      expect(resA1.abiVariant, equals('UNIVERSAL'));
      expect(resA1.signatureStatus, equals('OFFICIAL_RELEASE'));
      expect(resA1.suggestedChangelog, contains('cambios v1'));
      expect(resA1.suggestedInternalNotes, contains('internas v1'));
      expect(resB1.abiVariant, equals('ARM64'));
      expect(toolCalls, equals(4)); // aapt2 + apksigner por A y B

      // Validar estructura limpia cache_version: 1 sin notas compañeras cacheadas
      final cacheFile = File(cachePath);
      expect(cacheFile.existsSync(), isTrue);
      final rawJson =
          jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      expect(rawJson['cache_version'], equals(1));
      final entries = rawJson['entries'] as Map<String, dynamic>;
      final canonA = ApkInspectorService.canonicalizePath(apkA.path);
      final entryA = entries[canonA] as Map<String, dynamic>;
      expect(entryA.containsKey('size_bytes'), isTrue);
      expect(entryA.containsKey('modified_micros'), isTrue);
      expect(entryA.containsKey('inspected_at'), isTrue);
      expect(entryA.containsKey('version_name'), isTrue);
      expect(entryA.containsKey('version_code'), isTrue);
      expect(entryA.containsKey('abi_variant'), isTrue);
      expect(entryA.containsKey('sha256'), isTrue);
      expect(entryA.containsKey('signature_status'), isTrue);
      expect(entryA.containsKey('signature_verified'), isTrue);
      expect(entryA.containsKey('signer_sha256'), isTrue);
      expect(entryA.containsKey('signer_dn'), isTrue);
      expect(entryA.containsKey('signature_detail'), isTrue);
      expect(entryA.containsKey('db_schema_version'), isTrue);
      expect(entryA.containsKey('size_mb'), isTrue);
      expect(entryA.containsKey('suggested_release_type'), isTrue);
      expect(entryA.containsKey('suggested_changelog'), isFalse);
      expect(entryA.containsKey('suggested_internal_notes'), isFalse);

      // Editar notas compañeras sin tocar el APK
      await cambiosFile.writeAsString('Changelog actualizado EN VIVO v2');
      await atpNotesFile.writeAsString('Notas ATP actualizadas EN VIVO v2');

      // Instancia 2 nueva: debe resolver desde cacheFilePath con 0 llamadas a herramientas y notas .txt frescas
      toolCalls = 0;
      final secondInstance = ApkInspectorService(
        cacheFilePath: cachePath,
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        processRunnerOverride: fakeRunner,
      );
      await secondInstance.loadDiskCache();
      expect(secondInstance.liveCacheCount, equals(2));

      final resA2 = await secondInstance.inspectApk(apkA);
      expect(toolCalls, equals(0));
      expect(resA2.sha256, equals(resA1.sha256));
      expect(resA2.versionCode, equals(85));
      expect(resA2.signatureStatus, equals('OFFICIAL_RELEASE'));
      expect(resA2.suggestedChangelog, contains('EN VIVO v2'));
      expect(resA2.suggestedInternalNotes, contains('EN VIVO v2'));

      // Invalidación por cambio de mtime
      await apkA.setLastModified(DateTime.now().add(const Duration(minutes: 3)));
      final resMtime = await secondInstance.inspectApk(apkA);
      expect(toolCalls, equals(2));
      expect(resMtime.sha256, equals(resA1.sha256));

      // Invalidación por cambio de tamaño
      toolCalls = 0;
      await apkA.writeAsBytes(createTestZip([
        'AndroidManifest.xml',
        'lib/arm64-v8a/libapp_larger.so',
        'lib/armeabi-v7a/libapp_larger.so',
      ]));
      final resSize = await secondInstance.inspectApk(apkA);
      expect(toolCalls, equals(2));
      expect(resSize.sha256, isNot(equals(resA1.sha256)));

      // forceRefresh: true ignora hit de caché
      toolCalls = 0;
      await secondInstance.inspectApk(apkA, forceRefresh: true);
      expect(toolCalls, equals(2));

      // Eliminar apkB y agregar apkC -> poda automática de apkB al persistir
      await apkB.delete();
      final apkC = File('${apksDir.path}/mochilalista_v9.42_atp.apk');
      await apkC.writeAsBytes(createTestZip(['AndroidManifest.xml']));
      await secondInstance.inspectApk(apkC);
      final rawAfterPrune =
          jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      final entriesAfterPrune =
          rawAfterPrune['entries'] as Map<String, dynamic>;
      expect(
        entriesAfterPrune.containsKey(
            ApkInspectorService.canonicalizePath(apkB.path)),
        isFalse,
      );
      expect(
        entriesAfterPrune.containsKey(
            ApkInspectorService.canonicalizePath(apkC.path)),
        isTrue,
      );

      // Tolerancia segura a JSON corrupto
      await cacheFile.writeAsString('{ CORRUPT_JSON !!!');
      final corruptResilient = ApkInspectorService(
        cacheFilePath: cachePath,
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        processRunnerOverride: fakeRunner,
      );
      await corruptResilient.loadDiskCache();
      expect(corruptResilient.liveCacheCount, equals(0));
      toolCalls = 0;
      final rebuiltRes = await corruptResilient.inspectApk(apkA);
      expect(rebuiltRes.success, isTrue);
      expect(toolCalls, equals(2));
      expect(
        (jsonDecode(cacheFile.readAsStringSync())
            as Map<String, dynamic>)['cache_version'],
        equals(1),
      );
    });

    test(
        '2. Singleton server.dart + POST /api/releases/verify-all audita catálogo mixto con guardado consolidado',
        () async {
      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final apksDir = Directory('${tempDir.path}/apks')
        ..createSync(recursive: true);
      final sdkDir = Directory('${tempDir.path}/sdk/37.0.0')
        ..createSync(recursive: true);
      await File(
              '${sdkDir.path}/${Platform.isWindows ? 'apksigner.bat' : 'apksigner'}')
          .writeAsString('stub');

      final db = DatabaseService(
        dataDir: dataDir.path,
        backupDir: backupsDir.path,
        releasesDir: releasesDir,
      );
      await db.init();
      db.setMode('prod');

      final config =
          ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await config.init();

      final signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => (i * 13 + 7) % 256));
      final excel = ExcelExportService(dbService: db, configService: config);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dpapiService: MockDpapiService('TEST_P23_F6'),
        dbService: db,
        configService: config,
        signer: signer,
      );
      await vault.initialize();

      final univOfficial = File('${apksDir.path}/v941_univ_official.apk');
      await univOfficial.writeAsBytes(createTestZip([
        'AndroidManifest.xml',
        'lib/arm64-v8a/a.so',
        'lib/armeabi-v7a/a.so',
      ]));
      final armOfficial = File('${apksDir.path}/v941_arm64_official.apk');
      await armOfficial.writeAsBytes(createTestZip([
        'AndroidManifest.xml',
        'lib/arm64-v8a/a.so',
      ]));
      final debugApk = File('${apksDir.path}/v940_unofficial_debug.apk');
      await debugApk.writeAsBytes(createTestZip([
        'AndroidManifest.xml',
        'lib/arm64-v8a/b.so',
        'lib/armeabi-v7a/b.so',
      ]));
      final unverifiedApk = File('${apksDir.path}/v939_unverified.apk');
      await unverifiedApk.writeAsBytes(createTestZip([
        'AndroidManifest.xml',
      ]));
      final missingApk = File('${apksDir.path}/v938_missing.apk');
      await missingApk.writeAsBytes(createTestZip(['AndroidManifest.xml']));

      // Crear 4 versiones mixtas (al principio todas sin verificar)
      await db.createRelease({
        'version_name': '9.41.0',
        'version_code': 85,
        'abi_variant': 'UNIVERSAL',
        'apk_file_path': univOfficial.path,
        'universal_apk': {
          'file_path': univOfficial.path,
          'file_size_mb': '1.00 MB',
          'sha256': 'old',
          'signature_status': 'UNVERIFIED',
          'signature_verified': null,
          'file_exists': true,
        },
        'arm64_apk': {
          'file_path': armOfficial.path,
          'file_size_mb': '1.00 MB',
          'sha256': 'oldarm',
          'signature_status': 'UNVERIFIED',
          'signature_verified': null,
          'file_exists': true,
        },
        'signature_status': 'UNVERIFIED',
      });
      await db.createRelease({
        'version_name': '9.40.0',
        'version_code': 84,
        'abi_variant': 'UNIVERSAL',
        'apk_file_path': debugApk.path,
        'signature_status': 'OFFICIAL_RELEASE', // estado obsoleto a corregir
        'signature_verified': true,
      });
      await db.createRelease({
        'version_name': '9.39.0',
        'version_code': 83,
        'abi_variant': 'UNIVERSAL',
        'apk_file_path': unverifiedApk.path,
        'signature_status': 'OFFICIAL_RELEASE',
        'signature_verified': true,
      });
      await db.createRelease({
        'version_name': '9.38.0',
        'version_code': 82,
        'abi_variant': 'UNIVERSAL',
        'apk_file_path': missingApk.path,
        'signature_status': 'OFFICIAL_RELEASE',
        'signature_verified': true,
      });
      // Simular archivo extraviado en disco
      await missingApk.delete();

      final snapshotsBefore = backupsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith('prod_releases_'))
          .length;

      int inspectRunCount = 0;
      final tmpCache = '${tempDir.path}/cache/verify_all_cache.json';
      final testInspector = ApkInspectorService(
        cacheFilePath: tmpCache,
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        defaultBuildOutputDir:
            Directory('${tempDir.path}/empty_build')..createSync(recursive: true),
        processRunnerOverride: (exe, args) async {
          if (exe.contains('apksigner')) {
            inspectRunCount++;
            final target = args.last;
            if (target.contains('unofficial_debug')) {
              return ProcessResult(
                1,
                0,
                'V2 Signer: certificate DN: CN=Android Debug\n'
                'V2 Signer: certificate SHA-256 digest: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n',
                '',
              );
            }
            if (target.contains('official')) {
              return ProcessResult(
                1,
                0,
                'V2 Signer: certificate DN: CN=Julio Angello Vasquez Navarro\n'
                'V2 Signer: certificate SHA-256 digest: ${ApkInspectorService.officialSignerSha256}\n',
                '',
              );
            }
            return ProcessResult(2, 1, '', 'verify error');
          }
          return ProcessResult(2, 1, '', 'no aapt2');
        },
      );
      await testInspector.loadDiskCache();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            config,
            excel,
            vault,
            apkInspectorService: testInspector,
          ));

      final client = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';
      try {
        final req = await client.postUrl(
            Uri.parse('$baseUrl/api/releases/verify-all'));
        req.headers.add('X-App-Mode', 'prod');
        req.headers.contentType = ContentType.json;
        req.write('{}');
        final res = await req.close();
        expect(res.statusCode, equals(200));
        final json =
            jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;

        expect(json['ok'], isTrue);
        expect(json['total'], equals(4));
        expect(json['official_count'], equals(1));
        expect(json['unofficial_count'], equals(1));
        expect(json['unverified_count'], equals(1));
        expect(json['missing_count'], equals(1));
        expect(json['updated_count'], equals(4));
        expect(json['duration_ms'], isA<int>());
        expect((json['items'] as List).length, equals(4));
        expect((json['releases'] as List).length, equals(4));

        // Guardado único consolidado: a lo mucho +1 snapshot, jamás +4
        final snapshotsAfterFirst = backupsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last.startsWith('prod_releases_'))
            .length;
        expect(snapshotsAfterFirst - snapshotsBefore, equals(1));

        final afterReleases = await db.getReleases();
        final rel941 =
            afterReleases.firstWhere((r) => r['version_name'] == '9.41.0');
        expect(rel941['signature_status'], equals('OFFICIAL_RELEASE'));
        expect(rel941['universal_apk']['file_exists'], isTrue);
        expect(rel941['arm64_apk']['file_exists'], isTrue);

        final rel938 =
            afterReleases.firstWhere((r) => r['version_name'] == '9.38.0');
        expect(rel938['file_exists'], isFalse);

        // Segunda corrida sin cambios: 0 actualizaciones, 0 snapshots adicionales, 0 ejecuciones apksigner
        final runsAfterFirst = inspectRunCount;
        final req2 = await client.postUrl(
            Uri.parse('$baseUrl/api/releases/verify-all'));
        req2.headers.add('X-App-Mode', 'prod');
        final res2 = await req2.close();
        final json2 =
            jsonDecode(await utf8.decodeStream(res2)) as Map<String, dynamic>;
        expect(json2['updated_count'], equals(0));
        expect(inspectRunCount, equals(runsAfterFirst));
        final snapshotsAfterSecond = backupsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last.startsWith('prod_releases_'))
            .length;
        expect(snapshotsAfterSecond, equals(snapshotsAfterFirst));

        // ?force=true fuerza re-inspección sin caché
        final reqForce = await client.postUrl(
            Uri.parse('$baseUrl/api/releases/verify-all?force=true'));
        reqForce.headers.add('X-App-Mode', 'prod');
        final resForce = await reqForce.close();
        expect(resForce.statusCode, equals(200));
        await resForce.drain();
        expect(inspectRunCount, greaterThan(runsAfterFirst));
      } finally {
        client.close(force: true);
        await server.close(force: true);
      }
    });

    test(
        '3. Auditoría HTML/CSS/JS, higiene server.dart/.gitignore y ejecución real Node.js de #btnVerifyAllReleases',
        () async {
      final serverSrc = File('server.dart').readAsStringSync();
      expect(
        serverSrc,
        contains("cacheFilePath: 'data/.apk_inspection_cache.json'"),
      );
      expect(serverSrc, contains('await apkInspector.loadDiskCache();'));
      expect(serverSrc, contains('apkInspectorService: apkInspector,'));

      final adminGitignore = File('.gitignore').readAsStringSync();
      expect(adminGitignore, contains('data/.apk_inspection_cache.json'));
      final rootGitignore = File('../.gitignore').readAsStringSync();
      expect(rootGitignore, contains('mochilalista_admin/data/.apk_inspection_cache.json'));

      final html = File('web/index.html').readAsStringSync();
      final css = File('web/css/styles.css').readAsStringSync();
      final js = File('web/js/admin_app.js').readAsStringSync();

      final releaseTabStart = html.indexOf('<section id="tabReleaseManager"');
      final releaseTabEnd = html.indexOf('</section>', releaseTabStart);
      final releaseHtml = html.substring(releaseTabStart, releaseTabEnd);

      expect(releaseHtml, contains('id="btnVerifyAllReleases"'));
      expect(releaseHtml, contains('Verificar Todo el Catálogo'));
      expect(releaseHtml, contains('id="catalogVerifyAllBanner"'));

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      expect(emojiRegex.hasMatch(releaseHtml), isFalse);

      expect(css, contains('.catalog-verify-banner'));
      expect(css, contains('.catalog-verify-banner.is-running'));
      expect(css, contains('.catalog-verify-banner.is-success'));
      expect(css, contains('.catalog-verify-banner.is-warning'));
      expect(css, contains('.catalog-verify-banner.is-error'));
      expect(css, contains('[data-theme="light"] .catalog-verify-banner'));
      expect(css, contains('[data-theme="light"] .catalog-verify-pill'));

      final startMarker = 'let isVerifyAllCatalogRunning = false;';
      final endMarker = '/**\n * Carga notas compañeras';
      final sIdx = js.indexOf(startMarker);
      final eIdx = js.indexOf(endMarker, sIdx + 1);
      expect(sIdx, isPositive);
      expect(eIdx, greaterThan(sIdx));
      final verifyAllJs = js.substring(sIdx, eIdx);
      expect(emojiRegex.hasMatch(verifyAllJs), isFalse);

      final nodeScript = File('${tempDir.path}/fase6_verify_all_ui.js');
      nodeScript.writeAsStringSync('''
const assert = require('assert');
const elMap = {};
function makeEl(id) {
  return {
    id,
    disabled: false,
    innerHTML: '',
    className: '',
    style: { display: 'none' },
    classList: {
      set: new Set(),
      add(c) { this.set.add(c); },
      remove(c) { this.set.delete(c); },
      contains(c) { return this.set.has(c); }
    },
    addEventListener() {}
  };
}
elMap.btnVerifyAllReleases = makeEl('btnVerifyAllReleases');
elMap.btnVerifyAllReleases.innerHTML = '<span>Verificar Todo el Catálogo</span>';
elMap.catalogVerifyAllBanner = makeEl('catalogVerifyAllBanner');
elMap.modalWaComposer = makeEl('modalWaComposer');
elMap.modalWaComposer.classList.add('open');
elMap.modalEditRelease = makeEl('modalEditRelease');

global.document = { getElementById: (id) => elMap[id] || null };
let currentMode = 'prod';
let globalReleases = [];
let currentDispatchRelease = { version_name: '9.41.0', signature_status: 'UNVERIFIED' };
let isApkDispatchMode = true;
let loadReleasesCalls = 0;
let loadMatrixCalls = 0;
let syncedWaRelease = null;
const toasts = [];
function escapeHtml(s) { return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
function showToast(msg, type) { toasts.push({ msg, type }); }
async function loadReleases() { loadReleasesCalls++; }
async function loadReleaseMatrix() { loadMatrixCalls++; }
function syncWaApkDispatchPanel(rel) { syncedWaRelease = rel; }

global.fetch = async (url, opts) => {
  assert.strictEqual(url, '/api/releases/verify-all');
  assert.strictEqual(opts.method, 'POST');
  assert.strictEqual(elMap.btnVerifyAllReleases.disabled, true);
  assert.strictEqual(elMap.btnVerifyAllReleases.classList.contains('is-spinning'), true);
  assert.ok(elMap.catalogVerifyAllBanner.className.includes('is-running'));
  return {
    ok: true,
    status: 200,
    json: async () => ({
      ok: true,
      total: 3,
      official_count: 2,
      unofficial_count: 0,
      unverified_count: 0,
      missing_count: 1,
      updated_count: 2,
      duration_ms: 42,
      releases: [{ version_name: '9.41.0', signature_status: 'OFFICIAL_RELEASE' }],
    }),
  };
};

$verifyAllJs

(async () => {
  await verifyAllReleasesCatalog(false);
  assert.strictEqual(loadReleasesCalls, 1);
  assert.strictEqual(loadMatrixCalls, 1);
  assert.strictEqual(syncedWaRelease.signature_status, 'OFFICIAL_RELEASE');
  assert.strictEqual(elMap.btnVerifyAllReleases.disabled, false);
  assert.strictEqual(elMap.btnVerifyAllReleases.classList.contains('is-spinning'), false);
  assert.ok(elMap.catalogVerifyAllBanner.className.includes('is-warning'));
  assert.ok(elMap.catalogVerifyAllBanner.innerHTML.includes('Catálogo auditado (3 versiones): 2 Oficiales RSA-4096 · 0 No Oficiales · 0 Sin Verificar · 1 Extraviados en disco'));
  assert.ok(elMap.catalogVerifyAllBanner.innerHTML.includes('42 ms'));
  assert.strictEqual(toasts[0].type, 'warning');
  dismissCatalogVerifyAllBanner();
  assert.strictEqual(elMap.catalogVerifyAllBanner.style.display, 'none');
  console.log('PLAN23_FASE6_UI_NODE_OK');
})();
''');

      final nodeRes = await Process.run('node', [nodeScript.path]);
      expect(
        nodeRes.exitCode,
        equals(0),
        reason:
            'Node UI test Fase 6 falló:\nSTDOUT: ${nodeRes.stdout}\nSTDERR: ${nodeRes.stderr}',
      );
      expect(nodeRes.stdout.toString(), contains('PLAN23_FASE6_UI_NODE_OK'));
    });
  });
}
