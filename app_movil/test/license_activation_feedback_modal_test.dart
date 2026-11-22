import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/features/auth/screens/license/widgets/license_activation_feedback_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ed25519 = Ed25519();
  late SimpleKeyPair keyPair;
  late SimplePublicKey pubKey;
  const String testDeviceId = 'ML-379E';
  const String otherDeviceId = 'ML-999Z';

  setUpAll(() async {
    keyPair = await ed25519.newKeyPair();
    pubKey = await keyPair.extractPublicKey();
  });

  setUp(() {
    Ed25519LicenseValidator.setTestPublicKey(pubKey.bytes);
  });

  tearDown(() {
    Ed25519LicenseValidator.setTestPublicKey(null);
  });

  LicenseModel createTestLicense({int nonce = 0, String deviceId = testDeviceId}) {
    return LicenseModel(
      deviceFingerprint: deviceId,
      tipoPlan: 'TRIAL',
      estadoActual: 'ACTIVA',
      fechaInicio: DateTime.now().subtract(const Duration(days: 2)),
      fechaExpiracion: DateTime.now().add(const Duration(days: 28)),
      fechaUltimoCheck: DateTime.now(),
      ultimoNonce: nonce,
      aiAccumulatedScans: 50,
    );
  }

  Future<String> createSignedToken({
    required String deviceId,
    required String plan,
    required int daysToAdd,
    required int nonce,
    DateTime? issuedAt,
    DateTime? expiresAt,
    int aiCredits = 0,
  }) async {
    final payloadMap = <String, dynamic>{
      'd': deviceId,
      'p': plan,
      'y': daysToAdd,
      'n': nonce,
      'v': 9,
      'iat': (issuedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
    if (aiCredits > 0) {
      payloadMap['c'] = aiCredits;
    }
    if (expiresAt != null) {
      payloadMap['e'] = expiresAt.toUtc().toIso8601String();
    }

    final payloadBytes = utf8.encode(jsonEncode(payloadMap));
    final signature = await ed25519.sign(payloadBytes, keyPair: keyPair);
    final b64Payload = Ed25519LicenseValidator.encodeBase64UrlSafe(payloadBytes);
    final b64Sig = Ed25519LicenseValidator.encodeBase64UrlSafe(signature.bytes);
    return 'ML9-$b64Payload.$b64Sig';
  }

  group('1. Clasificación Tipada en Ed25519LicenseValidator', () {
    test('Rechaza formato inválido con LicenseRedeemStatus.invalidFormat', () async {
      try {
        await Ed25519LicenseValidator.validateAndParse(
          rawCode: 'ML9-codigo-invalido-sin-firma',
          currentDeviceFingerprint: testDeviceId,
          currentLicense: createTestLicense(),
        );
        fail('Debió lanzar LicenseValidationException');
      } on LicenseValidationException catch (e) {
        expect(e.status, equals(LicenseRedeemStatus.invalidFormat));
        expect(e, isA<Exception>());
      }
    });

    test('Rechaza firma alterada con LicenseRedeemStatus.invalidSignatureOrTampered', () async {
      final validToken = await createSignedToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );
      final parts = validToken.substring(4).split('.');
      final originalSig = parts[1];
      final tamperedSig = (originalSig[0] == 'A' ? 'B' : 'A') + originalSig.substring(1);
      final tampered = 'ML9-${parts[0]}.$tamperedSig';

      try {
        await Ed25519LicenseValidator.validateAndParse(
          rawCode: tampered,
          currentDeviceFingerprint: testDeviceId,
          currentLicense: createTestLicense(),
        );
        fail('Debió lanzar LicenseValidationException');
      } on LicenseValidationException catch (e) {
        expect(e.status, equals(LicenseRedeemStatus.invalidSignatureOrTampered));
      }
    });

    test('Detecta discrepancia de dispositivo con LicenseRedeemStatus.hardwareMismatch', () async {
      final token = await createSignedToken(
        deviceId: otherDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );

      try {
        await Ed25519LicenseValidator.validateAndParse(
          rawCode: token,
          currentDeviceFingerprint: testDeviceId,
          currentLicense: createTestLicense(),
        );
        fail('Debió lanzar LicenseValidationException');
      } on LicenseValidationException catch (e) {
        expect(e.status, equals(LicenseRedeemStatus.hardwareMismatch));
        expect(e.tokenDeviceId, equals(otherDeviceId));
        expect(e.currentDeviceId, equals(testDeviceId));
      }
    });

    test('Clasifica reintento del mismo código con LicenseRedeemStatus.alreadyRedeemedSameNonce', () async {
      final token = await createSignedToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );

      try {
        await Ed25519LicenseValidator.validateAndParse(
          rawCode: token,
          currentDeviceFingerprint: testDeviceId,
          currentLicense: createTestLicense(nonce: 1), // Ya canjeado previamente con nonce = 1
        );
        fail('Debió lanzar LicenseValidationException');
      } on LicenseValidationException catch (e) {
        expect(e.status, equals(LicenseRedeemStatus.alreadyRedeemedSameNonce));
        expect(e.tokenNonce, equals(1));
        expect(e.currentNonce, equals(1));
        // Preserva compatibilidad con tests que buscan la palabra Nonce en el mensaje técnico
        expect(e.message, contains('Nonce'));
      }
    });

    test('Clasifica código histórico superado con LicenseRedeemStatus.supersededOlderNonce', () async {
      final token = await createSignedToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );

      try {
        await Ed25519LicenseValidator.validateAndParse(
          rawCode: token,
          currentDeviceFingerprint: testDeviceId,
          currentLicense: createTestLicense(nonce: 2), // Ya superado por nonce = 2
        );
        fail('Debió lanzar LicenseValidationException');
      } on LicenseValidationException catch (e) {
        expect(e.status, equals(LicenseRedeemStatus.supersededOlderNonce));
        expect(e.tokenNonce, equals(1));
        expect(e.currentNonce, equals(2));
      }
    });

    test('Detecta código expirado con LicenseRedeemStatus.expiredToken', () async {
      // Token mensual (30 días) emitido hace 35 días
      final issuedAt = DateTime.now().toUtc().subtract(const Duration(days: 35));
      final token = await createSignedToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 5,
        issuedAt: issuedAt,
      );

      try {
        await Ed25519LicenseValidator.validateAndParse(
          rawCode: token,
          currentDeviceFingerprint: testDeviceId,
          currentLicense: createTestLicense(),
        );
        fail('Debió lanzar LicenseValidationException');
      } on LicenseValidationException catch (e) {
        expect(e.status, equals(LicenseRedeemStatus.expiredToken));
      }
    });

    test('Valida con éxito y produce LicenseValidationResult estructurado', () async {
      final token = await createSignedToken(
        deviceId: testDeviceId,
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        aiCredits: 20,
        nonce: 2,
      );

      final result = await Ed25519LicenseValidator.validateAndParse(
        rawCode: token,
        currentDeviceFingerprint: testDeviceId,
        currentLicense: createTestLicense(nonce: 1),
      );

      expect(result.isValid, isTrue);
      expect(result.plan, equals('BONO_IA_PERSONALIZADO'));
      expect(result.daysToAdd, equals(0));
      expect(result.aiExtraCredits, equals(20));
      expect(result.nonce, equals(2));
    });
  });

  group('2. Widget LicenseActivationFeedbackModal - Escenarios de Usuario y Cero Jerga', () {
    testWidgets('Escenario alreadyRedeemedSameNonce: muestra "Ref. soporte: #1" y CERO menciones de Nonce', (tester) async {
      bool onDoneCalled = false;

      final snapshot = LicenseModel(
        deviceFingerprint: testDeviceId,
        tipoPlan: 'TRIAL',
        estadoActual: 'ACTIVA',
        fechaInicio: DateTime.now().subtract(const Duration(days: 2)),
        fechaExpiracion: DateTime.now().add(const Duration(days: 28)),
        fechaUltimoCheck: DateTime.now(),
        ultimoNonce: 1,
        aiAccumulatedScans: 69,
      );

      final result = LicenseRedeemResult(
        status: LicenseRedeemStatus.alreadyRedeemedSameNonce,
        isSuccess: false,
        message: 'Código ya aplicado previamente',
        tokenNonce: 1,
        currentNonce: 1,
        currentLicenseSnapshot: snapshot,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => LicenseActivationFeedbackModal.show(
                  ctx,
                  result: result,
                  onDone: () => onDoneCalled = true,
                ),
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // Verifica título amigable
      expect(find.text('Este código ya está aplicado'), findsOneWidget);
      // Verifica tag de soporte con formato #1
      expect(find.text('Ref. soporte: #1'), findsOneWidget);
      // Verifica metadatos del snapshot
      expect(find.text('69'), findsOneWidget);
      expect(find.text('${snapshot.daysRemaining} días restantes'), findsOneWidget);

      // REGLA FUNDAMENTAL: NUNCA mostrar la palabra técnica Nonce ni "correlativo vencido"
      expect(find.textContaining('Nonce'), findsNothing);
      expect(find.textContaining('correlativo'), findsNothing);

      // Tap en Entendido cierra el modal y ejecuta onDone
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(onDoneCalled, isTrue);
    });

    testWidgets('Escenario supersededOlderNonce: muestra vigente y superado con cero Nonce', (tester) async {
      final result = const LicenseRedeemResult(
        status: LicenseRedeemStatus.supersededOlderNonce,
        isSuccess: false,
        message: 'Código anterior superado',
        tokenNonce: 1,
        currentNonce: 3,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => LicenseActivationFeedbackModal.show(ctx, result: result),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Código anterior ya superado'), findsOneWidget);
      expect(find.text('Ref. soporte: #1 • Vigente: #3'), findsOneWidget);
      expect(find.textContaining('Nonce'), findsNothing);
    });

    testWidgets('Escenario hardwareMismatch: compara Hardware IDs y ofrece botón de Soporte', (tester) async {
      bool supportCalled = false;

      final result = const LicenseRedeemResult(
        status: LicenseRedeemStatus.hardwareMismatch,
        isSuccess: false,
        message: 'Hardware mismatch',
        tokenDeviceId: 'ML-999Z',
        currentDeviceId: 'ML-379E',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => LicenseActivationFeedbackModal.show(
                  ctx,
                  result: result,
                  onContactSupport: () => supportCalled = true,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Código emitido para otro celular'), findsOneWidget);
      expect(find.text('ML-999Z'), findsOneWidget);
      expect(find.text('ML-379E'), findsOneWidget);
      expect(find.text('Contactar a Soporte Oficial'), findsOneWidget);

      await tester.tap(find.text('Contactar a Soporte Oficial'));
      await tester.pumpAndSettle();
      expect(supportCalled, isTrue);
    });

    testWidgets('Escenario success (Bono IA): muestra sello de bono y mantención de vigencia', (tester) async {
      final result = LicenseRedeemResult.success(
        message: 'Bono aplicado',
        plan: 'BONO_IA_PERSONALIZADO',
        daysAdded: 0,
        aiCreditsAdded: 20,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => LicenseActivationFeedbackModal.show(ctx, result: result),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('¡Bono IA Acreditado!'), findsOneWidget);
      expect(find.text('+20 escaneos'), findsOneWidget);
      expect(find.text('Tu fecha de vencimiento actual se mantiene intacta.'), findsOneWidget);
      expect(find.text('Comenzar a Usar'), findsOneWidget);
    });
  });

  group('3. Responsividad y Cero Desbordamiento (0px Overflow)', () {
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      testWidgets('0px Overflow en ${size.width}x${size.height} con escala de texto 1.3', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final result = const LicenseRedeemResult(
          status: LicenseRedeemStatus.hardwareMismatch,
          isSuccess: false,
          message: 'Hardware mismatch',
          tokenDeviceId: 'ML-999Z-LONG-DEVICE-IDENTIFIER',
          currentDeviceId: 'ML-379E-LONG-DEVICE-IDENTIFIER',
        );

        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.3),
              viewPadding: EdgeInsets.only(bottom: 48), // Barra Android de 3 botones
            ),
            child: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => LicenseActivationFeedbackModal.show(ctx, result: result),
                    child: const Text('Test'),
                  ),
                ),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Código emitido para otro celular'), findsOneWidget);
      });
    }
  });
}
