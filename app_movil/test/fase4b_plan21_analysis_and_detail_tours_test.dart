import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/commercial_radar_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_edit_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_history_detail_tour.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/services/link_health_verifier.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/manual_quote_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';

class _MockAuth4B extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Plan 21 4B',
    address: 'Jr. Unión 240',
    moneda: 'S/ (Soles)',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Angello Vendedor',
    phone: '999888777',
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
  bool get isLoading => false;

  @override
  String get userName => 'Angello Vendedor';

  @override
  String get businessName => 'Librería Plan 21 4B';

  @override
  String get errorMessage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTheme4B extends ChangeNotifier implements ThemeProvider {
  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicense4B extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isPerpetual => false;

  @override
  bool get isActive => true;

  @override
  String get currentPlanName => 'MENSUAL';

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory4B extends ChangeNotifier implements InventoryProvider {
  final Product _product;

  _MockInventory4B(this._product);

  @override
  List<Category> get categories => const <Category>[];

  @override
  List<Brand> get brands => const <Brand>[];

  @override
  List<ProviderModel> get providers => const <ProviderModel>[];

  @override
  List<InventoryWrapper> get items => const <InventoryWrapper>[];

  @override
  bool get hasCreationDraft => false;

  @override
  bool get isLoading => false;

  @override
  String errorMessage = '';

  @override
  String getCategoryName(int? categoryId) => 'Útiles Escolares';

  @override
  String getBrandName(int? brandId) => 'Faber-Castell';

  @override
  Future<void> loadMasterData({bool showAll = false}) async {}

  @override
  Future<Product?> fetchProductById(int productId) async => _product;

  @override
  Future<Product?> getFullProductWithFallback(int productId) async => _product;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockWorkbench4B extends ChangeNotifier implements WorkbenchProvider {
  final ValidationResult _validation;

  _MockWorkbench4B(this._validation);

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
  Future<void> checkTrafficLight(int quotationId) async {}

  @override
  ValidationResult? getValidationFor(int quotationId) => _validation;

  @override
  Future<void> loadDashboard({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSmartQuotation4B extends ChangeNotifier
    implements SmartQuotationProvider {
  final SmartQuotationModel _quotation;

  _MockSmartQuotation4B(this._quotation);

  @override
  bool get hasManualDraft => false;

  @override
  Future<SmartQuotationModel?> getQuotationById(int id) async => _quotation;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockQuickSale4B extends ChangeNotifier implements QuickSaleProvider {
  bool _hideProfits = false;

  @override
  bool get hideProfits => _hideProfits;

  @override
  List<MatchedProduct> get cartItems => const <MatchedProduct>[];

  @override
  Future<void> toggleHideProfits() async {
    _hideProfits = !_hideProfits;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSaleProvider4B extends ChangeNotifier implements SaleProvider {
  final Map<String, dynamic> _saleDetail;

  _MockSaleProvider4B(this._saleDetail);

  @override
  bool get isLoading => false;

  @override
  List<SaleModel> get salesHistory => const <SaleModel>[];

  @override
  Future<Map<String, dynamic>?> getSaleDetail(int saleId) async => _saleDetail;

  @override
  Future<void> silentRefresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTracking4B extends ChangeNotifier implements TrackingProvider {
  @override
  int get pendingRewardsCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockPromotion4B extends ChangeNotifier implements PromotionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockCatalog4B extends ChangeNotifier implements CatalogProvider {
  @override
  void syncPresentation(
    int presentationId, {
    int? newStock,
    double? newPrice,
    double? newOfferPrice,
    String? newDiscountType,
    double? newDiscountValue,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockQuickSearch4B extends ChangeNotifier implements QuickSearchProvider {
  @override
  void syncPresentation(
    int presentationId, {
    int? newStock,
    double? newPrice,
    double? newOfferPrice,
    String? newDiscountType,
    double? newDiscountValue,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockManualQuote4B extends ChangeNotifier implements ManualQuoteProvider {
  @override
  void syncPresentation(
    int presentationId, {
    int? newStock,
    double? newPrice,
    double? newOfferPrice,
    String? newDiscountType,
    double? newDiscountValue,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Product _buildSampleProduct({int stock = 3, String modoStock = 'COMPARTIDO'}) {
  final createdAt = DateTime.now()
      .subtract(const Duration(days: 20))
      .toIso8601String();
  return Product(
    id: 77,
    nombre: 'Cuaderno A4 Especial 4B',
    descripcion: 'Cuaderno cuadriculado de 100 hojas papel bond 75g.',
    categoriaId: 1,
    marcaId: 2,
    imagenUrl: '',
    codigoBarras: '7750011223344',
    modoStock: modoStock,
    stockCompartido: 24,
    costoBase: 2.50,
    fechaCreacion: createdAt,
    presentaciones: [
      ProductPresentation(
        id: 771,
        nombreEspecifico: 'Unidad Rayada',
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        precioVentaFinal: 5.00,
        costoUnitarioCalculado: 2.50,
        factorGananciaVenta: 2.0,
        stockActual: stock,
        usaStockCompartido: modoStock == 'COMPARTIDO',
        esDefault: true,
        estado: 'publico',
      ),
      ProductPresentation(
        id: 772,
        nombreEspecifico: 'Docena Escolar',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        precioVentaFinal: 54.00,
        costoUnitarioCalculado: 30.00,
        factorGananciaVenta: 1.8,
        stockActual: 24,
        usaStockCompartido: modoStock == 'COMPARTIDO',
        esDefault: false,
        estado: 'publico',
      ),
    ],
  );
}

SmartQuotationModel _buildSampleQuotation({int id = 101}) {
  return SmartQuotationModel(
    id: id,
    sequentialNumber: id,
    negocioId: 1,
    creadoPorUsuarioId: 1,
    clientId: 10,
    clientName: 'Lista Escolar Primaria 4B',
    institutionName: 'I.E. Nuestra Señora de Guadalupe',
    gradeLevel: '4to Grado Primaria',
    notas: 'Entregar forrados con etiqueta azul.',
    totalAmount: 112.0,
    totalSavings: 18.0,
    status: 'PENDING',
    type: 'manual',
    createdAt: '2026-11-24T12:00:00.000Z',
    itemCount: 2,
    items: [
      QuotationItem(
        id: 1,
        productId: 77,
        presentationId: 771,
        productName: 'Cuaderno A4 Especial 4B',
        brandName: 'Faber-Castell',
        specificName: 'Cuadriculado 100 hojas',
        salesUnit: 'Unidad',
        quantity: 4,
        unitPriceApplied: 5.0,
        originalUnitPrice: 6.0,
        isAvailable: true,
      ),
      QuotationItem(
        id: 2,
        productId: 78,
        presentationId: 781,
        productName: 'Caja de Colores x24',
        brandName: 'Artesco',
        specificName: 'Larga duración',
        salesUnit: 'Caja',
        quantity: 2,
        unitPriceApplied: 46.0,
        originalUnitPrice: 53.0,
        isAvailable: false,
      ),
    ],
  );
}

Map<String, dynamic> _buildSampleSaleHistoryDetail({int saleId = 42}) {
  return {
    'id': saleId,
    'numero_secuencial': saleId,
    'cotizacion_id': 101,
    'cliente_id': 10,
    'cliente_nombre': 'Ana María Compradora',
    'origen_venta': 'manual',
    'estado_pago': 'pagado',
    'estado_entrega': 'entregado',
    'metodo_pago': 'efectivo',
    'monto_total': 112.0,
    'monto_pagado': 112.0,
    'fecha_venta': '2026-11-24T14:30:00.000Z',
    'is_archived': 0,
    'cotizacion': {
      'client_name': 'Lista Escolar Primaria 4B',
      'institution_name': 'I.E. Nuestra Señora de Guadalupe',
      'grade_level': '4to Grado Primaria',
      'notas': 'Entregar con bolsa reforzada',
    },
    'items': [
      {
        'product_name': 'Cuaderno A4 Especial 4B',
        'brand_name': 'Faber-Castell',
        'specific_name': 'Cuadriculado 100 hojas',
        'sales_unit': 'Unidad',
        'quantity': 4,
        'unit_price_applied': 5.0,
        'original_unit_price': 6.0,
      },
      {
        'product_name': 'Caja de Colores x24',
        'brand_name': 'Artesco',
        'specific_name': 'Larga duración',
        'sales_unit': 'Caja',
        'quantity': 2,
        'unit_price_applied': 46.0,
        'original_unit_price': 53.0,
      },
    ],
  };
}

Widget _wrapWithProviders({
  required Widget child,
  required Size viewport,
  Product? product,
  SmartQuotationModel? quotation,
  ValidationResult? validation,
  Map<String, dynamic>? saleDetail,
}) {
  final sampleProduct = product ?? _buildSampleProduct();
  final sampleQuotation = quotation ?? _buildSampleQuotation();
  final sampleValidation = validation ??
      ValidationResult(
        hasIssues: true,
        canSell: false,
        stockWarnings: [
          StockWarning(
            itemId: 2,
            productName: 'Caja de Colores x24',
            requested: 2,
            available: 1,
          ),
        ],
        priceChanges: const [],
      );
  final sampleSale = saleDetail ?? _buildSampleSaleHistoryDetail();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: _MockAuth4B()),
      ChangeNotifierProvider<ThemeProvider>.value(value: _MockTheme4B()),
      ChangeNotifierProvider<LicenseProvider>.value(value: _MockLicense4B()),
      ChangeNotifierProvider<InventoryProvider>.value(
        value: _MockInventory4B(sampleProduct),
      ),
      ChangeNotifierProvider<WorkbenchProvider>.value(
        value: _MockWorkbench4B(sampleValidation),
      ),
      ChangeNotifierProvider<SmartQuotationProvider>.value(
        value: _MockSmartQuotation4B(sampleQuotation),
      ),
      ChangeNotifierProvider<QuickSaleProvider>.value(
        value: _MockQuickSale4B(),
      ),
      ChangeNotifierProvider<SaleProvider>.value(
        value: _MockSaleProvider4B(sampleSale),
      ),
      ChangeNotifierProvider<TrackingProvider>.value(
        value: _MockTracking4B(),
      ),
      ChangeNotifierProvider<PromotionProvider>.value(
        value: _MockPromotion4B(),
      ),
      ChangeNotifierProvider<CatalogProvider>.value(value: _MockCatalog4B()),
      ChangeNotifierProvider<QuickSearchProvider>.value(
        value: _MockQuickSearch4B(),
      ),
      ChangeNotifierProvider<ManualQuoteProvider>.value(
        value: _MockManualQuote4B(),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: viewport,
        textScaler: const TextScaler.linear(1.3),
      ),
      child: MaterialApp(home: child),
    ),
  );
}

MockClient _buildOfflineMockRssClient() {
  return MockClient((request) async {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>SUNAT actualiza cronograma para mypes librerías - El Peruano</title>
      <link>https://www.gob.pe/sunat/cronograma-mypes-test</link>
      <pubDate>Tue, 24 Nov 2026 10:00:00 GMT</pubDate>
      <source url="https://www.gob.pe">El Peruano</source>
    </item>
    <item>
      <title>Tránsito fluido en Panamericana Norte hacia Piura - MTC</title>
      <link>https://www.gob.pe/mtc/rutas-norte-test</link>
      <pubDate>Tue, 24 Nov 2026 09:00:00 GMT</pubDate>
      <source url="https://www.gob.pe">MTC</source>
    </item>
  </channel>
</rss>''';
    return http.Response(xml, 200);
  });
}

Future<void> _pumpBounded(WidgetTester tester, {int frames = 6}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 30,
}) async {
  for (int i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 80));
      return;
    }
  }
}

Future<void> _openManualTourFromTooltip(WidgetTester tester) async {
  final infoBtn = find.byTooltip('Información');
  expect(infoBtn, findsOneWidget);
  await tester.tap(infoBtn);
  await _pumpBounded(tester, frames: 6);
  final startBtn = find.text('Iniciar guía interactiva paso a paso');
  expect(startBtn, findsOneWidget);
  await tester.tap(startBtn);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final emojiRegex = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
    CommercialRadarService.clearMemoryCache();
    CommercialRadarService.customHttpClient = _buildOfflineMockRssClient();
    CommercialRadarService.geminiCuratorMock = null;
    LinkHealthVerifier.clearCache();
  });

  tearDown(() async {
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
    CommercialRadarService.clearMemoryCache();
    CommercialRadarService.customHttpClient = null;
    CommercialRadarService.geminiCuratorMock = null;
    LinkHealthVerifier.clearCache();
  });

  group('Plan Maestro 21 - Sub-turno 4B: Modelos y Contratos de Guías', () {
    test(
      '1. Contratos completos y cero emojis crudos en los 5 tours de Sub-turno 4B',
      () {
        final radarConfig = CommercialRadarTour.buildConfig();
        expect(radarConfig.screenId, equals('commercial_radar_screen'));
        expect(radarConfig.steps.length, equals(5));
        expect(
          radarConfig.steps
              .map((s) => '${s.title} ${s.description}')
              .join(' '),
          allOf(
            contains('Selector Geográfico'),
            contains('Semáforo'),
            contains('RSS + IA'),
            contains('gob.pe'),
            contains('Guardadas'),
            contains('SUNAT'),
          ),
        );

        final quoteConfig = QuotationDetailTour.buildConfig();
        expect(quoteConfig.screenId, equals('quotation_detail_screen'));
        expect(quoteConfig.steps.length, equals(5));
        expect(
          quoteConfig.steps
              .map((s) => '${s.title} ${s.description}')
              .join(' '),
          allOf(
            contains('Título Editable'),
            contains('Verificación de Stock'),
            contains('Privacidad'),
            contains('Resumen de Totales'),
            contains('PDF'),
            contains('WhatsApp'),
          ),
        );

        final saleHistConfig = SaleHistoryDetailTour.buildConfig();
        expect(saleHistConfig.screenId, equals('sale_history_detail_screen'));
        expect(saleHistConfig.steps.length, equals(4));
        expect(
          saleHistConfig.steps
              .map((s) => '${s.title} ${s.description}')
              .join(' '),
          allOf(
            contains('Resumen del Comprobante'),
            contains('Márgenes'),
            contains('Térmica'),
            contains('PDF'),
            contains('Anulación Atómica'),
          ),
        );

        final prodDetailConfig = ProductDetailTour.buildConfig();
        expect(prodDetailConfig.screenId, equals('product_detail_screen'));
        expect(prodDetailConfig.steps.length, equals(5));
        expect(
          prodDetailConfig.steps
              .map((s) => '${s.title} ${s.description}')
              .join(' '),
          allOf(
            contains('Variantes'),
            contains('Dashboard Financiero'),
            contains('Alertas de Stock y Rotación'),
            contains('Acciones Rápidas'),
            contains('AuditTrail'),
          ),
        );

        final prodEditConfig = ProductEditTour.buildConfig(
          onExpandPresentationsForTour: () async {},
          onRestorePresentationsAfterTour: () async {},
        );
        expect(prodEditConfig.screenId, equals('product_edit_screen'));
        expect(prodEditConfig.steps.length, equals(5));
        expect(prodEditConfig.onCancel, isNotNull);
        expect(prodEditConfig.onDismiss, isNotNull);
        expect(prodEditConfig.steps[3].onBeforeStep, isNotNull);
        expect(prodEditConfig.steps[3].onAfterStep, isNotNull);
        expect(
          prodEditConfig.steps
              .map((s) => '${s.title} ${s.description}')
              .join(' '),
          allOf(
            contains('Código de Barras'),
            contains('Compartido'),
            contains('Costo Base'),
            contains('Deshacer'),
            contains('Guardado'),
          ),
        );

        for (final config in [
          radarConfig,
          quoteConfig,
          saleHistConfig,
          prodDetailConfig,
          prodEditConfig,
        ]) {
          final seenIds = <String>{};
          expect(emojiRegex.hasMatch(config.screenTitle), isFalse);
          expect(emojiRegex.hasMatch(config.welcomeSummary), isFalse);
          for (final step in config.steps) {
            expect(seenIds.add(step.id), isTrue);
            expect(step.title.trim(), isNotEmpty);
            expect(step.description.trim(), isNotEmpty);
            expect(step.tip?.trim(), isNotEmpty);
            expect(emojiRegex.hasMatch(step.title), isFalse);
            expect(emojiRegex.hasMatch(step.description), isFalse);
            if (step.tip != null) {
              expect(emojiRegex.hasMatch(step.tip!), isFalse);
            }
          }
        }
      },
    );
  });

  group('Plan Maestro 21 - Sub-turno 4B: Recorridos Interactivos Reales', () {
    testWidgets(
      '2. CommercialRadarScreen: botón (i) recorre 5/5 sin red real y cierra con ¡Listo!, X, Back y dispose',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <String>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => capturedErrors.add(details.toString());

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              child: const CommercialRadarScreen(
                initialRegion: 'Talara / Piura',
                autoTriggerTour: false,
              ),
            ),
          );

          await _pumpBounded(tester, frames: 10);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          expect(find.text('Selector Geográfico de 3 Niveles'), findsOneWidget);

          final expectedTitles = [
            'Semáforo Operativo Comercial',
            'Indicador Honesto de Origen',
            'Buscador, Categorías y Guardadas',
            'Tarjetas de Señales y Acciones Directas',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${i + 2} / 5'));
            expect(find.text('${i + 2} / 5'), findsOneWidget);
            expect(find.text(expectedTitles[i]), findsOneWidget);
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          // Cerrar con X
          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          // Cerrar con Back
          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          // Dispose durante tour activo
          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpBounded(tester, frames: 6);

          expect(tester.takeException(), isNull);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '3. QuotationDetailScreen: botón (i) recorre 5/5 (banner e ítems) y cierra limpiamente',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <String>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => capturedErrors.add(details.toString());

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              child: const QuotationDetailScreen(
                quotationId: 101,
                clientName: 'Lista Escolar Primaria 4B',
                autoTriggerTour: false,
              ),
            ),
          );

          await _pumpBounded(tester, frames: 10);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          expect(
            find.text('Título Editable y Estado de la Cotización'),
            findsOneWidget,
          );

          final expectedTitles = [
            'Verificación de Stock y Alertas',
            'Modo Privacidad (Ojo) y Edición',
            'Resumen de Totales, Paquetes y Descuentos',
            'Acciones de Salida (PDF, WhatsApp y Vender)',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${i + 2} / 5'));
            final visibleTexts = find
                .byType(Text)
                .evaluate()
                .map((e) => (e.widget as Text).data)
                .whereType<String>()
                .where(
                  (t) =>
                      t.contains('/ 5') ||
                      expectedTitles.contains(t) ||
                      t.contains('Selector'),
                )
                .toList();
            expect(
              find.text('${i + 2} / 5'),
              findsOneWidget,
              reason:
                  'No se encontró contador de paso ${i + 2} / 5; visibles: $visibleTexts',
            );
            expect(find.text(expectedTitles[i]), findsOneWidget);
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          // Cerrar con X y Back y dispose
          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 6);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 6);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpBounded(tester, frames: 6);

          expect(tester.takeException(), isNull);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '4. SaleHistoryDetailScreen: botón (i) recorre 4/4 pasos y cierra con ¡Listo!, X, Back y dispose',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <String>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => capturedErrors.add(details.toString());

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              child: const SaleHistoryDetailScreen(
                saleId: 42,
                autoTriggerTour: false,
              ),
            ),
          );

          await _pumpBounded(tester, frames: 10);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 4'));
          expect(find.text('Resumen del Comprobante y Origen'), findsOneWidget);

          final expectedTitles = [
            'Detalle de Ítems, Precios y Márgenes',
            'Emisión y Envío (Impresora Térmica, PDF y WhatsApp)',
            'Anulación Atómica y Seguridad Contable',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${i + 2} / 4'));
            expect(find.text(expectedTitles[i]), findsOneWidget);
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 4'));
          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 6);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 4'));
          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 6);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 4'));
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpBounded(tester, frames: 6);

          expect(tester.takeException(), isNull);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '5. ProductDetailScreen: botón (i) existente recorre 5/5 pasos incluyendo alerta, acciones rápidas y AuditTrail',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <String>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => capturedErrors.add(details.toString());

        final lowStockProduct = _buildSampleProduct(
          stock: 3,
          modoStock: 'INDEPENDIENTE',
        );

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              product: lowStockProduct,
              child: ProductDetailScreen(
                product: lowStockProduct,
                initialPresentationId: 771,
                autoTriggerTour: false,
              ),
            ),
          );

          await _pumpBounded(tester, frames: 10);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          expect(
            find.text('Selector de Variantes y Presentaciones'),
            findsOneWidget,
          );

          final expectedTitles = [
            'Dashboard Financiero del Producto',
            'Alertas de Stock y Rotación',
            'Acciones Rápidas (Stock, Precio y Oferta)',
            'Auditoría de Movimientos (AuditTrail) y Edición',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${i + 2} / 5'));
            final visibleTexts = find
                .byType(Text)
                .evaluate()
                .map((e) => (e.widget as Text).data)
                .whereType<String>()
                .where(
                  (t) =>
                      t.contains('/ 5') ||
                      expectedTitles.contains(t) ||
                      t.contains('Selector'),
                )
                .toList();
            expect(
              find.text('${i + 2} / 5'),
              findsOneWidget,
              reason:
                  'No se encontró contador de paso ${i + 2} / 5; visibles: $visibleTexts',
            );
            expect(find.text(expectedTitles[i]), findsOneWidget);
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 6);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 6);
          expect(InteractiveTourService.isTourActive, isFalse);

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpBounded(tester, frames: 6);

          expect(tester.takeException(), isNull);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );

    testWidgets(
      '6. ProductEditScreen: botón (i) recorre 5/5 pasos y restaura estado colapsado al completar, X, Back y dispose',
      (tester) async {
        const viewport = Size(360, 640);
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final capturedErrors = <String>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => capturedErrors.add(details.toString());

        final product = _buildSampleProduct(stock: 24, modoStock: 'COMPARTIDO');

        try {
          await tester.pumpWidget(
            _wrapWithProviders(
              viewport: viewport,
              product: product,
              child: ProductEditScreen(
                productToEdit: product,
                initialPresentationId: 771,
                autoTriggerTour: false,
              ),
            ),
          );

          await _pumpBounded(tester, frames: 12);

          // Colapsar todas las presentaciones primero para probar expansión/restauración del Paso 4
          final collapseAllBtn = find.text('COLAPSAR');
          if (collapseAllBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(collapseAllBtn.first);
            await tester.tap(collapseAllBtn.first);
            await _pumpBounded(tester, frames: 6);
          }

          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          expect(
            find.text('Datos Generales y Código de Barras'),
            findsOneWidget,
          );

          final expectedTitles = [
            'Estrategia de Stock (Compartido vs. Propio)',
            'Costo Base y Asesor de Variantes',
            'Presentaciones, Extracción y Deshacer (Undo)',
            'Barra de Guardado y Protección de Cambios',
          ];

          for (int i = 0; i < expectedTitles.length; i++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${i + 2} / 5'));
            final visibleTexts = find
                .byType(Text)
                .evaluate()
                .map((e) => (e.widget as Text).data)
                .whereType<String>()
                .where(
                  (t) =>
                      t.contains('/ 5') ||
                      expectedTitles.contains(t) ||
                      t.contains('Selector'),
                )
                .toList();
            expect(
              find.text('${i + 2} / 5'),
              findsOneWidget,
              reason:
                  'No se encontró contador de paso ${i + 2} / 5; visibles: $visibleTexts',
            );
            expect(find.text(expectedTitles[i]), findsOneWidget);
          }

          await tester.tap(find.text('¡Listo!'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          // Cerrar con X en paso 4
          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          for (int s = 0; s < 3; s++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${s + 2} / 5'));
          }
          await tester.tap(find.byTooltip('Cerrar guía'));
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          // Cerrar con Back en paso 4
          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          for (int s = 0; s < 3; s++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${s + 2} / 5'));
          }
          await tester.binding.handlePopRoute();
          await _pumpBounded(tester, frames: 8);
          expect(InteractiveTourService.isTourActive, isFalse);

          // Dispose en paso 4 sin setState after dispose
          await _openManualTourFromTooltip(tester);
          await _pumpUntilFound(tester, find.text('1 / 5'));
          for (int s = 0; s < 3; s++) {
            await tester.tap(find.text('Siguiente'));
            await _pumpUntilFound(tester, find.text('${s + 2} / 5'));
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpBounded(tester, frames: 8);

          expect(tester.takeException(), isNull);
          expect(capturedErrors, isEmpty);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });

  group('Plan Maestro 21 - Sub-turno 4B: Responsividad 0px Overflow a 1.3x', () {
    const viewports = [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ];

    for (final viewport in viewports) {
      testWidgets(
        '7. Responsividad ${viewport.width.toInt()}x${viewport.height.toInt()}dp @ 1.3x: las 5 pantallas y AppBars con 0px Overflow',
        (tester) async {
          final capturedErrors = <String>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) => capturedErrors.add(details.toString());

          final product = _buildSampleProduct(stock: 3, modoStock: 'COMPARTIDO');

          try {
            await tester.binding.setSurfaceSize(viewport);
            addTearDown(() => tester.binding.setSurfaceSize(null));

            // 1) CommercialRadarScreen
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                child: const CommercialRadarScreen(
                  initialRegion: 'San Juan de Lurigancho, Lima',
                  autoTriggerTour: false,
                ),
              ),
            );
            await _pumpBounded(tester, frames: 10);
            final radarTitle = find.text('Radar Comercial IA');
            expect(radarTitle, findsOneWidget);
            expect(find.byTooltip('Información'), findsOneWidget);
            expect(tester.getRect(radarTitle).right, lessThanOrEqualTo(viewport.width));

            // 2) QuotationDetailScreen
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                child: const QuotationDetailScreen(
                  quotationId: 101,
                  clientName: 'Lista Escolar Primaria 4B',
                  autoTriggerTour: false,
                ),
              ),
            );
            await _pumpBounded(tester, frames: 10);
            expect(find.byTooltip('Información'), findsOneWidget);
            expect(find.text('VENDER'), findsNothing);
            expect(find.textContaining('CORREGIR'), findsOneWidget);

            // 3) SaleHistoryDetailScreen
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                child: const SaleHistoryDetailScreen(
                  saleId: 42,
                  autoTriggerTour: false,
                ),
              ),
            );
            await _pumpBounded(tester, frames: 10);
            final receiptTitle = find.text('Recibo #42');
            expect(receiptTitle, findsOneWidget);
            expect(find.byTooltip('Información'), findsOneWidget);
            expect(tester.getRect(receiptTitle).right, lessThanOrEqualTo(viewport.width));

            // 4) ProductDetailScreen
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                product: product,
                child: ProductDetailScreen(
                  product: product,
                  initialPresentationId: 771,
                  autoTriggerTour: false,
                ),
              ),
            );
            await _pumpBounded(tester, frames: 10);
            expect(find.text('Cuaderno A4 Especial 4B'), findsOneWidget);
            expect(find.byTooltip('Información'), findsOneWidget);

            // 5) ProductEditScreen
            await tester.pumpWidget(
              _wrapWithProviders(
                viewport: viewport,
                product: product,
                child: ProductEditScreen(
                  productToEdit: product,
                  initialPresentationId: 771,
                  autoTriggerTour: false,
                ),
              ),
            );
            await _pumpBounded(tester, frames: 12);
            final editTitle = find.text('Editar Producto');
            expect(editTitle, findsOneWidget);
            expect(find.byTooltip('Información'), findsOneWidget);
            expect(tester.getRect(editTitle).right, lessThanOrEqualTo(viewport.width));

            await tester.pumpWidget(const SizedBox.shrink());
            await _pumpBounded(tester, frames: 6);

            expect(tester.takeException(), isNull);
            expect(
              capturedErrors,
              isEmpty,
              reason:
                  'Se detectaron overflows o errores visuales en ${viewport.width}x${viewport.height}dp @ 1.3x',
            );
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );
    }
  });
}
