import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';

void main() {
  group('Plan Maestro 18.5 - Fase 3: Blindaje Anti-Colisión Correlativos, Comprobantes Canvas/HTML y Dashboard', () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late File clientsDbFile;
    late DatabaseService db;
    late ConfigService configService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_plan18_5_fase3_');
      dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempDir.path}/backups')..createSync(recursive: true);
      clientsDbFile = File('${dataDir.path}/sandbox_clients_db.json');
      clientsDbFile.writeAsStringSync(jsonEncode([]));

      db = DatabaseService(dataDir: dataDir.path);
      db.setMode('sandbox');

      configService = ConfigService(dataDirectory: dataDir, backupsDirectory: backupsDir);
      await configService.init();
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('3.1. DatabaseService: Blindaje Anti-Colisión de Correlativos BOL- y FAC- ante desfase de ConfigService', () async {
      // 1. Crear primer cliente y registrar pago
      final c1 = await db.createClient({
        'business_name': 'Bodega San Martín',
        'owner_name': 'Carlos Rojas',
        'phone': '987111222',
        'current_device_id': 'ML-1001',
      });
      final c1Id = c1['id'] as String;

      final c1WithPay = await db.addPayment(c1Id, {
        'amount': 35.0,
        'plan': 'MENSUAL',
      });
      final p1Id = ((c1WithPay!['payment_history'] as List).last as Map)['id'] as String;

      // 2. Emitir primer comprobante Boleta BOL-0001
      final r1Bol = await db.issueOrGetPaymentReceipt(
        clientId: c1Id,
        paymentId: p1Id,
        configService: configService,
        voucherType: 'BOL',
      );
      expect(r1Bol, isNotNull);
      expect(r1Bol!['receipt_number'], equals('BOL-0001'));
      expect(r1Bol['receipt_bol_number'], equals('BOL-0001'));

      // 3. Emitir Factura FAC-0001 para el mismo pago (conversión/comprobante fiscal)
      final r1Fac = await db.issueOrGetPaymentReceipt(
        clientId: c1Id,
        paymentId: p1Id,
        configService: configService,
        voucherType: 'FAC',
        invoiceRuc: '20123456789',
        invoiceBusinessName: 'San Martin SAC',
      );
      expect(r1Fac, isNotNull);
      expect(r1Fac!['receipt_number'], equals('FAC-0001'));
      expect(r1Fac['receipt_fac_number'], equals('FAC-0001'));
      // Preserva el boleta previo intacto
      expect(r1Fac['receipt_bol_number'], equals('BOL-0001'));

      // 4. SIMULAR DESFASE / RESET ACCIDENTAL EN CONFIGSERVICE (ambos contadores forzados a 1)
      final rawCfg = Map<String, dynamic>.from(configService.config);
      final rawRc = Map<String, dynamic>.from(configService.receiptConfig);
      rawRc['sandbox_next_correlative'] = 1;
      rawRc['sandbox_next_invoice_correlative'] = 1;
      rawCfg['receipt_config'] = rawRc;
      await configService.saveConfig(rawCfg);

      expect(configService.receiptConfig['sandbox_next_correlative'], equals(1));
      expect(configService.receiptConfig['sandbox_next_invoice_correlative'], equals(1));

      // 5. Crear segundo cliente y registrar pago
      final c2 = await db.createClient({
        'business_name': 'Farmacia Santa Rosa',
        'owner_name': 'Rosa Benites',
        'phone': '987333444',
        'current_device_id': 'ML-1002',
      });
      final c2Id = c2['id'] as String;

      final c2WithPay = await db.addPayment(c2Id, {
        'amount': 90.0,
        'plan': 'TRIMESTRAL',
      });
      final p2Id = ((c2WithPay!['payment_history'] as List).last as Map)['id'] as String;

      // 6. Emitir Boleta para cliente 2: DEBE detectar maxExisting = 1 y asignar BOL-0002 (nunca colisionar con BOL-0001)
      final r2Bol = await db.issueOrGetPaymentReceipt(
        clientId: c2Id,
        paymentId: p2Id,
        configService: configService,
        voucherType: 'BOL',
      );
      expect(r2Bol, isNotNull);
      expect(r2Bol!['receipt_number'], equals('BOL-0002'), reason: 'No debe colisionar con BOL-0001');
      expect(r2Bol['receipt_bol_number'], equals('BOL-0002'));

      // Verificar que el contador de ConfigService quedó sincronizado a 3 (seguridad para futuras emisiones)
      expect(configService.receiptConfig['sandbox_next_correlative'], equals(3),
          reason: 'ConfigService debe sincronizarse a safeNum + 1');

      // 7. Emitir Factura para cliente 2: DEBE detectar maxExisting = 1 y asignar FAC-0002 (nunca colisionar con FAC-0001)
      final r2Fac = await db.issueOrGetPaymentReceipt(
        clientId: c2Id,
        paymentId: p2Id,
        configService: configService,
        voucherType: 'FAC',
        invoiceRuc: '20987654321',
        invoiceBusinessName: 'Santa Rosa Farmacias SAC',
      );
      expect(r2Fac, isNotNull);
      expect(r2Fac!['receipt_number'], equals('FAC-0002'), reason: 'No debe colisionar con FAC-0001');
      expect(r2Fac['receipt_fac_number'], equals('FAC-0002'));
      expect(configService.receiptConfig['sandbox_next_invoice_correlative'], equals(3));
    });

    test('3.2. DatabaseService: Idempotencia estricta sin incremento de contadores', () async {
      final client = await db.createClient({
        'business_name': 'Bazar Central',
        'owner_name': 'Maria Gomez',
        'phone': '987555666',
        'current_device_id': 'ML-1003',
      });
      final cId = client['id'] as String;

      final clientWithPay = await db.addPayment(cId, {
        'amount': 35.0,
        'plan': 'MENSUAL',
      });
      final pId = ((clientWithPay!['payment_history'] as List).last as Map)['id'] as String;

      // Emisión inicial
      final firstBol = await db.issueOrGetPaymentReceipt(
        clientId: cId,
        paymentId: pId,
        configService: configService,
        voucherType: 'BOL',
      );
      expect(firstBol!['receipt_number'], equals('BOL-0001'));
      final nextCorrAfterFirst = configService.receiptConfig['sandbox_next_correlative'];

      // Segunda consulta para el mismo pago y tipo: debe devolver exactamente el mismo correlativo
      final secondBol = await db.issueOrGetPaymentReceipt(
        clientId: cId,
        paymentId: pId,
        configService: configService,
        voucherType: 'BOL',
      );
      expect(secondBol!['receipt_number'], equals('BOL-0001'));
      expect(configService.receiptConfig['sandbox_next_correlative'], equals(nextCorrAfterFirst),
          reason: 'Llamada idempotente no debe avanzar el contador en ConfigService');
    });

    test('3.3. Inspección Estática Frontend: Canvas >= 430px, Contraste Fijo en .rdoc-paper y formatPlanHumanLabel', () {
      final jsFile = File('web/js/admin_app.js');
      expect(jsFile.existsSync(), isTrue);
      final js = jsFile.readAsStringSync();

      final cssFile = File('web/css/styles.css');
      expect(cssFile.existsSync(), isTrue);
      final css = cssFile.readAsStringSync();

      // 1. Canvas >= 430px y medición dinámica
      expect(js.contains('Math.max(430, labelW + amountW + 70)'), isTrue,
          reason: 'Caja sin IGV debe medir mínimo 430px y usar ctx.measureText');
      expect(js.contains('Math.max(430, width - 120 > 430 ? 430 : width - 120)'), isTrue,
          reason: 'Caja con IGV debe medir mínimo 430px');

      // 2. Formato comercial humano en comprobantes
      expect(js.contains('formatPlanHumanLabel(payment.plan) || payment.plan'), isTrue,
          reason: 'Tanto en HTML preview como en Canvas debe usarse formatPlanHumanLabel');

      // 3. Contraste fijo oscuro en .rdoc-total-box (sin variables dinámicas de tema claro/oscuro sobre papel blanco)
      final renderReceiptIdx = js.indexOf('function renderReceiptPreviewAndCanvas()');
      expect(renderReceiptIdx, isPositive);
      final drawCanvasIdx = js.indexOf('function drawReceiptOnCanvas()', renderReceiptIdx);
      final receiptPreviewBlock = js.substring(renderReceiptIdx, drawCanvasIdx);
      expect(receiptPreviewBlock.contains('var(--text-secondary)'), isFalse,
          reason: 'No debe haber variables dinámicas de texto secundario sobre papel blanco');
      expect(receiptPreviewBlock.contains('var(--text-primary)'), isFalse,
          reason: 'No debe haber variables dinámicas de texto primario sobre papel blanco');

      // 4. Micro-leyenda aclaratoria en Finanzas
      expect(js.contains('receipt-matched-prev'), isTrue);
      expect(css.contains('.receipt-matched-prev'), isTrue);
    });

    test('3.4. Inspección Estática Frontend: Orden de carga Dashboard y ausencia de emoji reloj ⏳', () {
      final jsFile = File('web/js/admin_app.js');
      final js = jsFile.readAsStringSync();

      // 1. loadClients() antes de loadDashboard() en DOMContentLoaded
      final domLoadedIdx = js.indexOf("document.addEventListener('DOMContentLoaded'");
      expect(domLoadedIdx, isPositive);
      final loadClientsIdx = js.indexOf('await loadClients();', domLoadedIdx);
      final loadDashboardIdx = js.indexOf('await loadDashboard();', domLoadedIdx);
      expect(loadClientsIdx, isPositive);
      expect(loadDashboardIdx, isPositive);
      expect(loadClientsIdx, lessThan(loadDashboardIdx),
          reason: 'loadClients() debe ejecutarse ANTES de loadDashboard() para que el gráfico de dona tenga datos');

      // 2. renderPlanDistributionChart ejecutado en loadClients()
      final loadClientsFuncIdx = js.indexOf('async function loadClients()');
      expect(loadClientsFuncIdx, isPositive);
      final nextFuncIdx = js.indexOf('function compareSemVer', loadClientsFuncIdx);
      final loadClientsBlock = js.substring(loadClientsFuncIdx, nextFuncIdx);
      expect(loadClientsBlock.contains('renderPlanDistributionChart(globalClients)'), isTrue,
          reason: 'loadClients() debe actualizar la dona de cartera');

      // 3. Ausencia del emoji residual ⏳ en Acciones Urgentes
      final urgentTableIdx = js.indexOf('urgentTableBody');
      expect(urgentTableIdx, isPositive);
      final urgentEndIdx = js.indexOf('dashPendingActionsAlert', urgentTableIdx);
      expect(urgentEndIdx, isPositive);
      final urgentBlock = js.substring(urgentTableIdx, urgentEndIdx);
      expect(urgentBlock.contains('⏳'), isFalse,
          reason: 'No debe quedar ningún emoji ⏳ en la tabla de acciones urgentes');
      expect(urgentBlock.contains('<svg width="12" height="12" viewBox="0 0 24 24"'), isTrue,
          reason: 'Debe renderizarse el ícono SVG de reloj');

      // 4. Pulido de Resumen en Ficha 360°
      expect(js.contains("formatPlanHumanLabel(client.license_type)"), isTrue);
      expect(js.contains("document.getElementById('drawerKpiAiCredits').textContent = `\${realAi} IA`;"), isTrue);
      expect(js.contains("drawerKpiUpdates.textContent = 'Incluido en suscripción';"), isTrue);
    });
  });
}
