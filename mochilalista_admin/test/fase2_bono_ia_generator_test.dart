import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import '../lib/license_signer.dart';

void main() {
  late Directory tempDir;
  late DatabaseService dbService;
  late LicenseSigner signer;
  final testSeed = List<int>.generate(32, (i) => (i * 7 + 13) % 256);

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('fase2_bono_ia_test_');
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

  group('Certificación FASE 2: Estudio Generador y Bono IA Personalizado', () {
    test('LicenseSigner firma y decodifica BONO_IA_PERSONALIZADO con y=0 y escaneos personalizados', () async {
      final token = await signer.generateLicenseToken(
        plan: 'BONO_IA_PERSONALIZADO',
        deviceFingerprint: 'ML-379E',
        nonce: 1,
        daysToAdd: 0,
        aiExtraCredits: 20,
      );

      expect(token, startsWith('ML9-'));

      final inspection = await signer.inspectToken(token);
      expect(inspection['isValid'], isTrue);
      expect(inspection['payload']['p'], equals('BONO_IA_PERSONALIZADO'));
      expect(inspection['payload']['y'], equals(0));
      expect(inspection['payload']['c'], equals(20));
      expect(inspection['payload']['n'], equals(1));
      expect(inspection['payload']['d'], equals('ML-379E'));
      expect(inspection['days_added'], equals(0));
      expect(inspection['nonce'], equals(1));
      expect(inspection['device_id'], equals('ML-379E'));
      expect(inspection['total_ai_scans_received_by_app'], equals(20));
    });

    test('recordCodeEmission en Bono Gratuito: actualiza saldo IA, liquida bono pendiente, no altera vigencia ni registra pago espurio', () async {
      final client = await dbService.createClient({
        'business_name': 'Luzam Angello',
        'owner_name': 'Angello',
        'phone': '+51922836879',
        'current_device_id': 'ML-379E',
        'license_type': 'TRIAL',
        'trial_days_remaining': 28,
        'license_expires': '2026-12-19T23:59:59.000Z',
        'ai_reported_balance': 49,
        'ai_pending_bonus': 20,
      });

      final clientId = client['id'] as String;
      final originalExpires = client['license_expires'];
      final originalType = client['license_type'];

      final token = await signer.generateLicenseToken(
        plan: 'BONO_IA_PERSONALIZADO',
        deviceFingerprint: 'ML-379E',
        nonce: 1,
        daysToAdd: 0,
        aiExtraCredits: 20,
      );

      final updated = await dbService.recordCodeEmission(
        clientId: clientId,
        plan: 'BONO_IA_PERSONALIZADO',
        token: token,
        daysToAdd: 0,
        paymentAmount: 0.0,
        paymentMethod: 'Cortesia / Promocion',
        paymentRef: 'Bono Gratuito',
        updatesUntil: null,
        aiExtraCredits: 20,
      );

      expect(updated, isNotNull);
      // Saldo IA en celular sube exactamente de 49 a 69
      expect(updated!['ai_reported_balance'], equals(69));
      expect(updated['ai_accumulated_credits'], equals(69));
      // Bono pendiente se liquida a 0
      expect(updated['ai_pending_bonus'], equals(0));
      // Vigencia y tipo de licencia NO se alteran
      expect(updated['license_expires'], equals(originalExpires));
      expect(updated['license_type'], equals(originalType));
      // Nonce incrementado
      expect(updated['next_nonce'], equals(2));

      // Historial de pagos no contiene pago espurio con monto 0.00
      final payments = (updated['payment_history'] as List?) ?? [];
      expect(payments, isEmpty);

      // Historial de códigos emitidos persiste nonce, created_at, expires_at y ai_credits
      final codes = (updated['generated_codes_history'] as List?) ?? [];
      expect(codes.length, equals(1));
      final lastCode = codes.first as Map<String, dynamic>;
      expect(lastCode['plan'], equals('BONO_IA_PERSONALIZADO'));
      expect(lastCode['nonce'], equals(1));
      expect(lastCode['token'], equals(token));
      expect(lastCode['ai_credits'], equals(20));
      expect(lastCode['created_at'], isNotNull);
      expect(lastCode['expires_at'], equals(originalExpires));
    });

    test('recordCodeEmission en Bono con Cobro Personalizado: registra pago contable legítimo', () async {
      final client = await dbService.createClient({
        'business_name': 'Bazar Angello',
        'owner_name': 'Angello Vasquez',
        'phone': '+51922836879',
        'current_device_id': 'ML-D8F8',
        'license_type': 'MENSUAL',
        'license_expires': '2027-01-19T23:59:59.000Z',
        'ai_reported_balance': 120,
        'ai_pending_bonus': 0,
      });

      final clientId = client['id'] as String;

      final token = await signer.generateLicenseToken(
        plan: 'BONO_IA_PERSONALIZADO',
        deviceFingerprint: 'ML-D8F8',
        nonce: 1,
        daysToAdd: 0,
        aiExtraCredits: 50,
      );

      final updated = await dbService.recordCodeEmission(
        clientId: clientId,
        plan: 'BONO_IA_PERSONALIZADO',
        token: token,
        daysToAdd: 0,
        paymentAmount: 7.0,
        paymentMethod: 'Yape',
        paymentRef: 'Op. 94821',
        updatesUntil: null,
        aiExtraCredits: 50,
      );

      expect(updated, isNotNull);
      expect(updated!['ai_reported_balance'], equals(170));
      expect(updated['next_nonce'], equals(2));

      final payments = (updated['payment_history'] as List?) ?? [];
      expect(payments.length, equals(1));
      expect(payments.first['amount'], equals(7.0));
      expect(payments.first['method'], equals('Yape'));
      expect(payments.first['reference'], equals('Op. 94821'));
      expect(payments.first['plan'], equals('BONO_IA_PERSONALIZADO'));

      final codes = (updated['generated_codes_history'] as List?) ?? [];
      expect(codes.length, equals(1));
      expect(codes.first['nonce'], equals(1));
      expect(codes.first['ai_credits'], equals(50));
    });
  });
}
