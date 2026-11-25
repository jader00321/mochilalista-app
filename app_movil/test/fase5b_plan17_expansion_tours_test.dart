import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/client_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/loyalty_center_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/analytics_dashboard_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/bundle_builder_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/printer_config_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/profile_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_create_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quick_sale_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/workbench_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/client_tracking_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sales_history_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/backup_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/license_status_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/catalog_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_scan_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_scan_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sales_checkout_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/manual_quotation_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_financial_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/commercial_radar_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_history_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_edit_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/ai_settings_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/notifications_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/matching_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_review_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_staging_tour.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/providers/printer_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';

import 'package:app_movil/features/profile/screens/printer_config_screen.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';
import 'package:app_movil/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

// Mocks livianos para tests de widget
class MockAuthProviderForPhase5B extends ChangeNotifier implements AuthProvider {
  @override
  int? get activeBusinessId => 1;

  @override
  String get businessName => 'Mochila Lista Comercial';

  @override
  String get activeBusinessName => 'Mochila Lista Comercial';

  @override
  bool get hasActiveContext => true;

  @override
  bool get isCommunityClient => false;

  @override
  bool get canManageClients => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPrinterProviderForPhase5B extends ChangeNotifier implements PrinterProvider {
  @override
  List<BluetoothDevice> get printers => [];

  @override
  List<BluetoothDevice> get otherDevices => [];

  @override
  BluetoothDevice? get selectedDevice => null;

  @override
  bool get isConnected => false;

  @override
  bool get isScanning => false;

  @override
  bool get isBluetoothOff => false;

  @override
  int get paperWidth => 58;

  @override
  String get statusMessage => "Desconectado";

  @override
  Future<void> scanDevices() async {}

  @override
  Future<void> setPaperWidth(int width) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTrackingProviderForPhase5B extends ChangeNotifier implements TrackingProvider {
  @override
  List<SaleModel> get currentClientDebts => [];

  @override
  bool get isLoadingDebts => false;

  @override
  bool get isLoadingLedger => false;

  @override
  List<LedgerItem> get currentClientLedger => [];

  @override
  bool get isLoadingQuotations => false;

  @override
  List<SmartQuotationModel> get currentClientQuotations => [];

  @override
  int get pendingRewardsCount => 0;

  @override
  Future<void> loadClientDebts(int clientId) async {}

  @override
  Future<void> loadClientLedger(int clientId) async {}

  @override
  Future<void> loadClientQuotations(int clientId) async {}

  @override
  Future<void> loadPendingRewardsCount() async {}

  @override
  Future<ClientModel?> getClientById(int clientId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget createTestAppForPhase5B({
  required Widget child,
  bool isDark = true,
  Size screenSize = const Size(412, 915),
  EdgeInsets viewPadding = const EdgeInsets.only(bottom: 48),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProviderForPhase5B()),
      ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
      ChangeNotifierProvider<PrinterProvider>.value(value: MockPrinterProviderForPhase5B()),
      ChangeNotifierProvider<InventoryProvider>.value(value: InventoryProvider()),
      ChangeNotifierProvider<PromotionProvider>.value(value: PromotionProvider()),
      ChangeNotifierProvider<AnalyticsProvider>.value(value: AnalyticsProvider()),
      ChangeNotifierProvider<TrackingProvider>.value(value: MockTrackingProviderForPhase5B()),
      ChangeNotifierProvider<QuickSaleProvider>.value(value: QuickSaleProvider()),
    ],
    child: MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14141C),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          viewPadding: viewPadding,
          textScaler: const TextScaler.linear(1.3),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.resetRuntimeLockForTesting();
    InteractiveTourService.autoTriggerOverrideForTesting = null;
  });

  tearDown(() {
    InteractiveTourService.resetRuntimeLockForTesting();
    InteractiveTourService.autoTriggerOverrideForTesting = null;
  });

