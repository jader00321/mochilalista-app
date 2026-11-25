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
  group(
      'PLAN MAESTRO 22.5 - FASE 1: Rutas Configurables, Autodetección Recursiva, Endpoints y Variantes',
      () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_p22_5_fase1_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    // =========================================================================
    // 1. ConfigService: Retrocompatibilidad, apk_search_dirs y Lista Negra
    // =========================================================================
    test(
        '1. ConfigService: retrocompatibilidad apk_library_dir <-> apk_search_dirs, save/reset y lista negra',
        () async {
      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);

      final config = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await config.init();

      // A) Migración transparente sin apk_search_dirs persistido aún
      final defaults = config.getEffectiveApkSearchDirs(
        defaultBuildOutputDir: '${tempDir.path}/flutter_build',
      );
      expect(defaults.length, equals(2));
      expect(defaults.first.kind, equals('official_library'));
      expect(defaults.last.kind, equals('flutter_build'));

      // B) Sincronización cuando se guarda solo system.apk_library_dir (legacy/tests)
      final customLib = Directory('${tempDir.path}/mi_biblioteca')
        ..createSync(recursive: true);
      await config.saveConfig({
        'system': {'apk_library_dir': customLib.path},
      });
      final synced = config.getEffectiveApkSearchDirs(
        defaultBuildOutputDir: '${tempDir.path}/flutter_build',
      );
      expect(
        ApkInspectorService.canonicalizePath(synced.first.path),
        equals(ApkInspectorService.canonicalizePath(customLib.path)),
      );

      // C) Guardar múltiples rutas con deduplicación y recarga desde disco
      final extraFolder = Directory('${tempDir.path}/Builds Especiales/Ñandú')
        ..createSync(recursive: true);
      await config.saveApkSearchDirs([
        {
          'path': customLib.path,
          'label': 'Biblioteca Principal',
          'enabled': true,
          'is_default': true,
          'kind': 'official_library',
        },
        {
          'path': extraFolder.path,
          'label': 'Carpeta Ñandú',
          'enabled': true,
          'is_default': false,
          'kind': 'custom',
        },
        // Duplicado con segmento '..' que debe colapsarse
        {
          'path': '${extraFolder.path}/../Ñandú',
          'label': 'Duplicado',
          'enabled': true,
          'is_default': false,
          'kind': 'custom',
        },
      ]);

      final reloaded = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await reloaded.init();
      final loadedDirs = reloaded.getEffectiveApkSearchDirs();
      expect(loadedDirs.length, equals(2));
      expect(loadedDirs.last.label, equals('Carpeta Ñandú'));
      expect(reloaded.apkLibraryDir,
          equals(ApkInspectorService.canonicalizePath(customLib.path)));

      // D) Lista negra de seguridad (Salvaguarda Paso 0: raíces de disco + rutas sensibles)
      expect(config.isForbiddenApkSearchDir(''), isTrue);
      expect(config.isForbiddenApkSearchDir(r'C:\'), isTrue);
      expect(config.isForbiddenApkSearchDir('C:'), isTrue);
      expect(config.isForbiddenApkSearchDir(r'D:\'), isTrue);
      expect(config.isForbiddenApkSearchDir('/'), isTrue);
      expect(config.isForbiddenApkSearchDir(dataDir.path), isTrue);
      expect(config.isForbiddenApkSearchDir(backupsDir.path), isTrue);
      expect(
          config.isForbiddenApkSearchDir('${tempDir.path}/private_keys'), isTrue);
      expect(
          config.isForbiddenApkSearchDir('../app_movil/android'), isTrue);
      if (Platform.isWindows) {
        expect(config.isForbiddenApkSearchDir(r'C:\Windows'), isTrue);
        expect(config.isForbiddenApkSearchDir(r'C:\Windows\System32'), isTrue);
      }
      expect(config.isForbiddenApkSearchDir(extraFolder.path), isFalse);

      // Intentar guardar ruta prohibida lanza InvalidApkSearchDirException
      await expectLater(
        () => config.saveApkSearchDirs([
          {'path': r'C:\', 'label': 'Disco'}
        ]),
        throwsA(isA<InvalidApkSearchDirException>()),
      );

      // E) Restablecer rutas por defecto
      final resetDirs = await config.resetApkSearchDirsToDefaults(
        defaultBuildOutputDir: '${tempDir.path}/flutter_build',
      );
      expect(resetDirs.length, equals(2));
      expect(resetDirs.first.kind, equals('official_library'));
      expect(resetDirs.last.kind, equals('flutter_build'));
    });

    // =========================================================================
    // 2. ApkInspectorService: Recursividad acotada, skip list, dedup, filtros y ranking
    // =========================================================================
    test(
        '2. ApkInspectorService: escaneo recursivo maxDepth, skip list, dedup SHA-256, ranking SemVer+fecha, filtros ABI/query/limit y per_dir_stats',
        () async {
      final libDir = Directory('${tempDir.path}/lib_oficial')
        ..createSync(recursive: true);
      final customDir = Directory('${tempDir.path}/custom_builds')
        ..createSync(recursive: true);
      final buildDir = Directory('${tempDir.path}/flutter_build')
        ..createSync(recursive: true);
      final missingDir = Directory('${tempDir.path}/carpeta_inexistente');

      // Subcarpetas dentro de customDir (depth 1, 2, 3 y 4)
      final depth1 = Directory('${customDir.path}/v9.41')
        ..createSync(recursive: true);
      final depth2 = Directory('${depth1.path}/arm64')
        ..createSync(recursive: true);
      final depth3 = Directory('${depth2.path}/release')
        ..createSync(recursive: true);
      final depth4 = Directory('${depth3.path}/too_deep')
        ..createSync(recursive: true);

      // Carpetas ignoradas que deben omitirse
      final gitDir = Directory('${customDir.path}/.git')
        ..createSync(recursive: true);
      final interDir = Directory('${buildDir.path}/intermediates')
        ..createSync(recursive: true);

      final univ940Bytes = createTestZip(
          ['AndroidManifest.xml', 'lib/arm64-v8a/a.so', 'lib/armeabi-v7a/a.so']);
      final arm941Bytes =
          createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/b.so']);
      final arm939Bytes =
          createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/c.so']);
      final deepBytes =
          createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/deep.so']);

      final apkLib940 = File('${libDir.path}/mochilalista_v9.40_atp.apk');
      await apkLib940.writeAsBytes(univ940Bytes);
      // Copia idéntica en buildDir (debe deduplicarse conservando libDir por prioridad)
      await File('${buildDir.path}/app-release.apk').writeAsBytes(univ940Bytes);

      final apkArm941 = File('${depth2.path}/mochilalista_v9.41_arm64.apk');
      await apkArm941.writeAsBytes(arm941Bytes);
      await File('${depth2.path}/mochilalista_v9.41_atp_cambios.txt')
          .writeAsString('Notas comerciales v9.41 desde subcarpeta');

      final apkDepth3 = File('${depth3.path}/mochilalista_v9.39.1_arm64.apk');
      await apkDepth3.writeAsBytes(arm939Bytes);

      // Depth 4 no debe incluirse con maxDepth = 3
      await File('${depth4.path}/mochilalista_v9.99.0_arm64.apk')
          .writeAsBytes(deepBytes);
      // Carpetas ignoradas no deben incluirse
      await File('${gitDir.path}/mochilalista_v9.98.0_atp.apk')
          .writeAsBytes(deepBytes);
      await File('${interDir.path}/mochilalista_v9.97.0_atp.apk')
          .writeAsBytes(deepBytes);

      // Simular fecha más nueva en 9.39.1 para verificar que ranking híbrido prioriza SemVer 9.41 > 9.40 > 9.39.1
      await apkDepth3.setLastModified(DateTime.now().add(const Duration(minutes: 5)));

      final inspector = ApkInspectorService(
        sdkSearchRootsOverride: const [],
        processRunnerOverride: (cmd, args) async {
          if (cmd.contains('aapt2') && args.contains('badging')) {
            final p = args.last;
            if (p.contains('9.41')) {
              return ProcessResult(
                  1, 0, "package: name='com.mochilalista.app' versionCode='85' versionName='9.41.0'\n", '');
            }
            if (p.contains('9.40') || p.contains('app-release')) {
              return ProcessResult(
                  1, 0, "package: name='com.mochilalista.app' versionCode='84' versionName='9.40.0'\n", '');
            }
            if (p.contains('9.39.1')) {
              return ProcessResult(
                  1, 0, "package: name='com.mochilalista.app' versionCode='83' versionName='9.39.1'\n", '');
            }
          }
          return ProcessResult(2, 1, '', 'no tool');
        },
      );

      final searchDirs = [
        ApkSearchDirConfig(
          path: libDir.path,
          label: 'Biblioteca Oficial',
          enabled: true,
          isDefault: true,
          kind: 'official_library',
        ),
        ApkSearchDirConfig(
          path: customDir.path,
          label: 'Carpeta Personalizada',
          enabled: true,
          isDefault: false,
          kind: 'custom',
        ),
        ApkSearchDirConfig(
          path: buildDir.path,
          label: 'Build Local',
          enabled: true,
          isDefault: true,
          kind: 'flutter_build',
        ),
        ApkSearchDirConfig(
          path: missingDir.path,
          label: 'Carpeta Movida',
          enabled: true,
          isDefault: false,
          kind: 'custom',
        ),
      ];

      final fullReport = await inspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: searchDirs,
        maxDepth: 3,
        limit: 10,
      );

      // 3 únicos válidos: v9.41.0 (depth 2), v9.40.0 (lib+build dedup), v9.39.1 (depth 3)
      expect(fullReport.totalAllUnique, equals(3));
      expect(fullReport.results.map((r) => r.versionName).toList(),
          equals(['9.41.0', '9.40.0', '9.39.1']));

      // Dedup SHA-256 conservó Biblioteca Oficial y registró app-release.apk como duplicado
      final v940 = fullReport.results[1];
      expect(v940.sourceLabel, equals('Biblioteca Oficial'));
      expect(v940.duplicatePaths, hasLength(1));

      // Notas compañeras encontradas dentro de subcarpeta
      expect(fullReport.results.first.suggestedChangelog,
          contains('Notas comerciales v9.41'));

      // per_dir_stats reporta existencia y conteo real por ruta
      expect(fullReport.perDirStats.length, equals(4));
      final customStat = fullReport.perDirStats
          .firstWhere((s) => s['label'] == 'Carpeta Personalizada');
      expect(customStat['exists'], isTrue);
      expect(customStat['apk_count'], equals(2)); // solo depth2 + depth3, ignora depth4 y .git
      final missingStat =
          fullReport.perDirStats.firstWhere((s) => s['label'] == 'Carpeta Movida');
      expect(missingStat['exists'], isFalse);
      expect(missingStat['apk_count'], equals(0));

      // Filtro ABI ARM64 + limit = 1
      final armReport = await inspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: searchDirs,
        maxDepth: 3,
        abiFilter: 'ARM64',
        limit: 1,
      );
      expect(armReport.totalUniqueFound, equals(2));
      expect(armReport.totalReturned, equals(1));
      expect(armReport.results.first.abiVariant, equals('ARM64'));
      expect(armReport.results.first.versionName, equals('9.41.0'));

      // Filtro query
      final queryReport = await inspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: searchDirs,
        maxDepth: 3,
        query: '9.39.1',
      );
      expect(queryReport.results.length, equals(1));
      expect(queryReport.results.first.versionName, equals('9.39.1'));

      // Cache en vivo: hit cuando size/mtime no cambian e invalidación al actualizar tamaño/fecha
      final mockSdkDir = Directory('${tempDir.path}/cache_sdk/37.0.0')
        ..createSync(recursive: true);
      await File('${mockSdkDir.path}/${Platform.isWindows ? 'aapt2.exe' : 'aapt2'}')
          .writeAsString('stub');
      var inspectRuns = 0;
      final cachedInspector = ApkInspectorService(
        sdkSearchRootsOverride: ['${tempDir.path}/cache_sdk'],
        processRunnerOverride: (cmd, args) async {
          inspectRuns++;
          return ProcessResult(2, 1, '', 'no tool');
        },
      );
      await cachedInspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: [searchDirs[1]],
        maxDepth: 3,
        query: '9.41.0',
      );
      final runsAfterCold = inspectRuns;
      expect(runsAfterCold, greaterThan(0));

      await cachedInspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: [searchDirs[1]],
        maxDepth: 3,
        query: '9.41.0',
      );
      expect(inspectRuns, equals(runsAfterCold));

      await apkDepth3.setLastModified(DateTime.now().add(const Duration(minutes: 10)));
      await cachedInspector.detectLocalApksWithStats(
        apkLibraryDir: libDir,
        searchDirs: [searchDirs[1]],
        maxDepth: 3,
        query: '9.39.1',
      );
      expect(inspectRuns, greaterThan(runsAfterCold));
    });

    // =========================================================================
    // 3. Constructor PowerShell Selector de Carpetas Windows (Salvaguarda Paso 0)
    // =========================================================================
    test(
        '3. Builder PowerShell browse-search-dir usa -STA, UTF-8, TopMost y Dispose()',
        () {
      final args = buildWindowsFolderPickerPsArgs(
          initialPath: r"C:\Users\O'Brien\Builds Ñ");
      expect(args, contains('-NoProfile'));
      expect(args, contains('-STA'));
      final script = args.last;
      expect(script, contains('Add-Type -AssemblyName System.Windows.Forms'));
      expect(script,
          contains('[Console]::OutputEncoding = [System.Text.Encoding]::UTF8'));
      expect(script, contains('FolderBrowserDialog'));
      expect(script, contains(r'$topForm.TopMost = $true'));
      expect(script, contains(r'$dialog.Dispose()'));
      expect(script, contains(r'$topForm.Dispose()'));
      expect(script, contains(r"O''Brien\Builds Ñ"));
    });

    // =========================================================================
    // 4. Integración HTTP Completa de Fase 1 + Ciclo de Variantes DatabaseService
    // =========================================================================
    test(
        '4. HTTP Endpoints: search-dirs CRUD/reset/browse, detect-local-build filtros, import-local ruta custom, companion-notes y variantes',
        () async {
      final dataDir = Directory('${tempDir.path}/data')
        ..createSync(recursive: true);
      final backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      final releasesDir = '${tempDir.path}/releases_apks';
      final libDir = Directory('${tempDir.path}/apk_lib')
        ..createSync(recursive: true);
      final customDir = Directory('${tempDir.path}/custom_apks')
        ..createSync(recursive: true);
      final customSubDir = Directory('${customDir.path}/v9.42')
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
          .initWithSeed(List<int>.generate(32, (i) => (i * 11 + 5) % 256));
      final excel = ExcelExportService(dbService: db, configService: config);
      final vault = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dpapiService: MockDpapiService('TEST_P225_F1'),
        dbService: db,
        configService: config,
        signer: signer,
      );
      await vault.initialize();

      final sdkDir = Directory('${tempDir.path}/sdk/37.0.0')
        ..createSync(recursive: true);
      final exeName = Platform.isWindows ? 'apksigner.bat' : 'apksigner';
      await File('${sdkDir.path}/$exeName').writeAsString('echo mock');

      final inspector = ApkInspectorService(
        sdkSearchRootsOverride: ['${tempDir.path}/sdk'],
        defaultBuildOutputDir:
            Directory('${tempDir.path}/empty_build')..createSync(recursive: true),
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

      String? mockPickedFolder = customDir.path;
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
            onBrowseFolderOverride: () async => mockPickedFolder,
          ));

      final http = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';

      try {
        // Preparar APKs y notas en carpeta personalizada (en subcarpeta)
        final armApk = File('${customSubDir.path}/mochilalista_v9.42_arm64.apk');
        await armApk.writeAsBytes(
            createTestZip(['AndroidManifest.xml', 'lib/arm64-v8a/a.so']));
        final univApk = File('${libDir.path}/mochilalista_v9.40_atp.apk');
        await univApk.writeAsBytes(createTestZip(
            ['AndroidManifest.xml', 'lib/arm64-v8a/a.so', 'lib/armeabi-v7a/a.so']));
        await File('${customSubDir.path}/mochilalista_v9.42_atp_cambios.txt')
            .writeAsString('Novedades v9.42 desde carpeta personalizada');
        await File('${customSubDir.path}/mochilalista_v9.42_atp.txt')
            .writeAsString('Ficha técnica v9.42');

        // A) GET search-dirs inicial
        final getDirsRes = await (await http.getUrl(
                Uri.parse('$baseUrl/api/releases/search-dirs')))
            .close();
        expect(getDirsRes.statusCode, equals(200));
        final getDirsJson =
            jsonDecode(await utf8.decodeStream(getDirsRes)) as Map<String, dynamic>;
        expect(getDirsJson['ok'], isTrue);
        expect((getDirsJson['search_dirs'] as List).length, equals(2));

        // B) POST browse-search-dir usando hook inyectado
        final browseRes = await (await http.postUrl(
                Uri.parse('$baseUrl/api/releases/browse-search-dir')))
            .close();
        expect(browseRes.statusCode, equals(200));
        final browseJson =
            jsonDecode(await utf8.decodeStream(browseRes)) as Map<String, dynamic>;
        expect(browseJson['ok'], isTrue);
        expect(browseJson['cancelled'], isFalse);
        expect(browseJson['path'],
            equals(ApkInspectorService.canonicalizePath(customDir.path)));

        // Cancelado
        mockPickedFolder = null;
        final cancelRes = await (await http.postUrl(
                Uri.parse('$baseUrl/api/releases/browse-search-dir')))
            .close();
        final cancelJson =
            jsonDecode(await utf8.decodeStream(cancelRes)) as Map<String, dynamic>;
        expect(cancelJson['ok'], isTrue);
        expect(cancelJson['cancelled'], isTrue);

        // C) PUT search-dirs rechazando raíz prohibida con 400
        final badPutReq = await http
            .putUrl(Uri.parse('$baseUrl/api/releases/search-dirs'));
        badPutReq.headers.contentType = ContentType.json;
        badPutReq.write(jsonEncode({
          'search_dirs': [
            {'path': r'C:\', 'label': 'Raíz'}
          ]
        }));
        final badPutRes = await badPutReq.close();
        expect(badPutRes.statusCode, equals(400));
        await badPutRes.drain();

        // D) PUT search-dirs agregando customDir
        final putDirsReq = await http
            .putUrl(Uri.parse('$baseUrl/api/releases/search-dirs'));
        putDirsReq.headers.contentType = ContentType.json;
        putDirsReq.write(jsonEncode({
          'search_dirs': [
            ...(getDirsJson['search_dirs'] as List),
            {
              'path': customDir.path,
              'label': 'Compilaciones Custom',
              'enabled': true,
              'is_default': false,
              'kind': 'custom',
            }
          ]
        }));
        final putDirsRes = await putDirsReq.close();
        expect(putDirsRes.statusCode, equals(200));
        final putDirsJson =
            jsonDecode(await utf8.decodeStream(putDirsRes)) as Map<String, dynamic>;
        expect((putDirsJson['search_dirs'] as List).length, equals(3));

        // E) GET detect-local-build con filtro abi=ARM64 y limit=1
        final detRes = await (await http.getUrl(Uri.parse(
                '$baseUrl/api/releases/detect-local-build?abi=ARM64&limit=1')))
            .close();
        expect(detRes.statusCode, equals(200));
        final detJson =
            jsonDecode(await utf8.decodeStream(detRes)) as Map<String, dynamic>;
        expect(detJson['total_returned'], equals(1));
        expect(detJson['total_unique_found'], equals(1));
        expect(detJson['total_all_unique'], equals(2));
        expect((detJson['per_dir_stats'] as List).length, equals(3));
        expect(detJson['available_builds'][0]['version_name'], equals('9.42.0'));

        // F) POST import-local-apk desde carpeta custom y rechazo de ruta fuera/prohibida
        final impReq = await http
            .postUrl(Uri.parse('$baseUrl/api/releases/import-local-apk'));
        impReq.headers.contentType = ContentType.json;
        impReq.write(jsonEncode({'source_path': armApk.path}));
        final impRes = await impReq.close();
        expect(impRes.statusCode, equals(200));
        final impJson =
            jsonDecode(await utf8.decodeStream(impRes)) as Map<String, dynamic>;
        expect(impJson['ok'], isTrue);
        expect(impJson['abi_variant'], equals('ARM64'));
        expect(impJson['suggested_changelog'],
            contains('Novedades v9.42 desde carpeta personalizada'));

        final forbiddenApk = File('${dataDir.path}/secret_fake.apk');
        await forbiddenApk.writeAsBytes(createTestZip(['AndroidManifest.xml']));
        final badImpReq = await http
            .postUrl(Uri.parse('$baseUrl/api/releases/import-local-apk'));
        badImpReq.headers.contentType = ContentType.json;
        badImpReq.write(jsonEncode({'source_path': forbiddenApk.path}));
        final badImpRes = await badImpReq.close();
        expect(badImpRes.statusCode, equals(403));
        await badImpRes.drain();

        // G) POST /api/releases persiste abi_variant + variante inicial y companion-notes busca en rutas custom
        final createReq =
            await http.postUrl(Uri.parse('$baseUrl/api/releases'));
        createReq.headers.contentType = ContentType.json;
        createReq.write(jsonEncode({
          'version_name': '9.42.0',
          'version_code': 86,
          'type': 'FEATURE_RELEASE',
          'abi_variant': 'ARM64',
          'apk_file_path': impJson['imported_path'],
          'apk_sha256': impJson['sha256'],
          'file_size_mb': impJson['size_mb'],
          'signature_status': 'OFFICIAL_RELEASE',
          'signature_verified': true,
        }));
        final createRes = await createReq.close();
        expect(createRes.statusCode, equals(201));
        final createdJson =
            jsonDecode(await utf8.decodeStream(createRes)) as Map<String, dynamic>;
        expect(createdJson['abi_variant'], equals('ARM64'));
        expect(createdJson['arm64_apk'], isNotNull);
        expect(createdJson['arm64_apk']['file_exists'], isTrue);

        // H) Borrar binario físico de disco -> getReleases y /verify deben reportar file_exists: false en la variante
        final importedArmFile = File(impJson['imported_path'] as String);
        await importedArmFile.delete();

        final listAfterDel = await db.getReleases();
        final rel942 =
            listAfterDel.firstWhere((r) => r['version_name'] == '9.42.0');
        expect(rel942['file_exists'], isFalse);
        expect(rel942['arm64_apk']['file_exists'], isFalse);

        final verAfterDelRes = await (await http.postUrl(
                Uri.parse('$baseUrl/api/releases/9.42.0/verify')))
            .close();
        expect(verAfterDelRes.statusCode, equals(200));
        final verAfterDelJson = jsonDecode(
            await utf8.decodeStream(verAfterDelRes)) as Map<String, dynamic>;
        expect(verAfterDelJson['file_exists'], isFalse);
        expect(
            verAfterDelJson['release']['arm64_apk']['file_exists'], isFalse);

        // I) Adjuntar universal_apk y luego desvincular arm64_apk con {'arm64_apk': null} (Salvaguarda Paso 0)
        final putPairReq =
            await http.putUrl(Uri.parse('$baseUrl/api/releases/9.42.0'));
        putPairReq.headers.contentType = ContentType.json;
        putPairReq.write(jsonEncode({
          'universal_apk': {
            'file_path': univApk.path,
            'file_size_mb': '108.47 MB',
            'sha256': 'abc123',
            'signature_status': 'OFFICIAL_RELEASE',
            'signature_verified': true,
            'file_exists': true,
          },
        }));
        final putPairRes = await putPairReq.close();
        expect(putPairRes.statusCode, equals(200));
        await putPairRes.drain();

        final unlinkReq =
            await http.putUrl(Uri.parse('$baseUrl/api/releases/9.42.0'));
        unlinkReq.headers.contentType = ContentType.json;
        unlinkReq.write(jsonEncode({'arm64_apk': null}));
        final unlinkRes = await unlinkReq.close();
        expect(unlinkRes.statusCode, equals(200));
        final unlinkJson =
            jsonDecode(await utf8.decodeStream(unlinkRes)) as Map<String, dynamic>;
        expect(unlinkJson.containsKey('arm64_apk'), isFalse);
        expect(unlinkJson['universal_apk'], isNotNull);
        expect(unlinkJson['apk_file_path'], equals(univApk.path));
        expect(unlinkJson['abi_variant'], equals('UNIVERSAL'));

        // J) companion-notes encuentra *_cambios.txt y *_atp.txt en subcarpeta de ruta configurada
        final notesRes = await (await http.getUrl(
                Uri.parse('$baseUrl/api/releases/9.42.0/companion-notes')))
            .close();
        expect(notesRes.statusCode, equals(200));
        final notesJson =
            jsonDecode(await utf8.decodeStream(notesRes)) as Map<String, dynamic>;
        expect(notesJson['suggested_changelog'],
            contains('Novedades v9.42 desde carpeta personalizada'));
        expect(notesJson['suggested_internal_notes'],
            contains('Ficha técnica v9.42'));

        // K) POST search-dirs/reset
        final resetRes = await (await http.postUrl(
                Uri.parse('$baseUrl/api/releases/search-dirs/reset')))
            .close();
        expect(resetRes.statusCode, equals(200));
        final resetJson =
            jsonDecode(await utf8.decodeStream(resetRes)) as Map<String, dynamic>;
        expect((resetJson['search_dirs'] as List).length, equals(2));
      } finally {
        http.close(force: true);
        await server.close(force: true);
      }
    });
  });
}
