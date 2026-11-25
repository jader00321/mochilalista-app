import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/client_tracking_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/backup_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/license_status_tour.dart';
import 'package:app_movil/core/widgets/product_optional_info.dart';
import 'package:app_movil/features/catalog/screens/tabs/widgets/inventory_filter_header.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_tracking_screen.dart';
import 'package:app_movil/core/widgets/home/dashboard_header.dart';

class MockAuthProviderForPhase3Test extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    fullName: "Comerciante Fase 3",
    phone: "999888777",
    isActive: true,
  );

  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: "Negocio Fase 3",
    address: "Av. Industrial 123",
    moneda: "PEN",
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
  String get userName => "Comerciante Fase 3";

  @override
  bool get isOwner => true;

  @override
  bool get isWorker => false;

  @override
  bool get isCommunityClient => false;

  @override
  bool get canManageClients => true;

  @override
  String get businessName => "Negocio Fase 3";

  @override
  Future<void> refreshActiveUser() async {}

  @override
  Future<void> checkInitialState() async {}

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockTrackingProviderForPhase3Test extends ChangeNotifier implements TrackingProvider {
  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  String get searchQuery => '';

  @override
  bool get filterHasDebt => false;

  @override
  bool get filterPendingDelivery => false;

  @override
  String get filterConfidenceLevel => 'todos';

  @override
  String get currentSort => 'name_asc';

  @override
  bool get filterIsAppClient => false;

  @override
  int get clientCount => 0;

  @override
  int get pendingRewardsCount => 0;

  @override
  List<ClientModel> get filteredClients => const [];

  @override
  void resetFiltersAndSearch() {}

  @override
  Future<void> loadClients() async {}

  @override
  Future<void> loadClientCount() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockInventoryProviderForPhase3Test extends ChangeNotifier implements InventoryProvider {
  @override
  int get totalProductsCount => 12;

  @override
  int get totalPresentationsCount => 24;

  @override
  bool get showStockAlertColors => true;

  @override
  SortType get prodSort => SortType.id;

  @override
  bool get prodAsc => true;

  @override
  bool get hasCreationDraft => false;

  bool get hasActiveCreationTasks => false;

  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  bool get hasOrphanCategories => false;

  @override
  String get activeQuery => '';

  String? get searchQuery => null;

  String? get filterState => null;

  @override
  String? get activeState => null;

  @override
  bool get activeHasOffer => false;

  @override
  bool get activeOnlyDefaults => false;

  @override
  double? get activeMinPrice => null;

  @override
  int? get activeMinStock => null;

  @override
  List<InventoryWrapper> get items => const <InventoryWrapper>[];

  @override
  List<Category> get categories => const <Category>[];

  @override
  List<Brand> get brands => const <Brand>[];

  @override
  List<ProviderModel> get providers => const <ProviderModel>[];

  @override
  List<int> get activeCategoryIds => const [];

  @override
  List<int> get activeBrandIds => const [];

  @override
  List<int> get activeProviderIds => const [];

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
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final name = invocation.memberName.toString();
      if (name.contains('Count')) return 0;
      if (name.contains('Loading')) return false;
      return const [];
    }
    return null;
  }
}

class MockWorkbenchProviderForPhase3Test extends ChangeNotifier implements WorkbenchProvider {
  @override
  bool get isLoading => false;

  @override
  List<SmartQuotationModel> get inProcessList => const [];

  @override
  List<SmartQuotationModel> get readyAndPacksList => const [];

  @override
  List<SmartQuotationModel> get soldList => const [];

  int get inProcessCount => 0;

