import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:excel/excel.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';
import '../lib/license_signer.dart';
import '../lib/excel_export_service.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';

void main() {
  late Directory tempDir;
  late Directory dataDir;
  late Directory backupsDir;
  late DatabaseService dbService;
  late ConfigService configService;
  late LicenseSigner signer;
  late ExcelExportService excelService;
  late VaultStorageService vaultStorage;
  final testSeed = List<int>.generate(32, (i) => (i * 7 + 13) % 256);

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('pilar15_comp_test_');
    dataDir = Directory('${tempDir.path}/data');
    backupsDir = Directory('${tempDir.path}/backups');
    await dataDir.create(recursive: true);
    await backupsDir.create(recursive: true);

    // Inicializar BD aislada y vacía para pruebas estrictas
    final sandboxClients = File('${dataDir.path}/sandbox_clients_db.json');
    await sandboxClients.writeAsString('[]');
    final sandboxReleases = File('${dataDir.path}/sandbox_releases_db.json');
    await sandboxReleases.writeAsString('[]');

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

    signer = LicenseSigner();
    await signer.initWithSeed(testSeed);

    excelService = ExcelExportService(
      dbService: dbService,
      configService: configService,
    );

    vaultStorage = VaultStorageService(
      dbService: dbService,
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

  group('Pilar 1: Saldo IA Desacoplado y Modelo de Hardware al Crear Cliente', () {
    test('Alta Trial desacopla saldo en celular (+49) y bono acordado (+20) sin falsa suma 70', () async {
      final client = await dbService.createClient({
        'business_name': 'Librería & Papelería Piura',
        'owner_name': 'Carlos Farfán',
        'document_id': '10485963214',
        'phone': '922836879',
        'current_device_id': 'ML-P101',
        'device_model': 'Samsung Galaxy A54 5G',
        'license_type': 'TRIAL',
        'ai_reported_balance': 49,
        'ai_pending_bonus': 20,
        'trial_days_remaining': 30,
      });

      expect(client['id'], isNotNull);
      expect(client['business_name'], equals('Librería & Papelería Piura'));
      expect(client['device_model'], equals('Samsung Galaxy A54 5G'));
      expect(client['ai_reported_balance'], equals(49));
      expect(client['ai_pending_bonus'], equals(20));
      expect(client['ai_extra_credits'], equals(0));
      // Invarianza estricta: los créditos extra entregados en tokens son 0
      final dynamicDisplay = (client['ai_reported_balance'] as int) + (client['ai_extra_credits'] as int);
      expect(dynamicDisplay, equals(49), reason: 'El saldo disponible inicial debe ser exactamente 49, no 70');
    });
  });

  group('Pilar 2: Modalidad BONO_IA_PERSONALIZADO (Gratuito y con Cobro Sugerido)', () {
    test('Bono IA Gratuito (S/ 0.00): y=0, c=20, cero cobros espurios y vigencia intacta', () async {
      final client = await dbService.createClient({
        'business_name': 'Minimarket San José',
        'owner_name': 'María Rosales',
        'phone': '987654321',
        'current_device_id': 'ML-P201',
        'license_type': 'TRIAL',
        'ai_reported_balance': 49,
        'ai_pending_bonus': 20,
      });

      final clientId = client['id'] as String;
      final originalExpires = client['license_expires'] as String;

      // Generar token BONO_IA_PERSONALIZADO con días = 0 y créditos = 20
      final token = await signer.generateLicenseToken(
        deviceFingerprint: 'ML-P201',
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        nonce: 1,
        aiExtraCredits: 20,
      );

      // Registrar emisión gratuita (paymentAmount: 0.0)
      final recordResult = await dbService.recordCodeEmission(
        clientId: clientId,
        token: token,
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        paymentAmount: 0.0,
        paymentMethod: 'Gratuito / Cortesía',
        paymentRef: 'CORTESIA-IA-01',
        updatesUntil: null,
        aiExtraCredits: 20,
      );

      expect(recordResult, isNotNull);
      final updatedClient = await dbService.getClientById(clientId);
      expect(updatedClient, isNotNull);

      // 1. Vigencia no se altera (y = 0)
      expect(updatedClient!['license_expires'], equals(originalExpires));
      // 2. Historial financiero libre de cobros espurios
      expect((updatedClient['payment_history'] as List).length, equals(0));
      // 3. Créditos extra acumulados actualizados
      expect(updatedClient['ai_extra_credits'], equals(20));
      // 4. Saldo efectivo en celular reflejado directamente (49 + 20 = 69)
      expect(updatedClient['ai_reported_balance'], equals(69));
      expect(updatedClient['ai_pending_bonus'], equals(0));
    });

    test('Bono IA con Cobro Sugerido (S/ 7.00): registra pago contable en payment_history', () async {
      final client = await dbService.createClient({
        'business_name': 'Comercial Grau',
        'owner_name': 'Luis Silva',
        'phone': '912345678',
        'current_device_id': 'ML-P202',
        'license_type': 'MENSUAL',
      });

      final clientId = client['id'] as String;
      final token = await signer.generateLicenseToken(
        deviceFingerprint: 'ML-P202',
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        nonce: 1,
        aiExtraCredits: 35,
      );

      await dbService.recordCodeEmission(
        clientId: clientId,
        token: token,
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        paymentAmount: 7.0,
        paymentMethod: 'YAPE',
        paymentRef: 'OP-BONO-777',
        updatesUntil: null,
        aiExtraCredits: 35,
      );

      final updatedClient = await dbService.getClientById(clientId);
      final payments = (updatedClient!['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(payments.length, equals(1));
      expect(payments.first['amount'], equals(7.0));
      expect(payments.first['plan'], equals('BONO_IA_PERSONALIZADO'));
      expect(payments.first['reference'], equals('OP-BONO-777'));
    });
  });

  group('Pilar 3 & 4: Configuración, Metadatos en Historial y Hardware', () {
    test('Plantillas WhatsApp personalizadas persisten en ConfigService', () async {
      final cfg = Map<String, dynamic>.from(configService.config);
      final tpls = Map<String, dynamic>.from(configService.templates);
      tpls['entrega_licencia'] = 'Hola {titular}, tu licencia {plan} está lista: {codigo}';
      cfg['templates'] = tpls;
      await configService.saveConfig(cfg);

      expect(configService.templates['entrega_licencia'], equals('Hola {titular}, tu licencia {plan} está lista: {codigo}'));

      // Verificar que se persiste en disco y se recarga
      final reloadedConfig = ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await reloadedConfig.init();
      expect(reloadedConfig.templates['entrega_licencia'], equals('Hola {titular}, tu licencia {plan} está lista: {codigo}'));
    });

    test('Códigos emitidos guardan nonce, created_at, expires_at y ai_credits', () async {
      final client = await dbService.createClient({
        'business_name': 'Bazar El Sol',
        'owner_name': 'Ana Torres',
        'current_device_id': 'ML-P301',
        'license_type': 'TRIMESTRAL',
      });

      final token = await signer.generateLicenseToken(
        deviceFingerprint: 'ML-P301',
        plan: 'TRIMESTRAL',
        daysToAdd: 90,
        nonce: 1,
        aiExtraCredits: 0,
      );

      await dbService.recordCodeEmission(
        clientId: client['id'] as String,
        token: token,
        plan: 'TRIMESTRAL',
        daysToAdd: 90,
        paymentAmount: 90.0,
        paymentMethod: 'PLIN',
        paymentRef: 'OP-TRIMESTRE-01',
        updatesUntil: null,
        aiExtraCredits: 0,
      );

      final history = await dbService.getClientHistory(client['id'] as String);
      final codes = (history!['codes'] as List).cast<Map<String, dynamic>>();
      expect(codes.length, equals(1));
      final c = codes.first;
      expect(c['nonce'], equals(1));
      expect(c['created_at'], isNotNull);
      expect(c['expires_at'], isNotNull);
      expect(c['ai_credits'], equals(180));
    });

    test('updateDeviceHistoryReason actualiza observaciones de hardware con persistencia', () async {
      final client = await dbService.createClient({
        'business_name': 'Bodega La Unión',
        'owner_name': 'Jorge Ramos',
        'current_device_id': 'ML-OLD1',
      });

      await dbService.migrateDevice(
        clientId: client['id'] as String,
        newDeviceId: 'ML-NEW1',
        feeAmount: 0.0,
        paymentMethod: 'Gratuito / Cortesía',
        reason: 'Razón inicial',
        migrationScenario: 'RESTORED_BACKUP',
        signer: signer,
      );

      final updated = await dbService.updateDeviceHistoryReason(
        clientId: client['id'] as String,
        historyIndex: 0,
        reason: 'Razón corregida por garantía de pantalla',
      );

      expect(updated, isNotNull);
      final devHist = (updated!['device_history'] as List).cast<Map<String, dynamic>>();
      expect(devHist.first['reason'], equals('Razón corregida por garantía de pantalla'));
    });
  });

  group('Pilar 5: Boletas de Pago Permanentes (BOL-XXXX) y Presets', () {
    test('Idempotencia de correlativo por pago: múltiples llamadas retornan el mismo BOL-XXXX', () async {
      final client = await dbService.createClient({
        'business_name': 'Farmacia Santa María',
        'owner_name': 'Carmen Vega',
        'current_device_id': 'ML-P501',
      });

      final updatedClient = await dbService.addManualPayment(
        client['id'] as String,
        {
          'amount': 35.0,
          'plan': 'MENSUAL',
          'method': 'Yape',
          'reference': 'OP-889900',
        },
      );

      final payments = (updatedClient!['payment_history'] as List).cast<Map<String, dynamic>>();
      final paymentId = payments.last['id'] as String;

      // Primera emisión de boleta
      final receipt1 = await dbService.issueOrGetPaymentReceipt(
        clientId: client['id'] as String,
        paymentId: paymentId,
        configService: configService,
      );

      expect(receipt1, isNotNull);
      final bolNum1 = receipt1!['receipt_number'] as String;
      expect(bolNum1.startsWith('BOL-'), isTrue);

      // Segunda llamada para el mismo pago: debe ser IDEMPOTENTE
      final receipt2 = await dbService.issueOrGetPaymentReceipt(
        clientId: client['id'] as String,
        paymentId: paymentId,
        configService: configService,
      );

      expect(receipt2!['receipt_number'], equals(bolNum1));
    });

    test('Configuración de boleta (receipt_config) guarda ciudad Piura, Perú y plantilla', () async {
      final defaultCity = configService.receiptConfig['issuer_city'] as String?;
      expect(defaultCity, contains('Piura'));

      final cfg = Map<String, dynamic>.from(configService.config);
      final rc = Map<String, dynamic>.from(configService.receiptConfig);
      rc['title'] = 'COMPROBANTE DE PAGO ELECTRÓNICO';
      rc['issuer_city'] = 'Piura, Perú';
      cfg['receipt_config'] = rc;
      await configService.saveConfig(cfg);

      expect(configService.receiptConfig['title'], equals('COMPROBANTE DE PAGO ELECTRÓNICO'));
      expect(configService.receiptConfig['issuer_city'], equals('Piura, Perú'));
    });
  });

  group('Pilar 6: Migración Segura de Dispositivo (Gratuita vs Estándar)', () {
    test('Escenario RESTORED_BACKUP con tarifa FREE emite y=0, m=1, c=0 y 0 cobros espurios', () async {
      final client = await dbService.createClient({
        'business_name': 'Librería Escolar',
        'owner_name': 'Felipe Moran',
        'current_device_id': 'ML-MIG1',
        'device_model': 'Xiaomi Redmi 10',
        'license_type': 'MENSUAL',
      });

      final result = await dbService.migrateDevice(
        clientId: client['id'] as String,
        newDeviceId: 'ML-MIG2',
        feeAmount: 0.0,
        paymentMethod: 'Gratuito / Cortesía',
        reason: 'Garantía por rotura de equipo',
        migrationScenario: 'RESTORED_BACKUP',
        newDeviceModel: 'Xiaomi Redmi Note 13',
        signer: signer,
        emitImmediately: true,
      );

      expect(result, isNotNull);
      expect(result!['current_device_id'], equals('ML-MIG2'));
      expect(result['device_model'], equals('Xiaomi Redmi Note 13'));
      // No debe existir pago generado
      expect(result.containsKey('payment_id'), isFalse);
      expect((result['payment_history'] as List).length, equals(0));

      final token = result['emitted_migration_token'] as String;
      expect(token.startsWith('ML9-'), isTrue);

      // Decodificar y verificar claims
      final payload = jsonDecode(utf8.decode(base64Decode(
        token.substring(4).split('.')[0].replaceAll('-', '+').replaceAll('_', '/') + '=='.substring(0, (4 - (token.substring(4).split('.')[0].length % 4)) % 4),
      ))) as Map<String, dynamic>;

      expect(payload['m'], equals(1), reason: 'Claim de migración m=1 requerido');
      expect(payload['y'], equals(0), reason: 'RESTORED_BACKUP debe emitir y=0 días');
      expect(payload['d'], equals('ML-MIG2'));
    });

    test('Escenario CLEAN_INSTALL con tarifa STANDARD cobra S/ 40.00 y genera payment_id', () async {
      final client = await dbService.createClient({
        'business_name': 'Bodega La Parada',
        'owner_name': 'Rogelio Silva',
        'current_device_id': 'ML-MIG3',
        'license_type': 'MENSUAL',
      });

      final result = await dbService.migrateDevice(
        clientId: client['id'] as String,
        newDeviceId: 'ML-MIG4',
        feeAmount: 40.0,
        paymentMethod: 'BCP',
        reason: 'Nuevo celular limpio',
        migrationScenario: 'CLEAN_INSTALL',
        signer: signer,
        emitImmediately: true,
      );

      expect(result, isNotNull);
      expect(result!['payment_id'], isNotNull);
      final payments = (result['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(payments.length, equals(1));
      expect(payments.first['amount'], equals(40.0));
      expect(payments.first['plan'], equals('SERVICIO_MIGRACION'));
    });
  });

  group('Pilar 7: Apagado Seguro, Exportador Excel y Auditoría Estructural UI', () {
    test('POST /api/system/shutdown con PIN bloqueado retorna HTTP 423 y no apaga', () async {
      // 1. Activar PIN en la bóveda
      await vaultStorage.configurePin(enabled: true, pin: '849201');

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      int exitCalled = -1;

      server.listen((req) => handleRequest(
            req,
            dbService,
            signer,
            configService,
            excelService,
            vaultStorage,
            onExitOverride: (code) => exitCalled = code,
          ));

      final client = HttpClient();
      try {
        final req = await client.postUrl(Uri.parse('http://localhost:${server.port}/api/system/shutdown'));
        final res = await req.close();

        // Debe retornar HTTP 423 Locked
        expect(res.statusCode, equals(423));
        expect(exitCalled, equals(-1), reason: 'No se debió invocar onExitOverride cuando la sesión está bloqueada');
      } finally {
        client.close();
        await server.close(force: true);
      }
    });

    test('POST /api/system/shutdown sin PIN retorna HTTP 200 e invoca onExitOverride(0)', () async {
      // Asegurar que el PIN esté desactivado
      await vaultStorage.configurePin(pin: null, enabled: false);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      int exitCalled = -1;

      server.listen((req) => handleRequest(
            req,
            dbService,
            signer,
            configService,
            excelService,
            vaultStorage,
            onExitOverride: (code) => exitCalled = code,
          ));

      final client = HttpClient();
      try {
        final req = await client.postUrl(Uri.parse('http://localhost:${server.port}/api/system/shutdown'));
        final res = await req.close();

        expect(res.statusCode, equals(200));
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['ok'], isTrue);
        expect(json['message'], contains('apagado correctamente'));

        // Esperar el margen de gracia de 250ms
        await Future.delayed(const Duration(milliseconds: 350));
        expect(exitCalled, equals(0), reason: 'onExitOverride debe ser invocado con código 0');
      } finally {
        client.close();
        await server.close(force: true);
      }
    });

    test('ExcelExportService genera libro .xlsx integral con prospectos, recibos y bonos IA', () async {
      // Registrar un prospecto
      await dbService.createClient({
        'business_name': 'Prospecto Comercial Chiclayo',
        'owner_name': 'Elena Gil',
        'phone': '987000111',
        'current_device_id': 'PENDIENTE',
        'license_type': 'PROSPECTO',
      });

      // Registrar cliente con bono y pago
      final c2 = await dbService.createClient({
        'business_name': 'Librería Norte',
        'owner_name': 'Marcos Polo',
        'phone': '987222333',
        'current_device_id': 'ML-X101',
        'device_model': 'Samsung Galaxy S23',
        'license_type': 'TRIAL',
        'ai_reported_balance': 49,
        'ai_pending_bonus': 20,
      });

      final updatedC2 = await dbService.addManualPayment(
        c2['id'] as String,
        {
          'amount': 35.0,
          'plan': 'MENSUAL',
          'method': 'Yape',
          'reference': 'OP-EXCEL-001',
        },
      );
      final c2Payments = (updatedC2!['payment_history'] as List).cast<Map<String, dynamic>>();
      await dbService.issueOrGetPaymentReceipt(
        clientId: c2['id'] as String,
        paymentId: c2Payments.last['id'] as String,
        configService: configService,
      );

      final bytes = await excelService.generateMasterWorkbook();
      expect(bytes.isNotEmpty, isTrue);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.sheets.keys.length, equals(5));

      final crmSheet = excel['Cartera CRM'];
      expect(crmSheet, isNotNull);
      final rows = crmSheet.rows;
      // Verificar que el prospecto figura con estado PROSPECTO
      final prospectRow = rows.firstWhere((r) => r.any((cell) => cell?.value?.toString().contains('Prospecto Comercial') ?? false));
      expect(prospectRow[7]?.value?.toString(), equals('PROSPECTO'));

      // Verificar que el modelo figura en columna Hardware ID
      final clientRow = rows.firstWhere((r) => r.any((cell) => cell?.value?.toString().contains('Librería Norte') ?? false));
      expect(clientRow[5]?.value?.toString(), contains('Samsung Galaxy S23'));

      final paySheet = excel['Libro de Pagos'];
      expect(paySheet, isNotNull);
      final payRows = paySheet.rows;
      // Verificar que la boleta BOL-XXXX figura en la columna de referencia
      final receiptCell = payRows.any((r) => r[9]?.value?.toString().contains('BOL-') ?? false);
      expect(receiptCell, isTrue);
    });

    test('Verificación estructural en disco de CSS, HTML y JS (Plan Maestro 15)', () {
      final cssFile = File('web/css/styles.css');
      final htmlFile = File('web/index.html');
      final jsFile = File('web/js/admin_app.js');

      expect(cssFile.existsSync(), isTrue);
      expect(htmlFile.existsSync(), isTrue);
      expect(jsFile.existsSync(), isTrue);

      final css = cssFile.readAsStringSync();
      final html = htmlFile.readAsStringSync();
      final js = jsFile.readAsStringSync();

      // 1. CSS
      expect(css.contains('color-scheme: dark'), isTrue, reason: 'Garantiza selects y datepickers oscuros en Chromium');
      expect(css.contains('z-index: 3000'), isTrue, reason: 'Gestor de capas Ficha 360 vs Modales');
      expect(css.contains('.btn-shutdown-server'), isTrue);
      expect(css.contains('.modal-receipt-dialog'), isTrue);
      expect(css.contains('.mig-preservation-card'), isTrue);

      // 2. HTML
      expect(html.contains('id="btnShutdownServer"'), isTrue);
      expect(html.contains('id="modalPaymentReceipt"'), isTrue);
      expect(html.contains('id="modalWaComposer"'), isTrue);
      expect(html.contains('id="modalSyncReported"'), isTrue);
      expect(html.contains('id="migScenario"'), isTrue);
      expect(html.contains('id="migFeeMode"'), isTrue);

      // 3. JS
      expect(js.contains('drawerReturnState'), isTrue, reason: 'Preservación de retorno automático a Ficha 360');
      expect(js.contains('openPaymentReceiptModal'), isTrue);
      expect(js.contains('handleMigrateDeviceSubmit'), isTrue);
      expect(js.contains('renderShutdownSuccessScreen'), isTrue);
    });
  });
}
