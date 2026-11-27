import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart';

class _MockAuth9D3 extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería MochilaLista 9D3',
    ruc: '20601234567',
    address: 'Av. Escolar 420, Lima',
    paymentInfo: 'Yape / Plin: 987654321',
    moneda: 'S/ (Soles)',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Julio Titular',
    phone: '987654321',
    isActive: true,
    business: _business,
  );

  @override
  UserModel? get user => _user;

  @override
  BusinessModel? get currentBusiness => _business;

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  bool get hasActiveContext => true;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isOwner => true;

  @override
  bool get isWorker => false;

  @override
  bool get isCommunityClient => false;

  @override
  bool get canManageClients => true;

  @override
  String get userName => 'Julio Titular';

  @override
  String get businessName => 'Librería MochilaLista 9D3';

  @override
  String get activeBusinessName => 'Librería MochilaLista 9D3';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTheme9D3 extends ChangeNotifier implements ThemeProvider {
  @override
  bool get isDarkMode => false;

  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicense9D3 extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isActive => true;

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSmartQuotation9D3 extends ChangeNotifier
    implements SmartQuotationProvider {
  final SmartQuotationModel? _quotation;
  _MockSmartQuotation9D3([this._quotation]);

  @override
  Future<SmartQuotationModel?> getQuotationById(int id) async => _quotation;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSaleProvider9D3 extends ChangeNotifier implements SaleProvider {
  final Map<String, dynamic> _saleDetail;
  _MockSaleProvider9D3(this._saleDetail);

  @override
  Future<Map<String, dynamic>?> getSaleDetail(int saleId) async => _saleDetail;

  @override
  Future<Map<String, dynamic>?> getSaleDetailSilently(int saleId) async =>
      _saleDetail;

  @override
  Future<ClientModel?> getClientById(int clientId) async => null;

  @override
  String get errorMessage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory9D3 extends ChangeNotifier implements InventoryProvider {
  final List<InventoryWrapper> _items;
  _MockInventory9D3(this._items);

  @override
  List<InventoryWrapper> get items => _items;

  @override
  bool get isLoading => false;

  @override
  bool get showStockAlertColors => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockPromotion9D3 extends ChangeNotifier implements PromotionProvider {
  final List<BundleModel> _bundles;
  final Map<int, List<BundleItemModel>> _itemsByBundle;

  _MockPromotion9D3(this._bundles, this._itemsByBundle);

  @override
  List<BundleModel> get bundles => _bundles;

  @override
  List<BundleItemModel> getItemsForBundle(int bundleId) =>
      _itemsByBundle[bundleId] ?? const <BundleItemModel>[];

  @override
  int calculateBundleMaxStock(int bundleId) => 8;

  @override
  Future<void> loadPromotions(int negocioId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockQuickSearch9D3 extends ChangeNotifier
    implements QuickSearchProvider {
  @override
  List<InventoryWrapper> get searchResults => const <InventoryWrapper>[];

  @override
  bool get isSearching => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  List<Category> get categories => const <Category>[];

  @override
  int? get selectedCategoryId => null;

  @override
  bool get hasOrphanCategories => false;

  @override
  void updateContext(int? negocioId) {}

  @override
  void clearSearch() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

InventoryWrapper _buildSampleWrapper({
  int prodId = 10,
  int presId = 101,
  String name = 'Cuaderno Alpha A4 Cuadriculado Triple Renglón',
  double price = 14.50,
  double cost = 9.20,
}) {
  final pres = ProductPresentation(
    id: presId,
    nombreEspecifico: 'Tapa Dura 100 Hojas',
    unidadVenta: 'Unidad',
    unidadesPorVenta: 1,
    costoUnitarioCalculado: cost,
    factorGananciaVenta: price / cost,
    precioVentaFinal: price,
    stockActual: 40,
  );
  final prod = Product(
    id: prodId,
    nombre: name,
    marcaNombre: 'Alpha',
    categoriaId: 1,
    presentaciones: [pres],
    costoBase: cost,
  );
  return InventoryWrapper(product: prod, presentation: pres);
}

SmartQuotationModel _buildSampleQuotation() {
  return SmartQuotationModel(
    id: 42,
    sequentialNumber: 42,
    negocioId: 1,
    creadoPorUsuarioId: 1,
    clientName: 'María Fernanda Quispe',
    institutionName: 'Colegio San Martín',
    gradeLevel: '3ro de Primaria',
    totalAmount: 145.00,
    totalSavings: 15.00,
    status: 'READY',
    type: 'manual',
    createdAt: '2026-11-26T10:00:00.000',
    itemCount: 2,
    explicitContextMode: QuotationContextMode.school,
    items: [
      QuotationItem(
        id: 1,
        productId: 10,
        presentationId: 101,
        productName: 'Cuaderno A4 Rayado 100h',
        brandName: 'Standford',
        salesUnit: 'Unidad',
        quantity: 6,
        unitPriceApplied: 12.00,
        originalUnitPrice: 14.00,
      ),
      QuotationItem(
        id: 2,
        productId: 11,
        presentationId: 102,
        productName: 'Caja de Colores x 24',
        brandName: 'Faber',
        salesUnit: 'Caja',
        quantity: 2,
        unitPriceApplied: 36.50,
        originalUnitPrice: 38.00,
      ),
    ],
  );
}

Map<String, dynamic> _buildSampleSaleDetail() {
  final pastIso = DateTime.now()
      .subtract(const Duration(days: 4))
      .toIso8601String();
  final futureIso = DateTime.now()
      .add(const Duration(days: 15))
      .toIso8601String();
  return <String, dynamic>{
    'id': 77,
    'numero_secuencial': 77,
    'cotizacion_id': 42,
    'origen_venta': 'cotizacion',
    'metodo_pago': 'CREDITO',
    'estado_entrega': 'en_camino',
    'foto_entrega': 'C:/no_existe/evidencia_entrega_test.jpg',
    'monto_total': 240.0,
    'monto_pagado': 80.0,
    'porcentaje_interes': 10.0,
    'mora_total': 12.5,
    'cliente_id': null,
    'cliente_nombre': 'Carlos Eduardo Mendoza Paredes',
    'cliente_telefono': '+51987654321',
    'fecha_venta': '2026-11-20',
    'cuotas': [
      {
        'id': 1,
        'numero_cuota': 1,
        'monto': 132.5,
        'monto_original': 120.0,
        'monto_pagado': 0.0,
        'mora_monto': 12.5,
        'mora_porcentaje': 10.0,
        'mora_automatica': 1,
        'fecha_vencimiento': pastIso,
        'estado': 'pendiente',
      },
      {
        'id': 2,
        'numero_cuota': 2,
        'monto': 120.0,
        'monto_original': 120.0,
        'monto_pagado': 80.0,
        'mora_monto': 0.0,
        'mora_porcentaje': 0.0,
        'mora_automatica': 0,
        'fecha_vencimiento': futureIso,
        'estado': 'parcial',
      },
    ],
    'items': [
      {
        'brand_name': 'Faber-Castell',
        'product_name': 'Set Plumones Acuarelables Ultra Resistentes',
        'specific_name': 'Estuche Rígido x 36',
        'sales_unit': 'Estuche',
        'unit_price_applied': 45.0,
        'original_unit_price': 52.0,
        'quantity': 4,
        'image_url': 'C:/no_existe/plumon.jpg',
        'original_text': '4 estuches plumones x36',
      },
    ],
  };
}

Widget _wrap9D3App({
  required Size viewport,
  required Widget child,
  SmartQuotationModel? quotation,
  Map<String, dynamic>? saleDetail,
  List<InventoryWrapper> inventoryItems = const [],
  List<BundleModel> bundles = const [],
  Map<int, List<BundleItemModel>> bundleItems = const {},
  QuickSaleProvider? quickSaleProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: _MockAuth9D3()),
      ChangeNotifierProvider<ThemeProvider>.value(value: _MockTheme9D3()),
      ChangeNotifierProvider<LicenseProvider>.value(value: _MockLicense9D3()),
      ChangeNotifierProvider<SmartQuotationProvider>.value(
        value: _MockSmartQuotation9D3(quotation),
      ),
      ChangeNotifierProvider<SaleProvider>.value(
        value: _MockSaleProvider9D3(saleDetail ?? _buildSampleSaleDetail()),
      ),
      ChangeNotifierProvider<InventoryProvider>.value(
        value: _MockInventory9D3(inventoryItems),
      ),
      ChangeNotifierProvider<PromotionProvider>.value(
        value: _MockPromotion9D3(bundles, bundleItems),
      ),
      ChangeNotifierProvider<QuickSearchProvider>.value(
        value: _MockQuickSearch9D3(),
      ),
      ChangeNotifierProvider<QuickSaleProvider>.value(
        value: quickSaleProvider ?? QuickSaleProvider(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          viewPadding: const EdgeInsets.only(bottom: 24),
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
  });

  group('Plan Maestro 25 - Fase 9D-3: Censo Modular, DRY y D-MOV-06', () {
    const coordinators = [
      'lib/features/smart_quotation/screens/whatsapp_preview_screen.dart',
      'lib/features/promotions/screens/bundle_builder_screen.dart',
      'lib/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart',
      'lib/features/smart_quotation/screens/quick_sale_screen.dart',
    ];

    const subModules = [
      'lib/features/smart_quotation/screens/whatsapp_preview/whatsapp_state_and_history_mixin.dart',
      'lib/features/smart_quotation/screens/whatsapp_preview/whatsapp_message_builder_mixin.dart',
      'lib/features/smart_quotation/screens/whatsapp_preview/whatsapp_message_financial_mixin.dart',
      'lib/features/smart_quotation/screens/whatsapp_preview/whatsapp_actions_and_gps_mixin.dart',
      'lib/features/smart_quotation/screens/whatsapp_preview/whatsapp_pdf_and_send_mixin.dart',
      'lib/features/promotions/screens/bundle_builder/bundle_builder_logic_mixin.dart',
      'lib/features/promotions/screens/bundle_builder/bundle_builder_sections_mixin.dart',
      'lib/features/promotions/screens/bundle_builder/bundle_builder_pricing_mixin.dart',
      'lib/features/promotions/screens/bundle_builder/bundle_builder_product_picker_mixin.dart',
      'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_balance_card.dart',
      'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_logistics_dialogs_mixin.dart',
      'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_installment_actions_mixin.dart',
      'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_installments_mixin.dart',
      'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_items_section.dart',
      'lib/features/smart_quotation/screens/quick_sale/quick_sale_dialogs_mixin.dart',
      'lib/features/smart_quotation/screens/quick_sale/quick_sale_search_sliver_mixin.dart',
      'lib/features/smart_quotation/screens/quick_sale/quick_sale_offers_and_recents_sliver_mixin.dart',
      'lib/features/smart_quotation/screens/quick_sale/quick_sale_cart_sliver_mixin.dart',
      'lib/features/smart_quotation/screens/quick_sale/quick_sale_checkout_footer.dart',
    ];

    test(
      'Todos los 23 archivos cumplen límites (<600 L coordinadores, <650 L submódulos)',
      () {
        for (final path in coordinators) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: 'Falta coordinador $path');
          final lines = file.readAsLinesSync().length;
          expect(
            lines,
            lessThan(600),
            reason: '$path tiene $lines L (>= 600 L)',
          );
          expect(lines, greaterThan(50), reason: '$path vacío o truncado');
        }

        for (final path in subModules) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: 'Falta submódulo $path');
          final lines = file.readAsLinesSync().length;
          expect(
            lines,
            lessThan(650),
            reason: '$path tiene $lines L (>= 650 L)',
          );
          expect(lines, greaterThan(50), reason: '$path vacío o truncado');
        }
      },
    );

    test(
      'D-MOV-06 cerrado en SaleFinancialDetail: 0 existsSync y 0 Image.file en display, usa UniversalImage',
      () {
        const finPaths = [
          'lib/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart',
          'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_balance_card.dart',
          'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_logistics_dialogs_mixin.dart',
          'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_installment_actions_mixin.dart',
          'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_installments_mixin.dart',
          'lib/features/smart_quotation/screens/crm/sale_financial_detail/sale_financial_items_section.dart',
        ];
        int existsSyncMatches = 0;
        int imageFileMatches = 0;
        bool hasUniversalImage = false;
        for (final path in finPaths) {
          final src = File(path).readAsStringSync();
          existsSyncMatches += RegExp(
            r'\bexistsSync\s*\(',
          ).allMatches(src).length;
          imageFileMatches += RegExp(
            r'Image\.file\s*\(',
          ).allMatches(src).length;
          if (src.contains('UniversalImage(')) {
            hasUniversalImage = true;
          }
        }
        expect(existsSyncMatches, equals(0));
        expect(imageFileMatches, equals(0));
        expect(hasUniversalImage, isTrue);
      },
    );

    test(
      'Adopción DRY y retiro de emojis crudos UI en BundleBuilder, QuickSale y WhatsAppPreview',
      () {
        final waSendSrc = File(
          'lib/features/smart_quotation/screens/whatsapp_preview/whatsapp_pdf_and_send_mixin.dart',
        ).readAsStringSync();
        expect(waSendSrc, contains('WhatsAppUriBuilder.buildSendUri'));
        expect(waSendSrc.contains('wa.me/51'), isFalse);

        final bundleFiles = [
          'lib/features/promotions/screens/bundle_builder_screen.dart',
          'lib/features/promotions/screens/bundle_builder/bundle_builder_logic_mixin.dart',
          'lib/features/promotions/screens/bundle_builder/bundle_builder_sections_mixin.dart',
          'lib/features/promotions/screens/bundle_builder/bundle_builder_pricing_mixin.dart',
          'lib/features/promotions/screens/bundle_builder/bundle_builder_product_picker_mixin.dart',
        ];
        final bundleCombined = bundleFiles
            .map((p) => File(p).readAsStringSync())
            .join('\n');
        expect(bundleCombined.contains('NumberFormat'), isFalse);
        expect(bundleCombined.contains('DateFormat('), isFalse);
        expect(bundleCombined, contains('AppCurrency.format('));
        expect(bundleCombined, contains('AppDateFormatter.'));
        expect(bundleCombined.contains('🔴'), isFalse);
        expect(bundleCombined.contains('🟡'), isFalse);
        expect(bundleCombined.contains('🟢'), isFalse);
        expect(bundleCombined.contains('⚪'), isFalse);

        final qsOffersSrc = File(
          'lib/features/smart_quotation/screens/quick_sale/quick_sale_offers_and_recents_sliver_mixin.dart',
        ).readAsStringSync();
        expect(qsOffersSrc.contains('🔥'), isFalse);
        expect(qsOffersSrc, contains('Icons.local_fire_department_rounded'));
        expect(qsOffersSrc, contains('AppCurrency.format('));
      },
    );
  });

  group('Plan Maestro 25 - Fase 9D-3: Responsividad 0px Overflow @ 1.3x', () {
    const viewports = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final vp in viewports) {
      testWidgets(
        'WhatsAppPreviewScreen renderiza 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details.exceptionAsString());
          };

          try {
            await tester.pumpWidget(
              _wrap9D3App(
                viewport: vp,
                quotation: _buildSampleQuotation(),
                child: const WhatsAppPreviewScreen(
                  quotationId: 42,
                  contextMode: QuotationContextMode.school,
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            expect(errors, isEmpty, reason: 'Errors en ${vp.width}: $errors');
            expect(find.text('Editor WhatsApp'), findsOneWidget);
            expect(find.text('VISUALIZAR MENSAJE FINAL'), findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 100));
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'BundleBuilderScreen con ítem inicial renderiza 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <FlutterErrorDetails>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = errors.add;

          final itemWrap = _buildSampleWrapper();
          try {
            await tester.pumpWidget(
              _wrap9D3App(
                viewport: vp,
                inventoryItems: [itemWrap],
                child: BundleBuilderScreen(
                  initialItem: itemWrap,
                  autoTriggerTour: false,
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            expect(find.text('Nuevo Paquete'), findsOneWidget);
            expect(find.text('GUARDAR PAQUETE'), findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 100));

            expect(errors, isEmpty, reason: 'Errors en ${vp.width}: $errors');
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'SaleFinancialDetailScreen completo (cuotas, mora, ítems y UniversalImage) 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <FlutterErrorDetails>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = errors.add;

          try {
            await tester.pumpWidget(
              _wrap9D3App(
                viewport: vp,
                child: const SaleFinancialDetailScreen(
                  saleId: 77,
                  autoTriggerTour: false,
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            expect(find.text('Detalle de Venta #77'), findsOneWidget);
            expect(find.text('Ver Foto de Entrega'), findsOneWidget);

            // Expandir Cuota 1 y verificar botones Fecha/Mora/Recordar/Cobrar
            await tester.ensureVisible(find.text('Cuota 1'));
            await tester.tap(find.text('Cuota 1'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.text('Monto Base:'), findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 100));

            expect(errors, isEmpty, reason: 'Errors en ${vp.width}: $errors');
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'QuickSaleScreen con carrito y ofertas renderiza 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details.exceptionAsString());
          };

          final itemWrap = _buildSampleWrapper();
          final quickSaleProv = QuickSaleProvider();
          quickSaleProv.updateContext(1, 1);
          quickSaleProv.addToCart(itemWrap);

          final bundle = BundleModel(
            id: 501,
            negocioId: 1,
            nombrePaquete: 'Pack Escolar Pro 2026',
            descripcion: 'Incluye cuaderno y accesorios',
            precioVentaTotal: 25.00,
            activo: true,
            tipoPromocion: 'escolar',
          );
          final bundleItems = {
            501: [
              BundleItemModel(
                id: 1,
                paqueteId: 501,
                productoId: 10,
                presentacionId: 101,
                cantidadRequerida: 2,
                precioOriginalUnitario: 14.50,
              ),
            ],
          };

          try {
            await tester.pumpWidget(
              _wrap9D3App(
                viewport: vp,
                inventoryItems: [itemWrap],
                bundles: [bundle],
                bundleItems: bundleItems,
                quickSaleProvider: quickSaleProv,
                child: const QuickSaleScreen(),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            expect(errors, isEmpty, reason: 'Errors en ${vp.width}: $errors');
            expect(find.text('Caja Rápida'), findsOneWidget);
            expect(find.text('COBRAR'), findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 100));
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );
    }

    testWidgets(
      'SaleFinancialDetailScreen abre diálogo Ver Foto de Entrega con UniversalImage en 320x568dp @ 1.3x sin excepción',
      (tester) async {
        const vp = Size(320, 568);
        await tester.binding.setSurfaceSize(vp);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = errors.add;

        try {
          await tester.pumpWidget(
            _wrap9D3App(
              viewport: vp,
              child: const SaleFinancialDetailScreen(
                saleId: 77,
                autoTriggerTour: false,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          await tester.tap(find.text('Ver Foto de Entrega'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.byType(UniversalImage), findsWidgets);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 100));

          expect(errors, isEmpty, reason: 'Errors diálogo foto: $errors');
        } finally {
          FlutterError.onError = prevOnError;
        }
      },
    );
  });
}
