import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/widgets/home/smart_action_grid.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_detail_tour.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart';

Directory _resolveAppMovilRoot() {
  final dir = Directory.current;
  if (dir.path.endsWith('app_movil')) {
    return dir;
  }
  final nested = Directory('${dir.path}${Platform.pathSeparator}app_movil');
  if (nested.existsSync()) {
    return nested;
  }
  return dir;
}

int _lineCount(Directory root, String relativePath) {
  final file = File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  expect(file.existsSync(), isTrue, reason: 'No existe $relativePath');
  return file.readAsLinesSync().length;
}

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Central Escolar SAC',
    ruc: '20554433221',
    address: 'Av. Los Próceres 1420',
    moneda: 'S/ (Soles)',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Angello Propietario',
    phone: '999888777',
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
  bool get isCommunityClient => false;

  @override
  bool get isOwner => true;

  @override
  bool get isWorker => false;

  @override
  String get businessName => _business.commercialName;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeLicenseProvider extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isActive => true;

  @override
  bool get canCreateSales => true;

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeScannerProvider extends ScannerProvider {}

class _FakeQuickSaleProvider extends QuickSaleProvider {}

class _FakeSaleProvider extends ChangeNotifier implements SaleProvider {
  @override
  int get todaySalesCount => 4;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeTrackingProvider extends ChangeNotifier implements TrackingProvider {
  @override
  int get clientCount => 18;

  @override
  int get pendingRewardsCount => 2;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeInventoryProvider extends InventoryProvider {
  Product? mockProduct;

  @override
  int get totalPresentationsCount => 42;

  @override
  String getCategoryName(int? id) => 'Útiles Escolares';

  @override
  String getBrandName(int? id) => 'Faber-Castell';

  @override
  Future<Product?> fetchProductById(int id) async => mockProduct;

  @override
  Future<Product?> getFullProductWithFallback(int id) async => mockProduct;
}

class _FakeSmartQuotationProvider extends SmartQuotationProvider {
  final Map<int, SmartQuotationModel> quotations = {};

  @override
  Future<SmartQuotationModel?> getQuotationById(int id) async => quotations[id];
}

class _FakeWorkbenchProvider extends ChangeNotifier
    implements WorkbenchProvider {
  final Map<int, ValidationResult> validations = {};

  @override
  Future<void> checkTrafficLight(int quotationId) async {}

  @override
  ValidationResult? getValidationFor(int quotationId) =>
      validations[quotationId];

  @override
  Future<void> loadDashboard({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Plan 25 Fase 9D-2 — Censo Post-Formato y Paridad de Símbolos/Keys', () {
    test(
      'Cumple topes (<600 L coordinadores, <650 L submódulos) y preserva símbolos públicos y Keys',
      () {
        final root = _resolveAppMovilRoot();

        const coordinators = [
          'lib/features/smart_quotation/screens/quotation_detail_screen.dart',
          'lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart',
          'lib/core/widgets/home/smart_action_grid.dart',
        ];
        for (final path in coordinators) {
          expect(_lineCount(root, path), lessThan(600), reason: path);
        }

        const submodules = [
          'lib/features/smart_quotation/screens/quotation_detail/quotation_detail_validation_mixin.dart',
          'lib/features/smart_quotation/screens/quotation_detail/quotation_detail_dialogs_mixin.dart',
          'lib/features/smart_quotation/screens/quotation_detail/quotation_detail_state_sheet_mixin.dart',
          'lib/features/smart_quotation/screens/quotation_detail/quotation_detail_header_and_banners.dart',
          'lib/features/smart_quotation/widgets/matching/detail_modal/product_quote_detail_logic_mixin.dart',
          'lib/features/smart_quotation/widgets/matching/detail_modal/product_quote_header_and_variants_section.dart',
          'lib/features/smart_quotation/widgets/matching/detail_modal/product_quote_pricing_and_bundles_section.dart',
          'lib/features/smart_quotation/widgets/matching/detail_modal/product_quote_qty_and_totals_section.dart',
          'lib/core/widgets/home/smart_action_grid/smart_action_grid_definitions_mixin.dart',
          'lib/core/widgets/home/smart_action_grid/smart_action_grid_cards_mixin.dart',
          'lib/core/widgets/home/smart_action_grid/smart_action_grid_studio_cards_mixin.dart',
          'lib/core/widgets/home/smart_action_grid/smart_action_grid_modals_and_trays_mixin.dart',
        ];
        for (final path in submodules) {
          expect(_lineCount(root, path), lessThan(650), reason: path);
        }

        // Paridad de importación directa desde rutas originales
        expect(QuotationDetailScreen, isNotNull);
        expect(ProductQuoteDetailModal, isNotNull);
        expect(ProductQuoteDetailModal.show, isNotNull);
        expect(SmartActionGrid, isNotNull);

        const quoteWidget = QuotationDetailScreen(
          quotationId: 10,
          clientName: 'Cliente Test',
          autoTriggerTour: false,
        );
        expect(quoteWidget.quotationId, equals(10));

        const gridKey = ValueKey('home_smart_grid_tour_key');
        const gridWidget = SmartActionGrid(tourKey: gridKey);
        expect(gridWidget.tourKey, equals(gridKey));
      },
    );
  });

  group('Plan 25 Fase 9D-2 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    const viewports = [Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final size in viewports) {
      testWidgets(
        'QuotationDetailScreen, ProductQuoteDetailModal y SmartActionGrid en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
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
            final authProv = _FakeAuthProvider();
            final licenseProv = _FakeLicenseProvider();
            final scannerProv = _FakeScannerProvider();
            final quickSaleProv = _FakeQuickSaleProvider();
            final saleProv = _FakeSaleProvider();
            final trackingProv = _FakeTrackingProvider();
            final fakeInv = _FakeInventoryProvider();
            final fakeQuoteProv = _FakeSmartQuotationProvider();
            final fakeWorkbench = _FakeWorkbenchProvider();

            final pendingQuote = SmartQuotationModel(
              id: 501,
              negocioId: 1,
              creadoPorUsuarioId: 1,
              clientId: 20,
              clientName: 'Lista Escolar Primaria María Ángel Peña',
              institutionName: 'IE Santa Rosa de Lima',
              gradeLevel: '5to Primaria Sección B',
              notas: 'Con forro azul y etiquetas',
              totalAmount: 128.90,
              totalSavings: 14.50,
              status: 'PENDING',
              type: 'manual',
              createdAt: '2026-11-20T10:00:00',
              items: [
                QuotationItem(
                  id: 1,
                  productId: 100,
                  presentationId: 101,
                  productName: 'Cuaderno A4 Rayado Profesional',
                  brandName: 'Faber-Castell',
                  specificName: 'Caja Escolar',
                  salesUnit: '½ Docena',
                  quantity: 2,
                  unitPriceApplied: 21.50,
                  originalUnitPrice: 25.00,
                ),
              ],
            );

            final soldQuote = SmartQuotationModel(
              id: 502,
              negocioId: 1,
              creadoPorUsuarioId: 1,
              clientId: 20,
              clientName: 'Pedido Escolar Vendido Histórico',
              totalAmount: 84.00,
              totalSavings: 0.0,
              status: 'SOLD',
              type: 'manual',
              createdAt: '2026-11-21T10:00:00',
              items: pendingQuote.items,
            );

            fakeQuoteProv.quotations[501] = pendingQuote;
            fakeQuoteProv.quotations[502] = soldQuote;
            fakeWorkbench.validations[501] = ValidationResult(
              hasIssues: true,
              canSell: false,
              stockWarnings: [
                StockWarning(
                  itemId: 1,
                  productName: 'Cuaderno A4 Rayado Profesional',
                  requested: 12,
                  available: 5,
                ),
              ],
              priceChanges: [
                PriceChange(
                  itemId: 1,
                  productName: 'Cuaderno A4 Rayado Profesional',
                  oldPrice: 25.00,
                  newPrice: 26.50,
                ),
              ],
            );

            // 1A. QuotationDetailScreen PENDING (banner crítico + hoja de opciones)
            currentStage = 'QuotationDetailScreen PENDING';
            final tourKeys = QuotationDetailTourKeys();
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<WorkbenchProvider>.value(
                    value: fakeWorkbench,
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: fakeQuoteProv,
                  ),
                  ChangeNotifierProvider<QuickSaleProvider>.value(
                    value: quickSaleProv,
                  ),
                ],
                child: _wrapWithTextScaler(
                  QuotationDetailScreen(
                    quotationId: 501,
                    clientName: pendingQuote.clientName,
                    autoTriggerTour: false,
                    tourKeys: tourKeys,
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));

            expect(find.text('VER SOLUCIONES'), findsOneWidget);
            expect(find.byKey(tourKeys.privacyAndEditKey), findsOneWidget);

            // Abrir modal de opciones y estado
            await tester.tap(find.byTooltip('Opciones y Estado'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('Opciones de Cotización'), findsOneWidget);
            expect(find.text('Convertir en Pack Escolar'), findsOneWidget);

            Navigator.of(
              tester.element(find.text('Opciones de Cotización')),
            ).pop();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            // 1B. QuotationDetailScreen SOLD (bloqueo edición + DUPLICAR COTIZACIÓN)
            currentStage = 'QuotationDetailScreen SOLD';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<WorkbenchProvider>.value(
                    value: fakeWorkbench,
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: fakeQuoteProv,
                  ),
                  ChangeNotifierProvider<QuickSaleProvider>.value(
                    value: quickSaleProv,
                  ),
                ],
                child: _wrapWithTextScaler(
                  const QuotationDetailScreen(
                    key: ValueKey('quote_502'),
                    quotationId: 502,
                    clientName: 'Pedido Escolar Vendido Histórico',
                    autoTriggerTour: false,
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('LISTA VENDIDA Y CERRADA'), findsOneWidget);
            expect(find.text('DUPLICAR COTIZACIÓN'), findsOneWidget);

            // 2. ProductQuoteDetailModal (variantes mixto/compartido + descuento manual + bundles)
            currentStage = 'ProductQuoteDetailModal';
            final fullProd = Product(
              id: 100,
              nombre: 'Cuaderno A4 Rayado Profesional',
              categoriaId: 1,
              modoStock: 'MIXTO',
              stockCompartido: 68,
              costoBase: 2.0,
              presentaciones: [
                ProductPresentation(
                  id: 101,
                  nombreEspecifico: 'Caja Escolar',
                  unidadVenta: '½ Docena',
                  unidadesPorVenta: 6,
                  precioVentaFinal: 25.0,
                  precioOferta: 21.50,
                  costoUnitarioCalculado: 12.0,
                  usaStockCompartido: true,
                  cupoMaximoVariante: 9,
                  stockActual: 68,
                ),
                ProductPresentation(
                  id: 102,
                  nombreEspecifico: 'Unidad Suelta',
                  unidadVenta: 'Unidad',
                  unidadesPorVenta: 1,
                  precioVentaFinal: 4.5,
                  costoUnitarioCalculado: 2.0,
                  usaStockCompartido: false,
                  stockActual: 15,
                ),
              ],
            );
            fakeInv.mockProduct = fullProd;
            final wrapper = InventoryWrapper(
              product: fullProd,
              presentation: fullProd.presentaciones.first,
            );
            final bundle = BundleModel(
              id: 1,
              negocioId: 1,
              nombrePaquete: 'Pack Lista Primaria Completa',
              precioVentaTotal: 90.0,
            );
            final bundleItems = {
              1: [
                BundleItemModel(
                  id: 1,
                  paqueteId: 1,
                  productoId: 100,
                  presentacionId: 101,
                  cantidadRequerida: 2,
                ),
              ],
            };

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: fakeInv,
                  ),
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                ],
                child: _wrapWithTextScaler(
                  Scaffold(
                    body: ProductQuoteDetailModal(
                      wrapper: wrapper,
                      brandName: 'Faber-Castell',
                      currentQuantity: 2,
                      currentSnapshotName: 'Cuaderno Rayado Viejo',
                      categoryName: 'Útiles Escolares',
                      availableBundles: [bundle],
                      bundleItemsCache: bundleItems,
                      onSave: (_, __, ___, ____) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final verOtrasFinder = find.text('Ver otras');
            await Scrollable.ensureVisible(
              tester.element(verOtrasFinder),
              alignment: 0.3,
            );
            await tester.pump();
            await tester.tap(verOtrasFinder);
            await tester.pumpAndSettle();
            expect(
              find.textContaining('Inventario base compartido: 68 und.'),
              findsOneWidget,
            );

            final manualRadioTitle = find.text('Precio Especial Manual');
            await Scrollable.ensureVisible(
              tester.element(manualRadioTitle),
              alignment: 0.3,
            );
            await tester.pump();
            await tester.tap(manualRadioTitle);
            await tester.pumpAndSettle();
            expect(find.text('S/ a Descontar'), findsOneWidget);
            expect(find.text('CONFIRMAR PRODUCTO'), findsOneWidget);

            final addQtyFinder = find.byIcon(Icons.add);
            await Scrollable.ensureVisible(
              tester.element(addQtyFinder),
              alignment: 0.3,
            );
            await tester.pump();
            await tester.tap(addQtyFinder);
            await tester.pumpAndSettle();

            // 3. SmartActionGrid (modo normal 2 cols + edición Home Studio 3 cols + Hero Card)
            currentStage = 'SmartActionGrid';
            const smartTourKey = ValueKey('smart_action_grid_tour');
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<LicenseProvider>.value(
                    value: licenseProv,
                  ),
                  ChangeNotifierProvider<ScannerProvider>.value(
                    value: scannerProv,
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: fakeQuoteProv,
                  ),
                  ChangeNotifierProvider<QuickSaleProvider>.value(
                    value: quickSaleProv,
                  ),
                  ChangeNotifierProvider<SaleProvider>.value(value: saleProv),
                  ChangeNotifierProvider<TrackingProvider>.value(
                    value: trackingProv,
                  ),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: fakeInv,
                  ),
                ],
                child: _wrapWithTextScaler(
                  const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: SmartActionGrid(tourKey: smartTourKey),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.byKey(smartTourKey), findsOneWidget);
            expect(find.text('Gestión Operativa'), findsOneWidget);
            expect(find.text('Venta Rápida'), findsOneWidget);

            // Entrar en modo Home Studio, cambiar densidad a 3 Columnas y fijar Hero
            await tester.tap(find.text('Personalizar'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('Densidad:'), findsOneWidget);

            await tester.tap(find.text('3 Columnas'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));

            final starFinder = find.byIcon(Icons.star_border_rounded).first;
            await tester.ensureVisible(starFinder);
            await tester.pump();
            await tester.tap(starFinder);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));

            final listoFinder = find.text('Listo');
            await Scrollable.ensureVisible(
              tester.element(listoFinder),
              alignment: 0.2,
            );
            await tester.pump();
            await tester.tap(listoFinder);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('ACCESO RÁPIDO'), findsOneWidget);

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
