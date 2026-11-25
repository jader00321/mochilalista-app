import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/models/notification_preferences_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/ai_settings_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/analytics_dashboard_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/backup_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/bundle_builder_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/catalog_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/client_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/client_tracking_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/commercial_radar_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_review_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_scan_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_staging_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/license_status_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/loyalty_center_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/manual_quotation_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/matching_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/notifications_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/printer_config_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_create_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_edit_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/profile_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quick_sale_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_scan_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_financial_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_history_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sales_checkout_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sales_history_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/workbench_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';
import 'package:app_movil/features/profile/screens/notifications_screen.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/invoice_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/invoice_history_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_review_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';

class _MockAuth4C extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Plan 21 4C',
    address: 'Av. Principal 100',
    moneda: 'S/ (Soles)',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Angello Propietario',
    phone: '999111222',
    isActive: true,
    business: _business,
  );

  @override
  UserModel? get user => _user;

  @override
  BusinessModel? get currentBusiness => _business;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  bool get isOwner => true;

  @override
  bool get isWorker => false;

  @override
  bool get isCommunityClient => false;

  @override
  bool get canManageClients => true;

  @override
  bool get hasPinCache => true;

  @override
  bool get isPinReminderSnoozed => true;

  @override
  bool get isLoading => false;

  @override
  String get userName => 'Angello Propietario';

  @override
  String get businessName => 'Librería Plan 21 4C';

  @override
  String get errorMessage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTheme4C extends ChangeNotifier implements ThemeProvider {
  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicense4C extends ChangeNotifier implements LicenseProvider {
  String _mode = 'INCLUDED';

  @override
  bool get isActive => true;

  @override
  bool get isPerpetual => false;

  @override
  String get currentPlanName => 'MENSUAL';

  @override
  LicenseModel? get license => null;

  @override
  bool get isUsingByokMode => _mode == 'BYOK';

  @override
  int get remainingAiScans => 45;

  @override
  int get aiAccumulatedScans => 45;

  @override
  Future<void> refreshAiScans({DateTime? overrideNow}) async {}

  @override
  Future<void> setAiSelectedMode(String mode) async {
    _mode = mode;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory4C extends ChangeNotifier implements InventoryProvider {
  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  bool get showStockAlertColors => true;

  @override
  int get totalProductsCount => 20;

  @override
  int get totalPresentationsCount => 30;

  @override
  List<InventoryWrapper> get items => const <InventoryWrapper>[];

  @override
  List<Category> get categories => const <Category>[];

  @override
  List<Brand> get brands => const <Brand>[];

  @override
  List<ProviderModel> get providers => const <ProviderModel>[];

  @override
  Future<void> loadCategories() async {}

  @override
  Future<void> loadBrands() async {}

  @override
  Future<void> loadMasterData({bool showAll = false}) async {}

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
  Future<void> loadProviders() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockNotification4C extends ChangeNotifier implements NotificationProvider {
  final List<NotificationModel> _items;
  final NotificationPreferences _prefs = NotificationPreferences.defaultFor(1);

  _MockNotification4C({List<NotificationModel>? items}) : _items = items ?? [];

  @override
  NotificationPreferences get preferences => _prefs;

  @override
  bool get isLoading => false;

  @override
  List<NotificationModel> get notifications => _items;

  @override
  List<NotificationModel> get allNotifications => _items;

  @override
  List<NotificationModel> get archivedNotifications =>
      _items.where((n) => n.isArchived).toList();

  @override
  List<NotificationModel> get silencedNotifications =>
      _items.where((n) => n.isSilenced).toList();

  @override
  List<NotificationModel> get pendingNotifications =>
      _items.where((n) => n.isActionable && !n.isResolved).toList();

  @override
  List<NotificationModel> get resolvedNotifications =>
      _items.where((n) => n.isActionable && n.isResolved).toList();

  @override
  List<NotificationModel> get historyNotifications => _items;

  @override
  int get unreadCount => _items.where((n) => !n.isRead).length;

  @override
  int get pendingCount => pendingNotifications.length;

  @override
  int get resolvedCount => resolvedNotifications.length;

  @override
  int get totalHistoryCount => historyNotifications.length;

  @override
  int get archivedCount => archivedNotifications.length;

  @override
  int get silencedCount => silencedNotifications.length;

  @override
  Future<void> fetchNotifications() async {}

  @override
  Future<void> markAllAsRead() async {
    for (final n in _items) {
      n.isRead = true;
    }
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockMatching4C extends ChangeNotifier implements MatchingProvider {
  List<MatchPair> _pairs;
  ExtractedMetadata? _metadata;
  ClientModel? _selectedClient;
  bool _hasModifications = false;

  _MockMatching4C({
    List<MatchPair>? pairs,
    ExtractedMetadata? metadata,
  }) : _pairs = pairs ?? _buildSampleMatchPairs(),
       _metadata = metadata ??
           ExtractedMetadata(
             contextMode: QuotationContextMode.school,
             institutionName: 'Colegio San Agustín',
             studentName: 'Mateo López',
             gradeLevel: '3ro Primaria',
           );

  static List<MatchPair> _buildSampleMatchPairs() {
    return [
      MatchPair(
        sourceItem: ExtractedItem(
          id: 1,
          originalText: '2 Cuadernos A4 Rayado',
          fullName: 'Cuaderno A4 Rayado 100H',
          brand: 'Standford',
          quantity: 2,
          unit: 'Unidad',
        ),
        selectedProduct: MatchedProduct(
          productId: 10,
          presentationId: 101,
          fullName: 'Cuaderno A4 Rayado Standford',
          productName: 'Cuaderno A4',
          price: 8.5,
          stock: 40,
          brand: 'Standford',
        ),
        status: MatchStatus.auto,
      ),
    ];
  }

  @override
  bool get isLoading => false;

  @override
  bool get isSaving => false;

  @override
  String get errorMessage => '';

  @override
  List<MatchPair> get pairs => _pairs;

  @override
  ExtractedMetadata? get metadata => _metadata;

  @override
  ClientModel? get selectedClient => _selectedClient;

  @override
  bool get hasModifications => _hasModifications;

  @override
  List<BundleModel> get activeBundles => const <BundleModel>[];

  @override
  Map<int, List<BundleItemModel>> get bundleItemsCache =>
      const <int, List<BundleItemModel>>{};

  @override
  double get totalNetAmount => _pairs.fold(0.0, (s, p) => s + p.subtotal);

  @override
  double get totalSavingsAmount =>
      _pairs.fold(0.0, (s, p) => s + p.totalSavings);

  @override
  int get matchedCount => _pairs.where((p) => p.selectedProduct != null).length;

  @override
  Map<int, int> get sharedDemandPerProduct => const <int, int>{};

  @override
  bool isProductRepeated(int? presentationId) => false;

  @override
  Future<void> initializeAndMatch(
    List<ExtractedItem> items,
    ExtractedMetadata? metadata, {
    bool isClientRole = false,
    bool prioritizeWholesale = false,
  }) async {}

  @override
  void updateMetadata({
    QuotationContextMode? mode,
    String? institution,
    String? student,
    String? grade,
    String? phone,
  }) {
    _metadata = (_metadata ?? ExtractedMetadata()).copyWith(
      contextMode: mode,
      institutionName: institution,
      studentName: student,
      gradeLevel: grade,
    );
  }

  @override
  void setClient(ClientModel? client) {
    _selectedClient = client;
    notifyListeners();
  }

  @override
  void addManualRow() {
    _pairs = [
      ..._pairs,
      MatchPair(
        sourceItem: ExtractedItem(
          id: _pairs.length + 1,
          originalText: 'Ítem Manual',
          fullName: 'Ítem Manual',
        ),
      ),
    ];
    _hasModifications = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockScanner4C extends ChangeNotifier implements ScannerProvider {
  @override
  bool get isLoading => false;

  @override
  String get statusMessage => '';

  @override
  File? get currentImage => File('/tmp/fake_invoice_4c.jpg');

  @override
  bool get hasSavedProgress => false;

  @override
  AIInvoiceResponse? get aiRawData => AIInvoiceResponse(
        invoiceId: 77,
        proveedorDetectado: 'Distribuidora Escolar SAC',
        rucDetectado: '20512345678',
        fechaDetectada: '24/11/2026',
        montoTotalFactura: 120.0,
        items: [
          AIItemExtracted(
            descripcion: 'Cuaderno A4 Rayado x100H',
            productoPadreEstimado: 'Cuaderno A4 Rayado',
            marcaDetectada: 'Standford',
            umpCompra: 'Caja',
            unidadesPorLote: 12,
            cantidadUmpComprada: 2,
            precioUmpProveedor: 60.0,
            totalPagoLote: 120.0,
          ),
        ],
      );

  @override
  StagingResponse? get stagingData => StagingResponse(
        invoiceId: 77,
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Distribuidora Escolar SAC',
        rucProveedor: '20512345678',
        fechaFactura: '24/11/2026',
        montoTotalFactura: 120.0,
        productosAgrupados: [
          StagingProductGroup(
            nombrePadre: 'Cuaderno A4 Rayado',
            marcaTexto: 'Standford',
            matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
            matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
            variantes: [
              StagingVariant(
                nombreEspecifico: '100 Hojas',
                umpCompra: 'Caja',
                cantidadUmpComprada: 2,
                precioUmpProveedor: 60.0,
                totalPagoLote: 120.0,
                unidadesPorLote: 12,
                unidadVenta: 'Unidad',
                unidadesPorVenta: 1,
                costoUnitarioSugerido: 5.0,
                factorGananciaVentaSugerido: 1.4,
                precioVentaSugerido: 7.0,
                matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
              ),
            ],
          ),
        ],
      );

  @override
  int get countLinked => 0;

  @override
  int get countNew => 1;

  @override
  int get totalActiveVariants => 1;

  @override
  bool get hasUnresolvedStock => false;

  @override
  int get unresolvedStockErrorsCount => 0;

  @override
  String? get highlightedGroupUuid => null;

  @override
  String? get highlightedVariantUuid => null;

  @override
  GlobalKey? getVariantKey(String uuid) => null;

  @override
  void registerVariantKey(String uuid, GlobalKey key) {}

  @override
  void unregisterVariantKey(String uuid) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInvoice4C extends ChangeNotifier implements InvoiceProvider {
  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  List<InvoiceModel> get invoices => const <InvoiceModel>[];

  @override
  bool get hasMoreData => false;

  @override
  Future<void> fetchInvoices({bool reset = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

bool _containsEmojiGlyph(String text) {
  final emojiPattern = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]|[👁🔍✅❌✨🚀💡📊⚡⚠🔗🛡📌🤖📄💰🏷📷✍ⓘ]',
    unicode: true,
  );
  return emojiPattern.hasMatch(text);
}

Future<void> _pumpBounded(
  WidgetTester tester, {
  int steps = 5,
  Duration step = const Duration(milliseconds: 60),
}) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxSteps = 20,
}) async {
  for (int i = 0; i < maxSteps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Widget _wrapWithProviders({
  required Widget child,
  Size size = const Size(412, 915),
  double textScale = 1.0,
  AuthProvider? auth,
  LicenseProvider? license,
  InventoryProvider? inventory,
  NotificationProvider? notifications,
  MatchingProvider? matching,
  ScannerProvider? scanner,
  InvoiceProvider? invoice,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth ?? _MockAuth4C()),
      ChangeNotifierProvider<ThemeProvider>.value(value: _MockTheme4C()),
      ChangeNotifierProvider<LicenseProvider>.value(
        value: license ?? _MockLicense4C(),
      ),
      ChangeNotifierProvider<InventoryProvider>.value(
        value: inventory ?? _MockInventory4C(),
      ),
      ChangeNotifierProvider<NotificationProvider>.value(
        value: notifications ?? _MockNotification4C(),
      ),
      ChangeNotifierProvider<MatchingProvider>.value(
        value: matching ?? _MockMatching4C(),
      ),
      ChangeNotifierProvider<ScannerProvider>.value(
        value: scanner ?? _MockScanner4C(),
      ),
      ChangeNotifierProvider<InvoiceProvider>.value(
        value: invoice ?? _MockInvoice4C(),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(home: child),
    ),
  );
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
}

Future<void> _resetTestViewport(WidgetTester tester) async {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  await tester.binding.setSurfaceSize(null);
}

Future<void> _startInteractiveTourFromTooltip(WidgetTester tester) async {
  final infoBtn = find.byType(InfoTooltipButton).first;
  await _pumpUntilFound(tester, infoBtn);
  expect(infoBtn, findsOneWidget);

  await tester.tap(infoBtn);
  await _pumpBounded(tester, steps: 6);

  final startBtn = find.text('Iniciar guía interactiva paso a paso');
  await _pumpUntilFound(tester, startBtn);
  expect(startBtn, findsOneWidget);

  await tester.tap(startBtn);
  await _pumpBounded(tester, steps: 8);

  final introCta = find.text('Guíame');
  if (introCta.evaluate().isNotEmpty) {
    await tester.tap(introCta);
    await _pumpBounded(tester, steps: 8);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es_ES');
    await initializeDateFormatting('es_PE');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.resetRuntimeLockForTesting();
    InteractiveTourService.autoTriggerOverrideForTesting = null;
  });

  tearDown(() {
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  group('Grupo 1 - Integridad de las 5 Configs Tier-1 de Sub-turno 4C', () {
    test('AiSettingsTour (4 pasos), NotificationsTour (4 pasos), MatchingTour (5 pasos), InvoiceReviewTour (4 pasos) e InvoiceStagingTour (4 pasos) sin emojis crudos', () {
      final configs = <ScreenTourConfig>[
        AiSettingsTour.buildConfig(),
        NotificationsTour.buildConfig(),
        MatchingTour.buildConfig(),
        InvoiceReviewTour.buildConfig(),
        InvoiceStagingTour.buildConfig(),
      ];

      expect(configs.map((c) => c.steps.length).toList(), [4, 4, 5, 4, 4]);
      expect(configs.map((c) => c.screenId).toList(), [
        'ai_settings_screen',
        'notifications_screen',
        'matching_screen',
        'invoice_review_screen',
        'invoice_staging_screen',
      ]);

      for (final config in configs) {
        expect(config.screenTitle, isNotEmpty);
        expect(config.welcomeSummary, isNotEmpty);
        expect(_containsEmojiGlyph(config.screenTitle), isFalse);
        expect(_containsEmojiGlyph(config.welcomeSummary), isFalse);
        final stepIds = <String>{};
        for (final step in config.steps) {
          expect(step.id, isNotEmpty);
          expect(stepIds.add(step.id), isTrue);
          expect(step.title, isNotEmpty);
          expect(step.description, isNotEmpty);
          expect(step.tip, isNotNull);
          expect(_containsEmojiGlyph(step.title), isFalse);
          expect(_containsEmojiGlyph(step.description), isFalse);
          expect(_containsEmojiGlyph(step.tip!), isFalse);
        }
      }
    });

    test('MatchingTour ejecuta hooks onCancel y onDismiss para restaurar acordeones', () async {
      int restoredClientCount = 0;
      int restoredQuoteCount = 0;

      final config = MatchingTour.buildConfig(
        onRestoreClientPanel: () async => restoredClientCount++,
        onRestoreQuoteData: () async => restoredQuoteCount++,
      );

      await config.onCancel?.call();
      await config.onDismiss?.call();

      expect(restoredClientCount, 2);
      expect(restoredQuoteCount, 2);
    });
  });

  group('Grupo 2 - Recorridos Interactivos Reales en las 5 Pantallas Tier-1', () {
    testWidgets('AiSettingsScreen completa los 4 pasos vía (i) y finaliza con ¡Listo!', (tester) async {
      await _setTestViewport(tester, const Size(412, 915));
      addTearDown(() => _resetTestViewport(tester));

      await tester.pumpWidget(
        _wrapWithProviders(
          child: const AiSettingsScreen(autoTriggerTour: false),
        ),
      );
      await _pumpBounded(tester, steps: 8);

      await _startInteractiveTourFromTooltip(tester);

      final expectedTitles = [
        'Selector de Modo IA: Oficial vs BYOK',
        'Monitor de Cuota Acumulativa',
        'Bóveda Multi-Clave y Prueba en Vivo',
        'Protección Cifrada y Guía Gratuita',
      ];

      for (int i = 0; i < expectedTitles.length; i++) {
        await _pumpUntilFound(tester, find.text(expectedTitles[i]));
        expect(find.text(expectedTitles[i]), findsOneWidget);
        if (i < expectedTitles.length - 1) {
          await tester.tap(find.text('Siguiente'));
          await _pumpBounded(tester, steps: 6);
        } else {
          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, steps: 6);
        }
      }

      expect(find.text('¡Listo!'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_screen_seen_ai_settings_screen'), isTrue);
    });

    testWidgets('NotificationsScreen completa sus 4 pasos con alertas activas y también soporta estado vacío sin errores', (tester) async {
      await _setTestViewport(tester, const Size(412, 915));
      addTearDown(() => _resetTestViewport(tester));

      final sampleAlert = NotificationModel(
        id: 1,
        title: 'Cuota vencida hoy',
        message: 'Saldo pendiente de S/ 50.00',
        type: 'alerta',
        isRead: false,
        createdAt: DateTime.now(),
        prioridad: 'Alta',
        nivelPrioridad: 'critica',
        objetoRelacionadoTipo: 'cuota',
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          notifications: _MockNotification4C(items: [sampleAlert]),
          child: const NotificationsScreen(autoTriggerTour: false),
        ),
      );
      await _pumpBounded(tester, steps: 8);

      await _startInteractiveTourFromTooltip(tester);

      final expectedTitles = [
        'Filtros por Estado, Categoría y Fecha',
        'Tarjetas Interactivas y Estado al Día',
        'Silenciamiento y Preferencias de Canal',
        'Archivadas y Limpieza Rápida',
      ];

      for (int i = 0; i < expectedTitles.length; i++) {
        await _pumpUntilFound(tester, find.text(expectedTitles[i]));
        expect(find.text(expectedTitles[i]), findsOneWidget);
        if (i < expectedTitles.length - 1) {
          await tester.tap(find.text('Siguiente'));
          await _pumpBounded(tester, steps: 6);
        } else {
          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, steps: 6);
        }
      }

      // Estado vacío: verificar anclaje seguro sin tarjetas activas
      await tester.pumpWidget(
        _wrapWithProviders(
          notifications: _MockNotification4C(items: []),
          child: const NotificationsScreen(autoTriggerTour: false),
        ),
      );
      await _pumpBounded(tester, steps: 8);
      await _startInteractiveTourFromTooltip(tester);
      await _pumpUntilFound(tester, find.text('Filtros por Estado, Categoría y Fecha'));
      await tester.tap(find.text('Siguiente'));
      await _pumpBounded(tester, steps: 6);
      await _pumpUntilFound(tester, find.text('Tarjetas Interactivas y Estado al Día'));
      expect(find.text('Tarjetas Interactivas y Estado al Día'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _pumpBounded(tester, steps: 6);

      expect(tester.takeException(), isNull);
    });

    testWidgets('MatchingScreen recorre 5 pasos expandiendo/restaurando acordeones y cierra limpio con Atrás/X sin error en dispose', (tester) async {
      await _setTestViewport(tester, const Size(412, 915));
      addTearDown(() => _resetTestViewport(tester));

      await tester.pumpWidget(
        _wrapWithProviders(
          child: MatchingScreen(
            extractedItems: [
              ExtractedItem(
                id: 1,
                originalText: 'Cuaderno A4',
                fullName: 'Cuaderno A4 Rayado',
              ),
            ],
            autoTriggerTour: false,
          ),
        ),
      );
      await _pumpBounded(tester, steps: 8);

      await _startInteractiveTourFromTooltip(tester);

      await _pumpUntilFound(tester, find.text('Cliente, Colegio y Modo Comercial'));
      expect(find.text('Cliente, Colegio y Modo Comercial'), findsOneWidget);
      await _pumpBounded(tester, steps: 8);
      // Al expandir acordeón 2 aparece el selector Mayorista
      expect(find.text('Mayorista'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await _pumpBounded(tester, steps: 8);
      await _pumpUntilFound(tester, find.text('Emparejamiento IA, Equivalentes y Stock'));
      expect(find.text('Emparejamiento IA, Equivalentes y Stock'), findsOneWidget);

      // Avanzar hasta paso 4 (Título y Notas) y probar cierre con botón Atrás del navegador
      await tester.tap(find.text('Siguiente'));
      await _pumpBounded(tester, steps: 8, step: const Duration(milliseconds: 80));
      await tester.tap(find.text('Siguiente'));
      await _pumpUntilFound(tester, find.text('4 / 5'));
      await _pumpBounded(tester, steps: 10, step: const Duration(milliseconds: 80));
      expect(find.text('Título Editable y Notas del Pedido'), findsOneWidget);

      // Simular cierre con botón Atrás
      await tester.binding.handlePopRoute();
      await _pumpBounded(tester, steps: 14, step: const Duration(milliseconds: 80));
      expect(InteractiveTourService.isTourActive, isFalse);
      expect(find.text('Título Editable y Notas del Pedido'), findsNothing);

      // Reabrir, probar cierre con botón X y verificar cierre limpio ante unmount repentino
      await _startInteractiveTourFromTooltip(tester);
      await _pumpUntilFound(tester, find.byTooltip('Cerrar guía'));
      await tester.tap(find.byTooltip('Cerrar guía'));
      await _pumpBounded(tester, steps: 10, step: const Duration(milliseconds: 80));
      expect(InteractiveTourService.isTourActive, isFalse);

      await _startInteractiveTourFromTooltip(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpBounded(tester, steps: 10, step: const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
    });

    testWidgets('InvoiceReviewScreen recorre 4 pasos completos vía (i) y finaliza con ¡Listo!', (tester) async {
      await _setTestViewport(tester, const Size(412, 915));
      addTearDown(() => _resetTestViewport(tester));

      await tester.pumpWidget(
        _wrapWithProviders(
          child: const InvoiceReviewScreen(autoTriggerTour: false),
        ),
      );
      await _pumpBounded(tester, steps: 8);

      await _startInteractiveTourFromTooltip(tester);

      final expectedTitles = [
        'Visor Dividido con Zoom Táctil',
        'Proveedor, RUC, Fecha y Total',
        'Edición de Cantidades, UMP y Costos',
        'Confirmar y Clasificar en Inventario',
      ];

      for (int i = 0; i < expectedTitles.length; i++) {
        await _pumpUntilFound(tester, find.text(expectedTitles[i]));
        expect(find.text(expectedTitles[i]), findsOneWidget);
        if (i < expectedTitles.length - 1) {
          await tester.tap(find.text('Siguiente'));
          await _pumpBounded(tester, steps: 6);
        } else {
          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, steps: 6);
        }
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('InvoiceStagingScreen recorre 4 pasos completos vía (i) y finaliza con ¡Listo!', (tester) async {
      await _setTestViewport(tester, const Size(412, 915));
      addTearDown(() => _resetTestViewport(tester));

      await tester.pumpWidget(
        _wrapWithProviders(
          child: const InvoiceStagingScreen(autoTriggerTour: false),
        ),
      );
      await _pumpBounded(tester, steps: 8);

      await _startInteractiveTourFromTooltip(tester);

      final expectedTitles = [
        'Tarjeta de Proveedor y Factura',
        'Agrupación Inteligente: Nuevos vs Existentes',
        'Edición de Presentaciones, Precios y Stock',
        'Ingreso Atómico al Inventario',
      ];

      for (int i = 0; i < expectedTitles.length; i++) {
        await _pumpUntilFound(tester, find.text(expectedTitles[i]));
        expect(find.text(expectedTitles[i]), findsOneWidget);
        if (i < expectedTitles.length - 1) {
          await tester.tap(find.text('Siguiente'));
          await _pumpBounded(tester, steps: 6);
        } else {
          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, steps: 6);
        }
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('Grupo 3 - Blindaje Responsivo 0px Overflow en 320/360/412dp @ 1.3x y Tier-2', () {
    const viewports = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ];

    testWidgets('Las 5 pantallas Tier-1 y el AppBar Tier-2 renderizan con 0px Overflow a TextScaler 1.3x en 320, 360 y 412dp', (tester) async {
      addTearDown(() => _resetTestViewport(tester));
      final sampleAlert = NotificationModel(
        id: 2,
        title: 'Alerta stock mínimo',
        message: 'Cuaderno A4 por debajo del mínimo',
        type: 'alerta',
        isRead: false,
        createdAt: DateTime.now(),
        prioridad: 'Media',
        nivelPrioridad: 'preventiva',
        objetoRelacionadoTipo: 'producto',
      );

      for (final size in viewports) {
        await _setTestViewport(tester, size);

        final List<({String name, Widget child})> screens = [
          (
            name: 'AiSettingsScreen',
            child: const AiSettingsScreen(autoTriggerTour: false),
          ),
          (
            name: 'NotificationsScreen',
            child: const NotificationsScreen(autoTriggerTour: false),
          ),
          (
            name: 'MatchingScreen',
            child: MatchingScreen(
              extractedItems: [
                ExtractedItem(
                  id: 1,
                  originalText: 'Lápiz 2B',
                  fullName: 'Lápiz Grafito 2B',
                ),
              ],
              autoTriggerTour: false,
            ),
          ),
          (
            name: 'InvoiceReviewScreen',
            child: const InvoiceReviewScreen(autoTriggerTour: false),
          ),
          (
            name: 'InvoiceStagingScreen',
            child: const InvoiceStagingScreen(autoTriggerTour: false),
          ),
          (
            name: 'InvoiceHistoryScreen',
            child: const InvoiceHistoryScreen(),
          ),
        ];

        for (final entry in screens) {
          final errors = <FlutterErrorDetails>[];
          final prevHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
          };

          try {
            await tester.pumpWidget(
              _wrapWithProviders(
                size: size,
                textScale: 1.3,
                notifications: _MockNotification4C(items: [sampleAlert]),
                child: entry.child,
              ),
            );
            await _pumpBounded(tester, steps: 8);
          } finally {
            FlutterError.onError = prevHandler;
          }

          final overflowErrors = errors
              .where((e) => e.toString().toLowerCase().contains('overflow'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason:
                '${entry.name} reportó overflow a ${size.width}x${size.height} @ 1.3x: $overflowErrors',
          );
        }
      }

      await _resetTestViewport(tester);
    });

    testWidgets('Tier-2 InvoiceHistoryScreen abre InfoTooltipButton limpio sin emojis crudos', (tester) async {
      await _setTestViewport(tester, const Size(320, 568));
      addTearDown(() => _resetTestViewport(tester));

      await tester.pumpWidget(
        _wrapWithProviders(
          size: const Size(320, 568),
          textScale: 1.3,
          child: const InvoiceHistoryScreen(),
        ),
      );
      await _pumpBounded(tester, steps: 6);

      await tester.tap(find.byType(InfoTooltipButton));
      await _pumpBounded(tester, steps: 6);

      expect(find.text('Historial de Facturas'), findsWidgets);
      final sheetTextFinder = find.textContaining('Escaneada IA');
      expect(sheetTextFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(sheetTextFinder);
      expect(_containsEmojiGlyph(textWidget.data ?? ''), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Grupo 4 - Paridad Oficial 35 Pantallas, Exclusión lock_screen y Sello Fase 2', () {
    test('knownScreenIds tiene exactamente 35 IDs únicos en paridad 1:1 y excluye lock_screen', () {
      expect(InteractiveTourService.knownScreenIds.length, 35);
      expect(InteractiveTourService.knownScreenIds.toSet().length, 35);
      expect(InteractiveTourService.knownScreenIds, isNot(contains('lock_screen')));
      expect(InteractiveTourService.knownScreenIds, isNot(contains('products_tab')));
      expect(InteractiveTourService.knownScreenIds, isNot(contains('quick_quotation_screen')));

      // Tier-2 permanece estrictamente fuera del conteo Tier-1 para preservar auto-deshabilitación exacta
      for (final tier2Id in const [
        'smart_restock_screen',
        'predictive_analytics_screen',
        'audit_trail_screen',
        'invoice_history_screen',
        'invoice_detail_screen',
        'pdf_preview_screen',
        'whatsapp_preview_screen',
      ]) {
        expect(InteractiveTourService.knownScreenIds, isNot(contains(tier2Id)));
      }

      final allConfigs = <ScreenTourConfig>[
        HomeScreenTour.buildConfig(keys: HomeScreenTourKeys()),
        InventoryTour.buildConfigForTab(tabIndex: 0, keys: InventoryTourKeys()),
        InventoryTour.buildConfigForTab(tabIndex: 1, keys: InventoryTourKeys()),
        InventoryTour.buildConfigForTab(tabIndex: 2, keys: InventoryTourKeys()),
        InventoryTour.buildConfigForTab(tabIndex: 3, keys: InventoryTourKeys()),
        InventoryTour.buildConfigForTab(tabIndex: 4, keys: InventoryTourKeys()),
        WorkbenchTour.buildConfig(keys: WorkbenchTourKeys()),
        QuickSaleTour.buildConfig(keys: QuickSaleTourKeys()),
        ManualQuotationTour.buildConfig(keys: ManualQuotationTourKeys()),
        MatchingTour.buildConfig(keys: MatchingTourKeys()),
        QuotationDetailTour.buildConfig(keys: QuotationDetailTourKeys()),
        ProductCreateTour.buildConfig(keys: ProductCreateTourKeys()),
        ProductDetailTour.buildConfig(keys: ProductDetailTourKeys()),
        ProductEditTour.buildConfig(keys: ProductEditTourKeys()),
        ProfileScreenTour.buildConfig(keys: ProfileScreenTourKeys()),
        AiSettingsTour.buildConfig(keys: AiSettingsTourKeys()),
        NotificationsTour.buildConfig(keys: NotificationsTourKeys()),
        CommercialRadarTour.buildConfig(keys: CommercialRadarTourKeys()),
        BackupScreenTour.buildConfig(keys: BackupScreenTourKeys()),
        ClientTrackingTour.buildConfig(keys: ClientTrackingTourKeys()),
        SalesHistoryTour.buildConfig(keys: SalesHistoryTourKeys()),
        SaleHistoryDetailTour.buildConfig(keys: SaleHistoryDetailTourKeys()),
        SaleFinancialDetailTour.buildConfig(keys: SaleFinancialDetailTourKeys()),
        LicenseStatusTour.buildConfig(keys: LicenseStatusTourKeys()),
        CatalogTour.buildConfig(keys: CatalogTourKeys()),
        InvoiceScanTour.buildConfig(keys: InvoiceScanTourKeys()),
        InvoiceReviewTour.buildConfig(keys: InvoiceReviewTourKeys()),
        InvoiceStagingTour.buildConfig(keys: InvoiceStagingTourKeys()),
        QuotationScanTour.buildConfig(keys: QuotationScanTourKeys()),
        SalesCheckoutTour.buildConfig(keys: SalesCheckoutTourKeys()),
        ClientDetailTour.buildConfig(keys: ClientDetailTourKeys()),
        LoyaltyCenterTour.buildConfig(keys: LoyaltyCenterTourKeys()),
        AnalyticsDashboardTour.buildConfig(keys: AnalyticsDashboardTourKeys()),
        BundleBuilderTour.buildConfig(keys: BundleBuilderTourKeys()),
        PrinterConfigTour.buildConfig(keys: PrinterConfigTourKeys()),
      ];

      expect(allConfigs.length, 35);
      final configIds = allConfigs.map((c) => c.screenId).toSet();
      expect(InteractiveTourService.knownScreenIds.toSet(), equals(configIds));
    });

    test('Sello automático Fase 2 bloquea las 5 pantallas nuevas de 4C al actualizar sin reactivar guías', () async {
      InteractiveTourService.autoTriggerOverrideForTesting = true;
      await InteractiveTourService.sealAutomaticToursForExistingOrUpdatedInstall();

      for (final newId in const [
        'ai_settings_screen',
        'notifications_screen',
        'matching_screen',
        'invoice_review_screen',
        'invoice_staging_screen',
      ]) {
        expect(
          await InteractiveTourService.shouldAutoShowTour(newId),
          isFalse,
          reason: '$newId no debe reactivarse automáticamente tras sellado de actualización',
        );
      }
    });
  });
}
