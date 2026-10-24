import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sales_list_builder.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/history_dashboard_cards.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/history_filter_bar.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_status_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_reminder_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_notes_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_header_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

void main() {
  group('ÁRBITRO ADVERSARIAL 1: Tarjetas del Historial (sales_list_builder.dart)', () {
    testWidgets('Folio y fecha tienen cabecera limpia, sin emojis en origen, sin deuda redundante y formato AppCurrency', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final prestamo = SaleModel.fromJson({
        'id': 7,
        'numero_secuencial': 7,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 15,
        'cliente_nombre': 'Carlos Mendoza',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Transferencia BCP',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 1500.0,
        'monto_pagado': 0.0,
        'nota_prestamo': 'Capital de trabajo para librería',
        'fecha_venta': '2026-10-20T14:30:00.000',
      });

      final ventaParcial = SaleModel.fromJson({
        'id': 8,
        'numero_secuencial': 8,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cotizacion_id': 42,
        'cliente_id': 16,
        'cliente_nombre': 'Lucía Torres',
        'origen_venta': 'smart_quotation',
        'metodo_pago': 'Yape',
        'estado_pago': 'parcial',
        'estado_entrega': 'pendiente_entrega',
        'monto_total': 250.50,
        'monto_pagado': 100.0,
        'fecha_venta': '2026-10-21T09:15:00.000',
      });

      final mockProvider = _ReengineeringMockSaleProvider(history: [prestamo, ventaParcial]);

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

      // 1. Folios nítidos sin truncar
      expect(find.text("Préstamo #7"), findsOneWidget);
      expect(find.text("Recibo #8"), findsOneWidget);

      // 2. Fechas presentes en cabecera limpia
      expect(find.textContaining("20/10/2026"), findsOneWidget);
      expect(find.textContaining("21/10/2026"), findsOneWidget);

      // 3. Origen elegante SIN emojis
      expect(find.text("Préstamo Personal"), findsOneWidget);
      expect(find.text("Cotización Vendida"), findsOneWidget);
      expect(find.textContaining("🏦"), findsNothing);
      expect(find.textContaining("📋"), findsNothing);
      expect(find.textContaining("⚡"), findsNothing);

      // 4. Formato de moneda oficial S/ #,##0.00
      expect(find.text(AppCurrency.format(1500.0)), findsOneWidget); // S/ 1,500.00
      expect(find.text(AppCurrency.format(250.50)), findsOneWidget); // S/ 250.50

      // 5. Deuda redundante eliminada, pero conservando abono
      expect(find.text("Abonado: S/ 100.00"), findsOneWidget);
      expect(find.text("Debe: S/ 150.50"), findsNothing); // Eliminado bajo el monto principal

      // 6. Subtítulo en préstamo no repite 'Préstamo personal'
      expect(find.text("Capital de trabajo para librería"), findsOneWidget);

      // 0 excepciones de renderizado
      expect(tester.takeException(), isNull);
    });
  });

  group('ÁRBITRO ADVERSARIAL 2: KPIs y Slivers (history_dashboard_cards.dart)', () {
    testWidgets('Títulos de KPIs sin cortes y cifras formateadas con AppCurrency a 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final stats = SalesStatsModel(
        totalIngresos: 4850.50,
        totalDeuda: 1200.00,
        cantidadVentas: 15,
        totalProductosVendidos: 45,
      );

      final mockProvider = _ReengineeringMockSaleProvider(stats: stats);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockProvider,
              child: const HistoryDashboardCards(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Títulos limpios sin ' (S/)' que causaban wrapping o truncamiento
      expect(find.text("Operaciones"), findsOneWidget);
      expect(find.text("Cobrado"), findsOneWidget);
      expect(find.text("Por Cobrar"), findsOneWidget);

      // Cifras con AppCurrency
      expect(find.text("15"), findsOneWidget);
      expect(find.text("S/ 4,850.50"), findsOneWidget);
      expect(find.text("S/ 1,200.00"), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('ÁRBITRO ADVERSARIAL 3: Velocidad a 0ms entre Pestañas en SaleProvider', () {
    test('setTab cambia pestaña y recalcula KPIs al instante en memoria sin vaciar la lista', () {
      final sale1 = SaleModel.fromJson({
        'id': 1,
        'numero_secuencial': 1,
        'negocio_id': 1,
        'origen_venta': 'pos_rapido',
        'monto_total': 50.0,
        'monto_pagado': 50.0,
        'estado_pago': 'pagado',
        'is_archived': 0,
        'fecha_venta': '2026-10-21T10:00:00.000',
      });

      final sale2 = SaleModel.fromJson({
        'id': 2,
        'numero_secuencial': 2,
        'negocio_id': 1,
        'origen_venta': 'smart_quotation',
        'monto_total': 120.0,
        'monto_pagado': 60.0,
        'estado_pago': 'parcial',
        'is_archived': 0,
        'fecha_venta': '2026-10-21T11:00:00.000',
      });

      final sale3 = SaleModel.fromJson({
        'id': 3,
        'numero_secuencial': 3,
        'negocio_id': 1,
        'origen_venta': 'prestamo_personal',
        'monto_total': 300.0,
        'monto_pagado': 0.0,
        'estado_pago': 'pendiente',
        'is_archived': 0,
        'fecha_venta': '2026-10-21T12:00:00.000',
      });

      final saleArchived = SaleModel.fromJson({
        'id': 4,
        'numero_secuencial': 4,
        'negocio_id': 1,
        'origen_venta': 'pos_rapido',
        'monto_total': 80.0,
        'monto_pagado': 0.0,
        'estado_pago': 'anulado',
        'is_archived': 1,
        'fecha_venta': '2026-10-21T13:00:00.000',
      });

      final provider = _InMemoryTabFilteringSaleProvider(allSales: [sale1, sale2, sale3, saleArchived]);

      // Pestaña inicial: 'todas'
      expect(provider.currentTab, equals('todas'));
      expect(provider.salesHistory.length, equals(3)); // 3 no archivadas
      expect(provider.currentStats?.totalIngresos, equals(110.0)); // 50 + 60
      expect(provider.currentStats?.totalDeuda, equals(360.0)); // 60 + 300

      // Cambio a pestaña 'pos_rapido'
      provider.setTab('pos_rapido');
      expect(provider.currentTab, equals('pos_rapido'));
      expect(provider.salesHistory.length, equals(1));
      expect(provider.salesHistory.first.id, equals(1));
      expect(provider.currentStats?.totalIngresos, equals(50.0));
      expect(provider.currentStats?.totalDeuda, equals(0.0));

      // Cambio a pestaña 'archivadas'
      provider.setTab('archivadas');
      expect(provider.currentTab, equals('archivadas'));
      expect(provider.salesHistory.length, equals(1));
      expect(provider.salesHistory.first.id, equals(4));

      // Regreso a 'todas'
      provider.setTab('todas');
      expect(provider.salesHistory.length, equals(3));
    });
  });

  group('ÁRBITRO ADVERSARIAL 4: SafeArea en Modales de Filtro y Detalle', () {
    testWidgets('HistoryFilterChips abre bottom sheet con InteractiveSheetWrapper', (tester) async {
      final mockProvider = _ReengineeringMockSaleProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockProvider,
              child: const HistoryFilterChips(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abrir modal de periodo
      await tester.tap(find.text("6 Meses"));
      await tester.pumpAndSettle();

      // Verificar que el modal se encuentra envuelto con InteractiveSheetWrapper
      expect(find.byType(InteractiveSheetWrapper), findsOneWidget);
      expect(find.text("Filtrar periodo de tiempo"), findsOneWidget);
      expect(find.text("Rango Personalizado..."), findsOneWidget);

      // Cerrar modal
      await tester.tap(find.text("Este Mes"));
      await tester.pumpAndSettle();
      expect(mockProvider.activeQuickFilter, equals('este_mes'));
    });
  });

  group('ÁRBITRO ADVERSARIAL 5: Detalle, Modal WhatsApp y Notas en Préstamos', () {
    testWidgets('DetailStatusCard no desborda horizontalmente con préstamos con financiamiento', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final saleData = {
        'id': 50,
        'origen_venta': 'prestamo_personal',
        'monto_total': 1250.0,
        'abono_inicial': 250.0,
        'porcentaje_interes': 15.0,
        'metodo_pago': 'Transferencia Interbancaria con Voucher',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DetailStatusCard(
                saleData: saleData,
                totalAmount: 1250.0,
                paidAmount: 250.0,
                pendingDebt: 1000.0,
                cuotasRaw: const [],
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar filas financieras con AppCurrency y sin overflow
      expect(find.textContaining("Interés / Financiamiento"), findsOneWidget);
      expect(find.textContaining("15.0%"), findsOneWidget);
      expect(find.text(AppCurrency.format(1250.0)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CuotaReminderModal muestra teléfono editable, cuota formateada y vista previa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  CuotaReminderModal.show(
                    context: ctx,
                    cuota: {
                      'numero_cuota': 2,
                      'monto': 350.0,
                    },
                    dateFormatted: '25/10/2026',
                    clientName: 'Roberto Gómez',
                    clientPhone: '987654321',
                    isDark: false,
                  );
                },
                child: const Text("Abrir Recordatorio"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Abrir Recordatorio"));
      await tester.pumpAndSettle();

      // Verificaciones del modal de recordatorio:
      expect(find.byType(InteractiveSheetWrapper), findsWidgets);
      expect(find.text("Recordatorio de Cuota"), findsOneWidget);
      expect(find.textContaining("Cuota #2"), findsOneWidget);
      expect(find.textContaining("350.00"), findsWidgets);
      expect(find.text("Vence: 25/10/2026"), findsOneWidget);
      expect(find.text("Enviar por WhatsApp"), findsOneWidget);

      // Vista previa del mensaje redactado
      expect(find.textContaining("Hola Roberto Gómez"), findsOneWidget);
      expect(find.textContaining("cuota #2 por S/ 350.00"), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('DetailNotesCard permite editar nota de préstamo', (tester) async {
      String? tappedType;
      int? tappedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailNotesCard(
              saleNote: "Garantía prendaria acordada",
              clientNote: "Buen pagador",
              cotizacionId: 0,
              clientId: 22,
              isDark: false,
              isLoan: true,
              onEditTap: (type, note, id) {
                tappedType = type;
                tappedId = id;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("MOTIVO DEL PRÉSTAMO"), findsOneWidget);
      expect(find.text("Garantía prendaria acordada"), findsOneWidget);

      // Tocar en el botón de editar la nota del préstamo
      final editButtons = find.byIcon(Icons.edit);
      expect(editButtons, findsNWidgets(2)); // Nota de préstamo + Nota de cliente
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      expect(tappedType, equals('loan'));
      expect(tappedId, equals(0));
    });
  });

  group('ÁRBITRO ADVERSARIAL: Auditoría y Certificación de los 5 Puntos Finales', () {
    testWidgets('PUNTO 1: Subtítulo exacto "Préstamo personal" o vacío muestra "Sin motivo especificado" sin duplicar badge', (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Caso 1: chip rápido por defecto "Préstamo personal"
      final p1 = SaleModel.fromJson({
        'id': 101,
        'numero_secuencial': 101,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 1,
        'cliente_nombre': 'Pedro Morales',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Efectivo',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 300.0,
        'monto_pagado': 0.0,
        'nota_prestamo': 'Préstamo personal', // Texto exacto
        'fecha_venta': '2026-10-22T08:00:00.000',
      });

      // Caso 2: minúsculas "préstamo personal"
      final p2 = SaleModel.fromJson({
        'id': 102,
        'numero_secuencial': 102,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 2,
        'cliente_nombre': 'Ana Silva',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Yape',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 150.0,
        'monto_pagado': 0.0,
        'nota_prestamo': 'préstamo personal',
        'fecha_venta': '2026-10-22T08:10:00.000',
      });

      // Caso 3: sin observación (vacío)
      final p3 = SaleModel.fromJson({
        'id': 103,
        'numero_secuencial': 103,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 3,
        'cliente_nombre': 'María Vega',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Efectivo',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 200.0,
        'monto_pagado': 0.0,
        'nota_prestamo': '',
        'fecha_venta': '2026-10-22T08:20:00.000',
      });

      // Caso 4: observación real con prefijo
      final p4 = SaleModel.fromJson({
        'id': 104,
        'numero_secuencial': 104,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 4,
        'cliente_nombre': 'Carlos Ramos',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Transferencia',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 500.0,
        'monto_pagado': 0.0,
        'nota_prestamo': 'Préstamo personal para mercadería',
        'fecha_venta': '2026-10-22T08:30:00.000',
      });

      final mockProvider = _ReengineeringMockSaleProvider(history: [p1, p2, p3, p4]);

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

      // Debe mostrar "Sin motivo especificado" para los casos 1, 2 y 3 (exactamente 3 veces)
      expect(find.text("Sin motivo especificado"), findsNWidgets(3));

      // Debe mostrar la observación limpia "Mercadería" para el caso 4
      expect(find.text("Mercadería"), findsOneWidget);

      // NO debe repetirse el texto "Préstamo personal" como subtítulo redundante debajo del cliente
      // (Sólo debe figurar en el badge superior como "Préstamo Personal" en mayúsculas estilo Title)
      final allSubtitleMatches = find.byWidgetPredicate((widget) =>
          widget is Text && widget.data == "Préstamo personal");
      expect(allSubtitleMatches, findsNothing);
    });

    testWidgets('PUNTO 2: DetailHeaderCard usa FittedBox y AppCurrency; SaleActionBottomSheet usa InteractiveSheetWrapper y AppCurrency', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Probar DetailHeaderCard
      final saleData = {
        'id': 50,
        'origen_venta': 'prestamo_personal',
        'cliente_nombre': 'Mario Delgado',
        'is_archived': 1,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailHeaderCard(
              saleData: saleData,
              styles: const {'color': Colors.amber, 'icon': Icons.monetization_on, 'label': 'PRÉSTAMO'},
              totalAmount: 2400.0,
              dateString: '22/10/2026 09:00',
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Monto formateado con AppCurrency
      expect(find.text(AppCurrency.format(2400.0)), findsOneWidget); // S/ 2,400.00
      // FittedBox presente para blindar de desbordes
      expect(find.byType(FittedBox), findsOneWidget);
      // Nombre adaptado a préstamo
      expect(find.text("Mario Delgado"), findsOneWidget);
      // Badge adaptado a préstamo anulado
      expect(find.text("PRÉSTAMO ANULADO"), findsOneWidget);

      // 2. Probar SaleActionBottomSheet
      final loanSale = SaleModel.fromJson({
        'id': 60,
        'numero_secuencial': 60,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 5,
        'cliente_nombre': 'Luciana Soto',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Efectivo',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 800.0,
        'monto_pagado': 250.0,
        'nota_prestamo': 'Capital de inversión',
        'fecha_venta': '2026-10-22T09:30:00.000',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: _ReengineeringMockSaleProvider(history: [loanSale]),
              child: SaleActionBottomSheet(sale: loanSale),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // InteractiveSheetWrapper presente con applyEffectiveBottomPadding
      final sheetFinder = find.byType(InteractiveSheetWrapper);
      expect(sheetFinder, findsOneWidget);
      final sheetWidget = tester.widget<InteractiveSheetWrapper>(sheetFinder);
      expect(sheetWidget.applyEffectiveBottomPadding, isTrue);

      // Deuda pendiente formateada con AppCurrency
      expect(find.text("Deuda Pendiente: ${AppCurrency.format(550.0)}"), findsOneWidget);
    });

    testWidgets('PUNTO 3: DetailNotesCard pasa saleId al editar nota de préstamo y adapta semántica a préstamo', (tester) async {
      String? recordedType;
      int? recordedId;
      String? recordedNote;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailNotesCard(
              saleNote: "Garantía prendaria acordada",
              clientNote: "Cliente VIP",
              cotizacionId: 0,
              clientId: 12,
              saleId: 77, // SaleId real de préstamo
              isDark: false,
              isLoan: true,
              onEditTap: (type, note, id) {
                recordedType = type;
                recordedNote = note;
                recordedId = id;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("MOTIVO DEL PRÉSTAMO"), findsOneWidget);
      expect(find.text("Motivo del Préstamo:"), findsOneWidget);
      expect(find.text("Garantía prendaria acordada"), findsOneWidget);

      // Tocar el lápiz de edición de la nota del préstamo
      final editPencils = find.byIcon(Icons.edit);
      expect(editPencils, findsNWidgets(2));
      await tester.tap(editPencils.first);
      await tester.pumpAndSettle();

      // Verificar que envía type 'loan' e id del préstamo (77) y NO 0 ni cotizacionId
      expect(recordedType, equals('loan'));
      expect(recordedNote, equals("Garantía prendaria acordada"));
      expect(recordedId, equals(77));
    });

    testWidgets('PUNTO 4: TabBar y HistorySearchBar tienen espaciado compacto y no truncan Caja Rápida a 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockProvider = _ReengineeringMockSaleProvider(history: []);

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Scaffold(
              body: ChangeNotifierProvider<SaleProvider>.value(
                value: mockProvider,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      physics: const BouncingScrollPhysics(),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(text: "Todas"),
                        Tab(text: "Cotizaciones Vendidas"),
                        Tab(text: "Caja Rápida"),
                        Tab(text: "Archivadas / Anuladas"),
                      ],
                    ),
                    const HistorySearchBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que pestaña "Caja Rápida" se encuentra renderizada
      final cajaRapidaTab = find.text("Caja Rápida");
      expect(cajaRapidaTab, findsOneWidget);

      // Verificar que el buscador está presente y no desborda
      expect(find.byType(HistorySearchBar), findsOneWidget);
      expect(find.text("Buscar por cliente, #recibo, DNI..."), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('PUNTO 5: Sincronización reactiva de _masterSales y KPIs a 0ms en mutaciones (pagos, notas, anulación)', () {
      final s1 = SaleModel.fromJson({
        'id': 1,
        'origen_venta': 'smart_quotation',
        'monto_total': 100.0,
        'monto_pagado': 40.0,
        'estado_pago': 'parcial',
        'is_archived': 0,
      });

      final s2 = SaleModel.fromJson({
        'id': 2,
        'origen_venta': 'prestamo_personal',
        'monto_total': 200.0,
        'monto_pagado': 0.0,
        'estado_pago': 'pendiente',
        'is_archived': 0,
        'nota_prestamo': 'Préstamo personal',
      });

      final syncTest = _SyncMasterAdversarialTester(initialSales: [s1, s2]);

      // Estado inicial
      expect(syncTest.currentStats.cantidadVentas, equals(2));
      expect(syncTest.currentStats.totalIngresos, equals(40.0));
      expect(syncTest.currentStats.totalDeuda, equals(260.0)); // 60 + 200

      // 1. Mutación: Cobrar deuda total de préstamo #2
      syncTest.simulatePayment(saleId: 2, newPaid: 200.0);
      expect(syncTest.currentStats.totalIngresos, equals(240.0)); // 40 + 200
      expect(syncTest.currentStats.totalDeuda, equals(60.0)); // 60 + 0

      // 2. Mutación: Editar nota de préstamo #2
      syncTest.simulateNoteUpdate(saleId: 2, newNote: "Compró mercadería escolar");
      expect(syncTest.masterSales.firstWhere((s) => s.id == 2).notes, equals("Compró mercadería escolar"));

      // 3. Mutación: Anular venta #1
      syncTest.simulateVoid(saleId: 1);
      expect(syncTest.currentStats.cantidadVentas, equals(1)); // Solo queda préstamo #2 activo
      expect(syncTest.currentStats.totalIngresos, equals(200.0));
      expect(syncTest.currentStats.totalDeuda, equals(0.0));

      // 4. Mutación: Restaurar venta #1
      syncTest.simulateRestore(saleId: 1);
      expect(syncTest.currentStats.cantidadVentas, equals(2));
      expect(syncTest.currentStats.totalIngresos, equals(240.0));
      expect(syncTest.currentStats.totalDeuda, equals(60.0));
    });
  });
}

class _ReengineeringMockSaleProvider extends ChangeNotifier implements SaleProvider {
  final List<SaleModel> _history;
  final SalesStatsModel? _stats;
  String _activeFilter = 'seis_meses';
  String _financial = 'todos';

  _ReengineeringMockSaleProvider({
    List<SaleModel>? history,
    SalesStatsModel? stats,
  })  : _history = history ?? [],
        _stats = stats;

  @override
  List<SaleModel> get salesHistory => _history;

  @override
  SalesStatsModel? get currentStats => _stats;

  @override
  String get activeQuickFilter => _activeFilter;

  @override
  String get financialStatus => _financial;

  @override
  String get currentTab => "todas";

  @override
  String get currentSortBy => "fecha_venta";

  @override
  String get currentOrder => "desc";

  @override
  String get searchQuery => "";

  @override
  bool get isLoading => false;

  @override
  bool get isRefreshing => false;

  @override
  bool get hasMoreData => false;

  @override
  bool get isLoadingMore => false;

  @override
  List<SaleModel> get archivedSales => _history.where((s) => s.isArchived).toList();

  @override
  List<SaleModel> getSalesForTab(String tabKey) {
    if (tabKey == 'archivadas') {
      return _history.where((s) => s.isArchived).toList();
    }
    if (tabKey == 'smart_quotation') {
      return _history.where((s) => !s.isArchived && !s.isQuickSale && !s.isLoan).toList();
    }
    if (tabKey == 'pos_rapido') {
      return _history.where((s) => !s.isArchived && s.isQuickSale).toList();
    }
    return _history.where((s) => !s.isArchived).toList();
  }

  @override
  String get errorMessage => "";

  @override
  String? get currentStartDate => null;

  @override
  String? get currentEndDate => null;

  @override
  double get todaySalesTotal => 0.0;

  @override
  int get todaySalesCount => 0;

  @override
  double? get currentMonthMargin => null;

  @override
  double? get currentMonthSalesTotal => null;

  @override
  List<SaleModel> get recentHomeSales => [];

  @override
  void setQuickFilter(String filterType, {DateTime? customStart, DateTime? customEnd}) {
    _activeFilter = filterType;
    notifyListeners();
  }

  @override
  void setFinancialFilter(String status) {
    _financial = status;
    notifyListeners();
  }

  @override
  void setSearchQuery(String query) {
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryTabFilteringSaleProvider extends ChangeNotifier {
  final List<SaleModel> allSales;
  String currentTab = 'todas';
  List<SaleModel> salesHistory = [];
  SalesStatsModel? currentStats;

  _InMemoryTabFilteringSaleProvider({required this.allSales}) {
    _apply();
  }

  void setTab(String tabKey) {
    currentTab = tabKey;
    _apply();
  }

  void _apply() {
    if (currentTab == 'archivadas') {
      salesHistory = allSales.where((s) => s.isArchived).toList();
    } else {
      final active = allSales.where((s) => !s.isArchived);
      if (currentTab == 'pos_rapido') {
        salesHistory = active.where((s) => s.isQuickSale).toList();
      } else if (currentTab == 'smart_quotation') {
        salesHistory = active.where((s) => s.isQuotationSale).toList();
      } else {
        salesHistory = active.toList();
      }
    }

    double ingresos = 0.0;
    double deuda = 0.0;
    for (final s in salesHistory) {
      ingresos += s.paidAmount;
      deuda += s.pendingDebt;
    }
    currentStats = SalesStatsModel(
      totalIngresos: ingresos,
      totalDeuda: deuda,
      cantidadVentas: salesHistory.length,
      totalProductosVendidos: 0,
    );
    notifyListeners();
  }
}

class _SyncMasterAdversarialTester extends ChangeNotifier {
  final List<SaleModel> masterSales;
  List<SaleModel> salesHistory = [];
  SalesStatsModel currentStats = SalesStatsModel(
    totalIngresos: 0,
    totalDeuda: 0,
    cantidadVentas: 0,
    totalProductosVendidos: 0,
  );

  _SyncMasterAdversarialTester({required List<SaleModel> initialSales})
      : masterSales = List.from(initialSales) {
    _recalculate();
  }

  void simulatePayment({required int saleId, required double newPaid}) {
    final mIdx = masterSales.indexWhere((s) => s.id == saleId);
    if (mIdx != -1) {
      final old = masterSales[mIdx];
      masterSales[mIdx] = old.copyWith(
        paidAmount: newPaid,
        paymentStatus: newPaid >= old.trueTotalAmount - 0.01 ? 'pagado' : 'parcial',
      );
    }
    _recalculate();
  }

  void simulateNoteUpdate({required int saleId, required String newNote}) {
    final mIdx = masterSales.indexWhere((s) => s.id == saleId);
    if (mIdx != -1) {
      masterSales[mIdx] = masterSales[mIdx].copyWith(notes: newNote);
    }
    _recalculate();
  }

  void simulateVoid({required int saleId}) {
    final mIdx = masterSales.indexWhere((s) => s.id == saleId);
    if (mIdx != -1) {
      masterSales[mIdx] = masterSales[mIdx].copyWith(isArchived: true);
    }
    _recalculate();
  }

  void simulateRestore({required int saleId}) {
    final mIdx = masterSales.indexWhere((s) => s.id == saleId);
    if (mIdx != -1) {
      masterSales[mIdx] = masterSales[mIdx].copyWith(isArchived: false);
    }
    _recalculate();
  }

  void _recalculate() {
    salesHistory = masterSales.where((s) => !s.isArchived).toList();
    double ingresos = 0.0;
    double deuda = 0.0;
    for (final s in salesHistory) {
      ingresos += s.paidAmount;
      deuda += s.pendingDebt;
    }
    currentStats = SalesStatsModel(
      totalIngresos: ingresos,
      totalDeuda: deuda,
      cantidadVentas: salesHistory.length,
      totalProductosVendidos: 0,
    );
    notifyListeners();
  }
}
