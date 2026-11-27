import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_staging_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/campaign_model.dart';
import 'package:app_movil/features/promotions/models/promotion_rule_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/promotions/screens/offers_tab.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart';
import 'package:app_movil/features/scanner/services/invoice_pdf_report_service.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart';

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
  throw StateError('No se pudo localizar app_movil desde ${cwd.path}');
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería MochilaLista 9E-1',
    address: 'Av. Los Olivos 456, Lima',
    moneda: 'S/ (Soles)',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Administrador 9E-1',
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
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  String get businessName => 'Librería MochilaLista 9E-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockThemeProvider extends ChangeNotifier implements ThemeProvider {
  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicenseProvider extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isActive => true;

  @override
  bool get isUsingByokMode => false;

  @override
  int get remainingAiScans => 50;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventoryProvider extends ChangeNotifier
    implements InventoryProvider {
  late final List<InventoryWrapper> _items = [
    InventoryWrapper(
      product: Product(
        id: 1,
        nombre: 'Cuaderno Premium A4 100 Hojas',
        categoriaId: 1,
        marcaNombre: 'Standford',
        fechaActualizacion: '2026-09-15T10:00:00Z',
      ),
      presentation: ProductPresentation(
        id: 101,
        nombreEspecifico: 'Paquete x10 Unidades',
        precioVentaFinal: 45.0,
        costoUnitarioCalculado: 32.0,
        stockActual: 24,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 2,
        nombre: 'Tempera Escolar 12 Colores',
        categoriaId: 1,
        marcaNombre: 'Artesco',
        fechaActualizacion: '2026-09-10T10:00:00Z',
      ),
      presentation: ProductPresentation(
        id: 102,
        nombreEspecifico: 'Caja Display x12',
        precioVentaFinal: 18.5,
        costoUnitarioCalculado: 12.0,
        stockActual: 8,
      ),
    ),
  ];

  @override
  List<InventoryWrapper> get items => _items;

  @override
  List<Category> get categories => [
    Category(id: 1, nombre: 'Útiles Escolares'),
  ];

  @override
  List<Brand> get brands => [
    Brand(id: 1, nombre: 'Standford'),
    Brand(id: 2, nombre: 'Artesco'),
  ];

  @override
  List<ProviderModel> get providers => const [];

  @override
  bool get isLoading => false;

  @override
  String getBrandName(int? id) => 'Standford';

  @override
  String getCategoryName(int? id) => 'Útiles Escolares';

  @override
  Future<void> loadCategories({String? searchQuery}) async {}

  @override
  Future<void> loadBrands({String? searchQuery}) async {}

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
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockPromotionProvider extends ChangeNotifier
    implements PromotionProvider {
  final List<BundleModel> _bundles = [
    BundleModel(
      id: 50,
      negocioId: 1,
      nombrePaquete: 'Pack Regreso a Clases Full Escolar',
      descripcion: 'Combina cuaderno y colores con margen competitivo',
      precioVentaTotal: 59.90,
      costoTotalCalculado: 41.00,
      activo: true,
      tipoPromocion: 'escolar',
      fechaFin: DateTime(2026, 12, 31),
    ),
  ];

  @override
  List<BundleModel> get bundles => _bundles;

  @override
  List<CampaignModel> get campaigns => const [];

  @override
  List<PromotionRuleModel> get promotionRules => const [];

  @override
  bool get isLoading => false;

  @override
  int calculateBundleMaxStock(int bundleId) => 4;

  @override
  List<BundleModel> getBundlesForPresentation(int presentacionId) =>
      presentacionId == 101 ? [_bundles.first] : const [];

  @override
  Future<void> loadPromotions(int negocioId) async {}

  @override
  Future<void> deleteBundle(int bundleId) async {}

  @override
  void refreshUI() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

StagingProductGroup _buildSampleGroup(StagingVariant variant) {
  return StagingProductGroup(
    uuidTemporal: 'grp-9e1-1',
    nombrePadre: 'Cuaderno A4 Cuadriculado 100 Hojas',
    marcaTexto: 'Standford Profesional',
    matchProducto: MatchResult(
      estado: 'MATCH_EXACTO',
      confianza: 98,
      datos: MatchData(
        id: 1,
        nombre: 'Cuaderno A4 Cuadriculado',
        categoriaNombre: 'Cuadernos y Block',
        marcaNombre: 'Standford Profesional',
      ),
    ),
    matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 98),
    variantes: [variant],
  );
}

StagingVariant _buildSampleVariant() {
  return StagingVariant(
    uuidTemporal: 'var-9e1-1',
    nombreEspecifico: 'Docena Escolar Tapa Dura',
    unidadVenta: 'Docena',
    unidadesPorVenta: 12,
    umpCompra: 'Caja',
    cantidadUmpComprada: 2.0,
    unidadesPorLote: 12,
    precioUmpProveedor: 96.0,
    totalPagoLote: 192.0,
    costoUnitarioSugerido: 96.0,
    factorGananciaVentaSugerido: 1.35,
    precioVentaSugerido: 129.60,
    matchPresentacion: MatchResult(
      estado: 'MATCH_EXACTO',
      confianza: 96,
      datos: MatchData(
        id: 20,
        nombre: 'Docena Escolar Tapa Dura',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 0,
        precioVentaFinal: 125.00,
        costoUnitarioCalculado: 90.00,
      ),
    ),
  );
}

Widget _wrapScaled(Widget child) {
  return MaterialApp(
    builder: (ctx, c) => MediaQuery(
      data: MediaQuery.of(
        ctx,
      ).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: c!,
    ),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Plan 25 Fase 9E-1: Censo Post-Formato, Hito >=1000L=0 y DRY', () {
    test(
      'Los 15 archivos modulares de 9E-1 cumplen topes estrictos y sellan FILES_GE_1000L=0',
      () {
        final root = _resolveAppMovilRoot();

        final expectedLineCaps = <String, int>{
          'lib/features/promotions/screens/offers_tab.dart': 550,
          'lib/features/promotions/screens/offers_tab/offers_tab_bundle_card_mixin.dart':
              600,
          'lib/features/promotions/screens/offers_tab/offers_tab_insights_mixin.dart':
              600,
          'lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart':
              550,
          'lib/features/scanner/widgets/staging/comparative_modal/sections/modal_header_and_identity_mixin.dart':
              600,
          'lib/features/scanner/widgets/staging/comparative_modal/sections/modal_unit_and_recalculation_mixin.dart':
              600,
          'lib/features/scanner/screens/invoice_staging_screen.dart': 550,
          'lib/features/scanner/screens/invoice_staging/invoice_staging_dialogs_and_actions_mixin.dart':
              600,
          'lib/features/scanner/screens/invoice_staging/invoice_staging_sections_and_scroll_mixin.dart':
              600,
          'lib/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart':
              550,
          'lib/features/smart_quotation/widgets/quick_sale/header/quick_sale_client_actions_mixin.dart':
              600,
          'lib/features/smart_quotation/widgets/quick_sale/header/quick_sale_client_sections_mixin.dart':
              600,
          'lib/features/scanner/services/invoice_pdf_report_service.dart': 450,
          'lib/features/scanner/services/invoice_pdf_report/invoice_pdf_report_sections_part.dart':
              550,
          'lib/features/scanner/services/invoice_pdf_report/invoice_pdf_report_tables_part.dart':
              550,
        };

        for (final entry in expectedLineCaps.entries) {
          final file = File(
            '${root.path}${Platform.pathSeparator}${entry.key}',
          );
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Falta archivo ${entry.key}',
          );
          final lines = file.readAsLinesSync().length;
          expect(
            lines,
            lessThan(entry.value),
            reason: '${entry.key} tiene $lines líneas (tope < ${entry.value})',
          );
        }

        final libDir = Directory('${root.path}${Platform.pathSeparator}lib');
        final ge1000 = <String>[];
        final b800_999 = <String>[];
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            final lines = entity.readAsLinesSync().length;
            final rel = entity.path
                .substring(root.path.length + 1)
                .replaceAll('\\', '/');
            if (lines >= 1000) {
              ge1000.add('$rel ($lines)');
            } else if (lines >= 800) {
              b800_999.add('$rel ($lines)');
            }
          }
        }

        expect(
          ge1000,
          isEmpty,
          reason:
              'Se esperaba FILES_GE_1000L_IN_APP_MOVIL=0, encontrados: $ge1000',
        );
        expect(
          b800_999.length,
          lessThanOrEqualTo(17),
          reason:
              'Se esperaba FILES_800_TO_999L_IN_APP_MOVIL <= 17 tras 9E-1, lista: $b800_999',
        );
        for (final closed9e1 in const [
          'lib/features/promotions/screens/offers_tab.dart',
          'lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart',
          'lib/features/scanner/screens/invoice_staging_screen.dart',
          'lib/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart',
          'lib/features/scanner/services/invoice_pdf_report_service.dart',
        ]) {
          expect(
            b800_999.any((entry) => entry.startsWith(closed9e1)),
            isFalse,
            reason:
                'El archivo $closed9e1 cerrado en 9E-1 no puede volver a >= 800 L',
          );
        }
      },
    );

    test('Reutilización DRY en 9E-1 y retiro de deuda intl / emojis UI crudos', () {
      final root = _resolveAppMovilRoot();

      final offersTab = File(
        '${root.path}/lib/features/promotions/screens/offers_tab.dart',
      ).readAsStringSync();
      final offersCard = File(
        '${root.path}/lib/features/promotions/screens/offers_tab/offers_tab_bundle_card_mixin.dart',
      ).readAsStringSync();
      final pdfService = File(
        '${root.path}/lib/features/scanner/services/invoice_pdf_report_service.dart',
      ).readAsStringSync();
      final pdfSections = File(
        '${root.path}/lib/features/scanner/services/invoice_pdf_report/invoice_pdf_report_sections_part.dart',
      ).readAsStringSync();
      final quickHeader = File(
        '${root.path}/lib/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart',
      ).readAsStringSync();
      final compIdentity = File(
        '${root.path}/lib/features/scanner/widgets/staging/comparative_modal/sections/modal_header_and_identity_mixin.dart',
      ).readAsStringSync();

      expect(offersTab.contains('package:intl/intl.dart'), isFalse);
      expect(offersTab.contains('NumberFormat'), isFalse);
      expect(offersCard.contains('AppCurrency.format'), isTrue);
      expect(offersCard.contains('AppDateFormatter.ddMMyyyy'), isTrue);
      expect(offersCard.contains('AppFeedbackHelper.'), isTrue);

      expect(pdfService.contains('package:intl/intl.dart'), isFalse);
      expect(pdfService.contains('AppDateFormatter.ddMMyyyy'), isTrue);
      expect(pdfSections.contains('AppCurrency.format'), isTrue);

      expect(quickHeader.contains('AppCurrency.format'), isTrue);
      expect(compIdentity.contains('📝'), isFalse);
    });
  });

  group(
    'Plan 25 Fase 9E-1: Paridad y Unit Tests de InvoicePdfReportService',
    () {
      test(
        'generatePdfBytes produce %PDF- válido con ítems IA, manuales y vacío',
        () async {
          final user = UserModel(
            id: 1,
            fullName: 'Auditor 9E-1',
            isActive: true,
            business: BusinessModel(
              id: 1,
              commercialName: 'Comercial MochilaLista S.A.C.',
            ),
          );

          final aiInvoice = InvoiceModel(
            id: 42,
            numeroSecuencial: 42,
            negocioId: 1,
            imagenUrl: 'https://cdn.example.com/42.jpg',
            estado: 'completado',
            fechaCarga: DateTime(2026, 11, 20, 10, 30),
            fechaEmision: DateTime(2026, 11, 19),
            montoTotalFactura: 384.0,
            cantidadItemsExtraidos: 2,
            datosCrudosIaJson: {
              'items': [
                {
                  'descripcion_detectada': 'Cuaderno Rayado 100H Standford',
                  'producto_padre_estimado': 'Cuaderno A4',
                  'variante_detectada': 'Rayado 100H',
                  'marca_detectada': 'Standford',
                  'cantidad_ump_comprada': 2,
                  'ump_compra': 'DOC',
                  'unidades_por_lote': 12,
                  'total_pago_lote': 192.0,
                },
                {
                  'descripcion_detectada': 'Colores x12 Artesco Largo',
                  'cantidad_ump_comprada': 4,
                  'ump_compra': 'PAQ',
                  'unidades_por_lote': 6,
                  'total_pago_lote': 192.0,
                },
              ],
            },
          );

          final Uint8List aiPdf =
              await InvoicePdfReportService.generatePdfBytes(
                invoice: aiInvoice,
                providerName: 'Distribuidora Escolar SAC',
                providerRuc: '20123456789',
                currentUser: user,
              );
          expect(aiPdf.length, greaterThan(500));
          expect(String.fromCharCodes(aiPdf.take(5)), equals('%PDF-'));

          final manualInvoice = InvoiceModel(
            id: 43,
            numeroSecuencial: 43,
            negocioId: 1,
            imagenUrl: '',
            estado: 'revision',
            fechaCarga: DateTime(2026, 11, 21, 9, 15),
          );
          final Uint8List manualPdf =
              await InvoicePdfReportService.buildExecutivePdf(
                invoice: manualInvoice,
                providerName: 'Proveedor Manual',
                currentUser: user,
                linkedPresentations: const [
                  {
                    'producto_nombre': 'Borrador Blanco',
                    'presentacion_nombre': 'Caja x24',
                    'precio_costo': 18.0,
                    'cantidad_stock': 3,
                  },
                ],
              );
          expect(manualPdf.length, greaterThan(500));
          expect(String.fromCharCodes(manualPdf.take(5)), equals('%PDF-'));

          final Uint8List emptyPdf =
              await InvoicePdfReportService.generatePdfBytes(
                invoice: manualInvoice,
              );
          expect(String.fromCharCodes(emptyPdf.take(5)), equals('%PDF-'));
        },
      );
    },
  );

  group('Plan 25 Fase 9E-1: 0px Overflow @ 1.3x en 320dp, 360dp y 412dp', () {
    const viewports = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final viewport in viewports) {
      testWidgets(
        'OffersTab sin overflow @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          try {
            FlutterError.onError = (d) => errors.add(d.toString());

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: _MockInventoryProvider(),
                  ),
                  ChangeNotifierProvider<PromotionProvider>.value(
                    value: _MockPromotionProvider(),
                  ),
                ],
                child: _wrapScaled(
                  Scaffold(body: OffersTab(tourKeys: InventoryTabTourKeys())),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Insights & Sugerencias'), findsOneWidget);
            expect(
              find.text('Pack Regreso a Clases Full Escolar'),
              findsOneWidget,
            );

            // Expandir Insights & Sugerencias para validar Paquete Fusión y alertas lentas
            await tester.tap(find.text('Insights & Sugerencias'));
            await tester.pumpAndSettle();
            expect(find.text('Paquete Fusión Sugerido'), findsOneWidget);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow en OffersTab @ ${viewport.width}x${viewport.height}:\n${errors.join('\n')}',
          );
        },
      );

      testWidgets(
        'ComparativeUpdateModal sin overflow @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          try {
            FlutterError.onError = (d) => errors.add(d.toString());
            final scannerProv = ScannerProvider();
            final variant = _buildSampleVariant();
            final group = _buildSampleGroup(variant);

            await tester.pumpWidget(
              _wrapScaled(
                Scaffold(
                  body: Builder(
                    builder: (ctx) => Center(
                      child: ElevatedButton(
                        onPressed: () {
                          ComparativeUpdateModal.show(
                            ctx,
                            variant: variant,
                            group: group,
                            dbData: const {
                              'id': 20,
                              'nombre_especifico': 'Docena Escolar Tapa Dura',
                              'unidad': 'Docena',
                              'factor_conversion': 12,
                              'stock_actual': 5,
                              'precio_costo': 90.0,
                              'precio_venta': 125.0,
                              'marca_nombre': 'Standford Profesional',
                            },
                            isDark: false,
                            provider: scannerProv,
                            onConfirm: () {},
                          );
                        },
                        child: const Text('Abrir Comparativo'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Abrir Comparativo'));
            await tester.pumpAndSettle();

            expect(find.text('Control de Variante'), findsOneWidget);
            expect(find.text('GUARDAR DECISIÓN'), findsOneWidget);

            final identityRow = find.text('Identidad del Producto');
            await tester.ensureVisible(identityRow);
            await tester.tap(identityRow);
            await tester.pumpAndSettle();
            expect(find.text('Nombre Específico'), findsOneWidget);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow en ComparativeUpdateModal @ ${viewport.width}x${viewport.height}:\n${errors.join('\n')}',
          );
        },
      );

      testWidgets(
        'InvoiceStagingScreen sin overflow @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          try {
            FlutterError.onError = (d) => errors.add(d.toString());
            final scannerProv = ScannerProvider();
            final variant = _buildSampleVariant();
            final group = _buildSampleGroup(variant);
            scannerProv.setStagingDataForTesting(
              StagingResponse(
                proveedorMatch: MatchResult(
                  estado: 'MATCH_EXACTO',
                  confianza: 95,
                  datos: MatchData(
                    id: 10,
                    nombre: 'Distribuidora Standford del Perú SAC',
                  ),
                ),
                proveedorTexto: 'Distribuidora Standford del Perú SAC',
                montoTotalFactura: 384.0,
                productosAgrupados: [group],
              ),
            );

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                  ChangeNotifierProvider<ThemeProvider>.value(
                    value: _MockThemeProvider(),
                  ),
                  ChangeNotifierProvider<LicenseProvider>.value(
                    value: _MockLicenseProvider(),
                  ),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: _MockInventoryProvider(),
                  ),
                  ChangeNotifierProvider<ScannerProvider>.value(
                    value: scannerProv,
                  ),
                ],
                child: _wrapScaled(
                  InvoiceStagingScreen(
                    autoTriggerTour: false,
                    tourKeys: InvoiceStagingTourKeys(),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));

            expect(find.text('Clasificar y Confirmar'), findsOneWidget);
            expect(find.text('GUARDAR E INGRESAR STOCK'), findsOneWidget);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow en InvoiceStagingScreen @ ${viewport.width}x${viewport.height}:\n${errors.join('\n')}',
          );
        },
      );

      testWidgets(
        'QuickSaleHeader sin overflow @ 1.3x en ${viewport.width.toInt()}x${viewport.height.toInt()}dp',
        (tester) async {
          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          try {
            FlutterError.onError = (d) => errors.add(d.toString());
            final quickProv = QuickSaleProvider();
            quickProv.setClientInfo(
              client: ClientModel(
                id: 7,
                negocioId: 1,
                creadoPorUsuarioId: 1,
                fullName: 'María Fernanda Quispe Mamani',
                phone: '987654321',
                docNumber: '74125896',
                address: 'Av. Universitaria 1234, Los Olivos',
                notes: 'Cliente frecuente escolar',
                saldoAFavor: 45.50,
                registeredDate: '2026-10-01',
              ),
            );

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                  ChangeNotifierProvider<QuickSaleProvider>.value(
                    value: quickProv,
                  ),
                ],
                child: _wrapScaled(
                  const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(12),
                      child: QuickSaleHeader(isGuest: false, isDark: false),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.text('María Fernanda Quispe Mamani'),
              findsAtLeastNWidgets(1),
            );

            // Expandir acordeón y abrir edición in-situ del cliente
            await tester.tap(find.text('María Fernanda Quispe Mamani').first);
            await tester.pumpAndSettle();
            expect(
              find.text('Buscar en Directorio de Clientes'),
              findsOneWidget,
            );

            final editBtn = find.byTooltip('Editar datos del cliente');
            await tester.ensureVisible(editBtn);
            await tester.tap(editBtn);
            await tester.pumpAndSettle();
            expect(find.text('Guardar Cambios del Cliente'), findsOneWidget);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Overflow en QuickSaleHeader @ ${viewport.width}x${viewport.height}:\n${errors.join('\n')}',
          );
        },
      );
    }
  });
}
