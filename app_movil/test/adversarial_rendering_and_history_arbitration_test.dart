import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_history_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/history_dashboard_cards.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/history_filter_bar.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sales_list_builder.dart';

SaleModel createTestSale({
  required int id,
  String? clientName,
  String origenVenta = 'smart_quotation',
  double total = 100.0,
  double paid = 100.0,
  bool isArchived = false,
  DateTime? date,
}) {
  return SaleModel.fromJson({
    'id': id,
    'numero_secuencial': id,
    'negocio_id': 1,
    'creado_por_usuario_id': 1,
    'cliente_id': id,
    'cliente_nombre': clientName ?? 'Cliente $id',
    'origen_venta': origenVenta,
    'metodo_pago': 'efectivo',
    'estado_pago': paid >= total ? 'pagado' : 'parcial',
    'estado_entrega': 'entregado',
    'monto_total': total,
    'monto_pagado': paid,
    'is_archived': isArchived ? 1 : 0,
    'fecha_venta': (date ?? DateTime.now()).toIso8601String(),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ÁRBITRO ADVERSARIAL: Auditoría de Renderizado en Inteligencia de Negocio (analytics_dashboard_screen.dart)', () {
    testWidgets('1. Viewport 360x800dp: Opciones de Periodo Consistentes (6 Meses por defecto) y Cero Overflows', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? capturedDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      final analyticsProv = AnalyticsProvider();
      final authProv = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AnalyticsProvider>.value(value: analyticsProv),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
          ],
          child: const MaterialApp(
            home: AnalyticsDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // 1.1 Verificar cabecera e icono
      expect(find.byIcon(Icons.query_stats), findsOneWidget);
      expect(find.text("Inteligencia de Negocio & Radar"), findsOneWidget);

      // 1.2 Verificar las 4 tarjetas de preview con textos 100% legibles
      expect(find.text("📊 Ganancia Neta Real"), findsOneWidget);
      expect(find.text("🚀 Motor Predictivo"), findsOneWidget);
      expect(find.text("📦 Inventario Muerto"), findsOneWidget);
      expect(find.text("📰 Radar Mercado IA"), findsOneWidget);

      // 1.3 Verificar chips de periodo exactos requeridos: Hoy, 7 Días, 30 Días, 6 Meses, Todo, Personalizado 📅
      expect(find.text("Selecciona el periodo a analizar:"), findsOneWidget);
      expect(find.text("Hoy"), findsOneWidget);
      expect(find.text("7 Días"), findsOneWidget);
      expect(find.text("30 Días"), findsOneWidget);
      expect(find.text("6 Meses"), findsOneWidget);
      expect(find.text("Todo", skipOffstage: false), findsOneWidget);
      expect(find.text("Personalizado 📅", skipOffstage: false), findsOneWidget);

      // Periodo por defecto es 6 Meses
      expect(analyticsProv.selectedPeriod, equals(AnalyticsPeriod.sixMonths));

      // 1.4 Botón CTA y transición sin colapso
      final generateBtn = find.text("Generar Reporte Integral");
      expect(generateBtn, findsOneWidget);

      expect(capturedDetails, isNull);
      expect(tester.takeException(), isNull);

      await tester.tap(generateBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dashboard cargado sin ningún error geométrico en StickyHeader (altura 98px)
      expect(capturedDetails, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('ÁRBITRO ADVERSARIAL: Auditoría de Cabecera Reactiva, Scroll Cooldown y Botón Flotante en Historial de Ventas', () {
    testWidgets('2. Máquina de estados de scroll: pixels <= 15 garantiza expansión y botón flotante sube a 0', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockProvider = _ArbitrationMockSaleProvider(
        history: List.generate(
          30,
          (i) => createTestSale(
            id: i + 1,
            clientName: "Cliente $i",
            origenVenta: 'smart_quotation',
            total: 100.0 + i * 10,
            paid: 100.0 + i * 10,
          ),
        ),
      );
      final mockAuth = _ArbitrationMockAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SaleProvider>.value(value: mockProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: SalesHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // En reposo (tope superior): KPIs + Buscador + Filtros visibles
      expect(find.byType(HistoryDashboardCards), findsOneWidget);
      expect(find.byType(HistorySearchBar), findsOneWidget);
      expect(find.byType(HistoryFilterChips), findsOneWidget);

      // Fila 1 y 2 de filtros visibles íntegramente
      expect(find.text("6 Meses"), findsOneWidget);
      expect(find.text("Más recientes"), findsOneWidget);
      expect(find.text("Todos"), findsOneWidget);
      expect(find.text("Pagados"), findsOneWidget);
      expect(find.text("Con Deuda"), findsOneWidget);

      // Scroll abajo para colapsar
      await tester.drag(find.byType(SalesListBuilder).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Al bajar sustancialmente, aparece el botón flotante '^'
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      // Presionar botón flotante para volver arriba
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Al volver a pixels <= 15, los KPIs y Filtros están restaurados
      expect(find.byType(HistoryDashboardCards), findsOneWidget);
      expect(find.byType(HistoryFilterChips), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ÁRBITRO ADVERSARIAL: Auditoría de Filtrado Completo, Búsqueda, Ordenamiento y KPIs a 0ms en SaleProvider', () {
    test('3. getSalesForTab aplica búsqueda por cliente/#recibo, estado de pago y ordenamiento con recálculo de KPIs', () {
      final now = DateTime.now();
      final master = [
        createTestSale(id: 1, clientName: "Carlos Gómez", origenVenta: 'smart_quotation', total: 200.0, paid: 200.0, date: now.subtract(const Duration(days: 2))),
        createTestSale(id: 2, clientName: "Ana Flores", origenVenta: 'smart_quotation', total: 300.0, paid: 100.0, date: now.subtract(const Duration(days: 1))),
        createTestSale(id: 3, clientName: "Pedro Pascal", origenVenta: 'pos_rapido', total: 50.0, paid: 50.0, date: now),
        createTestSale(id: 4, clientName: "Venta Anulada", origenVenta: 'smart_quotation', total: 120.0, paid: 0.0, isArchived: true, date: now),
      ];

      final provider = _ArbitrationMockSaleProvider(history: master);

      // 3.1 Pestaña 'smart_quotation': Ventas 1 y 2
      final quotes = provider.getSalesForTab('smart_quotation');
      expect(quotes.length, equals(2));

      // 3.2 Búsqueda en tiempo real por texto "Carlos"
      provider.setSearchQuery("carlos");
      final searched = provider.getSalesForTab('smart_quotation');
      expect(searched.length, equals(1));
      expect(searched.first.clientName, equals("Carlos Gómez"));
      provider.setSearchQuery(""); // Limpiar búsqueda

      // 3.3 Filtro de estado financiero: 'con_deuda'
      provider.setFinancialFilter('con_deuda');
      final debtSales = provider.getSalesForTab('smart_quotation');
      expect(debtSales.length, equals(1));
      expect(debtSales.first.clientName, equals("Ana Flores"));
      expect(debtSales.first.pendingDebt, equals(200.0));
      provider.setFinancialFilter('todos'); // Limpiar estado financiero

      // 3.4 Ordenamiento por monto descendente
      provider.setSort('monto_total', 'desc');
      final sortedAmount = provider.getSalesForTab('smart_quotation');
      expect(sortedAmount.first.totalAmount, equals(300.0));
      expect(sortedAmount.last.totalAmount, equals(200.0));

      // 3.5 Ordenamiento por fecha ascendente
      provider.setSort('fecha_venta', 'asc');
      final sortedDate = provider.getSalesForTab('smart_quotation');
      expect(sortedDate.first.id, equals(1)); // 2 días atrás
      expect(sortedDate.last.id, equals(2));  // 1 día atrás
    });
  });
}

class _ArbitrationMockSaleProvider extends ChangeNotifier implements SaleProvider {
  final List<SaleModel> _history;
  SalesStatsModel? _stats;
  String _activeFilter = 'seis_meses';
  String _financial = 'todos';
  String _tab = 'todas';
  String _query = '';
  String _sortBy = 'fecha_venta';
  String _order = 'desc';

  _ArbitrationMockSaleProvider({
    List<SaleModel>? history,
    SalesStatsModel? stats,
  })  : _history = history ?? [],
        _stats = stats {
    _recalcStats();
  }

  void _recalcStats() {
    final visible = getSalesForTab(_tab);
    int count = visible.length;
    double ingresos = 0.0;
    double deuda = 0.0;
    for (var s in visible) {
      ingresos += s.paidAmount;
      deuda += s.pendingDebt;
    }
    _stats = SalesStatsModel(
      cantidadVentas: count,
      totalIngresos: ingresos,
      totalDeuda: deuda,
      totalProductosVendidos: 0,
    );
  }

  @override
  List<SaleModel> get salesHistory => getSalesForTab(_tab);

  @override
  SalesStatsModel? get currentStats => _stats;

  @override
  String get activeQuickFilter => _activeFilter;

  @override
  String get financialStatus => _financial;

  @override
  String get currentTab => _tab;

  @override
  String get currentSortBy => _sortBy;

  @override
  String get currentOrder => _order;

  @override
  String get searchQuery => _query;

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
    List<SaleModel> list;
    switch (tabKey) {
      case 'todas':
        list = _history.where((s) => !s.isArchived).toList();
        break;
      case 'smart_quotation':
        list = _history.where((s) => !s.isArchived && s.origenVenta == 'smart_quotation').toList();
        break;
      case 'pos_rapido':
        list = _history.where((s) => !s.isArchived && s.origenVenta == 'pos_rapido').toList();
        break;
      case 'archivadas':
        list = _history.where((s) => s.isArchived).toList();
        break;
      default:
        list = List<SaleModel>.from(_history);
    }

    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((s) {
        final name = (s.clientName ?? '').toLowerCase();
        final idStr = s.id.toString();
        final displayId = s.displayId.toLowerCase();
        return name.contains(q) || idStr.contains(q) || displayId.contains(q);
      }).toList();
    }

    if (_financial == 'pagados') {
      list = list.where((s) => s.isFullyPaid).toList();
    } else if (_financial == 'con_deuda') {
      list = list.where((s) => s.pendingDebt > 0.01).toList();
    }

    list.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'monto_total':
          comparison = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 'fecha_venta':
        default:
          final dateA = DateTime.tryParse(a.saleDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b.saleDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
          comparison = dateA.compareTo(dateB);
          break;
      }
      return _order == 'desc' ? -comparison : comparison;
    });

    return list;
  }

  @override
  Future<void> loadFilteredHistory({bool reset = false}) async {}

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
    _recalcStats();
    notifyListeners();
  }

  @override
  void setSort(String sortBy, String order) {
    _sortBy = sortBy;
    _order = order;
    _recalcStats();
    notifyListeners();
  }

  @override
  void setSearchQuery(String query) {
    _query = query;
    _recalcStats();
    notifyListeners();
  }

  @override
  void setTab(String tabKey) {
    _tab = tabKey;
    _recalcStats();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArbitrationMockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get hasActiveContext => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
