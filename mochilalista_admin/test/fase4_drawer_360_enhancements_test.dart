import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/config_service.dart';
import '../lib/license_signer.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('FASE 4: Ficha 360° Drawer, Metadatos QR, Pagos Compactos y Hardware',
      () {
    late Directory tempDir;
    late Directory backupsDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late LicenseSigner signer;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_admin_fase4_test_');
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

      signer = LicenseSigner();
      await signer.initWithSeed(List<int>.generate(32, (i) => (i * 7 + 13) % 256));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        '1. recordCodeEmission guarda todos los metadatos necesarios en generated_codes_history',
        () async {
      final client = await dbService.createClient({
        'business_name': 'Bodega San Juan',
        'owner_name': 'Juan Pérez',
        'phone': '+51987654321',
        'current_device_id': 'ML-SJ01',
        'license_type': 'TRIAL',
        'license_status': 'ACTIVE',
        'ai_reported_balance': 50,
      });

      expect(client, isNotNull);
      final clientId = client['id'] as String;

      final updated = await dbService.recordCodeEmission(
        clientId: clientId,
        token: 'ML9-TEST-TOKEN-1234',
        plan: 'MENSUAL',
        daysToAdd: 30,
        paymentAmount: 35.0,
        paymentMethod: 'Yape',
        paymentRef: 'Op. 12345',
        updatesUntil: DateTime(2027, 2, 1),
        aiExtraCredits: 20,
      );

      expect(updated, isNotNull);
      final codes = (updated!['generated_codes_history'] as List)
          .cast<Map<String, dynamic>>();
      expect(codes.length, equals(1));

      final c = codes.first;
      expect(c['token'], equals('ML9-TEST-TOKEN-1234'));
      expect(c['plan'], equals('MENSUAL'));
      expect(c['days_added'], equals(30));
      expect(c['nonce'], equals(1));
      expect(c['created_at'], isNotNull);
      expect(c['emitted_at'], isNotNull);
      expect(c['device_id'], equals('ML-SJ01'));
      expect(c['expires_at'], isNotNull);
      expect(c['expires_result'], isNotNull);
      expect(c['ai_credits'], equals(70)); // 50 base plan + 20 extra
    });

    test(
        '2. migrateDevice con emitImmediately guarda nonce, created_at, expires_at y ai_credits en el histórico',
        () async {
      final client = await dbService.createClient({
        'business_name': 'Farmacia Central',
        'owner_name': 'Carlos Ruiz',
        'phone': '+51987654322',
        'current_device_id': 'ML-FC01',
        'license_type': 'MENSUAL',
        'license_status': 'ACTIVE',
        'license_expires': DateTime.now()
            .add(const Duration(days: 25))
            .toUtc()
            .toIso8601String(),
        'ai_reported_balance': 45,
      });

      expect(client, isNotNull);
      final clientId = client['id'] as String;

      final migrated = await dbService.migrateDevice(
        clientId: clientId,
        newDeviceId: 'ML-FC02',
        feeAmount: 40.0,
        paymentMethod: 'Yape',
        reason: 'Renovó a Xiaomi Redmi Note 13',
        emitImmediately: true,
        signer: signer,
      );

      expect(migrated, isNotNull);
      expect(migrated!['current_device_id'], equals('ML-FC02'));

      final codes = (migrated['generated_codes_history'] as List)
          .cast<Map<String, dynamic>>();
      expect(codes.length, equals(1));

      final c = codes.first;
      expect(c['device_id'], equals('ML-FC02'));
      expect(c['nonce'], equals(2));
      expect(c['created_at'], isNotNull);
      expect(c['emitted_at'], isNotNull);
      expect(c['expires_at'], isNotNull);
      expect(c['expires_result'], isNotNull);
      expect(c['ai_credits'],
          equals(0)); // Token de migración preserva sin inflar (c=0)
    });

    test(
        '3. updateDeviceHistoryReason actualiza atómicamente el motivo de migración y persiste en disco',
        () async {
      final client = await dbService.createClient({
        'business_name': 'Librería Escolar',
        'owner_name': 'Ana María',
        'phone': '+51987654323',
        'current_device_id': 'ML-LE01',
      });
      final clientId = client['id'] as String;

      await dbService.migrateDevice(
        clientId: clientId,
        newDeviceId: 'ML-LE02',
        feeAmount: 0.0,
        paymentMethod: 'Cortesía',
        reason: 'Motivo temporal previo',
        emitImmediately: false,
      );

      final updated = await dbService.updateDeviceHistoryReason(
        clientId: clientId,
        historyIndex: 0,
        reason: 'Celular mojado por lluvia - equipo de reemplazo urgente',
      );

      expect(updated, isNotNull);
      final history =
          (updated!['device_history'] as List).cast<Map<String, dynamic>>();
      expect(history.first['reason'],
          equals('Celular mojado por lluvia - equipo de reemplazo urgente'));

      // Verificar persistencia tras recargar de disco
      final reloadedClients = await dbService.getClients();
      final reloaded = reloadedClients.firstWhere((c) => c['id'] == clientId);
      final reloadedHistory =
          (reloaded['device_history'] as List).cast<Map<String, dynamic>>();
      expect(reloadedHistory.first['reason'],
          equals('Celular mojado por lluvia - equipo de reemplazo urgente'));
    });

    test(
        '4. ConfigService persiste plantillas personalizadas de WhatsApp sin descartarlas',
        () async {
      final customTemplates = {
        'welcome':
            '¡Hola {titular}! Personalizada para {negocio} con device {device_id}',
        'expiring': 'Estimado {titular}, vence pronto en {dias_restantes} días',
      };

      final current = configService.config;
      final newConfig = Map<String, dynamic>.from(current);
      newConfig['templates'] = customTemplates;

      final saved = await configService.saveConfig(newConfig);
      expect(saved['templates']['welcome'],
          contains('Personalizada para {negocio}'));
      expect(saved['templates']['expiring'],
          contains('vence pronto en {dias_restantes} días'));

      // Recargar desde disco
      await configService.reloadFromDisk();
      expect(configService.templates['welcome'],
          contains('Personalizada para {negocio}'));
      expect(configService.templates['expiring'],
          contains('vence pronto en {dias_restantes} días'));
    });

    test(
        '5. Integridad de Frontend: Elementos visuales, cards de pago y estilos de peligro',
        () {
      final html = WebBundleLoader.loadHtml();
      final css = WebBundleLoader.loadCss();
      final js = WebBundleLoader.loadJs();

      // Cero "+ + Registrar Pago Manual"
      expect(html.contains('+ + Registrar Pago Manual'), isFalse);
      expect(html.contains('Registrar Pago'), isTrue);

      // Tarjetas compactas de pago
      expect(css.contains('.drawer-payment-card'), isTrue);
      expect(css.contains('.drawer-payments-container'), isTrue);
      expect(html.contains('id="drawerPaymentsBody"'), isTrue);

      // Píldora de copiado de Hardware ID
      expect(css.contains('.btn-copy-pill'), isTrue);
      expect(html.contains('id="btnDrawerCopyCurrentDevId"'), isTrue);

      // Edición rápida inline de Modelo Celular
      expect(html.contains('id="btnDrawerEditModelInline"'), isTrue);
      expect(html.contains('id="drawerHwModelInlineForm"'), isTrue);

      // Botón rojo de peligro
      expect(css.contains('.btn-danger'), isTrue);
      expect(css.contains('#dc2626'), isTrue);
      expect(html.contains('btn-danger'), isTrue);
      expect(html.contains('id="btnDrawerDeleteClient"'), isTrue);

      // Botón Copiar Imagen Credencial y Emitir Nueva Licencia
      expect(html.contains('id="btnDrawerCopyCredential"'), isTrue);
      expect(html.contains('id="btnDrawerQrNewLicense"'), isTrue);

      // Control de Ventana Updates en admin_app.js
      expect(js.contains('function updateDrawerEditPlanFields('), isTrue);
      expect(js.contains('function openPaymentReceiptModal('), isTrue);
    });
  });
}
