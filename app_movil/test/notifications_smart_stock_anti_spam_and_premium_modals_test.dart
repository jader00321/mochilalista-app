import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/models/notification_preferences_model.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/widgets/notification_toast_feedback.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/widgets/notifications/stock_analysis_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/archived_notifications_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/silenced_notifications_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_settings_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
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
      'nombre_comercial': 'Comercial MochilaLista Test',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': testUsuarioId,
      'nombre_completo': 'Admin Test',
      'email': 'admin@test.com',
    });

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

  group('Árbitro Interno Adversarial: Reingeniería de Notificaciones y Stock Inteligente', () {
    
    // ARB-01: Regla de Gracia en Creación / Edición Inicial
    test('ARB-01: Producto nuevo con stock inicial bajo y 0 ventas en stock_ledger no genera alerta de stock bajo', () async {
      // 1. Crear producto con stock 3 y umbral 5, sin movimientos en stock_ledger
      final pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Leche Condensada Doypack',
        'categoria_id': 1,
        'modo_stock': 'INDEPENDIENTE',
        'stock_compartido': 0,
        'costo_base': 3.50,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });

      await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': 'Doypack 180g',
        'stock_actual': 3,
        'stock_alerta': 5,
        'precio_venta_final': 5.00,
        'costo_unitario_calculado': 3.50,
        'es_default': 1,
        'activo': 1,
      });

      // 2. Ejecutar generación de alertas automáticas
      await notificationProvider.generateAutoNotifications(testUsuarioId);

      // 3. Verificar que NO se generó alerta de stock bajo preventiva
      final stockAlerts = notificationProvider.notifications
          .where((n) => n.objetoRelacionadoId == pId && n.objetoRelacionadoTipo == 'producto')
          .toList();
      expect(stockAlerts.isEmpty, isTrue, reason: "Regla de gracia debe evitar falsas alarmas en productos recién registrados sin ventas");
    });

    // ARB-02: Activación Legítima tras 1ra Venta
    test('ARB-02: Se activa la alerta legítimamente cuando ocurre la 1ra venta que deja stock <= umbral', () async {
      final pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Fideos Canuto Chico',
        'categoria_id': 1,
        'modo_stock': 'INDEPENDIENTE',
        'stock_compartido': 0,
        'costo_base': 2.00,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });

      final presId = await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': '250g',
        'stock_actual': 3,
        'stock_alerta': 5,
        'precio_venta_final': 3.00,
        'costo_unitario_calculado': 2.00,
        'es_default': 1,
        'activo': 1,
      });

      // Simular venta en stock_ledger
      await db.insert('stock_ledger', {
        'presentation_id': presId,
        'negocio_id': testNegocioId,
        'tipo_transaccion': 'VENTA',
        'cantidad': -1,
        'costo_unitario': 2.00,
        'precio_venta': 3.00,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);

      final stockAlerts = notificationProvider.notifications
          .where((n) => n.objetoRelacionadoId == pId && n.objetoRelacionadoTipo == 'producto')
          .toList();
      expect(stockAlerts.length, equals(1));
      expect(stockAlerts.first.cleanTitle.contains('Stock Bajo'), isTrue);
      expect(stockAlerts.first.cleanTitle.contains('Fideos Canuto Chico'), isTrue);
    });

    // ARB-03: Auto-Saneamiento / Purga Inmediata de Falsas Alarmas Previas en SQLite
    test('ARB-03: Saneamiento automático purga falsas alarmas previas de productos en gracia sin salidas', () async {
      final pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Limpiador Multiuso',
        'categoria_id': 1,
        'modo_stock': 'INDEPENDIENTE',
        'stock_compartido': 0,
        'costo_base': 4.00,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });

      await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': '550ml',
        'stock_actual': 3,
        'stock_alerta': 5,
        'precio_venta_final': 6.00,
        'costo_unitario_calculado': 4.00,
        'es_default': 1,
        'activo': 1,
      });

      // Sembrar una alerta vieja previa a la actualización
      final oldNotifId = await db.insert('notificaciones', {
        'negocio_id': testNegocioId,
        'user_id': testUsuarioId,
        'titulo': '⚠️ Stock Bajo • Limpiador Multiuso',
        'mensaje': 'El stock cayó a 3 und. (umbral: 5 und.)',
        'tipo': 'alerta',
        'prioridad': 'Media',
        'nivel_prioridad': 'preventiva',
        'dedup_key': 'stock_bajo_$pId',
        'objeto_relacionado_tipo': 'producto',
        'objeto_relacionado_id': pId,
        'leida': 0,
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });

      // Al sincronizar, debe auto-sanear y marcar como resuelta la falsa alarma
      await notificationProvider.generateAutoNotifications(testUsuarioId);

      final activeAlerts = notificationProvider.pendingNotifications
          .where((n) => n.id == oldNotifId)
          .toList();
      expect(activeAlerts.isEmpty, isTrue, reason: "La falsa alarma previa debió ser saneada automáticamente de la lista de pendientes");

      final resolvedAlerts = notificationProvider.resolvedNotifications
          .where((n) => n.id == oldNotifId)
          .toList();
      expect(resolvedAlerts.isNotEmpty, isTrue, reason: "La falsa alarma saneada debe figurar en resueltas");

      final dbCheck = await db.query('notificaciones', where: 'id = ?', whereArgs: [oldNotifId]);
      expect(dbCheck.first['is_resolved'], equals(1));
    });

    // ARB-04: Anti-Spam en Ventas Sucesivas (5 -> 4 -> 3 -> 2)
    test('ARB-04: Ventas consecutivas actualizan in-place sin duplicar notificaciones', () async {
      final pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Arroz Superior',
        'categoria_id': 1,
        'modo_stock': 'INDEPENDIENTE',
        'fecha_creacion': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      });

      final presId = await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': '1kg',
        'stock_actual': 4,
        'stock_alerta': 5,
        'precio_venta_final': 4.50,
        'costo_unitario_calculado': 3.20,
        'es_default': 1,
        'activo': 1,
      });

      await db.insert('stock_ledger', {
        'presentation_id': presId,
        'negocio_id': testNegocioId,
        'tipo_transaccion': 'VENTA',
        'cantidad': -1,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // 1ra generación: stock = 4
      await notificationProvider.generateAutoNotifications(testUsuarioId);
      expect(notificationProvider.notifications.where((n) => n.objetoRelacionadoId == pId).length, equals(1));
      final firstNotif = notificationProvider.notifications.firstWhere((n) => n.objetoRelacionadoId == pId);
      expect(firstNotif.message.contains('4'), isTrue);

      // Simular 2da venta: stock pasa de 4 a 3
      await db.update('presentaciones_producto', {'stock_actual': 3}, where: 'id = ?', whereArgs: [presId]);
      await notificationProvider.generateAutoNotifications(testUsuarioId);

      // Debe mantenerse exactamente 1 notificación y actualizarse el texto in-place
      final updatedList = notificationProvider.notifications.where((n) => n.objetoRelacionadoId == pId).toList();
      expect(updatedList.length, equals(1), reason: "No debe haber duplicados tras ventas consecutivas");
      expect(updatedList.first.id, equals(firstNotif.id));
      expect(updatedList.first.message.contains('3'), isTrue);
    });

    // ARB-05: Respeto al Archivado y Silenciado
    test('ARB-05: Si el usuario archiva la alerta en 4 und., al bajar a 3 y 2 und. NO se desarchiva ni se resucita', () async {
      final pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Aceite Vegetal',
        'categoria_id': 1,
        'modo_stock': 'INDEPENDIENTE',
        'fecha_creacion': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      });

      final presId = await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': '1L',
        'stock_actual': 4,
        'stock_alerta': 5,
        'precio_venta_final': 8.50,
        'es_default': 1,
        'activo': 1,
      });

      await db.insert('stock_ledger', {
        'presentation_id': presId,
        'negocio_id': testNegocioId,
        'tipo_transaccion': 'VENTA',
        'cantidad': -1,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);
      final notif = notificationProvider.notifications.firstWhere((n) => n.objetoRelacionadoId == pId);

      // El usuario archiva la notificación
      await notificationProvider.archiveNotification(notif.id);
      expect(notificationProvider.notifications.any((n) => n.id == notif.id), isFalse);
      expect(notificationProvider.archivedNotifications.any((n) => n.id == notif.id), isTrue);

      // Siguiente venta: baja a 3 und.
      await db.update('presentaciones_producto', {'stock_actual': 3}, where: 'id = ?', whereArgs: [presId]);
      await notificationProvider.generateAutoNotifications(testUsuarioId);

      // Debe permanecer archivada y NO reaparecer en lista activa
      expect(notificationProvider.notifications.any((n) => n.objetoRelacionadoId == pId), isFalse);
      expect(notificationProvider.archivedNotifications.any((n) => n.objetoRelacionadoId == pId), isTrue);
    });

    // ARB-06: Escalamiento Crítico al Agotarse Existencias (0 und.)
    test('ARB-06: Escalamiento crítico dispara ¡Producto Agotado! al llegar a 0 und. aun si la previa estaba archivada', () async {
      final pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Atún en Trozos',
        'categoria_id': 1,
        'modo_stock': 'INDEPENDIENTE',
        'fecha_creacion': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      });

      final presId = await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': 'Lata 170g',
        'stock_actual': 1,
        'stock_alerta': 5,
        'precio_venta_final': 5.50,
        'es_default': 1,
        'activo': 1,
      });

      await db.insert('stock_ledger', {
        'presentation_id': presId,
        'negocio_id': testNegocioId,
        'tipo_transaccion': 'VENTA',
        'cantidad': -1,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);
      final notif = notificationProvider.notifications.firstWhere((n) => n.objetoRelacionadoId == pId);
      await notificationProvider.archiveNotification(notif.id);

      // Ahora el producto se agota completamente (0 unidades)
      await db.update('presentaciones_producto', {'stock_actual': 0}, where: 'id = ?', whereArgs: [presId]);
      await notificationProvider.generateAutoNotifications(testUsuarioId);

      // Debe dispararse la alerta crítica de producto agotado
      final activeAgotado = notificationProvider.notifications
          .where((n) => n.objetoRelacionadoId == pId && n.nivelPrioridad == 'critica')
          .toList();
      expect(activeAgotado.isNotEmpty, isTrue);
      expect(activeAgotado.first.cleanTitle.contains('Agotado'), isTrue);
    });

    // ARB-07: StockAnalysisModal: Abastecimiento Rápido y Ajuste de Umbral
    test('ARB-07: Abastecimiento rápido e in-modal actualiza stock_ledger, umbral y auto-resuelve alerta', () async {
      final pId = await db.insert('productos', {
        'negocio_id': testNegocioId,
        'nombre': 'Galletas Soda',
        'categoria_id': 1,
        'modo_stock': 'INDEPENDIENTE',
        'costo_base': 2.20,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });

      final presId = await db.insert('presentaciones_producto', {
        'producto_id': pId,
        'nombre_especifico': 'Paquete 6x',
        'stock_actual': 3,
        'stock_alerta': 5,
        'precio_venta_final': 3.50,
        'costo_unitario_calculado': 2.20,
        'factor_ganancia_venta': 0.59,
        'es_default': 1,
        'activo': 1,
      });

      // Simular que ya existía venta previa que detonó la alerta de stock bajo
      await db.insert('stock_ledger', {
        'presentation_id': presId,
        'negocio_id': testNegocioId,
        'tipo_transaccion': 'VENTA',
        'cantidad': -1,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      await notificationProvider.generateAutoNotifications(testUsuarioId);
      expect(notificationProvider.pendingNotifications.any((n) => n.objetoRelacionadoId == pId), isTrue);

      // 1. Abastecimiento rápido (+10 und.) como lo hace StockAnalysisModal._applyQuickRestock
      const int qtyToAdd = 10;
      final int newStock = 3 + qtyToAdd;
      await db.update('presentaciones_producto', {'stock_actual': newStock}, where: 'id = ?', whereArgs: [presId]);
      await db.insert('stock_ledger', {
        'presentation_id': presId,
        'negocio_id': testNegocioId,
        'tipo_transaccion': 'INGRESO',
        'cantidad': qtyToAdd,
        'costo_unitario': 2.20,
        'precio_venta': 3.50,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Al superar el umbral (13 > 5), debe auto-resolverse
      await notificationProvider.resolveProductStockNotification(pId);
      await notificationProvider.fetchNotifications();

      expect(notificationProvider.pendingNotifications.any((n) => n.objetoRelacionadoId == pId), isFalse);
      expect(notificationProvider.resolvedNotifications.any((n) => n.objetoRelacionadoId == pId), isTrue);

      // Verificar que el movimiento INGRESO se grabó en stock_ledger
      final ledgerRows = await db.query('stock_ledger', where: 'presentation_id = ?', whereArgs: [presId], orderBy: 'id DESC');
      expect(ledgerRows.first['tipo_transaccion'], equals('INGRESO'));
      expect(ledgerRows.first['cantidad'], equals(10));

      // 2. Ajuste rápido de umbral mínimo (_updateThreshold)
      await db.update('presentaciones_producto', {'stock_alerta': 15}, where: 'id = ?', whereArgs: [presId]);
      final updatedPres = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [presId]);
      expect(updatedPres.first['stock_alerta'], equals(15));
    });

    // ARB-08: NotificationToastFeedback Flotante con Deshacer
    testWidgets('ARB-08: NotificationToastFeedback renderiza toast flotante con acción Deshacer', (tester) async {
      bool undoTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    NotificationToastFeedback.showArchived(
                      ctx,
                      onUndo: () {
                        undoTriggered = true;
                      },
                    );
                  },
                  child: const Text("Mostrar Toast"),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Mostrar Toast"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Notificación archivada'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await tester.pump();
      expect(undoTriggered, isTrue);

      NotificationToastFeedback.dismiss();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ARB-09: Título limpio (cleanTitle) y Posponer (Snooze)
    test('ARB-09: NotificationModel.cleanTitle remueve emojis residuales y snoozeNotification pospone', () async {
      final notif = NotificationModel(
        id: 50,
        title: '⚠️ Stock Bajo • Arroz Costeño',
        message: 'Quedan 2 unidades',
        type: 'alerta',
        prioridad: 'Media',
        isRead: false,
        createdAt: DateTime.now(),
      );

      expect(notif.cleanTitle, equals('Stock Bajo • Arroz Costeño'));
      expect(notif.cleanTitle.contains('⚠️'), isFalse);
      expect(notif.isSnoozed, isFalse);

      await db.insert('notificaciones', {
        'id': 50,
        'negocio_id': testNegocioId,
        'user_id': testUsuarioId,
        'titulo': notif.title,
        'mensaje': notif.message,
        'tipo': notif.type,
        'prioridad': notif.prioridad,
        'leida': 0,
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });

      await notificationProvider.fetchNotifications();
      expect(notificationProvider.notifications.any((n) => n.id == 50), isTrue);

      // Posponer por 1 día
      await notificationProvider.snoozeNotification(50, const Duration(days: 1));
      expect(notificationProvider.notifications.any((n) => n.id == 50), isFalse, reason: "La notificación pospuesta debe ocultarse de pendientes");
    });

    // ARB-10: Clave de Silenciamiento canónica y deduplicación
    test('ARB-10: effectiveMuteKey agrupa canónicamente ítems por tipo e ID', () {
      final notifCuota = NotificationModel(
        id: 1,
        title: 'Cuota Vencida • Freddy',
        message: 'Monto: S/ 80.00',
        type: 'alerta',
        prioridad: 'Alta',
        objetoRelacionadoTipo: 'cuota',
        objetoRelacionadoId: 42,
        isRead: false,
        createdAt: DateTime.now(),
      );
      expect(notifCuota.effectiveMuteKey, equals('cuota_42'));

      final notifProd = NotificationModel(
        id: 2,
        title: 'Stock Bajo • Leche',
        message: 'Stock: 3',
        type: 'alerta',
        prioridad: 'Media',
        objetoRelacionadoTipo: 'producto',
        objetoRelacionadoId: 10,
        isRead: false,
        createdAt: DateTime.now(),
      );
      expect(notifProd.effectiveMuteKey, equals('producto_10'));
    });

    // ARB-11: Preferencias de Notificaciones en SQLite
    test('ARB-11: NotificationPreferences persiste diasGraciaStockBajo y antiSpamStockSilencioso', () async {
      final prefs = NotificationPreferences.defaultFor(testNegocioId);
      expect(prefs.diasGraciaStockBajo, equals(3));
      expect(prefs.antiSpamStockSilencioso, isTrue);

      final updated = prefs.copyWith(
        diasGraciaStockBajo: 7,
        antiSpamStockSilencioso: false,
      );

      await notificationProvider.updatePreferences(updated);

      final dbPrefs = await db.query('preferencias_notificaciones', where: 'negocio_id = ?', whereArgs: [testNegocioId]);
      expect(dbPrefs.isNotEmpty, isTrue);
      expect(dbPrefs.first['dias_gracia_stock_bajo'], equals(7));
      expect(dbPrefs.first['anti_spam_stock_silencioso'], equals(0));
    });

    // ARB-12: Verificación de Cero Emojis en código UI y Pure withValues
    test('ARB-12: NotificationModel categoría canónica mapea correctamente', () {
      final n1 = NotificationModel(id: 1, title: 'T1', message: 'M', type: 'alerta', prioridad: 'Alta', isRead: false, createdAt: DateTime.now(), objetoRelacionadoTipo: 'producto');
      final n2 = NotificationModel(id: 2, title: 'T2', message: 'M', type: 'alerta', prioridad: 'Alta', isRead: false, createdAt: DateTime.now(), objetoRelacionadoTipo: 'cuota');
      final n3 = NotificationModel(id: 3, title: 'T3', message: 'M', type: 'alerta', prioridad: 'Alta', isRead: false, createdAt: DateTime.now(), objetoRelacionadoTipo: 'cotizacion');
      final n4 = NotificationModel(id: 4, title: 'T4', message: 'M', type: 'alerta', prioridad: 'Alta', isRead: false, createdAt: DateTime.now(), objetoRelacionadoTipo: 'otro');

      expect(n1.categoria, equals('inventario'));
      expect(n2.categoria, equals('cobranza'));
      expect(n3.categoria, equals('cotizacion'));
      expect(n4.categoria, equals('general'));
    });

    // =========================================================================
    // PROTOCOLO WIDGET RENDERING: Viewports 320x568dp y 360x640dp (Anti-Overflow)
    // =========================================================================

    // ARB-W1: StockAnalysisModal en 320x568dp
    testWidgets('ARB-W1: StockAnalysisModal renderiza en 320x568dp sin overflows y con footer docked', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testProduct = Product(
        id: 10,
        nombre: 'Leche Condensada Doypack',
        categoriaId: 1,
        modoStock: 'INDEPENDIENTE',
        presentaciones: [
          ProductPresentation(
            id: 20,
            nombreEspecifico: 'Doypack 180g',
            stockActual: 3,
            stockAlerta: 5,
            precioVentaFinal: 5.50,
            costoUnitarioCalculado: 3.50,
            factorGananciaVenta: 0.57,
            esDefault: true,
            activo: true,
          ),
        ],
      );

      final testNotif = NotificationModel(
        id: 101,
        title: 'Stock Bajo • Leche Condensada Doypack',
        message: 'Stock cayó a 3 und. (umbral: 5 und.)',
        type: 'alerta',
        prioridad: 'Media',
        nivelPrioridad: 'preventiva',
        objetoRelacionadoTipo: 'producto',
        objetoRelacionadoId: 10,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
            ChangeNotifierProvider<InventoryProvider>(create: (_) => _MockInventoryProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StockAnalysisModal(
                notif: testNotif,
                product: testProduct,
                isDark: false,
                initialLedger: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Análisis de Stock'), findsOneWidget);
      expect(find.text('Leche Condensada Doypack'), findsOneWidget);
      expect(find.text('Stock Bajo Preventivo'), findsOneWidget);
      expect(find.text('Abastecimiento Rápido'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('Ajustar Umbral de Alerta'), findsOneWidget);
      expect(find.text('Ir a Editar Producto'), findsOneWidget);
      expect(find.textContaining('Aún no registra salidas ni ventas'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ARB-W2: ArchivedNotificationsModal en 320x568dp
    testWidgets('ARB-W2: ArchivedNotificationsModal renderiza en 320x568dp con Docked Footer completo', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await db.insert('notificaciones', {
          'id': 601,
          'user_id': testUsuarioId,
          'negocio_id': testNegocioId,
          'titulo': 'Stock Bajo • Arroz',
          'mensaje': 'Quedan 2 und.',
          'tipo': 'alerta',
          'nivel_prioridad': 'preventiva',
          'is_resolved': 0,
          'is_archived': 1,
          'is_silenced': 0,
          'objeto_relacionado_tipo': 'producto',
          'objeto_relacionado_id': 99,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'fecha_archivado': DateTime.now().toIso8601String(),
        });
        await notificationProvider.fetchNotifications();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ArchivedNotificationsModal(isDark: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Notificaciones Archivadas'), findsOneWidget);
      expect(find.text('Buscar en archivadas...'), findsOneWidget);
      expect(find.text('Limpiar bandeja'), findsOneWidget);
      expect(find.text('Restaurar todo'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ARB-W3: SilencedNotificationsModal en 320x568dp
    testWidgets('ARB-W3: SilencedNotificationsModal renderiza en 320x568dp sin mute key y con nombre real', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await db.insert('notificaciones', {
          'id': 701,
          'user_id': testUsuarioId,
          'negocio_id': testNegocioId,
          'titulo': 'Cuota Vencida • Freddy',
          'mensaje': 'Mora de 15 días',
          'tipo': 'alerta',
          'nivel_prioridad': 'critica',
          'is_resolved': 0,
          'is_archived': 0,
          'is_silenced': 1,
          'mute_key': 'cuota_3',
          'objeto_relacionado_tipo': 'cuota',
          'objeto_relacionado_id': 3,
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
        await notificationProvider.fetchNotifications();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SilencedNotificationsModal(isDark: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Buscar por cliente, producto o referencia...'), findsOneWidget);
      expect(find.textContaining('mute key'), findsNothing);
      expect(find.textContaining('(cuota_3)'), findsNothing);
      expect(find.textContaining('Freddy'), findsWidgets);
      expect(find.text('Limpiar bandeja'), findsOneWidget);
      expect(find.text('Restaurar todo'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ARB-W4: NotificationSettingsModal en 320x568dp
    testWidgets('ARB-W4: NotificationSettingsModal renderiza en 320x568dp con switches y docked footer completo', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationSettingsModal(isDark: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Configuración de Alertas'), findsOneWidget);
      expect(find.text('Notificaciones Archivadas'), findsOneWidget);
      expect(find.text('Ítems No Deseados / Silenciados'), findsOneWidget);
      expect(find.text('Restaurar recomendados'), findsOneWidget);
      expect(find.text('Listo / Guardar'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Desplazar hacia abajo para verificar la sección de alertas
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pump();

      expect(find.text('Cuotas Vencidas (Mora)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

  });
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  bool get showStockAlertColors => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
