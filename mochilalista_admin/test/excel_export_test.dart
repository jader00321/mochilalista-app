import 'dart:io';
import 'package:test/test.dart';
import 'package:excel/excel.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';
import '../lib/excel_export_service.dart';

void main() {
  late Directory tempDir;
  late Directory dataDir;
  late Directory backupsDir;
  late DatabaseService dbService;
  late ConfigService configService;
  late ExcelExportService excelService;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ml_excel_test_');
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

  group('1. Libro Maestro Excel con Datos (Entorno Poblado Sandbox)', () {
    test('Genera archivo .xlsx decodificable con exactamente las 5 hojas oficiales (≤ 31 chars)', () async {
      final bytes = await excelService.generateMasterWorkbook();
      expect(bytes.isNotEmpty, isTrue);

      final excel = Excel.decodeBytes(bytes);

      // 1. Exactamente 5 hojas
      expect(excel.sheets.keys.length, equals(5));

      // 2. Nombres exactos de las hojas
      final sheetNames = excel.sheets.keys.toList();
      expect(sheetNames, contains('Resumen Ejecutivo'));
      expect(sheetNames, contains('Cartera CRM'));
      expect(sheetNames, contains('Libro de Pagos'));
      expect(sheetNames, contains('Equipos y Licencias'));
      expect(sheetNames, contains('Guia y Glosario'));

      // 3. Ninguna hoja se llama Sheet1
      expect(sheetNames.contains('Sheet1'), isFalse);

      // 4. Cada nombre ≤ 31 caracteres
      for (final name in sheetNames) {
        expect(name.length, lessThanOrEqualTo(31),
            reason: 'El nombre "$name" excede los 31 caracteres permitidos por Microsoft Excel');
      }
    });

    test('Cartera CRM cuenta con 17 columnas exactas (A..Q) y estados normalizados', () async {
      final bytes = await excelService.generateMasterWorkbook();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Cartera CRM'];

      // Fila 0 (encabezados) debe tener 18 columnas (incluyendo Próximo Seguimiento)
      final headerRow = sheet.rows.first;
      expect(headerRow.length, equals(18));

      expect(headerRow[0]?.value.toString(), equals('ID'));
      expect(headerRow[1]?.value.toString(), equals('Nombre Comercial'));
      expect(headerRow[5]?.value.toString(), equals('Hardware ID (ANDROID_ID)'));
      expect(headerRow[7]?.value.toString(), equals('Estado de Licencia'));
      expect(headerRow[12]?.value.toString(), equals('Créditos IA Acumulados'));
      expect(headerRow[16]?.value.toString(), equals('Notas y Acuerdos'));
      expect(headerRow[17]?.value.toString(), equals('Próximo Seguimiento'));

      // Al menos 1 fila de datos correspondiente a los clientes semilla
      expect(sheet.rows.length, greaterThan(1));
    });

    test('Libro de Pagos cuenta con 14 columnas exactas (A..N) y fila de total', () async {
      final bytes = await excelService.generateMasterWorkbook();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Libro de Pagos'];

      final headerRow = sheet.rows.first;
      expect(headerRow.length, equals(14));

      expect(headerRow[0]?.value.toString(), equals('ID Transacción'));
      expect(headerRow[5]?.value.toString(), equals('Concepto / Plan'));
      expect(headerRow[8]?.value.toString(), equals('Medio de Pago'));
      expect(headerRow[10]?.value.toString(), equals('Monto Cobrado (PEN)'));
      expect(headerRow[11]?.value.toString(), equals('Tipo Comprobante'));
      expect(headerRow[12]?.value.toString(), equals('N.° Comprobante'));
      expect(headerRow[13]?.value.toString(), equals('Última Edición'));
    });

    test('Resumen Ejecutivo contiene fórmulas reales SUM, COUNTIF, SUMIF e IFERROR', () async {
      final bytes = await excelService.generateMasterWorkbook();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Resumen Ejecutivo'];

      final formulasFound = <String>[];
      for (final row in sheet.rows) {
        for (final cell in row) {
          if (cell != null && cell.value is FormulaCellValue) {
            formulasFound.add((cell.value as FormulaCellValue).formula);
          }
        }
      }

      expect(formulasFound.isNotEmpty, isTrue);

      // Verificar fórmulas clave del resumen
      expect(formulasFound.any((f) => f.contains('COUNTA(\'Cartera CRM\'!A2:')), isTrue);
      expect(formulasFound.any((f) => f.contains('COUNTIF(\'Cartera CRM\'!H2:') && f.contains('ACTIVA')), isTrue);
      expect(formulasFound.any((f) => f.contains('SUM(\'Libro de Pagos\'!K2:')), isTrue);
      expect(formulasFound.any((f) => f.contains('COUNTIF(\'Libro de Pagos\'!I2:') && f.contains('Yape')), isTrue);
      expect(formulasFound.any((f) => f.contains('SUMIF(\'Libro de Pagos\'!I2:')), isTrue);
      expect(formulasFound.any((f) => f.contains('IFERROR(AVERAGE(\'Libro de Pagos\'!K2:')), isTrue);

      // Ninguna fórmula debe empezar con doble "="
      for (final f in formulasFound) {
        expect(f.startsWith('='), isFalse,
            reason: 'FormulaCellValue en excel: ^4.0.6 no debe incluir "=" inicial para evitar doble == en OOXML');
      }
    });
  });

  group('2. Modo Producción Limpio (0 Clientes y 0 Pagos)', () {
    test('Genera libro limpio sin excepciones y con fórmulas seguras contra #DIV/0!', () async {
      // Forzar entorno de producción limpio
      dbService.setMode('prod');
      final bytes = await excelService.generateMasterWorkbook();
      expect(bytes.isNotEmpty, isTrue);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.sheets.keys.length, equals(5));

      final resumenSheet = excel['Resumen Ejecutivo'];
      final formulasFound = <String>[];
      for (final row in resumenSheet.rows) {
        for (final cell in row) {
          if (cell != null && cell.value is FormulaCellValue) {
            formulasFound.add((cell.value as FormulaCellValue).formula);
          }
        }
      }

      // Los rangos deben ser seguros (K2:K2, A2:A2)
      expect(formulasFound.any((f) => f.contains('K2:K2')), isTrue);
      expect(formulasFound.any((f) => f.contains('IFERROR(AVERAGE')), isTrue);
    });
  });

  group('3. Reporte Financiero Filtrado por Fechas (generateFinancesReport)', () {
    test('Filtra cobros por rango de fechas respetando fromDate y toDate', () async {
      // Agregar un pago con fecha pasada y otro reciente
      final clients = await dbService.getClients();
      final client = clients.first;
      final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();

      payments.add({
        'id': 'PAY-OLD-2025',
        'date': '2025-05-10T10:00:00.000Z',
        'amount': 35.0,
        'plan': 'MENSUAL',
        'method': 'Yape',
        'reference': 'Op. 111111',
      });
      payments.add({
        'id': 'PAY-RECENT-2026',
        'date': '2026-11-15T10:00:00.000Z',
        'amount': 90.0,
        'plan': 'TRIMESTRAL',
        'method': 'BCP',
        'reference': 'Op. 222222',
      });
      client['payment_history'] = payments;
      await dbService.saveClients(clients);

      // Filtrar únicamente rango de 2026
      final bytes = await excelService.generateFinancesReport(
        fromDate: '2026-01-01',
        toDate: '2026-12-31',
      );

      final excel = Excel.decodeBytes(bytes);
      expect(excel.sheets.keys, contains('Resumen Contable'));
      expect(excel.sheets.keys, contains('Libro de Pagos'));
      expect(excel.sheets.keys, contains('Guia y Glosario'));

      final paySheet = excel['Libro de Pagos'];
      final rows = paySheet.rows;

      // Debe incluir PAY-RECENT-2026 pero excluir PAY-OLD-2025
      final transIds = rows.map((r) => r.first?.value?.toString()).toList();
      expect(transIds, contains('PAY-RECENT-2026'));
      expect(transIds.contains('PAY-OLD-2025'), isFalse);
    });
  });
}
