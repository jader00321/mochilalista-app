import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:excel/excel.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';
import '../lib/excel_export_service.dart';

void main() {
  group('Fase 6 - Plan Maestro 18: Finanzas, Excel Multi-hoja, Búsqueda y Cierre', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late ExcelExportService excelService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_fase6_test_');
      dataDir = Directory('${tempDir.path}/data');
      backupsDir = Directory('${tempDir.path}/backups');
      await dataDir.create(recursive: true);
      await backupsDir.create(recursive: true);

      dbService = DatabaseService(
        dataDir: dataDir.path,
        backupDir: backupsDir.path,
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
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Sincronización Excel: Hoja Cartera CRM incluye Próximo Seguimiento en columna 17 (R)', () async {
      // Registrar cliente con fecha de seguimiento
      final client = await dbService.createClient({
        'business_name': 'Bodega Las Palmeras',
        'owner_name': 'Carlos Rivera',
        'document_number': '20123456789',
        'phone': '987654321',
        'current_device_id': 'ML-TEST1',
        'license_type': 'MENSUAL',
        'next_followup_date': '2026-12-15',
      });
      expect(client['id'], isNotNull);

      final bytes = await excelService.generateMasterWorkbook();
      expect(bytes.isNotEmpty, isTrue);

      final excel = Excel.decodeBytes(bytes);
      final crmSheet = excel['Cartera CRM'];
      expect(crmSheet, isNotNull);

      final headerRow = crmSheet.rows.first;
      expect(headerRow.length, equals(18));
      expect(headerRow[17]?.value.toString(), equals('Próximo Seguimiento'));

      // Buscar la fila del cliente registrado
      final clientRow = crmSheet.rows.firstWhere(
        (r) => r.length > 1 && r[1]?.value.toString() == 'Bodega Las Palmeras',
        orElse: () => [],
      );
      expect(clientRow.isNotEmpty, isTrue);
      expect(clientRow[17]?.value.toString(), equals('2026-12-15'));
    });

    test('2. Sincronización Excel: Hoja Libro de Pagos preserva Monto en K (col 10) y añade Tipo/N.° Comprobante y Última Edición en L, M, N', () async {
      final client = await dbService.createClient({
        'business_name': 'Farmacia Central',
        'owner_name': 'Ana Silva',
        'document_number': '10987654321',
        'phone': '998877665',
        'current_device_id': 'ML-TEST2',
        'license_type': 'MENSUAL',
      });
      final cId = client['id'] as String;

      // Registrar pago con Boleta
      final clientWithP1 = await dbService.addPayment(cId, {
        'amount': 35.0,
        'plan': 'MENSUAL',
        'method': 'Yape',
        'reference': 'OP-9901',
        'date': '2026-11-20',
      });
      expect(clientWithP1, isNotNull);
      final p1 = (clientWithP1!['payment_history'] as List).last as Map;
      final p1Id = p1['id'] as String;
      await dbService.issueOrGetPaymentReceipt(
        clientId: cId,
        paymentId: p1Id,
        configService: configService,
        voucherType: 'BOL',
      );

      // Registrar pago con Factura y edición
      final clientWithP2 = await dbService.addPayment(cId, {
        'amount': 85.0,
        'plan': 'TRIMESTRAL',
        'method': 'BCP',
        'reference': 'OP-9902',
        'date': '2026-11-21',
      });
      expect(clientWithP2, isNotNull);
      final p2 = (clientWithP2!['payment_history'] as List).last as Map;
      final p2Id = p2['id'] as String;
      await dbService.issueOrGetPaymentReceipt(
        clientId: cId,
        paymentId: p2Id,
        configService: configService,
        voucherType: 'FAC',
      );
      await dbService.updatePayment(cId, p2Id, {
        'notes': 'Actualizado con RUC y retención',
      });

      final bytes = await excelService.generateMasterWorkbook();
      final excel = Excel.decodeBytes(bytes);
      final paySheet = excel['Libro de Pagos'];
      expect(paySheet, isNotNull);

      final headerRow = paySheet.rows.first;
      expect(headerRow.length, equals(14));
      expect(headerRow[10]?.value.toString(), equals('Monto Cobrado (PEN)'));
      expect(headerRow[11]?.value.toString(), equals('Tipo Comprobante'));
      expect(headerRow[12]?.value.toString(), equals('N.° Comprobante'));
      expect(headerRow[13]?.value.toString(), equals('Última Edición'));

      // Comprobar filas de datos
      final p1Row = paySheet.rows.firstWhere(
        (r) => r.length > 9 && (r[9]?.value.toString() ?? '').contains('OP-9901'),
        orElse: () => [],
      );
      expect(p1Row.isNotEmpty, isTrue);
      expect(p1Row[11]?.value.toString(), equals('Boleta'));
      expect(p1Row[12]?.value.toString(), contains('BOL-'));

      final p2Row = paySheet.rows.firstWhere(
        (r) => r.length > 9 && (r[9]?.value.toString() ?? '').contains('OP-9902'),
        orElse: () => [],
      );
      expect(p2Row.isNotEmpty, isTrue);
      expect(p2Row[11]?.value.toString(), equals('Factura'));
      expect(p2Row[12]?.value.toString(), contains('FAC-'));
      expect(p2Row[13]?.value.toString(), isNot(equals('-')));

      // Comprobar que en Resumen Ejecutivo las fórmulas siguen apuntando a la columna K
      final execSheet = excel['Resumen Ejecutivo'];
      expect(execSheet, isNotNull);
      final formulasFound = <String>[];
      for (final row in execSheet.rows) {
        for (final cell in row) {
          if (cell != null && cell.value is FormulaCellValue) {
            formulasFound.add((cell.value as FormulaCellValue).formula);
          }
        }
      }
      expect(formulasFound.any((f) => f.contains("'Libro de Pagos'!K")), isTrue,
          reason: 'Las fórmulas de Resumen Ejecutivo deben apuntar a la columna K de Libro de Pagos');
    });

    test('3. Exportación CSV incluye BOM UTF-8 y columnas de comprobante', () async {
      final client = await dbService.createClient({
        'business_name': 'Minimarket El Sol',
        'owner_name': 'Mario Vargas',
        'document_number': '10445566778',
        'phone': '912345678',
        'current_device_id': 'ML-TEST3',
      });
      final cId = client['id'] as String;

      final clientWithP = await dbService.addPayment(cId, {
        'amount': 35.0,
        'plan': 'MENSUAL',
        'method': 'Plin',
        'reference': 'PLIN-4455',
        'date': '2026-11-22',
      });
      expect(clientWithP, isNotNull);
      final p = (clientWithP!['payment_history'] as List).last as Map;
      final pId = p['id'] as String;
      await dbService.issueOrGetPaymentReceipt(
        clientId: cId,
        paymentId: pId,
        configService: configService,
        voucherType: 'BOL',
      );

      final csv = await dbService.exportFinancesToCsv();
      // Verificación de BOM UTF-8
      expect(csv.startsWith('\uFEFF'), isTrue);

      final lines = csv.split('\n');
      expect(lines.isNotEmpty, isTrue);

      final header = lines.first;
      expect(header, contains('RUC_DNI'));
      expect(header, contains('TIPO_COMPROBANTE'));
      expect(header, contains('N_COMPROBANTE'));

      final dataRow = lines.firstWhere((l) => l.contains('PLIN-4455'));
      expect(dataRow, contains('BOL'));
      expect(dataRow, contains('BOL-'));
      expect(dataRow, contains('10445566778'));
    });

    test('4. Auditoría estática web: Buscador interactivo y comprobantes en Finanzas', () {
      final indexHtml = File('web/index.html').readAsStringSync();
      final stylesCss = File('web/css/styles.css').readAsStringSync();
      final adminJs = File('web/js/admin_app.js').readAsStringSync();

      // index.html
      expect(indexHtml, contains('id="inputFinSearch"'));
      expect(indexHtml, contains('id="btnFinSearchClear"'));
      expect(indexHtml, contains('id="tabFinancesAndBackups"'));

      // Cero emojis crudos en la barra de búsqueda de finanzas
      final finSearchBarRegex = RegExp(r'<div class="finance-filters-bar">[\s\S]*?<\/div>');
      final finMatch = finSearchBarRegex.firstMatch(indexHtml);
      expect(finMatch, isNotNull);
      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);
      expect(rawEmojiRegex.hasMatch(finMatch!.group(0)!), isFalse,
          reason: 'La barra de filtros y búsqueda de Finanzas no debe contener emojis crudos');

      // styles.css
      expect(stylesCss, contains('.badge-receipt-bol'));
      expect(stylesCss, contains('.badge-receipt-fac'));
      expect(stylesCss, contains('.btn-fin-emit'));

      // admin_app.js
      expect(adminJs, contains("document.getElementById('inputFinSearch')"));
      expect(adminJs, contains("document.getElementById('btnFinSearchClear')"));
      expect(adminJs, contains('badge-receipt-bol'));
      expect(adminJs, contains('badge-receipt-fac'));
      expect(adminJs, contains('btn-fin-emit'));
      expect(adminJs, contains('sanitizeDownloadFileName'));
      expect(adminJs, contains('openWhatsAppComposer(client.id, null, {'));
      expect(adminJs, contains('options.customMessage'));
    });

    test('5. Blindaje del Lanzador Windows (Iniciar_MochilaLista_Admin.bat): CRLF puro y ASCII estricto', () {
      final batFile = File('../Iniciar_MochilaLista_Admin.bat');
      expect(batFile.existsSync(), isTrue, reason: 'El lanzador Iniciar_MochilaLista_Admin.bat debe existir en la raíz');

      final batBytes = batFile.readAsBytesSync();
      expect(batBytes.isNotEmpty, isTrue);

      // 1. CRLF verification
      final content = latin1.decode(batBytes);
      expect(content.contains('\r\n'), isTrue, reason: 'El archivo .bat debe tener saltos de línea Windows (CRLF)');

      // 2. No bare LF (\n without \r before it)
      for (int i = 0; i < batBytes.length; i++) {
        if (batBytes[i] == 0x0A) { // LF
          expect(i > 0 && batBytes[i - 1] == 0x0D, isTrue, // CR
              reason: 'Se detectó un byte LF (0x0A) solitario sin CR previo en offset $i');
        }
      }

      // 3. Strict ASCII (all bytes <= 127)
      for (int i = 0; i < batBytes.length; i++) {
        expect(batBytes[i], lessThanOrEqualTo(127),
            reason: 'El archivo contiene un caracter no-ASCII (byte ${batBytes[i]}) en offset $i');
      }

      // 4. Fallback interactivo (cmd /c ... || pause)
      expect(content, contains('dart run server.dart || pause'),
          reason: 'Debe contener el mecanismo anti-cierre silencioso dart run server.dart || pause');
    });
  });
}
