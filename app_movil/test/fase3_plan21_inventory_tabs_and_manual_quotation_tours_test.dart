import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/morphing_accordion.dart';
import 'package:app_movil/core/widgets/tour/coach_card_widget.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/manual_quotation_tour.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/campaign_model.dart';
import 'package:app_movil/features/promotions/models/promotion_rule_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/promotions/screens/offers_tab.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_footer.dart';

class _MockAuthFase3Plan21 extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    fullName: 'Comerciante Plan21',
    phone: '999111222',
    isActive: true,
  );
  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Plan21',
    address: 'Av. Principal 456',
    moneda: 'PEN',
  );

  @override
  UserModel? get user => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  BusinessModel? get currentBusiness => _business;

  @override
  bool get hasPinCache => true;

  @override
  bool get isPinReminderSnoozed => true;

  @override
  bool get isLoading => false;

  @override
  String get userName => 'Comerciante Plan21';

  @override
  String get businessName => 'Librería Plan21';

  @override
  String get errorMessage => '';

  @override
  bool get isOwner => true;

  @override
  bool get isWorker => false;

  @override
  bool get isCommunityClient => false;

  @override
  bool get canManageClients => true;

  @override
  Future<void> refreshActiveUser() async {}

  @override
  Future<void> checkInitialState() async {}

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventoryFase3Plan21 extends ChangeNotifier
    implements InventoryProvider {
  @override
  int? get negocioId => 1;

  @override
  int get totalProductsCount => 0;

  @override
  int get totalPresentationsCount => 0;

  @override
  int get orphanCategoriesCount => 0;

  @override
  int get orphanBrandsCount => 0;

  @override
  bool get hasOrphanCategories => false;

  @override
  bool get hasOrphanBrands => false;

  @override
  bool get showStockAlertColors => true;

  @override
  bool get hasCreationDraft => false;

  @override
  bool get hasActiveFilters => false;

  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  SortType get prodSort => SortType.id;

  @override
  bool get prodAsc => true;

  @override
  SortType get catSort => SortType.alpha;

  @override
  bool get catAsc => true;

  @override
  SortType get brandSort => SortType.alpha;

  @override
  bool get brandAsc => true;

  @override
  SortType get provSort => SortType.alpha;

  @override
  bool get provAsc => true;

  @override
  String get activeQuery => '';

  @override
  String? get activeState => null;

  @override
  double? get activeMinPrice => null;

  @override
  double? get activeMaxPrice => null;

  @override
  int? get activeMinStock => null;

  @override
  int? get activeMaxStock => null;

  @override
  bool get activeHasOffer => false;

  @override
  bool get activeOnlyDefaults => false;

  @override
  List<InventoryWrapper> get items => const <InventoryWrapper>[];

  @override
  List<Category> get categories => const <Category>[];

  @override
  List<Brand> get brands => const <Brand>[];

  @override
  List<ProviderModel> get providers => const <ProviderModel>[];

  @override
  List<int> get activeCategoryIds => const <int>[];

  @override
  List<int> get activeBrandIds => const <int>[];

  @override
  List<int> get activeProviderIds => const <int>[];

  @override
  Future<void> loadInventory({
    bool reset = false,
    String? searchQuery,
    List<int>? categoryIds,
    List<int>? brandIds,
    List<int>? providerIds,
    String? filterState,
    double? minPrice,
    double? maxPrice,
    int? minStock,
    int? maxStock,
    bool? hasOffer,
    bool? onlyDefaults,
  }) async {}

  @override
  Future<void> loadCategories({String? searchQuery}) async {}

  @override
  Future<void> loadBrands({String? searchQuery}) async {}

  @override
  Future<void> loadProviders({String? searchQuery}) async {}

  @override
  Future<Product?> fetchProductById(int productId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final name = invocation.memberName.toString();
      if (name.contains('Count')) {
        return 0;
      }
      if (name.contains('Loading') ||
          name.startsWith('Symbol("has') ||
          name.startsWith('Symbol("is') ||
          name.contains('Asc')) {
        return false;
      }
      if (name.contains('Query') || name.contains('Message')) {
        return '';
      }
      if (name.contains('Sort')) {
        return SortType.alpha;
      }
      return const [];
    }
    return null;
  }
}