  group('Fase 5B - Catálogo Canónico de 35 Pantallas Oficiales', () {
    test('InteractiveTourService.knownScreenIds contiene exactamente 35 pantallas registradas', () {
      expect(InteractiveTourService.knownScreenIds.length, 35);
    });

    test('knownScreenIds incluye las 5 nuevas pantallas de Fase 5B y todas las de Plan 21', () {
      expect(InteractiveTourService.knownScreenIds, contains('client_detail_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('loyalty_center_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('analytics_dashboard_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('bundle_builder_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('printer_config_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('ai_settings_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('notifications_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('matching_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('invoice_review_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('invoice_staging_screen'));
    });

    test('knownScreenIds EXCLUYE estrictamente lock_screen para blindaje de seguridad PIN', () {
      expect(InteractiveTourService.knownScreenIds, isNot(contains('lock_screen')));
    });

    test('Paridad exacta 1:1 de conjuntos (Set) entre knownScreenIds y los 35 configs reales', () {
      final configScreenIds = <String>{
        HomeScreenTour.buildConfig(keys: HomeScreenTourKeys()).screenId,
        ProfileScreenTour.buildConfig(keys: ProfileScreenTourKeys()).screenId,
        AiSettingsTour.buildConfig(keys: AiSettingsTourKeys()).screenId,
        NotificationsTour.buildConfig(keys: NotificationsTourKeys()).screenId,
        CommercialRadarTour.buildConfig(keys: CommercialRadarTourKeys()).screenId,
        ProductCreateTour.buildConfig(keys: ProductCreateTourKeys()).screenId,
        ProductDetailTour.buildConfig(keys: ProductDetailTourKeys()).screenId,
        ProductEditTour.buildConfig(keys: ProductEditTourKeys()).screenId,
        QuickSaleTour.buildConfig(keys: QuickSaleTourKeys()).screenId,
        InventoryTour.buildConfigForTab(tabIndex: 0, keys: InventoryTourKeys()).screenId,
        InventoryTour.buildConfigForTab(tabIndex: 1, keys: InventoryTourKeys()).screenId,
        InventoryTour.buildConfigForTab(tabIndex: 2, keys: InventoryTourKeys()).screenId,
        InventoryTour.buildConfigForTab(tabIndex: 3, keys: InventoryTourKeys()).screenId,
        InventoryTour.buildConfigForTab(tabIndex: 4, keys: InventoryTourKeys()).screenId,
        WorkbenchTour.buildConfig(keys: WorkbenchTourKeys()).screenId,
        ManualQuotationTour.buildConfig(keys: ManualQuotationTourKeys()).screenId,
        MatchingTour.buildConfig(keys: MatchingTourKeys()).screenId,
        QuotationDetailTour.buildConfig(keys: QuotationDetailTourKeys()).screenId,
        ClientTrackingTour.buildConfig(keys: ClientTrackingTourKeys()).screenId,
        SalesHistoryTour.buildConfig(keys: SalesHistoryTourKeys()).screenId,
        SaleHistoryDetailTour.buildConfig(keys: SaleHistoryDetailTourKeys()).screenId,
        SaleFinancialDetailTour.buildConfig(keys: SaleFinancialDetailTourKeys()).screenId,
        BackupScreenTour.buildConfig(keys: BackupScreenTourKeys()).screenId,
        LicenseStatusTour.buildConfig(keys: LicenseStatusTourKeys()).screenId,
        CatalogTour.buildConfig(keys: CatalogTourKeys()).screenId,
        InvoiceScanTour.buildConfig(keys: InvoiceScanTourKeys()).screenId,
        InvoiceReviewTour.buildConfig(keys: InvoiceReviewTourKeys()).screenId,
        InvoiceStagingTour.buildConfig(keys: InvoiceStagingTourKeys()).screenId,
        QuotationScanTour.buildConfig(keys: QuotationScanTourKeys()).screenId,
        SalesCheckoutTour.buildConfig(keys: SalesCheckoutTourKeys()).screenId,
        ClientDetailTour.buildConfig(keys: ClientDetailTourKeys()).screenId,
        LoyaltyCenterTour.buildConfig(keys: LoyaltyCenterTourKeys()).screenId,
        AnalyticsDashboardTour.buildConfig(keys: AnalyticsDashboardTourKeys()).screenId,
        BundleBuilderTour.buildConfig(keys: BundleBuilderTourKeys()).screenId,
        PrinterConfigTour.buildConfig(keys: PrinterConfigTourKeys()).screenId,
      };

      expect(configScreenIds.length, 35);
      expect(InteractiveTourService.knownScreenIds.length, 35);
      expect(InteractiveTourService.knownScreenIds.toSet(), equals(configScreenIds));
      expect(InteractiveTourService.knownScreenIds, isNot(contains('lock_screen')));
      expect(InteractiveTourService.knownScreenIds, isNot(contains('products_tab')));
      expect(InteractiveTourService.knownScreenIds, isNot(contains('quick_quotation_screen')));
    });
  });

  group('Fase 5B - Integridad de Modelos y Textos de los 5 Nuevos Tours', () {
    test('ClientDetailTour tiene 7 pasos pedagógicos completos sin emojis crudos', () {
      final keys = ClientDetailTourKeys();
      final config = ClientDetailTour.buildConfig(keys: keys);

      expect(config.screenId, 'client_detail_screen');
      expect(config.screenTitle, 'Detalle de Cliente y Abonos');
      expect(config.steps.length, 7);

      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(step.tip, isNotNull);
        expect(step.icon, isNotNull);
        // Cero emojis crudos
        expect(step.title.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
        expect(step.description.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
      }
    });

    test('LoyaltyCenterTour tiene 4 pasos con hooks de cambio de tab y restauración', () async {
      final keys = LoyaltyCenterTourKeys();
      int currentTab = 0;
      int tabSwitchCount = 0;
      bool restored = false;

      final config = LoyaltyCenterTour.buildConfig(
        keys: keys,
        onSwitchTab: (index) async {
          currentTab = index;
          tabSwitchCount++;
        },
        onRestoreInitialTab: () async {
          currentTab = 0;
          restored = true;
        },
      );

      expect(config.screenId, 'loyalty_center_screen');
      expect(config.steps.length, 4);

      // Simular ejecución secuencial de hooks
      await config.steps[0].onBeforeStep?.call();
      expect(currentTab, 1);

      await config.steps[1].onBeforeStep?.call();
      expect(currentTab, 1);

      await config.steps[2].onBeforeStep?.call();
      expect(currentTab, 0);

      await config.steps[3].onBeforeStep?.call();
      expect(currentTab, 2);

      await config.steps[3].onAfterStep?.call();
      expect(currentTab, 0);
      expect(restored, isTrue);
      expect(tabSwitchCount, 4);
    });

    test('AnalyticsDashboardTour tiene 4 pasos pedagógicos completos sin emojis crudos', () {
      final keys = AnalyticsDashboardTourKeys();
      final config = AnalyticsDashboardTour.buildConfig(keys: keys);

      expect(config.screenId, 'analytics_dashboard_screen');
      expect(config.screenTitle, 'Inteligencia de Negocio y Métricas');
      expect(config.steps.length, 4);

      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(step.tip, isNotNull);
        expect(step.title.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
        expect(step.description.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
      }
    });

    test('BundleBuilderTour tiene 3 pasos pedagógicos completos sin emojis crudos', () {
      final keys = BundleBuilderTourKeys();
      final config = BundleBuilderTour.buildConfig(keys: keys);

      expect(config.screenId, 'bundle_builder_screen');
      expect(config.screenTitle, 'Creador de Combos y Promociones');
      expect(config.steps.length, 3);

      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(step.tip, isNotNull);
        expect(step.title.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
        expect(step.description.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
      }
    });

    test('PrinterConfigTour tiene 3 pasos pedagógicos completos sin emojis crudos', () {
      final keys = PrinterConfigTourKeys();
      final config = PrinterConfigTour.buildConfig(keys: keys);

      expect(config.screenId, 'printer_config_screen');
      expect(config.screenTitle, 'Impresora Térmica Bluetooth');
      expect(config.steps.length, 3);

      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(step.tip, isNotNull);
        expect(step.title.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
        expect(step.description.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)), isFalse);
      }
    });
  });

  group('Fase 5B - Responsividad y Verificación de Cero Desbordes (0px Overflow)', () {
    final testViewports = [
      {'name': 'Compact (320x568)', 'size': const Size(320, 568)},
      {'name': 'Standard (360x640)', 'size': const Size(360, 640)},
      {'name': 'Modern Flagship (412x915)', 'size': const Size(412, 915)},
    ];

    for (final vp in testViewports) {
      final vpName = vp['name'] as String;
      final vpSize = vp['size'] as Size;

      testWidgets('PrinterConfigScreen renderiza con 0px overflow en $vpName a TextScaler 1.3', (tester) async {
        await tester.pumpWidget(
          createTestAppForPhase5B(
            child: const PrinterConfigScreen(autoTriggerTour: false),
            screenSize: vpSize,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text("Impresora Térmica"), findsOneWidget);
        expect(find.byType(InfoTooltipButton), findsOneWidget);
      });

      testWidgets('BundleBuilderScreen renderiza con 0px overflow en $vpName a TextScaler 1.3', (tester) async {
        await tester.pumpWidget(
          createTestAppForPhase5B(
            child: const BundleBuilderScreen(autoTriggerTour: false),
            screenSize: vpSize,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text("Nuevo Paquete"), findsOneWidget);
        expect(find.byType(InfoTooltipButton), findsOneWidget);
      });

      testWidgets('AnalyticsDashboardScreen renderiza con 0px overflow en $vpName a TextScaler 1.3', (tester) async {
        await tester.pumpWidget(
          createTestAppForPhase5B(
            child: const AnalyticsDashboardScreen(autoTriggerTour: false),
            screenSize: vpSize,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text("Inteligencia de Negocio"), findsOneWidget);
      });

      testWidgets('ClientDetailScreen renderiza con 0px overflow en $vpName a TextScaler 1.3', (tester) async {
        final client = ClientModel(
          id: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          fullName: 'Carlos Mendoza',
          phone: '987654321',
          registeredDate: '2026-01-01',
        );

        await tester.pumpWidget(
          createTestAppForPhase5B(
            child: ClientDetailScreen(
              client: client,
              autoRefreshOnLoad: false,
              autoTriggerTour: false,
            ),
            screenSize: vpSize,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text("Perfil del Cliente"), findsOneWidget);
        expect(find.byType(InfoTooltipButton), findsOneWidget);
      });
    }
  });

  group('Fase 5B - Activación Manual vía InfoTooltipButton', () {
    testWidgets('PrinterConfigScreen abre modal informativo y botón de tour interactivo', (tester) async {
      await tester.pumpWidget(
        createTestAppForPhase5B(
          child: const PrinterConfigScreen(autoTriggerTour: false),
        ),
      );
      await tester.pumpAndSettle();

      final infoBtn = find.byType(InfoTooltipButton);
      expect(infoBtn, findsOneWidget);

      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      expect(find.text("Impresora Térmica Bluetooth"), findsWidgets);
      expect(find.text("Iniciar guía interactiva paso a paso"), findsOneWidget);
    });
  });
}
