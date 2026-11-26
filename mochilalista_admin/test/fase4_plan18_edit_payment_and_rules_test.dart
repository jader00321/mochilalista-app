import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/license_signer.dart';
import '../lib/config_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('Fase 4 - Plan Maestro 18: Reingeniería de Edición de Pagos, Slugs y Blindaje Contable', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late DatabaseService db;
    late ConfigService configService;
    late File clientsDbFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_edit_payment_test_');
      dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      clientsDbFile = File('${dataDir.path}/sandbox_clients_db.json');
      clientsDbFile.writeAsStringSync(jsonEncode([]));
      db = DatabaseService(dataDir: dataDir.path);
      configService = ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await configService.init();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. DatabaseService: updatePayment valida amount >= 0 y rechaza montos negativos', () async {
      final client = await db.createClient({
        'business_name': 'Bodega San Martin',
        'owner_name': 'Juan Perez',
        'phone': '987654321',
        'current_device_id': 'ML-1111',
        'license_type': 'MENSUAL',
      });
      final clientId = client['id'] as String;

      final updatedClient = await db.addPayment(clientId, {
        'amount': 35.0,
        'plan': 'MENSUAL',
        'method': 'Yape',
        'reference': 'Op-1234',
        'date': '2026-11-20',
      });
      expect(updatedClient, isNotNull);
      final payments = (updatedClient!['payment_history'] as List).cast<Map<String, dynamic>>();
      final paymentId = payments.last['id'] as String;

      // Intentar actualizar con monto negativo debe lanzar ArgumentError
      expect(
        () => db.updatePayment(clientId, paymentId, {
          'amount': -10.0,
          'plan': 'MENSUAL',
        }),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('mayor o igual a'),
        )),
      );

      // Intentar actualizar con string no numérico
      expect(
        () => db.updatePayment(clientId, paymentId, {
          'amount': 'invalido',
          'plan': 'MENSUAL',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('2. DatabaseService: updatePayment valida fecha ISO y rechaza formato corrupto', () async {
      final client = await db.createClient({
        'business_name': 'Bazar Central',
        'owner_name': 'Ana Silva',
        'phone': '912345678',
        'current_device_id': 'ML-2222',
        'license_type': 'MENSUAL',
      });
      final clientId = client['id'] as String;

      final updatedClient = await db.addPayment(clientId, {
        'amount': 35.0,
        'plan': 'MENSUAL',
        'method': 'Plin',
        'date': '2026-11-20',
      });
      expect(updatedClient, isNotNull);
      final payments = (updatedClient!['payment_history'] as List).cast<Map<String, dynamic>>();
      final paymentId = payments.last['id'] as String;

      // Fecha corrupta
      expect(
        () => db.updatePayment(clientId, paymentId, {
          'amount': 35.0,
          'date': 'fecha-no-valida-31-02',
        }),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('formato ISO'),
        )),
      );
    });

    test('3. DatabaseService: updatePayment preserva receipt_number, inyecta updated_at y recalcula total_paid', () async {
      final client = await db.createClient({
        'business_name': 'Farmacia Popular',
        'owner_name': 'Roberto Gomez',
        'phone': '999888777',
        'current_device_id': 'ML-3333',
        'license_type': 'MENSUAL',
      });
      final clientId = client['id'] as String;

      // 1. Agregar primer pago de S/ 35.00
      final clientWithPay = await db.addPayment(clientId, {
        'amount': 35.0,
        'plan': 'MENSUAL',
        'method': 'Yape',
        'reference': 'OP-998811',
        'date': '2026-11-15',
      });
      expect(clientWithPay, isNotNull);
      final payments1 = (clientWithPay!['payment_history'] as List).cast<Map<String, dynamic>>();
      final paymentId1 = payments1.last['id'] as String;

      // 2. Emitir comprobante oficial BOL-0001
      final receiptData = await db.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId1,
        configService: configService,
      );
      expect(receiptData, isNotNull);
      final receiptNum = receiptData!['receipt_number'] as String;
      expect(receiptNum, startsWith('BOL-'));

      // Verificar estado previo
      var currentClient = await db.getClientById(clientId);
      expect((currentClient!['total_paid'] as num).toDouble(), equals(35.0));

      // 3. Modificar pago: cambiar monto a S/ 50.00, corregir referencia y plan a TRIMESTRAL
      // Intento malicioso de alterar receipt_number o id debe ser ignorado defensivamente
      final updatedClient = await db.updatePayment(clientId, paymentId1, {
        'id': 'ID_FALSO_HACK',
        'receipt_number': 'BOL-9999_HACK',
        'amount': 50.0,
        'plan': 'TRIMESTRAL',
        'reference': 'OP-998811-CORREGIDO',
        'date': '2026-11-16',
      });
      expect(updatedClient, isNotNull);

      // Validar cliente actualizado
      expect((updatedClient!['total_paid'] as num).toDouble(), equals(50.0));
      final payments = (updatedClient['payment_history'] as List).cast<Map<String, dynamic>>();
      final updatedP = payments.firstWhere((p) => p['id'] == paymentId1);

      expect(updatedP['id'], equals(paymentId1)); // ID original intacto
      expect(updatedP['receipt_number'], equals(receiptNum)); // Comprobante correlativo preservado
      expect((updatedP['amount'] as num).toDouble(), equals(50.0)); // Monto actualizado
      expect(updatedP['plan'], equals('TRIMESTRAL'));
      expect(updatedP['reference'], equals('OP-998811-CORREGIDO'));
      expect(updatedP['updated_at'], isNotNull); // Marca de tiempo de edición presente
      final updatedAt = DateTime.parse(updatedP['updated_at'] as String);
      expect(updatedAt.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1))), isTrue);

      // Re-verificar llamada idempotente a issueOrGetPaymentReceipt:
      // no debe regenerar correlativo ni duplicar comprobante
      final reReceipt = await db.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId1,
        configService: configService,
      );
      expect(reReceipt, isNotNull);
      expect(reReceipt!['receipt_number'], equals(receiptNum));
      expect((reReceipt['payment'] as Map<String, dynamic>)['amount'], equals(50.0));
    });

    test('4. REST HTTP: PUT /api/clients/:id/payments/:paymentId responde HTTP 400 ante monto negativo o corrupto', () async {
      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 3 + 7) % 256);
      await signer.initWithSeed(testSeed);

      final excelService = ExcelExportService(dbService: db, configService: configService);
      final vaultStorage = VaultStorageService(
        dbService: db,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            configService,
            excelService,
            vaultStorage,
          ));

      final httpClient = HttpClient();

      try {
        final c = await db.createClient({
          'business_name': 'Test Store',
          'owner_name': 'Owner',
          'phone': '911222333',
          'current_device_id': 'ML-9988',
        });
        final clientId = c['id'] as String;

        final clientWithPay = await db.addPayment(clientId, {
          'amount': 35.0,
          'plan': 'MENSUAL',
        });
        expect(clientWithPay, isNotNull);
        final payments = (clientWithPay!['payment_history'] as List).cast<Map<String, dynamic>>();
        final paymentId = payments.last['id'] as String;

        // 1. PUT con monto negativo
        final putReqBadAmt = await httpClient.put('127.0.0.1', server.port, '/api/clients/$clientId/payments/$paymentId');
        putReqBadAmt.headers.contentType = ContentType.json;
        putReqBadAmt.write(jsonEncode({
          'amount': -25.50,
          'plan': 'MENSUAL',
        }));
        final putResBadAmt = await putReqBadAmt.close();
        expect(putResBadAmt.statusCode, equals(HttpStatus.badRequest));
        final bodyBadAmt = jsonDecode(await utf8.decodeStream(putResBadAmt)) as Map<String, dynamic>;
        expect(bodyBadAmt['error'], contains('mayor o igual a cero'));

        // 2. PUT con fecha inválida
        final putReqBadDate = await httpClient.put('127.0.0.1', server.port, '/api/clients/$clientId/payments/$paymentId');
        putReqBadDate.headers.contentType = ContentType.json;
        putReqBadDate.write(jsonEncode({
          'amount': 35.0,
          'date': 'no-es-fecha-iso',
        }));
        final putResBadDate = await putReqBadDate.close();
        expect(putResBadDate.statusCode, equals(HttpStatus.badRequest));
        final bodyBadDate = jsonDecode(await utf8.decodeStream(putResBadDate)) as Map<String, dynamic>;
        expect(bodyBadDate['error'], contains('formato ISO'));
      } finally {
        httpClient.close();
        await server.close(force: true);
      }
    });

    test('5. REST HTTP: PUT /api/clients/:id/payments/:paymentId exitoso retorna HTTP 200 y actualiza datos contables', () async {
      final signer = LicenseSigner();
      final testSeed = List<int>.generate(32, (i) => (i * 3 + 7) % 256);
      await signer.initWithSeed(testSeed);

      final excelService = ExcelExportService(dbService: db, configService: configService);
      final vaultStorage = VaultStorageService(
        dbService: db,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            db,
            signer,
            configService,
            excelService,
            vaultStorage,
          ));

      final httpClient = HttpClient();

      try {
        final c = await db.createClient({
          'business_name': 'Distribuidora Norte',
          'owner_name': 'Luis Alva',
          'phone': '987000111',
          'current_device_id': 'ML-5544',
        });
        final clientId = c['id'] as String;

        final clientWithPay = await db.addPayment(clientId, {
          'amount': 35.0,
          'plan': 'MENSUAL',
          'method': 'Yape',
        });
        expect(clientWithPay, isNotNull);
        final paymentsList = (clientWithPay!['payment_history'] as List).cast<Map<String, dynamic>>();
        final paymentId = paymentsList.last['id'] as String;

        // Emitir comprobante previo
        await db.issueOrGetPaymentReceipt(
          clientId: clientId,
          paymentId: paymentId,
          configService: configService,
        );

        // Actualizar vía REST
        final putReq = await httpClient.put('127.0.0.1', server.port, '/api/clients/$clientId/payments/$paymentId');
        putReq.headers.contentType = ContentType.json;
        putReq.write(jsonEncode({
          'amount': 95.0,
          'plan': 'TRIMESTRAL',
          'method': 'Transferencia BCP',
          'reference': 'OP-998877',
          'date': '2026-11-21',
        }));
        final putRes = await putReq.close();
        expect(putRes.statusCode, equals(HttpStatus.ok));

        final updatedClient = jsonDecode(await utf8.decodeStream(putRes)) as Map<String, dynamic>;
        expect((updatedClient['total_paid'] as num).toDouble(), equals(95.0));

        final payments = (updatedClient['payment_history'] as List).cast<Map<String, dynamic>>();
        final updatedPayment = payments.firstWhere((item) => item['id'] == paymentId);
        expect((updatedPayment['amount'] as num).toDouble(), equals(95.0));
        expect(updatedPayment['plan'], equals('TRIMESTRAL'));
        expect(updatedPayment['method'], equals('Transferencia BCP'));
        expect(updatedPayment['receipt_number'], startsWith('BOL-'));
        expect(updatedPayment['updated_at'], isNotNull);
      } finally {
        httpClient.close();
        await server.close(force: true);
      }
    });

    test('6. Inspección Estática: Slugs canónicos, formatos y UI limpia en index.html', () {
      final html = WebBundleLoader.loadHtml();
      expect(html, isNotEmpty, reason: 'index.html debe existir en web/');

      // Slugs canónicos obligatorios en manualPayPlanPreset
      final canonicalSlugs = [
        'MENSUAL',
        'TRIMESTRAL',
        'SEMESTRAL',
        'ANUAL',
        'PERPETUO_LIBERADO',
        'PASE_ACTUALIZACION_ANUAL',
        'RECARGA_IA_150',
        'BONO_IA_PERSONALIZADO',
        'SERVICIO_MIGRACION',
        'EXTENSION_CORTESIA',
        'ABONO_PARCIAL',
        'CUSTOM',
      ];

      for (final slug in canonicalSlugs) {
        expect(
          html.contains('value="$slug"'),
          isTrue,
          reason: 'index.html debe contener opción con slug canónico "$slug"',
        );
      }

      // Validación de step="0.01" y min="0" en manualPayAmount
      expect(html.contains('id="manualPayAmount"'), isTrue);
      expect(html.contains('step="0.01"'), isTrue);
      expect(html.contains('min="0"'), isTrue);

      // Elementos de aviso de comprobante y checkbox alineado
      expect(html.contains('id="manualPayReceiptNotice"'), isTrue);
      expect(html.contains('id="manualPayReceiptNumberBadge"'), isTrue);
      expect(html.contains('class="checkbox-row-styled"'), isTrue);
      expect(html.contains('id="manualPayGenerateReceiptLabel"'), isTrue);
    });

    test('7. Inspección Estática: Funciones de normalización y formateo en admin_app.js', () {
      final js = WebBundleLoader.loadJs();
      expect(js, isNotEmpty, reason: 'admin_app.js debe existir en web/js/');

      // Existencia de la función normalizePlanToSlug
      expect(js.contains('function normalizePlanToSlug(rawPlan)'), isTrue);
      expect(js.contains("if (p === 'MENSUAL') return 'MENSUAL';"), isTrue);
      expect(js.contains("if (p.includes('MENSUAL')) return 'MENSUAL';"), isTrue);
      expect(js.contains("if (p === 'PERPETUO_LIBERADO'"), isTrue);
      expect(js.contains("if (p.includes('PERPETU')) return 'PERPETUO_LIBERADO';"), isTrue);

      // Verificación de toFixed(2) en carga de montos y selector de preset
      expect(js.contains('toFixed(2)'), isTrue);

      // Presencia de badge-edited-payment y comprobante actualizado
      expect(js.contains('badge-edited-payment'), isTrue);
      expect(js.contains('manualPayReceiptNotice'), isTrue);
      expect(js.contains('manualPayReceiptNumberBadge'), isTrue);
    });

    test('8. Inspección Estática: Reglas CSS para tema Oscuro y Claro en styles.css', () {
      final css = WebBundleLoader.loadCss();
      expect(css, isNotEmpty, reason: 'styles.css debe existir en web/css/');

      expect(css.contains('.checkbox-row-styled'), isTrue);
      expect(css.contains('.receipt-notice-banner'), isTrue);
      expect(css.contains('.badge-edited-payment'), isTrue);

      // Soporte tema claro
      expect(css.contains('[data-theme="light"] .checkbox-row-styled'), isTrue);
      expect(css.contains('[data-theme="light"] .receipt-notice-banner'), isTrue);
      expect(css.contains('[data-theme="light"] .badge-edited-payment'), isTrue);
    });
  });
}
