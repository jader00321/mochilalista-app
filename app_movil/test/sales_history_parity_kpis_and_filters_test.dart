import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/widgets/home/recent_activity_list.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sales_list_builder.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/history_dashboard_cards.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/history_filter_bar.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_history_screen.dart';
import 'package:app_movil/core/widgets/deep_nav_return_pill.dart';
import 'package:app_movil/core/providers/auth_provider.dart';

void main() {
  group('FASE 1: Integridad Matemática en SaleModel y Deserialización', () {
    test('Deserialización de nota_prestamo y cliente en préstamos', () {
      final json = {
        'id': 2,
        'numero_secuencial': 2,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cotizacion_id': null,
        'cliente_id': 10,
        'cliente_nombre': 'Freddy',
        'origen_venta': 'prestamo_personal',
        'is_archived': 0,
        'metodo_pago': 'Yape',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 240.0,
        'monto_pagado': 0.0,
        'descuento_aplicado': 0.0,
        'abono_inicial': 0.0,
        'porcentaje_interes': 0.0,
        'nota_prestamo': 'Préstamo para mercadería escolar',
        'fecha_venta': '2026-09-04T20:18:00.000',
      };

      final sale = SaleModel.fromJson(json);

      expect(sale.id, equals(2));
      expect(sale.displayId, equals('2'));
      expect(sale.clientName, equals('Freddy'));
      expect(sale.isLoan, isTrue);
      expect(sale.isQuickSale, isFalse);
      expect(sale.isQuotationSale, isFalse);
      expect(sale.notes, equals('Préstamo para mercadería escolar'));
      expect(sale.trueTotalAmount, equals(240.0));
      expect(sale.paidAmount, equals(0.0));
      expect(sale.pendingDebt, equals(240.0));
      expect(sale.isFullyPaid, isFalse);
      expect(sale.isPartialPayment, isFalse);
      expect(sale.isUnpaid, isTrue);
    });

    test('Verdad Contable: Venta Parcial (Recibo #1 de 23.57 con abono de 5.00)', () {
      final json = {
        'id': 1,
        'numero_secuencial': 1,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cotizacion_id': 101,
        'cliente_id': 10,
        'cliente_nombre': 'Freddy',
        'origen_venta': 'smart_quotation',
        'is_archived': 0,
        'metodo_pago': 'yape',
        'estado_pago': 'parcial',
        'estado_entrega': 'pendiente_recojo',
        'monto_total': 23.57,
        'monto_pagado': 5.00,
        'descuento_aplicado': 0.0,
        'fecha_venta': '2026-08-22T02:14:00.000',
      };

      final sale = SaleModel.fromJson(json);

      expect(sale.isQuotationSale, isTrue);
      expect(sale.isLoan, isFalse);
      expect(sale.isFullyPaid, isFalse); // NUNCA debe decir PAGADO
      expect(sale.isPartialPayment, isTrue);
      expect(sale.isUnpaid, isFalse);
      expect(sale.pendingDebt, closeTo(18.57, 0.001));
    });

    test('Venta totalmente pagada vs Venta Anulada', () {
      final paidSale = SaleModel.fromJson({
        'id': 3,
        'numero_secuencial': 3,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'origen_venta': 'pos_rapido',
        'monto_total': 4.40,
        'monto_pagado': 4.40,
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'fecha_venta': '2026-10-13T20:08:00.000',
      });

      expect(paidSale.isQuickSale, isTrue);
      expect(paidSale.isFullyPaid, isTrue);
      expect(paidSale.isPartialPayment, isFalse);
      expect(paidSale.pendingDebt, equals(0.0));

      final archivedSale = SaleModel.fromJson({
        'id': 4,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'origen_venta': 'pos_rapido',
        'is_archived': 1,
        'monto_total': 50.0,
        'monto_pagado': 0.0,
        'estado_pago': 'anulado',
        'fecha_venta': '2026-10-13T20:08:00.000',
      });

      expect(archivedSale.isArchived, isTrue);
      expect(archivedSale.pendingDebt, equals(0.0)); // No es deuda activa
      expect(archivedSale.isFullyPaid, isFalse);
      expect(archivedSale.isPartialPayment, isFalse);
      expect(archivedSale.isUnpaid, isFalse);
    });
  });

  group('FASE 2: Paridad y Diferenciación en Actividad Reciente (Home)', () {
    testWidgets('Actividad Reciente discrimina Préstamo, Caja Rápida y Cotización', (tester) async {
      final salePrestamo = SaleModel.fromJson({
        'id': 2,
        'numero_secuencial': 2,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_nombre': 'Freddy',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Yape',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 240.0,
        'monto_pagado': 0.0,
        'fecha_venta': '2026-09-04T20:18:00.000',
      });

      final saleReciboParcial = SaleModel.fromJson({
        'id': 1,
        'numero_secuencial': 1,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cotizacion_id': 101,
        'cliente_nombre': 'Freddy',
        'origen_venta': 'smart_quotation',
        'metodo_pago': 'yape',
        'estado_pago': 'parcial',
        'estado_entrega': 'pendiente_recojo',
        'monto_total': 23.57,
        'monto_pagado': 5.00,
        'fecha_venta': '2026-08-22T02:14:00.000',
      });

      final saleCajaRapida = SaleModel.fromJson({
        'id': 3,
        'numero_secuencial': 3,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'origen_venta': 'pos_rapido',
        'metodo_pago': 'yape',
        'estado_pago': 'pagado',
        'estado_entrega': 'entregado',
        'monto_total': 4.40,
        'monto_pagado': 4.40,
        'fecha_venta': '2026-10-13T20:08:00.000',
      });

      final mockSaleProvider = _MockSaleProvider(recentHome: [saleCajaRapida, salePrestamo, saleReciboParcial]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockSaleProvider,
              child: const RecentActivityList(),
            ),
          ),
        ),
      );

      // Verificaciones Semánticas Home:
      // 1. Préstamo #2 muestra etiqueta "Préstamo (#2)" y cliente Freddy (NO "Venta Directa")
      expect(find.text("Préstamo (#2)"), findsOneWidget);
      expect(find.text("Freddy"), findsNWidgets(2)); // En préstamo y en cotización

      // 2. Caja Rápida #3 muestra "Caja Rápida (#3)" y "Sin cliente"
      expect(find.text("Caja Rápida (#3)"), findsOneWidget);
      expect(find.text("Sin cliente"), findsOneWidget);

      // 3. Cotización #1 muestra "Cotización (#1)"
      expect(find.text("Cotización (#1)"), findsOneWidget);

      // 4. Badges de estado financiero real en Home
      expect(find.text("Pagado"), findsOneWidget);
      expect(find.text("Parcial · Debe S/ 18.57"), findsOneWidget);
      expect(find.text("Pendiente · S/ 240.00"), findsOneWidget);
    });
  });

  group('FASE 3: Rediseño de Tarjetas en Historial de Ventas', () {
    testWidgets('Historial muestra badge explícito de origen, cliente Freddy y verdad contable', (tester) async {
      final salePrestamo = SaleModel.fromJson({
        'id': 2,
        'numero_secuencial': 2,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 10,
        'cliente_nombre': 'Freddy',
        'origen_venta': 'prestamo_personal',
        'metodo_pago': 'Yape',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado',
        'monto_total': 240.0,
        'monto_pagado': 0.0,
        'nota_prestamo': 'Préstamo personal para mercadería',
        'fecha_venta': '2026-09-04T20:18:00.000',
      });

      final saleReciboParcial = SaleModel.fromJson({
        'id': 1,
        'numero_secuencial': 1,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cotizacion_id': 101,
        'cliente_id': 10,
        'cliente_nombre': 'Freddy',
        'origen_venta': 'smart_quotation',
        'metodo_pago': 'yape',
        'estado_pago': 'parcial',
        'estado_entrega': 'pendiente_recojo',
        'monto_total': 23.57,
        'monto_pagado': 5.00,
        'fecha_venta': '2026-08-22T02:14:00.000',
      });

      final mockSaleProvider = _MockSaleProvider(history: [salePrestamo, saleReciboParcial]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockSaleProvider,
              child: const SalesListBuilder(),
            ),
          ),
        ),
      );

      // Verificaciones en Tarjetas de Historial:
      // 1. Badges superiores de Origen Explícito (elegante sin emojis)
      expect(find.text("Préstamo Personal"), findsOneWidget);
      expect(find.text("Cotización Vendida"), findsOneWidget);

      // 2. Cliente Freddy visible en ambos (¡El préstamo NO debe ocultar a Freddy!)
      expect(find.text("Freddy"), findsNWidgets(2));

      // 3. Subtítulo del préstamo no repite 'Préstamo personal'
      expect(find.text("Mercadería"), findsOneWidget);

      // 4. Verdad contable en Recibo #1: Debe decir PAGO PARCIAL · Debe S/ 18.57 (JAMÁS PAGADO)
      expect(find.text("PAGO PARCIAL · Debe S/ 18.57"), findsOneWidget);
      expect(find.text("Abonado: S/ 5.00"), findsOneWidget);
      // El texto redundante "Debe: S/ 18.57" bajo el monto principal fue eliminado
      expect(find.text("Debe: S/ 18.57"), findsNothing);

      // 5. Estado de entrega: presente en ventas ("PENDIENTE RECOJO"), NUNCA en préstamos
      expect(find.text("PENDIENTE RECOJO"), findsOneWidget);
      expect(find.text("ENTREGADO"), findsNothing); // El préstamo no tiene badge de entrega
    });
  });

  group('FASE 4: KPIs Responsivos y Barra Unificada de Filtros', () {
    testWidgets('HistoryDashboardCards renderiza 3 columnas con FittedBox sin overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final stats = SalesStatsModel(
        totalIngresos: 9.40,
        totalDeuda: 18.57,
        cantidadVentas: 2,
        totalProductosVendidos: 5,
      );

      final mockSaleProvider = _MockSaleProvider(stats: stats);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockSaleProvider,
              child: const HistoryDashboardCards(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificación de títulos nítidos sin truncar
      expect(find.text("Operaciones"), findsOneWidget);
      expect(find.text("Cobrado"), findsOneWidget);
      expect(find.text("Por Cobrar"), findsOneWidget);

      // Verificación de cifras renderizadas
      expect(find.text("2"), findsOneWidget);
      expect(find.textContaining("9"), findsOneWidget);
      expect(find.textContaining("18"), findsOneWidget);

      // Cero excepciones de desbordamiento de renderizado
      expect(tester.takeException(), isNull);
    });

    testWidgets('Barra Unificada de Filtros muestra Periodo, Orden y Estados sin scroll horizontal', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSaleProvider = _MockSaleProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SaleProvider>.value(
              value: mockSaleProvider,
              child: const HistoryFilterChips(),
            ),
          ),
        ),
      );

      // Selector de Periodo visible (6 Meses por defecto)
      expect(find.text("6 Meses"), findsOneWidget);

      // Selector de Orden visible (Más recientes por defecto)
      expect(find.text("Más recientes"), findsOneWidget);

      // Segmento de Estado Financiero visible de inmediato
      expect(find.text("Todos"), findsOneWidget);
      expect(find.text("Pagados"), findsOneWidget);
      expect(find.text("Con Deuda"), findsOneWidget);

      // Tocar en "Con Deuda" activa el filtro
      await tester.tap(find.text("Con Deuda"));
      await tester.pumpAndSettle();
      expect(mockSaleProvider.financialStatus, equals("con_deuda"));

      expect(tester.takeException(), isNull);
    });
  });

  group('FASE 5: Presencia y Persistencia de DeepNavReturnPill en Historial de Ventas', () {
    testWidgets('SalesHistoryScreen contiene DeepNavReturnPill con persistencia global', (tester) async {
      final mockSaleProvider = _MockSaleProvider();
      final mockAuth = _MockAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SaleProvider>.value(value: mockSaleProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: SalesHistoryScreen(),
          ),
        ),
      );

      await tester.pump();

      // DeepNavReturnPill debe existir en el árbol de widgets de SalesHistoryScreen
      expect(find.byType(DeepNavReturnPill), findsOneWidget);
    });
  });
}

