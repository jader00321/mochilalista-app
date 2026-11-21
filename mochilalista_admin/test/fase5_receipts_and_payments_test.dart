import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';

void main() {
  group('FASE 5: Configuración de Boletas, Correlativos y Generación de Comprobantes', () {
    late Directory tempDir;
    late Directory backupsDir;
    late DatabaseService dbService;
    late ConfigService configService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_admin_fase5_test_');
      backupsDir = Directory('${tempDir.path}/backups');
      await backupsDir.create();

      dbService = DatabaseService(
        dataDir: '${tempDir.path}/data',
        backupDir: '${tempDir.path}/backups',
        releasesDir: '${tempDir.path}/releases',
      );
      await dbService.init();

      configService = ConfigService(
        dataDirectory: Directory('${tempDir.path}/data'),
        backupsDirectory: backupsDir,
      );
      await configService.init();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. ConfigService inicializa receipt_config con valores oficiales por defecto y ciudad "Piura, Perú"', () {
      final rc = configService.receiptConfig;
      expect(rc, isNotEmpty);
      expect(rc['title'], equals('BOLETA DE PAGO ADMINISTRATIVA'));
      expect(rc['commercial_name'], equals('MochilaLista'));
      expect(rc['issuer_name'], equals('Julio Angello Vasquez Navarro'));
      expect(rc['issuer_city'], equals('Piura, Perú'));
      expect(rc['show_logo'], isTrue);
      expect(rc['accent_color'], equals('#2563eb'));
      expect(rc['next_correlative'], equals(1));
      expect(rc['sandbox_next_correlative'], equals(1));
      expect(rc['signature_text'], contains('MochilaLista'));
    });

    test('2. Segregación estricta de correlativos: Sandbox vs Prod operan de forma independiente', () async {
      expect(configService.getNextReceiptCorrelative(isSandbox: true), equals(1));
      expect(configService.getNextReceiptCorrelative(isSandbox: false), equals(1));

      // Consumir en sandbox
      final sb1 = await configService.consumeReceiptCorrelative(isSandbox: true);
      expect(sb1, equals(1));
      expect(configService.getNextReceiptCorrelative(isSandbox: true), equals(2));
      // Prod permanece intacto
      expect(configService.getNextReceiptCorrelative(isSandbox: false), equals(1));

      // Consumir en prod
      final prod1 = await configService.consumeReceiptCorrelative(isSandbox: false);
      expect(prod1, equals(1));
      expect(configService.getNextReceiptCorrelative(isSandbox: false), equals(2));
      // Sandbox permanece en 2
      expect(configService.getNextReceiptCorrelative(isSandbox: true), equals(2));
    });

    test('3. issueOrGetPaymentReceipt asigna BOL-0001 en primer cobro y es 100% IDEMPOTENTE', () async {
      final client = await dbService.createClient({
        'business_name': 'Luzam Comercial',
        'owner_name': 'Angello Vasquez',
        'phone': '+51922836879',
        'current_device_id': 'ML-LZ01',
        'license_type': 'MENSUAL',
      });
      final clientId = client['id'] as String;

      // Registrar dos pagos para este cliente
      await dbService.addManualPayment(clientId, {
        'amount': 35.0,
        'plan': 'Renovación Mensual',
        'method': 'Yape',
        'reference': 'Op. 11111',
      });
      await dbService.addManualPayment(clientId, {
        'amount': 35.0,
        'plan': 'Renovación Mensual',
        'method': 'Plin',
        'reference': 'Op. 22222',
      });

      final reloadedClients = await dbService.getClients();
      final cData = reloadedClients.firstWhere((c) => c['id'] == clientId);
      final payments = (cData['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(payments.length, equals(2));

      final pay1Id = payments[0]['id'] as String;
      final pay2Id = payments[1]['id'] as String;

      // 1ra emisión de Pago 1: Debe asignar BOL-0001
      final res1 = await dbService.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: pay1Id,
        configService: configService,
        customNote: 'Primera boleta oficial',
      );
      expect(res1, isNotNull);
      expect(res1!['ok'], isTrue);
      expect(res1['receipt_number'], equals('BOL-0001'));
      expect(res1['already_issued'], isFalse);
      expect(res1['payment']['receipt_number'], equals('BOL-0001'));
      expect(res1['payment']['receipt_custom_note'], equals('Primera boleta oficial'));

      // 2da consulta de Pago 1: Debe devolver exactamente BOL-0001 (already_issued: true) sin incrementar correlativo
      final res1Retry = await dbService.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: pay1Id,
        configService: configService,
      );
      expect(res1Retry, isNotNull);
      expect(res1Retry!['receipt_number'], equals('BOL-0001'));
      expect(res1Retry['already_issued'], isTrue);

      // Emisión de Pago 2: Debe asignar BOL-0002
      final res2 = await dbService.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: pay2Id,
        configService: configService,
      );
      expect(res2, isNotNull);
      expect(res2!['receipt_number'], equals('BOL-0002'));
      expect(res2['already_issued'], isFalse);

      // Re-verificar persistencia en disco tras recarga completa
      final finalClients = await dbService.getClients();
      final finalClient = finalClients.firstWhere((c) => c['id'] == clientId);
      final finalPayments = (finalClient['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(finalPayments[0]['receipt_number'], equals('BOL-0001'));
      expect(finalPayments[1]['receipt_number'], equals('BOL-0002'));
    });

    test('4. ConfigService persiste modificaciones en receipt_config vía saveConfig', () async {
      final modified = Map<String, dynamic>.from(configService.config);
      final rc = Map<String, dynamic>.from(configService.receiptConfig);
      rc['title'] = 'COMPROBANTE ELECTRÓNICO OFICIAL';
      rc['accent_color'] = '#059669';
      rc['issuer_city'] = 'Piura, Perú';
      modified['receipt_config'] = rc;

      await configService.saveConfig(modified);
      expect(configService.receiptConfig['title'], equals('COMPROBANTE ELECTRÓNICO OFICIAL'));
      expect(configService.receiptConfig['accent_color'], equals('#059669'));

      // Recarga de disco
      await configService.reloadFromDisk();
      expect(configService.receiptConfig['title'], equals('COMPROBANTE ELECTRÓNICO OFICIAL'));
      expect(configService.receiptConfig['accent_color'], equals('#059669'));
    });
  });
}
