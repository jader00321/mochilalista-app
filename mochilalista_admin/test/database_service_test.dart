import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/license_signer.dart';

void main() {
  late Directory tempDir;
  late DatabaseService dbService;
  late LicenseSigner signer;
  final testSeed = List<int>.generate(32, (i) => (i * 3 + 17) % 256);

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ml_db_test_');
    dbService = DatabaseService(
      dataDir: '${tempDir.path}/data',
      backupDir: '${tempDir.path}/backups',
      releasesDir: '${tempDir.path}/releases',
    );
    await dbService.init();

    signer = LicenseSigner();
    await signer.initWithSeed(testSeed);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('1. Inicialización y Semillas Sandbox Sincronizadas v36', () {
    test('Sandbox se inicializa con esquema v36 y versión 9.34.0', () async {
      final releases = await dbService.getReleases();
      expect(releases.isNotEmpty, isTrue);
      final latest = releases.first;
      expect(latest['version_name'], equals('9.34.0'));
      expect(latest['version_code'], equals(78));
      expect(latest['db_schema_version'], equals(36));

      final clients = await dbService.getClients();
      expect(clients.isNotEmpty, isTrue);
      final c1 = clients.first;
      expect(c1['installed_version'], equals('9.34.0'));
      expect(c1['current_device_id'], equals('ML-9K4B'));
    });
  });

  group('2. Creación de Cliente y Acreditación de Saldo IA Inicial', () {
    test('Nuevo cliente TRIAL recibe automáticamente 50 escaneos acumulados', () async {
      final newClient = await dbService.createClient({
        'business_name': 'Librería Central',
        'owner_name': 'Mario Vargas',
        'phone': '+51988888888',
        'current_device_id': 'ML-AAAA',
        'license_type': 'TRIAL',
      });

      expect(newClient['id'], isNotNull);
      expect(newClient['ai_extra_credits'], equals(50));
      expect(newClient['ai_accumulated_credits'], equals(50));
      expect(newClient['installed_version'], equals('9.34.0'));
    });
  });

  group('3. Acumulación Estricta de Cuota IA (Cero Reseteo Mensual)', () {
    test('Secuencia TRIAL (50) -> +MENSUAL (50) -> +TRIMESTRAL (180) -> +RECARGA (150) = 430 escaneos', () async {
      // 1. Crear cliente TRIAL (50)
      final client = await dbService.createClient({
        'business_name': 'Bodega San Jorge',
        'owner_name': 'Jorge Benavides',
        'phone': '+51977777777',
        'current_device_id': 'ML-BBBB',
        'license_type': 'TRIAL',
      });
      final cId = client['id'] as String;
      expect(client['ai_extra_credits'], equals(50));

      // 2. Emitir MENSUAL (+50)
      final tokenMensual = await signer.generateLicenseToken(
        deviceFingerprint: 'ML-BBBB',
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );
      final afterMensual = await dbService.recordCodeEmission(
        clientId: cId,
        token: tokenMensual,
        plan: 'MENSUAL',
        daysToAdd: 30,
        paymentAmount: 35.0,
        paymentMethod: 'Yape',
        paymentRef: 'Op. 1111',
        updatesUntil: null,
      );
      expect(afterMensual!['ai_extra_credits'], equals(100)); // 50 + 50 = 100

      // 3. Emitir TRIMESTRAL (+180)
      final tokenTrimestral = await signer.generateLicenseToken(
        deviceFingerprint: 'ML-BBBB',
        plan: 'TRIMESTRAL',
        daysToAdd: 90,
        nonce: 2,
      );
      final afterTrimestral = await dbService.recordCodeEmission(
        clientId: cId,
        token: tokenTrimestral,
        plan: 'TRIMESTRAL',
        daysToAdd: 90,
        paymentAmount: 90.0,
        paymentMethod: 'Plin',
        paymentRef: 'Op. 2222',
        updatesUntil: null,
      );
      expect(afterTrimestral!['ai_extra_credits'], equals(280)); // 100 + 180 = 280

      // 4. Emitir RECARGA_IA_150 (+150)
      final tokenRecarga = await signer.generateLicenseToken(
        deviceFingerprint: 'ML-BBBB',
        plan: 'RECARGA_IA_150',
        daysToAdd: 0,
        nonce: 3,
      );
      final afterRecarga = await dbService.recordCodeEmission(
        clientId: cId,
        token: tokenRecarga,
        plan: 'RECARGA_IA_150',
        daysToAdd: 0,
        paymentAmount: 20.0,
        paymentMethod: 'Yape',
        paymentRef: 'Op. 3333',
        updatesUntil: null,
      );
      expect(afterRecarga!['ai_extra_credits'], equals(430)); // 280 + 150 = 430
    });
  });

  group('4. Migración de Celular en 1 Paso (emitImmediately: true)', () {
    test('Migra a nuevo ANDROID_ID, archiva histórico, emite token con c=0 y preserva días', () async {
      final client = await dbService.createClient({
        'business_name': 'Minimarket Los Andes',
        'owner_name': 'Ana Quispe',
        'phone': '+51966666666',
        'current_device_id': 'ML-OLD1',
        'license_type': 'TRIMESTRAL',
        'license_expires': DateTime.now().add(const Duration(days: 60)).toUtc().toIso8601String(),
      });
      final cId = client['id'] as String;

      // Migrar en 1 paso
      final result = await dbService.migrateDevice(
        clientId: cId,
        newDeviceId: 'ML-NEW2',
        feeAmount: 40.0,
        paymentMethod: 'Yape',
        reason: 'Renovó a Xiaomi Redmi Note 13',
        emitImmediately: true,
        signer: signer,
      );

      expect(result, isNotNull);
      expect(result!['current_device_id'], equals('ML-NEW2'));
      expect(result['emitted_migration_token'], isNotNull);

      // Inspeccionar el token emitido
      final token = result['emitted_migration_token'] as String;
      final inspection = await signer.inspectToken(token);
      expect(inspection['isValid'], isTrue);
      expect(inspection['device_id'], equals('ML-NEW2'));
      // Regla anti-doble conteo: el claim c debe ser 0 en migración
      expect(inspection['bonus_ai_scans'], equals(0));

      // Verificar historial de hardware
      final history = (result['device_history'] as List).cast<Map<String, dynamic>>();
      expect(history.length, equals(1));
      expect(history.first['old_device_id'], equals('ML-OLD1'));
      expect(history.first['new_device_id'], equals('ML-NEW2'));
      expect(history.first['fee_charged'], equals(40.0));

      // Verificar que los créditos IA del cliente se preservaron intactos
      expect(result['ai_extra_credits'], equals(client['ai_extra_credits']));
    });
  });

  group('5. FASE 5: CRUD de Pagos en Ficha 360°, Historial de Hardware y Datos Reportados', () {
    test('updatePayment modifica un registro de pago existente y getClientHistory expone alias hardware', () async {
      final client = await dbService.createClient({
        'business_name': 'Bodega San Martín',
        'owner_name': 'Carlos Rivera',
        'phone': '+51977777777',
        'current_device_id': 'ML-PAY1',
        'license_type': 'MENSUAL',
      });
      final cId = client['id'] as String;

      // Registrar un pago
      final added = await dbService.addPayment(cId, {
        'amount': 35.0,
        'plan': 'Renovación Mensual',
        'method': 'Yape',
        'reference': 'OP-123456',
        'notes': 'Cobro en ventanilla',
      });
      expect(added, isNotNull);
      final payments = (added!['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(payments.length, equals(1));
      final paymentId = payments.first['id'] as String;

      // Actualizar el pago (PUT)
      final updated = await dbService.updatePayment(cId, paymentId, {
        'amount': 40.0,
        'plan': 'Renovación Mensual Especial',
        'method': 'BCP',
        'reference': 'OP-999999',
        'notes': 'Corrección de importe por voucher BCP',
        'date': '2026-11-20',
      });

      expect(updated, isNotNull);
      final updatedPayments = (updated!['payment_history'] as List).cast<Map<String, dynamic>>();
      final p = updatedPayments.firstWhere((item) => item['id'] == paymentId);
      expect(p['amount'], equals(40.0));
      expect(p['plan'], equals('Renovación Mensual Especial'));
      expect(p['method'], equals('BCP'));
      expect(p['reference'], equals('OP-999999'));
      expect(p['date'], equals('2026-11-20'));

      // Verificar que getClientHistory expone tanto hardware como device_history
      final history = await dbService.getClientHistory(cId);
      expect(history, isNotNull);
      expect(history!.containsKey('device_history'), isTrue);
      expect(history.containsKey('hardware'), isTrue);
      expect(history['payments'].length, equals(1));

      // Eliminar pago (DELETE)
      final deleted = await dbService.deletePayment(cId, paymentId);
      expect(deleted, isNotNull);
      final remPayments = (deleted!['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(remPayments.isEmpty, isTrue);
    });

    test('syncClientReportedState sincroniza atómicamente modelo de celular y balance IA', () async {
      final client = await dbService.createClient({
        'business_name': 'Librería El Saber',
        'owner_name': 'Rosa Flores',
        'phone': '+51988888888',
        'current_device_id': 'ML-DEV1',
        'license_type': 'TRIAL',
      });
      final cId = client['id'] as String;

      final synced = await dbService.syncClientReportedState(
        clientId: cId,
        deviceId: 'ML-DEV1-NEW',
        deviceModel: 'Samsung Galaxy A54 5G',
        installedVersion: '9.31.0',
        aiReportedBalance: 42,
        trialDaysRemaining: 20,
      );

      expect(synced, isNotNull);
      expect(synced!['current_device_id'], equals('ML-DEV1-NEW'));
      expect(synced['device_model'], equals('Samsung Galaxy A54 5G'));
      expect(synced['installed_version'], equals('9.31.0'));
      expect(synced['ai_reported_balance'], equals(42));
      expect(synced['trial_days_remaining'], equals(20));
    });
  });
}
