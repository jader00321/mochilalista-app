import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';

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

    // Sembrar negocio y usuario
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

  group('Árbitro Adversarial Bloque 1: Migración SQLite v29 y Columnas de Auditoría', () {
    test('1. La tabla ventas y cuotas poseen las columnas requeridas para anulación atómica', () async {
      // Verificar columnas en ventas
      final tableInfoVentas = await db.rawQuery('PRAGMA table_info(ventas)');
      final colVentas = tableInfoVentas.map((c) => c['name'] as String).toSet();
      expect(colVentas.contains('is_archived'), isTrue);
      expect(colVentas.contains('motivo_anulacion'), isTrue);
      expect(colVentas.contains('fecha_anulacion'), isTrue);

      // Verificar columnas en cuotas
      final tableInfoCuotas = await db.rawQuery('PRAGMA table_info(cuotas)');
      final colCuotas = tableInfoCuotas.map((c) => c['name'] as String).toSet();
      expect(colCuotas.contains('estado'), isTrue);
      expect(colCuotas.contains('monto_pagado'), isTrue);

      // Verificar columnas en pagos
      final tableInfoPagos = await db.rawQuery('PRAGMA table_info(pagos)');
      final colPagos = tableInfoPagos.map((c) => c['name'] as String).toSet();
      expect(colPagos.contains('fecha_pago'), isTrue);
      expect(colPagos.contains('venta_id'), isTrue);
    });
  });

  group('Árbitro Adversarial Bloque 1: Anulación Atómica de Préstamos y Reversión Contable 360°', () {
    test('2. Anulación de Préstamo sin abonos (0 abonos) revierte deuda a 0.00 y anula cuotas', () async {
      // 1. Crear cliente
      final client = await clientService.createClient({
        'nombre_completo': 'Juan Pérez Test',
        'telefono': '987654321',
      }, testNegocioId, testUsuarioId);

      // 2. Registrar préstamo de S/ 1,200.00 en 1 cuota
      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 1200.0,
        motivo: 'Préstamo personal',
        installments: [
          InstallmentModel(
            installmentNumber: 1,
            amount: 1200.0,
            dueDate: '2026-12-01',
            status: 'pendiente',
          ),
        ],
      );

      final loanRows = await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id]);
      expect(loanRows.isNotEmpty, isTrue);
      final int loanId = loanRows.first['id'] as int;

      // 3. Verificar deuda activa
      await clientService.recalculateClientDebt(client.id);
      var cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect((cRow['deuda_total'] as num).toDouble(), equals(1200.0));

      // 4. Anular el préstamo
      await salesService.voidSale(loanId, testNegocioId, 'Cliente arrepentido');

      // 5. Verificar estado en base de datos
      final saleRows = await db.query('ventas', where: 'id = ?', whereArgs: [loanId]);
      expect(saleRows.first['is_archived'], equals(1));
      expect(saleRows.first['motivo_anulacion'], equals('Cliente arrepentido'));
      expect(saleRows.first['estado_pago'], equals('anulado'));
      expect(saleRows.first['fecha_anulacion'], isNotNull);

      // 6. Verificar cuotas anuladas
      final cuotasRows = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [loanId]);
      expect(cuotasRows.isNotEmpty, isTrue);
      for (final row in cuotasRows) {
        expect(row['estado'], equals('anulada'));
      }

      // 7. Reversión contable: deuda del cliente debe ser 0.00
      await clientService.recalculateClientDebt(client.id);
      cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect((cRow['deuda_total'] as num).toDouble(), equals(0.0));

      // 8. Estado de cuenta (ledger) excluye la operación anulada
      final ledger = await clientService.getClientLedger(client.id);
      expect(ledger.isEmpty, isTrue);
    });

    test('3. Anulación de Préstamo con abonos parciales: pagos retienen venta_id y se excluyen del ledger', () async {
      // 1. Crear cliente
      final client = await clientService.createClient({
        'nombre_completo': 'Carlos Abonador',
        'telefono': '912345678',
      }, testNegocioId, testUsuarioId);

      // 2. Registrar préstamo de S/ 1,000 en 2 cuotas de S/ 500
      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 1000.0,
        motivo: 'Préstamo para mercadería',
        installments: [
          InstallmentModel(
            installmentNumber: 1,
            amount: 500.0,
            dueDate: '2026-11-15',
            status: 'pendiente',
          ),
          InstallmentModel(
            installmentNumber: 2,
            amount: 500.0,
            dueDate: '2026-11-30',
            status: 'pendiente',
          ),
        ],
      );

      final loanRows = await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id]);
      final int loanId = loanRows.first['id'] as int;

      // 3. Registrar un abono real de S/ 500 para la cuota 1
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [loanId], orderBy: 'numero_cuota ASC');
      final int cuota1Id = cuotas.first['id'] as int;

      await clientService.registerPayment(
        client.id,
        500.0,
        'Efectivo',
        testNegocioId,
        testUsuarioId,
        ventaId: loanId,
        cuotaId: cuota1Id,
      );

      // Deuda debe ser S/ 500
      await clientService.recalculateClientDebt(client.id);
      var cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect((cRow['deuda_total'] as num).toDouble(), equals(500.0));

      // 4. Anular el préstamo
      await salesService.voidSale(loanId, testNegocioId, 'Error en registro');

      // 5. Verificar que pagos conserva venta_id intacto y nota auditada
      final pagos = await db.query('pagos', where: 'venta_id = ?', whereArgs: [loanId]);
      expect(pagos.isNotEmpty, isTrue);
      expect(pagos.first['venta_id'], equals(loanId));
      expect(pagos.first['nota'].toString().contains('[ANULADO - Venta #$loanId]'), isTrue);

      // 6. Deuda y saldo a favor no deben tener dinero flotante
      await clientService.recalculateClientDebt(client.id);
      cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect((cRow['deuda_total'] as num).toDouble(), equals(0.0));

      await clientService.recalculateClientSaldoAFavor(client.id);
      cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect((cRow['saldo_a_favor'] as num).toDouble(), equals(0.0));

      // 7. Ledger filtrado
      final ledger = await clientService.getClientLedger(client.id);
      expect(ledger.isEmpty, isTrue);
    });
  });

  group('Árbitro Adversarial Bloque 1: Préstamos Históricos y Cronogramas con Cuotas Pre-Pagadas', () {
    test('4. Registro de Préstamo Histórico (2024) con cuotas pre-pagadas e inserción de pagos pasados', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Histórico Morales',
        'telefono': '998877665',
      }, testNegocioId, testUsuarioId);

      final historicalDate = DateTime(2024, 6, 15);

      // Préstamo de S/ 1,500 en 3 cuotas de S/ 500
      // Cuota 1: ya pagada (500)
      // Cuota 2: abono parcial (200)
      // Cuota 3: pendiente (0)
      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 1500.0,
        motivo: 'Préstamo antiguo consolidado',
        loanDate: historicalDate,
        installments: [
          InstallmentModel(
            installmentNumber: 1,
            amount: 500.0,
            dueDate: '2024-07-15',
            status: 'pagado',
            montoPagado: 500.0,
          ),
          InstallmentModel(
            installmentNumber: 2,
            amount: 500.0,
            dueDate: '2024-08-15',
            status: 'parcial',
            montoPagado: 200.0,
          ),
          InstallmentModel(
            installmentNumber: 3,
            amount: 500.0,
            dueDate: '2024-09-15',
            status: 'vencida',
            montoPagado: 0.0,
          ),
        ],
      );

      final loanRows = await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id]);
      final int loanId = loanRows.first['id'] as int;

      // 1. Verificar fecha histórica en ventas
      final saleRow = (await db.query('ventas', where: 'id = ?', whereArgs: [loanId])).first;
      expect(saleRow['fecha_venta'], equals(historicalDate.toIso8601String()));
      expect((saleRow['monto_pagado'] as num).toDouble(), equals(700.0));

      // 2. Verificar que se crearon los registros de pagos pasados
      final pagos = await db.query('pagos', where: 'venta_id = ?', whereArgs: [loanId], orderBy: 'monto ASC');
      expect(pagos.length, equals(2));
      expect((pagos[0]['monto'] as num).toDouble(), equals(200.0));
      expect((pagos[1]['monto'] as num).toDouble(), equals(500.0));

      // 3. Saldo deudor inicial debe ser exactamente S/ 800.00 (1500 - 700)
      await clientService.recalculateClientDebt(client.id);
      final cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect((cRow['deuda_total'] as num).toDouble(), equals(800.0));
    });

    test('5. Sincronización de Reputación en Tiempo Real: Morosidad activa vs Anulación', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Rosa Alerta',
        'telefono': '955443322',
      }, testNegocioId, testUsuarioId);

      // Actualizar cliente como bueno
      await db.update('clientes', {
        'nivel_confianza': 'bueno',
        'nivel_reputacion': 'PLATA',
        'score_reputacion': 650,
      }, where: 'id = ?', whereArgs: [client.id]);

      // Registrar préstamo con fecha vencida en el pasado
      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 500.0,
        motivo: 'Préstamo con atraso',
        installments: [
          InstallmentModel(
            installmentNumber: 1,
            amount: 500.0,
            dueDate: '2026-01-10', // En el pasado
            status: 'vencida',
          ),
        ],
      );

      final loanRows = await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id]);
      final int loanId = loanRows.first['id'] as int;

      // Recalcular reputación: debe detectar la cuota vencida activa y cambiar de BUENO
      await clientService.recalculateClientReputation(client.id);
      var cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect(cRow['nivel_reputacion'], equals('OBSERVACION'));
      expect(cRow['nivel_confianza'], equals('moroso'));

      // Ahora anular el préstamo
      await salesService.voidSale(loanId, testNegocioId, 'Préstamo no concretado');

      // Recalcular reputación tras anulación: cuota anulada no cuenta, vuelve a PLATA / bueno
      await clientService.recalculateClientReputation(client.id);
      cRow = (await db.query('clientes', where: 'id = ?', whereArgs: [client.id])).first;
      expect(cRow['nivel_reputacion'], isNot(equals('OBSERVACION')));
      expect(cRow['nivel_confianza'], isNot(equals('moroso')));
    });

    test('6. Matemática de Centavos y Fracciones en Cronogramas Periódicos', () {
      // 100 / 3 cuotas = 33.33, 33.33, 33.34
      const double totalDebt = 100.0;
      const int numCuotas = 3;
      final double basePerQuota = totalDebt / numCuotas;

      double accumulated = 0;
      final List<double> cuotas = [];
      for (int i = 1; i <= numCuotas; i++) {
        double amt = (i == numCuotas)
            ? double.parse((totalDebt - accumulated).toStringAsFixed(2))
            : double.parse(basePerQuota.toStringAsFixed(2));
        accumulated += amt;
        cuotas.add(amt);
      }

      expect(cuotas, equals([33.33, 33.33, 33.34]));
      expect(cuotas.fold(0.0, (s, a) => s + a), equals(100.0));
    });
  });

  group('Árbitro Adversarial Bloque 1: UI de Operaciones Financieras y Cero Desbordes', () {
    testWidgets('7. ClientFinanceActionsModal renderiza selector de Fecha de Emisión y Wrap sin clipping', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testClient = ClientModel(
        id: 99,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Jj',
        phone: '922836879',
        registeredDate: '2026-11-04',
        saldoAFavor: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TrackingProvider()),
              ],
              child: ClientFinanceActionsModal(client: testClient, isDark: true),
            ),
          ),
        ),
      );

      // Cambiar a pestaña Préstamo
      await tester.tap(find.text('Préstamo'));
      await tester.pumpAndSettle();

      // Verificar existencia del selector de Fecha de Emisión / Entrega
      expect(find.text('Fecha de Emisión / Entrega'), findsOneWidget);
      expect(find.text('Fecha de Entrega del Dinero'), findsOneWidget);

      // Verificar que los chips de motivo están presentes
      expect(find.text('Préstamo personal'), findsOneWidget);
      expect(find.text('Fiado mercadería'), findsOneWidget);
      expect(find.text('Adelanto de trabajo'), findsOneWidget);

      // Verificar selector de estado inicial para 1 cuota
      expect(find.text('Estado de Pago Inicial'), findsOneWidget);
      expect(find.text('Pendiente / Vencida'), findsOneWidget);
      expect(find.text('Ya Pagada'), findsOneWidget);
      expect(find.text('Pago Parcial'), findsOneWidget);
    });
  });
}
