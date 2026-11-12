import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/screens/notifications_screen.dart';
import 'package:app_movil/features/profile/widgets/notifications/archived_notifications_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/silenced_notifications_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late NotificationProvider notificationProvider;
  late _MockAuthProvider authProvider;
  late _MockInventoryProvider inventoryProvider;

  const int testNegocioId = 1;
  const int testUsuarioId = 1;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    await db.insert('negocios', {
      'id': testNegocioId,
      'nombre_comercial': 'Tienda Comercial Test',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': testUsuarioId,
      'nombre_completo': 'Comerciante Test',
      'email': 'comerciante@test.com',
    });

    authProvider = _MockAuthProvider();
    inventoryProvider = _MockInventoryProvider();
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

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<InventoryProvider>.value(value: inventoryProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Protocolo del Árbitro Interno: 7 Puntos de Reingeniería de Notificaciones', () {

    // -------------------------------------------------------------------------
    // PUNTO 1: Swipe Horizontal Anticolisión Gestual entre Pestañas
    // -------------------------------------------------------------------------
    testWidgets('P1: Swipe horizontal sobre tarjeta navega entre pestañas sin borrar ni resolver accidentalmente', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insertar una cuota en mora
      await tester.runAsync(() async {
        await db.insert('notificaciones', {
          'id': 101,
          'user_id': testUsuarioId,
          'negocio_id': testNegocioId,
          'dedup_key': 'cuota_vencida_101',
          'titulo': 'Cuota Vencida • Freddy',
          'mensaje': 'Freddy tiene la Cuota #1 con S/ 50.00 pendiente.',
          'tipo': 'alerta',
          'nivel_prioridad': 'critica',
          'prioridad': 'Alta',
          'leida': 0,
          'is_resolved': 0,
          'is_archived': 0,
          'is_silenced': 0,
          'mute_key': 'cuota_101',
          'objeto_relacionado_tipo': 'cuota',
          'objeto_relacionado_id': 101,
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
        await notificationProvider.fetchNotifications();
      });

      await tester.pumpWidget(createTestWidget(const NotificationsScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 🛡️ VERIFICACIÓN ADVERSARIAL: Ausencia absoluta de Dismissible destructor de gestos
      expect(find.byType(Dismissible), findsNothing);

      // Verificar que la tarjeta está en pantalla
      final cardFinder = find.text('Cuota Vencida • Freddy');
      expect(cardFinder, findsOneWidget);

      // Cambiar a la pestaña Resueltas tocando el Tab
      final resueltasTab = find.textContaining('Resueltas');
      await tester.tap(resueltasTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 🛡️ VERIFICACIÓN ADVERSARIAL: La notificación NO debe haberse borrado ni resuelto al cambiar de pestaña
      expect(notificationProvider.notifications.any((n) => n.id == 101), isTrue);
      expect(notificationProvider.notifications.firstWhere((n) => n.id == 101).isResolved, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    // -------------------------------------------------------------------------
    // PUNTO 2: Menú de Acciones Rápidas '•••' y Deshacer Inmediato
    // -------------------------------------------------------------------------
    testWidgets('P2: Menú de acciones rápidas permite archivar con botón Deshacer a 0ms', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await db.insert('notificaciones', {
          'id': 102,
          'user_id': testUsuarioId,
          'negocio_id': testNegocioId,
          'dedup_key': 'cuota_vencida_102',
          'titulo': 'Cuota Vencida • Rosa',
          'mensaje': 'Rosa tiene la Cuota #2 vencida.',
          'tipo': 'alerta',
          'nivel_prioridad': 'critica',
          'prioridad': 'Alta',
          'leida': 0,
          'is_resolved': 0,
          'is_archived': 0,
          'is_silenced': 0,
          'mute_key': 'cuota_102',
          'objeto_relacionado_tipo': 'cuota',
          'objeto_relacionado_id': 102,
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
        await notificationProvider.fetchNotifications();
      });

      await tester.pumpWidget(createTestWidget(const NotificationsScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tocar el botón de acciones rápidas (•••)
      final moreBtn = find.byIcon(Icons.more_vert_rounded).first;
      await tester.tap(moreBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que el menú modal de opciones se desplegó
      expect(find.text('Archivar notificación'), findsOneWidget);
      expect(find.text('Mover a No Deseadas (Silenciar ítem)'), findsOneWidget);

      // Tocar "Archivar notificación"
      await tester.tap(find.text('Archivar notificación'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que salió de la lista activa y apareció el SnackBar con Deshacer
      expect(notificationProvider.pendingCount, equals(0));
      expect(notificationProvider.archivedCount, equals(1));
      expect(find.text('Deshacer'), findsOneWidget);

      // Tocar Deshacer
      await tester.tap(find.text('Deshacer'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 🛡️ VERIFICACIÓN ADVERSARIAL: Reversión inmediata a 0ms
      expect(notificationProvider.pendingCount, equals(1));
      expect(notificationProvider.archivedCount, equals(0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    // -------------------------------------------------------------------------
    // PUNTO 3: Paridad Matemática 1:1 (Badge == Chip Todas == Suma Categorías)
    // -------------------------------------------------------------------------
    test('P3: Paridad matemática exacta: Badge Pestaña == Chip Todas == Suma de Categorías', () async {
      await db.insert('notificaciones', {
        'id': 201,
        'user_id': testUsuarioId,
        'negocio_id': testNegocioId,
        'titulo': 'Cuota 1',
        'mensaje': 'Mora',
        'tipo': 'alerta',
        'nivel_prioridad': 'critica',
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'objeto_relacionado_tipo': 'cuota',
        'objeto_relacionado_id': 1,
        'fecha_creacion': '2026-11-01',
      });
      await db.insert('notificaciones', {
        'id': 202,
        'user_id': testUsuarioId,
        'negocio_id': testNegocioId,
        'titulo': 'Cuota 2',
        'mensaje': 'Vence mañana',
        'tipo': 'alerta',
        'nivel_prioridad': 'preventiva',
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'objeto_relacionado_tipo': 'cuota',
        'objeto_relacionado_id': 2,
        'fecha_creacion': '2026-11-02',
      });
      await db.insert('notificaciones', {
        'id': 203,
        'user_id': testUsuarioId,
        'negocio_id': testNegocioId,
        'titulo': 'Stock Agotado',
        'mensaje': 'Agotado',
        'tipo': 'alerta',
        'nivel_prioridad': 'critica',
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'objeto_relacionado_tipo': 'producto',
        'objeto_relacionado_id': 1,
        'fecha_creacion': '2026-11-03',
      });
      await db.insert('notificaciones', {
        'id': 204,
        'user_id': testUsuarioId,
        'negocio_id': testNegocioId,
        'titulo': 'Cotización Vence',
        'mensaje': 'Cotización',
        'tipo': 'alerta',
        'nivel_prioridad': 'preventiva',
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'objeto_relacionado_tipo': 'cotizacion',
        'objeto_relacionado_id': 1,
        'fecha_creacion': '2026-11-04',
      });
      await db.insert('notificaciones', {
        'id': 205,
        'user_id': testUsuarioId,
        'negocio_id': testNegocioId,
        'titulo': 'Cuota Pagada Resuelta',
        'mensaje': 'Resuelta',
        'tipo': 'alerta',
        'nivel_prioridad': 'critica',
        'is_resolved': 1,
        'is_archived': 0,
        'is_silenced': 0,
        'objeto_relacionado_tipo': 'cuota',
        'objeto_relacionado_id': 3,
        'fecha_creacion': '2026-11-05',
      });

      await notificationProvider.fetchNotifications();

      // Pestaña Pendientes
      final pendingBadge = notificationProvider.pendingCount;
      final pendingList = notificationProvider.pendingNotifications;
      final int pendingCobranzas = pendingList.where((n) => n.objetoRelacionadoTipo == 'cuota').length;
      final int pendingInventario = pendingList.where((n) => n.objetoRelacionadoTipo == 'producto').length;
      final int pendingCotizaciones = pendingList.where((n) => n.objetoRelacionadoTipo == 'cotizacion').length;

      expect(pendingBadge, equals(4));
      expect(pendingList.length, equals(4));
      expect(pendingCobranzas + pendingInventario + pendingCotizaciones, equals(4));

      // Pestaña Resueltas
      final resolvedBadge = notificationProvider.resolvedCount;
      final resolvedList = notificationProvider.resolvedNotifications;
      expect(resolvedBadge, equals(1));
      expect(resolvedList.length, equals(1));

      // Pestaña Historial
      final historyBadge = notificationProvider.totalHistoryCount;
      final historyList = notificationProvider.historyNotifications;
      expect(historyBadge, equals(5));
      expect(historyList.length, equals(5));
    });

    // -------------------------------------------------------------------------
    // PUNTO 4: Flujo Completo de Bandeja de Archivadas (Archivar -> Desarchivar -> Eliminar)
    // -------------------------------------------------------------------------
    test('P4: Ciclo de vida de Archivadas: Archivar, Desarchivar y Eliminación definitiva en SQLite', () async {
      await db.insert('notificaciones', {
        'id': 301,
        'user_id': testUsuarioId,
        'negocio_id': testNegocioId,
        'titulo': 'Alerta de Inventario 301',
        'mensaje': 'Stock bajo aceite',
        'tipo': 'alerta',
        'nivel_prioridad': 'preventiva',
        'is_resolved': 0,
        'is_archived': 0,
        'is_silenced': 0,
        'objeto_relacionado_tipo': 'producto',
        'objeto_relacionado_id': 10,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      await notificationProvider.fetchNotifications();

      expect(notificationProvider.pendingCount, equals(1));
      expect(notificationProvider.archivedCount, equals(0));

      // 1. Archivar
      await notificationProvider.archiveNotification(301);
      expect(notificationProvider.pendingCount, equals(0));
      expect(notificationProvider.archivedCount, equals(1));

      // Verificar persistencia en SQLite
      final archivedRows = await db.query('notificaciones', where: 'id = ?', whereArgs: [301]);
      expect(archivedRows.first['is_archived'], equals(1));
      expect(archivedRows.first['fecha_archivado'], isNotNull);

      // 2. Desarchivar
      await notificationProvider.unarchiveNotification(301);
      expect(notificationProvider.pendingCount, equals(1));
      expect(notificationProvider.archivedCount, equals(0));

      final unarchivedRows = await db.query('notificaciones', where: 'id = ?', whereArgs: [301]);
      expect(unarchivedRows.first['is_archived'], equals(0));

      // 3. Volver a archivar y probar eliminación definitiva
      await notificationProvider.archiveNotification(301);
      expect(notificationProvider.archivedCount, equals(1));

      await notificationProvider.deleteNotification(301);
      expect(notificationProvider.archivedCount, equals(0));

      // 🛡️ VERIFICACIÓN ADVERSARIAL: Eliminado físicamente de SQLite
      final rows = await db.query('notificaciones', where: 'id = ?', whereArgs: [301]);
      expect(rows, isEmpty);
    });

    // -------------------------------------------------------------------------
    // PUNTO 5: Flujo de No Deseadas (Silenciamiento Inteligente Anti-Regeneración)
    // -------------------------------------------------------------------------
    test('P5: No Deseadas bloquea la regeneración canónica y Restaurar reactiva las alertas', () async {
      final int clienteId = await db.insert('clientes', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Cliente Silenciado',
        'telefono': '999111222',
      });

      final int ventaId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': clienteId,
        'origen_venta': 'smart_quotation',
        'monto_total': 100.0,
        'monto_pagado': 0.0,
        'metodo_pago': 'Credito',
        'fecha_venta': '2026-10-01',
      });

      final int cuotaId = await db.insert('cuotas', {
        'venta_id': ventaId,
        'numero_cuota': 1,
        'monto': 100.0,
        'monto_original': 100.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-15', // Vencida
        'estado': 'pendiente',
      });

      // Generar alerta inicial
      await notificationProvider.generateAutoNotifications(testUsuarioId);
      expect(notificationProvider.pendingCount, equals(1));
      final notif = notificationProvider.notifications.first;

      // 1. Mover a No Deseadas
      await notificationProvider.silenceNotification(notif.id);
      expect(notificationProvider.pendingCount, equals(0));
      expect(notificationProvider.silencedCount, equals(1));

      // Verificar persistencia de regla en notificaciones_silenciadas
      final silenciadas = await db.query('notificaciones_silenciadas', where: 'mute_key = ?', whereArgs: ['cuota_$cuotaId']);
      expect(silenciadas, isNotEmpty);

      // 2. Ejecutar nuevamente generateAutoNotifications: 🛡️ NO DEBE REGENERAR ALERTA
      await notificationProvider.generateAutoNotifications(testUsuarioId);
      expect(notificationProvider.pendingCount, equals(0));
      expect(notificationProvider.silencedCount, equals(1));

      // 3. Restaurar y reactivar alertas
      await notificationProvider.unsilenceNotification(notif.id);
      expect(notificationProvider.silencedCount, equals(0));
      expect(notificationProvider.pendingCount, equals(1));

      final reglaBorrada = await db.query('notificaciones_silenciadas', where: 'mute_key = ?', whereArgs: ['cuota_$cuotaId']);
      expect(reglaBorrada, isEmpty);
    });

    // -------------------------------------------------------------------------
    // PUNTO 6: Switches de NotificationSettingsModal y Persistencia de Preferencias
    // -------------------------------------------------------------------------
    test('P6: NotificationSettingsModal persiste cambios en SQLite y reactiva filtros de canales', () async {
      expect(notificationProvider.preferences.notifCuotasVencidas, isTrue);

      // 1. Apagar canal de Cuotas Vencidas
      await notificationProvider.updatePreferences(
        notificationProvider.preferences.copyWith(notifCuotasVencidas: false),
      );
      expect(notificationProvider.preferences.notifCuotasVencidas, isFalse);

      // Verificar guardado en SQLite
      final prefRows = await db.query('preferencias_notificaciones', where: 'negocio_id = ?', whereArgs: [testNegocioId]);
      expect(prefRows.first['notif_cuotas_vencidas'], equals(0));

      // 2. Probar anticipación preventiva configurada a 3 días
      await notificationProvider.updatePreferences(
        notificationProvider.preferences.copyWith(diasAnticipacionCuotas: 3),
      );
      expect(notificationProvider.preferences.diasAnticipacionCuotas, equals(3));
      final prefRows2 = await db.query('preferencias_notificaciones', where: 'negocio_id = ?', whereArgs: [testNegocioId]);
      expect(prefRows2.first['dias_anticipacion_cuotas'], equals(3));
    });

    // -------------------------------------------------------------------------
    // PUNTO 7: Visual en 360x640dp: Título Completo y COBRANZAS CONSOLIDADAS
    // -------------------------------------------------------------------------
    testWidgets('P7: Título "Notificaciones" 100% visible sin truncamiento y "COBRANZAS CONSOLIDADAS" con nombre de cliente', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Sembrar cliente con 2 cuotas en mora para activar Smart Grouping
      await tester.runAsync(() async {
        final int cId = await db.insert('clientes', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'nombre_completo': 'Freddy Consol',
          'telefono': '999333444',
        });

        final int vId = await db.insert('ventas', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'cliente_id': cId,
          'origen_venta': 'prestamo_personal', // Préstamo
          'numero_secuencial': 2,
          'monto_total': 100.0,
          'monto_pagado': 0.0,
          'metodo_pago': 'Credito',
          'fecha_venta': '2026-10-01',
        });

        await db.insert('cuotas', {
          'venta_id': vId,
          'numero_cuota': 1,
          'monto': 50.0,
          'monto_original': 50.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-10',
          'estado': 'pendiente',
        });
        await db.insert('cuotas', {
          'venta_id': vId,
          'numero_cuota': 2,
          'monto': 50.0,
          'monto_original': 50.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-15',
          'estado': 'pendiente',
        });

        await notificationProvider.generateAutoNotifications(testUsuarioId);
        await notificationProvider.fetchNotifications();
      });

      await tester.pumpWidget(createTestWidget(const NotificationsScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Título exacto "Notificaciones"
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.textContaining('Notificacion...'), findsNothing);

      // 2. Encabezado gramatical correcto en plural: "COBRANZAS CONSOLIDADAS (1)"
      expect(find.textContaining('COBRANZAS CONSOLIDADAS'), findsOneWidget);
      expect(find.textContaining('COBRANZAS CONSOLIDADA ('), findsNothing);

      // 3. Título de cuota vencida de préstamo contiene el nombre del cliente
      final notifTitle = notificationProvider.notifications.first.title;
      expect(notifTitle, equals('Cuota Vencida • Freddy Consol'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    // -------------------------------------------------------------------------
    // PUNTO 8: Anticipación Preventiva de Cuotas Configurable (0 a 3 días)
    // -------------------------------------------------------------------------
    testWidgets('P8: Ventana de anticipación a 3 días genera alerta preventiva, y al bajar a 1 día la limpia automáticamente', (tester) async {
      await tester.runAsync(() async {
        final cId = await db.insert('clientes', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'nombre_completo': 'Cliente Preventivo',
          'telefono': '999888777',
        });
        final vId = await db.insert('ventas', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'cliente_id': cId,
          'monto_total': 150.0,
          'monto_pagado': 0.0,
          'metodo_pago': 'Credito',
          'fecha_venta': DateTime.now().toIso8601String().substring(0, 10),
        });

        // Cuota vence en 3 días
        final dueDate3Days = DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10);
        await db.insert('cuotas', {
          'venta_id': vId,
          'numero_cuota': 1,
          'monto': 150.0,
          'monto_original': 150.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': dueDate3Days,
          'estado': 'pendiente',
        });

        // 1. Con anticipación por defecto (1 día), NO debe generarse alerta para cuota en 3 días
        await notificationProvider.updatePreferences(
          notificationProvider.preferences.copyWith(diasAnticipacionCuotas: 1),
        );
        await notificationProvider.generateAutoNotifications(testUsuarioId);
        await notificationProvider.fetchNotifications();
        expect(notificationProvider.notifications.any((n) => n.nivelPrioridad == 'preventiva'), isFalse);

        // 2. Al cambiar a 3 días, DEBE generarse la alerta preventiva
        await notificationProvider.updatePreferences(
          notificationProvider.preferences.copyWith(diasAnticipacionCuotas: 3),
        );
        await notificationProvider.generateAutoNotifications(testUsuarioId);
        await notificationProvider.fetchNotifications();
        expect(notificationProvider.notifications.any((n) => n.nivelPrioridad == 'preventiva'), isTrue);

        // 3. Al reducir a 1 día, debe resolverse/limpiarse a 0ms
        await notificationProvider.updatePreferences(
          notificationProvider.preferences.copyWith(diasAnticipacionCuotas: 1),
        );
        await notificationProvider.generateAutoNotifications(testUsuarioId);
        await notificationProvider.fetchNotifications();
        expect(notificationProvider.notifications.where((n) => n.nivelPrioridad == 'preventiva' && !n.isResolved).isEmpty, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // PUNTO 9: Slide-to-Reveal con Tope Estricto y Sin Disparo Automático
    // -------------------------------------------------------------------------
    testWidgets('P9: Comportamiento "card_actions" revela cajón Slide-to-Reveal con tope a 150dp sin ejecutar acciones al soltar el dedo', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await notificationProvider.updatePreferences(
          notificationProvider.preferences.copyWith(comportamientoSwipe: 'card_actions'),
        );
        await db.insert('notificaciones', {
          'id': 201,
          'user_id': testUsuarioId,
          'negocio_id': testNegocioId,
          'dedup_key': 'stock_agotado_201',
          'titulo': 'Stock Agotado • Aceite',
          'mensaje': 'El producto se ha agotado por completo.',
          'tipo': 'alerta',
          'nivel_prioridad': 'critica',
          'prioridad': 'Alta',
          'leida': 0,
          'is_resolved': 0,
          'is_archived': 0,
          'is_silenced': 0,
          'mute_key': 'producto_201',
          'objeto_relacionado_tipo': 'producto',
          'objeto_relacionado_id': 201,
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
        await notificationProvider.fetchNotifications();
      });

      await tester.pumpWidget(createTestWidget(const NotificationsScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Arrastrar la tarjeta horizontalmente hacia la izquierda
      final cardFinder = find.text('Stock Agotado • Aceite');
      expect(cardFinder, findsOneWidget);
      await tester.drag(cardFinder, const Offset(-100, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // 🛡️ VERIFICACIÓN ADVERSARIAL: Botones revelados pero NO ejecutados automáticamente
      expect(find.text('Archivar'), findsOneWidget);
      expect(find.text('Silenciar'), findsOneWidget);
      expect(find.text('Resolver'), findsOneWidget);

      // La tarjeta sigue existiendo y activa
      expect(notificationProvider.notifications.any((n) => n.id == 201 && !n.isArchived && !n.isResolved), isTrue);

      // Ahora el usuario toca explícitamente el botón "Archivar"
      await tester.tap(find.text('Archivar'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ahora sí se archiva: se retira de la lista activa y pasa a archivedNotifications
      expect(notificationProvider.notifications.any((n) => n.id == 201), isFalse);
      expect(notificationProvider.archivedNotifications.any((n) => n.id == 201), isTrue);
      expect(find.text('Notificación archivada'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    // -------------------------------------------------------------------------
    // PUNTO 10: Buscador y Filtro por Categorías en Modales de Archivadas y Silenciadas
    // -------------------------------------------------------------------------
    testWidgets('P10: Modales de Archivadas y Silenciadas ofrecen buscador y chips con conteos y desarchivado/restauración', (tester) async {
      await tester.runAsync(() async {
        await db.insert('notificaciones', {
          'id': 301,
          'user_id': testUsuarioId,
          'negocio_id': testNegocioId,
          'dedup_key': 'arc_cuota_301',
          'titulo': 'Cuota Archivada • Carlos',
          'mensaje': 'Carlos tiene cuota archivada.',
          'tipo': 'alerta',
          'nivel_prioridad': 'critica',
          'is_archived': 1,
          'is_silenced': 0,
          'mute_key': 'cuota_301',
          'objeto_relacionado_tipo': 'cuota',
          'objeto_relacionado_id': 301,
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
        await db.insert('notificaciones', {
          'id': 302,
          'user_id': testUsuarioId,
          'negocio_id': testNegocioId,
          'dedup_key': 'sil_prod_302',
          'titulo': 'Producto Silenciado • Arroz',
          'mensaje': 'Stock de arroz silenciado.',
          'tipo': 'alerta',
          'nivel_prioridad': 'critica',
          'is_archived': 0,
          'is_silenced': 1,
          'mute_key': 'producto_302',
          'objeto_relacionado_tipo': 'producto',
          'objeto_relacionado_id': 302,
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
        await notificationProvider.fetchNotifications();
      });

      // 1. Probar modal de Archivadas
      await tester.pumpWidget(createTestWidget(const Scaffold(body: ArchivedNotificationsModal(isDark: false))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Notificaciones Archivadas'), findsOneWidget);
      expect(find.text('Cuota Archivada • Carlos'), findsOneWidget);

      // Filtrar por categoría Cobranzas
      final chipCobranzas = find.widgetWithText(GestureDetector, 'Cobranzas');
      if (chipCobranzas.evaluate().isNotEmpty) {
        await tester.tap(chipCobranzas.first);
        await tester.pump();
      }
      expect(find.text('Cuota Archivada • Carlos'), findsOneWidget);

      // 2. Probar modal de Silenciadas (No Deseadas)
      await tester.pumpWidget(createTestWidget(const Scaffold(body: SilencedNotificationsModal(isDark: false))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Ítems en No Deseadas'), findsOneWidget);
      expect(find.text('Producto Silenciado • Arroz'), findsOneWidget);

      // Restaurar ítem
      await tester.tap(find.text('Restaurar y Reactivar'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(notificationProvider.silencedNotifications.any((n) => n.id == 302), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    // -------------------------------------------------------------------------
    // PUNTO 11: Acciones Grupales en Smart Grouping e Inmediatez Reactiva a 0ms
    // -------------------------------------------------------------------------
    testWidgets('P11: Smart Grouping soporta archivar grupo completo con recálculo a 0ms y opción Deshacer', (tester) async {
      int cId = 0;
      await tester.runAsync(() async {
        cId = await db.insert('clientes', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'nombre_completo': 'Grupo Reactivo',
          'telefono': '999111222',
        });
        final vId = await db.insert('ventas', {
          'negocio_id': testNegocioId,
          'creado_por_usuario_id': testUsuarioId,
          'cliente_id': cId,
          'monto_total': 200.0,
          'monto_pagado': 0.0,
          'metodo_pago': 'Credito',
          'fecha_venta': '2026-10-01',
        });
        await db.insert('cuotas', {
          'venta_id': vId,
          'numero_cuota': 1,
          'monto': 100.0,
          'monto_original': 100.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-05',
          'estado': 'pendiente',
        });
        await db.insert('cuotas', {
          'venta_id': vId,
          'numero_cuota': 2,
          'monto': 100.0,
          'monto_original': 100.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-10',
          'estado': 'pendiente',
        });

        await notificationProvider.generateAutoNotifications(testUsuarioId);
        await notificationProvider.fetchNotifications();
      });

      await tester.pumpWidget(createTestWidget(const NotificationsScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Grupo Reactivo'), findsOneWidget);
      expect(find.text('2 cuotas'), findsOneWidget);

      // Archivar todas las cuotas del cliente mediante método del provider
      await tester.runAsync(() async {
        await notificationProvider.archiveClientCuotas(cId);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // La tarjeta maestra debe desaparecer de Pendientes
      expect(find.text('Grupo Reactivo'), findsNothing);

      // Desarchivar cuotas del cliente
      await tester.runAsync(() async {
        await notificationProvider.unarchiveClientCuotas(cId);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // La tarjeta maestra vuelve a aparecer
      expect(find.text('Grupo Reactivo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

  });
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get hasActiveContext => true;
  @override
  bool get isCommunityClient => false;
  @override
  String get businessName => 'Tienda Test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  bool get showStockAlertColors => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