class _MockSaleProvider extends ChangeNotifier implements SaleProvider {
  final List<SaleModel> _recentHome;
  final List<SaleModel> _history;
  final SalesStatsModel? _stats;
  String _activeFilter = 'seis_meses';
  String _sortBy = 'fecha_venta';
  String _order = 'desc';
  String _tab = 'todas';
  String _financial = 'todos';

  _MockSaleProvider({
    List<SaleModel>? recentHome,
    List<SaleModel>? history,
    SalesStatsModel? stats,
  })  : _recentHome = recentHome ?? [],
        _history = history ?? [],
        _stats = stats;

  @override
  List<SaleModel> get recentHomeSales => _recentHome;

  @override
  List<SaleModel> get salesHistory => _history;

  @override
  SalesStatsModel? get currentStats => _stats;

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
  String get activeQuickFilter => _activeFilter;

  @override
  String get currentSortBy => _sortBy;

  @override
  String get currentOrder => _order;

  @override
  String get currentTab => _tab;

  @override
  String get financialStatus => _financial;

  @override
  String get searchQuery => "";

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
  void setFinancialFilter(String status) {
    _financial = status;
    notifyListeners();
  }

  @override
  void setQuickFilter(String filterType, {DateTime? customStart, DateTime? customEnd}) {
    _activeFilter = filterType;
    notifyListeners();
  }

  @override
  void setSort(String sortBy, String order) {
    _sortBy = sortBy;
    _order = order;
    notifyListeners();
  }

  @override
  void setTab(String tabKey) {
    _tab = tabKey;
    notifyListeners();
  }

  @override
  void setSearchQuery(String query) {
    notifyListeners();
  }

  @override
  Future<void> loadFilteredHistory({bool reset = false}) async {}

  @override
  Future<void> loadRecentHomeActivity() async {}

  @override
  Future<void> loadSalesHistory() async {}

  @override
  Future<void> silentRefresh() async {}

  @override
  void resetFilters() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get hasActiveContext => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
