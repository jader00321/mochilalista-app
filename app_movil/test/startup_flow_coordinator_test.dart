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
import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';

// Modales y Pantallas
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

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
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  Widget buildTestHost(LicenseProvider provider, {required Future<void> Function(BuildContext) onRunFlow}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LicenseProvider?>.value(value: provider),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('trigger_startup_flow'),
                  onPressed: () => onRunFlow(context),
                  child: const Text('Ejecutar StartupFlow'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  group('StartupFlowCoordinator — Detección de Datos Comerciales Previos', () {
    test('hasPriorCommercialData retorna false en base de datos vacía', () async {
      final hasData = await StartupFlowCoordinator.hasPriorCommercialData(db: testDb);
      expect(hasData, isFalse);
    });

    test('hasPriorCommercialData retorna true si existen productos', () async {
      await testDb.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Cuaderno Standford A4',
      });
      final hasData = await StartupFlowCoordinator.hasPriorCommercialData(db: testDb);
      expect(hasData, isTrue);
    });

    test('hasPriorCommercialData retorna true si existen ventas', () async {
      await testDb.insert('ventas', {
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'metodo_pago': 'EFECTIVO',
        'monto_total': 50.0,
        'monto_pagado': 50.0,
      });
      final hasData = await StartupFlowCoordinator.hasPriorCommercialData(db: testDb);
      expect(hasData, isTrue);
    });

    test('hasPriorCommercialData retorna true si existen clientes', () async {
      await testDb.insert('clientes', {
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'nombre_completo': 'Cliente Frecuente Prueba',
        'telefono': '987654321',
      });
      final hasData = await StartupFlowCoordinator.hasPriorCommercialData(db: testDb);
      expect(hasData, isTrue);
    });
  });

  group('StartupFlowCoordinator — Máquina de Estados de Arranque (4 Escenarios)', () {
    testWidgets('1. Escenario A (Instalación Limpia): EULA aceptado -> Registra versión en DB -> Redirige a Licencia con Notice -> No muestra update modal', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      // Asegurar que no hay datos previos ni versión registrada
      expect(provider.license!.lastExecutedAppVersion, isNull);
      expect(provider.license!.eulaAcceptedVersion, isNull);

      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      // Disparar flujo de arranque
      await tester.tap(find.byKey(const Key('trigger_startup_flow')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Debe aparecer el modal de EULA
      expect(find.byType(EulaAcceptanceModal), findsOneWidget);
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);

      // Desplazarse al fondo del EULA para habilitar el botón de aceptación
      final scrollFinder = find.byType(SingleChildScrollView);
      await tester.drag(scrollFinder, const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Marcar checkbox y aceptar EULA
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text("Aceptar Términos de Licencia"));
      await tester.pumpAndSettle();

      // 2. Verificar resultado del coordinador
      expect(flowResult, equals(StartupScenarioResult.freshInstallNavigatedToLicense));

      // 3. NO debe haber mostrado el modal de actualización
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);

      // 4. Debe haberse redirigido a la pantalla de Licencia y Activación con el banner de bienvenida
      expect(find.byType(LicenseStatusAndActivationScreen), findsOneWidget);
      expect(
        find.textContaining("¡Bienvenido a MochilaLista! Dispones de 30 días de prueba gratuita"),
        findsOneWidget,
      );

      // 5. Debe haberse registrado la versión actual en base de datos
      final rows = await testDb.query('licencia_app');
      expect(rows.first['last_executed_app_version'], equals(AppChangelogRegistry.currentVersion));
      expect(rows.first['eula_accepted_version'], isNotNull);
    });

    testWidgets('2. Escenario B1 (Usuario Antiguo sin lastExecutedAppVersion pero con datos en SQLite): EULA -> Modal Update trialOrGrace con 2 botones', (tester) async {
      // Simular usuario antiguo con productos previos
      await testDb.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Mochila Escolar Porta',
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      expect(provider.license!.lastExecutedAppVersion, isNull);

      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      // Disparar flujo
      await tester.tap(find.byKey(const Key('trigger_startup_flow')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Muestra EULA pendiente
      expect(find.byType(EulaAcceptanceModal), findsOneWidget);

      final scrollFinder = find.byType(SingleChildScrollView);
      await tester.drag(scrollFinder, const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text("Aceptar Términos de Licencia"));
      await tester.pumpAndSettle();

      // 2. Ahora debe desplegar PostUpdateWelcomeModal en modo trialOrGrace
      expect(find.byType(PostUpdateWelcomeModal), findsOneWidget);
      expect(
        find.textContaining("Tus datos comerciales han sido migrados con éxito"),
        findsOneWidget,
      );

      // 3. Debe ofrecer ambos botones de acción
      expect(find.text("Activar Plan / Ver Licencia"), findsOneWidget);
      expect(find.text("Continuar con mi prueba"), findsOneWidget);

      // 4. Cerrar presionando "Continuar con mi prueba"
      await tester.ensureVisible(find.text("Continuar con mi prueba"));
      await tester.tap(find.text("Continuar con mi prueba"));
      await tester.pumpAndSettle();

      expect(flowResult, equals(StartupScenarioResult.legacyUpgradeShowedUpdateModal));
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);

      // 5. Debe haberse registrado la versión en DB
      final rows = await testDb.query('licencia_app');
      expect(rows.first['last_executed_app_version'], equals(AppChangelogRegistry.currentVersion));
    });

    testWidgets('3. Escenario B2 (Actualización de Versión en Trial/Gracia): Muestra PostUpdateWelcomeModal trialOrGrace con 2 botones', (tester) async {
      // Usuario con EULA aceptado pero versión anterior
      final repo = await LocalDatabase.instance.database;
      await repo.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'eula_accepted_version': '9.20.0+70',
        'last_executed_app_version': '9.20.0+70',
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      expect(provider.license!.isTrial, isTrue);
      expect(provider.license!.lastExecutedAppVersion, equals('9.20.0+70'));

      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_startup_flow')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No debe pedir EULA porque ya estaba aceptado
      expect(find.byType(EulaAcceptanceModal), findsNothing);

      // Debe abrir directamente el modal de actualización en modo trialOrGrace
      expect(find.byType(PostUpdateWelcomeModal), findsOneWidget);
      expect(
        find.textContaining("Tus datos comerciales han sido migrados con éxito"),
        findsOneWidget,
      );
      expect(find.text("Activar Plan / Ver Licencia"), findsOneWidget);
      expect(find.text("Continuar con mi prueba"), findsOneWidget);

      // Probar navegación a pantalla de Licencia al presionar "Activar Plan / Ver Licencia"
      await tester.ensureVisible(find.text("Activar Plan / Ver Licencia"));
      await tester.tap(find.text("Activar Plan / Ver Licencia"));
      await tester.pumpAndSettle();

      expect(flowResult, equals(StartupScenarioResult.trialUpgradeShowedUpdateModal));
      expect(find.byType(LicenseStatusAndActivationScreen), findsOneWidget);
    });

    testWidgets('4. Escenario C (Actualización con Licencia Comercial Pagada o Perpetua): Muestra 1 solo botón "Comenzar a Usar"', (tester) async {
      // Usuario con plan MENSUAL pagado activo y versión anterior
      final repo = await LocalDatabase.instance.database;
      await repo.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'MENSUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'eula_accepted_version': '9.20.0+70',
        'last_executed_app_version': '9.20.0+70',
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      expect(provider.license!.isTrial, isFalse);
      expect(provider.license!.isActive, isTrue);

      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_startup_flow')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Despliega PostUpdateWelcomeModal en modo activeCommercialOrPerpetual
      expect(find.byType(PostUpdateWelcomeModal), findsOneWidget);
      expect(
        find.text("Tus datos y licencia han sido migrados con éxito y respaldo verificado."),
        findsOneWidget,
      );

      // 1 solo botón "Comenzar a Usar"
      expect(find.text("Comenzar a Usar"), findsOneWidget);
      expect(find.text("Activar Plan / Ver Licencia"), findsNothing);
      expect(find.text("Continuar con mi prueba"), findsNothing);

      // Presionar "Comenzar a Usar"
      await tester.ensureVisible(find.text("Comenzar a Usar"));
      await tester.tap(find.text("Comenzar a Usar"));
      await tester.pumpAndSettle();

      expect(flowResult, equals(StartupScenarioResult.commercialUpgradeShowedUpdateModal));
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);

      final rows = await testDb.query('licencia_app');
      expect(rows.first['last_executed_app_version'], equals(AppChangelogRegistry.currentVersion));
    });

    testWidgets('5. Cancelación / Rechazo de EULA detiene limpiamente el flujo', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_startup_flow')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EulaAcceptanceModal), findsOneWidget);

      // Presionar Cancelar sin aceptar (despliega diálogo de barrera)
      await tester.tap(find.text("Cancelar"));
      await tester.pumpAndSettle();

      expect(find.text("Aceptación Obligatoria"), findsOneWidget);
      await tester.tap(find.text("Salir de la App"));
      await tester.pumpAndSettle();

      expect(flowResult, equals(StartupScenarioResult.eulaCancelled));
      expect(find.byType(EulaAcceptanceModal), findsNothing);
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);
      expect(find.byType(LicenseStatusAndActivationScreen), findsNothing);

      // La versión en DB no debe haber sido actualizada
      final rows = await testDb.query('licencia_app');
      expect(rows.first['last_executed_app_version'], isNull);
      expect(rows.first['eula_accepted_version'], isNull);
    });
  });

  group('PostUpdateWelcomeModal — Renderizado Libre de Overflows (0px overflow)', () {
    testWidgets('Renderiza en pantalla ultra-compacta (320x568) en modo trialOrGrace con 0px overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider?>.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PostUpdateWelcomeModal(
                appVersion: '9.30.0+74',
                mode: PostUpdateMode.trialOrGrace,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("¡Actualización Exitosa!"), findsOneWidget);
      expect(find.text("Activar Plan / Ver Licencia"), findsOneWidget);
      expect(find.text("Continuar con mi prueba"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renderiza en pantalla ultra-compacta (320x568) en modo activeCommercialOrPerpetual con 0px overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider?>.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PostUpdateWelcomeModal(
                appVersion: '9.30.0+74',
                mode: PostUpdateMode.activeCommercialOrPerpetual,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("¡Actualización Exitosa!"), findsOneWidget);
      expect(find.text("Comenzar a Usar"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renderiza en pantalla estándar (360x640) en ambos modos con 0px overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      // Modo trialOrGrace
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider?>.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PostUpdateWelcomeModal(
                appVersion: '9.30.0+74',
                mode: PostUpdateMode.trialOrGrace,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Activar Plan / Ver Licencia"), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Modo activeCommercialOrPerpetual
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider?>.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PostUpdateWelcomeModal(
                appVersion: '9.30.0+74',
                mode: PostUpdateMode.activeCommercialOrPerpetual,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Comenzar a Usar"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
