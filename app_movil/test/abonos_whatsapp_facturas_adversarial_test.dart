import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/scanner/providers/invoice_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart';
import 'package:app_movil/features/scanner/widgets/shared/download_feedback_modal.dart';
import 'package:app_movil/features/scanner/screens/invoice_detail_screen.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

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

class _MockTrackingProvider extends ChangeNotifier implements TrackingProvider {
  List<SaleModel> debts = [];

  @override
  bool get isLoadingDebts => false;

  @override
  List<SaleModel> get currentClientDebts => debts;

  @override
  Future<void> loadClientDebts(int clientId, {bool forcePeriodicMorosidad = true}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInvoiceProvider extends ChangeNotifier implements InvoiceProvider {
  InvoiceModel? testInvoice;

  @override
  Future<InvoiceModel?> getInvoiceDetail(int id) async {
    return testInvoice;
  }

  @override
  Future<List<Map<String, dynamic>>> getLinkedPresentations(int id) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  String getProviderName(int? id) => 'BAZAR LIBRERIA DEL PACIFICO';

  @override
  List<ProviderModel> get providers => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestApp({
  required Widget child,
  _MockTrackingProvider? trackingProv,
  _MockAuthProvider? authProv,
  QuickSaleProvider? quickProv,
  _MockSaleProvider? saleProv,
  _MockInvoiceProvider? invoiceProv,
  _MockInventoryProvider? inventoryProv,
  Size size = const Size(360, 800),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TrackingProvider>.value(
        value: trackingProv ?? _MockTrackingProvider(),
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
      ChangeNotifierProvider<InvoiceProvider>.value(
        value: invoiceProv ?? _MockInvoiceProvider(),
      ),
      ChangeNotifierProvider<InventoryProvider>.value(
        value: inventoryProv ?? _MockInventoryProvider(),
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

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  late Database db;
  late ClientService clientService;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    clientService = ClientService();

    // Negocio base
    await db.insert('negocios', {
      'id': 1,
      'nombre_comercial': 'Librería Central',
      'moneda': 'S/ (Soles)',
    });

    // Cliente base
    await db.insert('clientes', {
      'id': 1,
      'negocio_id': 1,
      'creado_por_usuario_id': 1,
      'nombre_completo': 'Jj',
      'telefono': '922836879',
      'deuda_total': 3173.0,
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

  group('SUITE ADVERSARIAL: Auditoría de Abonos FIFO, WhatsApp y Exportación de Facturas', () {
    test('TC-01: Paridad y orden FIFO estricto (fecha_vencimiento ASC) en registerPayment entre Préstamo #13 y Préstamo #14', () async {
      // Préstamo #13 (vencimiento 24/10 y 31/10)
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
        'fecha_venta': '2026-10-15 10:00:00',
        'created_at': '2026-10-15 10:00:00',
      });

      await db.insert('cuotas', {
        'id': 101,
        'venta_id': 13,
        'numero_cuota': 1,
        'monto': 300.0,
        'monto_original': 300.0,
        'monto_pagado': 0.0,
        'mora_monto': 0.0,
        'fecha_vencimiento': '2026-10-24',
        'estado': 'pendiente',
      });

      await db.insert('cuotas', {
        'id': 102,
        'venta_id': 13,
        'numero_cuota': 2,
        'monto': 305.0,
        'monto_original': 300.0,
        'monto_pagado': 0.0,
        'mora_monto': 5.0,
        'fecha_vencimiento': '2026-10-31',
        'estado': 'pendiente',
      });

      // Préstamo #14 (vencimiento posterior: 02/11)
      await db.insert('ventas', {
        'id': 14,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 14,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 1968.00,
        'monto_pagado': 0.00,
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-10-20 10:00:00',
        'created_at': '2026-10-20 10:00:00',
      });

      await db.insert('cuotas', {
        'id': 202,
        'venta_id': 14,
        'numero_cuota': 2,
        'monto': 528.0,
        'monto_original': 480.0,
        'monto_pagado': 0.0,
        'mora_monto': 48.0,
        'fecha_vencimiento': '2026-11-02',
        'estado': 'pendiente',
      });

      // Aplicamos un abono automático de S/ 300.00
      final success = await clientService.registerPayment(
        1,
        300.00,
        'efectivo',
        1,
        1,
      );

      expect(success, isTrue);

      // Verificamos que los S/ 300.00 se aplicaron a la Cuota 1 del Préstamo #13 (vencida 24/10),
      // y NO a la Cuota 2 del Préstamo #14 (vencida 02/11)
      final cuota13_1 = (await db.query('cuotas', where: 'id = ?', whereArgs: [101])).first;
      expect(cuota13_1['monto_pagado'], equals(300.0));
      expect(cuota13_1['estado'], equals('pagado'));

      final cuota14_2 = (await db.query('cuotas', where: 'id = ?', whereArgs: [202])).first;
      expect(cuota14_2['monto_pagado'], equals(0.0));
      expect(cuota14_2['estado'], equals('pendiente'));
    });

    test('TC-02: Extinción de cuota saldada, paso a estado pagado y apagado de mora_automatica', () async {
      await db.insert('ventas', {
        'id': 15,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 15,
        'origen_venta': 'venta_credito',
        'metodo_pago': 'efectivo',
        'monto_total': 305.00,
        'monto_pagado': 0.00,
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-10-15 10:00:00',
        'created_at': '2026-10-15 10:00:00',
      });

      await db.insert('cuotas', {
        'id': 301,
        'venta_id': 15,
        'numero_cuota': 1,
        'monto': 305.0,
        'monto_original': 300.0,
        'monto_pagado': 0.0,
        'mora_monto': 5.0,
        'mora_automatica': 1,
        'fecha_vencimiento': '2026-10-31',
        'estado': 'pendiente',
      });

      // Pago total de la cuota con mora (S/ 305.00)
      final success = await clientService.registerPayment(
        1,
        305.00,
        'efectivo',
        1,
        1,
        ventaId: 15,
        cuotaId: 301,
      );

      expect(success, isTrue);

      final cuota = (await db.query('cuotas', where: 'id = ?', whereArgs: [301])).first;
      expect(cuota['monto_pagado'], equals(305.0));
      expect(cuota['estado'], equals('pagado'));
      expect(cuota['mora_automatica'], equals(0));
    });

    test('TC-03: Cascada inteligente de excedente en Pago Específico a siguientes cuotas del mismo préstamo', () async {
      await db.insert('ventas', {
        'id': 14,
        'negocio_id': 1,
        'cliente_id': 1,
        'creado_por_usuario_id': 1,
        'numero_secuencial': 14,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'efectivo',
        'monto_total': 1008.00,
        'monto_pagado': 0.00,
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-10-02 00:00:00',
        'created_at': '2026-11-07 14:00:00',
      });

      // Cuota 2: S/ 528.00 (S/ 480 base + S/ 48 mora)
      await db.insert('cuotas', {
        'id': 402,
        'venta_id': 14,
        'numero_cuota': 2,
        'monto': 528.0,
        'monto_original': 480.0,
        'monto_pagado': 0.0,
        'mora_monto': 48.0,
        'fecha_vencimiento': '2026-11-02',
        'estado': 'pendiente',
      });

      // Cuota 3: S/ 480.00
      await db.insert('cuotas', {
        'id': 403,
        'venta_id': 14,
        'numero_cuota': 3,
        'monto': 480.0,
        'monto_original': 480.0,
        'monto_pagado': 0.0,
        'mora_monto': 0.0,
        'fecha_vencimiento': '2026-11-17',
        'estado': 'pendiente',
      });

      // Abono específico a Cuota 2 con sobrepago: S/ 600.00 (Excedente de S/ 72.00)
      final success = await clientService.registerPayment(
        1,
        600.00,
        'efectivo',
        1,
        1,
        ventaId: 14,
        cuotaId: 402,
      );

      expect(success, isTrue);

      final cuota2 = (await db.query('cuotas', where: 'id = ?', whereArgs: [402])).first;
      expect(cuota2['monto_pagado'], equals(528.0));
      expect(cuota2['estado'], equals('pagado'));

      // El excedente de S/ 72.00 debe haberse aplicado a la Cuota 3
      final cuota3 = (await db.query('cuotas', where: 'id = ?', whereArgs: [403])).first;
      expect(cuota3['monto_pagado'], equals(72.0));
      expect(cuota3['estado'], equals('parcial'));
    });

    testWidgets('TC-04: Sincronización de carrusel dinámico de 5 etiquetas y selección animada en PaymentEntryModal', (tester) async {
      final mockTracking = _MockTrackingProvider();
      mockTracking.debts = [
        SaleModel(
          id: 13,
          sequentialNumber: 13,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientId: 1,
          clientName: 'Jj',
          origenVenta: 'prestamo_personal',
          paymentMethod: 'efectivo',
          paymentStatus: 'pendiente',
          deliveryStatus: 'entregado',
          totalAmount: 1205.0,
          paidAmount: 600.0,
          discount: 0.0,
          saleDate: '2026-10-15',
          installments: [
            InstallmentModel(
              id: 101,
              installmentNumber: 1,
              dueDate: '2026-10-24', // Vencida
              amount: 300.0,
              montoOriginal: 300.0,
              montoPagado: 0.0,
              moraMonto: 0.0,
              status: 'pendiente',
            ),
            InstallmentModel(
              id: 102,
              installmentNumber: 2,
              dueDate: '2026-10-31', // Vencida
              amount: 305.0,
              montoOriginal: 300.0,
              montoPagado: 0.0,
              moraMonto: 5.0,
              status: 'pendiente',
            ),
          ],
        ),
      ];

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Jj',
        phone: '922836879',
        totalDebt: 605.0,
        saldoAFavor: 0.0,
        pendingDeliveryCount: 0,
        registeredDate: '2026-11-01',
        nivelConfianza: 'BRONCE',
        etiquetas: [],
      );

      await tester.pumpWidget(
        _buildTestApp(
          trackingProv: mockTracking,
          child: PaymentEntryModal(
            client: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que el carrusel contiene las etiquetas configuradas
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Cuota Ant.'), findsOneWidget);
      expect(find.text('Total Vencido'), findsOneWidget);
      expect(find.text('50% Deuda'), findsOneWidget);

      // Tocar en "Cuota Ant." (S/ 300.00)
      await tester.tap(find.text('Cuota Ant.'));
      await tester.pumpAndSettle();

      // El campo de monto debe tener S/ 300.00
      expect(find.text('300.00'), findsWidgets);

      // Verificar que la etiqueta seleccionada tiene el checkmark animado
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
    });

    testWidgets('TC-05: Sincronización de deuda exigible con morosidad (S/ 3,173.00) y alternancia entre 4 plantillas en WhatsAppPreviewModal', (tester) async {
      final cuotas = [
        {
          'id': 101,
          'numero_cuota': 1,
          'monto': 300.0,
          'monto_original': 300.0,
          'mora_monto': 0.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-24',
        },
        {
          'id': 102,
          'numero_cuota': 2,
          'monto': 305.0,
          'monto_original': 300.0,
          'mora_monto': 5.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-31',
        },
        {
          'id': 202,
          'numero_cuota': 2,
          'monto': 528.0,
          'monto_original': 480.0,
          'mora_monto': 48.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-11-02',
        },
        {
          'id': 203,
          'numero_cuota': 3,
          'monto': 2040.0,
          'monto_original': 2040.0,
          'mora_monto': 0.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-11-17',
        },
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: WhatsAppPreviewModal(
            key: const ValueKey('wa_test_modal'),
            initialClientName: 'Jj',
            initialClientPhone: '922836879',
            isDark: true,
            totalDebt: 3173.0,
            multipleCuotas: cuotas,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verificar presencia de las 4 plantillas
      expect(find.text('📋 Cobranza Formal'), findsOneWidget);
      expect(find.text('🤝 Recordatorio Amable'), findsOneWidget);
      expect(find.text('🚨 Aviso con Mora'), findsOneWidget);
      expect(find.text('⚡ Resumen Breve'), findsOneWidget);

      // 2. Verificar suma total exacta con moras (S/ 3,173.00)
      expect(find.textContaining('S/ 3,173.00'), findsWidgets);

      // 3. Alternar a "🤝 Recordatorio Amable"
      await tester.ensureVisible(find.text('🤝 Recordatorio Amable'));
      await tester.tap(find.text('🤝 Recordatorio Amable'));
      await tester.pumpAndSettle();
      final tf1 = tester.widget<TextField>(find.byType(TextField));
      expect(tf1.controller?.text, contains('Esperamos que se encuentre muy bien'));

      // 4. Alternar a "🚨 Aviso con Mora"
      await tester.ensureVisible(find.text('🚨 Aviso con Mora'));
      await tester.tap(find.text('🚨 Aviso con Mora'));
      await tester.pumpAndSettle();
      final tf2 = tester.widget<TextField>(find.byType(TextField));
      expect(tf2.controller?.text, contains('AVISO URGENTE: CUOTAS EN MOROSIDAD'));

      // 5. Alternar a "⚡ Resumen Breve"
      await tester.ensureVisible(find.text('⚡ Resumen Breve'));
      await tester.tap(find.text('⚡ Resumen Breve'));
      await tester.pumpAndSettle();
      final tf3 = tester.widget<TextField>(find.byType(TextField));
      expect(tf3.controller?.text, contains('RESUMEN DE CUOTAS PENDIENTES'));
    });

    testWidgets('TC-06: Toggles de Chips Modulares en WhatsAppPreviewModal agregan y remueven secciones dinámicamente', (tester) async {
      final cuotas = [
        {
          'id': 101,
          'numero_cuota': 1,
          'monto': 305.0,
          'monto_original': 300.0,
          'mora_monto': 5.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-10-31',
        },
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: WhatsAppPreviewModal(
            initialClientName: 'Jj',
            initialClientPhone: '922836879',
            isDark: true,
            totalDebt: 305.0,
            multipleCuotas: cuotas,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Por defecto Cuentas Abono está deshabilitado
      expect(find.text('+ Cuentas Abono'), findsOneWidget);

      // Tocar en "+ Cuentas Abono" para activarlo
      await tester.tap(find.text('+ Cuentas Abono'));
      await tester.pumpAndSettle();

      // Ahora el chip debe estar activo y el texto debe reflejarse en el editor
      expect(find.text('✓ Cuentas Abono'), findsOneWidget);
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, contains('Canales oficiales de abono'));

      // Desactivar "Desglose Cuotas"
      await tester.tap(find.text('✓ Desglose Cuotas'));
      await tester.pumpAndSettle();
      expect(find.text('+ Desglose Cuotas'), findsOneWidget);
      expect(tf.controller?.text.contains('*Detalle de cuotas:*'), isFalse);
    });

    testWidgets('TC-07: InvoiceDetailScreen no contiene botones duplicados en AppBar y dispone de pantalla completa y detección de descargas', (tester) async {
      final mockInv = _MockInvoiceProvider();
      mockInv.testInvoice = InvoiceModel(
        id: 19,
        numeroSecuencial: 19,
        negocioId: 1,
        imagenUrl: 'sample_path.jpg',
        estado: 'completado',
        fechaCarga: DateTime(2026, 10, 13, 21, 27),
        proveedorId: 1,
        montoTotalFactura: 435.40,
        fechaEmision: DateTime(2026, 3, 12),
        datosCrudosIaJson: {
          'items': [
            {'descripcion': 'BIBLIA LATINOAM UNIMUNDO', 'precio': 35.0}
          ]
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          invoiceProv: mockInv,
          child: const InvoiceDetailScreen(invoiceId: 19),
        ),
      );
      // Avanzar frames para permitir la resolución del detalle de factura
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verificar título en AppBar
      expect(find.text('Factura #19'), findsOneWidget);

      // 2. En AppBar.actions debe haber ÚNICAMENTE InfoTooltipButton (no los 2 IconButtons duplicados)
      final appBarFinder = find.byType(AppBar);
      final appBar = tester.widget<AppBar>(appBarFinder);
      expect(appBar.actions?.length, equals(1));
      expect(appBar.actions?.first, isA<InfoTooltipButton>());

      // 3. Botones principales de Descarga en el cuerpo (reflejan estado dinámico: Descargar / Guardado)
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Descargar Foto' ||
                  widget.data == '✓ Foto Guardada'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Reporte PDF' || widget.data == '✓ PDF Guardado'),
        ),
        findsOneWidget,
      );

      // 4. Botón de Pantalla Completa en el visor superior
      expect(find.text('Pantalla Completa'), findsOneWidget);
    });

    testWidgets('TC-08: DownloadFeedbackModal protege la extensión .PDF y provee botón de Compartir', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('ml_test_invoice_');
      final tempFile = File('${tempDir.path}/Factura_19_Reporte_BAZAR_LIBRERIA_DEL_PACIFICO_20261106_214205.pdf');
      tempFile.writeAsStringSync('test pdf content');

      await tester.pumpWidget(
        _buildTestApp(
          child: DownloadFeedbackModal(
            title: 'Reporte PDF',
            loadingMessage: 'Generando archivo...',
            downloadTask: () async => tempFile,
          ),
        ),
      );

      // Aguardamos la resolución del task evitando pumpAndSettle por animación continua
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // Verificar estado de éxito
      expect(find.text('¡Descarga Exitosa!'), findsOneWidget);

      // Verificar que la extensión PDF se muestra en su badge protegido
      expect(find.text('.PDF'), findsOneWidget);

      // Verificar que los 3 botones están presentes: Cerrar, Compartir y Abrir
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.text('Abrir'), findsOneWidget);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
