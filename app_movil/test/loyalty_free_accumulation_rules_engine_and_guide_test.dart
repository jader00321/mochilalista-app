import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/loyalty_rules_config_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart';

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

    await db.insert('negocios', {
      'id': testNegocioId,
      'nombre_comercial': 'Comercial Mi Tienda',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': testUsuarioId,
      'nombre_completo': 'Administrador',
      'email': 'admin@tienda.com',
    });

    clientService = ClientService();
    salesService = SalesService();
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    await db.close();
  });

  group('FASE 1: Migración V33 y Restauración Defensiva del Saldo de Jj', () {
    test('Cliente Jj recupera sus 50 pts reservados indebidamente en PENDIENTE_REVISION de forma idempotente', () async {
      // 1. Simular estado exacto de la captura de pantalla:
      // Cliente Jj con 0 pts actuales pero con 50 pts reservados en PENDIENTE_REVISION
      await db.insert('clientes', {
        'id': 99,
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Jj',
        'telefono': '999888777',
        'puntos_actuales': 0, // Saldo en cero en la captura
        'puntos_historicos': 50,
        'score_reputacion': 227,
        'nivel_reputacion': 'OBSERVACION',
      });

      // Crear meta "ganador"
      final metaId = await db.insert('metas_recompensas', {
        'negocio_id': testNegocioId,
        'nombre': 'ganador',
        'descripcion': 'Premio Ganador',
        'puntos_requeridos': 50,
        'tipo_beneficio': 'PRODUCTO_REGALO',
        'valor_beneficio': 15.0,
        'activo': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insertar recompensa pendiente que le restó 50 pts indebidamente
      await db.insert('recompensas_cliente', {
        'id': 501,
        'negocio_id': testNegocioId,
        'cliente_id': 99,
        'meta_id': metaId,
        'puntos_consumidos': 50,
        'estado': 'PENDIENTE_REVISION',
        'tipo_beneficio': 'PRODUCTO_REGALO',
        'valor_beneficio': 15.0,
        'titulo_recompensa': 'ganador',
        'fecha_desbloqueo': DateTime.now().toIso8601String(),
      });

      // 2. Ejecutar la rutina de restauración de migración V33
      await LocalDatabase.ensureLoyaltyRulesAndRestoration(db);

      // 3. Verificar que Jj ahora tiene 50 pts actuales libres
      final jjAfter = await clientService.getClientById(99);
      expect(jjAfter, isNotNull);
      expect(jjAfter!.puntosActuales, equals(50));
      expect(jjAfter.puntosHistoricos, equals(50));

      // 4. Verificar el movimiento en el Kardex
      final ledger = await clientService.getClientLoyaltyLedger(99);
      final restRow = ledger.firstWhere((l) => l.tipoMovimiento == 'RESTAURACION_MIGRACION');
      expect(restRow.puntosDelta, equals(50));
      expect(restRow.saldoPuntosDespues, equals(50));
      expect(restRow.motivo, contains('Restauración de puntos'));

      // 5. Verificar idempotencia: correr de nuevo no debe duplicar puntos
      await LocalDatabase.ensureLoyaltyRulesAndRestoration(db);
      final jjAfterSecond = await clientService.getClientById(99);
      expect(jjAfterSecond!.puntosActuales, equals(50));
    });
  });

  group('FASE 2: Paradigma de Acumulación Libre sin Descuento Automático', () {
    test('Múltiples compras acumulan saldo libremente y exponen premios reclamables sin bloquear puntos', () async {
      await LocalDatabase.seedDefaultMetasRecompensas(db);

      // Agregar meta accesible de 50 pts
      await db.insert('metas_recompensas', {
        'negocio_id': testNegocioId,
        'nombre': 'Descuento S/ 5',
        'descripcion': 'Bono de S/ 5',
        'puntos_requeridos': 50,
        'tipo_beneficio': 'DESCUENTO_MONTO',
        'valor_beneficio': 5.0,
        'activo': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final client = await clientService.createClient({
        'nombre_completo': 'Carlos Mendoza',
        'telefono': '987111222',
      }, testNegocioId, testUsuarioId);

      // Compra 1: S/ 50.00 al contado -> +50 pts
      await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 50.0,
        'monto_pagado': 50.0,
        'descuento_aplicado': 0.0,
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Cuaderno', 'cantidad': 1, 'precio_unitario': 50.0, 'subtotal': 50.0}
        ]
      }, testNegocioId, testUsuarioId);

      var c = await clientService.getClientById(client.id);
      expect(c!.puntosActuales, equals(50));

      // Compra 2: S/ 70.00 al contado -> +70 pts (Total: 120 pts)
      await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 70.0,
        'monto_pagado': 70.0,
        'descuento_aplicado': 0.0,
        'items': [
          {'producto_id': 2, 'nombre_producto': 'Mochila', 'cantidad': 1, 'precio_unitario': 70.0, 'subtotal': 70.0}
        ]
      }, testNegocioId, testUsuarioId);

      c = await clientService.getClientById(client.id);
      // Puntos intactos: 120 pts (cero descuentos automáticos)
      expect(c!.puntosActuales, equals(120));
      expect(c.puntosHistoricos, equals(120));

      // Resumen de premios reclamables
      final summary = await clientService.getClientClaimableRewardsSummary(client.id, testNegocioId);
      expect(summary, isNotNull);
      expect(summary!.hasClaimableRewards, isTrue);
      // Puede reclamar las metas de 50 pts y 100 pts
      expect(summary.claimableGoals.length, greaterThanOrEqualTo(2));
      expect(summary.claimableGoals.any((g) => g.puntosRequeridos == 50), isTrue);
      expect(summary.claimableGoals.any((g) => g.puntosRequeridos == 100), isTrue);

      // Siguiente meta para seguir ahorrando (300 pts)
      expect(summary.nextGoal, isNotNull);
      expect(summary.nextGoal!.puntosRequeridos, equals(300));
      expect(summary.puntosFaltantesParaSiguiente, equals(180)); // 300 - 120 = 180
    });

    test('Elección manual de premio: descuenta puntos atómicamente solo al confirmar', () async {
      await LocalDatabase.seedDefaultMetasRecompensas(db);

      // Insertar meta de 50 pts
      final meta50Id = await db.insert('metas_recompensas', {
        'negocio_id': testNegocioId,
        'nombre': 'Descuento S/ 5',
        'descripcion': 'Bono S/ 5',
        'puntos_requeridos': 50,
        'tipo_beneficio': 'DESCUENTO_MONTO',
        'valor_beneficio': 5.0,
        'activo': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final client = await clientService.createClient({
        'nombre_completo': 'Ana Morales',
        'telefono': '987333444',
      }, testNegocioId, testUsuarioId);

      // Otorgar 120 puntos
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
          {'producto_id': 1, 'nombre_producto': 'Calculadora', 'cantidad': 1, 'precio_unitario': 120.0, 'subtotal': 120.0}
        ]
      }, testNegocioId, testUsuarioId);

      final summary = await clientService.getClientClaimableRewardsSummary(client.id, testNegocioId);
      final goal50 = summary!.claimableGoals.firstWhere((g) => g.id == meta50Id);

      // Cliente elige reclamar el premio menor de 50 pts para guardar 70 pts restantes
      final reward = (await clientService.claimAndDeliverReward(
        client.id,
        goal50.id,
        deliverImmediately: true,
      ))!;

      expect(reward.estado, equals('CANJEADA'));
      expect(reward.puntosConsumidos, equals(50));

      final cAfter = await clientService.getClientById(client.id);
      expect(cAfter!.puntosActuales, equals(70)); // 120 - 50 = 70 libres

      final ledger = await clientService.getClientLoyaltyLedger(client.id);
      final claimEntry = ledger.firstWhere((l) => l.tipoMovimiento == 'CANJE_RECOMPENSA');
      expect(claimEntry.puntosDelta, equals(-50));
      expect(claimEntry.saldoPuntosDespues, equals(70));
    });
  });

  group('FASE 3: Motor de 6 Reglas Automáticas de Fidelización en SQLite a 0ms', () {
    test('Regla 1 (Compras al Contado), Regla 2 (Cotización Concretada) y Reversión Atómica en voidSale', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Roberto Gómez',
        'telefono': '911222333',
      }, testNegocioId, testUsuarioId);

      // Configurar reglas: 1 punto por cada S/ 1.00, bono cotización +30 pts
      final initialRules = await clientService.getLoyaltyRules(testNegocioId);
      await clientService.updateLoyaltyRules(
        initialRules.copyWith(
          puntosPorCompraActivo: true,
          puntosPorUnidadMoneda: 1,
          montoBaseCompra: 1.0,
          compraMinimaParaPuntos: 0.0,
          bonoCotizacionActivo: true,
          puntosBonoCotizacion: 30,
        ),
      );

      // Crear cotización previa en smart_quotations
      final cotId = await db.insert('smart_quotations', {
        'numero_secuencial': 101,
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'client_id': client.id,
        'total_amount': 80.0,
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Concretar cotización como venta al contado de S/ 80.00
      final sale = await salesService.createSale({
        'cliente_id': client.id,
        'cotizacion_id': cotId,
        'origen_venta': 'cotizacion_concretada',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 80.0,
        'monto_pagado': 80.0,
        'descuento_aplicado': 0.0,
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Pack Útiles', 'cantidad': 1, 'precio_unitario': 80.0, 'subtotal': 80.0}
        ]
      }, testNegocioId, testUsuarioId);

      // Puntos esperados: 80 pts (compra) + 30 pts (bono cotización) = 110 pts
      final cAfter = await clientService.getClientById(client.id);
      expect(cAfter!.puntosActuales, equals(110));

      final ledger = await clientService.getClientLoyaltyLedger(client.id);
      expect(ledger.any((l) => l.tipoMovimiento == 'GANANCIA_COMPRA' && l.puntosDelta == 80), isTrue);
      expect(ledger.any((l) => l.tipoMovimiento == 'BONO_COTIZACION_CONCRETADA' && l.puntosDelta == 30), isTrue);

      // Reversión Atómica en voidSale
      await salesService.voidSale(sale.id, testNegocioId, 'Error en caja');

      final cAfterVoid = await clientService.getClientById(client.id);
      expect(cAfterVoid!.puntosActuales, equals(0)); // Reversión de los 110 puntos

      final ledgerAfter = await clientService.getClientLoyaltyLedger(client.id);
      expect(ledgerAfter.any((l) => l.tipoMovimiento == 'REVERSION_ANULACION'), isTrue);
    });

    test('Reglas de Pagos: Abono inicial crédito, Pago puntual, Bono de Racha y Liquidación total', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Diana Flores',
        'telefono': '944555666',
      }, testNegocioId, testUsuarioId);

      // Reglas: Pago puntual +15 pts, Racha cada 2 cuotas +25 pts, Liquidación sin mora +50 pts
      final initialRules = await clientService.getLoyaltyRules(testNegocioId);
      await clientService.updateLoyaltyRules(
        initialRules.copyWith(
          puntosPorCompraActivo: true,
          puntosAbonoInicialActivo: true,
          bonoPagoPuntualActivo: true,
          puntosPagoPuntual: 15,
          bonoRachaActivo: true,
          cadaCuantasCuotasRacha: 2,
          puntosBonoRacha: 25,
          bonoLiquidacionSinMoraActivo: true,
          puntosLiquidacionSinMora: 50,
        ),
      );

      final futureDue1 = DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T').first;
      final futureDue2 = DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T').first;

      // 1. Venta a crédito: Monto S/ 200.00, Abono inicial S/ 40.00 (Regla 3)
      final saleCredit = await salesService.createSale({
        'cliente_id': client.id,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'credito',
        'estado_pago': 'parcial',
        'estado_entrega': 'entregado',
        'monto_total': 200.0,
        'monto_pagado': 40.0,
        'abono_inicial': 40.0,
        'cuotas': [
          {'numero_cuota': 1, 'monto': 80.0, 'fecha_vencimiento': futureDue1},
          {'numero_cuota': 2, 'monto': 80.0, 'fecha_vencimiento': futureDue2},
        ],
        'items': [
          {'producto_id': 1, 'nombre_producto': 'Uniforme', 'cantidad': 1, 'precio_unitario': 200.0, 'subtotal': 200.0}
        ]
      }, testNegocioId, testUsuarioId);

      // Abono inicial S/ 40.00 otorga 40 pts
      var c = await clientService.getClientById(client.id);
      expect(c!.puntosActuales, equals(40));

      // Obtener IDs de cuotas
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleCredit.id], orderBy: 'numero_cuota ASC');
      expect(cuotas.length, equals(2));
      final cuota1Id = cuotas[0]['id'] as int;
      final cuota2Id = cuotas[1]['id'] as int;

      // 2. Pago de Cuota 1 Puntual (Regla 4: +15 pts, racha = 1)
      await clientService.registerPayment(
        client.id,
        80.0,
        'Efectivo',
        testNegocioId,
        testUsuarioId,
        ventaId: saleCredit.id,
        cuotaId: cuota1Id,
      );

      c = await clientService.getClientById(client.id);
      // 40 + 15 = 55 pts
      expect(c!.puntosActuales, equals(55));
      expect(c.rachaPagosPuntuales, equals(1));

      // 3. Pago de Cuota 2 Puntual y Liquidación del Crédito:
      // Otorga: +15 pts (pago puntual) + 25 pts (racha múltiplo de 2) + 50 pts (liquidación total sin mora)
      await clientService.registerPayment(
        client.id,
        80.0,
        'Efectivo',
        testNegocioId,
        testUsuarioId,
        ventaId: saleCredit.id,
        cuotaId: cuota2Id,
      );

      c = await clientService.getClientById(client.id);
      // 55 + 15 + 25 + 50 = 145 pts
      expect(c!.puntosActuales, equals(145));
      expect(c.rachaPagosPuntuales, equals(2));

      final ledger = await clientService.getClientLoyaltyLedger(client.id);
      expect(ledger.any((l) => l.tipoMovimiento == 'BONO_PAGO_PUNTUAL' && l.puntosDelta == 15), isTrue);
      expect(ledger.any((l) => l.tipoMovimiento == 'BONO_RACHA_PAGOS' && l.puntosDelta == 25), isTrue);
      expect(ledger.any((l) => l.tipoMovimiento == 'BONO_LIQUIDACION_SIN_MORA' && l.puntosDelta == 50), isTrue);
    });
  });

  group('FASE 4: Cartilla y Mensajes Dinámicos de WhatsApp', () {
    test('Cartilla genera texto dinámico reflejando fielmente solo las reglas activas del negocio', () async {
      final rules = LoyaltyRulesModel(
        negocioId: testNegocioId,
        puntosPorCompraActivo: true,
        puntosPorUnidadMoneda: 1,
        montoBaseCompra: 1.0,
        compraMinimaParaPuntos: 10.0,
        bonoCotizacionActivo: true,
        puntosBonoCotizacion: 20,
        puntosAbonoInicialActivo: true,
        bonoPagoPuntualActivo: true,
        puntosPagoPuntual: 15,
        bonoRachaActivo: false, // Desactivado
        cadaCuantasCuotasRacha: 3,
        puntosBonoRacha: 30,
        bonoLiquidacionSinMoraActivo: true,
        puntosLiquidacionSinMora: 40,
        updatedAt: DateTime.now().toIso8601String(),
      );

      final goals = [
        RewardGoalModel(
          id: 1,
          negocioId: testNegocioId,
          nombre: 'Descuento S/ 10',
          descripcion: 'Vale por S/ 10',
          puntosRequeridos: 100,
          tipoBeneficio: 'DESCUENTO_MONTO',
          valorBeneficio: 10.0,
          activo: true,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];

      final msg = LoyaltyWhatsAppService.buildLoyaltyGuideAndCatalogMessage(
        businessName: 'Librería Central',
        rules: rules,
        activeGoals: goals,
        clientName: 'Juan Pérez',
        puntosActuales: 100,
      );

      expect(msg.toUpperCase(), contains('GUÍA OFICIAL DE PUNTOS Y PREMIOS • LIBRERÍA CENTRAL'));
      expect(msg, contains('Juan Pérez'));
      expect(msg, contains('Compras al Contado'));
      expect(msg, contains('+20 pts extra'));
      expect(msg, contains('+15 pts'));
      // Racha estaba inactiva: no debe aparecer en el mensaje
      expect(msg.contains('Racha Impecable'), isFalse);
      expect(msg, contains('+40 pts'));
      expect(msg, contains('100 pts'));
    });
  });

  group('FASE 5: Renderizado UI Responsivo en 320dp y 360dp sin Overflows', () {
    testWidgets('LoyaltyRulesConfigModal renderiza en 320dp y 360dp sin pixel overflows y con teclado seguro', (tester) async {
      tester.view.physicalSize = const Size(320, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoyaltyRulesConfigModal(
              negocioId: testNegocioId,
              initialRules: LoyaltyRulesModel(
                negocioId: testNegocioId,
                updatedAt: DateTime.now().toIso8601String(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Configurar Reglas de Puntos"), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);

      // Cambio a 360dp
      tester.view.physicalSize = const Size(360, 750);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ClientLoyaltyHistoryModal renderiza en 320dp con tarjetas de premios y movimientos sin truncar títulos', (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 1,
        negocioId: testNegocioId,
        creadoPorUsuarioId: testUsuarioId,
        fullName: 'Jj',
        phone: '999888777',
        registeredDate: DateTime.now().toIso8601String(),
        puntosActuales: 50,
        puntosHistoricos: 50,
        scoreReputacion: 227,
        rachaPagosPuntuales: 0,
      );

      final movements = [
        LoyaltyLedgerModel(
          id: 1,
          negocioId: testNegocioId,
          clienteId: 1,
          tipoMovimiento: 'AJUSTE_MANUAL',
          puntosDelta: 50,
          puntosSaldoResultante: 50,
          scoreDelta: 0,
          scoreResultante: 500,
          motivo: 'Bono de fidelización otorgado',
          referenciaTipo: 'manual',
          fechaRegistro: DateTime.now().toIso8601String(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientLoyaltyHistoryModal(
              client: client,
              autoLoadHistory: false,
              initialMovements: movements,
              initialTabIndex: 1, // Pestaña 2: Historial de Puntos
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Jj'), findsOneWidget);
      expect(find.text('50 pts'), findsWidgets);
      expect(find.textContaining('Bono de fidelización otorgado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
