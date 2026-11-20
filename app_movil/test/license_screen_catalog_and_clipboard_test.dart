import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:intl/date_symbol_data_local.dart';

// Modelos y Core
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';

// Pantallas bajo prueba
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = "ML-270D";
  String clipboardContent = '';

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final ed25519 = Ed25519();
    testKeyPair = await ed25519.newKeyPair();
    testPublicKey = await testKeyPair.extractPublicKey();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(mockDeviceId);
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);
    clipboardContent = '';

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardContent};
        }
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          clipboardContent = (args?['text'] as String?) ?? '';
          return null;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  Widget buildTestableWidget(Widget child, {LicenseProvider? provider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LicenseProvider?>.value(
          value: provider,
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('1. Tarjeta Superior Ejecutiva: Badges Dinámicos, Hardware ID y Chip IA', () {
    testWidgets('Muestra badge dinámico exacto de Trial, leyenda anti-IMEI y chip IA navegable', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Título sin corte y Badge Dinámico Exacto para Trial
      expect(find.text("Estado de la Licencia"), findsOneWidget);
      expect(find.text("Prueba Gratuita (Trial)"), findsOneWidget);

      // 2. Leyenda aclaratoria sobre el Hardware ID (no es IMEI)
      expect(find.textContaining("ML-270D"), findsWidgets);
      expect(
        find.text("Código de seguridad único generado para esta instalación (no es tu IMEI)"),
        findsOneWidget,
      );

      // 3. Chip Interactivo de Escaneos IA
      expect(find.text("Escaneos IA Disponibles"), findsOneWidget);
      expect(find.text("50 escaneos acumulados disponibles"), findsOneWidget);

      // Tocar chip IA debe navegar a AiSettingsScreen
      await tester.tap(find.text("Escaneos IA Disponibles"));
      await tester.pumpAndSettle();

      expect(find.byType(AiSettingsScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Muestra badge dinámico exacto para Plan Mensual Activo y Licencia Perpetua Liberada', (tester) async {
      // 1. Simular Plan Mensual
      await testDb.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'MENSUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
      });

      final provMensual = LicenseProvider();
      await tester.runAsync(() async {
        await provMensual.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provMensual,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Plan Mensual Activo"), findsOneWidget);

      // 2. Simular Licencia Perpetua Liberada
      await testDb.delete('licencia_app');
      await testDb.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'PERPETUA',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 3650)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
      });

      final provPerpetua = LicenseProvider();
      await tester.runAsync(() async {
        await provPerpetua.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provPerpetua,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Licencia Perpetua Liberada"), findsOneWidget);
      expect(find.text("Acceso de por vida habilitado"), findsOneWidget);
    });
  });

  group('2. Barra de Progreso Dinámica y Renovación Acumulativa (59 Días)', () {
    testWidgets('Plan Mensual con 59 días acumulados muestra progreso <= 1.0 y subtítulo aclaratorio', (tester) async {
      // Simular Plan Mensual (base 30 días) con 59 días acumulados vigentes (Trial restante + Mensual)
      final now = DateTime.now();
      final expiration = now.add(const Duration(days: 59));

      await testDb.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'MENSUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': now.toIso8601String(),
        'fecha_expiracion': expiration.toIso8601String(),
        'fecha_ultimo_check': now.toIso8601String(),
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      expect(provider.license!.plan.baseDurationDays, equals(30));
      expect(provider.license!.daysRemaining, inInclusiveRange(58, 60));
      expect(provider.license!.totalPeriodDays, inInclusiveRange(58, 60));
      expect(provider.license!.progressRatio, inInclusiveRange(0.0, 1.0));
      expect(provider.license!.hasAccumulatedBonusDays, isTrue);

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // Debe mostrar el subtítulo aclaratorio de acumulación
      expect(
        find.text("Incluye días acumulados de tu periodo anterior."),
        findsOneWidget,
      );
    });
  });

  group('3. Catálogo Oficial de 7 Productos y Cobertura Multinegocio', () {
    testWidgets('Despliega los 7 productos del tarifario oficial y aviso de cobertura multinegocio', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // 1. Aviso de Cobertura Multinegocio
      expect(
        find.textContaining("Una sola licencia activa ampara todos los perfiles de tu negocio en este celular"),
        findsOneWidget,
      );

      // 2. Presencia de los 7 productos
      expect(find.text("Mensual"), findsOneWidget);
      expect(find.text("S/ 35.00"), findsOneWidget);

      expect(find.text("Trimestral"), findsOneWidget);
      expect(find.text("S/ 90.00"), findsOneWidget);

      expect(find.text("Semestral"), findsOneWidget);
      expect(find.text("S/ 160.00"), findsOneWidget);

      expect(find.text("Anual"), findsOneWidget);
      expect(find.text("S/ 280.00"), findsOneWidget);

      expect(find.text("Perpetua"), findsOneWidget);
      expect(find.text("S/ 850.00"), findsOneWidget);

      expect(find.text("Bolsa Extra IA"), findsOneWidget);
      expect(find.text("S/ 20.00"), findsOneWidget);

      expect(find.text("Pase Anual de Updates"), findsOneWidget);
      expect(find.text("S/ 150.00"), findsOneWidget);
    });
  });

  group('4. Medios de Pago Parametrizados, Copiado al Portapapeles y Deep Link WhatsApp', () {
    testWidgets('Tarjeta Yape/Plin copia número al portapapeles y activa Toast flotante', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // Desplazarse hacia la sección de medios de pago
      await tester.scrollUntilVisible(
        find.text("Yape y Plin (Perú)"),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text("Yape y Plin (Perú)"), findsOneWidget);
      expect(find.textContaining(OwnerLegalIdentity.supportPhone), findsWidgets);
      expect(find.textContaining(OwnerLegalIdentity.yapePlinHolder), findsWidgets);

      // Presionar botón Copiar en Yape
      final copyYapeBtn = find.widgetWithText(ElevatedButton, "Copiar");
      expect(copyYapeBtn, findsOneWidget);
      await tester.tap(copyYapeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardContent, equals(OwnerLegalIdentity.supportPhone));

      // Limpiar toast animado antes de terminar
      await tester.pump(const Duration(seconds: 10));
    });

    test('Helper buildPlanWhatsAppUri construye el enlace y mensaje prellenado exacto', () {
      final uriString = OwnerLegalIdentity.buildPlanWhatsAppUri(
        planName: "Plan Trimestral",
        price: "S/ 90.00",
        hardwareId: "ML-270D",
      );

      final uri = Uri.parse(uriString);
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('wa.me'));
      expect(uri.path, equals('/51922836879'));

      final decodedMessage = uri.queryParameters['text'];
      expect(decodedMessage, isNotNull);
      expect(decodedMessage, contains("Hola Julio Angello, deseo solicitar el Plan Trimestral (S/ 90.00) para MochilaLista."));
      expect(decodedMessage, contains("Mi código de dispositivo (Hardware ID) es: ML-270D"));
      expect(decodedMessage, contains("Adjunto mi comprobante de pago por Yape / Transferencia bancaria."));
    });
  });

  group('5. Cero Desbordes (0px Overflow) en Resoluciones Compactas 320x568dp y 360x640dp', () {
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      testWidgets('LicenseStatusAndActivationScreen renderiza con 0px overflow en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        final errors = <String>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details.toString());
        };

        await tester.pumpWidget(buildTestableWidget(
          const LicenseStatusAndActivationScreen(),
          provider: provider,
        ));
        await tester.pumpAndSettle();

        FlutterError.onError = prevOnError;

        expect(find.byType(LicenseStatusAndActivationScreen), findsOneWidget);
        expect(find.text("Estado de la Licencia"), findsOneWidget);
        expect(find.text("QR desde Galería"), findsOneWidget);
        expect(errors, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
