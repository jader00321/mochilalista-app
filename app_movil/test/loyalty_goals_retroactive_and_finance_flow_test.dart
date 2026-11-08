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
import 'package:app_movil/features/smart_quotation/widgets/crm/client_stats_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';

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

class _TestTrackingProvider extends TrackingProvider {
  List<SaleModel> _customDebts = [];

  void setCustomDebts(List<SaleModel> debts) {
    _customDebts = debts;
    notifyListeners();
  }

  @override
  List<SaleModel> get currentClientDebts => _customDebts;
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
        value: trackingProv ?? _TestTrackingProvider(),
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
        child: Material(child: child),
      ),
    ),
  );
}

ClientModel _createTestClient({
  int id = 10,
  int negocioId = 1,
  int creadoPorUsuarioId = 1,
  String fullName = 'Jj',
  String phone = '922836879',
  int puntosActuales = 50,
  int puntosHistoricos = 50,
  int scoreReputacion = 370,
  String nivelReputacion = 'BRONCE',
  double saldoAFavor = 0.0,
  int rachaPagosPuntuales = 0,
  String registeredDate = '2026-11-01',
}) {
  return ClientModel(
    id: id,
    negocioId: negocioId,
    creadoPorUsuarioId: creadoPorUsuarioId,
    fullName: fullName,
    phone: phone,
    puntosActuales: puntosActuales,
    puntosHistoricos: puntosHistoricos,
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
  late _TestTrackingProvider trackingProv;
  late QuickSaleProvider quickProv;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    mockAuth = _MockAuthProvider();
    trackingProv = _TestTrackingProvider();
    quickProv = QuickSaleProvider();

    // Limpiar borradores residuales entre tests
    for (int i = 1; i <= 300; i++) {
      ClientFinanceDraftManager.instance.clearLoanDraft(i);
      ClientFinanceDraftManager.instance.clearWithdrawDraft(i);
      ClientFinanceDraftManager.instance.setActiveTab(i, 0);
    }

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
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase 1: Evaluación Retroactiva Inteligente de Metas', () {
    test('evaluateAllClientsForActiveGoals desbloquea meta de 50 pts para cliente con 50 pts', () async {
      final clientService = ClientService();

      // Insertar cliente Jj con 50 pts
      await db.insert('clientes', {
        'id': 100,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'nombre_completo': 'Jj',
        'telefono': '922836879',
        'puntos_actuales': 50,
        'puntos_historicos': 50,
        'score_reputacion': 370,
        'nivel_reputacion': 'BRONCE',
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Crear nueva meta "ganador" de 50 pts
      final metaId = await db.insert('metas_recompensas', {
        'negocio_id': 1,
        'nombre': 'ganador',
        'descripcion': 'Producto de Regalo S/ 10.00',
        'puntos_requeridos': 50,
        'tipo_beneficio': 'PRODUCTO_REGALO',
        'valor_beneficio': 10.0,
        'activo': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(metaId, greaterThan(0));

      // Ejecutar evaluación retroactiva
      final unlocked = await clientService.evaluateAllClientsForActiveGoals(1, usuarioId: 1);
      expect(unlocked.length, equals(1));
      expect(unlocked.first.clienteId, equals(100));
      expect(unlocked.first.metaId, equals(metaId));

      // Verificar que se haya creado la recompensa en PENDIENTE_REVISION
      final rewards = await db.query(
        'recompensas_cliente',
        where: 'cliente_id = ? AND meta_id = ?',
        whereArgs: [100, metaId],
      );
      expect(rewards.length, equals(1));
      expect(rewards.first['estado'], equals('PENDIENTE_REVISION'));
      expect(rewards.first['puntos_consumidos'], equals(50));

      // Re-evaluar: no debe generar duplicados
      final secondRun = await clientService.evaluateAllClientsForActiveGoals(1, usuarioId: 1);
      expect(secondRun.isEmpty, isTrue);

      final rewardsAfter = await db.query(
        'recompensas_cliente',
        where: 'cliente_id = ? AND meta_id = ?',
        whereArgs: [100, metaId],
      );
      expect(rewardsAfter.length, equals(1));
    });

    test('getClientsAlmostAtGoal excluye estrictamente clientes con 0 pts o menos del 50%', () async {
      final clientService = ClientService();

      // Cliente Freddy con 0 pts
      await db.insert('clientes', {
        'id': 101,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'nombre_completo': 'Freddy',
        'telefono': '910888652',
        'puntos_actuales': 0,
        'puntos_historicos': 0,
        'score_reputacion': 180,
        'nivel_reputacion': 'OBSERVACION',
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Cliente Huk con 0 pts
      await db.insert('clientes', {
        'id': 102,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'nombre_completo': 'Huk',
        'telefono': '000000000',
        'puntos_actuales': 0,
        'puntos_historicos': 0,
        'score_reputacion': 500,
        'nivel_reputacion': 'PLATA',
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Cliente Carlos con 20 pts (40% de 50 pts -> progreso < 50%, no entra)
      await db.insert('clientes', {
        'id': 103,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'nombre_completo': 'Carlos',
        'telefono': '999111222',
        'puntos_actuales': 20,
        'puntos_historicos': 20,
        'score_reputacion': 450,
        'nivel_reputacion': 'BRONCE',
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Cliente Ana con 35 pts (70% de 50 pts -> progreso >= 50%, SÍ entra)
      await db.insert('clientes', {
        'id': 104,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'nombre_completo': 'Ana',
        'telefono': '988333444',
        'puntos_actuales': 35,
        'puntos_historicos': 35,
        'score_reputacion': 600,
        'nivel_reputacion': 'PLATA',
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Meta de 50 pts
      await db.insert('metas_recompensas', {
        'negocio_id': 1,
        'nombre': 'ganador',
        'descripcion': 'Producto de Regalo S/ 10.00',
        'puntos_requeridos': 50,
        'tipo_beneficio': 'PRODUCTO_REGALO',
        'valor_beneficio': 10.0,
        'activo': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final almostList = await clientService.getClientsAlmostAtGoal(1);

      // Freddy (0 pts) y Huk (0 pts) NO deben estar en Casi en la Meta
      final freddyMatch = almostList.where((m) => (m['client'] as ClientModel).id == 101);
      final hukMatch = almostList.where((m) => (m['client'] as ClientModel).id == 102);
      expect(freddyMatch.isEmpty, isTrue, reason: 'Freddy con 0 pts no debe estar en Casi en la Meta');
      expect(hukMatch.isEmpty, isTrue, reason: 'Huk con 0 pts no debe estar en Casi en la Meta');

      // Carlos (20 pts = 40%) NO debe estar
      final carlosMatch = almostList.where((m) => (m['client'] as ClientModel).id == 103);
      expect(carlosMatch.isEmpty, isTrue, reason: 'Carlos con 40% no debe estar en Casi en la Meta');

      // Ana (35 pts = 70%) SÍ debe estar
      final anaMatch = almostList.where((m) => (m['client'] as ClientModel).id == 104);
      expect(anaMatch.isNotEmpty, isTrue, reason: 'Ana con 70% debe estar en Casi en la Meta');
      expect(anaMatch.first['puntos_faltantes'], equals(15));
    });
  });

  group('Fase 2: Blindaje de Kardex y Botón + Préstamo en 360dp', () {
    testWidgets('ClientLoyaltyHistoryModal abre sin TypeError y renderiza Kardex', (tester) async {
      final client = _createTestClient(id: 100, puntosActuales: 50);

      await tester.pumpWidget(
        _buildTestApp(
          trackingProv: trackingProv,
          authProv: mockAuth,
          quickProv: quickProv,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                ClientLoyaltyHistoryModal.show(
                  ctx,
                  client: client,
                );
              },
              child: const Text('Abrir Historial'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Historial'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que se abrió el modal y no hubo grey screen de TypeError
      expect(find.byType(ClientLoyaltyHistoryModal), findsOneWidget);
      expect(find.text('Jj'), findsOneWidget);
      expect(find.textContaining('50 pts'), findsWidgets);
    });

    testWidgets('ClientStatsHeader muestra botón + Préstamo completo en 360dp', (tester) async {
      final client = _createTestClient(id: 100, fullName: 'Jj');

      await tester.pumpWidget(
        _buildTestApp(
          size: const Size(360, 800),
          trackingProv: trackingProv,
          authProv: mockAuth,
          child: ClientStatsHeader(
            client: client,
            isDark: true,
            onWhatsAppTap: () {},
            onCallTap: () {},
            onGoToQuickSale: () {},
            onFinanceActionCompleted: () {},
          ),
        ),
      );
      await tester.pump();

      // Verificar que no dice "+ Prést..." truncado, sino "+ Préstamo"
      expect(find.text('+ Préstamo'), findsOneWidget);
      expect(find.textContaining('+ Prést...'), findsNothing);
    });
  });

  group('Fase 3 y 4: Tarjeta Contextual y Modal de Operaciones Financieras', () {
    testWidgets('ClientFinanceActionsModal en Tab 0 muestra alerta de mora activa si hay cuotas vencidas', (tester) async {
      final client = _createTestClient(id: 100, fullName: 'Jj');

      // Simular que el cliente tiene una deuda con cuota vencida
      final overdueInstallment = InstallmentModel(
        id: 1,
        installmentNumber: 1,
        dueDate: '2026-10-15', // Fecha pasada respecto a noviembre 2026
        amount: 200.0,
        montoPagado: 0.0,
        status: 'pendiente',
      );

      final saleWithDebt = SaleModel(
        id: 50,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientId: 100,
        discount: 0.0,
        paymentMethod: 'CREDITO',
        paymentStatus: 'PENDIENTE',
        deliveryStatus: 'ENTREGADO',
        totalAmount: 200.0,
        paidAmount: 0.0,
        saleDate: '2026-10-01',
        installments: [overdueInstallment],
      );

      trackingProv.setCustomDebts([saleWithDebt]);

      await tester.pumpWidget(
        _buildTestApp(
          size: const Size(360, 800),
          trackingProv: trackingProv,
          authProv: mockAuth,
          child: ClientFinanceActionsModal(
            client: client,
            isDark: true,
            initialTab: 0,
          ),
        ),
      );
      await tester.pump();

      // Debe detectar la cuota vencida y mostrar el límite congelado en S/ 0.00
      expect(find.textContaining('Límite Congelado: S/ 0.00 (Mora Activa)'), findsOneWidget);
      expect(find.textContaining('cuota vencida'), findsOneWidget);
      // Cero emojis Unicode en la tarjeta de mora (usa Icons.warning_amber_rounded)
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
    });

    testWidgets('ClientFinanceActionsModal en Tab 1 reacciona al monto a retirar', (tester) async {
      final client = _createTestClient(id: 100, fullName: 'Jj', saldoAFavor: 150.0);

      await tester.pumpWidget(
        _buildTestApp(
          size: const Size(360, 800),
          trackingProv: trackingProv,
          authProv: mockAuth,
          child: ClientFinanceActionsModal(
            client: client,
            isDark: true,
            initialTab: 1,
          ),
        ),
      );
      await tester.pump();

      // Inicialmente sin monto ingresado
      expect(find.textContaining('Saldo a Favor Disponible: S/ 150.00'), findsWidgets);

      // Escribir monto válido (S/ 50.00)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '50.00');
      await tester.pump();

      expect(find.textContaining('Retiro Válido: S/ 50.00'), findsOneWidget);
      expect(find.textContaining('nuevo saldo a favor de Jj será de S/ 100.00'), findsOneWidget);

      // Escribir monto que supera el saldo (S/ 200.00)
      await tester.enterText(textFields.first, '200.00');
      await tester.pump();

      expect(find.textContaining('Monto Excede el Saldo Disponible'), findsOneWidget);
    });
  });

  group('Fase 5: Anti-Colisión y Ocultamiento de +1d en Cuotas Pagadas', () {
    testWidgets('Cronograma oculta botón +1d cuando la cuota está totalmente pagada', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 1200 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = _createTestClient(id: 205, fullName: 'Pedro');

      // Pre-cargar borrador con fraccionamiento activo y 1 cuota pagada
      ClientFinanceDraftManager.instance.setLoanDraft(
        205,
        FinanceLoanDraft(
          amount: '200.00',
          splitInQuotas: true,
          numCuotas: '2',
          installments: [
            InstallmentModel(
              installmentNumber: 1,
              dueDate: '2026-11-20',
              amount: 100.0,
              montoPagado: 100.0, // Totalmente pagada -> +1d DEBE OCULTARSE
              status: 'pagado',
            ),
            InstallmentModel(
              installmentNumber: 2,
              dueDate: '2026-12-20',
              amount: 100.0,
              montoPagado: 0.0, // Pendiente -> +1d DEBE MOSTRARSE
              status: 'pendiente',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          trackingProv: trackingProv,
          authProv: mockAuth,
          child: Scaffold(
            body: ClientFinanceActionsModal(
              client: client,
              isDark: true,
              initialTab: 0,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll hacia abajo para ubicar el cronograma
      await tester.drag(find.text('Registrar Préstamo o Venta al Fiado'), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 100));

      // Cuota 1 (pagada) NO tiene +1d. Cuota 2 (pendiente) SÍ tiene +1d.
      // Por ende, debe haber exactamente 1 widget "+1d" en pantalla.
      expect(find.text('+1d'), findsOneWidget);
      expect(find.text('Pagada'), findsOneWidget);
    });
  });
}
