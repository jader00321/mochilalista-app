import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/screens/notifications_screen.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_item_card.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ClientService clientService;
  late SalesService salesService;
  late NotificationProvider notificationProvider;

  const int testNegocioId = 1;
  const int testUsuarioId = 1;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    // Sembrar negocio y usuario
    await db.insert('negocios', {
      'id': testNegocioId,
      'nombre_comercial': 'Librería Central Test',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': testUsuarioId,
      'nombre_completo': 'Admin Test',
      'email': 'admin@test.com',
    });

    clientService = ClientService();
    salesService = SalesService();
    notificationProvider = NotificationProvider();
    notificationProvider.updateContext(testNegocioId, usuarioId: testUsuarioId);
    await notificationProvider.fetchNotifications();
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    if (db.isOpen) {
      await db.close();
    }
  });

  group('Árbitro Interno Adversarial: Reingeniería del Centro de Notificaciones', () {
    
    // T1: Deduplicación Canónica en Cuotas Múltiples de Freddy
    test('T1: Deduplicación Canónica en Cuotas Múltiples (UPSERT por dedup_key)', () async {
      final int freddyId = await db.insert('clientes', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Freddy Test',
        'telefono': '999888777',
      });

      final int vId1 = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': freddyId,
        'origen_venta': 'smart_quotation',
        'numero_secuencial': 101,
        'monto_total': 80.0,
        'monto_pagado': 0.0,
        'metodo_pago': 'Credito',
        'fecha_venta': '2026-10-01',
      });

      final int cuotaId1 = await db.insert('cuotas', {
        'venta_id': vId1,
        'numero_cuota': 1,
        'monto': 80.0,
        'monto_original': 80.0,
        'mora_monto': 0.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-15', // Vencida
        'estado': 'pendiente',
      });

      // Ejecutar generateAutoNotifications dos veces
      await notificationProvider.generateAutoNotifications(testUsuarioId);
      await notificationProvider.generateAutoNotifications(testUsuarioId);

      // Verificar en SQLite que solo existe 1 registro para esta cuota (cero duplicados)
      final rows = await db.query(
        'notificaciones',
        where: 'negocio_id = ? AND dedup_key = ?',
        whereArgs: [testNegocioId, 'cuota_vencida_$cuotaId1'],
      );

      expect(rows.length, equals(1));
      expect(rows.first['dedup_key'], equals('cuota_vencida_$cuotaId1'));
      expect(rows.first['titulo'], contains('Freddy Test'));
      expect(rows.first['mensaje'], contains('Recibo #101'));
      expect(rows.first['mensaje'], contains('S/ 80.00'));
    });

    // T2: Reflejo Dinámico de Morosidad en Jj (+S/ 5.00)
    test('T2: Reflejo Dinámico de Morosidad (+S/ 5.00 acumulado -> S/ 305.00)', () async {
      final int jjId = await db.insert('clientes', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Jj Test',
        'telefono': '911222333',
      });

      final int vId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': jjId,
        'origen_venta': 'prestamo_personal',
        'numero_secuencial': 45,
        'monto_total': 305.0,
        'mora_total': 5.0,
        'monto_pagado': 0.0,
        'metodo_pago': 'Credito',
        'fecha_venta': '2026-10-01',
      });

      final int cuotaId = await db.insert('cuotas', {
        'venta_id': vId,
        'numero_cuota': 2,
        'monto': 305.0,
        'monto_original': 300.0,
        'mora_monto': 5.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-25', // Vencida
        'estado': 'pendiente',
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);

      final rows = await db.query(
        'notificaciones',
        where: 'dedup_key = ?',
        whereArgs: ['cuota_vencida_$cuotaId'],
      );

      expect(rows.length, equals(1));
      final notif = NotificationModel.fromJson(rows.first);
      expect(notif.saldoTotal, equals(305.0));
      expect(notif.moraAcumulada, equals(5.0));
      expect(notif.montoBase, equals(300.0));
      expect(notif.esPrestamo, isTrue);
      expect(notif.folioOperacion, equals('Préstamo #45'));
      expect(notif.message, contains('S/ 305.00 exigible'));
      expect(notif.message, contains('Mora: S/ 5.00'));
    });

    // T3: Anulación Atómica de Venta / Préstamo (0 Alertas Fantasma)
    test('T3: Anulación Atómica limpia alertas de cuotas a 0ms', () async {
      final int cId = await db.insert('clientes', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Cliente Anulable',
        'telefono': '999111222',
      });

      final int vId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': cId,
        'origen_venta': 'smart_quotation',
        'numero_secuencial': 200,
        'monto_total': 100.0,
        'monto_pagado': 0.0,
        'metodo_pago': 'Credito',
        'fecha_venta': '2026-10-01',
        'is_archived': 0,
      });

      final int cuotaId = await db.insert('cuotas', {
        'venta_id': vId,
        'numero_cuota': 1,
        'monto': 100.0,
        'monto_original': 100.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-10',
        'estado': 'pendiente',
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);

      // Verificar que la alerta estaba pendiente
      var notifs = await db.query('notificaciones', where: 'dedup_key = ?', whereArgs: ['cuota_vencida_$cuotaId']);
      expect(notifs.first['is_resolved'], equals(0));

      // Anular venta mediante SalesService
      await salesService.voidSale(vId, testNegocioId, 'Error de prueba');

      // Verificar que la notificación fue resuelta atómicamente en SQLite
      notifs = await db.query('notificaciones', where: 'dedup_key = ?', whereArgs: ['cuota_vencida_$cuotaId']);
      expect(notifs.first['is_resolved'], equals(1));
      expect(notifs.first['fecha_resolucion'], isNotNull);

      // Al hacer fetchNotifications(), no debe figurar como pendiente
      await notificationProvider.fetchNotifications();
      final pendientes = notificationProvider.notifications.where((n) => n.isActionable && !n.isResolved).toList();
      expect(pendientes.any((n) => n.objetoRelacionadoId == cuotaId), isFalse);
    });

    // T4: Reprogramación de Cuota a Fecha Futura
    test('T4: Reprogramar cuota a fecha futura resuelve la alerta de vencida', () async {
      final int cId = await db.insert('clientes', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Cliente Reprogramado',
        'telefono': '999111222',
      });

      final int vId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': cId,
        'origen_venta': 'smart_quotation',
        'monto_total': 150.0,
        'monto_pagado': 0.0,
        'metodo_pago': 'Credito',
        'fecha_venta': '2026-10-01',
      });

      final int cuotaId = await db.insert('cuotas', {
        'venta_id': vId,
        'numero_cuota': 1,
        'monto': 150.0,
        'monto_original': 150.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-05', // Vencida
        'estado': 'pendiente',
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);

      // Reprogramar hacia el futuro (año 2030)
      await clientService.updateInstallmentDueDate(cuotaId, '2030-12-01');

      final notifs = await db.query('notificaciones', where: 'dedup_key = ?', whereArgs: ['cuota_vencida_$cuotaId']);
      expect(notifs.first['is_resolved'], equals(1));
    });

    // T5: Plazo de Gracia de 7 Días en Nuevos Productos
    test('T5: Producto creado hoy (< 7 días) respeta plazo de gracia y no alerta stock bajo', () async {
      final nowStr = DateTime.now().toIso8601String();
      final int prodId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Cuaderno Nuevo En Gracia',
        'categoria_id': 1,
        'estado': 'publico',
        'modo_stock': 'INDEPENDIENTE',
        'fecha_creacion': nowStr, // Creado hoy (< 7 días)
      });

      final int presId = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Unidad',
        'unidades_por_venta': 1,
        'stock_actual': 2,
        'stock_alerta': 5,
        'precio_venta_final': 5.0,
        'activo': 1,
      });

      // Realizar una venta que baje el stock a 0
      final saleData = {
        'cliente_id': null,
        'metodo_pago': 'Efectivo',
        'monto_total': 10.0,
        'monto_pagado': 10.0,
        'items': [
          {
            'product_id': prodId,
            'presentation_id': presId,
            'product_name': 'Cuaderno Nuevo En Gracia',
            'quantity': 2,
            'unit_price': 5.0,
          }
        ],
      };

      await salesService.createSale(saleData, testNegocioId, testUsuarioId);

      // Verificar que NO existe notificación de stock bajo para este producto en periodo de gracia
      final notifs = await db.query(
        'notificaciones',
        where: "objeto_relacionado_tipo = 'producto' AND objeto_relacionado_id = ?",
        whereArgs: [prodId],
      );

      expect(notifs.isEmpty, isTrue);
    });

    // T6: Diferenciación Visual y 4 Niveles Semánticos
    test('T6: Taxonomía de 4 Niveles Semánticos en NotificationModel', () {
      final notifCritica = NotificationModel.fromJson({
        'id': 1,
        'titulo': 'Cuota Vencida',
        'mensaje': 'Alerta de mora',
        'tipo': 'alerta',
        'prioridad': 'Alta',
        'nivel_prioridad': 'critica',
        'leida': 0,
        'is_resolved': 0,
        'fecha_creacion': '2026-11-01T10:00:00',
      });
      expect(notifCritica.nivelPrioridad, equals('critica'));
      expect(notifCritica.isActionable, isTrue);

      final notifPreventiva = NotificationModel.fromJson({
        'id': 2,
        'titulo': 'Stock Bajo',
        'mensaje': 'Quedan 3 und.',
        'tipo': 'alerta',
        'prioridad': 'Media',
        'nivel_prioridad': 'preventiva',
        'leida': 0,
        'is_resolved': 0,
        'fecha_creacion': '2026-11-01T10:00:00',
      });
      expect(notifPreventiva.nivelPrioridad, equals('preventiva'));
      expect(notifPreventiva.isActionable, isTrue);

      final notifInformativa = NotificationModel.fromJson({
        'id': 3,
        'titulo': 'Cuota Pagada',
        'mensaje': 'Freddy pagó S/ 150.00',
        'tipo': 'exito',
        'nivel_prioridad': 'informativa',
        'leida': 0,
        'is_resolved': 1,
        'fecha_creacion': '2026-11-01T10:00:00',
      });
      expect(notifInformativa.nivelPrioridad, equals('informativa'));
      expect(notifInformativa.isActionable, isFalse);
    });

    // T7: In-Card Actions y Deserialización de Metadata Tipada
    test('T7: Metadata JSON se deserializa con getters tipados seguros', () {
      final meta = {
        'cliente_id': 42,
        'cliente_nombre': 'Carlos Ruiz',
        'cliente_telefono': '987654321',
        'cuota_id': 105,
        'cuota_numero': 3,
        'venta_id': 55,
        'folio_operacion': 'Préstamo #55',
        'es_prestamo': true,
        'monto_base': 200.0,
        'mora_acumulada': 10.0,
        'saldo_total': 210.0,
        'dias_atraso': 8,
      };

      final notif = NotificationModel.fromJson({
        'id': 10,
        'titulo': 'Cuota Vencida • Carlos Ruiz',
        'mensaje': 'Carlos tiene S/ 210.00 exigible',
        'tipo': 'alerta',
        'nivel_prioridad': 'critica',
        'prioridad': 'Alta',
        'leida': 0,
        'fecha_creacion': '2026-11-01T10:00:00',
        'metadata_json': jsonEncode(meta),
      });

      expect(notif.clientId, equals(42));
      expect(notif.clientName, equals('Carlos Ruiz'));
      expect(notif.clientPhone, equals('987654321'));
      expect(notif.cuotaNumero, equals(3));
      expect(notif.folioOperacion, equals('Préstamo #55'));
      expect(notif.esPrestamo, isTrue);
      expect(notif.montoBase, equals(200.0));
      expect(notif.moraAcumulada, equals(10.0));
      expect(notif.saldoTotal, equals(210.0));
      expect(notif.diasAtraso, equals(8));
    });

    // T8: Smart Grouping Multi-Cuota
    test('T8: Smart Grouping consolida múltiples cuotas de un mismo cliente', () async {
      final int cId = await db.insert('clientes', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Cliente Multi Cuotas',
        'telefono': '999111222',
      });

      final int vId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': cId,
        'origen_venta': 'smart_quotation',
        'monto_total': 500.0,
        'monto_pagado': 0.0,
        'metodo_pago': 'Credito',
        'fecha_venta': '2026-10-01',
      });

      await db.insert('cuotas', {
        'venta_id': vId,
        'numero_cuota': 1,
        'monto': 250.0,
        'monto_original': 250.0,
        'mora_monto': 0.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-10',
        'estado': 'pendiente',
      });

      await db.insert('cuotas', {
        'venta_id': vId,
        'numero_cuota': 2,
        'monto': 255.0,
        'monto_original': 250.0,
        'mora_monto': 5.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-20',
        'estado': 'pendiente',
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);
      await notificationProvider.fetchNotifications();

      final pendingCuotas = notificationProvider.notifications
          .where((n) => n.objetoRelacionadoTipo == 'cuota' && n.clientId == cId && !n.isResolved)
          .toList();

      expect(pendingCuotas.length, equals(2));
      final double totalConsolidado = pendingCuotas.fold(0.0, (sum, c) => sum + (c.saldoTotal ?? 0.0));
      expect(totalConsolidado, equals(505.0));
    });

    // T9: Gestos Swipe y Resolución en NotificationProvider
    test('T9: markAsResolved y deleteNotification actualizan memoria y SQLite', () async {
      final int notifId = await db.insert('notificaciones', {
        'user_id': testUsuarioId,
        'negocio_id': testNegocioId,
        'dedup_key': 'test_swipe_1',
        'titulo': 'Alerta de Prueba',
        'mensaje': 'Mensaje de prueba',
        'tipo': 'alerta',
        'nivel_prioridad': 'critica',
        'prioridad': 'Alta',
        'leida': 0,
        'is_resolved': 0,
        'fecha_creacion': '2026-11-01T10:00:00',
      });

      await notificationProvider.fetchNotifications();
      expect(notificationProvider.notifications.any((n) => n.id == notifId), isTrue);

      // Resolver (Swipe derecho)
      await notificationProvider.markAsResolved(notifId);
      expect(notificationProvider.notifications.firstWhere((n) => n.id == notifId).isResolved, isTrue);

      var dbRow = await db.query('notificaciones', where: 'id = ?', whereArgs: [notifId]);
      expect(dbRow.first['is_resolved'], equals(1));
      expect(dbRow.first['leida'], equals(1));

      // Eliminar (Swipe izquierdo)
      await notificationProvider.deleteNotification(notifId);
      expect(notificationProvider.notifications.any((n) => n.id == notifId), isFalse);

      dbRow = await db.query('notificaciones', where: 'id = ?', whereArgs: [notifId]);
      expect(dbRow.isEmpty, isTrue);
    });

    // T10: Cotizaciones Inteligentes: Emisión y Auto-Resolución
    test('T10: Cotizaciones Inteligentes: Emite alerta de vencimiento y se auto-resuelve al pasar a SOLD o ANNULLED', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first;
      final int qId = await db.insert('smart_quotations', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'client_name': 'Colegio San José',
        'total_amount': 1250.0,
        'valid_until': tomorrow,
        'status': 'PENDING',
        'numero_secuencial': 12,
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);
      await notificationProvider.fetchNotifications();

      final notifs = notificationProvider.notifications
          .where((n) => n.dedupKey == 'cotizacion_vence_$qId')
          .toList();

      expect(notifs.length, equals(1));
      expect(notifs.first.isResolved, isFalse);
      expect(notifs.first.objetoRelacionadoTipo, equals('cotizacion'));
      expect(notifs.first.title, contains('San José'));

      // Ahora la cotización se vende
      await db.update('smart_quotations', {'status': 'SOLD'}, where: 'id = ?', whereArgs: [qId]);
      await notificationProvider.generateAutoNotifications(testUsuarioId);
      await notificationProvider.fetchNotifications();

      final resolvedNotif = notificationProvider.notifications
          .firstWhere((n) => n.dedupKey == 'cotizacion_vence_$qId');
      expect(resolvedNotif.isResolved, isTrue);
    });

    // T11: Auto-Resolución de Stock a 0ms al reabastecer
    test('T11: Auto-Resolución de Stock a 0ms al reabastecer', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 15)).toIso8601String();
      final int pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Cuaderno Cuadriculado Test',
        'categoria_id': 1,
        'fecha_creacion': oldDate,
        'estado': 'publico',
        'modo_stock': 'INDEPENDIENTE',
      });

      await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': 'A4 100 Hojas',
        'precio_venta_final': 5.0,
        'stock_actual': 0,
        'stock_alerta': 5,
        'usa_stock_compartido': 0,
        'activo': 1,
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);
      await notificationProvider.fetchNotifications();

      final stockNotifs = notificationProvider.notifications
          .where((n) => n.dedupKey == 'stock_agotado_$pId')
          .toList();

      expect(stockNotifs.length, equals(1));
      expect(stockNotifs.first.isResolved, isFalse);
      expect(stockNotifs.first.nivelPrioridad, equals('critica'));

      // Reabastecimiento a 0ms mediante resolveProductStockNotification
      await notificationProvider.resolveProductStockNotification(pId);

      expect(notificationProvider.notifications.firstWhere((n) => n.dedupKey == 'stock_agotado_$pId').isResolved, isTrue);

      final dbRow = await db.query('notificaciones', where: 'dedup_key = ?', whereArgs: ['stock_agotado_$pId']);
      expect(dbRow.first['is_resolved'], equals(1));
    });

    // W1: Widget Test: NotificationItemCard en 360x640dp
    testWidgets('W1: NotificationItemCard en 360x640dp sin textos truncados ni overflows y con In-Card Actions', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool recordarClicked = false;
      bool cobrarClicked = false;
      bool moraClicked = false;
      bool abastecerClicked = false;
      bool cotizacionClicked = false;

      final notifCuota = NotificationModel(
        id: 1,
        title: 'Cuota Vencida • Freddy Test',
        message: 'Freddy tiene la Cuota #1 con S/ 80.00 pendiente y lleva 3 días de atraso.',
        type: 'alerta',
        prioridad: 'Alta',
        nivelPrioridad: 'critica',
        isRead: false,
        isResolved: false,
        objetoRelacionadoTipo: 'cuota',
        objetoRelacionadoId: 10,
        createdAt: DateTime.now(),
        metadataJson: jsonEncode({
          'cliente_nombre': 'Freddy Test',
          'cliente_telefono': '999888777',
          'cuota_numero': 1,
          'saldo_total': 80.0,
          'dias_atraso': 3,
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItemCard(
              notif: notifCuota,
              isDark: false,
              isSelected: false,
              isSelectionMode: false,
              tabIndex: 0,
              onTap: () {},
              onLongPress: () {},
              onActionRecordar: () => recordarClicked = true,
              onActionCobrar: () => cobrarClicked = true,
              onActionMora: () => moraClicked = true,
            ),
          ),
        ),
      );

      // Verificar que NO existe ningún texto repetido o truncado tipo "Toca para ver detalles"
      expect(find.textContaining('Toca para ver detalles de la ...'), findsNothing);
      expect(find.textContaining('👆'), findsNothing);

      // Verificar presencia de botones de cuota
      expect(find.text('Recordar'), findsOneWidget);
      expect(find.text('Cobrar'), findsOneWidget);
      expect(find.text('Mora'), findsOneWidget);

      await tester.tap(find.text('Recordar'));
      await tester.tap(find.text('Cobrar'));
      await tester.ensureVisible(find.text('Mora'));
      await tester.tap(find.text('Mora'));
      expect(recordarClicked, isTrue);
      expect(cobrarClicked, isTrue);
      expect(moraClicked, isTrue);

      // Probar tarjeta con cotización
      final notifCotizacion = NotificationModel(
        id: 2,
        title: 'Cotización Vence Hoy • San José',
        message: 'La cotización #5 vence hoy por S/ 450.00.',
        type: 'alerta',
        prioridad: 'Media',
        nivelPrioridad: 'preventiva',
        isRead: false,
        isResolved: false,
        objetoRelacionadoTipo: 'cotizacion',
        objetoRelacionadoId: 5,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItemCard(
              notif: notifCotizacion,
              isDark: false,
              isSelected: false,
              isSelectionMode: false,
              tabIndex: 0,
              onTap: () {},
              onLongPress: () {},
              onActionVerCotizacion: () => cotizacionClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Ver Cotización'), findsOneWidget);
      await tester.tap(find.text('Ver Cotización'));
      expect(cotizacionClicked, isTrue);

      // Probar tarjeta con producto (Abastecer / Kardex)
      final notifStock = NotificationModel(
        id: 3,
        title: '🚨 Producto Agotado • Borrador',
        message: 'El producto Borrador tiene 0 und.',
        type: 'alerta',
        prioridad: 'Alta',
        nivelPrioridad: 'critica',
        isRead: false,
        isResolved: false,
        objetoRelacionadoTipo: 'producto',
        objetoRelacionadoId: 99,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationItemCard(
              notif: notifStock,
              isDark: true,
              isSelected: false,
              isSelectionMode: false,
              tabIndex: 0,
              onTap: () {},
              onLongPress: () {},
              onActionAbastecer: () => abastecerClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Abastecer'), findsOneWidget);
      await tester.tap(find.text('Abastecer'));
      expect(abastecerClicked, isTrue);
    });

    // W2: Widget Test: NotificationsScreen en 360x640dp
    testWidgets('W2: NotificationsScreen en 360x640dp renderiza Dashboard de Pulso, Badges y Acordeón', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        final int cId = await db.insert('clientes', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'nombre_completo': 'Freddy Visual Test',
          'telefono': '999333444',
        });

        final int vId = await db.insert('ventas', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'cliente_id': cId,
          'origen_venta': 'smart_quotation',
          'monto_total': 300.0,
          'monto_pagado': 0.0,
          'metodo_pago': 'Credito',
          'fecha_venta': '2026-10-01',
        });

        await db.insert('cuotas', {
          'venta_id': vId,
          'numero_cuota': 1,
          'monto': 150.0,
          'monto_original': 150.0,
          'mora_monto': 0.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-10',
          'estado': 'pendiente',
        });

        await db.insert('cuotas', {
          'venta_id': vId,
          'numero_cuota': 2,
          'monto': 155.0,
          'monto_original': 150.0,
          'mora_monto': 5.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-20',
          'estado': 'pendiente',
        });

        await notificationProvider.generateAutoNotifications(testUsuarioId);
        await notificationProvider.fetchNotifications();
      });

      final authProv = _MockAuthProvider();
      final invProv = _MockInventoryProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<InventoryProvider>.value(value: invProv),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      // Esperar a que el postFrameCallback (fetchNotifications) termine en background
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verificar AppBar y pestañas con badges
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.textContaining('Pendientes'), findsOneWidget);
      expect(find.textContaining('Resueltas'), findsOneWidget);
      expect(find.textContaining('Historial'), findsOneWidget);

      // 2. Verificar Dashboard de Pulso Ejecutivo
      expect(find.text('Mora Exigible'), findsOneWidget);
      expect(find.text('Inventario'), findsWidgets);
      expect(find.textContaining('cuotas vencidas'), findsWidgets);

      // 3. Verificar Acordeón de Smart Grouping de Freddy
      expect(find.textContaining('Freddy Visual Test'), findsWidgets);
      expect(find.textContaining('2 cuotas'), findsWidgets);

      // 4. Expandir acordeón
      await tester.tap(find.textContaining('Freddy Visual Test').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 5. Verificar botón de Recordatorio Consolidado por WhatsApp
      expect(find.text('Recordatorio Consolidado por WhatsApp'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

  });
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isCommunityClient => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  bool get showStockAlertColors => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
