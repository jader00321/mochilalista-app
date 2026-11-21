import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseService dbService;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('fase1_ai_test_');
    dbService = DatabaseService(
      dataDir: '${tempDir.path}/data',
      backupDir: '${tempDir.path}/backups',
      releasesDir: '${tempDir.path}/releases',
    );
    await dbService.init();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Certificación FASE 1: Bug Matemático de Créditos IA y Modelo de Dispositivo', () {
    test('Cliente Trial con 49 IA en celular y bono 20 guarda 49 acumulados, 0 extra y modelo de celular', () async {
      final client = await dbService.createClient({
        'business_name': 'Luzam Test',
        'owner_name': 'Angello Test',
        'document_id': '10458796321',
        'phone': '+51922836879',
        'current_device_id': 'ML-TEST',
        'device_model': 'Samsung Galaxy A54 5G',
        'license_type': 'TRIAL',
        'trial_days_remaining': 28,
        'ai_reported_balance': 49,
        'ai_pending_bonus': 20,
      });

      expect(client['ai_reported_balance'], equals(49));
      expect(client['ai_pending_bonus'], equals(20));
      expect(client['ai_accumulated_credits'], equals(49));
      expect(client['ai_extra_credits'], equals(0));
      expect(client['device_model'], equals('Samsung Galaxy A54 5G'));
      expect(client['license_type'], equals('TRIAL'));
      expect(client['trial_days_remaining'], equals(28));
    });

    test('Cliente Trial por defecto sin reporte previo (legacy) mantiene 50 IA base acumulados', () async {
      final client = await dbService.createClient({
        'business_name': 'Cliente Trial Default',
        'owner_name': 'Titular Default',
        'phone': '+51999888777',
        'current_device_id': 'ML-DFLT',
        'license_type': 'TRIAL',
      });

      expect(client['ai_accumulated_credits'], equals(50));
      expect(client['ai_extra_credits'], equals(50));
      expect(client['ai_reported_balance'], equals(50));
      expect(client['ai_pending_bonus'], equals(0));
    });

    test('Cliente Trial creado desde UI con ai_reported_balance=50 y bono=0 asigna 0 extra y 50 acumulados', () async {
      final client = await dbService.createClient({
        'business_name': 'Cliente Trial UI',
        'owner_name': 'Titular UI',
        'phone': '+51999888778',
        'current_device_id': 'ML-DFL2',
        'license_type': 'TRIAL',
        'ai_reported_balance': 50,
        'ai_pending_bonus': 0,
        'ai_extra_credits': 0,
      });

      expect(client['ai_accumulated_credits'], equals(50));
      expect(client['ai_extra_credits'], equals(0));
      expect(client['ai_reported_balance'], equals(50));
      expect(client['ai_pending_bonus'], equals(0));
    });
  });
}
