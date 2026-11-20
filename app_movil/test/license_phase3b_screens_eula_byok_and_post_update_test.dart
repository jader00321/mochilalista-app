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
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/services/ai/ai_vault_service.dart';

// Pantallas y Modales Fase 3B
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/auth/screens/license/license_locked_screen.dart';
import 'package:app_movil/features/auth/screens/license/clock_desynced_screen.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';
import 'package:app_movil/features/auth/widgets/soft_lock_renewal_modal.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = "ML-9K4B";

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

    // SQLite FFI sin Isolate (NoIsolate) para evitar deadlocks de ReceivePort en testWidgets
    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);

    // Mockeo determinista de Clipboard en SystemChannels.platform
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

  group('1. LicenseProvider — Gestión de Estado, Hardware ID y Cuotas IA', () {
    test('checkLicense inicializa correctamente y expone datos de Trial', () async {
      final provider = LicenseProvider();
      await provider.checkLicense();

      expect(provider.deviceFingerprint, equals(mockDeviceId));
      expect(provider.isTrial, isTrue);
      expect(provider.isActive, isTrue);
      expect(provider.isExpiringSoon, isFalse);
      expect(provider.isSoftLock, isFalse);
      expect(provider.isStrictLock, isFalse);
      expect(provider.canCreateSales, isTrue);
      expect(provider.remainingAiScans, equals(50));
      expect(provider.currentPlanName, equals('TRIAL'));
    });

    test('canCreateSales es falso en BLOQUEO_SUAVE y BLOQUEO_ESTRICTO', () async {
      final repo = LicenseRepository();
      await repo.getOrCreateLicense();

      // Forzar BLOQUEO_SUAVE (vencida hace 2 días)
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      await testDb.update(
        'licencia_app',
        {
          'fecha_expiracion': pastDate.toIso8601String(),
          'estado_actual': 'BLOQUEO_SUAVE',
        },
        where: 'id = ?',
        whereArgs: [1],
      );

      final provider = LicenseProvider();
      await provider.checkLicense();

      expect(provider.isSoftLock, isTrue);
      expect(provider.canCreateSales, isFalse);

      // Forzar BLOQUEO_ESTRICTO (vencida hace 10 días)
      final strictPast = DateTime.now().subtract(const Duration(days: 10));
      await testDb.update(
        'licencia_app',
        {
          'fecha_expiracion': strictPast.toIso8601String(),
          'estado_actual': 'BLOQUEO_ESTRICTO',
        },
        where: 'id = ?',
        whereArgs: [1],
      );

      await provider.checkLicense();
      expect(provider.isStrictLock, isTrue);
      expect(provider.canCreateSales, isFalse);
    });

    test('consumeAiScan descuenta de la cuota mensual hasta agotarla', () async {
      final provider = LicenseProvider();
      await provider.checkLicense();

      expect(provider.remainingAiScans, equals(50));
      final canScan = await provider.canPerformAiScan();
      expect(canScan, isTrue);

      final success = await provider.consumeAiScan();
      expect(success, isTrue);
      expect(provider.remainingAiScans, equals(49));
    });
  });

  group('2. Validación y Activación Reactiva de Códigos Ed25519', () {
    test('redeemCode activa licencia MENSUAL y actualiza reactivamente la UI', () async {
      final provider = LicenseProvider();
      await provider.checkLicense();

      final payload = {
        "d": mockDeviceId,
        "p": "MENSUAL",
        "y": 30,
        "n": 100,
        "e": "2026-11-14",
        "v": 9,
        "b": "Librería Central",
        "c": OwnerLegalIdentity.watermarkNotice
      };
      final token = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: payload,
      );

      final ok = await provider.redeemCode(token);
      expect(ok, isTrue);
      expect(provider.license?.tipoPlan, equals('MENSUAL'));
      expect(provider.license?.estadoActual, equals('ACTIVA'));
      expect(provider.license?.ultimoNonce, equals(100));
      expect(provider.successMessage, contains('¡Licencia activada con éxito!'));
    });

    test('redeemCode rechaza token con firma alterada', () async {
      final provider = LicenseProvider();
      await provider.checkLicense();

      final payload = {
        "d": mockDeviceId,
        "p": "ANUAL",
        "y": 365,
        "n": 200,
        "e": "2026-11-14",
        "v": 9,
      };
      final token = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: payload,
      );

      final tampered = token.replaceRange(10, 11, 'Z');
      final ok = await provider.redeemCode(tampered);
      expect(ok, isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('3. Detección Inteligente en Portapapeles en LicenseStatusAndActivationScreen', () {
    testWidgets('Muestra banner de código detectado si el portapapeles contiene token válido', (tester) async {
      final payload = {
        "d": mockDeviceId,
        "p": "TRIMESTRAL",
        "y": 90,
        "n": 300,
        "e": "2026-11-14",
        "v": 9,
      };

      late String token;
      await tester.runAsync(() async {
        token = await Ed25519LicenseValidator.generateSignedTokenForTesting(
          keyPair: testKeyPair,
          payload: payload,
          addMl9Prefix: true,
        );
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': token};
          }
          if (call.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        },
      );

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

      expect(find.text("Código detectado en portapapeles"), findsOneWidget);
      expect(find.text("Pegar y Activar"), findsOneWidget);

      await tester.runAsync(() async {
        await provider.redeemCode(token);
      });
      await tester.tap(find.text("Pegar y Activar"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 10));

      expect(provider.license?.tipoPlan, equals('TRIMESTRAL'));
    });

    testWidgets('Muestra botón interactivo [Escanear QR desde Galería / Imagen] con icono de galería', (tester) async {
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

      expect(find.text("QR desde Galería"), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('4. Contrato Digital EULA con Scroll Obligatorio', () {
    testWidgets('Botón de aceptación está deshabilitado hasta scroll y checkbox', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const EulaAcceptanceModal(),
        provider: provider,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Términos de Licencia (EULA)"), findsOneWidget);
      expect(find.textContaining(OwnerLegalIdentity.authorFullName, skipOffstage: false), findsWidgets);

      // Botón "Aceptar Términos de Licencia" inicialmente inhabilitado (onPressed: null)
      final acceptBtnFinder = find.widgetWithText(ElevatedButton, "Aceptar Términos de Licencia");
      expect(acceptBtnFinder, findsOneWidget);
      final ElevatedButton btnWidget = tester.widget(acceptBtnFinder);
      expect(btnWidget.onPressed, isNull);

      // Desplazarse hacia el fondo del scroll
      final scrollFinder = find.byType(SingleChildScrollView);
      await tester.drag(scrollFinder, const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Checkbox ahora puede ser marcado
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      await tester.tap(checkboxFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Botón ahora habilitado
      final ElevatedButton btnEnabled = tester.widget(acceptBtnFinder);
      expect(btnEnabled.onPressed, isNotNull);

      // Presionar aceptar ejecutando la persistencia en DB dentro de runAsync
      await tester.runAsync(() async {
        await provider.recordEulaAcceptance("1.0");
      });
      await tester.tap(acceptBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar persistencia en base de datos
      final rows = await testDb.query('licencia_app');
      expect(rows.first['eula_accepted_version'], equals('1.0'));
      expect(rows.first['eula_accepted_timestamp'], isNotNull);
    });

    testWidgets('Modal EULA en modo Solo Lectura muestra botón Cerrar', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const EulaAcceptanceModal(isReadOnly: true),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Cerrar"), findsOneWidget);
      await tester.tap(find.text("Cerrar"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('5. Pantalla BYOK y Monitoreo de Cuota IA (AiSettingsScreen)', () {
    testWidgets('Configuración y persistencia de clave propia BYOK otorga cuota ilimitada', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const AiSettingsScreen(key: ValueKey('empty_vault')),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Cotizador Universal IA y Cuota"), findsOneWidget);
      expect(find.text("50 disponibles"), findsOneWidget);
      expect(find.text("Bolsa MochilaLista"), findsOneWidget);
      expect(find.text("Clave Propia (BYOK)"), findsOneWidget);
      expect(find.text("Abrir Google AI Studio"), findsOneWidget);

      // Ingresar clave propia en la bóveda
      const testKey = "AIzaSyTest1234567890SecretKeyValid";
      await tester.runAsync(() async {
        await AiVaultService.instance.addKey(
          alias: "Gmail Principal",
          apiKey: testKey,
        );
        await provider.setAiSelectedMode('BYOK');
      });

      await tester.pumpWidget(buildTestableWidget(
        const AiSettingsScreen(key: ValueKey('byok_vault_loaded')),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      expect(ApiConstants.isUsingCustomApiKey, isTrue);
      expect(find.text("Gmail Principal"), findsWidgets);
      expect(find.text("En Uso"), findsOneWidget);
      expect(find.text("Bolsa Congelada (BYOK)"), findsOneWidget);
    });
  });

  group('6. Modal Post-Actualización y Registro de Versión', () {
    testWidgets('PostUpdateWelcomeModal se despliega y actualiza last_executed_app_version', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const PostUpdateWelcomeModal(appVersion: '9.23.0+73'),
        provider: provider,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("¡Actualización Exitosa!"), findsOneWidget);
      expect(find.text("Tus datos y licencia han sido migrados con éxito y respaldo verificado."), findsOneWidget);
      expect(find.textContaining(OwnerLegalIdentity.authorFullName, skipOffstage: false), findsWidgets);

      await tester.runAsync(() async {
        await provider.updateLastExecutedVersion('9.23.0+73');
      });
      await tester.ensureVisible(find.text("Comenzar a Usar"));
      await tester.tap(find.text("Comenzar a Usar"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final rows = await testDb.query('licencia_app');
      expect(rows.first['last_executed_app_version'], equals('9.23.0+73'));
    });
  });

  group('7. Pantallas de Bloqueo Estricto, Reloj Desajustado y Modal Modo Lectura', () {
    testWidgets('LicenseLockedScreen muestra ID, WhatsApp y botón de respaldo siempre activo', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseLockedScreen(),
        provider: provider,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Licencia Concluida"), findsOneWidget);
      expect(find.text(mockDeviceId), findsOneWidget);
      expect(find.text("Contactar a Soporte por WhatsApp"), findsOneWidget);
      expect(find.text("Exportar Copia de Seguridad (.mlbg)"), findsOneWidget);
    });

    testWidgets('ClockDesyncedScreen muestra hora desfasada, instrucciones y reintento', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const ClockDesyncedScreen(),
        provider: provider,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Fecha u Hora Desajustada"), findsOneWidget);
      expect(find.text("Reintentar Verificación"), findsOneWidget);
      expect(find.text("Exportar Copia de Seguridad (.mlbg)"), findsOneWidget);
    });

    testWidgets('SoftLockRenewalModal intercepta amigablemente con botón Renovar Ahora', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const SoftLockRenewalModal(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Modo Lectura / Cobranza Activo"), findsOneWidget);
      expect(find.text("Renovar Ahora"), findsOneWidget);
      expect(find.text("Continuar en Modo Lectura"), findsOneWidget);
    });
  });

  group('8. Cero Desbordes (0px Overflow) en Resoluciones Compactas 320x568dp y 360x640dp', () {
    final compactSizes = [
      const Size(320, 568), // iPhone SE / ultra compacto
      const Size(360, 640), // Android estándar compacto
    ];

    for (final size in compactSizes) {
      testWidgets('LicenseStatusAndActivationScreen renderiza con 0px overflow en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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

        expect(find.text("QR desde Galería"), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AiSettingsScreen renderiza con 0px overflow en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(buildTestableWidget(
          const AiSettingsScreen(),
          provider: provider,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });

      testWidgets('LicenseLockedScreen renderiza con 0px overflow en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(buildTestableWidget(
          const LicenseLockedScreen(),
          provider: provider,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });

      testWidgets('ClockDesyncedScreen renderiza con 0px overflow en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(buildTestableWidget(
          const ClockDesyncedScreen(),
          provider: provider,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });

      testWidgets('EulaAcceptanceModal renderiza con 0px overflow en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(buildTestableWidget(
          const EulaAcceptanceModal(),
          provider: provider,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
