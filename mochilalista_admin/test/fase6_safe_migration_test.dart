import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/license_signer.dart';
import '../lib/config_service.dart';

void main() {
  group('FASE 6: Migración Segura de Dispositivos y Blindaje de Preservación', () {
    late Directory tempDir;
    late Directory backupsDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late LicenseSigner signer;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_admin_fase6_test_');
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
      await signer.initWithSeed(List<int>.filled(32, 9));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Escenario RESTORED_BACKUP emite token con y = 0 y c = 0 sin alterar fecha ni duplicar días', () async {
      final expFuture = DateTime.now().add(const Duration(days: 45)).toIso8601String();
      final client = await dbService.createClient({
        'business_name': 'Bodega San Martín',
        'owner_name': 'Carlos Sánchez',
        'phone': '+51987654321',
        'current_device_id': 'ML-OLD1',
        'license_type': 'TRIMESTRAL',
        'license_expires': expFuture,
        'ai_reported_balance': 85,
      });
      final clientId = client['id'] as String;

      final res = await dbService.migrateDevice(
        clientId: clientId,
        newDeviceId: 'ML-NEW1',
        feeAmount: 40.0,
        paymentMethod: 'Yape',
        reason: 'Renovó a Xiaomi Redmi Note 13',
        emitImmediately: true,
        signer: signer,
        migrationScenario: 'RESTORED_BACKUP',
        newDeviceModel: 'Xiaomi Redmi Note 13',
      );

      expect(res, isNotNull);
      expect(res!['current_device_id'], equals('ML-NEW1'));
      expect(res['device_model'], equals('Xiaomi Redmi Note 13'));
      expect(res['license_expires'], equals(expFuture)); // Preservación 100% intacta
      expect(res['payment_id'], startsWith('MIG-'));

      // Verificar token Ed25519 emitido
      final tokenInfo = res['migration_token_info'] as Map<String, dynamic>;
      expect(tokenInfo['days_retained'], equals(0)); // y = 0
      expect(tokenInfo['migration_scenario'], equals('RESTORED_BACKUP'));

      // Verificar historial de hardware y códigos generados
      final reloadedClients = await dbService.getClients();
      final cData = reloadedClients.firstWhere((c) => c['id'] == clientId);
      final devHistory = (cData['device_history'] as List).cast<Map<String, dynamic>>();
      expect(devHistory.length, equals(1));
      expect(devHistory[0]['old_device_id'], equals('ML-OLD1'));
      expect(devHistory[0]['new_device_id'], equals('ML-NEW1'));
      expect(devHistory[0]['scenario'], equals('RESTORED_BACKUP'));
      expect(devHistory[0]['device_model'], equals('Xiaomi Redmi Note 13'));

      final codes = (cData['generated_codes_history'] as List).cast<Map<String, dynamic>>();
      expect(codes.length, equals(1));
      expect(codes[0]['days_added'], equals(0));
      expect(codes[0]['is_migration_token'], isTrue);
      expect(codes[0]['migration_scenario'], equals('RESTORED_BACKUP'));
      expect(codes[0]['ai_credits'], equals(0));
    });

    test('2. Escenario CLEAN_INSTALL transfiere los días restantes exactos calculados', () async {
      final expFuture = DateTime.now().add(const Duration(days: 28)).toIso8601String();
      final client = await dbService.createClient({
        'business_name': 'Farmacia Central',
        'owner_name': 'Elena Prado',
        'phone': '+51955443322',
        'current_device_id': 'ML-FC01',
        'license_type': 'MENSUAL',
        'license_expires': expFuture,
      });
      final clientId = client['id'] as String;

      final res = await dbService.migrateDevice(
        clientId: clientId,
        newDeviceId: 'ML-FC02',
        feeAmount: 40.0,
        paymentMethod: 'Plin',
        emitImmediately: true,
        signer: signer,
        migrationScenario: 'CLEAN_INSTALL',
      );

      expect(res, isNotNull);
      final tokenInfo = res!['migration_token_info'] as Map<String, dynamic>;
      expect(tokenInfo['days_retained'], inInclusiveRange(27, 29)); // ~28 días
      expect(tokenInfo['migration_scenario'], equals('CLEAN_INSTALL'));
    });

    test('3. Modalidad FREE (S/ 0.00) NO registra pagos ficticios en payment_history', () async {
      final client = await dbService.createClient({
        'business_name': 'Bazar Perú',
        'owner_name': 'Rosa Flores',
        'phone': '+51944332211',
        'current_device_id': 'ML-BZ01',
        'license_type': 'MENSUAL',
      });
      final clientId = client['id'] as String;

      final res = await dbService.migrateDevice(
        clientId: clientId,
        newDeviceId: 'ML-BZ02',
        feeAmount: 0.0,
        paymentMethod: 'Gratuito / Cortesía',
        reason: 'Garantía de equipo / Traslado gratuito por cortesía',
        emitImmediately: true,
        signer: signer,
        migrationScenario: 'RESTORED_BACKUP',
      );

      expect(res, isNotNull);
      expect(res!['payment_id'], isNull); // Sin ID de pago

      final reloadedClients = await dbService.getClients();
      final cData = reloadedClients.firstWhere((c) => c['id'] == clientId);
      final payments = (cData['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      expect(payments, isEmpty); // CERO contaminación del libro de pagos

      final devHistory = (cData['device_history'] as List).cast<Map<String, dynamic>>();
      expect(devHistory[0]['fee_charged'], equals(0.0));
      expect(devHistory[0]['payment_method'], equals('Gratuito / Cortesía'));
      expect(devHistory[0]['reason'], contains('Garantía de equipo'));
    });

    test('4. Modalidad STANDARD o CUSTOM registra el pago en payment_history y retorna payment_id', () async {
      final client = await dbService.createClient({
        'business_name': 'Librería Escolar',
        'owner_name': 'Mario Gómez',
        'phone': '+51911223344',
        'current_device_id': 'ML-LB01',
        'license_type': 'MENSUAL',
      });
      final clientId = client['id'] as String;

      final res = await dbService.migrateDevice(
        clientId: clientId,
        newDeviceId: 'ML-LB02',
        feeAmount: 50.0,
        paymentMethod: 'Transferencia BCP',
        reason: 'Migración personalizada solicitada',
        emitImmediately: false,
      );

      expect(res, isNotNull);
      expect(res!['payment_id'], startsWith('MIG-'));

      final reloadedClients = await dbService.getClients();
      final cData = reloadedClients.firstWhere((c) => c['id'] == clientId);
      final payments = (cData['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(payments.length, equals(1));
      expect(payments[0]['amount'], equals(50.0));
      expect(payments[0]['plan'], equals('SERVICIO_MIGRACION'));
      expect(payments[0]['method'], equals('Transferencia BCP'));
    });
  });
}
