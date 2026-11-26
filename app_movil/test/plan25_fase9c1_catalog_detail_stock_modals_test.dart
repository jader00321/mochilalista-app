import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/product_detail_modal.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/catalog/catalog_screen.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_extract_config_modal.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory _resolveAppMovilRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}${Platform.pathSeparator}pubspec.yaml').existsSync() &&
      Directory('${cwd.path}${Platform.pathSeparator}lib').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}${Platform.pathSeparator}app_movil');
  if (nested.existsSync() &&
      File(
        '${nested.path}${Platform.pathSeparator}pubspec.yaml',
      ).existsSync()) {
    return nested;
  }
  throw StateError('No se pudo localizar la raíz app_movil desde ${cwd.path}');
}

int _lineCount(Directory root, String relPath) {
  final sep = Platform.pathSeparator;
  final file = File('${root.path}$sep${relPath.replaceAll('/', sep)}');
  expect(file.existsSync(), isTrue, reason: 'Falta archivo $relPath');
  return file.readAsLinesSync().length;
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  bool get isCommunityClient => false;

  @override
  String get businessName => 'Librería Central';

  @override
  UserModel? get user => UserModel(
    id: 1,
    fullName: 'Comerciante Prueba',
    phone: '999888777',
    isActive: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier
    implements InventoryProvider {
  final List<InventoryWrapper> mockItems;

  _MockInventoryProvider(this.mockItems);

  @override
  List<InventoryWrapper> get items => mockItems;

  @override
  List<Brand> get brands => [Brand(id: 1, nombre: 'Stanford')];

  @override
  List<Category> get categories => [Category(id: 1, nombre: 'Cuadernos')];

  @override
  String getBrandName(int? id) => 'Stanford';

  @override
  String getCategoryName(int? id) => 'Cuadernos';

  @override
  Future<bool> updatePresentation(
    int presentationId, {
    String? nombreEspecifico,
    String? unidadVenta,
    int? unidadesPorVenta,
    double? costoUnitarioCalculado,
    double? factorGananciaVenta,
    double? precioVentaFinal,
    double? precioUmpProveedor,
    double? cantidadUmpComprada,
    double? totalPagoLote,
    int? unidadesPorLote,
    String? umpCompra,
    double? oferta,
    String? tipoDesc,
    double? valorDesc,
    int? stock,
    int? cupoMaximoVariante,
    bool clearCupo = false,
    String? estado,
    String? imagenUrl,
  }) async => true;

  @override
  bool get hasCreationDraft => false;

  @override
  bool get isLoading => false;

  @override
  Future<bool> updateVariantQuota(int presentationId, int? quota) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCatalogProvider extends ChangeNotifier implements CatalogProvider {
  final List<InventoryWrapper> _items;
  final List<CartItem> _cart;
  final List<CartItem> _list;

  _MockCatalogProvider(this._items)
    : _cart = [CartItem(item: _items.first, quantity: 2)],
      _list = [CartItem(item: _items.last, quantity: 1)];

  @override
  List<InventoryWrapper> get displayItems => _items;

  @override
  int get totalLoadedCount => _items.length;

  @override
  int get realTotalProductsCount => _items.length;

  @override
  int get realTotalPresentationsCount =>
      _items.fold(0, (s, w) => s + w.product.presentaciones.length);

  @override
  bool get hasOrphanCategories => false;

  @override
  bool get hasOrphanBrands => false;

  @override
  int get orphanCategoriesCount => 0;

  @override
  int get orphanBrandsCount => 0;

  @override
  String get errorMessage => '';

  @override
  bool get isLoading => false;

  @override
  int? get selectedCategoryId => null;

  @override
  String get searchQuery => '';

  @override
  Map<String, dynamic> get advancedFilters => const {};

  @override
  bool get hasActiveFilters => false;

  @override
  CatalogSortOption get sortOption => CatalogSortOption.nameAsc;

  @override
  bool get isSortAscending => true;

  @override
  int get cartCount => 2;

  @override
  double get cartTotal => 148.50;

  @override
  List<CartItem> get shoppingCart => _cart;

  @override
  int get utilityCount => 1;

  @override
  double get utilityTotal => 36.00;

  @override
  List<CartItem> get utilityList => _list;

  @override
  List<Category> get categories => [
    Category(id: 1, nombre: 'Cuadernos A4'),
    Category(id: 2, nombre: 'Escritura'),
  ];

  @override
  List<Brand> get brands => [Brand(id: 1, nombre: 'Stanford')];

  @override
  String getBrandName(int? id) => 'Stanford';

  @override
  String getCategoryName(int? id) => 'Cuadernos A4';

  @override
  Future<void> initCatalog() async {}

  @override
  Future<void> loadMoreItems() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPromotionProvider extends ChangeNotifier
    implements PromotionProvider {
  final List<BundleModel> _bundles = [
    BundleModel(
      id: 1,
      negocioId: 1,
      nombrePaquete: 'Pack Escolar Completo Ahorro',
      descripcion: 'Incluye 6 cuadernos A4 y 2 lapiceros finos',
      precioVentaTotal: 45.90,
      tipoPromocion: 'volumen',
      activo: true,
    ),
  ];

  @override
  List<BundleModel> get bundles => _bundles;

  @override
  int calculateBundleMaxStock(int bundleId) => 12;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithTextScaler(Widget home) {
  return MaterialApp(
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(
        ctx,
      ).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
    home: home,
  );
}

List<InventoryWrapper> _sampleCatalogItems() {
  final sharedPresUnit = ProductPresentation(
    id: 101,
    nombreEspecifico: 'Unidad Rayado 100H',
    unidadVenta: 'Unidad',
    unidadesPorVenta: 1,
    costoUnitarioCalculado: 5.0,
    precioVentaFinal: 8.50,
    precioOferta: 6.80,
    tipoDescuento: 'porcentaje',
    valorDescuento: 20.0,
    stockActual: 120,
    usaStockCompartido: true,
    esDefault: true,
  );
  final sharedPresBox = ProductPresentation(
    id: 102,
    nombreEspecifico: 'Docena Institucional',
    unidadVenta: 'Docena',
    unidadesPorVenta: 12,
    costoUnitarioCalculado: 60.0,
    precioVentaFinal: 84.0,
    stockActual: 120,
    usaStockCompartido: true,
    cupoMaximoVariante: 6,
  );

  final prodShared = Product(
    id: 1,
    nombre: 'Cuaderno Universitario Espiral Stanford',
    descripcion: 'Tapa dura plastificada de alta durabilidad.',
    categoriaId: 1,
    marcaId: 1,
    modoStock: 'COMPARTIDO',
    stockCompartido: 120,
    presentaciones: [sharedPresUnit, sharedPresBox],
  );

  final ownPres = ProductPresentation(
    id: 201,
    nombreEspecifico: 'Caja x12 Colores Largos',
    unidadVenta: 'Caja',
    unidadesPorVenta: 12,
    costoUnitarioCalculado: 22.0,
    precioVentaFinal: 36.0,
    stockActual: 37,
    usaStockCompartido: false,
    esDefault: true,
  );

  final prodOwn = Product(
    id: 2,
    nombre: 'Colores Escolares Artesco x12',
    categoriaId: 2,
    marcaId: 1,
    presentaciones: [ownPres],
  );

  return [
    InventoryWrapper(product: prodShared, presentation: sharedPresUnit),
    InventoryWrapper(product: prodOwn, presentation: ownPres),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Plan 25 Fase 9C-1 — Censo Post-Formato (<600 / <650) y Paridad', () {
    test('Cumple topes estrictos en coordinadores (<600) y submódulos (<650)', () {
      final root = _resolveAppMovilRoot();

      const coordinators = [
        'lib/features/catalog/screens/catalog/catalog_screen.dart',
        'lib/features/catalog/widgets/variants/variant_extract_config_modal.dart',
        'lib/core/widgets/product_detail_modal.dart',
        'lib/core/widgets/stock_update_modal.dart',
      ];
      for (final rel in coordinators) {
        expect(_lineCount(root, rel), lessThan(600), reason: rel);
      }

      const subModules = [
        'lib/features/catalog/screens/catalog/widgets/catalog_screen_actions_and_transfers.dart',
        'lib/features/catalog/screens/catalog/widgets/catalog_screen_offers_section.dart',
        'lib/features/catalog/screens/catalog/widgets/catalog_screen_bottom_bar.dart',
        'lib/features/catalog/widgets/variants/extract_config/variant_extract_header_and_modes.dart',
        'lib/features/catalog/widgets/variants/extract_config/variant_extract_economic_and_sections.dart',
        'lib/features/catalog/widgets/variants/extract_config/variant_extract_stock_and_footer.dart',
        'lib/core/widgets/product_detail/product_detail_header_and_variants.dart',
        'lib/core/widgets/product_detail/product_detail_financial_band.dart',
        'lib/core/widgets/product_detail/product_detail_price_and_actions.dart',
        'lib/core/widgets/stock_update/stock_update_shared_banners.dart',
        'lib/core/widgets/stock_update/stock_update_own_mode_controls.dart',
        'lib/core/widgets/stock_update/stock_update_stepper_and_preview.dart',
      ];
      for (final rel in subModules) {
        expect(_lineCount(root, rel), lessThan(650), reason: rel);
      }

      // Paridad de importación directa desde rutas originales
      expect(CatalogScreen, isNotNull);
      expect(CatalogScreenState, isNotNull);
      expect(VariantExtractConfigModal, isNotNull);
      expect(ProductDetailModal, isNotNull);
      expect(StockUpdateModal, isNotNull);
    });
  });

  group('Plan 25 Fase 9C-1 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
      testWidgets(
        'CatalogScreen, VariantExtractConfigModal, ProductDetailModal y StockUpdateModal en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final capturedMessages = <String>[];
          String currentStage = 'init';
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            final msg = details.exceptionAsString();
            capturedMessages.add(
              msg.toLowerCase().contains('overflowed')
                  ? '[$currentStage] ${details.toString()}'
                  : '[$currentStage] $msg',
            );
          };

          try {
            final sampleItems = _sampleCatalogItems();
            final invProv = _MockInventoryProvider(sampleItems);
            final catProv = _MockCatalogProvider(sampleItems);
            final promoProv = _MockPromotionProvider();
            final authProv = _MockAuthProvider();

            // 1. CatalogScreen (AppBar + Ofertas Expandidas + Grilla + Barra Inferior Expandida)
            currentStage = 'CatalogScreen';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: invProv,
                  ),
                  ChangeNotifierProvider<CatalogProvider>.value(value: catProv),
                  ChangeNotifierProvider<PromotionProvider>.value(
                    value: promoProv,
                  ),
                ],
                child: _wrapWithTextScaler(
                  const CatalogScreen(autoTriggerTour: false),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            final offersToggle = find.textContaining('Ofertas Disponibles');
            if (offersToggle.evaluate().isNotEmpty) {
              await tester.tap(offersToggle.first);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 350));
            }

            final expandBottom = find.textContaining('VER CARRITO Y LISTA');
            if (expandBottom.evaluate().isNotEmpty) {
              await tester.tap(expandBottom.first);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 350));
            }

            // 2. VariantExtractConfigModal (Factor 12 + Stock Compartido + Cortar habilitado)
            currentStage = 'VariantExtractConfigModal';
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: VariantExtractConfigModal(
                    originProductName:
                        'Cuaderno Universitario Espiral Stanford',
                    originProductId: 1,
                    totalPresentations: 3,
                    categoryId: 1,
                    categoryName: 'Cuadernos',
                    brandId: 1,
                    brandName: 'Stanford',
                    generalProviderId: 1,
                    generalProviderName: 'Distribuidora Andina',
                    parentDescription: 'Papel bond 75g alta blancura.',
                    parentImageUrl: '',
                    modoStock: 'COMPARTIDO',
                    parentSharedStock: 120,
                    variantControllerMap: const {
                      'id': 'var-box',
                      'isDefault': false,
                      'specific': 'Docena Rayada',
                      'unidadVenta': 'Docena',
                      'unidadesVenta': '12',
                      'precioVenta': '84.00',
                      'costoPres': '60.00',
                      'margen': '1.40',
                      'stockFinal': '10',
                      'barcode': '7750011223344',
                      'usaStockCompartido': true,
                    },
                    isDark: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Continuar a Crear →'), findsOneWidget);

            // 3. ProductDetailModal (con múltiples variantes desplegadas + oferta + datos financieros)
            currentStage = 'ProductDetailModal';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<CatalogProvider>.value(value: catProv),
                ],
                child: _wrapWithTextScaler(
                  Scaffold(
                    body: ProductDetailModal(
                      item: sampleItems.first,
                      isStoreMode: false,
                      onAddToCart: (_, [__]) {},
                      onAddToList: (_, [__]) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final selectorToggle = find.text('Ver otras');
            if (selectorToggle.evaluate().isNotEmpty) {
              await tester.tap(selectorToggle.first);
              await tester.pumpAndSettle();
            }

            // 4A. StockUpdateModal Compartido con cupo == 0 (Restaurar al máximo + Editar Producto)
            currentStage = 'StockUpdateModal Shared ExhaustedQuota';
            final exhaustedQuotaPres = sampleItems
                .first
                .product
                .presentaciones[1]
                .copyWith(cupoMaximoVariante: 0);
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: StockUpdateModal(
                    key: const ValueKey('stock_modal_exhausted'),
                    presentation: exhaustedQuotaPres,
                    provider: invProv,
                    isDark: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Restaurar al máximo (10)'), findsOneWidget);

            // 4B. StockUpdateModal Compartido normal con cupo acotado (Usar máximo + Editar Producto)
            currentStage = 'StockUpdateModal Shared NormalBanner';
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: StockUpdateModal(
                    key: const ValueKey('stock_modal_shared'),
                    presentation: sampleItems.first.product.presentaciones[1],
                    provider: invProv,
                    isDark: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Usar máximo (10)'), findsOneWidget);

            // 4C. StockUpdateModal Propio con factor x12 y residuo (Sumar/Fijar + Unidad de ingreso + Cuadrar aquí)
            currentStage = 'StockUpdateModal Own Remainder';
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: StockUpdateModal(
                    key: const ValueKey('stock_modal_own'),
                    presentation: sampleItems.last.presentation,
                    provider: invProv,
                    isDark: true,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Cuadrar aquí'), findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();

            final overflowErrors = capturedMessages
                .where((m) => m.toLowerCase().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow detectado en ${size.width}x${size.height} @ 1.3x:\n${overflowErrors.join('\n')}',
            );
            expect(
              capturedMessages,
              isEmpty,
              reason:
                  'Errores de Flutter detectados en ${size.width}x${size.height}:\n${capturedMessages.join('\n')}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  });
}
