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
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';

// Widgets bajo prueba
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';

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
    StartupFlowCoordinator.resetIntegrityCompromised();

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
    StartupFlowCoordinator.resetIntegrityCompromised();
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
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('1. Cabecera Legal Completa y 7 Cláusulas Blindadas (Marco Legal Peruano)', () {
    testWidgets('Muestra cabecera en 2 niveles sin truncar y presencia íntegra de las 7 cláusulas', (tester) async {
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

      // 1. Cabecera en 2 niveles completa sin truncar
      expect(find.text(OwnerLegalIdentity.legalEulaTitle), findsOneWidget);
      expect(find.text(OwnerLegalIdentity.legalSubtitleCommercial), findsOneWidget);
      expect(find.text(OwnerLegalIdentity.legalAuthorTitle), findsOneWidget);
      expect(find.textContaining(OwnerLegalIdentity.authorFullName, skipOffstage: false), findsWidgets);

      // 2. Presencia de las 7 Cláusulas Legales Oficiales
      expect(find.textContaining("CLÁUSULA PRIMERA: PROPIEDAD INTELECTUAL"), findsOneWidget);
      expect(find.textContaining("Decreto Legislativo 822"), findsWidgets);
      expect(find.textContaining("INDECOPI"), findsWidgets);

      expect(find.textContaining("CLÁUSULA SEGUNDA: ALCANCE MULTINEGOCIO"), findsOneWidget);
      expect(find.textContaining("Hardware ID / DeviceFingerprint"), findsOneWidget);

      expect(find.textContaining("CLÁUSULA TERCERA: PROHIBICIÓN EXPRESA DE FRAUDE"), findsOneWidget);
      expect(find.textContaining("Código Penal Peruano"), findsOneWidget);

      expect(find.textContaining("CLÁUSULA CUARTA: DESLINDE DE RESPONSABILIDAD BYOK"), findsOneWidget);
      expect(find.textContaining("Google AI Studio"), findsOneWidget);

      expect(find.textContaining("CLÁUSULA QUINTA: PRIVACIDAD DE DATOS (LEY N° 29733)"), findsOneWidget);
      expect(find.textContaining("Offline-First"), findsOneWidget);

      expect(find.textContaining("CLÁUSULA SEXTA: POLÍTICA DE ACTUALIZACIONES"), findsOneWidget);
      expect(find.textContaining("Licencia Perpetua"), findsOneWidget);

      expect(find.textContaining("CLÁUSULA SÉPTIMA: JURISDICCIÓN Y SOLUCIÓN DE CONTROVERSIAS"), findsOneWidget);
      expect(find.textContaining("Distrito Judicial de Lima, República del Perú"), findsOneWidget);
    });
  });

  group('2. Mecanismo de Scroll Obligatorio Estricto y Guía Visual Dinámica', () {
    testWidgets('Guía visual se muestra inicialmente y botón permanece bloqueado hasta el fondo', (tester) async {
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

      // 1. Debe mostrarse la guía visual
      expect(
        find.text("Desliza hasta el final del contrato para habilitar la aceptación"),
        findsOneWidget,
      );

      // 2. El checkbox no debe permitir marcarse
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      final Checkbox cbBefore = tester.widget(checkboxFinder);
      expect(cbBefore.onChanged, isNull);

      // Intentar marcar la casilla antes del scroll no surte efecto
      await tester.tap(checkboxFinder);
      await tester.pump();
      final Checkbox cbStillUnchecked = tester.widget(checkboxFinder);
      expect(cbStillUnchecked.value, isFalse);

      // 3. El botón aceptar está inhabilitado
      final acceptBtnFinder = find.widgetWithText(ElevatedButton, "Aceptar Términos de Licencia");
      expect(acceptBtnFinder, findsOneWidget);
      final ElevatedButton btnBefore = tester.widget(acceptBtnFinder);
      expect(btnBefore.onPressed, isNull);

      // 4. Desplazarse hasta el fondo
      final scrollFinder = find.byType(SingleChildScrollView);
      await tester.drag(scrollFinder, const Offset(0, -2500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // La guía visual debe desaparecer
      expect(
        find.text("Desliza hasta el final del contrato para habilitar la aceptación"),
        findsNothing,
      );

      // Checkbox ahora habilitado
      final Checkbox cbAfter = tester.widget(checkboxFinder);
      expect(cbAfter.onChanged, isNotNull);

      // Marcar checkbox
      await tester.tap(checkboxFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Botón aceptar ahora habilitado
      final ElevatedButton btnEnabled = tester.widget(acceptBtnFinder);
      expect(btnEnabled.onPressed, isNotNull);

      // Presionar aceptar y validar persistencia
      await tester.tap(acceptBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final rows = await testDb.query('licencia_app');
      expect(rows.first['eula_accepted_version'], equals('1.0'));
      expect(rows.first['eula_accepted_timestamp'], isNotNull);
    });
  });

  group('3. Diálogo de Barrera ante Cancelación (Modo Obligatorio)', () {
    testWidgets('Al pulsar Cancelar despliega diálogo formal; Revisar Contrato regresa y Salir de la App invoca onExitApp', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      bool exitAppCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => EulaAcceptanceModal.show(
                ctx,
                onExitApp: () => exitAppCalled = true,
              ),
              child: const Text("Abrir EULA"),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Abrir EULA"));
      await tester.pumpAndSettle();

      expect(find.byType(EulaAcceptanceModal), findsOneWidget);

      // 1. Pulsar Cancelar -> Abre diálogo de barrera
      await tester.tap(find.text("Cancelar"));
      await tester.pumpAndSettle();

      expect(find.text("Aceptación Obligatoria"), findsOneWidget);
      expect(find.text("Revisar Contrato"), findsOneWidget);
      expect(find.text("Salir de la App"), findsOneWidget);

      // 2. Pulsar "Revisar Contrato" -> Cierra la barrera y devuelve al EULA
      await tester.tap(find.text("Revisar Contrato"));
      await tester.pumpAndSettle();

      expect(find.text("Aceptación Obligatoria"), findsNothing);
      expect(find.byType(EulaAcceptanceModal), findsOneWidget);
      expect(exitAppCalled, isFalse);

      // 3. Volver a pulsar Cancelar y presionar "Salir de la App"
      await tester.tap(find.text("Cancelar"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Salir de la App"));
      await tester.pumpAndSettle();

      expect(find.text("Aceptación Obligatoria"), findsNothing);
      expect(find.byType(EulaAcceptanceModal), findsNothing);
      expect(exitAppCalled, isTrue);
    });
  });

  group('4. Persistencia Global del EULA, Anclaje de Primer Trial y Anti-Tampering', () {
    test('Persistencia global: aceptar EULA en SQLite lo persiste, y una instalación limpia resetea el EULA obligatoriamente', () async {
      const storage = FlutterSecureStorage();
      final repo = LicenseRepository(secureStorage: storage);

      // Inicializa licencia
      final lic1 = await repo.getOrCreateLicense();
      expect(lic1.eulaAcceptedVersion, isNull);

      // Acepta EULA
      await repo.recordEulaAcceptance('1.0');

      // Verifica que se guardó en SQLite y en almacenamiento
      final licAccepted = await repo.getOrCreateLicense();
      expect(licAccepted.eulaAcceptedVersion, equals('1.0'));
      expect(licAccepted.eulaAcceptedTimestamp, isNotNull);

      // Simular desinstalación y reinstalación limpia (base de datos SQLite eliminada de cero)
      await testDb.delete('licencia_app');
      final rowsEmpty = await testDb.query('licencia_app');
      expect(rowsEmpty, isEmpty);

      // Al volver a inicializar la licencia en una instalación limpia, el EULA debe ser estrictamente null
      // y limpiar cualquier clave residual de Keystore
      final licClean = await repo.getOrCreateLicense();
      expect(licClean.eulaAcceptedVersion, isNull,
          reason: 'En instalación limpia no debe heredar EULA de Keystore');
      expect(licClean.eulaAcceptedTimestamp, isNull);
    });

    test('Anclaje de first_trial_timestamp: borrado de SQLite respeta la fecha de inicio del trial original', () async {
      const storage = FlutterSecureStorage();
      final repo = LicenseRepository(secureStorage: storage);

      // Fecha simulada de hace 10 días
      final originalStart = DateTime.now().subtract(const Duration(days: 10));
      await storage.write(
        key: LicenseRepository.firstTrialStorageKey,
        value: originalStart.toIso8601String(),
      );

      // Inicializa licencia en BD limpia
      final lic = await repo.getOrCreateLicense();

      // Debe calcular la fecha de inicio a partir del valor anclado
      expect(lic.fechaInicio.day, equals(originalStart.day));
      expect(lic.fechaInicio.month, equals(originalStart.month));

      // Días restantes deben ser ~20 (no 30)
      expect(lic.daysRemaining, lessThanOrEqualTo(20));
    });

    testWidgets('Anti-Tampering en StartupFlowCoordinator: flag isIntegrityCompromised permanece false si firma es válida', (tester) async {
      final repo = await LocalDatabase.instance.database;
      await repo.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'eula_accepted_version': '1.0',
        'last_executed_app_version': '9.30.0+74',
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              await StartupFlowCoordinator.coordinateStartup(
                ctx,
                signatureVerifier: () async => true,
              );
            },
            child: const Text("Run Safe"),
          ),
        ),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Run Safe"));
      await tester.pumpAndSettle();
      expect(StartupFlowCoordinator.isIntegrityCompromised, isFalse);
    });

    testWidgets('Anti-Tampering en StartupFlowCoordinator: flag isIntegrityCompromised cambia a true si firma es adulterada', (tester) async {
      final repo = await LocalDatabase.instance.database;
      await repo.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'eula_accepted_version': '1.0',
        'last_executed_app_version': '9.30.0+74',
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              await StartupFlowCoordinator.coordinateStartup(
                ctx,
                signatureVerifier: () async => false,
              );
            },
            child: const Text("Run Tampered"),
          ),
        ),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Run Tampered"));
      await tester.pumpAndSettle();
      expect(StartupFlowCoordinator.isIntegrityCompromised, isTrue);
    });
  });

  group('5. Cero Desbordes (0px Overflow) en Resoluciones Compactas 320x568dp y 360x640dp', () {
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      testWidgets('EulaAcceptanceModal renderiza con 0px overflow en modo obligatorio en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(buildTestableWidget(
          const EulaAcceptanceModal(isReadOnly: false),
          provider: provider,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(EulaAcceptanceModal), findsOneWidget);
        expect(find.text(OwnerLegalIdentity.legalEulaTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('EulaAcceptanceModal renderiza con 0px overflow en modo solo lectura en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(buildTestableWidget(
          const EulaAcceptanceModal(isReadOnly: true),
          provider: provider,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(EulaAcceptanceModal), findsOneWidget);
        expect(find.text("Cerrar"), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
