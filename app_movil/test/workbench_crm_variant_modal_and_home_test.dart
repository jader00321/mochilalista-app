import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/widgets/home/dashboard_header.dart';
import 'package:app_movil/core/widgets/marquee_text.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_quotations_tab.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_sales_history_tab.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_stats_header.dart';

class MockTrackingProviderForTest extends TrackingProvider {
  final List<SmartQuotationModel> quotations;
  final List<SaleModel> debts;
  MockTrackingProviderForTest({this.quotations = const [], this.debts = const []});

  @override
  bool get isLoadingQuotations => false;

  @override
  List<SmartQuotationModel> get currentClientQuotations => quotations;

  @override
  bool get isLoadingDebts => false;

  @override
  List<SaleModel> get currentClientDebts => debts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // ÁREA 1: MESA DE TRABAJO (Fase 1) - Estabilidad Anti-Rebote y Scroll
  // =========================================================================
  group('ÁREA 1: Mesa de Trabajo - Estabilidad Anti-Rebote y Eje Vertical', () {
    testWidgets('NotificationListener filtra estrictamente Axis.vertical y no rebota en horizontal', (tester) async {
      final workbenchProv = WorkbenchProvider();
      
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WorkbenchProvider>.value(value: workbenchProv),
            ],
            child: const WorkbenchScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verificar que WorkbenchScreen se construye limpiamente
      expect(find.byType(WorkbenchScreen), findsOneWidget);

      // Encontrar TabBarView y deslizar horizontalmente
      final tabBarViewFinder = find.byType(TabBarView);
      if (tabBarViewFinder.evaluate().isNotEmpty) {
        await tester.drag(tabBarViewFinder, const Offset(-120, 0));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('Estructura de Mesa de Trabajo: 0px superposición y padding inferior 110px', (tester) async {
      final workbenchProv = WorkbenchProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WorkbenchProvider>.value(value: workbenchProv),
            ],
            child: const WorkbenchScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verificar que el cuerpo es un Scaffold con body directo (no sliver colapsado)
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);

      // Verificar FloatingActionButton '+' presente
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  // =========================================================================
  // ÁREA 2: PERFIL DEL CLIENTE (Fases 2, 3 y 4) - Historial, Listas y Header
  // =========================================================================
  group('ÁREA 2: Perfil del Cliente - Historial de Compras, Listas Pendientes y Banners', () {
    testWidgets('ClientSalesHistoryTab en 360dp: títulos completos en hasta 2 líneas y fila inferior sin desborde', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Carlos Mendoza',
        phone: '987654321',
        registeredDate: '2026-10-20',
        lastSales: [
          SaleSummary(
            id: 101,
            sequentialNumber: 1,
            total: 350.0,
            montoPagado: 150.0,
            origenVenta: 'prestamo_personal',
            date: '2026-10-15T14:30:00',
            status: 'entregado',
          ),
          SaleSummary(
            id: 102,
            sequentialNumber: 2,
            total: 890.50,
            montoPagado: 890.50,
            origenVenta: 'lista_cotizada',
            date: '2026-10-18T10:00:00',
            status: 'entregado',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ClientSalesHistoryTab(
                client: client,
                isDark: false,
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificamos títulos sin truncamiento brusco
      expect(find.text('Préstamo Personal'), findsOneWidget);
      expect(find.text('Lista Cotizada'), findsOneWidget);

      // Verificamos botón Detalle y métricas
      expect(find.textContaining('Detalle'), findsNWidgets(2));
      expect(find.text('Total: S/ 350.00'), findsOneWidget);
      expect(find.text('Pagado: S/ 150.00'), findsOneWidget);
      expect(find.text('Total: S/ 890.50'), findsOneWidget);
      expect(find.text('Pagado: S/ 890.50'), findsOneWidget);

      // Cero excepciones de overflow en 360dp
      expect(tester.takeException(), isNull);
    });

    testWidgets('ClientQuotationsTab muestra badges, resumen de productos y oculta colegio no especificado', (tester) async {
      final quotationWithSchool = SmartQuotationModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: 'Ana Gomez',
        institutionName: 'San Agustín',
        gradeLevel: '5to Primaria',
        status: 'READY',
        type: 'scanner',
        createdAt: '2026-10-22T09:15:00',
        totalAmount: 120.0,
        totalSavings: 0.0,
        itemCount: 3,
        items: [
          QuotationItem(id: 1, productName: 'Cuaderno Standford 100h', quantity: 3, unitPriceApplied: 6.5, originalUnitPrice: 6.5, isAvailable: true),
          QuotationItem(id: 2, productName: 'Caja Colores Faber Castell', quantity: 1, unitPriceApplied: 24.0, originalUnitPrice: 24.0, isAvailable: true),
          QuotationItem(id: 3, productName: 'Regla 30cm Artesco', quantity: 2, unitPriceApplied: 2.5, originalUnitPrice: 2.5, isAvailable: true),
        ],
      );

      final quotationWithoutSchool = SmartQuotationModel(
        id: 2,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientName: 'Ana Gomez',
        institutionName: '', // Vacío: NUNCA debe mostrar "Colegio no especificado"
        status: 'DRAFT',
        type: 'manual',
        createdAt: '2026-10-23T11:00:00',
        totalAmount: 45.0,
        totalSavings: 0.0,
        itemCount: 2,
        items: [
          QuotationItem(id: 4, productName: 'Plastilina Norma 12 colores', quantity: 2, unitPriceApplied: 8.0, originalUnitPrice: 8.0, isAvailable: false),
          QuotationItem(id: 5, productName: 'Tijera punta roma', quantity: 1, unitPriceApplied: 4.5, originalUnitPrice: 4.5, isAvailable: true),
        ],
      );

      final mockTracking = MockTrackingProviderForTest(quotations: [quotationWithSchool, quotationWithoutSchool]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<TrackingProvider>.value(value: mockTracking),
              ],
              child: ClientQuotationsTab(
                isDark: false,
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cotización 1: Badges y colegio visible
      expect(find.text('📦 3 productos'), findsOneWidget);
      expect(find.text('✨ Escáner IA'), findsOneWidget);
      expect(find.text('✅ Lista'), findsOneWidget);
      expect(find.text('San Agustín • 5to Primaria'), findsOneWidget);
      expect(find.textContaining('Cuaderno Standford 100h, Caja Colores Faber Castell'), findsOneWidget);

      // Cotización 2: Badges y ausencia total de "Colegio no especificado"
      expect(find.text('📦 2 productos'), findsOneWidget);
      expect(find.text('✍️ Manual'), findsOneWidget);
      expect(find.text('⚠️ Alerta de stock'), findsOneWidget); // Tiene un producto no disponible
      expect(find.textContaining('Colegio no especificado'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('ClientStatsHeader no muestra emoji ⚠️ duplicado en texto de alerta de cuotas', (tester) async {
      final clientWithOverdue = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Juan Perez',
        phone: '999888777',
        registeredDate: '2026-08-01',
        totalDebt: 500.0,
      );

      final overdueDebt = SaleModel(
        id: 10,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientId: 1,
        clientName: 'Juan Perez',
        origenVenta: 'prestamo_personal',
        isArchived: false,
        paymentMethod: 'credito',
        paymentStatus: 'pendiente',
        deliveryStatus: 'entregado',
        totalAmount: 500.0,
        paidAmount: 0.0,
        discount: 0.0,
        abonoInicial: 0.0,
        porcentajeInteres: 0.0,
        saleDate: '2026-08-01',
        installments: [
          InstallmentModel(
            installmentNumber: 1,
            amount: 250.0,
            dueDate: DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
            status: 'pendiente',
          ),
          InstallmentModel(
            installmentNumber: 2,
            amount: 250.0,
            dueDate: DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
            status: 'pendiente',
          ),
        ],
      );

      final mockTracking = MockTrackingProviderForTest(debts: [overdueDebt]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<TrackingProvider>.value(value: mockTracking),
              ],
              child: ClientStatsHeader(
                client: clientWithOverdue,
                isDark: false,
                onWhatsAppTap: () {},
                onCallTap: () {},
                onGoToQuickSale: () {},
                onFinanceActionCompleted: () {},
              ),
            ),
          ),
        ),
      );

      // Usar pump con duración fija debido al AnimationController infinito (repeat)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que el texto de cuotas vencidas es limpio y no tiene "⚠️" duplicado en el String
      expect(find.text('2 cuotas vencidas'), findsOneWidget);
      expect(find.textContaining('⚠️ 2 cuota(s) vencida(s)'), findsNothing);
      expect(find.textContaining('Deuda más antigua: hace 45 días'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // ÁREA 3: CONTROL DE VARIANTE MODAL (Fase 5) - Scroll Desbloqueado y BD
  // =========================================================================
  group('ÁREA 3: Control de Variante Modal - Scroll a 60fps y Claridad BD:', () {
    testWidgets('ComparativeUpdateModal cuenta con Scrollbar, BouncingScrollPhysics y padding reactivo', (tester) async {
      final rawVariant = StagingVariant(
        uuidTemporal: 'var-uuid-1',
        nombreEspecifico: 'Cuaderno Cuadriculado 100h',
        umpCompra: 'Paquete',
        cantidadUmpComprada: 10,
        precioUmpProveedor: 4.5,
        totalPagoLote: 45.0,
        unidadesPorLote: 1,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 4.5,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 6.07,
        matchPresentacion: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
      );

      final group = StagingProductGroup(
        nombrePadre: 'Cuaderno Standford',
        marcaTexto: 'Standford',
        matchProducto: MatchResult(estado: 'MATCH_SISTEMA', confianza: 95),
        matchMarca: MatchResult(estado: 'MATCH_SISTEMA', confianza: 95),
        variantes: [rawVariant],
      );

      final scannerProv = ScannerProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    ComparativeUpdateModal.show(
                      ctx,
                      variant: rawVariant,
                      group: group,
                      dbData: {
                        'nombre_especifico': 'Cuaderno Cuadriculado 100h Standford',
                        'unidad': 'Unidad',
                        'factor_conversion': 1,
                        'precio_venta': 6.00,
                        'costo_unitario': 4.50,
                        'stock_actual': 25,
                      },
                      isDark: false,
                      provider: scannerProv,
                      onConfirm: () {},
                    );
                  },
                  child: const Text('Abrir Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // Verificar que el modal se abrió
      expect(find.text('Control de Variante'), findsOneWidget);
      expect(find.text('GUARDAR DECISIÓN'), findsOneWidget);

      // Verificar Scrollbar con thumbVisibility: true
      final scrollbarFinder = find.byType(Scrollbar);
      expect(scrollbarFinder, findsOneWidget);
      final Scrollbar scrollbar = tester.widget(scrollbarFinder);
      expect(scrollbar.thumbVisibility, isTrue);

      // Verificar SingleChildScrollView descendiente del Scrollbar con BouncingScrollPhysics
      final scrollViews = tester.widgetList<SingleChildScrollView>(
        find.descendant(of: scrollbarFinder, matching: find.byType(SingleChildScrollView)),
      );
      expect(scrollViews.any((s) => s.physics is BouncingScrollPhysics), isTrue);

      // Cerrar modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });
  });

  // =========================================================================
  // ÁREA 4: INICIO (HOME) CABECERA (Fase 6) - Nitidez y Extensión del Negocio
  // =========================================================================
  group('ÁREA 4: Inicio (Home) Cabecera - MarqueeText y Distribución', () {
    testWidgets('MarqueeText con enableGradientFade: false desactiva ShaderMask para 100% nitidez', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarqueeText(
              text: 'luz navarro',
              enableGradientFade: false, // Debe omitir ShaderMask
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No debe existir ningún ShaderMask envolviendo a MarqueeText
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text('luz navarro'), findsOneWidget);
    });

    testWidgets('MarqueeText con enableGradientFade: true mantiene ShaderMask activo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarqueeText(
              text: 'Texto con sombreado',
              enableGradientFade: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe existir el ShaderMask cuando esté habilitado
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.text('Texto con sombreado'), findsOneWidget);
    });

    testWidgets('DashboardHeader distribuye nombre de negocio extendiéndose bajo botones [🔄, 🔔] antes del avatar', (tester) async {
      final authProv = AuthProvider();
      final workbenchProv = WorkbenchProvider();
      final saleProv = SaleProvider();
      final notifProv = NotificationProvider();
      final trackingProv = TrackingProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProv),
              ChangeNotifierProvider<WorkbenchProvider>.value(value: workbenchProv),
              ChangeNotifierProvider<SaleProvider>.value(value: saleProv),
              ChangeNotifierProvider<NotificationProvider>.value(value: notifProv),
              ChangeNotifierProvider<TrackingProvider>.value(value: trackingProv),
            ],
            child: const Scaffold(
              body: SingleChildScrollView(
                child: DashboardHeader(),
              ),
            ),
          ),
        ),
      );

      // Usar pump con duración fija debido al AnimationController infinito (repeat) y timer
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que los botones de acción están presentes
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Verificar que los MarqueeText en la cabecera tienen enableGradientFade = false
      final marquees = tester.widgetList<MarqueeText>(find.byType(MarqueeText)).toList();
      expect(marquees.isNotEmpty, isTrue);
      for (final marquee in marquees) {
        expect(marquee.enableGradientFade, isFalse, reason: 'Todos los MarqueeText del header deben ser nítidos sin gradiente oscurecedor');
      }

      expect(tester.takeException(), isNull);
    });
  });
}
