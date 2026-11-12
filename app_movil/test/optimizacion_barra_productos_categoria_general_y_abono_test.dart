import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/tabs/widgets/inventory_filter_header.dart';
import 'package:app_movil/features/catalog/screens/tabs/products_tab.dart';
import 'package:app_movil/features/catalog/screens/tabs/categories_tab.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_search_bar.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  String get businessName => 'Librería Central';

  @override
  String get activeBusinessName => 'Librería Central';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  bool _showStockAlertColors = true;
  final int _totalProducts = 105;
  final int _totalPresentations = 115;
  int _orphanCategories = 3;
  List<Category> _categoriesList = [];
  final List<int> _activeCatIds = [];

  @override
  bool get showStockAlertColors => _showStockAlertColors;

  @override
  int get totalProductsCount => _totalProducts;

  @override
  int get totalPresentationsCount => _totalPresentations;

  @override
  int get orphanCategoriesCount => _orphanCategories;

  @override
  bool get hasOrphanCategories => _orphanCategories > 0;

  @override
  List<Category> get categories => _categoriesList;

  @override
  List<int> get activeCategoryIds => _activeCatIds;

  @override
  SortType get prodSort => SortType.id;

  @override
  bool get prodAsc => false;

  @override
  SortType get catSort => SortType.alpha;

  @override
  bool get catAsc => true;

  @override
  bool get hasCreationDraft => false;

  @override
  bool get isLoading => false;

  @override
  bool get activeHasOffer => false;

  @override
  bool get activeOnlyDefaults => false;

  int get activeFilterCount => 0;

  @override
  double? get activeMinPrice => null;

  @override
  double? get activeMaxPrice => null;

  @override
  int? get activeMinStock => null;

  @override
  int? get activeMaxStock => null;

  @override
  String get activeQuery => '';

  @override
  List<int> get activeBrandIds => [];

  @override
  List<int> get activeProviderIds => [];

  @override
  String? get activeState => null;

  @override
  String? get lastActionError => null;

  @override
  List<InventoryWrapper> get items => [];

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  Future<void> toggleStockAlertColors() async {
    _showStockAlertColors = !_showStockAlertColors;
    notifyListeners();
  }

  void toggleCategoryFilter(int id) {
    if (_activeCatIds.contains(id)) {
      _activeCatIds.remove(id);
    } else {
      _activeCatIds.add(id);
    }
    notifyListeners();
  }

  @override
  Future<void> loadMasterData({bool showAll = true}) async {}

  @override
  Future<bool> deleteCategory(int id) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTrackingProvider extends ChangeNotifier implements TrackingProvider {
  @override
  bool get isLoadingDebts => false;

  @override
  List<SaleModel> get currentClientDebts => [];

  @override
  Future<void> loadClientDebts(int clientId, {bool forcePeriodicMorosidad = true}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FASE 1: Responsividad de InventoryFilterHeader y Contador', () {
    testWidgets('Renderiza en 320dp y 360dp con RenderFlex overflowed = 0', (tester) async {
      final mockProvider = _MockInventoryProvider();

      // Test en pantalla ultra-estrecha de 320dp
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                InventoryFilterHeader(
                  provider: mockProvider,
                  isDark: true,
                  viewMode: 0,
                  onViewModeChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que no hay overflows y el contador se muestra
      expect(tester.takeException(), isNull);
      expect(find.text('105 Productos'), findsOneWidget);
      expect(find.text('115 Variantes'), findsOneWidget);

      // Test en pantalla estándar de 360dp
      tester.view.physicalSize = const Size(360, 700);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                InventoryFilterHeader(
                  provider: mockProvider,
                  isDark: false,
                  viewMode: 0,
                  onViewModeChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('105 Productos'), findsOneWidget);
      expect(find.text('115 Variantes'), findsOneWidget);
      expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    });
  });

  group('FASE 2: Ciclo de Vida y Auto-Ocultamiento del Toast de Alerta de Stock', () {
    testWidgets('Toast aparece con Timer de 2.0s y se oculta en cambio de pestaña', (tester) async {
      final mockProvider = _MockInventoryProvider();
      final mockAuth = _MockAuthProvider();

      late TabController tabController;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<InventoryProvider>.value(value: mockProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ],
            child: StatefulBuilder(
              builder: (context, setState) {
                tabController = TabController(length: 3, vsync: const TestVSync());
                return Scaffold(
                  body: ProductsTab(tabController: tabController),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente el toast no es visible (opacidad 0 o offstage)
      expect(find.text('Colores de stock activados'), findsNothing);

      // Tocar el botón de paleta en la barra de herramientas
      final paletteBtn = find.byTooltip('Colores de stock activos (Mantén presionado para info)');
      expect(paletteBtn, findsOneWidget);
      await tester.tap(paletteBtn);
      await tester.pump();

      // El toast debe aparecer
      expect(find.text('Estilo neutro activado'), findsOneWidget);

      // Avanzar 1 segundo: sigue visible
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Estilo neutro activado'), findsOneWidget);

      // Avanzar 1.2 segundos más (total > 2.0s): debe desaparecer automáticamente
      await tester.pump(const Duration(milliseconds: 1200));
      final animatedOpacityFinder = find.byWidgetPredicate(
        (widget) => widget is AnimatedOpacity && widget.opacity == 0.0,
      );
      expect(animatedOpacityFinder, findsOneWidget);

      // Tocar de nuevo para volver a activarlo
      final paletteInactiveBtn = find.byTooltip('Estilo neutro activo (Mantén presionado para info)');
      expect(paletteInactiveBtn, findsOneWidget);
      await tester.tap(paletteInactiveBtn);
      await tester.pump();
      expect(find.text('Colores de stock activados'), findsOneWidget);

      // Conmutar a la pestaña 1 en el TabController: debe ocultarse de inmediato
      tabController.index = 1;
      await tester.pump();
      final hiddenAfterTabChange = find.byWidgetPredicate(
        (widget) => widget is AnimatedOpacity && widget.opacity == 0.0,
      );
      expect(hiddenAfterTabChange, findsOneWidget);

      // Limpiar timer restante para cierre de test
      await tester.pumpAndSettle();
      tabController.dispose();
    });
  });

  group('FASE 3: Unificación de Categoría General y Erradicación de [ Sin Categoría ]', () {
    testWidgets('custom_search_bar muestra General sin corchetes y se oculta si count == 0', (tester) async {
      final mockProvider = _MockInventoryProvider();
      mockProvider._orphanCategories = 5;
      mockProvider._categoriesList = [
        Category(id: 1, nombre: 'Abarrotes', productsCount: 10, activo: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<InventoryProvider>.value(
              value: mockProvider,
              child: CustomSearchBar(
                onSearch: (_) {},
                onFilterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Erradicación absoluta de '[ Sin Categoría ]'
      expect(find.text('[ Sin Categoría ]'), findsNothing);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Abarrotes'), findsOneWidget);

      // Si orphanCategoriesCount == 0 y no hay categoría General, no debe mostrar el chip General
      mockProvider._orphanCategories = 0;
      mockProvider.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text('General'), findsNothing);
      expect(find.text('Abarrotes'), findsOneWidget);
    });

    testWidgets('categories_tab incluye General con conteo y protección contra borrado', (tester) async {
      final mockProvider = _MockInventoryProvider();
      final mockAuth = _MockAuthProvider();
      mockProvider._orphanCategories = 8;
      mockProvider._categoriesList = [
        Category(id: 10, nombre: 'Lácteos', productsCount: 4, activo: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<InventoryProvider>.value(value: mockProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ],
            child: const Scaffold(
              body: CategoriesTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Lácteos'), findsOneWidget);
    });
  });

  group('FASE 4: Toggle On/Off en Etiquetas de Monto Rápido en Registrar Abono', () {
    testWidgets('Primer tap selecciona e inyecta monto, segundo tap desmarca y limpia campo ("")', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
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
        phone: '999888777',
        totalDebt: 3149.0,
        registeredDate: DateTime.now().toIso8601String(),
      );
      final mockTracking = _MockTrackingProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TrackingProvider>.value(
            value: mockTracking,
            child: Scaffold(
              body: PaymentEntryModal(client: client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Verificar que el carrusel de chips contiene el chip "Total"
      final totalChip = find.text('Total');
      expect(totalChip, findsOneWidget);

      // 1. PRIMER TAP: Seleccionar chip "Total"
      await tester.tap(totalChip);
      await tester.pumpAndSettle();

      TextField tf = tester.widget<TextField>(textFieldFinder);
      expect(tf.controller?.text, '3149.00');
      // Debe mostrar el check de seleccionado
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // 2. SEGUNDO TAP EN EL MISMO CHIP: Toggle OFF -> Desmarcar y vaciar campo
      await tester.tap(totalChip);
      await tester.pumpAndSettle();

      tf = tester.widget<TextField>(textFieldFinder);
      expect(tf.controller?.text, '');
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // 3. EDITAR MANUALMENTE DESMARCA EL CHIP
      await tester.tap(totalChip);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Simular ingreso manual con teclado
      tf.controller?.text = '1500';
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });
}
