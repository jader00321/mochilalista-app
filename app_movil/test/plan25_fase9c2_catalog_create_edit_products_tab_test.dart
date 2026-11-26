import 'dart:io';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_stock_section.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/features/catalog/screens/tabs/products_tab.dart';
import 'package:app_movil/features/catalog/widgets/form/product_create_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
  String get activeBusinessName => 'Librería Central';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier
    implements InventoryProvider {
  final List<InventoryWrapper> _items;
  bool _showStockAlertColors = true;
  SortType _prodSort = SortType.id;
  bool _prodAsc = false;

  _MockInventoryProvider(this._items);

  @override
  List<InventoryWrapper> get items => _items;

  @override
  List<Category> get categories => [
    Category(id: 1, nombre: 'Cuadernos', productsCount: 8, activo: true),
    Category(id: 2, nombre: 'Escritura', productsCount: 5, activo: true),
  ];

  @override
  List<Brand> get brands => [Brand(id: 1, nombre: 'Stanford')];

  @override
  List<ProviderModel> get providers => [
    ProviderModel(id: 1, nombreEmpresa: 'Distribuidora Andina'),
  ];

  @override
  bool get showStockAlertColors => _showStockAlertColors;

  @override
  int get totalProductsCount => _items.length;

  @override
  int get totalPresentationsCount => _items.length;

  @override
  int get orphanCategoriesCount => 2;

  @override
  bool get hasOrphanCategories => true;

  @override
  List<int> get activeCategoryIds => const [];

  @override
  List<int> get activeBrandIds => const [];

  @override
  List<int> get activeProviderIds => const [];

  @override
  String? get activeState => null;

  @override
  String get activeQuery => '';

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

  int get activeFilterCount => 0;

  @override
  SortType get prodSort => _prodSort;

  @override
  bool get prodAsc => _prodAsc;

  @override
  SortType get catSort => SortType.alpha;

  @override
  bool get catAsc => true;

  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  String get errorMessage => '';

  @override
  String? get lastActionError => null;

  @override
  bool get hasCreationDraft => true;

  @override
  ProductCreateDraft? get creationDraft => ProductCreateDraft(
    name: 'Cuaderno Universitario A4 Ejecutivo',
    presentations: const [
      {'specific': 'Rayado 100H'},
      {'specific': 'Cuadriculado 100H'},
    ],
  );

  @override
  String getBrandName(int? id) => 'Stanford';

  @override
  String getCategoryName(int? id) => 'Cuadernos';

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
  void sortProducts(SortType type) {
    if (_prodSort == type) {
      _prodAsc = !_prodAsc;
    } else {
      _prodSort = type;
      _prodAsc = true;
    }
    notifyListeners();
  }

  @override
  Future<void> toggleStockAlertColors() async {
    _showStockAlertColors = !_showStockAlertColors;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _buildSampleProduct() {
  final presUnit = ProductPresentation(
    id: 101,
    nombreEspecifico: 'Unidad Rayada',
    unidadVenta: 'Unidad',
    unidadesPorVenta: 1,
    costoUnitarioCalculado: 4.50,
    factorGananciaVenta: 1.40,
    precioVentaFinal: 6.30,
    stockActual: 68,
    usaStockCompartido: true,
    estado: 'publico',
    esDefault: true,
  );
  final presBox = ProductPresentation(
    id: 102,
    nombreEspecifico: 'Caja x12',
    unidadVenta: 'Caja',
    unidadesPorVenta: 12,
    costoUnitarioCalculado: 54.00,
    factorGananciaVenta: 1.35,
    precioVentaFinal: 72.90,
    stockActual: 68,
    cupoMaximoVariante: 4,
    usaStockCompartido: true,
    estado: 'publico',
    esDefault: false,
  );
  return Product(
    id: 10,
    nombre: 'Cuaderno Espiral Ejecutivo Stanford',
    descripcion: 'Papel bond 75g alta blancura para uso escolar.',
    categoriaId: 1,
    marcaId: 1,
    imagenUrl: '',
    codigoBarras: '7750011223344',
    modoStock: 'COMPARTIDO',
    stockCompartido: 68,
    costoBase: 4.50,
    presentaciones: [presUnit, presBox],
  );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 25 Fase 9C-2 — Censo Post-Formato (<600 / <650) y Paridad', () {
    test(
      'Cumple topes estrictos en coordinadores/fachadas (<600) y submódulos (<650) y paridad de exportación',
      () {
        final root = _resolveAppMovilRoot();

        const coordinators = [
          'lib/features/catalog/widgets/form/product_create_operations.dart',
          'lib/core/widgets/presentation_card/presentation_stock_section.dart',
          'lib/features/catalog/screens/product_edit_screen.dart',
          'lib/features/catalog/screens/tabs/products_tab.dart',
        ];
        const submodules = [
          'lib/features/catalog/widgets/form/create_operations/product_create_hydrated_data.dart',
          'lib/features/catalog/widgets/form/create_operations/product_create_draft_and_hydration.dart',
          'lib/features/catalog/widgets/form/create_operations/product_create_presentation_ops.dart',
          'lib/features/catalog/widgets/form/create_operations/product_create_submit_ops.dart',
          'lib/core/widgets/presentation_card/stock_section/presentation_stock_shared_panel.dart',
          'lib/core/widgets/presentation_card/stock_section/presentation_stock_own_panel.dart',
          'lib/core/widgets/presentation_card/stock_section/presentation_stock_validation_alerts.dart',
          'lib/features/catalog/screens/product_edit/product_edit_snapshot_and_undo.dart',
          'lib/features/catalog/screens/product_edit/product_edit_variant_actions.dart',
          'lib/features/catalog/screens/product_edit/product_edit_appbar_and_body.dart',
          'lib/features/catalog/screens/tabs/widgets/products_tab_scan_and_modals.dart',
          'lib/features/catalog/screens/tabs/widgets/products_tab_list_and_slivers.dart',
          'lib/features/catalog/screens/tabs/widgets/products_tab_fab_and_toast.dart',
        ];

        for (final path in coordinators) {
          final lines = _lineCount(root, path);
          expect(
            lines,
            lessThan(600),
            reason: 'Coordinador/Fachada $path excede 600 L ($lines)',
          );
        }
        for (final path in submodules) {
          final lines = _lineCount(root, path);
          expect(
            lines,
            lessThan(650),
            reason: 'Submódulo $path excede 650 L ($lines)',
          );
        }

        // Paridad de símbolos públicos importables desde las 4 rutas originales
        const hydrated = ProductCreateHydratedData(modoStock: 'COMPARTIDO');
        expect(hydrated.modoStock, 'COMPARTIDO');
        expect(ProductCreateOperations.createControllerMapFromDraft, isNotNull);
        expect(ProductCreateOperations.buildCurrentDraft, isNotNull);
        expect(ProductCreateOperations.addPresentation, isNotNull);
        expect(ProductCreateOperations.clonePresentation, isNotNull);
        expect(ProductCreateOperations.createLeftover, isNotNull);
        expect(ProductCreateOperations.invalidateLeftover, isNotNull);
        expect(ProductCreateOperations.removePresentation, isNotNull);
        expect(ProductCreateOperations.setDefault, isNotNull);
        expect(ProductCreateOperations.moveUp, isNotNull);
        expect(ProductCreateOperations.moveDown, isNotNull);
        expect(ProductCreateOperations.handleClearAll, isNotNull);
        expect(ProductCreateOperations.submitProduct, isNotNull);
        expect(ProductCreateOperations.hydrateFromDraft, isNotNull);
        expect(ProductCreateOperations.hydrateFromExtraction, isNotNull);
        expect(ProductCreateOperations.applyGeneralProviderChange, isNotNull);
        expect(PresentationStockSection, isNotNull);
        expect(ProductEditScreen, isNotNull);
        expect(ProductsTab, isNotNull);

        final controllers = <Map<String, dynamic>>[];
        final keys = <String, GlobalKey>{};
        ProductCreateOperations.addPresentation(
          controllers: controllers,
          keys: keys,
          onSyncDraft: () {},
          generalProviderId: null,
          generalState: 2,
          isDefault: true,
        );
        expect(controllers.length, 1);
      },
    );
  });

  group('Plan 25 Fase 9C-2 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    const viewports = [Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final size in viewports) {
      testWidgets(
        'PresentationStockSection, ProductEditScreen y ProductsTab en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final capturedMessages = <String>[];
          String currentStage = 'init';
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            capturedMessages.add('[$currentStage] ${details.toString()}');
          };

          try {
            final sampleProduct = _buildSampleProduct();
            final sampleWrapper = InventoryWrapper(
              product: sampleProduct,
              presentation: sampleProduct.presentaciones.first,
            );
            final invProv = _MockInventoryProvider([sampleWrapper]);
            final authProv = _MockAuthProvider();

            // 1A. PresentationStockSection MIXTO Compartido con cupo acotado
            currentStage = 'PresentationStockSection MixedBounded';
            final sharedCtrl = TextEditingController(text: '68');
            final stockFinalCtrl = TextEditingController(text: '23');
            final controllerMap = <String, dynamic>{
              'cupoMaximoVariante': 23,
              'usaStockCompartido': true,
            };
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: PresentationStockSection(
                      key: const ValueKey('stock_sec_mixed'),
                      stockInicialCtrl: TextEditingController(text: '0'),
                      nuevoIngresoCtrl: TextEditingController(text: '0'),
                      stockDescuentoCtrl: TextEditingController(text: '0'),
                      stockFinalCtrl: stockFinalCtrl,
                      ajusteBaseCtrl: TextEditingController(text: '0'),
                      unidadVentaCtrl: TextEditingController(text: 'Par'),
                      unidadesVentaCtrl: TextEditingController(text: '2'),
                      specificCtrl: TextEditingController(text: 'Principal'),
                      isEditMode: true,
                      originalBaseStock: 68,
                      leftoverCreated: false,
                      stockValidation: StockValidationResult.empty(),
                      costoBaseParaSobrante: 2.0,
                      isDark: false,
                      onStockChanged: () {},
                      onAjusteBaseChanged: () {},
                      modoStock: 'MIXTO',
                      usaStockCompartido: true,
                      sharedStockCtrl: sharedCtrl,
                      controllerMap: controllerMap,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Usar máximo (34)'), findsOneWidget);

            // 1B. PresentationStockSection Independiente EditMode con Leftover y Ajustes
            currentStage = 'PresentationStockSection OwnLeftover';
            final leftoverValidation = UnitCatalogService.validateStockForUnit(
              totalUnitsBase: 26,
              presentationFactor: 12,
              baseUnitCost: 4.50,
              unitName: 'Docena',
            );
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: PresentationStockSection(
                      key: const ValueKey('stock_sec_leftover'),
                      stockInicialCtrl: TextEditingController(text: '26'),
                      nuevoIngresoCtrl: TextEditingController(text: '0'),
                      stockDescuentoCtrl: TextEditingController(text: '0'),
                      stockFinalCtrl: TextEditingController(text: '2'),
                      ajusteBaseCtrl: TextEditingController(text: '26'),
                      unidadVentaCtrl: TextEditingController(text: 'Docena'),
                      unidadesVentaCtrl: TextEditingController(text: '12'),
                      specificCtrl: TextEditingController(
                        text: 'Docena Escolar',
                      ),
                      isEditMode: true,
                      originalBaseStock: 26,
                      leftoverCreated: false,
                      stockValidation: leftoverValidation,
                      costoBaseParaSobrante: 4.50,
                      isDark: false,
                      onStockChanged: () {},
                      onAjusteBaseChanged: () {},
                      onCreateLeftover: (_, __) {},
                      modoStock: 'INDEPENDIENTE',
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final toggleAjustePrev = find.text('Ajuste por ventas previas');
            if (toggleAjustePrev.evaluate().isNotEmpty) {
              await tester.ensureVisible(toggleAjustePrev);
              await tester.tap(toggleAjustePrev);
              await tester.pumpAndSettle();
            }
            final toggleAjusteBase = find.text('Ajustar Unidades Reales');
            if (toggleAjusteBase.evaluate().isNotEmpty) {
              await tester.ensureVisible(toggleAjusteBase);
              await tester.tap(toggleAjusteBase);
              await tester.pumpAndSettle();
            }

            // 1C. PresentationStockSection Independiente con Déficit
            currentStage = 'PresentationStockSection OwnDeficit';
            final deficitValidation = UnitCatalogService.validateStockForUnit(
              totalUnitsBase: 5,
              presentationFactor: 12,
              baseUnitCost: 4.50,
              unitName: 'Docena',
            );
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: PresentationStockSection(
                      key: const ValueKey('stock_sec_deficit'),
                      stockInicialCtrl: TextEditingController(text: '5'),
                      nuevoIngresoCtrl: TextEditingController(text: '0'),
                      stockDescuentoCtrl: TextEditingController(text: '0'),
                      stockFinalCtrl: TextEditingController(text: '0'),
                      ajusteBaseCtrl: TextEditingController(text: ''),
                      unidadVentaCtrl: TextEditingController(text: 'Docena'),
                      unidadesVentaCtrl: TextEditingController(text: '12'),
                      specificCtrl: TextEditingController(text: 'Docena'),
                      isEditMode: false,
                      originalBaseStock: 5,
                      leftoverCreated: false,
                      stockValidation: deficitValidation,
                      costoBaseParaSobrante: 4.50,
                      isDark: true,
                      onStockChanged: () {},
                      onAjusteBaseChanged: () {},
                      modoStock: 'INDEPENDIENTE',
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // 2. ProductEditScreen con edición activa (AppBar con reversion_controls)
            currentStage = 'ProductEditScreen';
            await tester.pumpWidget(
              ChangeNotifierProvider<InventoryProvider>.value(
                value: invProv,
                child: _wrapWithTextScaler(
                  ProductEditScreen(
                    productToEdit: sampleProduct,
                    autoTriggerTour: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final nameField = find.widgetWithText(
              TextField,
              'Cuaderno Espiral Ejecutivo Stanford',
            );
            expect(nameField, findsOneWidget);
            await tester.enterText(
              nameField,
              'Cuaderno Espiral Stanford Edición Especial',
            );
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('reversion_controls')),
              findsOneWidget,
            );

            // 3. ProductsTab con borrador, categorías, modo grilla/compacto, toast y modal de factura
            currentStage = 'ProductsTab';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: invProv,
                  ),
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                ],
                child: _wrapWithTextScaler(const Scaffold(body: ProductsTab())),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('tour_search_filters_fallback')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('tour_new_prod_fab_fallback')),
              findsOneWidget,
            );

            // Activar toast de alerta de stock
            final paletteBtn = find.byTooltip(
              'Colores de stock activos (Mantén presionado para info)',
            );
            if (paletteBtn.evaluate().isNotEmpty) {
              await tester.tap(paletteBtn);
              await tester.pump(const Duration(milliseconds: 300));
            }

            // Abrir Speed Dial y modal de Factura (IA) para verificar responsive del Sheet
            final fabBtn = find.byKey(
              const ValueKey('tour_new_prod_fab_fallback'),
            );
            await tester.tap(fabBtn);
            await tester.pumpAndSettle();

            final scanInvoiceOpt = find.text('Escanear Factura (IA)');
            expect(scanInvoiceOpt, findsOneWidget);
            await tester.tap(scanInvoiceOpt);
            await tester.pumpAndSettle();
            expect(find.text('Procesar Factura'), findsOneWidget);
            expect(find.text('Tomar Foto'), findsOneWidget);
            expect(find.text('Galería'), findsOneWidget);

            // Cerrar modal y esperar que expire timer del toast (2s)
            Navigator.of(tester.element(find.text('Procesar Factura'))).pop();
            await tester.pump(const Duration(milliseconds: 2200));
            await tester.pumpAndSettle();

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
