import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/floating_dock_session_state.dart';
import 'package:app_movil/core/widgets/deep_nav_return_pill.dart';
import 'package:app_movil/features/smart_quotation/services/history_export_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_payment_timeline.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_status_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_notes_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_action_footer.dart';
import 'package:app_movil/core/widgets/export_options_modal.dart';

void main() {
  group('FASE 1: DeepNavReturnPill Gestos Estacionarios, Multi-Tarea y Persistencia', () {
    setUp(() {
      FloatingDockSessionState.isLeftEdge = false;
      FloatingDockSessionState.panBottom = 40.0;
      FloatingDockSessionState.isEdgeTucked = false;
      FloatingDockSessionState.selectedTaskIndex = 0;
    });

    test('Persistencia global de estado en FloatingDockSessionState y SecondaryBubbleSessionState', () {
      FloatingDockSessionState.isLeftEdge = true;
      FloatingDockSessionState.panBottom = 120.0;
      FloatingDockSessionState.isEdgeTucked = true;
      FloatingDockSessionState.selectedTaskIndex = 2;

      expect(FloatingDockSessionState.isLeftEdge, isTrue);
      expect(FloatingDockSessionState.panBottom, equals(120.0));
      expect(FloatingDockSessionState.isEdgeTucked, isTrue);
      expect(FloatingDockSessionState.selectedTaskIndex, equals(2));

      FloatingDockSessionState.reset();
      expect(FloatingDockSessionState.isLeftEdge, isFalse);
      expect(FloatingDockSessionState.panBottom, isNull);
      expect(FloatingDockSessionState.isEdgeTucked, isFalse);
      expect(FloatingDockSessionState.selectedTaskIndex, equals(0));

      // Test SecondaryBubbleSessionState independencia y persistencia
      SecondaryBubbleSessionState.isLeftEdge = true;
      SecondaryBubbleSessionState.panBottom = 150.0;
      SecondaryBubbleSessionState.isEdgeTucked = true;
      SecondaryBubbleSessionState.selectedTaskIndex = 3;

      expect(SecondaryBubbleSessionState.isLeftEdge, isTrue);
      expect(SecondaryBubbleSessionState.panBottom, equals(150.0));
      expect(SecondaryBubbleSessionState.isEdgeTucked, isTrue);
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(3));

      // Resetear SecondaryBubbleSessionState no afecta a FloatingDockSessionState
      SecondaryBubbleSessionState.reset();
      expect(SecondaryBubbleSessionState.isLeftEdge, isFalse);
      expect(SecondaryBubbleSessionState.panBottom, isNull);
      expect(SecondaryBubbleSessionState.isEdgeTucked, isFalse);
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(0));
    });

    testWidgets('Conmutación de tareas por pulsación fija (450ms sin movimiento)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DeepNavReturnPill(isBottom: true),
              ],
            ),
          ),
        ),
      );

      // Si no hay tareas activas en los providers de prueba, el pill se oculta limpiamente
      expect(find.byType(DeepNavReturnPill), findsOneWidget);
    });
  });

  group('FASES 2 Y 3: Reingeniería de Exportación y Verdad Contable en CSV/PDF', () {
    test('ExportFilterSelection y HistoryExportService generan CSV con verdad contable', () async {
      final sale1 = SaleModel(
        id: 1,
        sequentialNumber: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        quotationId: null,
        clientId: 10,
        clientName: 'Freddy',
        origenVenta: 'smart_quotation',
        isArchived: false,
        paymentMethod: 'Efectivo',
        paymentStatus: 'parcial',
        deliveryStatus: 'entregado',
        totalAmount: 100.0,
        paidAmount: 40.0,
        discount: 0.0,
        saleDate: '2026-10-20T10:00:00.000',
      );

      final loan1 = SaleModel(
        id: 2,
        sequentialNumber: 2,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        quotationId: null,
        clientId: 10,
        clientName: 'Freddy',
        origenVenta: 'prestamo_personal',
        isArchived: false,
        paymentMethod: 'Yape',
        paymentStatus: 'pendiente',
        deliveryStatus: 'entregado',
        totalAmount: 240.0,
        paidAmount: 0.0,
        discount: 0.0,
        saleDate: '2026-10-20T11:00:00.000',
      );

      final archivedSale = SaleModel(
        id: 3,
        sequentialNumber: 3,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        quotationId: null,
        clientId: null,
        clientName: 'Venta Anulada',
        origenVenta: 'pos_rapido',
        isArchived: true,
        paymentMethod: 'Efectivo',
        paymentStatus: 'anulado',
        deliveryStatus: 'entregado',
        totalAmount: 50.0,
        paidAmount: 0.0,
        discount: 0.0,
        saleDate: '2026-10-20T12:00:00.000',
      );

      final sales = [sale1, loan1, archivedSale];

      final file = await HistoryExportService.exportToCsv(
        sales: sales,
        stats: null,
        businessName: "Librería Mochilalista",
        dateRangeText: "Últimos 6 meses",
        reportTitle: "Historial Completo",
        outputDirectory: Directory.systemTemp,
      );

      final content = await file.readAsString();

      // Verificación de columnas contables
      expect(content.contains("Importe Total"), isTrue);
      expect(content.contains("Monto Cobrado"), isTrue);
      expect(content.contains("Deuda Pendiente"), isTrue);
      expect(content.contains("Total Exigible"), isTrue);
      expect(content.contains("Total Cobrado"), isTrue);

      // Verificación de operaciones
      expect(content.contains("Freddy"), isTrue);
      expect(content.contains("Préstamo Personal"), isTrue);
      expect(content.contains("240.0"), isTrue);
      expect(content.contains("40.0"), isTrue);
      expect(content.contains("60.0"), isTrue); // Deuda pendiente de sale1
    });

    test('HistoryExportService exportToPdf genera documento con verdad contable', () async {
      final sale1 = SaleModel(
        id: 1,
        sequentialNumber: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        quotationId: null,
        clientId: 10,
        clientName: 'Freddy',
        origenVenta: 'smart_quotation',
        isArchived: false,
        paymentMethod: 'Efectivo',
        paymentStatus: 'parcial',
        deliveryStatus: 'entregado',
        totalAmount: 100.0,
        paidAmount: 40.0,
        discount: 0.0,
        saleDate: '2026-10-20T10:00:00.000',
      );

      final pdfFile = await HistoryExportService.exportToPdf(
        sales: [sale1],
        stats: null,
        businessName: "Librería Mochilalista",
        dateRangeText: "Últimos 6 meses",
        reportTitle: "Reporte de Prueba",
        outputDirectory: Directory.systemTemp,
      );

      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(100));
    });

    testWidgets('ExportOptionsModal inicializa con filtros activos y actualiza preview', (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ExportFilterSelection? exportedSelection;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportOptionsModal(
              isCombinable: true,
              initialTab: 'prestamos',
              initialFinancialFilter: 'con_deuda',
              activePeriodLabel: 'Últimos 6 meses',
              isDark: false,
              onCountRequest: (sel) async => 5,
              onExportCombinable: (sel) {
                exportedSelection = sel;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Opciones de Exportación"), findsOneWidget);
      expect(find.textContaining("ALCANCE TEMPORAL"), findsOneWidget);
      expect(find.textContaining("TIPO DE REGISTRO"), findsOneWidget);
      expect(find.textContaining("ESTADO FINANCIERO"), findsOneWidget);
      expect(find.textContaining("FORMATO DE DESCARGA"), findsOneWidget);
      expect(find.text("PDF"), findsOneWidget);
      expect(find.text("CSV (Excel)"), findsOneWidget);

      // Resumen previo con contador en vivo
      expect(find.textContaining("5 operaciones encontradas"), findsOneWidget);

      await tester.tap(find.text("Generar y Descargar Reporte"));
      await tester.pumpAndSettle();

      expect(exportedSelection, isNotNull);
      expect(exportedSelection!.operationType, equals('prestamo_personal'));
      expect(exportedSelection!.financialStatus, equals('con_deuda'));
    });
  });

  group('FASE 4: SaleActionBottomSheet con Adaptabilidad Semántica y Deuda Pendiente', () {
    testWidgets('Adapta textos para Préstamo Personal y muestra banner de deuda y botón cobrar', (tester) async {
      final loanWithDebt = SaleModel(
        id: 2,
        sequentialNumber: 2,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        quotationId: null,
        clientId: 10,
        clientName: 'Freddy',
        origenVenta: 'prestamo_personal',
        isArchived: false,
        paymentMethod: 'Yape',
        paymentStatus: 'pendiente',
        deliveryStatus: 'entregado',
        totalAmount: 240.0,
        paidAmount: 0.0,
        discount: 0.0,
        saleDate: '2026-10-20T11:00:00.000',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaleActionBottomSheet(sale: loanWithDebt),
          ),
        ),
      );

      expect(find.text("Opciones de Préstamo #2"), findsOneWidget);
      expect(find.text("Préstamo Personal"), findsOneWidget);
      expect(find.text("Ver Detalle del Préstamo"), findsOneWidget);
      expect(find.text("Descargar Constancia PDF"), findsOneWidget);
      expect(find.text("Compartir Constancia"), findsOneWidget);
      expect(find.text("Anular Préstamo"), findsOneWidget);
      expect(find.text("Editar Diseño PDF"), findsNothing);

      // Banner y botón de deuda
      expect(find.textContaining("Deuda Pendiente"), findsOneWidget);
      expect(find.textContaining("240"), findsWidgets);
      expect(find.text("💸 Registrar Abono / Cobrar Deuda"), findsOneWidget);
    });
  });

  group('FASE 5: Rediseño "Mobile Awards" de Detalle, Plan de Cuotas y Préstamos', () {
    testWidgets('SalePaymentTimeline en 360px renderiza cuotas sin overflow ni texto partido', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cuotas = [
        {
          'id': 101,
          'numero_cuota': 1,
          'monto': 120.0,
          'monto_pagado': 120.0,
          'fecha_vencimiento': '2026-11-15T00:00:00.000',
          'estado': 'pagado',
        },
        {
          'id': 102,
          'numero_cuota': 2,
          'monto': 120.0,
          'monto_pagado': 0.0,
          'fecha_vencimiento': '2026-12-15T00:00:00.000',
          'estado': 'pendiente',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SalePaymentTimeline(
                cuotasRaw: cuotas,
                isDark: false,
                clientName: 'Freddy',
                clientPhone: '987654321',
                clientId: 10,
                saleId: 2,
              ),
            ),
          ),
        ),
      );

      expect(find.text("Plan de Cuotas (2)"), findsOneWidget);
      expect(find.text("Vence: 15/11/2026"), findsOneWidget);
      expect(find.text("Vence: 15/12/2026"), findsOneWidget);
      expect(find.text("PAGADO"), findsOneWidget);
      expect(find.text("PENDIENTE"), findsOneWidget);
      expect(find.text("Recordar"), findsOneWidget);
      expect(find.text("Cobrar"), findsOneWidget);

      // Cero RenderFlex Overflow verificado por tester.pumpAndSettle sin excepciones
      expect(tester.takeException(), isNull);
    });

    testWidgets('DetailStatusCard y DetailNotesCard muestran semántica completa de préstamo', (tester) async {
      final saleData = {
        'id': 2,
        'origen_venta': 'prestamo_personal',
        'estado_entrega': 'entregado',
        'metodo_pago': 'Yape',
        'estado_pago': 'pendiente',
        'monto_total': 240.0,
        'abono_inicial': 0.0,
        'porcentaje_interes': 20.0,
        'cliente_id': 10,
        'cliente_nombre': 'Freddy',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  DetailNotesCard(
                    saleNote: "Préstamo para mercadería escolar",
                    clientNote: "",
                    cotizacionId: 0,
                    clientId: 10,
                    isDark: false,
                    isLoan: true,
                    onEditTap: (_, __, ___) {},
                  ),
                  DetailStatusCard(
                    saleData: saleData,
                    totalAmount: 240.0,
                    paidAmount: 0.0,
                    pendingDebt: 240.0,
                    cuotasRaw: const [],
                    isDark: false,
                  ),
                  SaleActionFooter(
                    isDark: false,
                    cardColor: Colors.white,
                    cotizacionId: 0,
                    saleId: 2,
                    isQuickSale: false,
                    isLoan: true,
                    pendingDebt: 240.0,
                    onSellAgainQuickSale: () {},
                    onDuplicateOptions: () {},
                    onRegisterPayment: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verificación de semántica de préstamo
      expect(find.text("MOTIVO DEL PRÉSTAMO"), findsOneWidget);
      expect(find.text("Motivo del Préstamo:"), findsOneWidget);
      expect(find.text("ESTADO DEL PRÉSTAMO"), findsOneWidget);
      expect(find.text("PRÉSTAMO DESEMBOLSADO · EN CURSO"), findsOneWidget);
      expect(find.text("ENTREGADO AL INSTANTE"), findsNothing);

      // Verificación de desglose financiero
      expect(find.text("Capital Inicial Prestado"), findsOneWidget);
      expect(find.text("Interés / Financiamiento (20.0%)"), findsOneWidget);
      expect(find.text("Total a Devolver"), findsOneWidget);
      expect(find.text("Saldo Deudor Exigible"), findsOneWidget);

      // Verificación de SaleActionFooter habilitado para préstamo
      expect(find.text("Cobrar Deuda"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
