import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = "ML-SYNC-TEST";

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
    await ApiConstants.clearUserCustomApiKey();
    ApiConstants.setAiSelectedMode('INCLUDED');

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': ''};
        }
        if (call.method == 'Clipboard.setData') {
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
    await ApiConstants.clearUserCustomApiKey();
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

  group('Fase 1: Sincronización Reactiva IA y Fuente Única de Verdad en LicenseProvider', () {
    test('1. Test Unitario de LicenseProvider: 50 -> consumeAiScan() -> 49 en remainingAiScans, aiAccumulatedScans y license!.aiAccumulatedScans inmediatamente', () async {
      final provider = LicenseProvider();
      await provider.checkLicense();

      // Estado inicial en Trial limpio
      expect(provider.remainingAiScans, equals(50));
      expect(provider.aiAccumulatedScans, equals(50));
      expect(provider.license?.aiAccumulatedScans, equals(50));

      // Consumir 1 escaneo IA
      final success = await provider.consumeAiScan();
      expect(success, isTrue);

      // Verificación estricta de sincronización 1:1 inmediata
      expect(provider.remainingAiScans, equals(49), reason: "remainingAiScans debe actualizarse a 49");
      expect(provider.aiAccumulatedScans, equals(49), reason: "aiAccumulatedScans debe actualizarse a 49");
      expect(provider.license?.aiAccumulatedScans, equals(49), reason: "license!.aiAccumulatedScans debe reflejar 49");

      // Verificación de refreshAiScans
      await provider.refreshAiScans();
      expect(provider.remainingAiScans, equals(49));
      expect(provider.aiAccumulatedScans, equals(49));
      expect(provider.license?.aiAccumulatedScans, equals(49));
    });

    test('2. Test de Modo BYOK: aiAccumulatedScans mantiene 49 congelado y visible, y escaneo BYOK no gasta la bolsa', () async {
      final provider = LicenseProvider();
      await provider.checkLicense();

      // Consumir 1 escaneo en modo INCLUDED (50 -> 49)
      await provider.consumeAiScan();
      expect(provider.aiAccumulatedScans, equals(49));

      // Cambiar a modo BYOK con clave propia configurada
      await provider.setCustomApiKey('AIzaSyMockKeyForTestingPurposes12345');
      await provider.setAiSelectedMode('BYOK');

      expect(provider.isUsingByokMode, isTrue);
      // aiAccumulatedScans debe conservar los 49 usos reales congelados (NUNCA 999999 ni 50)
      expect(provider.aiAccumulatedScans, equals(49), reason: "El saldo real de la bolsa debe ser 49");
      // remainingAiScans refleja capacidad operativa ilimitada en modo BYOK con clave
      expect(provider.remainingAiScans, equals(999999));

      // Ejecutar un escaneo en modo BYOK
      final canScan = await provider.canPerformAiScan();
      expect(canScan, isTrue);

      final consumed = await provider.consumeAiScan();
      expect(consumed, isTrue);

      // El saldo de la bolsa sigue intacto en 49
      expect(provider.aiAccumulatedScans, equals(49), reason: "En modo BYOK no se descuenta la bolsa acumulada");
      expect(provider.license?.aiAccumulatedScans, equals(49));
    });

    testWidgets('3. Widget Test Anti-Truncado y Anti-Overflow en 320x568dp y 360x640dp con 49 escaneos', (WidgetTester tester) async {
      final provider = LicenseProvider();
      await provider.checkLicense();
      await provider.consumeAiScan(); // 50 -> 49
      expect(provider.aiAccumulatedScans, equals(49));

      // --- Viewport 1: 320x568dp (Dispositivo ultra-compacto tipo iPhone SE 1st Gen) ---
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const AiSettingsScreen(), provider: provider));
      await tester.pumpAndSettle();

      // 1. Verificar valores exactos (49 y NUNCA 50)
      expect(find.text('49 usos disponibles'), findsOneWidget, reason: "Tarjeta superior debe mostrar 49 usos disponibles");
      expect(find.text('49 disponibles'), findsOneWidget, reason: "Tarjeta central debe mostrar 49 disponibles");
      expect(find.text('50 usos disponibles'), findsNothing);
      expect(find.text('50 disponibles'), findsNothing);

      // 2. Verificar que los títulos completos están presentes sin elipsis de truncamiento
      expect(find.text('Bolsa Acumulativa de IA'), findsOneWidget, reason: "Título Bolsa Acumulativa de IA debe estar completo");
      expect(find.text('Bóveda Segura Multi-Clave'), findsOneWidget, reason: "Título Bóveda Segura Multi-Clave debe estar completo");
      expect(find.text('Bolsa Activa'), findsOneWidget);
      expect(find.text('Agregar Clave'), findsOneWidget);

      // 3. Certificar 0px Overflow
      expect(tester.takeException(), isNull, reason: "No debe haber ningún RenderFlex overflow en 320x568dp");

      // --- Viewport 2: 360x640dp (Dispositivo estándar Android tipo Galaxy A54 escala 100%) ---
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(buildTestableWidget(const AiSettingsScreen(), provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('49 usos disponibles'), findsOneWidget);
      expect(find.text('49 disponibles'), findsOneWidget);
      expect(find.text('Bolsa Acumulativa de IA'), findsOneWidget);
      expect(find.text('Bóveda Segura Multi-Clave'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: "No debe haber ningún RenderFlex overflow en 360x640dp");

      // --- Verificación paralela en LicenseStatusAndActivationScreen ---
      await tester.pumpWidget(buildTestableWidget(const LicenseStatusAndActivationScreen(), provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('49 escaneos acumulados disponibles'), findsOneWidget,
          reason: "LicenseStatusAndActivationScreen debe mostrar exactamente 49 escaneos acumulados disponibles");
      expect(tester.takeException(), isNull);
    });
  });
}
