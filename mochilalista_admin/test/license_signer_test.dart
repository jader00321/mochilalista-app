import 'package:test/test.dart';
import '../lib/license_signer.dart';

void main() {
  late LicenseSigner signer;
  // Semilla fija de 32 bytes para pruebas deterministas
  final testSeed = List<int>.generate(32, (i) => (i * 7 + 13) % 256);
  const testDeviceId = 'ML-9K4B';

  setUp(() async {
    signer = LicenseSigner();
    await signer.initWithSeed(testSeed);
  });

  group('1. Slugs Oficiales de los 7 Productos + Cortesía y Alias', () {
    test('Normaliza alias oficiales hacia los slugs canónicos', () {
      expect(LicenseSigner.normalizePlanSlug('PASE_UPDATES_12M'), equals('PASE_ACTUALIZACION_ANUAL'));
      expect(LicenseSigner.normalizePlanSlug('PASE_ANUAL_UPDATES'), equals('PASE_ACTUALIZACION_ANUAL'));
      expect(LicenseSigner.normalizePlanSlug('PERPETUO'), equals('PERPETUO_LIBERADO'));
      expect(LicenseSigner.normalizePlanSlug('PERPETUA'), equals('PERPETUO_LIBERADO'));
      expect(LicenseSigner.normalizePlanSlug('MENSUAL'), equals('MENSUAL'));
      expect(LicenseSigner.normalizePlanSlug('RECARGA_IA_150'), equals('RECARGA_IA_150'));
    });

    test('Helper getCumulativeScansForPlan retorna cuotas base acumulativas oficiales', () {
      expect(LicenseSigner.getCumulativeScansForPlan('TRIAL'), equals(50));
      expect(LicenseSigner.getCumulativeScansForPlan('MENSUAL'), equals(50));
      expect(LicenseSigner.getCumulativeScansForPlan('TRIMESTRAL'), equals(180));
      expect(LicenseSigner.getCumulativeScansForPlan('SEMESTRAL'), equals(450));
      expect(LicenseSigner.getCumulativeScansForPlan('ANUAL'), equals(1200));
      expect(LicenseSigner.getCumulativeScansForPlan('PERPETUO_LIBERADO'), equals(200));
      expect(LicenseSigner.getCumulativeScansForPlan('PASE_ACTUALIZACION_ANUAL'), equals(100));
      expect(LicenseSigner.getCumulativeScansForPlan('PASE_UPDATES_12M'), equals(100));
      expect(LicenseSigner.getCumulativeScansForPlan('RECARGA_IA_150'), equals(150));
      expect(LicenseSigner.getCumulativeScansForPlan('EXTENSION_CORTESIA'), equals(0));
    });
  });

  group('2. Regla Estricta Anti-Doble Conteo en Claim "c" del Token', () {
    test('Planes comerciales estándar firman con claim "c" == 0 (sin bono extra)', () async {
      final token = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
        aiExtraCredits: 0,
      );

      final inspection = await signer.inspectToken(token);
      expect(inspection['isValid'], isTrue);
      final payload = inspection['payload'] as Map<String, dynamic>;
      // El claim c no debe estar o debe ser 0 para evitar que app_movil duplique la base
      expect(payload.containsKey('c'), isFalse);
      expect(inspection['bonus_ai_scans'], equals(0));
      expect(inspection['plan_base_ai_scans'], equals(50));
      expect(inspection['total_ai_scans_received_by_app'], equals(50));
    });

    test('Planes comerciales con bono promocional transportan solo el bono en "c"', () async {
      final token = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'ANUAL',
        daysToAdd: 365,
        nonce: 2,
        aiExtraCredits: 100, // Bono de regalo
      );

      final inspection = await signer.inspectToken(token);
      expect(inspection['isValid'], isTrue);
      final payload = inspection['payload'] as Map<String, dynamic>;
      expect(payload['c'], equals(100));
      expect(inspection['bonus_ai_scans'], equals(100));
      expect(inspection['plan_base_ai_scans'], equals(1200));
      // La app móvil sumará 1200 (base) + 100 (bono c) = 1300
      expect(inspection['total_ai_scans_received_by_app'], equals(1300));
    });

    test('RECARGA_IA_150 siempre transporta 150 en claim "c" (recarga pura sin duplicar)', () async {
      final token = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'RECARGA_IA_150',
        daysToAdd: 0,
        nonce: 3,
        aiExtraCredits: 0,
      );

      final inspection = await signer.inspectToken(token);
      expect(inspection['isValid'], isTrue);
      final payload = inspection['payload'] as Map<String, dynamic>;
      expect(payload['c'], equals(150));
      expect(inspection['total_ai_scans_received_by_app'], equals(150));
    });
  });

  group('3. Metadata Enriquecida del Inspector Forense (ANDROID_ID y Claims)', () {
    test('Inspector clarifica procedencia Settings.Secure.ANDROID_ID y claims descriptivos', () async {
      final token = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'PERPETUO_LIBERADO',
        daysToAdd: 99999,
        nonce: 4,
        updatesUntil: DateTime(2027, 11, 19),
        businessTag: 'Libreria Estudiante',
      );

      final result = await signer.inspectToken(token);
      expect(result['isValid'], isTrue);
      expect(result['signatureVerified'], isTrue);
      expect(result['status'], equals('VÁLIDA'));
      expect(result['device_id'], equals('ML-9K4B'));
      expect(result['hardware_id_type'], contains('Settings.Secure.ANDROID_ID'));
      expect(result['isPerpetual'], isTrue);
      expect(result['updates_until'], isNotNull);
      expect(result['business_tag'], equals('Libreria Estudiante'));
      expect(result['plan_base_ai_scans'], equals(200));
    });

    test('Rechaza tokens manipulados o con firma no coincidente', () async {
      final validToken = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );

      // Adulterar payload Base64
      final tampered = '${validToken.substring(0, validToken.length - 8)}ABCDEF12';
      final result = await signer.inspectToken(tampered);
      expect(result['isValid'], isFalse);
      expect(result['signatureVerified'], isFalse);
    });

    test('Rechaza tokens sin prefijo oficial ML9-', () async {
      final result = await signer.inspectToken('TOKEN-SIN-PREFIJO.abcdef');
      expect(result['isValid'], isFalse);
      expect(result['status'], equals('ERROR_FORMATO'));
    });
  });
}
