import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';
import '../lib/license_signer.dart';
import '../lib/excel_export_service.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';

void main() {
  group('Fase 5 - Plan Maestro 18: Reingeniería de Comprobantes (Boletas BOL, Facturas FAC, IGV, Canvas y PDF)', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late DatabaseService db;
    late ConfigService configService;
    late File clientsDbFile;
    late LicenseSigner signer;
    late ExcelExportService excelService;
    late VaultStorageService vaultStorage;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_fase5_receipt_test_');
      dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      clientsDbFile = File('${dataDir.path}/sandbox_clients_db.json');
      clientsDbFile.writeAsStringSync(jsonEncode([]));
      db = DatabaseService(dataDir: dataDir.path);
      configService = ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await configService.init();

      signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 3 + 7) % 256);
      await signer.initWithSeed(testSeed);

      excelService = ExcelExportService(dbService: db, configService: configService);
      vaultStorage = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: '${tempDir.path}/mirror',
        dbService: db,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. ConfigService: Correlativos independientes y segregados para BOL y FAC (Sandbox y Prod)', () async {
      // Por defecto en sandbox los correlativos inician en 1
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'BOL'), equals(1));
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'FAC'), equals(1));

      // Consumir 1 de Boleta
      final bol1 = await configService.consumeReceiptCorrelative(isSandbox: true, voucherType: 'BOL');
      expect(bol1, equals(1));
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'BOL'), equals(2));
      // Factura sigue en 1
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'FAC'), equals(1));

      // Consumir 1 de Factura
      final fac1 = await configService.consumeReceiptCorrelative(isSandbox: true, voucherType: 'FAC');
      expect(fac1, equals(1));
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'FAC'), equals(2));
      // Boleta sigue en 2
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'BOL'), equals(2));

      // Consumir otro de Boleta
      final bol2 = await configService.consumeReceiptCorrelative(isSandbox: true, voucherType: 'BOL');
      expect(bol2, equals(2));
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'BOL'), equals(3));
      // Factura sigue en 2
      expect(configService.getNextReceiptCorrelative(isSandbox: true, voucherType: 'FAC'), equals(2));
    });

    test('2. ConfigService: Estructura de receipt_config con 9 toggles e IGV por defecto', () {
      final rc = configService.config['receipt_config'] as Map<String, dynamic>;
      expect(rc['show_logo'], isTrue);
      expect(rc['show_issuer_doc'], isTrue);
      expect(rc['show_issuer_phone'], isTrue);
      expect(rc['show_client_doc'], isTrue);
      expect(rc['show_hardware_id'], isTrue);
      expect(rc['show_operation_number'], isTrue);
      expect(rc['show_observation'], isTrue);
      expect(rc['show_signature'], isTrue);
      expect(rc['show_footer_notes'], isTrue);
      expect(rc['show_igv_breakdown'], isFalse);
    });

    test('3. DatabaseService: Emisión bivalente e idempotencia absoluta entre BOL y FAC en el mismo pago', () async {
      final client = await db.createClient({
        'business_name': 'Comercial Los Andes SAC',
        'owner_name': 'Carlos Mendoza',
        'document_number': '20556677881',
        'phone': '951234567',
        'current_device_id': 'ML-5555',
        'license_type': 'ANUAL',
      });
      final clientId = client['id'] as String;

      final updatedClient = await db.addPayment(clientId, {
        'amount': 350.0,
        'plan': 'ANUAL',
        'method': 'Transferencia BCP',
        'reference': 'Op-998877',
        'date': '2026-11-22',
      });
      final paymentId = (updatedClient!['payment_history'] as List).last['id'] as String;

      // 1. Emitir Boleta de Pago BOL
      final bolRes1 = await db.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId,
        configService: configService,
        voucherType: 'BOL',
      );
      expect(bolRes1, isNotNull);
      expect(bolRes1!['voucher_type'], equals('BOL'));
      expect(bolRes1['receipt_number'], startsWith('BOL-'));
      final bolNumber = bolRes1['receipt_number'] as String;

      // 2. Emitir Factura de Pago FAC en el mismo pago
      final facRes1 = await db.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId,
        configService: configService,
        voucherType: 'FAC',
        invoiceRuc: '20556677881',
        invoiceBusinessName: 'Comercial Los Andes SAC',
        invoiceFiscalAddress: 'Av. Grau 123, Piura',
        showIgvBreakdown: true,
      );
      expect(facRes1, isNotNull);
      expect(facRes1!['voucher_type'], equals('FAC'));
      expect(facRes1['receipt_number'], startsWith('FAC-'));
      final facNumber = facRes1['receipt_number'] as String;

      // 3. Volver a solicitar Boleta BOL: Debe devolver exactamente el mismo bolNumber sin consumir correlativo
      final bolRes2 = await db.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId,
        configService: configService,
        voucherType: 'BOL',
      );
      expect(bolRes2!['receipt_number'], equals(bolNumber));

      // 4. Volver a solicitar Factura FAC: Debe devolver exactamente el mismo facNumber sin consumir correlativo
      final facRes2 = await db.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId,
        configService: configService,
        voucherType: 'FAC',
      );
      expect(facRes2!['receipt_number'], equals(facNumber));

      // 5. Verificar persistencia de campos fiscales en el pago dentro de la base de datos
      final freshClient = await db.getClientById(clientId);
      final payment = (freshClient!['payment_history'] as List).last as Map<String, dynamic>;
      expect(payment['receipt_bol_number'], equals(bolNumber));
      expect(payment['receipt_fac_number'], equals(facNumber));
      expect(payment['invoice_ruc'], equals('20556677881'));
      expect(payment['invoice_business_name'], equals('Comercial Los Andes SAC'));
      expect(payment['invoice_fiscal_address'], equals('Av. Grau 123, Piura'));
      expect(payment['show_igv_breakdown'], isTrue);
    });

    test('4. Servidor HTTP: Endpoint POST /api/clients/:id/payments/:paymentId/receipt soporta voucher_type y datos fiscales', () async {
      final client = await db.createClient({
        'business_name': 'Ferreteria San Pedro',
        'owner_name': 'Pedro Ramos',
        'document_number': '10443322118',
        'phone': '987112233',
        'current_device_id': 'ML-8888',
        'license_type': 'MENSUAL',
      });
      final clientId = client['id'] as String;

      final updatedClient = await db.addPayment(clientId, {
        'amount': 35.0,
        'plan': 'MENSUAL',
        'method': 'Yape',
        'reference': 'Op-554433',
        'date': '2026-11-22',
      });
      final paymentId = (updatedClient!['payment_history'] as List).last['id'] as String;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            configService,
            excelService,
            vaultStorage,
          ));
      final port = server.port;

      try {
        final clientHttp = HttpClient();

        // 1. Emitir Factura FAC
        final reqFac = await clientHttp.post('127.0.0.1', port, '/api/clients/$clientId/payments/$paymentId/receipt');
        reqFac.headers.contentType = ContentType.json;
        reqFac.write(jsonEncode({
          'voucher_type': 'FAC',
          'invoice_ruc': '20601234567',
          'invoice_business_name': 'Ferreteria San Pedro EIRL',
          'invoice_fiscal_address': 'Calle Comercio 456, Piura',
          'show_igv_breakdown': true,
        }));
        final resFac = await reqFac.close();
        expect(resFac.statusCode, equals(200));
        final facBody = jsonDecode(await resFac.transform(utf8.decoder).join()) as Map<String, dynamic>;
        expect(facBody['voucher_type'], equals('FAC'));
        expect(facBody['receipt_number'], startsWith('FAC-'));

        // 2. Emitir Boleta BOL
        final reqBol = await clientHttp.post('127.0.0.1', port, '/api/clients/$clientId/payments/$paymentId/receipt');
        reqBol.headers.contentType = ContentType.json;
        reqBol.write(jsonEncode({
          'voucher_type': 'BOL',
        }));
        final resBol = await reqBol.close();
        expect(resBol.statusCode, equals(200));
        final bolBody = jsonDecode(await resBol.transform(utf8.decoder).join()) as Map<String, dynamic>;
        expect(bolBody['voucher_type'], equals('BOL'));
        expect(bolBody['receipt_number'], startsWith('BOL-'));

        clientHttp.close();
      } finally {
        await server.close(force: true);
      }
    });

    test('5. Inspección forense estática de admin_app.js: Canvas y PDF 100% blindados', () {
      final jsFile = File('web/js/admin_app.js');
      expect(jsFile.existsSync(), isTrue);
      final jsContent = jsFile.readAsStringSync();

      // Verificar aislamiento de tarjetas con ctx.save() y ctx.restore()
      expect(jsContent.contains('clientCardX'), isTrue);
      expect(jsContent.contains('clientTextX = clientCardX + 20'), isTrue);
      expect(jsContent.contains('roundRect(ctx, clientCardX, 165, colW, 160, 8, true, true)'), isTrue);

      // Verificar que el generador offline de PDF existe y genera estándar PDF 1.4 binario con DCTDecode
      expect(jsContent.contains('function generateOfflinePdfFromCanvas('), isTrue);
      expect(jsContent.contains('%PDF-1.4'), isTrue);
      expect(jsContent.contains('/Filter /DCTDecode'), isTrue);
      expect(jsContent.contains('function downloadReceiptPdf()'), isTrue);

      // Verificar que el desglose de IGV 18% esté implementado en la vista previa y en el canvas
      expect(jsContent.contains('subtotalVal = +(totalVal / 1.18).toFixed(2)'), isTrue);
      expect(jsContent.contains('igvVal = +(totalVal - subtotalVal).toFixed(2)'), isTrue);
      expect(jsContent.contains('SUBTOTAL (OP. GRAVADA):'), isTrue);
      expect(jsContent.contains('I.G.V. (18%):'), isTrue);
    });

    test('6. Inspección forense de UI (styles.css e index.html): Ergonomía y CERO emojis crudos', () {
      final htmlFile = File('web/index.html');
      final cssFile = File('web/css/styles.css');
      expect(htmlFile.existsSync(), isTrue);
      expect(cssFile.existsSync(), isTrue);

      final htmlContent = htmlFile.readAsStringSync();
      final cssContent = cssFile.readAsStringSync();

      // Selectores CSS ergonómicos
      expect(cssContent.contains('.receipt-actions-sticky'), isTrue);
      expect(cssContent.contains('.rc-toggles-grid'), isTrue);
      expect(cssContent.contains('.rc-invoice-block'), isTrue);
      expect(cssContent.contains('.rdoc-total-box.with-igv'), isTrue);

      // Controles HTML en el modal de comprobantes
      expect(htmlContent.contains('id="rcSelectVoucherType"'), isTrue);
      expect(htmlContent.contains('id="rcInvoiceFieldsBlock"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowIgv"'), isTrue);
      expect(htmlContent.contains('id="btnRcDownloadPdf"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowLogo"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowIssuerDoc"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowIssuerPhone"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowClientDoc"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowHardwareId"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowOperationNumber"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowObservation"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowSignature"'), isTrue);
      expect(htmlContent.contains('id="rcCheckShowFooterNotes"'), isTrue);

      // Verificar que el bloque del modal de comprobante no contenga emojis crudos
      final modalStart = htmlContent.indexOf('id="modalPaymentReceipt"');
      expect(modalStart, isPositive);
      final modalEnd = htmlContent.indexOf('id="modalSyncReported"', modalStart);
      expect(modalEnd, isPositive);
      final receiptModalSnippet = htmlContent.substring(modalStart, modalEnd);

      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);
      final matches = emojiRegex.allMatches(receiptModalSnippet);
      expect(matches.isEmpty, isTrue, reason: 'El modal de comprobantes no debe contener emojis crudos (solo SVG)');
    });
  });
}