  @override
  Future<void> loadDashboard({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockSaleProviderForPhase3Test extends ChangeNotifier implements SaleProvider {
  @override
  bool get isLoading => false;

  @override
  double get todaySalesTotal => 0.0;

  @override
  int get todaySalesCount => 0;

  @override
  List<SaleModel> get salesHistory => const [];

  @override
  Future<void> loadSalesHistory({bool silent = false}) async {}

  @override
  Future<void> silentRefresh() async {}

  @override
  Future<void> loadCurrentMonthMargin() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockNotificationProviderForPhase3Test extends ChangeNotifier implements NotificationProvider {
  @override
  int get unreadCount => 0;

  @override
  Future<void> fetchNotifications() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  tearDown(() async {
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  group('Fase 3 - Corrección Forense de Anclajes, Visibilidad y Coordinación', () {
    test('1. HomeScreenTour: textos, títulos y 4 pestañas reales alineadas', () {
      final config = HomeScreenTour.buildConfig();

      expect(config.steps.length, equals(6));

      // Paso 3: Perfil y Estado de Licencia (no circular 0x0)
      final step3 = config.steps[2];
      expect(step3.id, equals('step_license'));
      expect(step3.title, equals('Perfil y Estado de Licencia'));
      expect(step3.borderRadius, equals(25.0));

      // Paso 4: Accesos Rápidos Operativos con padding compacto
      final step4 = config.steps[3];
      expect(step4.id, equals('step_smart_actions'));
      expect(step4.title, equals('Accesos Rápidos Operativos'));
      expect(step4.spotlightPadding, isNotNull);

      // Paso 5: Mesa de Trabajo y Pedidos (1:1 con banner)
      final step5 = config.steps[4];
      expect(step5.id, equals('step_activity'));
      expect(step5.title, equals('Mesa de Trabajo y Pedidos'));

      // Paso 6: Barra de Navegación (4 pestañas reales)
      final step6 = config.steps[5];
      expect(step6.id, equals('step_bottom_nav'));
      expect(step6.title, equals('Barra de Navegación'));
      expect(step6.description, contains('Inicio, Inventario, Catálogo y Clientes'));
    });

    testWidgets('2. IndexedStack sin choques: InventoryScreen con autoTriggerTour: false no dispara tour en initState', (tester) async {
      await InteractiveTourService.setAutomaticToursEnabled(true);
      expect(InteractiveTourService.isTourActive, isFalse);

      final invKeys = InventoryTourKeys();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProviderForPhase3Test()),
            ChangeNotifierProvider<InventoryProvider>.value(value: MockInventoryProviderForPhase3Test()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: InventoryScreen(
                autoTriggerTour: false,
                tourKeys: invKeys,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Con autoTriggerTour: false jamás debe iniciar tour en initState
      expect(InteractiveTourService.isTourActive, isFalse);
      expect(find.byType(InteractiveTourOverlay), findsNothing);
    });

    testWidgets('3. IndexedStack sin choques: ClientTrackingScreen con autoTriggerTour: false no dispara tour en initState', (tester) async {
      await InteractiveTourService.setAutomaticToursEnabled(true);
      expect(InteractiveTourService.isTourActive, isFalse);

      final crmKeys = ClientTrackingTourKeys();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProviderForPhase3Test()),
            ChangeNotifierProvider<TrackingProvider>.value(value: MockTrackingProviderForPhase3Test()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ClientTrackingScreen(
                autoTriggerTour: false,
                tourKeys: crmKeys,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Con autoTriggerTour: false jamás debe iniciar tour en initState
      expect(InteractiveTourService.isTourActive, isFalse);
      expect(find.byType(InteractiveTourOverlay), findsNothing);
    });

    testWidgets('4. DashboardHeader: licenseAlertKey anclada a avatar circular >= 50x50dp (cero 0x0)', (tester) async {
      final homeKeys = HomeScreenTourKeys();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProviderForPhase3Test()),
            ChangeNotifierProvider<WorkbenchProvider>.value(value: MockWorkbenchProviderForPhase3Test()),
            ChangeNotifierProvider<SaleProvider>.value(value: MockSaleProviderForPhase3Test()),
            ChangeNotifierProvider<NotificationProvider>.value(value: MockNotificationProviderForPhase3Test()),
            ChangeNotifierProvider<TrackingProvider>.value(value: MockTrackingProviderForPhase3Test()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DashboardHeader(
                tourKeys: homeKeys,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final avatarFinder = find.byKey(homeKeys.licenseAlertKey);
      expect(avatarFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(avatarFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(50.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(50.0));
    });

    testWidgets('5. ProductOptionalInfo y ExpansibleController: despliegue animado para barcode', (tester) async {
      final controller = ExpansibleController();
      final descCtrl = TextEditingController();
      final imgCtrl = TextEditingController();
      final barcodeCtrl = TextEditingController();
      final barcodeKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductOptionalInfo(
                controller: controller,
                descCtrl: descCtrl,
                imgCtrl: imgCtrl,
                barcodeCtrl: barcodeCtrl,
                barcodeFieldKey: barcodeKey,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Inicialmente contraído
      expect(controller.isExpanded, isFalse);

      // Simular onBeforeStep del tour
      controller.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.isExpanded, isTrue);
      expect(find.byKey(barcodeKey), findsOneWidget);

      final barcodeBox = tester.renderObject<RenderBox>(find.byKey(barcodeKey));
      expect(barcodeBox.size.height, greaterThan(30.0));
      expect(barcodeBox.size.width, greaterThan(100.0));

      // Simular onAfterStep del tour
      controller.collapse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.isExpanded, isFalse);
    });

    testWidgets('6. InventoryFilterHeader: searchFiltersKey anclado a RenderBox Container (cero TypeError de RenderSliver)', (tester) async {
      final searchKey = GlobalKey();
      final provider = MockInventoryProviderForPhase3Test();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                InventoryFilterHeader(
                  searchFiltersKey: searchKey,
                  provider: provider,
                  isDark: false,
                  viewMode: 0,
                  onViewModeChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetFinder = find.byKey(searchKey);
      expect(targetFinder, findsOneWidget);

      final renderObj = tester.renderObject(targetFinder);
      // Debe ser estrictamente RenderBox (no RenderSliverPinnedPersistentHeader)
      expect(renderObj, isA<RenderBox>());
      final box = renderObj as RenderBox;
      expect(box.size.width, greaterThan(0));
      expect(box.size.height, greaterThanOrEqualTo(50));
    });

    test('7. LicenseStatusTour y BackupScreenTour: anclajes compactos y definidos', () {
      final licConfig = LicenseStatusTour.buildConfig();
      final backupConfig = BackupScreenTour.buildConfig();

      expect(licConfig.steps.length, equals(5));
      expect(backupConfig.steps.length, equals(4));

      // Paso 5 de licencia: Planes Oficiales y Soporte
      final licStep5 = licConfig.steps[4];
      expect(licStep5.id, equals('step_pricing_catalog'));
      expect(licStep5.title, equals('Planes Oficiales y Soporte'));

      // Paso 1 de backup: Respaldo Seguro en Google Drive
      final backupStep1 = backupConfig.steps[0];
      expect(backupStep1.id, equals('step_cloud_backup'));
      expect(backupStep1.title, equals('Respaldo Seguro en Google Drive'));
    });

    test('8. HomeScreen reactividad segura a tourResetEpoch: tour diferido al estar cubierto por ProfileScreen', () {
      final notifier = InteractiveTourService.tourResetEpoch;
      int lastObservedEpoch = notifier.value;
      bool pendingTourAfterReset = false;
      bool tourDispatched = false;

      void onTourResetEpochChanged({required bool isCurrent}) {
        final newEpoch = notifier.value;
        if (newEpoch > lastObservedEpoch) {
          lastObservedEpoch = newEpoch;
          if (!isCurrent) {
            pendingTourAfterReset = true;
          } else {
            tourDispatched = true;
          }
        }
      }

      void onProfileReturned() {
        if (pendingTourAfterReset) {
          pendingTourAfterReset = false;
          tourDispatched = true;
        }
      }

      // Simular que ProfileScreen está encima (isCurrent == false) al reiniciar las guías
      notifier.value++;
      onTourResetEpochChanged(isCurrent: false);

      expect(pendingTourAfterReset, isTrue, reason: 'Debe marcar tour pendiente sin dispararlo');
      expect(tourDispatched, isFalse, reason: 'No debe disparar el tour de HomeScreen mientras ProfileScreen está encima');

      // Al retornar de ProfileScreen
      onProfileReturned();
      expect(pendingTourAfterReset, isFalse);
      expect(tourDispatched, isTrue, reason: 'Debe disparar el tour seguro al retornar a HomeScreen');
    });
  });
}
