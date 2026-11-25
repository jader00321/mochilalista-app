import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:test/test.dart';

import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/time_utils.dart';
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

void main() {
  group('PLAN MAESTRO 23 - FASE 1: Finanzas, Hora Lima GMT-5, Excel/CSV y Centro de Respaldos', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late Directory releasesDir;
    late Directory vaultMirrorDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late ExcelExportService excelService;
    late LicenseSigner signer;
    late VaultStorageService vaultStorage;
    HttpServer? server;
    HttpClient? httpClient;
    late Uri baseUri;

    final testSeed = List<int>.generate(32, (i) => (i * 7 + 11) % 256);

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_p23_fase1_test_');
      dataDir = Directory('${tempDir.path}/data');
      backupsDir = Directory('${tempDir.path}/backups');
      releasesDir = Directory('${tempDir.path}/releases_apks');
      vaultMirrorDir = Directory('${tempDir.path}/vault_mirror');
      await dataDir.create(recursive: true);
      await backupsDir.create(recursive: true);
      await releasesDir.create(recursive: true);
      await vaultMirrorDir.create(recursive: true);

      dbService = DatabaseService(
        dataDir: dataDir.path,
        backupDir: backupsDir.path,
        releasesDir: releasesDir.path,
      );
      dbService.setMode('sandbox');
      await dbService.init();

      configService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await configService.init();

      excelService = ExcelExportService(
        dbService: dbService,
        configService: configService,
      );

      signer = LicenseSigner();
      await signer.initWithSeed(testSeed);

      vaultStorage = VaultStorageService(
        dbService: dbService,
        configService: configService,
        signer: signer,
        projectRootDir: tempDir.path,
        mirrorDir: vaultMirrorDir.path,
        dpapiService: _TestDpapiService(),
      );
      await vaultStorage.initialize();
    });

    tearDown(() async {
      httpClient?.close(force: true);
      httpClient = null;
      await server?.close(force: true);
      server = null;
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    Future<void> startTestServer() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://127.0.0.1:${server!.port}');
      httpClient = HttpClient();
      server!.listen((request) {
        handleRequest(
          request,
          dbService,
          signer,
          configService,
          excelService,
          vaultStorage,
        );
      });
    }

    test('1. PeruTimeHelper convierte UTC a America/Lima GMT-5 de forma determinista y preserva YYYY-MM-DD', () {
      expect(
        PeruTimeHelper.formatLimaDateTime('2026-11-23T23:03:34.000Z'),
        equals('2026-11-23 18:03:34'),
      );
      // Post 19:00 Lima (01:30 UTC del día siguiente) debe permanecer en día 23 Lima
      expect(
        PeruTimeHelper.formatLimaDate('2026-11-24T01:30:00.000Z'),
        equals('2026-11-23'),
      );
      expect(
        PeruTimeHelper.formatLimaDateTime('2026-11-24T01:30:00.000Z'),
        equals('2026-11-23 20:30:00'),
      );
      // Cadena solo fecha conserva día calendario sin retroceder -5h
      expect(
        PeruTimeHelper.formatLimaDate('2026-11-20'),
        equals('2026-11-20'),
      );
      expect(
        PeruTimeHelper.isWithinLimaDateRange(
          '2026-11-24T01:30:00.000Z',
          fromDate: '2026-11-23',
          toDate: '2026-11-23',
        ),
        isTrue,
      );
      expect(
        PeruTimeHelper.isWithinLimaDateRange(
          '2026-11-23T02:00:00.000Z', // 2026-11-22 21:00:00 Lima
          fromDate: '2026-11-23',
          toDate: '2026-11-23',
        ),
        isFalse,
      );
    });

    test('2. CSV y Excel (.xlsx) sanean comillas/saltos, usan hora Lima y días=0 en migraciones/abonos/recargas', () async {
      dbService.setMode('prod');
      final client = await dbService.createClient({
        'business_name': 'Bazar "El Sol"\nNorte',
        'owner_name': 'Lucía Pérez',
        'document_number': '10443322110',
        'phone': '999888777',
        'current_device_id': 'ML-P23X',
        'license_type': 'MENSUAL',
      });
      final cid = client['id'] as String;

      // Migración (debe dar 0 días) a las 20:30 hora Lima (2026-11-24T01:30:00Z)
      await dbService.addManualPayment(cid, {
        'amount': 40.0,
        'plan': 'SERVICIO_MIGRACION',
        'method': 'Yape',
        'reference': 'MIG-LINEA\nDOS',
        'notes': 'Cambio de "equipo"',
        'date': '2026-11-24T01:30:00.000Z',
      });

      // Abono parcial (debe dar 0 días) el 22 Nov 21:00 Lima (2026-11-23T02:00:00Z)
      await dbService.addManualPayment(cid, {
        'amount': 25.0,
        'plan': 'ABONO_PARCIAL',
        'method': 'Plin',
        'reference': 'ABO-001',
        'date': '2026-11-23T02:00:00.000Z',
      });

      // Recarga IA 150 (debe dar 0 días, 150 créditos IA)
      await dbService.addManualPayment(cid, {
        'amount': 20.0,
        'plan': 'RECARGA_IA_150',
        'method': 'BCP',
        'reference': 'REC-150',
        'date': '2026-11-23T18:00:00.000Z',
      });

      // A) Validar CSV RFC-4180 + BOM + hora Lima + sin quiebres por \n
      final csv = await dbService.exportFinancesToCsv();
      expect(csv.startsWith('\uFEFF'), isTrue);
      final csvLines =
          csv.trim().split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();
      // Header + 3 transacciones = 4 líneas exactas (ninguna línea rota por \n interno)
      expect(csvLines.length, equals(4));
      expect(csvLines.first, contains('NOTAS'));
      final migCsvRow = csvLines.firstWhere((l) => l.contains('SERVICIO_MIGRACION'));
      expect(migCsvRow, contains('"2026-11-23 20:30:00"'));
      expect(migCsvRow, contains('"Bazar ""El Sol"" Norte"'));
      expect(migCsvRow, contains('"MIG-LINEA DOS"'));
      expect(migCsvRow, contains('"Cambio de ""equipo"""'));

      // B) Validar Excel Maestro (5 hojas, días=0 en migración/abono/recarga, planes completos)
      final masterBytes = await excelService.generateMasterWorkbook();
      final masterExcel = Excel.decodeBytes(masterBytes);
      expect(masterExcel.sheets.keys.length, equals(5));

      final paySheet = masterExcel['Libro de Pagos'];
      final migRow = paySheet.rows.firstWhere(
        (r) => r.length > 5 && r[5]?.value.toString() == 'SERVICIO_MIGRACION',
      );
      expect(migRow[1]?.value.toString(), equals('2026-11-23 20:30:00'));
      expect((migRow[6]?.value as IntCellValue).value, equals(0));

      final recRow = paySheet.rows.firstWhere(
        (r) => r.length > 5 && r[5]?.value.toString() == 'RECARGA_IA_150',
      );
      expect((recRow[6]?.value as IntCellValue).value, equals(0));
      expect((recRow[7]?.value as IntCellValue).value, equals(150));

      final execSheet = masterExcel['Resumen Ejecutivo'];
      final execFirstCol =
          execSheet.rows.map((r) => r.first?.value?.toString() ?? '').toList();
      expect(execFirstCol, contains('RECARGA_IA_150'));
      expect(execFirstCol, contains('EXTENSION_CORTESIA'));
      expect(execFirstCol, contains('ABONO_PARCIAL'));
      expect(execFirstCol, contains('SERVICIO_MIGRACION'));

      // C) Validar rango inclusivo en generateFinancesReport post-19:00 Lima
      final filteredBytes = await excelService.generateFinancesReport(
        fromDate: '2026-11-23',
        toDate: '2026-11-23',
      );
      final filteredExcel = Excel.decodeBytes(filteredBytes);
      final filteredPays = filteredExcel['Libro de Pagos'];
      final refsInRange = filteredPays.rows
          .skip(1)
          .where((r) => r.length > 9)
          .map((r) => r[9]?.value.toString() ?? '')
          .toList();
      expect(refsInRange.any((s) => s.contains('MIG-LINEA')), isTrue);
      expect(refsInRange.any((s) => s.contains('REC-150')), isTrue);
      expect(refsInRange.any((s) => s.contains('ABO-001')), isFalse);

      final summarySheet = filteredExcel['Resumen Contable'];
      final summaryLabels =
          summarySheet.rows.map((r) => r.first?.value?.toString() ?? '').toList();
      expect(summaryLabels, contains('DESGLOSE POR MEDIO DE PAGO DEL PERIODO'));
    });

    test('3. HTTP Preview, Restauración (DB y Config GLOBAL con recarga), pre_restore_ y Anti-Traversal', () async {
      await startTestServer();

      // Sembrar cliente en PROD y crear snapshot manual
      dbService.setMode('prod');
      await dbService.createClient({
        'business_name': 'Cliente Original Prod',
        'owner_name': 'Propietario 1',
        'current_device_id': 'ML-ORIG',
      });
      final manualRes = await dbService.createManualBackup();
      final prodManualClientsFile = (manualRes['files'] as List).first as String;

      // Modificar estado PROD añadiendo otro cliente
      await dbService.createClient({
        'business_name': 'Cliente Nuevo Post Snapshot',
        'owner_name': 'Propietario 2',
        'current_device_id': 'ML-NEWW',
      });

      // A) GET /api/backups devuelve modified_lima y flags
      final listRes = await _httpJson(httpClient!, 'GET', baseUri.resolve('/api/backups'));
      expect(listRes['status'], equals(200));
      final backupsList = (listRes['body'] as List).cast<Map<String, dynamic>>();
      final targetEntry = backupsList.firstWhere(
        (b) => b['filename'] == prodManualClientsFile,
      );
      expect(targetEntry['modified_lima'], matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')));
      expect(targetEntry['is_manual'], isTrue);
      expect(targetEntry['is_protected'], isTrue);

      // B) GET /api/backups/preview/:filename compara Snapshot (1 cliente) vs Actual (2 clientes)
      final previewRes = await _httpJson(
        httpClient!,
        'GET',
        baseUri.resolve('/api/backups/preview/${Uri.encodeComponent(prodManualClientsFile)}'),
      );
      expect(previewRes['status'], equals(200));
      final pBody = previewRes['body'] as Map<String, dynamic>;
      expect(pBody['target_scope'], equals('clients'));
      expect(pBody['environment'], equals('prod'));
      expect(pBody['snapshot_summary']['clients_count'], equals(1));
      expect(pBody['current_summary']['clients_count'], equals(2));

      // C) POST /api/backups/restore crea snapshot protegido pre_restore_ y restaura
      final restoreRes = await _httpJson(
        httpClient!,
        'POST',
        baseUri.resolve('/api/backups/restore'),
        body: {'filename': prodManualClientsFile},
      );
      expect(restoreRes['status'], equals(200));
      expect(restoreRes['body']['restored_scope'], equals('clients'));
      final prodAfterRestore = await dbService.getClients();
      expect(prodAfterRestore.length, equals(1));
      expect(prodAfterRestore.first['business_name'], equals('Cliente Original Prod'));

      final preRestoreExists = backupsDir
          .listSync()
          .whereType<File>()
          .any((f) => f.uri.pathSegments.last.contains('pre_restore_'));
      expect(preRestoreExists, isTrue);

      // D) Restauración de owner_config_backup_*.json recarga ConfigService en caliente
      final savedCfgBackup = File('${backupsDir.path}/owner_config_backup_20261123_180000_manual_mig.json');
      final customConfigMap = Map<String, dynamic>.from(ConfigService.getDefaultConfig());
      (customConfigMap['catalog'] as Map<String, dynamic>)['HARDWARE_MIGRATION_FEE'] = {
        'price': 75.0,
        'label': 'Migración Especial',
      };
      await savedCfgBackup.writeAsString(jsonEncode(customConfigMap));

      final cfgPreview = await _httpJson(
        httpClient!,
        'GET',
        baseUri.resolve('/api/backups/preview/${savedCfgBackup.uri.pathSegments.last}'),
      );
      expect(cfgPreview['status'], equals(200));
      expect(cfgPreview['body']['target_scope'], equals('config'));

      final cfgRestore = await _httpJson(
        httpClient!,
        'POST',
        baseUri.resolve('/api/backups/restore'),
        body: {'filename': savedCfgBackup.uri.pathSegments.last},
      );
      expect(cfgRestore['status'], equals(200));
      expect(cfgRestore['body']['restored_scope'], equals('config'));
      expect(configService.migrationFee, equals(75.0));

      // E) Anti Path-Traversal en download, preview y restore (HTTP 400)
      for (final badPath in [
        '/api/backups/preview/..%2Fsecret.json',
        '/api/backups/download/..%2F..%2Fsecret.json',
      ]) {
        final badRes = await _httpJson(httpClient!, 'GET', baseUri.resolve(badPath));
        expect(badRes['status'], equals(400), reason: 'Debe rechazar $badPath con HTTP 400');
      }

      for (final badFilename in ['../owner_config.json', r'..\..\secret.json', 'archivo.txt', '']) {
        final badRestore = await _httpJson(
          httpClient!,
          'POST',
          baseUri.resolve('/api/backups/restore'),
          body: {'filename': badFilename},
        );
        expect(badRestore['status'], equals(400));
      }
    });

    test('4. POST /api/backups/purge-sandbox purga solo sandbox_* automáticos y blinda PROD/GLOBAL/protegidos', () async {
      await startTestServer();

      // Sembrar 15 snapshots automáticos Sandbox con timestamps escalonados
      for (int i = 0; i < 15; i++) {
        final f = File('${backupsDir.path}/sandbox_clients_auto_step_${i.toString().padLeft(2, '0')}.json');
        await f.writeAsString('[]');
        await f.setLastModified(DateTime.utc(2026, 11, 20, 10, i));
      }

      // Archivos protegidos o de otros entornos que jamás deben tocarse
      final protectedFiles = [
        File('${backupsDir.path}/prod_clients_auto_1.json'),
        File('${backupsDir.path}/prod_releases_auto_1.json'),
        File('${backupsDir.path}/owner_config_backup_20261123_180000_pre_save.json'),
        File('${backupsDir.path}/sandbox_clients_manual_2026.json'),
        File('${backupsDir.path}/sandbox_clients_vault_2026.json'),
        File('${backupsDir.path}/sandbox_clients_pre_restore_2026.json'),
        File('${backupsDir.path}/sandbox_clients_before_restore_legacy.json'),
        File('${backupsDir.path}/sandbox_clients_pre_import_2026.json'),
      ];
      for (final pf in protectedFiles) {
        await pf.writeAsString('[]');
      }

      final purgeRes = await _httpJson(
        httpClient!,
        'POST',
        baseUri.resolve('/api/backups/purge-sandbox'),
        body: {'keep_recent': 10},
      );
      expect(purgeRes['status'], equals(200));
      expect(purgeRes['body']['ok'], isTrue);
      expect(purgeRes['body']['deleted_count'], equals(5));
      expect(purgeRes['body']['preserved_count'], equals(10));

      for (final pf in protectedFiles) {
        expect(pf.existsSync(), isTrue,
            reason: 'Jamás se debe eliminar archivo protegido/PROD/GLOBAL: ${pf.path}');
      }

      // Los 5 sandbox más antiguos (00..04) eliminados; los 10 más recientes (05..14) preservados
      for (int i = 0; i < 5; i++) {
        final oldF = File('${backupsDir.path}/sandbox_clients_auto_step_${i.toString().padLeft(2, '0')}.json');
        expect(oldF.existsSync(), isFalse);
      }
      for (int i = 5; i < 15; i++) {
        final recentF = File('${backupsDir.path}/sandbox_clients_auto_step_${i.toString().padLeft(2, '0')}.json');
        expect(recentF.existsSync(), isTrue);
      }
    });

    test('5. Auditoría Estática Web (#tabFinancesAndBackups): paginación 20, filtros, preview modal, light-theme y 0 emojis', () {
      final html = File('web/index.html').readAsStringSync();
      final css = File('web/css/styles.css').readAsStringSync();
      final js = File('web/js/admin_app.js').readAsStringSync();

      // HTML checks
      expect(html, contains('id="backupsFilterPills"'));
      expect(html, contains('id="inputBackupsSearch"'));
      expect(html, contains('id="btnPurgeSandboxBackups"'));
      expect(html, contains('id="btnLoadMoreBackups"'));
      expect(html, contains('id="backupsModeBanner"'));
      expect(html, contains('id="modalBackupPreview"'));
      expect(html, contains('id="bpComparisonBody"'));

      // Extraer sección completa #tabFinancesAndBackups y modalBackupPreview para validar 0 emojis crudos
      final secStart = html.indexOf('<section id="tabFinancesAndBackups"');
      final secEnd = html.indexOf('</section>', secStart);
      expect(secStart, greaterThan(-1));
      expect(secEnd, greaterThan(secStart));
      final finSectionHtml = html.substring(secStart, secEnd);

      final modalStart = html.indexOf('<div class="modal-overlay" id="modalBackupPreview"');
      final modalEnd = html.indexOf('<script src="js/admin_app.js', modalStart);
      final previewModalHtml = html.substring(modalStart, modalEnd);

      final rawEmojiRegex = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{23EA}\u{2B07}]',
        unicode: true,
      );
      expect(rawEmojiRegex.hasMatch(finSectionHtml), isFalse,
          reason: '#tabFinancesAndBackups no debe contener emojis crudos en web/index.html');
      expect(rawEmojiRegex.hasMatch(previewModalHtml), isFalse,
          reason: '#modalBackupPreview no debe contener emojis crudos en web/index.html');

      // CSS checks (buscador 100%, temas claro/oscuro, estilos de filtros/paginación/preview)
      expect(css, contains('.finance-filters-bar .search-group'));
      expect(css, contains('[data-theme="light"] .finance-filters-bar'));
      expect(css, contains('[data-theme="light"] .backups-filter-bar'));
      expect(css, contains('[data-theme="light"] .backup-pill.active'));
      expect(css, contains('[data-theme="light"] .backup-preview-callout'));
      expect(css, contains('.modal-backup-preview-dialog'));

      // JS checks (paginación 20, Lima GMT-5, modal preview, purge sandbox, sin ⬇️ / ⏪)
      expect(js, contains('const BACKUPS_PAGE_SIZE = 20;'));
      expect(js, contains('function formatLimaIsoDate('));
      expect(js, contains('function renderBackupsTable('));
      expect(js, contains('async function openBackupRestorePreview('));
      expect(js, contains('async function executeConfirmedBackupRestore('));
      expect(js, contains('/api/backups/purge-sandbox'));
      expect(js, contains('Cargar 20 respaldos más'));
      expect(js.contains('⬇️'), isFalse, reason: 'No debe quedar ⬇️ en admin_app.js');
      expect(js.contains('⏪'), isFalse, reason: 'No debe quedar ⏪ en admin_app.js');
    });
  });
}
