import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';

import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = 'ML-A54-TEST';

  setUpAll(() async {
    databaseFactory = databaseFactoryFfiNoIsolate;
    final ed25519 = Ed25519();
    testKeyPair = await ed25519.newKeyPair();
    testPublicKey = await testKeyPair.extractPublicKey();
  });

  setUp(() async {
    StartupFlowCoordinator.resetSessionStateForTesting();
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
    StartupFlowCoordinator.resetSessionStateForTesting();
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
                  key: const Key('trigger_flow_button'),
                  onPressed: () => onRunFlow(context),
                  child: const Text('Trigger Flow'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  group('Plan Maestro 12 — Fase 1: Certificación Anti-Carrera y Separación Update vs Backup', () {
    testWidgets('1. Condición de carrera resuelta: Si license == null en frame 1, espera a checkLicense(), detecta actualización y persiste versión', (tester) async {
      // Configurar base de datos con versión previa (ej. v9.31) y datos comerciales
      await testDb.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Mochila Escolar Cuero',
      });
      await testDb.insert('licencia_app', {
        'id': 1,
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 25)).toIso8601String(),
        'ultimo_nonce': 0,
        'ai_accumulated_scans': 49,
        'ai_selected_mode': 'INCLUDED',
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'eula_accepted_version': '1.0',
        'last_executed_app_version': '9.31.0+75', // Versión previa diferente a la actual
      });

      // Crear provider SIN llamar a checkLicense() de antemano (license es null)
      final provider = LicenseProvider();
      expect(provider.license, isNull);

      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      // Disparar flujo de arranque
      await tester.tap(find.byKey(const Key('trigger_flow_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificación: Se cargó la licencia automáticamente a pesar de ser null al inicio
      expect(provider.license, isNotNull);
      expect(provider.license!.lastExecutedAppVersion, equals('9.31.0+75'));

      // Debe haberse desplegado el modal "¡Actualización Exitosa!"
      expect(find.byType(PostUpdateWelcomeModal), findsOneWidget);
      expect(find.text("¡Actualización Exitosa!"), findsOneWidget);

      // Cerrar el modal mediante el botón 'X'
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Verificación: Al cerrarse, el coordinador completa y retorna el resultado
      expect(flowResult, equals(StartupScenarioResult.trialUpgradeShowedUpdateModal));

      // Verificar persistencia en base de datos de la versión actual
      final rows = await testDb.query('licencia_app', where: 'id = 1');
      expect(rows.first['last_executed_app_version'], equals(AppChangelogRegistry.currentVersion));
      expect(rows.first['last_executed_app_version'], equals(OwnerLegalIdentity.currentAppVersionWithBuild));
    });

    testWidgets('2. No duplicación entre pantallas: Segunda llamada a coordinateStartup en la misma sesión no reabre el modal', (tester) async {
      // Configurar BD con versión previa
      await testDb.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Cuaderno Cuadriculado 100h',
      });
      await testDb.insert('licencia_app', {
        'id': 1,
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'MENSUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'ultimo_nonce': 0,
        'ai_accumulated_scans': 150,
        'ai_selected_mode': 'INCLUDED',
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'eula_accepted_version': '1.0',
        'last_executed_app_version': '9.31.0+75',
      });

      final provider = LicenseProvider();
      await tester.runAsync(() => provider.checkLicense());

      StartupScenarioResult? firstResult;
      StartupScenarioResult? secondResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          // Simular llamada en ProfileSelectionScreen
          firstResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_flow_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PostUpdateWelcomeModal), findsOneWidget);

      // Cerrar modal
      await tester.tap(find.byType(IconButton)); // Botón cerrar 'X'
      await tester.pumpAndSettle();

      expect(firstResult, equals(StartupScenarioResult.commercialUpgradeShowedUpdateModal));
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);

      // Simular segunda llamada en HomeScreen en la misma sesión
      final hostState = tester.state(find.byType(Scaffold));
      secondResult = await StartupFlowCoordinator.coordinateStartup(hostState.context, customDb: testDb);

      // Verificación: No vuelve a abrirse y retorna normalStartupNoModal
      expect(secondResult, equals(StartupScenarioResult.normalStartupNoModal));
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);
    });

    testWidgets('3. Inmunización post-restauración: Restaurar backup con versión antigua sella last_executed_app_version y NO dispara update modal', (tester) async {
      // 1. Simular base de datos restaurada desde un backup antiguo (ej. v9.30 o v9.31)
      await testDb.insert('licencia_app', {
        'id': 1,
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIMESTRAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'ultimo_nonce': 0,
        'ai_accumulated_scans': 200,
        'ai_selected_mode': 'INCLUDED',
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'eula_accepted_version': '1.0',
        'last_executed_app_version': '9.30.0+74', // Versión del backup antiguo
      });

      // Simular la regla de inmunización que ejecuta BackupManager al restaurar SQLite
      await testDb.execute('''
        UPDATE licencia_app 
        SET last_executed_app_version = ?
        WHERE id = 1
      ''', [OwnerLegalIdentity.currentAppVersionWithBuild]);

      // Verificar que la BD quedó sellada
      final rows = await testDb.query('licencia_app', where: 'id = 1');
      expect(rows.first['last_executed_app_version'], equals(OwnerLegalIdentity.currentAppVersionWithBuild));

      // Simular reinicio de la app (nueva sesión)
      StartupFlowCoordinator.resetSessionStateForTesting();

      final provider = LicenseProvider();
      await tester.runAsync(() => provider.checkLicense());

      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_flow_button')));
      await tester.pumpAndSettle();

      // Verificación crítica: NUNCA se muestra el modal "¡Actualización Exitosa!"
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);
      expect(flowResult, equals(StartupScenarioResult.normalStartupNoModal));
    });

    testWidgets('4. Instalación limpia: Base de datos vacía exige EULA y NO muestra modal de actualización', (tester) async {
      // Base de datos limpia sin tabla licencia_app ni datos previos
      StartupFlowCoordinator.resetSessionStateForTesting();

      final provider = LicenseProvider();
      StartupScenarioResult? flowResult;

      await tester.pumpWidget(buildTestHost(
        provider,
        onRunFlow: (ctx) async {
          flowResult = await StartupFlowCoordinator.coordinateStartup(ctx, customDb: testDb);
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_flow_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mostrar EULA
      expect(find.byType(EulaAcceptanceModal), findsOneWidget);
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);

      // Aceptar EULA
      final scrollFinder = find.byType(SingleChildScrollView);
      await tester.drag(scrollFinder, const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text("Aceptar Términos de Licencia"));
      await tester.pumpAndSettle();

      // Redirige a pantalla de licencia con notice de prueba
      expect(flowResult, equals(StartupScenarioResult.freshInstallNavigatedToLicense));
      expect(find.byType(LicenseStatusAndActivationScreen), findsOneWidget);
      expect(find.byType(PostUpdateWelcomeModal), findsNothing);

      // La versión registrada debe ser la actual
      final rows = await testDb.query('licencia_app', where: 'id = 1');
      expect(rows.first['last_executed_app_version'], equals(AppChangelogRegistry.currentVersion));
    });
  });
}
