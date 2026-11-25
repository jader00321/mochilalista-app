import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/catalog_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_scan_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_scan_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sales_checkout_tour.dart';

import 'package:app_movil/features/scanner/screens/scan_screen.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/catalog/screens/catalog/catalog_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_checkout_screen.dart';

// Mocks livianos para tests de widget
class MockAuthProviderForPhase5A extends ChangeNotifier implements AuthProvider {
  @override
  int? get activeBusinessId => 1;

  @override
  bool get hasActiveContext => true;

  @override
  bool get isCommunityClient => false;

  @override
  bool get canManageClients => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLicenseProviderForPhase5A extends ChangeNotifier implements LicenseProvider {
  @override
  int get remainingAiScans => 42;

  @override
  bool get isUsingByokMode => false;

  @override
  bool get isUsingCustomApiKey => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockScannerProviderForPhase5A extends ChangeNotifier implements ScannerProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSmartQuotationProviderForPhase5A extends ChangeNotifier implements SmartQuotationProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestAppForPhase5A({
  required Widget child,
  LicenseProvider? licenseProvider,
  bool isDark = true,
  Size screenSize = const Size(412, 915),
  EdgeInsets viewPadding = const EdgeInsets.only(bottom: 48),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProviderForPhase5A()),
      ChangeNotifierProvider<ScannerProvider>.value(value: MockScannerProviderForPhase5A()),
      ChangeNotifierProvider<SmartQuotationProvider>.value(value: MockSmartQuotationProviderForPhase5A()),
      if (licenseProvider != null)
        ChangeNotifierProvider<LicenseProvider>.value(value: licenseProvider)
      else
        Provider<LicenseProvider?>.value(value: null),
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
  });

