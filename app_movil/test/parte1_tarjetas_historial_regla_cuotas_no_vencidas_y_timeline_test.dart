import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sales_list_builder.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_header_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_payment_timeline.dart';

class _MockSaleProvider extends ChangeNotifier implements SaleProvider {
  final List<SaleModel> _history;
  _MockSaleProvider(this._history);

  @override
  List<SaleModel> get salesHistory => _history;

  @override
  List<SaleModel> getSalesForTab(String tabKey) => _history;

  @override
  bool get isLoading => false;

  @override
  bool get hasMoreData => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SalesService salesService;
  late ClientService clientService;

  const int testNegocioId = 1;
  const int testUsuarioId = 1;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

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

    salesService = SalesService();
    clientService = ClientService();
  });

  tearDown(() async {
    await db.close();
  });

  group('PARTE 1: Tarjetas Historial, Regla Cuotas No Vencidas, y Rediseño Timeline / Detalle', () {
    testWidgets('1. SalesListBuilder muestra motivo real ("Préstamo personal") sin texto contradictorio "Sin motivo especificado"', (tester) async {
      final saleWithNotes = SaleModel.fromJson({
        'id': 13,
        'numero_secuencial': 13,
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': 5,
        'cliente_nombre': 'Jj',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 1200.0,
        'monto_pagado': 0.0,
        'fecha_venta': '2026-11-04T22:53:00',
        'notas': 'Préstamo personal',
        'cuotas_vencidas_count': 2,
        'mora_total': 5.0,
      });

      final saleWithoutNotes = SaleModel.fromJson({
        'id': 14,
        'numero_secuencial': 14,
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': 6,
        'cliente_nombre': 'Ana',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 500.0,
        'monto_pagado': 0.0,
        'fecha_venta': '2026-11-04T22:53:00',
        'notas': null,
      });

      final mockProvider = _MockSaleProvider([saleWithNotes, saleWithoutNotes]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockProvider,
              child: const SalesListBuilder(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Para Préstamo #13 con notes='Préstamo personal': debe renderizar "Préstamo personal"
      expect(find.text('Préstamo personal'), findsOneWidget);
      // Para Préstamo #14 con notes=null: debe mostrar "Sin motivo especificado"
      expect(find.text('Sin motivo especificado'), findsOneWidget);
      // Préstamo #13 y #14 presentes
      expect(find.text('Préstamo #13'), findsOneWidget);
      expect(find.text('Préstamo #14'), findsOneWidget);
    });

    testWidgets('2. SalesListBuilder renderiza layout horizontal con badge compacto [Préstamo] y badges [⚠️ X vencidas] y [+S/ X mora]', (tester) async {
      final loanWithMora = SaleModel.fromJson({
        'id': 13,
        'numero_secuencial': 13,
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': 5,
        'cliente_nombre': 'Jj',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 1205.0,
        'monto_pagado': 0.0,
        'fecha_venta': '2026-11-04T22:53:00',
        'notas': 'Para mercadería',
        'cuotas_vencidas_count': 2,
        'mora_total': 5.0,
      });

      final mockProvider = _MockSaleProvider([loanWithMora]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockProvider,
              child: const SalesListBuilder(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Origen compacto: "Préstamo"
      expect(find.text('Préstamo'), findsOneWidget);
      // Método: "EFECTIVO"
      expect(find.text('EFECTIVO'), findsOneWidget);
      // Badge de cuotas vencidas: "2 vencidas" con icono de advertencia
      expect(find.text('2 vencidas'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      // Badge de mora acumulada: "+S/ 5.00 mora"
      expect(find.text('+S/ 5.00 mora'), findsOneWidget);
    });

    test('3. SalesService.aplicarMorosidadManual RECHAZA recargo directo en cuota no vencida (dueDate >= hoy)', () async {
      final clientId = await db.insert('clientes', {
        'nombre_completo': 'Cliente Test',
        'telefono': '999999999',
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'deuda_total': 600.0,
      });

      final ventaId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': clientId,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 600.0,
        'monto_pagado': 0.0,
        'mora_total': 0.0,
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'fecha_venta': DateTime.now().toIso8601String(),
      });

      // Cuota no vencida (vence en 7 días)
      final futureDate = DateTime.now().add(const Duration(days: 7)).toIso8601String();
      final cuotaNoVencidaId = await db.insert('cuotas', {
        'venta_id': ventaId,
        'numero_cuota': 1,
        'fecha_vencimiento': futureDate,
        'monto': 300.0,
        'monto_original': 300.0,
        'monto_pagado': 0.0,
        'mora_monto': 0.0,
        'estado': 'pendiente',
      });

      // Intentar aplicar morosidad manual directa a la cuota no vencida
      final applied = await salesService.aplicarMorosidadManual(
        cuotaNoVencidaId,
        tipo: 'fijo',
        valor: 10.0,
      );

      // DEBE SER RECHAZADA
      expect(applied, isFalse, reason: 'No se debe permitir aplicar morosidad manual a cuota no vencida');

      // Verificar que los montos en la BD se mantuvieron intactos
      final cuotaRow = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaNoVencidaId])).first;
      expect(cuotaRow['mora_monto'], 0.0);
      expect(cuotaRow['monto'], 300.0);

      final ventaRow = (await db.query('ventas', where: 'id = ?', whereArgs: [ventaId])).first;
      expect(ventaRow['mora_total'], 0.0);
      expect(ventaRow['monto_total'], 600.0);
    });

    test('4. SalesService.configurarMorosidadAutomatica guarda regla pero mantiene mora_monto = 0.0 y monto = montoOriginal si cuota no ha vencido', () async {
      final clientId = await db.insert('clientes', {
        'nombre_completo': 'Cliente Test 2',
        'telefono': '999999999',
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'deuda_total': 300.0,
      });

      final ventaId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': clientId,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 300.0,
        'monto_pagado': 0.0,
        'mora_total': 0.0,
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'fecha_venta': DateTime.now().toIso8601String(),
      });

      // Cuota que vence mañana
      final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      final cuotaId = await db.insert('cuotas', {
        'venta_id': ventaId,
        'numero_cuota': 1,
        'fecha_vencimiento': tomorrow,
        'monto': 300.0,
        'monto_original': 300.0,
        'monto_pagado': 0.0,
        'mora_monto': 0.0,
        'estado': 'pendiente',
      });

      final success = await salesService.configurarMorosidadAutomatica(
        cuotaId,
        activa: true,
        frecuencia: 'diario',
        tipo: 'porcentaje',
        valor: 2.0,
      );

      expect(success, isTrue);

      // Verificar que la regla se guardó pero mora_monto sigue en 0 y monto en 300.0
      final cuotaRow = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cuotaRow['mora_automatica'], 1);
      expect(cuotaRow['mora_frecuencia'], 'diario');
      expect(cuotaRow['mora_monto'], 0.0, reason: 'Mora debe ser 0 en cuota no vencida');
      expect(cuotaRow['monto'], 300.0, reason: 'Monto debe mantenerse en el original');

      // Venta también debe conservar mora_total = 0.0 y monto_total = 300.0
      final ventaRow = (await db.query('ventas', where: 'id = ?', whereArgs: [ventaId])).first;
      expect(ventaRow['mora_total'], 0.0);
      expect(ventaRow['monto_total'], 300.0);
    });

    test('5. ClientService.updateInstallmentDueDate resetea mora_monto a 0 y restaura base al reprogramar a fecha futura', () async {
      final clientId = await db.insert('clientes', {
        'nombre_completo': 'Cliente Moroso',
        'telefono': '999999999',
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'deuda_total': 305.0,
      });

      final ventaId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': clientId,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 305.0,
        'monto_pagado': 0.0,
        'mora_total': 5.0,
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'fecha_venta': '2026-10-01T10:00:00',
      });

      // Cuota vencida hace 10 días con mora de S/ 5.00 aplicada
      final pastDate = DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
      final cuotaId = await db.insert('cuotas', {
        'venta_id': ventaId,
        'numero_cuota': 1,
        'fecha_vencimiento': pastDate,
        'monto': 305.0,
        'monto_original': 300.0,
        'monto_pagado': 0.0,
        'mora_monto': 5.0,
        'estado': 'pendiente',
      });

      // Reprogramar fecha de vencimiento a 5 días en el futuro
      final newFutureDate = DateTime.now().add(const Duration(days: 5)).toIso8601String();
      final updated = await clientService.updateInstallmentDueDate(cuotaId, newFutureDate);

      expect(updated, isTrue);

      // Comprobar que la cuota tiene mora reseteada a 0.0 y monto restaurado a 300.0
      final cuotaRow = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cuotaRow['mora_monto'], 0.0);
      expect(cuotaRow['monto'], 300.0);

      // Comprobar que en la venta se descontó la mora
      final ventaRow = (await db.query('ventas', where: 'id = ?', whereArgs: [ventaId])).first;
      expect(ventaRow['mora_total'], 0.0);
      expect(ventaRow['monto_total'], 300.0);

      // Comprobar que la deuda del cliente se recalculó
      final clientRow = (await db.query('clientes', where: 'id = ?', whereArgs: [clientId])).first;
      expect(clientRow['deuda_total'], 300.0);
    });

    test('6. SaleProvider.syncSaleInMemory sincroniza en memoria y recalcula stats (totalDeuda / Por Cobrar) a 0ms', () async {
      final clientId = await db.insert('clientes', {
        'nombre_completo': 'Cliente Sync',
        'telefono': '999999999',
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'deuda_total': 1205.0,
      });

      final ventaId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': clientId,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 1205.0,
        'monto_pagado': 0.0,
        'mora_total': 5.0,
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'fecha_venta': DateTime.now().toIso8601String(),
        'nota_prestamo': 'Préstamo personal',
      });

      final provider = SaleProvider();
      provider.updateContext(testNegocioId, testUsuarioId);
      await provider.loadSalesHistory();

      // Verificar que la venta está en el historial
      final initialSale = provider.salesHistory.firstWhere((s) => s.id == ventaId);
      expect(initialSale.totalAmount, 1205.0);
      expect(initialSale.moraTotal, 5.0);
      expect(provider.currentStats?.totalDeuda, 1205.0);

      // Modificar directamente la venta en SQLite (simulando pago de mora o actualización)
      await db.update('ventas', {
        'monto_total': 1200.0,
        'mora_total': 0.0,
        'nota_prestamo': 'Préstamo personal editado',
      }, where: 'id = ?', whereArgs: [ventaId]);

      // Ejecutar syncSaleInMemory
      await provider.syncSaleInMemory(ventaId);

      // Comprobar actualización instantánea en memoria sin loadSalesHistory completo
      final updatedSale = provider.salesHistory.firstWhere((s) => s.id == ventaId);
      expect(updatedSale.totalAmount, 1200.0);
      expect(updatedSale.moraTotal, 0.0);
      expect(updatedSale.notes, 'Préstamo personal editado');
      expect(provider.currentStats?.totalDeuda, 1200.0);
    });

    testWidgets('7. DetailHeaderCard renderiza píldora de mora acumulada y monto total actualizado con paridad a Cronograma', (tester) async {
      final saleData = {
        'origen_venta': 'prestamo_personal',
        'cliente_nombre': 'Jj',
        'porcentaje_interes': 20.0,
        'mora_total': 5.0,
        'is_archived': 0,
      };

      final styles = {
        'color': Colors.amber,
        'icon': Icons.account_balance_wallet,
        'label': 'Préstamo Personal',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailHeaderCard(
              saleData: saleData,
              styles: styles,
              totalAmount: 1205.0,
              dateString: '04/11/2026 • 10:53 PM',
              isDark: true,
            ),
          ),
        ),
      );

      // Verificación de píldoras
      expect(find.text('Interés aplicado: 20.0%'), findsOneWidget);
      expect(find.text('Mora acumulada: + S/ 5.00'), findsOneWidget);
      expect(find.text('S/ 1,205.00'), findsOneWidget);
      expect(find.text('Jj'), findsOneWidget);
    });

    testWidgets('8. SalePaymentTimeline renderiza encabezados Venció / Vence y fila simétrica de 3 botones sin doble signo más', (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 6)).toIso8601String();
      final futureDate = DateTime.now().add(const Duration(days: 6)).toIso8601String();

      final cuotasRaw = [
        {
          'id': 1,
          'numero_cuota': 1,
          'fecha_vencimiento': pastDate,
          'monto': 305.0,
          'monto_original': 300.0,
          'monto_pagado': 0.0,
          'mora_monto': 5.0,
          'estado': 'pendiente',
        },
        {
          'id': 2,
          'numero_cuota': 2,
          'fecha_vencimiento': futureDate,
          'monto': 300.0,
          'monto_original': 300.0,
          'monto_pagado': 0.0,
          'mora_monto': 0.0,
          'estado': 'pendiente',
        },
      ];

      final provider = SaleProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SaleProvider>.value(
            value: provider,
            child: Scaffold(
              body: SingleChildScrollView(
                child: SalePaymentTimeline(
                  cuotasRaw: cuotasRaw,
                  isDark: true,
                  clientPhone: '922836879',
                  clientName: 'Jj',
                  clientId: 5,
                  saleId: 13,
                  isLoan: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Cuota 1 vencida debe decir "Venció:"
      expect(find.textContaining('Venció:'), findsOneWidget);
      // Cuota 2 en plazo debe decir "Vence:"
      expect(find.textContaining('Vence:'), findsOneWidget);

      // Botón de mora en cuota 1 (con mora aplicada): debe decir "Mora (+S/ 5.00)"
      expect(find.text('Mora (+S/ 5.00)'), findsOneWidget);
      // Botón de mora en cuota 2 (vigente): debe decir "Prog. Mora"
      expect(find.text('Prog. Mora'), findsOneWidget);

      // Botones Recordar y Cobrar (2 de cada uno, 1 por cuota)
      expect(find.text('Recordar'), findsNWidgets(2));
      expect(find.text('Cobrar'), findsNWidgets(2));

      // Verificar que NO existe ningún botón con "+ Mora" o "⊕ + Mora"
      expect(find.text('+ Mora'), findsNothing);
      expect(find.text('⊕ + Mora'), findsNothing);
    });
  });
}
