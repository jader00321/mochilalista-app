import 'dart:io';

import 'package:test/test.dart';

import '../lib/apk_inspector_service.dart';
import '../lib/client_sync_service.dart';
import '../lib/commercial_config_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/core/backup_rotation_helper.dart';
import '../lib/core/commercial_constants.dart';
import '../lib/core/csv_utils.dart';
import '../lib/core/path_security.dart';
import '../lib/core/semver_utils.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/time_utils.dart';
import '../lib/vault_crypto_service.dart';
import '../lib/vault_storage_service.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('PLAN MAESTRO 25 - FASE 1: Capa Core DRY, Fix D-ADM-02 y Modularización de 6 Servicios', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ml_p25_fase1_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. CsvCellEscaper y Fix D-ADM-02 en DatabaseService.exportClientsToCsv y exportFinancesToCsv', () async {
      // Contrato unitario RFC-4180 + normalización de saltos de línea
      expect(
        CsvCellEscaper.escapeCell('Librería "El Sol", S.A.C.\r\nSucursal Piura'),
        equals('"Librería ""El Sol"", S.A.C. Sucursal Piura"'),
      );
      expect(CsvCellEscaper.escapeCell(null), equals('""'));
      expect(
        CsvCellEscaper.encodeRow(['A,B', 'C"D', 'E\nF']),
        equals('"A,B","C""D","E F"'),
      );

      final db = DatabaseService(
        dataDir: '${tempDir.path}/data',
        backupDir: '${tempDir.path}/backups',
        releasesDir: '${tempDir.path}/releases',
      );
      await db.init();

      await db.saveClients([
        {
          'id': 'CLI-CSV-01',
          'business_name': 'Librería "El Sol"\r\nSede Centro, Piura',
          'owner_name': 'Juan "Chino" Pérez\nNorte',
          'document_id': '20609998881',
          'phone': '+51999888777',
          'current_device_id': 'ML-CSV1',
          'installed_version': '9.41.0',
          'license_type': 'ANUAL',
          'license_status': 'ACTIVA',
          'license_expires': '2027-11-25T23:59:59.000Z',
          'updates_until': '2027-11-25T23:59:59.000Z',
          'ai_extra_credits': 1200,
          'notes': 'Acuerdo "VIP"\r\nEntregado en mano, con BOLETA',
          'payment_history': [
            {
              'id': 'PAY-CSV-1',
              'date': '2026-11-25T16:00:00.000Z',
              'amount': 280.0,
              'plan': 'ANUAL',
              'method': 'Yape',
              'reference': 'Op "123"\nConfirmada',
              'receipt_type': 'BOL',
              'receipt_number': 'BOL-0001',
              'notes': 'Nota "interna"\r\nsin quiebre',
            },
          ],
          'generated_codes_history': [
            {'token': 'ML9-TOK-001'},
          ],
        },
      ]);

      final clientsCsv = await db.exportClientsToCsv();
      expect(clientsCsv.startsWith('\uFEFF'), isTrue);
      final clientLines = clientsCsv
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      // Header + 1 fila: cero saltos de línea rotos dentro de celdas
      expect(clientLines.length, equals(2));
      expect(
        clientLines[1],
        contains('"Librería ""El Sol"" Sede Centro, Piura"'),
      );
      expect(clientLines[1], contains('"Juan ""Chino"" Pérez Norte"'));
      expect(
        clientLines[1],
        contains('"Acuerdo ""VIP"" Entregado en mano, con BOLETA"'),
      );

      final financesCsv = await db.exportFinancesToCsv();
      expect(financesCsv.startsWith('\uFEFF'), isTrue);
      final finLines = financesCsv
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(finLines.length, equals(2));
      expect(finLines[1], contains('"Op ""123"" Confirmada"'));
      expect(finLines[1], contains('"Nota ""interna"" sin quiebre"'));
    });

    test('2. SemVerUtils y PathSecurity bloquean traversal y unifican comparaciones SemVer', () {
      // SemVer sin comparar build (ApkInspector / server)
      expect(SemVerUtils.compare('9.41.0', '9.40.9'), greaterThan(0));
      expect(SemVerUtils.compare('10.0.0', '9.99.9'), greaterThan(0));
      expect(SemVerUtils.compare('v9.41', '9.41.0'), equals(0));
      expect(SemVerUtils.compare('V9.41.0+85', '9.41.0+84'), equals(0));
      expect(SemVerUtils.compare(null, '9.0.0'), lessThan(0));

      // SemVer comparando +build cuando ambas lo declaran
      expect(
        SemVerUtils.compare('v9.41.0+85', '9.41.0+84', compareBuild: true),
        greaterThan(0),
      );
      expect(
        SemVerUtils.compare('v9.41.0+85', '9.41.0', compareBuild: true),
        equals(0),
      );
      expect(SemVerUtils.inferReleaseTypeFromVersion('9.41.0'), equals('FEATURE_RELEASE'));
      expect(SemVerUtils.inferReleaseTypeFromVersion('9.41.1'), equals('HOTFIX'));
      expect(SemVerUtils.compareVersionFolderNames('37.0.0', '36.1.0'), greaterThan(0));

      // PathSecurity containment y traversal
      final webRoot = Directory('${tempDir.path}/web')..createSync(recursive: true);
      final safeChild = File('${webRoot.path}/index.html')..writeAsStringSync('<html/>');
      final outsideSecret = File('${tempDir.path}/secret.json')..writeAsStringSync('{}');

      expect(PathSecurity.isPathWithinDirectory(webRoot.path, safeChild.path), isTrue);
      expect(
        PathSecurity.isPathWithinDirectory(webRoot.path, '${webRoot.path}/sub/../index.html'),
        isTrue,
      );
      expect(
        PathSecurity.isPathWithinDirectory(webRoot.path, '${webRoot.path}/../secret.json'),
        isFalse,
      );
      expect(PathSecurity.isPathWithinDirectory(webRoot.path, outsideSecret.path), isFalse);
      expect(
        PathSecurity.isPathWithinDirectory(webRoot.path, '${tempDir.path}/web_other/a.html'),
        isFalse,
      );

      // Bloqueos compartidos de carpetas prohibidas
      expect(PathSecurity.isForbiddenApkSearchDir(''), isTrue);
      expect(PathSecurity.isForbiddenApkSearchDir(r'C:\'), isTrue);
      expect(PathSecurity.isForbiddenApkSearchDir('/'), isTrue);
      expect(PathSecurity.isForbiddenApkSearchDir('${tempDir.path}/private_keys'), isTrue);
      final validApkDir = Directory('${tempDir.path}/apks_ok')..createSync();
      expect(PathSecurity.isForbiddenApkSearchDir(validApkDir.path), isFalse);
    });

    test('3. BackupRotationHelper: creación Lima GMT-5 y rotación determinista conservando 7 prefijos protegidos', () async {
      final backupsDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      final protectedNames = [
        'auto_manual_2026.json',
        'auto_vault_2026.json',
        'auto_pre_restore_2026.json',
        'auto_before_restore_2026.json',
        'auto_pre_import_2026.json',
        'auto_pre_save_2026.json',
        'auto_pre_reset_2026.json',
      ];
      for (final name in protectedNames) {
        expect(BackupRotationHelper.isProtectedBackupFilename(name), isTrue);
        await File('${backupsDir.path}/$name').writeAsString('{"protected":true}');
      }

      for (int i = 0; i < 34; i++) {
        final f = await BackupRotationHelper.writeAtomicSnapshot(
          backupsDirectory: backupsDir,
          prefix: 'auto',
          reason: 'tick_$i',
          content: '{"tick":$i}',
          timestamp: DateTime.utc(2026, 11, 25, 10, 0, i),
        );
        await f.setLastModified(DateTime.utc(2026, 11, 25, 10, 0, i));
      }

      await BackupRotationHelper.cleanOldSnapshots(
        backupsDirectory: backupsDir,
        autoPrefixes: const ['auto_'],
        maxAutoSnapshots: 30,
      );

      for (final name in protectedNames) {
        expect(
          File('${backupsDir.path}/$name').existsSync(),
          isTrue,
          reason: 'Snapshot protegido $name no debe eliminarse nunca',
        );
      }

      final remainingAuto = backupsDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.uri.pathSegments.last.startsWith('auto_') &&
              !BackupRotationHelper.isProtectedBackupFilename(
                f.uri.pathSegments.last,
              ))
          .toList();
      expect(remainingAuto.length, equals(30));
      expect(
        remainingAuto.any((f) => f.uri.pathSegments.last.contains('tick_33')),
        isTrue,
      );
      expect(
        remainingAuto.any((f) => f.uri.pathSegments.last.contains('tick_0_')),
        isFalse,
      );
    });

    test('4. Censo de líneas (< 600 L en capas nuevas) y paridad de símbolos en barrels lib/*.dart', () async {
      final adminRoot = WebBundleLoader.resolveAdminRoot();
      final libDir = Directory('${adminRoot.path}/lib');

      const modularDirs = ['core', 'apk', 'config', 'vault', 'sync', 'export'];
      int checkedFiles = 0;
      for (final dirName in modularDirs) {
        final subDir = Directory('${libDir.path}/$dirName');
        expect(subDir.existsSync(), isTrue, reason: 'Debe existir lib/$dirName/');
        final dartFiles = subDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        expect(dartFiles, isNotEmpty, reason: 'lib/$dirName/ no debe estar vacío');

        for (final file in dartFiles) {
          checkedFiles++;
          final lines = file.readAsLinesSync().length;
          expect(
            lines,
            lessThan(600),
            reason: 'Archivo modular ${file.path} tiene $lines líneas (>= 600)',
          );
        }
      }
      expect(checkedFiles, greaterThanOrEqualTo(20));

      const expectedBarrels = [
        'time_utils.dart',
        'apk_inspector_service.dart',
        'config_service.dart',
        'dpapi_service.dart',
        'vault_crypto_service.dart',
        'vault_storage_service.dart',
        'license_signer.dart',
        'client_sync_service.dart',
        'commercial_config_sync_service.dart',
        'excel_export_service.dart',
      ];
      for (final barrelName in expectedBarrels) {
        final barrel = File('${libDir.path}/$barrelName');
        expect(barrel.existsSync(), isTrue, reason: 'Falta barrel lib/$barrelName');
        final lines = barrel.readAsLinesSync();
        expect(
          lines.length,
          lessThan(20),
          reason: 'Barrel lib/$barrelName debe tener < 20 líneas',
        );
        expect(
          lines.every((l) => l.trim().isEmpty || l.trim().startsWith('export ')),
          isTrue,
          reason: 'Barrel lib/$barrelName solo debe re-exportar',
        );
      }

      // Paridad de símbolos públicos consumidos vía barrels originales
      expect(
        ApkInspectorService.officialSignerSha256,
        equals(CommercialConstants.officialSignerSha256),
      );
      expect(PeruTimeHelper.formatLimaDate('2026-11-25'), equals('2026-11-25'));
      expect(ApkInspectorService.compareSemVer('9.41.0', '9.40.0'), greaterThan(0));
      expect(ConfigService.canonicalTemplateKey('welcome'), equals('trial_welcome'));
      expect(ConfigService.getDefaultConfig()['catalog'], isA<Map>());
      expect(const InvalidApkSearchDirException('err').toString(), equals('err'));

      final mockDpapi = MockDpapiService('UNIT');
      expect(mockDpapi.isSupported, isTrue);
      expect(WindowsDpapiService(), isA<DpapiService>());

      expect(VaultCryptoService.kdfIterations, equals(100000));
      expect(VaultStorageService.criticalFileDescriptors.length, equals(5));
      expect(VaultException('x').toString(), equals('VaultException: x'));
      expect(VaultAuthException('x'), isA<VaultException>());
      expect(VaultIntegrityException('x'), isA<VaultException>());
      expect(VaultFormatException('x'), isA<VaultException>());
      expect(
        VaultUnlockCredential.dpapi().type,
        equals(VaultUnlockType.dpapi),
      );
      expect(LicenseSigner.normalizePlanSlug('PERPETUO'), equals('PERPETUO_LIBERADO'));
      expect(ClientSyncService.defaultHmacKey, isNotEmpty);
      expect(const SyncParseResult(valid: false).isValid, isFalse);
      expect(
        CommercialConfigSyncService.catalogSlugToSyncId.length,
        equals(8),
      );
      expect(const CommercialConfigSyncException('m').toString(), equals('m'));
      expect(ExcelExportService.sheetResumen, equals('Resumen Ejecutivo'));

      // Round-trip funcional de los servicios modularizados en tempDir
      final dataDir = Directory('${tempDir.path}/cfg_data');
      final bkpDir = Directory('${tempDir.path}/cfg_backups');
      final cfg = ConfigService(dataDirectory: dataDir, backupsDirectory: bkpDir);
      await cfg.init();
      final db = DatabaseService(
        dataDir: '${tempDir.path}/db_data',
        backupDir: '${tempDir.path}/db_backups',
        releasesDir: '${tempDir.path}/db_releases',
      );
      await db.init();
      final signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => i + 1));

      final exporter = ExcelExportService(dbService: db, configService: cfg);
      final xlsxBytes = await exporter.generateMasterWorkbook();
      expect(xlsxBytes, isNotEmpty);

      final syncSvc = CommercialConfigSyncService();
      final snippet = syncSvc.generateOwnerCommercialDefaultsDartFile(
        cfg.config,
        revision: 3,
      );
      expect(snippet, contains('commercialSyncDefaultRevision = 3'));
    });
  });
}