  group('FASE 5A - Catálogo Canónico y Configuraciones de Tour', () {
    test('1. Catálogo canónico knownScreenIds incluye los IDs oficiales (35 pantallas en catálogo completo)', () {
      expect(InteractiveTourService.knownScreenIds.length, 35);
      expect(InteractiveTourService.knownScreenIds, contains('catalog_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('invoice_scan_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('quotation_scan_screen'));
      expect(InteractiveTourService.knownScreenIds, contains('sales_checkout_screen'));
    });

    test('2. CatalogTour: 4 pasos, hooks de ofertas y menú inferior, cero emojis crudos', () async {
      final keys = CatalogTourKeys();
      bool offersExpanded = false;
      bool offersCollapsed = false;
      bool bottomMenuExpanded = false;
      bool bottomMenuCollapsed = false;

      final config = CatalogTour.buildConfig(
        keys: keys,
        onExpandOffers: () async => offersExpanded = true,
        onCollapseOffers: () async => offersCollapsed = true,
        onExpandBottomMenu: () async => bottomMenuExpanded = true,
        onCollapseBottomMenu: () async => bottomMenuCollapsed = true,
      );

      expect(config.screenId, 'catalog_screen');
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, 4);

      final stepIds = config.steps.map((s) => s.id).toList();
      expect(stepIds, [
        'step_search_filters',
        'step_offers_section',
        'step_product_grid',
        'step_cart_action',
      ]);

      // Verificar ejecución de hooks dinámicos
      final stepOffers = config.steps[1];
      expect(stepOffers.onBeforeStep, isNotNull);
      expect(stepOffers.onAfterStep, isNotNull);
      await stepOffers.onBeforeStep!();
      expect(offersExpanded, isTrue);
      await stepOffers.onAfterStep!();
      expect(offersCollapsed, isTrue);

      final stepCart = config.steps[3];
      expect(stepCart.onBeforeStep, isNotNull);
      expect(stepCart.onAfterStep, isNotNull);
      await stepCart.onBeforeStep!();
      expect(bottomMenuExpanded, isTrue);
      await stepCart.onAfterStep!();
      expect(bottomMenuCollapsed, isTrue);

      // Verificación de textos no vacíos y ausencia de emojis crudos
      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(step.tip, isNotEmpty);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
        expect(rawEmojiRegex.hasMatch(step.tip ?? ''), isFalse);
      }
    });

    test('3. InvoiceScanTour: 4 pasos concisos, claves dedicadas, cero emojis crudos', () {
      final keys = InvoiceScanTourKeys();
      final config = InvoiceScanTour.buildConfig(keys: keys);

      expect(config.screenId, 'invoice_scan_screen');
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, 4);

      final stepIds = config.steps.map((s) => s.id).toList();
      expect(stepIds, [
        'step_hero_quota',
        'step_camera_card',
        'step_gallery_card',
        'step_history_button',
      ]);

      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(step.tip, isNotEmpty);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
        expect(rawEmojiRegex.hasMatch(step.tip ?? ''), isFalse);
      }
    });

    test('4. QuotationScanTour: 3 pasos concisos, claves de escenario y captura, cero emojis crudos', () {
      final keys = QuotationScanTourKeys();
      final config = QuotationScanTour.buildConfig(keys: keys);

      expect(config.screenId, 'quotation_scan_screen');
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, 3);

      final stepIds = config.steps.map((s) => s.id).toList();
      expect(stepIds, [
        'step_scenarios',
        'step_capture_actions',
        'step_client_hint',
      ]);

      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(step.tip, isNotEmpty);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
        expect(rawEmojiRegex.hasMatch(step.tip ?? ''), isFalse);
      }
    });

    test('5. SalesCheckoutTour: 4 pasos concisos, claves de checkout, cero emojis crudos', () {
      final keys = SalesCheckoutTourKeys();
      final config = SalesCheckoutTour.buildConfig(keys: keys);

      expect(config.screenId, 'sales_checkout_screen');
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, 4);

      final stepIds = config.steps.map((s) => s.id).toList();
      expect(stepIds, [
        'step_client_selector',
        'step_payment_methods',
        'step_discounts_loyalty',
        'step_confirm_sale',
      ]);

      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(step.tip, isNotEmpty);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
        expect(rawEmojiRegex.hasMatch(step.tip ?? ''), isFalse);
      }
    });
  });

  group('FASE 5A - Integración en ScanScreen (Modo Factura y Modo Lista)', () {
    testWidgets('6. ScanScreen (Modo Factura): Anclajes de tour heroQuota, cameraCard, galleryCard, historyButton y tooltip', (tester) async {
      final invoiceKeys = InvoiceScanTourKeys();

      await tester.pumpWidget(
        createTestAppForPhase5A(
          licenseProvider: MockLicenseProviderForPhase5A(),
          child: ScanScreen(
            mode: ScanMode.invoice,
            autoTriggerTour: false,
            invoiceTourKeys: invoiceKeys,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que los widgets con claves de tour estén montados
      expect(find.byKey(invoiceKeys.heroQuotaKey), findsOneWidget);
      expect(find.byKey(invoiceKeys.cameraCardKey), findsOneWidget);
      expect(find.byKey(invoiceKeys.galleryCardKey), findsOneWidget);
      expect(find.byKey(invoiceKeys.historyButtonKey), findsOneWidget);

      // Verificar InfoTooltipButton en AppBar
      expect(find.byType(InfoTooltipButton), findsOneWidget);

      // Validar dimensiones >= 12x12 de los anclajes
      final RenderBox heroBox = tester.renderObject(find.byKey(invoiceKeys.heroQuotaKey));
      final RenderBox cameraBox = tester.renderObject(find.byKey(invoiceKeys.cameraCardKey));
      final RenderBox galleryBox = tester.renderObject(find.byKey(invoiceKeys.galleryCardKey));
      final RenderBox historyBox = tester.renderObject(find.byKey(invoiceKeys.historyButtonKey));

      expect(heroBox.size.width >= 12.0 && heroBox.size.height >= 12.0, isTrue);
      expect(cameraBox.size.width >= 12.0 && cameraBox.size.height >= 12.0, isTrue);
      expect(galleryBox.size.width >= 12.0 && galleryBox.size.height >= 12.0, isTrue);
      expect(historyBox.size.width >= 12.0 && historyBox.size.height >= 12.0, isTrue);
    });

    testWidgets('7. ScanScreen (Modo Lista): Anclajes de tour scenarios, captureActions, clientHint y tooltip SIN alterar diseño', (tester) async {
      final quotationKeys = QuotationScanTourKeys();

      await tester.pumpWidget(
        createTestAppForPhase5A(
          child: ScanScreen(
            mode: ScanMode.quotation,
            autoTriggerTour: false,
            quotationTourKeys: quotationKeys,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que los widgets con claves de tour estén montados
      expect(find.byKey(quotationKeys.scenariosKey), findsOneWidget);
      expect(find.byKey(quotationKeys.captureActionsKey), findsOneWidget);
      expect(find.byKey(quotationKeys.clientHintKey), findsOneWidget);

      // Verificar InfoTooltipButton en AppBar de Modo Lista
      expect(find.byType(InfoTooltipButton), findsOneWidget);

      // No debe contener el Hero card ni el botón de historial de facturas
      expect(find.text("Procesa tu Compra"), findsNothing);
      expect(find.byTooltip("Historial de Facturas"), findsNothing);

      // Validar dimensiones >= 12x12
      final RenderBox scenariosBox = tester.renderObject(find.byKey(quotationKeys.scenariosKey));
      final RenderBox captureBox = tester.renderObject(find.byKey(quotationKeys.captureActionsKey));
      final RenderBox hintBox = tester.renderObject(find.byKey(quotationKeys.clientHintKey));

      expect(scenariosBox.size.width >= 12.0 && scenariosBox.size.height >= 12.0, isTrue);
      expect(captureBox.size.width >= 12.0 && captureBox.size.height >= 12.0, isTrue);
      expect(hintBox.size.width >= 12.0 && hintBox.size.height >= 12.0, isTrue);
    });

    testWidgets('8. IndexedStack sin choques: CatalogScreen con autoTriggerTour: false no dispara tour en initState', (tester) async {
      await InteractiveTourService.setAutomaticToursEnabled(true);
      expect(InteractiveTourService.isTourActive, isFalse);

      final catKeys = CatalogTourKeys();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProviderForPhase5A()),
            ChangeNotifierProvider<CatalogProvider>(create: (_) => CatalogProvider()),
            ChangeNotifierProvider<PromotionProvider>(create: (_) => PromotionProvider()),
            ChangeNotifierProvider<InventoryProvider>(create: (_) => InventoryProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CatalogScreen(
                autoTriggerTour: false,
                tourKeys: catKeys,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Jamás debe iniciar tour automático
      expect(InteractiveTourService.isTourActive, isFalse);

      // Los anclajes base y el botón de InfoTooltip deben estar presentes
      expect(find.byKey(catKeys.searchFiltersKey), findsOneWidget);
      expect(find.byType(InfoTooltipButton), findsOneWidget);
    });

    test('9. SalesCheckoutScreen: constructor expone autoTriggerTour y tourKeys de forma configurable', () {
      final keys = SalesCheckoutTourKeys();
      const screenDefault = SalesCheckoutScreen(quotationId: 101);
      expect(screenDefault.autoTriggerTour, isTrue);
      expect(screenDefault.tourKeys, isNull);

      final screenCustom = SalesCheckoutScreen(
        quotationId: 102,
        autoTriggerTour: false,
        tourKeys: keys,
      );
      expect(screenCustom.autoTriggerTour, isFalse);
      expect(screenCustom.tourKeys, equals(keys));
      expect(screenCustom.tourKeys!.clientSelectorKey, equals(keys.clientSelectorKey));
      expect(screenCustom.tourKeys!.paymentMethodsKey, equals(keys.paymentMethodsKey));
      expect(screenCustom.tourKeys!.discountsLoyaltyKey, equals(keys.discountsLoyaltyKey));
      expect(screenCustom.tourKeys!.confirmSaleButtonKey, equals(keys.confirmSaleButtonKey));
    });

    test('10. CatalogTourKeys e InvoiceScanTourKeys generan GlobalKeys únicos e independientes por instancia', () {
      final keys1 = CatalogTourKeys();
      final keys2 = CatalogTourKeys();

      expect(keys1.searchFiltersKey, isNot(equals(keys2.searchFiltersKey)));
      expect(keys1.offersSectionKey, isNot(equals(keys2.offersSectionKey)));
      expect(keys1.productGridKey, isNot(equals(keys2.productGridKey)));
      expect(keys1.cartActionKey, isNot(equals(keys2.cartActionKey)));

      final invoiceKeys1 = InvoiceScanTourKeys();
      final invoiceKeys2 = InvoiceScanTourKeys();

      expect(invoiceKeys1.heroQuotaKey, isNot(equals(invoiceKeys2.heroQuotaKey)));
      expect(invoiceKeys1.cameraCardKey, isNot(equals(invoiceKeys2.cameraCardKey)));
      expect(invoiceKeys1.galleryCardKey, isNot(equals(invoiceKeys2.galleryCardKey)));
      expect(invoiceKeys1.historyButtonKey, isNot(equals(invoiceKeys2.historyButtonKey)));
    });
  });
}
