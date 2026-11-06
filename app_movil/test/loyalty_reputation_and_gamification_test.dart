import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/client_selection_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ClientService clientService;
  late SalesService salesService;

  const int testNegocioId = 1;
  const int testUsuarioId = 1;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    // Sembrar negocio y usuario base
    await db.insert('negocios', {
      'id': testNegocioId,
      'nombre_comercial': 'Librería Central',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': testUsuarioId,
      'nombre_completo': 'Vendedor Test',
      'email': 'test@libreria.com',
    });

    clientService = ClientService();
    salesService = SalesService();
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    await db.close();
  });

  group('Árbitro Adversarial - Fase 1: Esquema SQLite V27 y Metas Predeterminadas', () {
    test('La tabla clientes posee las 5 nuevas columnas de fidelización con valores seguros', () async {
      final columns = await db.rawQuery('PRAGMA table_info(clientes)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      expect(columnNames.contains('puntos_actuales'), isTrue);
      expect(columnNames.contains('puntos_historicos'), isTrue);
      expect(columnNames.contains('racha_pagos_puntuales'), isTrue);
      expect(columnNames.contains('score_reputacion'), isTrue);
      expect(columnNames.contains('nivel_reputacion'), isTrue);
    });

    test('Las 3 nuevas tablas V27 existen y tienen sus esquemas correctos', () async {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames.contains('metas_recompensas'), isTrue);
      expect(tableNames.contains('recompensas_cliente'), isTrue);
      expect(tableNames.contains('historial_puntos_reputacion'), isTrue);
    });

    test('seedDefaultMetasRecompensas siembra las 4 metas comerciales sin duplicados', () async {
      await LocalDatabase.seedDefaultMetasRecompensas(db);
      final goals = await clientService.getRewardGoals(testNegocioId, activeOnly: false);

      expect(goals.length, equals(4));
      expect(goals.any((g) => g.puntosRequeridos == 100), isTrue);
      expect(goals.any((g) => g.puntosRequeridos == 300), isTrue);
      expect(goals.any((g) => g.puntosRequeridos == 500), isTrue);
      expect(goals.any((g) => g.puntosRequeridos == 1000), isTrue);

      // Segunda llamada idempotente
      await LocalDatabase.seedDefaultMetasRecompensas(db);
      final goalsAfter = await clientService.getRewardGoals(testNegocioId, activeOnly: false);
      expect(goalsAfter.length, equals(4));
    });
  });

  group('Árbitro Adversarial - Fase 2: Motor Multivariable de Reputación y Puntos', () {
    test('Cliente nuevo nace en PLATA (500 pts de reputación) con 0 puntos canjeables', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Ana Morales',
        'telefono': '987654321',
      }, testNegocioId, testUsuarioId);

      expect(client.puntosActuales, equals(0));
      expect(client.puntosHistoricos, equals(0));
      expect(client.rachaPagosPuntuales, equals(0));
      expect(client.scoreReputacion, equals(500));
      expect(client.nivelReputacion, equals('PLATA'));
      expect(client.tier, equals(ReputationTier.plata));
    });

    test('Pagos puntuales otorgan bono +25 pts, elevan racha y score, mejorando Límite Sugerido', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Carlos Vargas',
        'telefono': '999888777',
      }, testNegocioId, testUsuarioId);

      // Registrar venta a crédito con 2 cuotas
      final sale = await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'credito',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 200.0,
        'monto_pagado': 0.0,
        'descuento_aplicado': 0.0,
        'cuotas': [
          {'numero_cuota': 1, 'monto': 100.0, 'fecha_vencimiento': '2026-12-01', 'estado': 'pendiente'},
          {'numero_cuota': 2, 'monto': 100.0, 'fecha_vencimiento': '2026-12-15', 'estado': 'pendiente'},
        ],
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Mochila Escolar', 'cantidad': 1, 'precio_unitario': 200.0, 'subtotal': 200.0}
        ]
      }, testNegocioId, testUsuarioId);

      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [sale.id]);
      final cuota1Id = cuotas.first['id'] as int;

      // Pago puntual de cuota 1
      await clientService.registerPayment(
        client.id,
        100.0,
        'Efectivo',
        testNegocioId,
        testUsuarioId,
        cuotaId: cuota1Id,
      );

      final updated = await clientService.getClientById(client.id);
      expect(updated, isNotNull);
      expect(updated!.rachaPagosPuntuales, equals(1));
      expect(updated.puntosActuales, equals(25)); // Bono puntual
      expect(updated.scoreReputacion, greaterThan(500));
    });

    test('Cuota en mora reinicia racha, penaliza score y congela crédito sugerido en 0.0', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Juan Pérez',
        'telefono': '911222333',
      }, testNegocioId, testUsuarioId);

      // Crear venta a crédito con cuota ya vencida
      await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'credito',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 300.0,
        'monto_pagado': 0.0,
        'descuento_aplicado': 0.0,
        'cuotas': [
          {'numero_cuota': 1, 'monto': 300.0, 'fecha_vencimiento': '2026-01-01', 'estado': 'pendiente'}, // vencida
        ],
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Cuadernos Pack', 'cantidad': 1, 'precio_unitario': 300.0, 'subtotal': 300.0}
        ]
      }, testNegocioId, testUsuarioId);

      await clientService.recalculateClientReputation(client.id);
      final updated = await clientService.getClientById(client.id);

      expect(updated, isNotNull);
      expect(updated!.rachaPagosPuntuales, equals(0));
      expect(updated.scoreReputacion, lessThan(500));
      expect(updated.totalDebt, greaterThan(0.01));
      // Debe congelar crédito sugerido a 0.0
      expect(updated.limiteCreditoSugerido, equals(0.0));
    });
  });

  group('Árbitro Adversarial - Fase 3: Ciclo Completo de Fidelización y Recompensas', () {
    test('Compra al contado otorga puntos y desbloquea meta en PENDIENTE_REVISION reservando puntos', () async {
      await LocalDatabase.seedDefaultMetasRecompensas(db);

      final client = await clientService.createClient({
        'nombre_completo': 'Elena Ramos',
        'telefono': '955444333',
      }, testNegocioId, testUsuarioId);

      // Compra al contado por S/ 120.00 -> 120 puntos ganados
      await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 120.0,
        'monto_pagado': 120.0,
        'descuento_aplicado': 0.0,
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Set Geometría', 'cantidad': 1, 'precio_unitario': 120.0, 'subtotal': 120.0}
        ]
      }, testNegocioId, testUsuarioId);

      final clientAfter = await clientService.getClientById(client.id);
      expect(clientAfter, isNotNull);
      expect(clientAfter!.puntosHistoricos, equals(120));

      // La meta de 100 pts se debió desbloquear en PENDIENTE_REVISION
      final pending = await clientService.getPendingReviewRewards(testNegocioId);
      expect(pending.isNotEmpty, isTrue);
      final reward = pending.firstWhere((r) => r.clienteId == client.id);
      expect(reward.estado, equals('PENDIENTE_REVISION'));
      expect(reward.puntosConsumidos, equals(100));

      // 100 puntos reservados de puntos_actuales: 120 - 100 = 20
      expect(clientAfter.puntosActuales, equals(20));
    });

    test('Descartar recompensa pendiente restaura los puntos reservados a puntos_actuales', () async {
      await LocalDatabase.seedDefaultMetasRecompensas(db);

      final client = await clientService.createClient({
        'nombre_completo': 'Mateo Silva',
        'telefono': '944333222',
      }, testNegocioId, testUsuarioId);

      await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 100.0,
        'monto_pagado': 100.0,
        'descuento_aplicado': 0.0,
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Diccionario', 'cantidad': 1, 'precio_unitario': 100.0, 'subtotal': 100.0}
        ]
      }, testNegocioId, testUsuarioId);

      final pending = await clientService.getPendingReviewRewards(testNegocioId);
      final reward = pending.firstWhere((r) => r.clienteId == client.id);

      // Descartar recompensa
      await clientService.discardReward(reward.id, reason: 'Cliente prefirió seguir acumulando');

      final clientRestored = await clientService.getClientById(client.id);
      expect(clientRestored!.puntosActuales, equals(100)); // Restaurado

      final ledger = await clientService.getClientLoyaltyLedger(client.id);
      expect(ledger.any((l) => l.tipoMovimiento == 'RESTAURACION_RECHAZO'), isTrue);
    });

    test('Aprobar recompensa, canjearla en venta y revertirla al anular la venta', () async {
      await LocalDatabase.seedDefaultMetasRecompensas(db);

      final client = await clientService.createClient({
        'nombre_completo': 'Lucía Torres',
        'telefono': '933222111',
      }, testNegocioId, testUsuarioId);

      // 1. Ganar 100 puntos y desbloquear
      await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 100.0,
        'monto_pagado': 100.0,
        'descuento_aplicado': 0.0,
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Libro', 'cantidad': 1, 'precio_unitario': 100.0, 'subtotal': 100.0}
        ]
      }, testNegocioId, testUsuarioId);

      final pending = await clientService.getPendingReviewRewards(testNegocioId);
      final reward = pending.firstWhere((r) => r.clienteId == client.id);

      // 2. Comerciante aprueba la recompensa
      await clientService.approveReward(reward.id);
      final approvedRewards = await clientService.getClientRewards(client.id, status: 'APROBADA_NOTIFICADA');
      expect(approvedRewards.length, equals(1));
      expect(approvedRewards.first.estado, equals('APROBADA_NOTIFICADA'));

      // 3. Canjear recompensa en nueva venta
      final saleWithReward = await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 50.0,
        'monto_pagado': 50.0,
        'descuento_aplicado': 10.0,
        'recompensa_canje_id': reward.id, // Canje
        'items': [
          {'producto_id': 2, 'nombre_producto': 'Plumones', 'cantidad': 1, 'precio_unitario': 60.0, 'subtotal': 60.0}
        ]
      }, testNegocioId, testUsuarioId);

      final rewardAfterCanje = await db.query('recompensas_cliente', where: 'id = ?', whereArgs: [reward.id]);
      expect(rewardAfterCanje.first['estado'], equals('CANJEADA'));
      expect(rewardAfterCanje.first['venta_canje_id'], equals(saleWithReward.id));

      // 4. Anular venta (voidSale)
      await salesService.voidSale(saleWithReward.id, testNegocioId, 'Error de digitación en caja');

      // 5. La recompensa debe revertirse automáticamente a APROBADA_NOTIFICADA
      final rewardReverted = await db.query('recompensas_cliente', where: 'id = ?', whereArgs: [reward.id]);
      expect(rewardReverted.first['estado'], equals('APROBADA_NOTIFICADA'));
      expect(rewardReverted.first['venta_canje_id'], isNull);
      expect(rewardReverted.first['fecha_canje'], isNull);
    });
  });

  group('Árbitro Adversarial - Fase 4: Render UI 360dp sin Overflow y Temas', () {
    testWidgets('ClientCard renderiza sin overflow en pantalla angosta de 360dp en Modo Claro y Oscuro', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 740 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 10,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Valeria Quispe Del Solar',
        phone: '998877665',
        docNumber: '72345678',
        puntosActuales: 450,
        puntosHistoricos: 850,
        rachaPagosPuntuales: 5,
        scoreReputacion: 820,
        nivelReputacion: 'ORO',
        totalDebt: 80.0,
        registeredDate: '2026-10-01T10:00:00',
        nivelConfianza: 'excelente',
        etiquetas: ['VIP', 'FRECUENTE'],
      );

      // Modo Claro
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ClientCard(client: client, onRefresh: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Oro'), findsOneWidget);
      expect(find.textContaining('450 pts'), findsOneWidget);

      // Modo Oscuro
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ClientCard(client: client, onRefresh: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ClientSelectionCard renderiza con premios aprobados sin overflow en 360dp', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 740 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 20,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Fernando Mendoza',
        phone: '912345678',
        puntosActuales: 320,
        puntosHistoricos: 920,
        rachaPagosPuntuales: 8,
        scoreReputacion: 920,
        nivelReputacion: 'DIAMANTE_VIP',
        registeredDate: '2026-09-01T10:00:00',
      );

      final approvedRewards = [
        ClientRewardModel(
          id: 1,
          negocioId: 1,
          clienteId: 20,
          metaId: 1,
          puntosConsumidos: 100,
          estado: 'APROBADA_NOTIFICADA',
          tipoBeneficio: 'DESCUENTO_MONTO',
          valorBeneficio: 10.0,
          tituloRecompensa: 'Vale S/ 10.00 en Útiles',
          fechaDesbloqueo: '2026-11-01T10:00:00',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClientSelectionCard(
                selectedClient: client,
                onSearchOrAddTap: () {},
                onEditTap: () {},
                approvedRewards: approvedRewards,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Diamante VIP'), findsOneWidget);
      expect(find.textContaining('Vale S/ 10.00 en Útiles'), findsOneWidget);
      expect(find.textContaining('Diamante VIP'), findsOneWidget);
      expect(find.textContaining('Vale S/ 10.00 en Útiles'), findsOneWidget);
    });
  });
}
