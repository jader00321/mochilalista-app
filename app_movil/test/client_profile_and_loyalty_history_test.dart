import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_stats_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/reward_review_modal.dart';

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  bool get hasActiveContext => true;

  @override
  String get businessName => 'Librería Central';

  @override
  String get activeBusinessName => 'Librería Central';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestApp({
  required Widget child,
  TrackingProvider? trackingProv,
  _MockAuthProvider? authProv,
  QuickSaleProvider? quickProv,
  Size size = const Size(360, 800),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TrackingProvider>.value(
        value: trackingProv ?? TrackingProvider(),
      ),
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProv ?? _MockAuthProvider(),
      ),
      ChangeNotifierProvider<QuickSaleProvider>.value(
        value: quickProv ?? QuickSaleProvider(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14141C),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 20),
        ),
        child: child,
      ),
    ),
  );
}

ClientModel _createTestClient({
  int id = 10,
  int negocioId = 1,
  int creadoPorUsuarioId = 1,
  String fullName = 'Juan Pérez',
  String phone = '999888777',
  int puntosActuales = 80,
  int scoreReputacion = 500,
  String nivelReputacion = 'PLATA',
  double saldoAFavor = 50.0,
  int rachaPagosPuntuales = 3,
  String registeredDate = '2026-11-01',
}) {
  return ClientModel(
    id: id,
    negocioId: negocioId,
    creadoPorUsuarioId: creadoPorUsuarioId,
    fullName: fullName,
    phone: phone,
    puntosActuales: puntosActuales,
    puntosHistoricos: puntosActuales,
    scoreReputacion: scoreReputacion,
    nivelReputacion: nivelReputacion,
    saldoAFavor: saldoAFavor,
    rachaPagosPuntuales: rachaPagosPuntuales,
    registeredDate: registeredDate,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late _MockAuthProvider mockAuth;
  late TrackingProvider trackingProv;
  late QuickSaleProvider quickProv;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    mockAuth = _MockAuthProvider();
    trackingProv = TrackingProvider();
    quickProv = QuickSaleProvider();

    await db.insert('negocios', {
      'id': 1,
      'nombre_comercial': 'Librería Central',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': 1,
      'nombre_completo': 'Administrador',
      'email': 'admin@central.com',
    });

    await LocalDatabase.seedDefaultMetasRecompensas(db);

    // Sembrar cliente en SQLite para tests directos de servicio
    await db.insert('clientes', {
      'id': 10,
      'negocio_id': 1,
      'creado_por_usuario_id': 1,
      'nombre_completo': 'Juan Pérez',
      'telefono': '999888777',
      'puntos_actuales': 80,
      'puntos_historicos': 80,
      'score_reputacion': 500,
      'nivel_reputacion': 'Plata',
      'saldo_a_favor': 50.0,
      'racha_pagos_puntuales': 3,
      'fecha_registro': '2026-11-01',
    });

    trackingProv.updateContext(1, 1);
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    await db.close();
  });

  group('G1: Decongestión del AppBar y Legibilidad en 360dp', () {
    testWidgets('AppBar muestra título sin desborde y botón estrella ⭐ fue removido', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient();

      await tester.pumpWidget(_buildTestApp(
        child: ClientDetailScreen(client: client, autoRefreshOnLoad: false),
        trackingProv: trackingProv,
        authProv: mockAuth,
        quickProv: quickProv,
      ));
      await tester.pump();

      // 1. Título completo sin cortes
      expect(find.text('Perfil del Cliente'), findsOneWidget);

      // 2. Botón estrella ⭐ en AppBar eliminado
      final appBars = find.byType(SliverAppBar);
      expect(appBars, findsOneWidget);
      final starInAppBar = find.descendant(
        of: appBars,
        matching: find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.stars_rounded && w.color == Colors.amber),
      );
      expect(starInAppBar, findsNothing);

      // 3. PopupMenuButton con opciones de administración
      final popupFinder = find.byType(PopupMenuButton<String>);
      expect(popupFinder, findsOneWidget);

      // Abrir el menú popup
      await tester.tap(popupFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Editar datos del cliente'), findsOneWidget);
      expect(find.text('Eliminar cliente'), findsOneWidget);
    });
  });

  group('G2: Retracción de Cabecera y TabBar Anti-Cutoff en 360dp', () {
    testWidgets('TabBar no es scrolleable, usa 3 pestañas concisas y no se corta en 360dp', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient();

      await tester.pumpWidget(_buildTestApp(
        child: ClientDetailScreen(client: client, autoRefreshOnLoad: false),
        trackingProv: trackingProv,
        authProv: mockAuth,
        quickProv: quickProv,
      ));
      await tester.pump();

      // Verificar pestañas completas
      expect(find.text('Estado de Cuenta'), findsOneWidget);
      expect(find.text('Compras'), findsOneWidget);
      expect(find.text('Listas / Cotiz.'), findsOneWidget);

      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final TabBar tabBar = tester.widget(tabBarFinder);
      expect(tabBar.isScrollable, isFalse);

      // Deslizar para verificar que el encabezado se retrae sin errores de viewport
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });

  group('G3: Botón + Préstamo y Modal de Acciones Financieras', () {
    testWidgets('ClientStatsHeader tiene botón + Préstamo (verde azulado) y abre modal en Tab 0', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient();

      await tester.pumpWidget(_buildTestApp(
        child: Scaffold(
          body: ClientStatsHeader(
            client: client,
            isDark: true,
            onWhatsAppTap: () {},
            onCallTap: () {},
            onGoToQuickSale: () {},
            onGoToQuotation: () {},
            onFinanceActionCompleted: () {},
          ),
        ),
        trackingProv: trackingProv,
        authProv: mockAuth,
        quickProv: quickProv,
      ));
      await tester.pump();

      // Botón + Préstamo
      final prestamoBtn = find.text('+ Préstamo');
      expect(prestamoBtn, findsOneWidget);

      await tester.tap(prestamoBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verificar modal abierto con selector de 2 tarjetas y subtítulos
      expect(find.text('Otorgar Préstamo'), findsWidgets);
      expect(find.text('Retirar Saldo'), findsOneWidget);
      expect(find.textContaining('En cuotas o pago único'), findsOneWidget);
      expect(find.textContaining('Límite de Crédito Sugerido (Plata):'), findsOneWidget);
      expect(find.text('Registrar Préstamo'), findsOneWidget);

      // Cambiar a Retirar Saldo
      await tester.tap(find.text('Retirar Saldo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Confirmar Retiro'), findsOneWidget);
    });

    testWidgets('ClientFinanceActionsModal abre directamente en initialTab=0 con límite sugerido', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient();

      await tester.pumpWidget(_buildTestApp(
        child: Scaffold(
          body: ClientFinanceActionsModal(
            client: client,
            isDark: true,
            initialTab: 0,
          ),
        ),
        trackingProv: trackingProv,
        authProv: mockAuth,
        quickProv: quickProv,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Otorgar Préstamo'), findsWidgets);
      expect(find.text('Retirar Saldo'), findsOneWidget);
      expect(find.text('Registrar Préstamo'), findsOneWidget);
      expect(find.textContaining('S/ 350.00'), findsOneWidget);
    });
  });

  group('G4: Modal Ajuste / Bono Manual Anti-Overflow y Protección Negativa', () {
    testWidgets('Ajuste Manual en 360dp no desborda, chips funcionan y protege saldo negativo', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient();

      await tester.pumpWidget(_buildTestApp(
        child: Scaffold(
          body: ClientLoyaltyHistoryModal(
            client: client,
            autoLoadHistory: false,
            initialMovements: const [],
          ),
        ),
        trackingProv: trackingProv,
        authProv: mockAuth,
        quickProv: quickProv,
      ));
      await tester.pump();

      // Abrir Bono Manual
      final bonoBtn = find.text('Bono Manual');
      expect(bonoBtn, findsOneWidget);
      await tester.tap(bonoBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ajuste / Bono Manual'), findsOneWidget);
      expect(find.text('Bono de cortesía'), findsOneWidget);

      // Cambiar a - Restar Puntos
      await tester.tap(find.text('- Restar Puntos'));
      await tester.pump(const Duration(milliseconds: 100));

      // Escribir 500 puntos (mayor que los 80 pts del cliente)
      final ptsField = find.byType(TextField).first;
      await tester.enterText(ptsField, '500');
      await tester.pump();

      // Verificar advertencia de saldo insuficiente y clamp a 0 pts
      expect(find.textContaining('Nuevo: 0 pts'), findsOneWidget);
      expect(find.textContaining('Excede el saldo'), findsOneWidget);

      // El botón Aplicar debe estar inhabilitado (onPressed null)
      final applyBtnFinder = find.widgetWithText(ElevatedButton, 'Aplicar');
      expect(applyBtnFinder, findsOneWidget);
      final ElevatedButton applyBtn = tester.widget(applyBtnFinder);
      expect(applyBtn.onPressed, isNull);

      // Escribir cantidad válida
      await tester.enterText(ptsField, '30');
      await tester.pump();
      expect(find.textContaining('Nuevo: 50 pts'), findsOneWidget);
      final ElevatedButton applyBtnValid = tester.widget(applyBtnFinder);
      expect(applyBtnValid.onPressed, isNotNull);
    });

    test('ClientService.addManualLoyaltyMovement no permite saldo negativo en SQLite', () async {
      final service = ClientService();
      // Restar 999 puntos al cliente con 80
      await service.addManualLoyaltyMovement(
        10,
        1,
        pointsDelta: -999,
        motivo: 'Ajuste de prueba',
        scoreDelta: -10,
        usuarioId: 1,
      );

      final updated = (await service.getClientById(10))!;
      expect(updated.puntosActuales, 0); // No baja de 0
    });
  });

  group('G5: Kardex Vectorial, Filtros y Apertura de RewardReviewModal', () {
    testWidgets('Métricas no usan emoji de fuego 🔥 y chips filtran movimientos', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient();

      final List<LoyaltyLedgerModel> movements = [
        LoyaltyLedgerModel(
          id: 1,
          negocioId: 1,
          clienteId: 10,
          tipoMovimiento: 'COMPRA_CONTADO',
          puntosDelta: 50,
          puntosSaldoResultante: 50,
          scoreDelta: 0,
          scoreResultante: 500,
          motivo: 'Compra escolar',
          fechaRegistro: '2026-11-06 10:00:00',
        ),
        LoyaltyLedgerModel(
          id: 2,
          negocioId: 1,
          clienteId: 10,
          tipoMovimiento: 'CANJE_RECOMPENSA',
          puntosDelta: -20,
          puntosSaldoResultante: 30,
          scoreDelta: 0,
          scoreResultante: 500,
          motivo: 'Canje de descuento',
          fechaRegistro: '2026-11-06 11:00:00',
        ),
      ];

      await tester.pumpWidget(_buildTestApp(
        child: Scaffold(
          body: ClientLoyaltyHistoryModal(
            client: client,
            autoLoadHistory: false,
            initialMovements: movements,
          ),
        ),
        trackingProv: trackingProv,
        authProv: mockAuth,
        quickProv: quickProv,
      ));
      await tester.pump();

      // Verificar que el texto de racha no tiene el emoji de fuego
      expect(find.textContaining('🔥'), findsNothing);
      expect(find.textContaining('a tiempo'), findsOneWidget);

      // Verificar que ambos movimientos están presentes
      expect(find.text('Compra escolar'), findsOneWidget);
      expect(find.text('Canje de descuento'), findsOneWidget);

      // Filtrar por + Ganados
      await tester.tap(find.text('+ Ganados'));
      await tester.pump();
      expect(find.text('Compra escolar'), findsOneWidget);
      expect(find.text('Canje de descuento'), findsNothing);

      // Filtrar por - Salidas
      await tester.ensureVisible(find.text('- Salidas'));
      await tester.tap(find.text('- Salidas'));
      await tester.pump();
      expect(find.text('Compra escolar'), findsNothing);
      expect(find.text('Canje de descuento'), findsOneWidget);
    });

    testWidgets('Apertura de RewardReviewModal cuando cliente tiene recompensa pendiente', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient();

      final pendingReward = ClientRewardModel(
        id: 1,
        negocioId: 1,
        clienteId: 10,
        metaId: 1,
        puntosConsumidos: 50,
        estado: 'PENDIENTE_REVISION',
        tipoBeneficio: 'DESCUENTO_MONTO',
        valorBeneficio: 20.0,
        tituloRecompensa: 'Vale S/ 20.00 en Útiles',
        fechaDesbloqueo: '2026-11-06 10:00:00',
      );

      await tester.pumpWidget(_buildTestApp(
        child: Scaffold(
          body: ClientLoyaltyHistoryModal(
            client: client,
            autoLoadHistory: false,
            initialMovements: const [],
            initialPendingRewards: [pendingReward],
          ),
        ),
        trackingProv: trackingProv,
        authProv: mockAuth,
        quickProv: quickProv,
      ));
      await tester.pump();

      // Verificar banner de premio pendiente
      expect(find.text('Premio pendiente de revisión'), findsOneWidget);
      expect(find.text('Vale S/ 20.00 en Útiles'), findsOneWidget);

      // Pulsar botón Revisar
      final reviewBtn = find.text('Revisar');
      expect(reviewBtn, findsOneWidget);
      await tester.tap(reviewBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verificar que abre RewardReviewModal
      expect(find.byType(RewardReviewModal), findsOneWidget);
    });
  });
}
