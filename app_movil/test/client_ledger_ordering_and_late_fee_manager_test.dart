import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/repositories/client_repository.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart';

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

class _MockSaleProvider extends ChangeNotifier implements SaleProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestApp({
  required Widget child,
  TrackingProvider? trackingProv,
  _MockAuthProvider? authProv,
  QuickSaleProvider? quickProv,
  _MockSaleProvider? saleProv,
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
      ChangeNotifierProvider<SaleProvider>.value(
        value: saleProv ?? _MockSaleProvider(),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ClientService clientService;
  late ClientRepository clientRepo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    clientService = ClientService();
    clientRepo = ClientRepository();

    // Inserción de negocio y cliente base
    await db.insert('negocios', {
      'id': 1,
      'nombre_comercial': 'Librería Central',
      'moneda': 'S/ (Soles)',
    });

    await db.insert('clientes', {
      'id': 1,
      'negocio_id': 1,
      'creado_por_usuario_id': 1,
      'nombre_completo': 'Jj',
      'telefono': '922836879',
      'deuda_total': 0.0,
      'saldo_a_favor': 0.0,
      'puntos_actuales': 50,
      'score_reputacion': 370,
      'nivel_reputacion': 'BRONCE',
      'fecha_registro': '2026-11-01 10:00:00',
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Árbitro Adversarial: Historial Contable Reciente-Primero y Trazabilidad', () {
    test('Test 1: Historical backdated loan appears on TOP of Estado de Cuenta and Compras', () async {
      // 1. Insertamos un primer préstamo (#13) emitido el 04/11/2026
      await db.insert('ventas', {
        'id': 13,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 13,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 1205.00,
        'monto_pagado': 0.00,
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-11-04 22:53:00',
        'created_at': '2026-11-04 22:53:00',
      });

      // 2. Insertamos un segundo préstamo (#14) recién registrado (created_at más reciente),
      // pero con fecha de emisión histórica previa (02/10/2026)
      await db.insert('ventas', {
        'id': 14,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 14,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 2400.00,
        'monto_pagado': 0.00,
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-10-02 00:00:00', // Fecha histórica de emisión
        'created_at': '2026-11-07 14:00:00', // Momento real de registro en la app
      });

      // Verificamos Estado de Cuenta (getClientLedger)
      final ledger = await clientService.getClientLedger(1);
      expect(ledger.isNotEmpty, isTrue);
      // El ítem en la CIMA (index 0) debe ser la operación recién registrada (Préstamo #14)
      expect(ledger.first.detalle, contains('Préstamo #14'));
      expect(ledger.last.detalle, contains('Préstamo #13'));

      // Verificamos Compras (getClientSales)
      final sales = await clientRepo.getClientSales(1);
      expect(sales.length, equals(2));
      expect(sales.first['numero_secuencial'], equals(14));
      expect(sales.last['numero_secuencial'], equals(13));
    });

    test('Test 2: Coherencia de saldo acumulativo progresivo (el ítem superior debe coincidir con la deuda total viva)', () async {
      // Préstamo #13: S/ 1,205.00
      await db.insert('ventas', {
        'id': 13,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 13,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 1205.00,
        'monto_pagado': 0.00,
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-11-04 22:53:00',
        'created_at': '2026-11-04 22:53:00',
      });

      // Préstamo #14: Base S/ 2,400.00 + Mora S/ 48.00 = Total S/ 2,448.00
      await db.insert('ventas', {
        'id': 14,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 14,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 2448.00,
        'monto_pagado': 480.00,
        'mora_total': 48.00,
        'estado_pago': 'parcial',
        'fecha_venta': '2026-10-02 00:00:00',
        'created_at': '2026-11-07 14:00:00',
      });

      // Cronograma del Préstamo #14: 5 cuotas de S/ 480.00 (con S/ 48.00 de mora en Cuota #2)
      await db.insert('cuotas', {
        'id': 101,
        'venta_id': 14,
        'numero_cuota': 1,
        'monto': 480.00,
        'monto_pagado': 480.00,
        'estado': 'pagado',
        'fecha_vencimiento': '2026-10-18',
      });
      await db.insert('cuotas', {
        'id': 102,
        'venta_id': 14,
        'numero_cuota': 2,
        'monto': 528.00,
        'monto_original': 480.00,
        'mora_monto': 48.00,
        'monto_pagado': 0.00,
        'estado': 'vencida',
        'fecha_vencimiento': '2026-11-02',
      });
      for (int i = 3; i <= 5; i++) {
        await db.insert('cuotas', {
          'id': 100 + i,
          'venta_id': 14,
          'numero_cuota': i,
          'monto': 480.00,
          'monto_pagado': 0.00,
          'estado': 'pendiente',
          'fecha_vencimiento': '2026-11-${10 + i * 5}',
        });
      }

      // Abono histórico de Cuota #1
      await db.insert('pagos', {
        'id': 501,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'venta_id': 14,
        'cuota_id': 101,
        'monto': 480.00,
        'metodo_pago': 'Efectivo',
        'nota': 'Abono histórico (Cuota #1 Préstamo #14)',
        'fecha_pago': '2026-10-18 12:00:00',
        'created_at': '2026-11-07 14:01:00', // Registrado justo con el préstamo
      });

      // Recalcular deuda del cliente
      await clientService.recalculateClientDebt(1);

      final freshClient = await clientService.getClientById(1);
      // Deuda esperada: 1205.00 + (2448.00 - 480.00) = S/ 3,173.00
      expect(freshClient!.totalDebt, equals(3173.00));

      final ledger = await clientService.getClientLedger(1);
      expect(ledger.length, equals(3));

      // El ítem superior (la operación más reciente registrada) debe tener exactamente el saldo deuda actual: 3,173.00
      expect(ledger.first.saldoResultante, equals(3173.00));

      // Verificamos que el saldo resultante nunca sea negativo en ningún paso intermedio
      for (var item in ledger) {
        expect(item.saldoResultante >= 0, isTrue);
      }
    });

    test('Test 3: Cuadre contable exacto entre Compras y Estado de Cuenta ante mora activa (+S/ 48.00)', () async {
      await db.insert('ventas', {
        'id': 14,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 14,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 2448.00,
        'monto_pagado': 480.00,
        'mora_total': 48.00,
        'estado_pago': 'parcial',
        'fecha_venta': '2026-10-02 00:00:00',
        'created_at': '2026-11-07 14:00:00',
      });

      final sales = await clientRepo.getClientSales(1);
      final sale = SaleSummary.fromJson(sales.first);

      // Validación de modelo SaleSummary enriquecido
      expect(sale.moraTotal, equals(48.00));
      expect(sale.total, equals(2448.00));
      expect(sale.montoPagado, equals(480.00));

      // Deuda de la venta: 2448.00 - 480.00 = 1968.00
      final double deudaVenta = sale.total - sale.montoPagado;
      expect(deudaVenta, equals(1968.00));

      // En el ledger, el desglose debe contener moraMonto: 48.00 y montoBase: 2400.00
      final ledger = await clientService.getClientLedger(1);
      final loanItem = ledger.firstWhere((i) => i.ventaId == 14 && i.tipo == 'cargo');
      expect(loanItem.moraMonto, equals(48.00));
      expect(loanItem.montoBase, equals(2400.00));
    });

    test('Test 4: Menú de corrección: edición de abono y recálculo en cascada de cuota, venta y deuda', () async {
      await db.insert('ventas', {
        'id': 14,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 14,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 2400.00,
        'monto_pagado': 480.00,
        'estado_pago': 'parcial',
        'fecha_venta': '2026-10-02 00:00:00',
        'created_at': '2026-11-07 14:00:00',
      });

      // 5 cuotas de S/ 480.00
      await db.insert('cuotas', {
        'id': 101,
        'venta_id': 14,
        'numero_cuota': 1,
        'monto': 480.00,
        'monto_pagado': 480.00,
        'estado': 'pagado',
        'fecha_vencimiento': '2026-10-18',
      });
      for (int i = 2; i <= 5; i++) {
        await db.insert('cuotas', {
          'id': 100 + i,
          'venta_id': 14,
          'numero_cuota': i,
          'monto': 480.00,
          'monto_pagado': 0.00,
          'estado': 'pendiente',
          'fecha_vencimiento': '2026-11-${10 + i * 5}',
        });
      }

      await db.insert('pagos', {
        'id': 501,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'venta_id': 14,
        'cuota_id': 101,
        'monto': 480.00,
        'metodo_pago': 'Efectivo',
        'nota': 'Abono Cuota 1',
        'fecha_pago': '2026-10-18 12:00:00',
      });

      await clientService.recalculateClientDebt(1);
      final initialClient = await clientService.getClientById(1);
      expect(initialClient!.totalDebt, equals(1920.00)); // 2400 - 480

      // Ejecutamos edición de abono: se corrigió a S/ 600.00 con Yape
      final ok = await clientService.editarPago(
        501,
        nuevoMonto: 600.00,
        nuevoMetodoPago: 'Yape',
        nuevaNota: 'Corrección por digitación',
      );
      expect(ok, isTrue);

      // Verificamos persistencia en tabla pagos
      final pagosRows = await db.query('pagos', where: 'id = 501');
      expect(pagosRows.first['monto'], equals(600.00));
      expect(pagosRows.first['metodo_pago'], equals('Yape'));

      // Verificamos recálculo en cascada en cuotas y ventas
      final cuotasRows = await db.query('cuotas', where: 'id = 101');
      expect(cuotasRows.first['monto_pagado'], equals(600.00));

      final ventasRows = await db.query('ventas', where: 'id = 14');
      expect(ventasRows.first['monto_pagado'], equals(600.00));

      // Verificamos recálculo global de deuda del cliente
      final updatedClient = await clientService.getClientById(1);
      expect(updatedClient!.totalDebt, equals(1800.00)); // 2400 - 600
    });

    test('Test 5: Reversión limpia de un movimiento erróneo en SQLite sin dejar residuos en la vista', () async {
      await db.insert('ventas', {
        'id': 14,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 14,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 2400.00,
        'monto_pagado': 480.00,
        'estado_pago': 'parcial',
        'fecha_venta': '2026-10-02 00:00:00',
        'created_at': '2026-11-07 14:00:00',
      });

      // 5 cuotas de S/ 480.00
      await db.insert('cuotas', {
        'id': 101,
        'venta_id': 14,
        'numero_cuota': 1,
        'monto': 480.00,
        'monto_pagado': 480.00,
        'estado': 'pagado',
        'fecha_vencimiento': '2026-10-18',
      });
      for (int i = 2; i <= 5; i++) {
        await db.insert('cuotas', {
          'id': 100 + i,
          'venta_id': 14,
          'numero_cuota': i,
          'monto': 480.00,
          'monto_pagado': 0.00,
          'estado': 'pendiente',
          'fecha_vencimiento': '2026-11-${10 + i * 5}',
        });
      }

      await db.insert('pagos', {
        'id': 501,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'venta_id': 14,
        'cuota_id': 101,
        'monto': 480.00,
        'metodo_pago': 'Efectivo',
        'fecha_pago': '2026-10-18 12:00:00',
      });

      // Reversión del abono
      final okPago = await clientService.revertirPago(501);
      expect(okPago, isTrue);

      // Verificamos que el abono fue eliminado
      final pCheck = await db.query('pagos', where: 'id = 501');
      expect(pCheck.isEmpty, isTrue);

      // La cuota vuelve a tener monto_pagado 0.0 y estado no pagado
      final cCheck = await db.query('cuotas', where: 'id = 101');
      expect(cCheck.first['monto_pagado'], equals(0.0));
      expect(cCheck.first['estado'], isNot(equals('pagado')));

      // Reversión de préstamo completo
      final okVenta = await clientService.revertirVentaOPrestamo(14);
      expect(okVenta, isTrue);

      // Verificamos que no quedan residuos en ventas ni cuotas
      final vCheck = await db.query('ventas', where: 'id = 14');
      expect(vCheck.isEmpty, isTrue);
      final cAll = await db.query('cuotas', where: 'venta_id = 14');
      expect(cAll.isEmpty, isTrue);

      final ledger = await clientService.getClientLedger(1);
      expect(ledger.isEmpty, isTrue);
    });
  });

  group('Árbitro Adversarial: Gestor de Morosidad, Badges y Cero Emojis', () {
    testWidgets('Test 6: Gestor de morosidad: banner interactivo en Manual / Directo y persistencia', (tester) async {
      final cuotaMap = {
        'id': 2,
        'numero_cuota': 2,
        'monto': 528.00,
        'monto_original': 480.00,
        'mora_monto': 48.00,
        'fecha_vencimiento': '2026-11-02',
        'mora_automatica': 1,
        'mora_activa': 1,
        'mora_frecuencia': 'personalizado',
        'mora_intervalo_dias': 2,
        'mora_tipo': 'porcentaje',
        'mora_porcentaje': 5.0,
        'mora_valor': 5.0,
      };

      await tester.pumpWidget(
        _buildTestApp(
          child: CuotaMorosidadModal(
            cuota: cuotaMap,
            isDark: true,
            onSaved: () {},
          ),
        ),
      );
      await tester.pump();

      // Cambiamos a la pestaña Manual / Directo
      final manualTab = find.text('Manual / Directo');
      expect(manualTab, findsOneWidget);
      await tester.tap(manualTab);
      await tester.pump();

      // En la pestaña Manual / Directo debe aparecer el banner con el texto informativo y el botón Desactivar
      expect(find.textContaining('acumulación periódica'), findsOneWidget);
      expect(find.text('Desactivar'), findsOneWidget);

      // Tap en Desactivar apaga la acumulación
      await tester.tap(find.text('Desactivar'));
      await tester.pump();

      // El botón Desactivar ya no debe figurar en pantalla
      expect(find.text('Desactivar'), findsNothing);
    });

    testWidgets('Test 7: Simulación en vivo estructurada sin desbordes en 360dp y con cero emojis Unicode', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final cuotaMap = {
        'id': 2,
        'numero_cuota': 2,
        'monto': 528.00,
        'monto_original': 480.00,
        'mora_monto': 48.00,
        'fecha_vencimiento': '2026-11-02',
        'mora_automatica': 1,
        'mora_activa': 1,
        'mora_frecuencia': 'personalizado',
        'mora_intervalo_dias': 2,
        'mora_tipo': 'porcentaje',
        'mora_porcentaje': 5.0,
        'mora_valor': 5.0,
      };

      await tester.pumpWidget(
        _buildTestApp(
          child: CuotaMorosidadModal(
            cuota: cuotaMap,
            isDark: true,
            onSaved: () {},
          ),
        ),
      );
      await tester.pump();

      // Verificamos que las 3 filas estructuradas de simulación se renderizan correctamente
      expect(find.textContaining('días de atraso'), findsOneWidget);
      expect(find.textContaining('de mora hoy'), findsOneWidget);
      expect(find.textContaining('Siguiente recargo'), findsOneWidget);

      // Verificación estricta de CERO EMOJIS Unicode en todos los textos del árbol
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F1E0}-\u{1F1FF}]', unicode: true);

      for (var tw in textWidgets) {
        final textData = tw.data ?? tw.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(textData),
          isFalse,
          reason: 'El texto "$textData" contiene un emoji Unicode prohibido. Use iconos vectoriales.',
        );
      }

      // Verificamos que no haya errores de overflow en RenderFlex
      expect(tester.takeException(), isNull);
    });
  });
}
