import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_full_stats_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_compliance_sparkline.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

class MockTrackingProvider extends TrackingProvider {
  final List<SaleModel> mockedDebts;
  MockTrackingProvider(this.mockedDebts);

  @override
  List<SaleModel> get currentClientDebts => mockedDebts;

  @override
  bool get isLoadingDebts => false;

  @override
  Future<void> loadClientDebts(int clientId) async {
    // No-op for test
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Árbitro Adversarial: Remate Quirúrgico de Clientes', () {
    testWidgets('1. Desplegar acordeón en Pago Específico contrae de inmediato la cabecera y el banner a Sticky Mini-Header', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Rosa Flores',
        phone: '987654321',
        totalDebt: 300.0,
        registeredDate: '2026-10-21',
      );

      final List<SaleModel> multiDebts = [
        SaleModel(
          id: 101,
          sequentialNumber: 101,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientId: 1,
          paymentMethod: 'efectivo',
          paymentStatus: 'pendiente',
          deliveryStatus: 'entregado',
          totalAmount: 200.0,
          paidAmount: 50.0,
          discount: 0.0,
          saleDate: '2026-10-21',
          installments: [
            InstallmentModel(id: 1, installmentNumber: 1, amount: 100.0, montoPagado: 50.0, dueDate: '2026-11-01', status: 'pendiente'),
            InstallmentModel(id: 2, installmentNumber: 2, amount: 100.0, montoPagado: 0.0, dueDate: '2026-12-01', status: 'pendiente'),
          ],
        ),
        SaleModel(
          id: 102,
          sequentialNumber: 102,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientId: 1,
          paymentMethod: 'efectivo',
          paymentStatus: 'pendiente',
          deliveryStatus: 'entregado',
          totalAmount: 150.0,
          paidAmount: 0.0,
          discount: 0.0,
          saleDate: '2026-10-21',
          installments: [
            InstallmentModel(id: 3, installmentNumber: 1, amount: 150.0, montoPagado: 0.0, dueDate: '2026-11-15', status: 'pendiente'),
          ],
        ),
      ];

      final mockProvider = MockTrackingProvider(multiDebts);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<TrackingProvider>.value(value: mockProvider),
              ],
              child: PaymentEntryModal(client: client),
            ),
          ),
        ),
      );

      // Verificamos que se renderiza el modal
      expect(find.text('Registrar Abono'), findsOneWidget);

      // Cambiamos a la pestaña "Pago Específico"
      await tester.tap(find.text('Pago Específico'));
      await tester.pumpAndSettle();

      // En lista con 2 deudas no expandidas, inicialmente se ven los inputs completos
      expect(find.text('Monto a abonar'), findsOneWidget);
      expect(find.text('Selecciona la venta o cuota exacta que se amortizará.'), findsOneWidget);

      // El árbitro toca el acordeón de la Venta #101 para expandir sus cuotas
      await tester.tap(find.text('Venta #101 (A Crédito)'));
      await tester.pumpAndSettle();

      // VERIFICACIÓN DEL ÁRBITRO: Al desplegar cuotas, la cabecera se contrajo de inmediato en Sticky Mini-Header
      expect(find.text('Modificar'), findsOneWidget);
      expect(find.text('Monto a abonar'), findsNothing);

      // Seleccionamos la cuota #1
      await tester.tap(find.text('Cuota 1'));
      await tester.pumpAndSettle();

      // El Mini-Header debe mostrar el botón "Limpiar" y el monto exacto de la cuota (S/ 50.00)
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('S/ 50.00'), findsOneWidget);

      // Pulsamos "Limpiar" para deseleccionar
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();

      // "Limpiar" debe desaparecer al no haber cuota seleccionada
      expect(find.text('Limpiar'), findsNothing);
    });

    testWidgets('2. ClientFullStatsModal muestra Comparativa Compras vs Abonos, Ticket Promedio y Frecuencia Media', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<SaleSummary> mockSales = [
        SaleSummary(
          id: 1,
          sequentialNumber: 1,
          date: '2026-10-01T10:00:00Z',
          total: 100.0,
          montoPagado: 80.0,
          status: 'completado',
          itemsCount: 3,
        ),
        SaleSummary(
          id: 2,
          sequentialNumber: 2,
          date: '2026-10-08T10:00:00Z',
          total: 200.0,
          montoPagado: 120.0,
          status: 'completado',
          itemsCount: 5,
        ),
        SaleSummary(
          id: 3,
          sequentialNumber: 3,
          date: '2026-10-15T10:00:00Z',
          total: 150.0,
          montoPagado: 150.0,
          status: 'completado',
          itemsCount: 2,
        ),
      ];

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Carlos Mendoza',
        phone: '955444333',
        totalDebt: 100.0,
        registeredDate: '2026-10-01',
        lastSales: mockSales,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AuthProvider()),
              ],
              child: ClientFullStatsModal(client: client, isDark: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFICACIÓN DEL ÁRBITRO:
      // 1. Título y Header
      expect(find.text('Analítica del Cliente'), findsOneWidget);

      // 2. Tarjeta Visual de Comparativa Compras vs. Abonos
      expect(find.text('Comparativa Compras vs. Abonos'), findsOneWidget);
      expect(find.text('77.8% Cubierto'), findsOneWidget);
      expect(find.text('Total Compras'), findsOneWidget);
      expect(find.text('S/ 450.00'), findsOneWidget);
      expect(find.text('Total Abonos'), findsOneWidget);
      expect(find.text('S/ 350.00'), findsOneWidget);
      expect(find.text('Saldo Pendiente'), findsOneWidget);
      expect(find.text('S/ 100.00'), findsAtLeastNWidgets(1));

      // 3. Ticket Promedio (450 / 3 = 150.00)
      expect(find.text('Ticket Promedio'), findsOneWidget);
      expect(find.text('S/ 150.00'), findsAtLeastNWidgets(1));

      // 4. Frecuencia Media de Compra (intervalo de 14 días / 2 = 7 días = Semanal)
      expect(find.text('Frecuencia Media'), findsOneWidget);
      expect(find.text('Semanal (~7 días)'), findsOneWidget);

      // 5. N° de Compras
      expect(find.text('N° de Compras'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // 6. Tendencia Comercial (Sparkline interactivo con Min/Promedio/Max)
      expect(find.text('Tendencia Comercial'), findsOneWidget);
      expect(find.text('Mínimo'), findsOneWidget);
      expect(find.text('Promedio'), findsOneWidget);
      expect(find.text('Máximo'), findsOneWidget);
    });

    testWidgets('3. Auditoría 1 Sola Fila: PaymentEntryModal renderiza chips rápidos y strip de métodos sin saltos ni desbordamientos', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Carlos Mendoza',
        phone: '955444333',
        totalDebt: 258.57,
        registeredDate: '2026-10-01',
      );

      final List<SaleModel> debts = [
        SaleModel(
          id: 1,
          sequentialNumber: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientId: 1,
          paymentMethod: 'efectivo',
          paymentStatus: 'pendiente',
          deliveryStatus: 'entregado',
          totalAmount: 258.57,
          paidAmount: 0.0,
          discount: 0.0,
          saleDate: '2026-10-21',
          installments: [
            InstallmentModel(id: 1, installmentNumber: 1, amount: 15.0, montoPagado: 0.0, dueDate: '2026-11-01', status: 'pendiente'),
            InstallmentModel(id: 2, installmentNumber: 2, amount: 243.57, montoPagado: 0.0, dueDate: '2026-12-01', status: 'pendiente'),
          ],
        ),
      ];

      final mockProvider = MockTrackingProvider(debts);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<TrackingProvider>.value(value: mockProvider),
              ],
              child: PaymentEntryModal(client: client),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFICACIÓN DEL ÁRBITRO:
      // 1. Chips de monto rápido en 1 sola fila
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Cuota Ant.'), findsOneWidget);
      expect(find.text('50% Deuda'), findsOneWidget);

      // 2. Strip horizontal de métodos de pago con ShaderMask y AnimatedSize en cabecera
      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.text('Yape'), findsOneWidget);
      expect(find.text('Plin'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsWidgets);
      expect(find.byType(ShaderMask), findsWidgets);

      // 3. Tocar método al extremo derecho ("Transferencia") mediante scroll suave
      await tester.ensureVisible(find.text('Transferencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      expect(find.text('Transferencia'), findsOneWidget);

      // 4. Cero desbordamiento visual en pantalla angosta (360dp)
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Auditoría Blindaje Sticky Mini-Header: Scroll ascendente y rebote NO re-despliegan cabecera; Drag Down o Modificar SÍ', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Carlos Mendoza',
        phone: '955444333',
        totalDebt: 258.57,
        registeredDate: '2026-10-01',
      );

      final List<SaleModel> multiDebts = [
        SaleModel(
          id: 1,
          sequentialNumber: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientId: 1,
          paymentMethod: 'efectivo',
          paymentStatus: 'pendiente',
          deliveryStatus: 'entregado',
          totalAmount: 100.0,
          paidAmount: 0.0,
          discount: 0.0,
          saleDate: '2026-10-21',
          installments: [
            InstallmentModel(id: 1, installmentNumber: 1, amount: 50.0, montoPagado: 0.0, dueDate: '2026-11-01', status: 'pendiente'),
            InstallmentModel(id: 2, installmentNumber: 2, amount: 50.0, montoPagado: 0.0, dueDate: '2026-12-01', status: 'pendiente'),
          ],
        ),
        SaleModel(
          id: 2,
          sequentialNumber: 2,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientId: 1,
          paymentMethod: 'efectivo',
          paymentStatus: 'pendiente',
          deliveryStatus: 'entregado',
          totalAmount: 158.57,
          paidAmount: 0.0,
          discount: 0.0,
          saleDate: '2026-10-21',
          installments: [
            InstallmentModel(id: 3, installmentNumber: 1, amount: 158.57, montoPagado: 0.0, dueDate: '2026-11-15', status: 'pendiente'),
          ],
        ),
      ];

      final mockProvider = MockTrackingProvider(multiDebts);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<TrackingProvider>.value(value: mockProvider),
              ],
              child: PaymentEntryModal(client: client),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cambiar a Pago Específico
      await tester.tap(find.text('Pago Específico'));
      await tester.pumpAndSettle();

      // Compactar mediante el acordeón de Venta #1
      await tester.tap(find.text('Venta #1 (A Crédito)'));
      await tester.pumpAndSettle();

      // La cabecera está compactada en Mini-Header
      expect(find.text('Modificar'), findsOneWidget);
      expect(find.text('Monto a abonar'), findsNothing);

      // PRUEBA DEL ÁRBITRO ADVERSARIAL: Simular scroll hacia arriba agresivo y rebote en la lista
      await tester.drag(find.byType(ListView).last, const Offset(0, 300));
      await tester.pumpAndSettle();

      // VERIFICACIÓN CRÍTICA: La cabecera DEBE PERMANECER COMPACTA (cero re-expansión accidental)
      expect(find.text('Modificar'), findsOneWidget);
      expect(find.text('Monto a abonar'), findsNothing);

      // Ahora arrastramos hacia abajo directamente sobre el Sticky Mini-Header
      await tester.drag(find.text('Modificar'), const Offset(0, 60));
      await tester.pumpAndSettle();

      // VERIFICACIÓN: El gesto descendente sobre el mini-header SÍ re-despliega la cabecera
      expect(find.text('Monto a abonar'), findsOneWidget);
      expect(find.text('Compactar'), findsOneWidget);
    });

    testWidgets('5. Auditoría Cero Textos Cortados y Layout Antidesbordamiento en pantalla 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<SaleSummary> mockSales = [
        SaleSummary(
          id: 1,
          sequentialNumber: 1,
          date: '2026-10-01T10:00:00Z',
          total: 100.0,
          montoPagado: 21.2,
          status: 'completado',
          itemsCount: 2,
        ),
      ];

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Rosa Flores',
        phone: '987654321',
        totalDebt: 78.8,
        registeredDate: '2026-10-01',
        lastSales: mockSales,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AuthProvider()),
              ],
              child: ClientFullStatsModal(client: client, isDark: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFICACIÓN DEL ÁRBITRO:
      // 1. Título y Badge de Comparativa sin desbordamiento ni recorte
      expect(find.text('Comparativa Compras vs. Abonos'), findsOneWidget);
      expect(find.text('21.2% Cubierto'), findsOneWidget);

      // 2. Títulos KPI de Compras y Deuda con verificación adversarial de cero truncamiento visual
      final firstBatchKpiTitles = [
        'Ticket Promedio',
        'Frecuencia Media',
        'N° de Compras',
        'Última Compra',
        'Deuda Total',
        'Deuda (Solo Compras)',
      ];

      for (final title in firstBatchKpiTitles) {
        final finder = find.text(title);
        expect(finder, findsOneWidget);
        final renderParagraph = tester.renderObject<RenderParagraph>(finder);
        expect(
          renderParagraph.didExceedMaxLines, 
          isFalse, 
          reason: 'El título "$title" se truncó indebidamente con puntos suspensivos (...) en pantalla angosta de 360dp',
        );
      }

      // 3. Interactividad táctil en Comparativa: tocar Total Abonos
      await tester.tap(find.text('Total Abonos'));
      await tester.pumpAndSettle();

      // Debe mostrar el banner contextual interactivo
      expect(find.textContaining('Total Abonos: Amortiza el 21.2%'), findsOneWidget);

      // 4. Scroll hacia abajo en la lista para revelar la sección de Préstamos Personales
      await tester.scrollUntilVisible(
        find.text('Deuda por Préstamos'),
        200.0,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      final loanKpiTitles = [
        'Deuda por Préstamos',
        'Préstamos Activos',
        'Total Histórico Prestado',
      ];

      for (final title in loanKpiTitles) {
        final finder = find.text(title);
        expect(finder, findsOneWidget);
        final renderParagraph = tester.renderObject<RenderParagraph>(finder);
        expect(
          renderParagraph.didExceedMaxLines, 
          isFalse, 
          reason: 'El título "$title" se truncó indebidamente con puntos suspensivos (...) en pantalla angosta de 360dp',
        );
      }

      // 5. Cero excepciones de overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Auditoría Tendencia Comercial con 1 sola compra no inventa pendiente falsa y muestra datos contextuales', (tester) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<SaleSummary> singleSaleList = [
        SaleSummary(
          id: 1,
          sequentialNumber: 1,
          date: '2026-08-22T10:00:00Z',
          total: 23.57,
          montoPagado: 5.0,
          status: 'completado',
          itemsCount: 2,
        ),
      ];

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Cliente Único',
        phone: '999888777',
        totalDebt: 18.57,
        registeredDate: '2026-08-22',
        lastSales: singleSaleList,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AuthProvider()),
              ],
              child: ClientFullStatsModal(client: client, isDark: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFICACIÓN DEL ÁRBITRO:
      // 1. Tendencia Comercial presente
      expect(find.text('Tendencia Comercial'), findsOneWidget);

      // 2. Chips contextuales para compra única (NO Mínimo/Promedio/Máximo redundante)
      expect(find.text('Operación'), findsOneWidget);
      expect(find.text('Compra Única'), findsWidgets); // Aparece en Frecuencia y en Tendencia
      expect(find.text('22/08/2026'), findsWidgets); // Fecha visible en el eje X
      expect(find.text('Mínimo'), findsNothing); // Sin repetición absurda

      // 3. Cero desbordamientos
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Auditoría Coherencia Semántica de Color en Tendencia Comercial: Deuda Activa (Naranja/Ámbar) vs Excelente Historial (Verde/Teal)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<SaleSummary> singleSale = [
        SaleSummary(
          id: 1,
          sequentialNumber: 1,
          date: '2026-08-22T10:00:00Z',
          total: 50.0,
          montoPagado: 20.0,
          status: 'completado',
          itemsCount: 1,
        ),
      ];

      // Caso A: Cliente con Deuda Activa (totalDebt > 0)
      final clientConDeuda = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Cliente Moroso',
        phone: '999111222',
        totalDebt: 30.0,
        registeredDate: '2026-08-22',
        lastSales: singleSale,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientComplianceSparkline(
              client: clientConDeuda,
              sales: singleSale,
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deuda Activa'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);

      // Caso B: Cliente al día / Excelente Historial (totalDebt == 0)
      final clientAlDia = ClientModel(
        id: 2,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Cliente Puntual',
        phone: '999333444',
        totalDebt: 0.0,
        registeredDate: '2026-08-22',
        lastSales: singleSale,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientComplianceSparkline(
              client: clientAlDia,
              sales: singleSale,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excelente Historial'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
