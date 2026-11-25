import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/home/dashboard_header.dart';
import 'package:app_movil/core/widgets/shimmer_box.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';

class _TrackingHomeHost extends StatefulWidget {
  final HomeScreenTourKeys tourKeys;
  final VoidCallback onInitState;
  final VoidCallback onDispose;

  const _TrackingHomeHost({
    required this.tourKeys,
    required this.onInitState,
    required this.onDispose,
  });

  @override
  State<_TrackingHomeHost> createState() => _TrackingHomeHostState();
}

class _TrackingHomeHostState extends State<_TrackingHomeHost> {
  @override
  void initState() {
    super.initState();
    widget.onInitState();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          DashboardHeader(tourKeys: widget.tourKeys),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    StartupFlowCoordinator.resetSessionStateForTesting();
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      LicenseRepository.deviceEulaVersionKey: LicenseRepository.canonicalEulaVersion,
      LicenseRepository.deviceEulaTimestampKey: '2026-11-24T10:00:00.000Z',
    });
    DeviceFingerprint.setMockFingerprint('ML-F1P21-TEST');

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);

    await testDb.insert('usuarios', {
      'id': 1,
      'nombre_completo': 'Angello Vasquez',
      'telefono': '999888777',
      'email': 'angello@luzam.pe',
      'activo': 1,
      'fecha_creacion': '2026-11-24T10:00:00.000Z',
    });
    await testDb.insert('negocios', {
      'id': 1,
      'nombre_comercial': 'Luzam Librería Bazar',
      'ruc': '10456789012',
      'direccion': 'Av. Grau 123',
      'moneda': 'S/ (Soles)',
      'id_dueno': 1,
      'fecha_creacion': '2026-11-24T10:00:00.000Z',
    });
    final licenseRepo = LicenseRepository();
    await licenseRepo.getOrCreateLicense();
    await licenseRepo.recordEulaAcceptance(LicenseRepository.canonicalEulaVersion);
    await licenseRepo.updateLastExecutedAppVersion(OwnerLegalIdentity.currentAppVersionWithBuild);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    LocalDatabase.setCustomDatabase(null);
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    await testDb.close();
  });

  group('Fase 1 Plan 21 - Fluidez Home, Refresh Silencioso y Cero Doble Salto', () {
    test('1. AuthProvider.refreshActiveUser() actualiza datos en RAM sin emitir AuthStatus.checking', () async {
      final auth = AuthProvider();
      await auth.loginWithProfile(1);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.businessName, 'Luzam Librería Bazar');

      final observedStatuses = <AuthStatus>[];
      auth.addListener(() {
        observedStatuses.add(auth.status);
      });

      await testDb.update(
        'negocios',
        {'nombre_comercial': 'Luzam Actualizado SAC'},
        where: 'id = ?',
        whereArgs: [1],
      );

      await auth.refreshActiveUser();

      expect(auth.businessName, 'Luzam Actualizado SAC');
      expect(auth.status, AuthStatus.authenticated);
      expect(
        observedStatuses,
        isNot(contains(AuthStatus.checking)),
        reason: 'refreshActiveUser() jamás debe emitir AuthStatus.checking ni desmontar HomeScreen',
      );
    });

    test('2. WorkbenchProvider y SaleProvider en modo silent no emiten isLoading ni Shimmer', () async {
      final workbench = WorkbenchProvider();
      workbench.updateContext(1, 1);
      await workbench.loadDashboard();

      final observedWorkbenchLoading = <bool>[];
      workbench.addListener(() {
        observedWorkbenchLoading.add(workbench.isLoading);
      });

      await testDb.insert('smart_quotations', {
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'client_name': 'Cliente Prueba',
        'total_amount': 45.0,
        'total_savings': 0.0,
        'status': 'DRAFT',
        'type': 'manual',
        'created_at': DateTime.now().toIso8601String(),
      });

      await workbench.loadDashboard(silent: true);

      expect(observedWorkbenchLoading, isNotEmpty);
      expect(
        observedWorkbenchLoading.every((loading) => loading == false),
        isTrue,
        reason: 'loadDashboard(silent: true) no debe conmutar las tarjetas KPI a ShimmerBox',
      );
      expect(workbench.inProcessList.length, 1);

      final saleProv = SaleProvider();
      saleProv.updateContext(1, 1);
      await saleProv.loadSalesHistory();

      final observedSaleLoading = <bool>[];
      saleProv.addListener(() {
        observedSaleLoading.add(saleProv.isLoading || saleProv.isRefreshing);
      });

      await testDb.insert('ventas', {
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'monto_total': 25.0,
        'monto_pagado': 25.0,
        'fecha_venta': DateTime.now().toIso8601String(),
        'metodo_pago': 'Efectivo',
        'estado_pago': 'pagado',
        'is_archived': 0,
      });

      await saleProv.loadSalesHistory(silent: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(observedSaleLoading, isNotEmpty);
      expect(
        observedSaleLoading.every((busy) => busy == false),
        isTrue,
        reason: 'loadSalesHistory(silent: true) debe refrescar sin colapsar WeeklySalesChart ni KPIs',
      );
      expect(saleProv.salesHistory.length, 1);
    });

    testWidgets('3. DashboardHeader compactado: 0px Overflow en 320dp, 360dp y 412dp @ TextScaler 1.3x (Invitado y Autenticado)', (tester) async {
      final auth = AuthProvider();
      final sizes = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(412, 915),
      ];

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // A. Modo Invitado (caso crítico del fallo histórico de 2.0px)
      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => WorkbenchProvider()),
              ChangeNotifierProvider(create: (_) => SaleProvider()),
              ChangeNotifierProvider(create: (_) => TrackingProvider()),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  padding: EdgeInsets.only(top: 28),
                  viewPadding: EdgeInsets.only(top: 28),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: Column(
                    children: [
                      DashboardHeader(tourKeys: HomeScreenTourKeys()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Invitado en $size con TextScaler 1.3x debe tener 0px Overflow');
        expect(find.text('INVITADO'), findsOneWidget);
      }

      // B. Modo Autenticado (con negocio activo y tarjetas KPI visibles)
      await auth.loginWithProfile(1);
      final tourKeys = HomeScreenTourKeys();

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => WorkbenchProvider()),
              ChangeNotifierProvider(create: (_) => SaleProvider()),
              ChangeNotifierProvider(create: (_) => TrackingProvider()),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  padding: EdgeInsets.only(top: 28),
                  viewPadding: EdgeInsets.only(top: 28),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(
                  body: Column(
                    children: [
                      KeyedSubtree(
                        key: tourKeys.headerKey,
                        child: DashboardHeader(tourKeys: tourKeys),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 150));

        expect(tester.takeException(), isNull, reason: 'Autenticado en $size con TextScaler 1.3x debe tener 0px Overflow');
        expect(find.byKey(tourKeys.headerKey), findsOneWidget);
        expect(find.byKey(tourKeys.licenseAlertKey), findsOneWidget);

        if (size.width == 360) {
          final headerSize13 = tester.getSize(find.byType(DashboardHeader));
          expect(
            headerSize13.height,
            lessThan(248.0),
            reason: 'El encabezado compactado en 360dp @ 1.3x debe recuperar espacio vertical útil (antes ~276dp)',
          );

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider(create: (_) => NotificationProvider()),
                ChangeNotifierProvider(create: (_) => WorkbenchProvider()),
                ChangeNotifierProvider(create: (_) => SaleProvider()),
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: const MediaQueryData(
                    padding: EdgeInsets.only(top: 28),
                    viewPadding: EdgeInsets.only(top: 28),
                    textScaler: TextScaler.linear(1.0),
                  ),
                  child: Scaffold(
                    body: Column(
                      children: [
                        DashboardHeader(tourKeys: HomeScreenTourKeys()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          await tester.pump(const Duration(milliseconds: 150));
          expect(tester.takeException(), isNull);
          final headerSize10 = tester.getSize(find.byType(DashboardHeader));
          expect(
            headerSize10.height,
            lessThanOrEqualTo(225.0),
            reason: 'El encabezado compactado en 360dp @ 1.0x debe medir <= 225dp',
          );
        }
      }
    });

    testWidgets('4. Regreso ProfileScreen -> Home con 0 ventas mantiene Home montado, 0 AuthStatus.checking y 0 ShimmerBox', (tester) async {
      InteractiveTourService.autoTriggerOverrideForTesting = false;
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = AuthProvider();
      await auth.loginWithProfile(1);

      final licenseProv = LicenseProvider();
      final themeProv = ThemeProvider();
      final invProv = InventoryProvider();
      final workbenchProv = WorkbenchProvider()..updateContext(1, 1);
      final saleProv = SaleProvider()..updateContext(1, 1); // 0 ventas
      final notifProv = NotificationProvider()..updateContext(1, usuarioId: 1);
      final trackingProv = TrackingProvider()..updateContext(1, 1);

      final statuses = <AuthStatus>[];
      auth.addListener(() => statuses.add(auth.status));

      int initCount = 0;
      int disposeCount = 0;
      final tourKeys = HomeScreenTourKeys();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<LicenseProvider?>.value(value: licenseProv),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProv),
            ChangeNotifierProvider<InventoryProvider>.value(value: invProv),
            ChangeNotifierProvider<WorkbenchProvider>.value(value: workbenchProv),
            ChangeNotifierProvider<SaleProvider>.value(value: saleProv),
            ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
            ChangeNotifierProvider<TrackingProvider>.value(value: trackingProv),
          ],
          child: MaterialApp(
            home: Consumer<AuthProvider>(
              builder: (context, authState, _) {
                if (authState.status == AuthStatus.checking) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return _TrackingHomeHost(
                  tourKeys: tourKeys,
                  onInitState: () => initCount++,
                  onDispose: () => disposeCount++,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(initCount, 1);
      expect(disposeCount, 0);
      expect(saleProv.salesHistory, isEmpty);

      // Abrir ProfileScreen tocando el avatar del header
      await tester.tap(find.byKey(tourKeys.licenseAlertKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(ProfileScreen), findsOneWidget);

      // Volver a Home sin mutar datos
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      expect(find.byType(ShimmerBox), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(ShimmerBox), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(ShimmerBox), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.byType(DashboardHeader), findsOneWidget);
      expect(find.byType(ShimmerBox), findsNothing);
      expect(initCount, 1, reason: 'HomeScreen no debe remontarse jamás al volver de ProfileScreen');
      expect(disposeCount, 0);
      expect(statuses, isNot(contains(AuthStatus.checking)));

      // Ahora volver a entrar a ProfileScreen, regresar y verificar cero Shimmer y cero doble salto
      await tester.tap(find.byKey(tourKeys.licenseAlertKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      expect(find.byType(ShimmerBox), findsNothing);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(ShimmerBox), findsNothing);
      expect(initCount, 1);
      expect(disposeCount, 0);
      expect(statuses, isNot(contains(AuthStatus.checking)));
    });

    testWidgets('5. HomeScreen completo muestra MESA DE TRABAJO íntegra y 0px Overflow en 320dp, 360dp y 412dp @ 1.3x', (tester) async {
      InteractiveTourService.autoTriggerOverrideForTesting = false;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = AuthProvider();
      await auth.loginWithProfile(1);
      await auth.snoozePinReminder(days: 7);

      final licenseProv = LicenseProvider();
      await licenseProv.checkLicense();
      final invProv = InventoryProvider()..updateContext(1);
      final promoProv = PromotionProvider()..updateContext(1, invProv);

      Widget buildTestHome({double scale = 1.3}) => MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<LicenseProvider?>.value(value: licenseProv),
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider<InventoryProvider>.value(value: invProv),
              ChangeNotifierProvider<PromotionProvider>.value(value: promoProv),
              ChangeNotifierProvider(create: (_) => CatalogProvider()..updateContext(1, 1)),
              ChangeNotifierProvider(create: (_) => WorkbenchProvider()..updateContext(1, 1)),
              ChangeNotifierProvider(create: (_) => SaleProvider()..updateContext(1, 1)),
              ChangeNotifierProvider(create: (_) => NotificationProvider()..updateContext(1, usuarioId: 1)),
              ChangeNotifierProvider(create: (_) => TrackingProvider()..updateContext(1, 1)),
              ChangeNotifierProvider(create: (_) => SmartQuotationProvider()..updateContext(1, 1, null)),
              ChangeNotifierProvider(create: (_) => MatchingProvider()),
              ChangeNotifierProvider(create: (_) => ScannerProvider()..updateContext(1, 1, null)),
              ChangeNotifierProvider(create: (_) => QuickSaleProvider()..updateContext(1, 1)),
              ChangeNotifierProvider(create: (_) => QuickSearchProvider()..updateContext(1)),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  padding: const EdgeInsets.only(top: 28),
                  viewPadding: const EdgeInsets.only(top: 28),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const HomeScreen(),
              ),
            ),
          );

      // A. Verificar altura recuperada e integridad de MESA DE TRABAJO en 360x780 @ 1.0x
      await tester.pumpWidget(buildTestHome(scale: 1.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('MESA DE TRABAJO'), findsOneWidget);
      expect(find.text('Gestiona tus Listas y Pedidos'), findsOneWidget);

      final headerRect = tester.getRect(find.byType(DashboardHeader));
      expect(
        headerRect.height,
        lessThanOrEqualTo(225.0),
        reason: 'DashboardHeader compactado en HomeScreen debe dejar >= 55dp adicionales libres al contenido',
      );

      final mesaBadgeRect = tester.getRect(find.text('MESA DE TRABAJO'));
      expect(
        mesaBadgeRect.bottom,
        lessThan(690.0),
        reason: 'El encabezado de la tarjeta MESA DE TRABAJO debe quedar visible dentro del primer pantallazo encima del NavigationBar',
      );

      // B. Cero Overflows a TextScaler 1.3x en 320x568dp, 360x640dp y 412x915dp
      for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(buildTestHome(scale: 1.3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'HomeScreen completo en $size @ 1.3x debe tener 0px Overflow');
      }
    });
  });
}
