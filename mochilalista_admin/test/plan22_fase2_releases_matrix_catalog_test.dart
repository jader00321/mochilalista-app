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
  group('PLAN MAESTRO 22 - FASE 2: #tabReleaseManager, Matriz, Catálogo y #modalEditRelease', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p22_fase2_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. CSS: Erradicación de lupa gigante (.search-icon) y utilidades Fase 2
    // =========================================================================
    test('1. CSS: .search-icon acotado (16px), position absolute, padding-left y clases Fase 2', () {
      final css = WebBundleLoader.loadCss();

      expect(css, contains('.search-input-wrap'));
      expect(css, contains('.search-icon'));
      expect(css, contains('.search-input-wrap .search-icon'));

      final searchIconIdx = css.indexOf('.search-icon,');
      expect(searchIconIdx, greaterThan(0));
      final searchSection = css.substring(searchIconIdx, searchIconIdx + 900);
      expect(searchSection, contains('position: absolute'));
      expect(searchSection, contains('width: 16px'));
      expect(searchSection, contains('height: 16px'));
      expect(searchSection, contains('min-width: 16px'));
      expect(searchSection, contains('max-width: 16px'));
      expect(searchSection, contains('pointer-events: none'));
      expect(searchSection, contains('padding-left: 2.35rem'));
      expect(searchSection, contains('#inputRelMatrixSearch'));

      // Clases nuevas de Fase 2
      expect(css, contains('.btn-xs'));
      expect(css, contains('.toast-action-btn'));
      expect(css, contains('.release-actions-row'));
      expect(css, contains('flex-wrap: nowrap'));
      expect(css, contains('.release-adoption-pill'));
      expect(css, contains('.matrix-installed-ver-cell'));
      expect(css, contains('.btn-micro-edit-ver'));
      expect(css, contains('.edit-variant-card'));
      expect(css, contains('.edit-variant-local-picker'));
      expect(css, contains('.badge-disk-ok'));
      expect(css, contains('.badge-disk-missing'));
      expect(css, contains('.badge-origin-lib'));
      expect(css, contains('.badge-origin-local'));
      expect(css, contains('.badge-unverified-sig'));
    });

    // =========================================================================
    // 2. HTML: SVG dimensionados y controles de Fase 2 sin emojis crudos
    // =========================================================================
    test('2. HTML: SVG dimensionados en #tabReleaseManager y modales Fase 2 sin emojis crudos', () {
      final html = WebBundleLoader.loadHtml();

      // Modal corregir versión instalada sin window.prompt
      expect(html, contains('id="modalFixClientVersion"'));
      expect(html, contains('id="fixClientVersionSelect"'));
      expect(html, contains('id="fixClientVersionInput"'));
      expect(html, contains('id="btnSubmitFixClientVersion"'));

      // Botones de recarga rápida de notas compañeras en Crear y Editar Release
      expect(html, contains('id="btnCreateLoadCambiosTxt"'));
      expect(html, contains('id="btnCreateLoadAtpTxt"'));
      expect(html, contains('id="btnEditLoadCambiosTxt"'));
      expect(html, contains('id="btnEditLoadAtpTxt"'));

      // Lupa acotada explícitamente en #tabReleaseManager
      final tabStart = html.indexOf('id="tabReleaseManager"');
      final tabEnd = html.indexOf('id="tabInspector"');
      expect(tabStart, greaterThan(0));
      expect(tabEnd, greaterThan(tabStart));
      final releaseTabHtml = html.substring(tabStart, tabEnd);
      expect(releaseTabHtml, contains('<svg class="search-icon" width="16" height="16"'));

      // Verificar que todo <svg> dentro de #tabReleaseManager, #modalCreateRelease, #modalEditRelease y #modalFixClientVersion
      // tenga clase dimensionada o atributos width/height explícitos
      final createStart = html.indexOf('id="modalCreateRelease"');
      final fixEnd = html.indexOf('id="modalConfirmLicenseEmission"');
      final modalsHtml = html.substring(createStart, fixEnd);
      final svgTagRegex = RegExp(r'<svg\b[^>]*>');
      for (final chunk in [releaseTabHtml, modalsHtml]) {
        for (final match in svgTagRegex.allMatches(chunk)) {
          final tag = match.group(0)!;
          final hasBounds = tag.contains('width=') ||
              tag.contains('width:') ||
              tag.contains('icon-svg') ||
              tag.contains('btn-icon') ||
              tag.contains('search-icon');
          expect(hasBounds, isTrue, reason: 'SVG sin dimensiones explícitas o clase acotada: $tag');
        }
      }

      // Auditoría de cero emojis crudos en secciones HTML de Fase 2
      final bannedEmojis = ['✅', '❌', '⚠️', 'ℹ️', '⬇️', '📁', '✏️', '🗑️', '📲', '🚀', '📦', '🛡️', '🔍', '✓'];
      for (final emoji in bannedEmojis) {
        expect(releaseTabHtml, isNot(contains(emoji)), reason: 'Emoji crudo $emoji detectado en #tabReleaseManager');
        expect(modalsHtml, isNot(contains(emoji)), reason: 'Emoji crudo $emoji detectado en modales de Fase 2');
      }
    });

    // =========================================================================
    // 3. JS: Autodetección sin onclick roto, 3 estados, Matriz, Catálogo y #modalEditRelease
    // =========================================================================
    test('3. JS: Sin rutas Windows en onclick, 3 estados de firma, SemVer, Matriz, Catálogo y #modalEditRelease', () async {
      final js = WebBundleLoader.loadJs();

      // Prohibición estricta del bug Windows onclick="importLocalApkDirectly(...)"
      expect(js, isNot(contains('onclick="importLocalApkDirectly(')));
      expect(js, isNot(contains("onclick='importLocalApkDirectly(")));
      expect(js, contains('btn.dataset.sourcePath'));
      expect(js, contains('importBtn.dataset.sourcePath = b.file_path'));
      expect(js, contains('Biblioteca Oficial'));
      expect(js, contains('Build Local'));
      expect(js, contains('duplicate_paths'));

      // Escudo de firma honesto de 3 estados
      expect(js, contains('Firma Comercial Oficial Verificada (RSA-4096)'));
      expect(js, contains('¡ATENCIÓN! Este APK no cuenta con la firma comercial oficial (posible debug.apk)'));
      expect(js, contains('Firma no verificable en este entorno'));

      // Auto-selección SemVer y notas técnicas en populateCreateReleaseFormFromInspection
      expect(js, contains('function inferReleaseTypeFromSemVer'));
      expect(js, contains('data.suggested_release_type'));
      expect(js, contains('data.suggested_internal_notes'));
      expect(js, contains('data.suggested_changelog'));

      // Matriz: Reenviar / Elegir APK en UP_TO_DATE y AHEAD + Toast Deshacer + lápiz sin window.prompt
      expect(js, contains('Reenviar / Elegir APK'));
      expect(js, contains("openApkDispatchComposer('\${escapeHtml(row.client_id)}', '\${escapeHtml(row.latest_version)}', 'resend')"));
      expect(js, contains("actionLabel: 'Deshacer'"));
      expect(js, contains('force: force'));
      expect(js, contains('openFixClientVersionModal'));
      expect(js, contains('Corregir versión instalada'));
      expect(js, isNot(contains('window.prompt(')));
      expect(js, isNot(contains('>✓ Al Día<')));

      // Catálogo: formatApkSizeMb, nowrap, adopción N clientes, Verificar
      expect(js, contains('function formatApkSizeMb'));
      expect(js, contains('class="release-actions-row"'));
      expect(js, contains('flex-wrap:nowrap'));
      expect(js, contains('release-adoption-pill'));
      expect(js, contains('function verifyReleaseIntegrity'));
      expect(js, contains('/verify'));

      // #modalEditRelease potenciado
      expect(js, contains('function buildEditVariantCardHtml'));
      expect(js, contains('Verificado en disco'));
      expect(js, contains('No encontrado'));
      expect(js, contains('Copiar SHA'));
      expect(js, contains('Re-verificar'));
      expect(js, contains('Subir desde PC'));
      expect(js, contains('Vincular desde Biblioteca Local'));
      expect(js, contains('linkLocalBuildToReleaseVariant'));
      expect(js, contains('loadCompanionNoteIntoField'));
      expect(js, contains('/companion-notes'));

      // Auditoría de cero emojis crudos en bloques JS de Fase 2
      final bannedEmojis = ['✅', '❌', '⚠️', 'ℹ️', '⬇️', '📁', '✏️', '🗑️', '📲', '🚀', '📦', '🛡️', '🔍'];
      final toastStart = js.indexOf('function showToast(');
      final toastEnd = js.indexOf('let confirmCallback = null;');
      final releaseStart = js.indexOf('function formatApkSizeMb(');
      final releaseEnd = js.indexOf('// =================== 5. INSPECTOR');
      final createSubmitStart = js.indexOf("document.getElementById('btnOpenCreateRelease')");
      final createSubmitEnd = js.indexOf("document.getElementById('btnSubmitEditRelease')");

      for (final chunk in [
        js.substring(toastStart, toastEnd),
        js.substring(releaseStart, releaseEnd),
        js.substring(createSubmitStart, createSubmitEnd),
      ]) {
        for (final emoji in bannedEmojis) {
          expect(chunk, isNot(contains(emoji)), reason: 'Emoji crudo $emoji detectado en módulo JS de Fase 2');
        }
      }

      // Ejecutar pruebas unitarias reales en Node.js sobre formatApkSizeMb e inferReleaseTypeFromSemVer
      final fmtStart = js.indexOf('function formatApkSizeMb(');
      final fmtEnd = js.indexOf('function renderSignatureStatusBadge(');
      final helperCode = js.substring(fmtStart, fmtEnd);
      final nodeEval = await Process.run('node', [
        '-e',
        '''
$helperCode
const assert = require('assert');
assert.strictEqual(formatApkSizeMb("108.86"), "108.86 MB");
assert.strictEqual(formatApkSizeMb("109.80 MB"), "109.80 MB");
assert.strictEqual(formatApkSizeMb(108.47), "108.47 MB");
assert.strictEqual(formatApkSizeMb(""), "-");
assert.strictEqual(formatApkSizeMb(null), "-");
assert.strictEqual(formatApkSizeMb("-"), "-");
assert.strictEqual(inferReleaseTypeFromSemVer("9.40.0"), "FEATURE_RELEASE");
assert.strictEqual(inferReleaseTypeFromSemVer("9.40.1"), "HOTFIX");
assert.strictEqual(inferReleaseTypeFromSemVer("v9.38.2+83"), "HOTFIX");
console.log("JS_HELPERS_OK");
'''
      ]);
      expect(nodeEval.exitCode, equals(0), reason: 'Error ejecutando helpers JS: ${nodeEval.stderr}');
      expect(nodeEval.stdout.toString(), contains('JS_HELPERS_OK'));
    });

    // =========================================================================
    // 4. Integración HTTP aislada para los flujos de Fase 2 en Directory.systemTemp
    // =========================================================================
    test('4. Integración HTTP aislada: import local, verify, companion-notes, link variante y undo force', () async {
      final dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final libDir = Directory('${tempDir.path}/apk_lib')..createSync(recursive: true);

      final db = DatabaseService(dataDir: dataDir.path, backupDir: backupsDir.path, releasesDir: releasesDir);
      await db.init();

      final config = ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await config.init();
      await config.saveConfig({
        'system': {'apk_library_dir': libDir.path},
      });

      final signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => (i * 17 + 3) % 256));
      final excel = ExcelExportService(dbService: db, configService: config);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dpapiService: MockDpapiService('TEST_P22_F2'),
        dbService: db,
        configService: config,
        signer: signer,
      );
      await vault.initialize();

      final sdkDir = Directory('${tempDir.path}/sdk/37.0.0')..createSync(recursive: true);
      final exeName = Platform.isWindows ? 'apksigner.bat' : 'apksigner';
      await File('${sdkDir.path}/$exeName').writeAsString('echo mock');

      final inspector = ApkInspectorService(
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        defaultBuildOutputDir: Directory('${tempDir.path}/empty_build')..createSync(recursive: true),
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('apksigner')) {
            return ProcessResult(
              1,
              0,
              'V2 Signer: certificate DN: CN=Julio Angello Vasquez Navarro\n'
              'V2 Signer: certificate SHA-256 digest: ${ApkInspectorService.officialSignerSha256}\n',
              '',
            );
          }
          return ProcessResult(2, 1, '', 'no aapt2');
        },
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
            onCopyFileOverride: (_) async => true,
          ));

      final httpClient = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';

      try {
        final univApk = File('${libDir.path}/mochilalista_v9.40_atp.apk');
        await univApk.writeAsBytes(createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/a.so', 'lib/armeabi-v7a/a.so']));
        final armApk = File('${libDir.path}/mochilalista_v9.40_arm64.apk');
        await armApk.writeAsBytes(createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/a.so']));
        await File('${libDir.path}/mochilalista_v9.40_atp_cambios.txt')
            .writeAsString('Resumen comercial v9.40 para WhatsApp');
        await File('${libDir.path}/mochilalista_v9.40_atp.txt')
            .writeAsString('Ficha técnica interna v9.40.0+84');

        // A) Autodetección y posterior importación sin deformación de ruta
        final detectReq = await httpClient.getUrl(Uri.parse('$baseUrl/api/releases/detect-local-build'));
        final detectRes = await detectReq.close();
        expect(detectRes.statusCode, equals(200));
        final detectJson = jsonDecode(await utf8.decodeStream(detectRes)) as Map<String, dynamic>;
        final builds = (detectJson['available_builds'] as List).cast<Map<String, dynamic>>();
        expect(builds.length, equals(2));

        final armBuild = builds.firstWhere((b) => b['abi_variant'] == 'ARM64');
        final impReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/releases/import-local-apk'));
        impReq.headers.contentType = ContentType.json;
        impReq.write(jsonEncode({'source_path': armBuild['file_path']}));
        final impRes = await impReq.close();
        expect(impRes.statusCode, equals(200));
        final impJson = jsonDecode(await utf8.decodeStream(impRes)) as Map<String, dynamic>;
        expect(impJson['ok'], isTrue);
        expect(impJson['abi_variant'], equals('ARM64'));

        // B) Crear release legacy y re-verificarlo + vincular variante local vía PUT + cargar notas separadas
        await db.createRelease({
          'version_name': '9.40.0',
          'version_code': 84,
          'type': 'FEATURE_RELEASE',
          'apk_file_path': univApk.path,
          'file_size_mb': '108.47',
          'signature_status': 'UNVERIFIED',
          'signature_verified': null,
        });

        final verReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/releases/9.40.0/verify'));
        final verRes = await verReq.close();
        expect(verRes.statusCode, equals(200));
        final verJson = jsonDecode(await utf8.decodeStream(verRes)) as Map<String, dynamic>;
        expect(verJson['release']['signature_status'], equals('OFFICIAL_RELEASE'));
        expect(verJson['release']['universal_apk']['file_exists'], isTrue);

        final putReq = await httpClient.putUrl(Uri.parse('$baseUrl/api/releases/9.40.0'));
        putReq.headers.contentType = ContentType.json;
        putReq.write(jsonEncode({
          'arm64_apk': {
            'file_path': impJson['imported_path'],
            'file_size_mb': impJson['size_mb'],
            'sha256': impJson['sha256'],
            'signature_status': impJson['signature_status'],
            'signature_verified': impJson['signature_verified'],
            'file_exists': true,
          },
        }));
        final putRes = await putReq.close();
        expect(putRes.statusCode, equals(200));
        final putJson = jsonDecode(await utf8.decodeStream(putRes)) as Map<String, dynamic>;
        expect(putJson['arm64_apk']['file_exists'], isTrue);

        // C) Notas compañeras separadas
        final notesReq = await httpClient.getUrl(Uri.parse('$baseUrl/api/releases/9.40.0/companion-notes'));
        final notesRes = await notesReq.close();
        final notesJson = jsonDecode(await utf8.decodeStream(notesRes)) as Map<String, dynamic>;
        expect(notesJson['suggested_changelog'], contains('Resumen comercial v9.40'));
        expect(notesJson['suggested_internal_notes'], contains('Ficha técnica interna v9.40'));
        expect(notesJson['suggested_changelog'], isNot(contains('Ficha técnica interna')));

        // D) Flujo Deshacer en Marcar Actualizado (mark-updated -> force revert)
        final clients = await db.getClients();
        final cid = clients.first['id'] as String;
        await db.markClientUpdated(cid, '9.35.0', force: true);

        final upReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/clients/$cid/mark-updated'));
        upReq.headers.contentType = ContentType.json;
        upReq.write(jsonEncode({'version_name': '9.40.0'}));
        final upRes = await upReq.close();
        final upJson = jsonDecode(await utf8.decodeStream(upRes)) as Map<String, dynamic>;
        expect(upJson['installed_version'], equals('9.40.0'));
        expect(upJson['previous_installed_version'], equals('9.35.0'));

        final undoReq = await httpClient.postUrl(Uri.parse('$baseUrl/api/clients/$cid/mark-updated'));
        undoReq.headers.contentType = ContentType.json;
        undoReq.write(jsonEncode({
          'version_name': upJson['previous_installed_version'],
          'force': true,
        }));
        final undoRes = await undoReq.close();
        final undoJson = jsonDecode(await utf8.decodeStream(undoRes)) as Map<String, dynamic>;
        expect(undoJson['installed_version'], equals('9.35.0'));
        expect(undoJson['force_applied'], isTrue);
      } finally {
        httpClient.close(force: true);
        await server.close(force: true);
      }
    });
  });
}