class _MockPromotionFase3Plan21 extends ChangeNotifier
    implements PromotionProvider {
  @override
  List<CampaignModel> get campaigns => const <CampaignModel>[];

  @override
  List<BundleModel> get bundles => const <BundleModel>[];

  @override
  List<PromotionRuleModel> get promotionRules => const <PromotionRuleModel>[];

  @override
  bool get isLoading => false;

  @override
  void refreshUI() {}

  @override
  void updateContext(int negocioId, InventoryProvider inventoryProvider) {}

  @override
  Future<void> loadPromotions(int negocioId) async {}

  @override
  List<BundleItemModel> getItemsForBundle(int bundleId) =>
      const <BundleItemModel>[];

  @override
  int calculateBundleMaxStock(int bundleId) => 0;

  @override
  List<BundleModel> getBundlesForPresentation(int presentacionId) =>
      const <BundleModel>[];

  @override
  double? calculateBundleCost(int bundleId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockWorkbenchFase3Plan21 extends ChangeNotifier
    implements WorkbenchProvider {
  @override
  bool get isLoading => false;

  @override
  List<SmartQuotationModel> get inProcessList => const <SmartQuotationModel>[];

  @override
  List<SmartQuotationModel> get readyAndPacksList =>
      const <SmartQuotationModel>[];

  @override
  List<SmartQuotationModel> get soldList => const <SmartQuotationModel>[];

  @override
  Future<void> loadDashboard({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSmartQuotationFase3Plan21 extends ChangeNotifier
    implements SmartQuotationProvider {
  @override
  bool get hasManualDraft => false;

  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  Future<String> generateDynamicQuoteName(
    ClientModel? client,
    String manualClientName, {
    String? schoolName,
    String? gradeLevel,
    bool isClientRole = false,
    String? clientUserName,
    int? sequentialNumber,
    required String type,
  }) async {
    return 'Cotización Prueba';
  }

  @override
  Future<SmartQuotationModel?> getQuotationById(int id) async => null;

  @override
  void saveManualDraft({
    required List<MatchedProduct> items,
    required Map<int, int> quantities,
    required Map<int, double> prices,
    required Map<int, String> names,
    ClientModel? client,
    String? cName,
    String? cPhone,
    String? cDni,
    String? cAddr,
    String? cEmail,
    String? cNotes,
    String? qTitle,
    String? qNotes,
    String? school,
    String? grade,
    int? quotationId,
  }) {}

  @override
  void clearManualDraft() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockQuickSaleFase3Plan21 extends ChangeNotifier
    implements QuickSaleProvider {
  bool _hideProfits = false;

  @override
  bool get hideProfits => _hideProfits;

  @override
  Future<void> toggleHideProfits() async {
    _hideProfits = !_hideProfits;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpBounded(WidgetTester tester, {int frames = 6}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 24,
}) async {
  for (int i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 80));
      return;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final emojiRegex = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  tearDown(() async {
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  group('Plan Maestro 21 - FASE 3: Gestión de Negocio y Cotización Manual', () {
    test(
      '1. InventoryTour.buildConfigForTab: 5 pestañas distintas y cero emojis crudos',
      () {
        final expectedScreenIds = [
          'inventory_screen',
          'inventory_offers_tab',
          'inventory_categories_tab',
          'inventory_brands_tab',
          'inventory_providers_tab',
        ];
        final expectedStepCounts = [5, 3, 4, 3, 3];

        final seenScreenIds = <String>{};
        for (int tab = 0; tab < 5; tab++) {
          final config = InventoryTour.buildConfigForTab(tabIndex: tab);
          expect(config.screenId, equals(expectedScreenIds[tab]));
          expect(seenScreenIds.add(config.screenId), isTrue);
          expect(config.steps.length, equals(expectedStepCounts[tab]));

          for (final step in config.steps) {
            expect(step.title.trim(), isNotEmpty);
            expect(step.description.trim(), isNotEmpty);
            expect(emojiRegex.hasMatch(step.title), isFalse);
            expect(emojiRegex.hasMatch(step.description), isFalse);
            if (step.tip != null) {
              expect(emojiRegex.hasMatch(step.tip!), isFalse);
            }
          }
        }

        final legacyDelegate = InventoryTour.buildConfig();
        expect(legacyDelegate.screenId, equals('inventory_screen'));
        expect(legacyDelegate.steps.length, equals(5));
        expect(legacyDelegate.steps[3].id, equals('step_product_card'));
      },
    );

    testWidgets(
      '2. InventoryScreen Tab 0 (PRODUCTOS): tour completo 5/5 sin saltos ni overflows',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          capturedErrors.add(details);
        };

        try {
          final invKey = GlobalKey<InventoryScreenState>();

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(
                  value: _MockAuthFase3Plan21(),
                ),
                ChangeNotifierProvider<InventoryProvider>.value(
                  value: _MockInventoryFase3Plan21(),
                ),
                ChangeNotifierProvider<PromotionProvider>.value(
                  value: _MockPromotionFase3Plan21(),
                ),
              ],
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 640),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: MaterialApp(
                  home: InventoryScreen(
                    key: invKey,
                    initialTabIndex: 0,
                    autoTriggerTour: false,
                  ),
                ),
              ),
            ),
          );

          await _pumpBounded(tester);

          // Disparar tour de la pestaña 0 explícitamente
          invKey.currentState!.startActiveTabTour(automatic: false);
          await _pumpBounded(tester, frames: 8);

          expect(InteractiveTourService.isTourActive, isTrue);
          expect(find.byType(CoachCardWidget), findsOneWidget);
          expect(find.text('1 / 5'), findsOneWidget);
          expect(find.text('Pestañas de Gestión de Negocio'), findsOneWidget);

          final expectedTitles = [
            'Facturas de Proveedor con IA',
            'Buscador y Filtros Avanzados',
            'Tarjetas de Producto y Stock',
            'Crear o Importar Productos',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpBounded(tester, frames: 8);
            expect(find.text('${i + 2} / 5'), findsOneWidget);
            expect(find.text(expectedTitles[i]), findsOneWidget);
            expect(find.byType(CoachCardWidget), findsOneWidget);
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 6);

          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.byType(CoachCardWidget), findsNothing);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '3. InventoryScreen Tab 1 (OFERTAS / BUNDLES): auto-expande y restaura Insights al completar, cancelar (X), Back y dispose',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          capturedErrors.add(details);
        };

        try {
          final invKey = GlobalKey<InventoryScreenState>();

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(
                  value: _MockAuthFase3Plan21(),
                ),
                ChangeNotifierProvider<InventoryProvider>.value(
                  value: _MockInventoryFase3Plan21(),
                ),
                ChangeNotifierProvider<PromotionProvider>.value(
                  value: _MockPromotionFase3Plan21(),
                ),
              ],
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 640),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: MaterialApp(
                  home: InventoryScreen(
                    key: invKey,
                    initialTabIndex: 1,
                    autoTriggerTour: false,
                  ),
                ),
              ),
            ),
          );

          await _pumpBounded(tester);

          OffersTabState offersState() =>
              tester.state<OffersTabState>(find.byType(OffersTab));

          expect(offersState().isInsightsExpanded, isFalse);

          // A) Abrir desde el botón dinámico (i) y completar todo el tour
          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpBounded(tester, frames: 8);

          expect(find.text('1 / 3'), findsOneWidget);
          expect(find.text('Insights y Sugerencias Inteligentes'), findsOneWidget);
          expect(offersState().isInsightsExpanded, isTrue);

          await tester.tap(find.text('Siguiente'));
          await _pumpBounded(tester, frames: 8);
          expect(find.text('2 / 3'), findsOneWidget);
          expect(find.text('Crear Nuevo Paquete u Oferta'), findsOneWidget);
          expect(offersState().isInsightsExpanded, isFalse);

          await tester.tap(find.text('Siguiente'));
          await _pumpBounded(tester, frames: 8);
          expect(find.text('3 / 3'), findsOneWidget);
          expect(find.text('Paquetes Activos y Vigencia'), findsOneWidget);

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 6);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(offersState().isInsightsExpanded, isFalse);

          // B) Cancelar con botón X en el paso 1 con Insights expandido
          invKey.currentState!.startActiveTabTour(automatic: false);
          await _pumpUntilFound(tester, find.byTooltip('Cerrar guía'));
          expect(offersState().isInsightsExpanded, isTrue);

          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(offersState().isInsightsExpanded, isFalse);

          // C) Cancelar con botón Atrás del sistema operativo (handlePopRoute)
          invKey.currentState!.startActiveTabTour(automatic: false);
          await _pumpUntilFound(tester, find.byTooltip('Cerrar guía'));
          expect(offersState().isInsightsExpanded, isTrue);

          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(offersState().isInsightsExpanded, isFalse);

          // D) Desmontar pantalla a mitad del tour no lanza setState() after dispose()
          invKey.currentState!.startActiveTabTour(automatic: false);
          await _pumpBounded(tester, frames: 5);
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpBounded(tester, frames: 8);

          expect(tester.takeException(), isNull);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '4. InventoryScreen Tabs 2, 3 y 4 (Categorías, Marcas, Proveedores): guías dedicadas operativas vía (i)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          capturedErrors.add(details);
        };

        try {
          final cases = <({int tabIndex, int steps, String firstTitle})>[
            (
              tabIndex: 2,
              steps: 4,
              firstTitle: 'Orden, Auto-categorizar IA y Duplicados',
            ),
            (
              tabIndex: 3,
              steps: 3,
              firstTitle: 'Herramientas de Marcas y Duplicados',
            ),
            (
              tabIndex: 4,
              steps: 3,
              firstTitle: 'Orden y Limpieza de Proveedores',
            ),
          ];

          for (final testCase in cases) {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthFase3Plan21(),
                  ),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: _MockInventoryFase3Plan21(),
                  ),
                  ChangeNotifierProvider<PromotionProvider>.value(
                    value: _MockPromotionFase3Plan21(),
                  ),
                ],
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(360, 640),
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: MaterialApp(
                    home: InventoryScreen(
                      initialTabIndex: testCase.tabIndex,
                      autoTriggerTour: false,
                    ),
                  ),
                ),
              ),
            );

            await _pumpBounded(tester);

            await tester.tap(find.byTooltip('Información'));
            await _pumpBounded(tester, frames: 5);
            await tester.tap(
              find.text('Iniciar guía interactiva paso a paso'),
            );
            await _pumpBounded(tester, frames: 8);

            expect(
              find.text('1 / ${testCase.steps}'),
              findsOneWidget,
              reason: 'Tab ${testCase.tabIndex} paso inicial',
            );
            expect(find.text(testCase.firstTitle), findsOneWidget);

            for (int step = 2; step <= testCase.steps; step++) {
              await tester.tap(find.text('Siguiente'));
              await _pumpBounded(tester, frames: 8);
              expect(find.text('$step / ${testCase.steps}'), findsOneWidget);
            }

            await tester.tap(find.text('¡Listo!'));
            await _pumpBounded(tester, frames: 6);
            expect(InteractiveTourService.isTourActive, isFalse);

            await tester.pumpWidget(const SizedBox.shrink());
            await _pumpBounded(tester, frames: 4);
          }

          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '5. ManualQuotationScreen AppBar & layout: 0px Overflow y título completo sin recorte "izaci" en 320/360/412dp a 1.3x',
      (tester) async {
        final viewports = [
          const Size(320, 568),
          const Size(360, 640),
          const Size(412, 915),
        ];

        final sampleItems = [
          MatchedProduct(
            productId: 10,
            presentationId: 100,
            fullName: 'Cuaderno A4 Rayado Plan21',
            productName: 'Cuaderno A4',
            price: 12.50,
            stock: 25,
          ),
        ];

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          capturedErrors.add(details);
        };

        try {
          for (final viewport in viewports) {
            for (final withItems in [false, true]) {
              await tester.binding.setSurfaceSize(viewport);

              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<AuthProvider>.value(
                      value: _MockAuthFase3Plan21(),
                    ),
                    ChangeNotifierProvider<WorkbenchProvider>.value(
                      value: _MockWorkbenchFase3Plan21(),
                    ),
                    ChangeNotifierProvider<SmartQuotationProvider>.value(
                      value: _MockSmartQuotationFase3Plan21(),
                    ),
                    ChangeNotifierProvider<InventoryProvider>.value(
                      value: _MockInventoryFase3Plan21(),
                    ),
                    ChangeNotifierProvider<PromotionProvider>.value(
                      value: _MockPromotionFase3Plan21(),
                    ),
                    ChangeNotifierProvider<QuickSaleProvider>.value(
                      value: _MockQuickSaleFase3Plan21(),
                    ),
                  ],
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: viewport,
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: MaterialApp(
                      home: ManualQuotationScreen(
                        initialItems: withItems ? sampleItems : null,
                      ),
                    ),
                  ),
                ),
              );

              await tester.pumpAndSettle();

              final titleFinder = find.text('Nueva Cotización');
              expect(
                titleFinder,
                findsOneWidget,
                reason:
                    'Título íntegro requerido en ${viewport.width}x${viewport.height} (withItems=$withItems)',
              );
              expect(find.text('izaci'), findsNothing);

              final titleRect = tester.getRect(titleFinder);
              expect(
                titleRect.left,
                greaterThanOrEqualTo(0.0),
                reason: 'Título fuera por izquierda en ${viewport.width}',
              );
              expect(
                titleRect.right,
                lessThanOrEqualTo(viewport.width),
                reason: 'Título fuera por derecha en ${viewport.width}',
              );
              expect(
                titleRect.width,
                greaterThan(70.0),
                reason:
                    'Título colapsado visualmente en ${viewport.width} (withItems=$withItems)',
              );

              final guardFinder = find.text('Guardar');
              expect(guardFinder, findsOneWidget);
              final guardRect = tester.getRect(guardFinder);
              expect(guardRect.right, lessThanOrEqualTo(viewport.width));
              expect(
                titleRect.right,
                lessThanOrEqualTo(guardRect.left),
                reason: 'Título solapado con acciones en ${viewport.width}',
              );

              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }
          }

          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
          await tester.binding.setSurfaceSize(null);
        }
      },
    );

    testWidgets(
      '6. ManualQuotationTour: guía completa de 6 pasos con expansión y restauración de acordeones y footer',
      (tester) async {
        final config = ManualQuotationTour.buildConfig();
        expect(config.screenId, equals('manual_quotation_screen'));
        expect(config.steps.length, equals(6));
        for (final step in config.steps) {
          expect(emojiRegex.hasMatch(step.title), isFalse);
          expect(emojiRegex.hasMatch(step.description), isFalse);
        }

        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          capturedErrors.add(details);
        };

        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(
                  value: _MockAuthFase3Plan21(),
                ),
                ChangeNotifierProvider<WorkbenchProvider>.value(
                  value: _MockWorkbenchFase3Plan21(),
                ),
                ChangeNotifierProvider<SmartQuotationProvider>.value(
                  value: _MockSmartQuotationFase3Plan21(),
                ),
                ChangeNotifierProvider<InventoryProvider>.value(
                  value: _MockInventoryFase3Plan21(),
                ),
                ChangeNotifierProvider<PromotionProvider>.value(
                  value: _MockPromotionFase3Plan21(),
                ),
                ChangeNotifierProvider<QuickSaleProvider>.value(
                  value: _MockQuickSaleFase3Plan21(),
                ),
              ],
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 640),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: const MaterialApp(
                  home: ManualQuotationScreen(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final footerCollapsedHeight =
              tester.getSize(find.byType(ManualQuoteFooter)).height;

          // Iniciar tour completo desde el botón (i)
          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('1 / 6'));

          // Paso 1 / 6: Identificación de Cotización expandido
          expect(find.text('1 / 6'), findsOneWidget);
          expect(find.text('Identificación de Cotización'), findsWidgets);
          expect(find.text('Notas de Cotización (Opcional)'), findsOneWidget);

          // Paso 2 / 6: Cliente y Colegio expandido (Identificación restaurado)
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('2 / 6'));
          expect(find.text('2 / 6'), findsOneWidget);
          expect(find.text('Información de Contacto'), findsOneWidget);

          // Paso 3 / 6: Agregar Productos (Cliente y Colegio restaurado)
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('3 / 6'));
          expect(find.text('3 / 6'), findsOneWidget);
          expect(find.text('Agregar Productos del Catálogo'), findsOneWidget);

          // Paso 4 / 6: Modo Vendedor y Privacidad
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('4 / 6'));
          expect(find.text('4 / 6'), findsOneWidget);
          expect(find.text('Modo Vendedor y Privacidad'), findsOneWidget);

          // Paso 5 / 6: Guardar Proforma o Borrador
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('5 / 6'));
          expect(find.text('5 / 6'), findsOneWidget);
          expect(find.text('Guardar Proforma o Borrador'), findsOneWidget);

          // Paso 6 / 6: Resumen Total y Venta Directa (Footer expandido)
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('6 / 6'));
          expect(find.text('6 / 6'), findsOneWidget);
          expect(find.text('Resumen Total y Venta Directa'), findsOneWidget);
          final footerExpandedHeight =
              tester.getSize(find.byType(ManualQuoteFooter)).height;
          expect(
            footerExpandedHeight,
            greaterThan(footerCollapsedHeight),
          );

          // Finalizar con ¡Listo! restaura el footer y acordeones
          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 10);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(
            tester.getSize(find.byType(ManualQuoteFooter)).height,
            equals(footerCollapsedHeight),
          );

          // Cancelar con X en el paso 1 restaura Identificación
          final accordionsFinder = find.byType(MorphingAccordion);
          final idCollapsedHeight =
              tester.getSize(accordionsFinder.at(0)).height;
          final clientCollapsedHeight =
              tester.getSize(accordionsFinder.at(1)).height;

          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.byTooltip('Cerrar guía'));
          expect(
            tester.getSize(accordionsFinder.at(0)).height,
            greaterThan(idCollapsedHeight),
          );

          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 10);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(
            tester.getSize(accordionsFinder.at(0)).height,
            equals(idCollapsedHeight),
          );

          // Cancelar con Back en el paso 2 restaura Cliente y Colegio
          await tester.tap(find.byTooltip('Información'));
          await _pumpBounded(tester, frames: 5);
          await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
          await _pumpUntilFound(tester, find.text('Siguiente'));
          await tester.tap(find.text('Siguiente'));
          await _pumpUntilFound(tester, find.text('2 / 6'));
          expect(
            tester.getSize(accordionsFinder.at(1)).height,
            greaterThan(clientCollapsedHeight),
          );

          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 10);
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(
            tester.getSize(accordionsFinder.at(1)).height,
            equals(clientCollapsedHeight),
          );

          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });
}
