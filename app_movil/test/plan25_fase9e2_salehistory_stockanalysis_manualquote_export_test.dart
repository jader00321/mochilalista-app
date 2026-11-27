import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/widgets/export_options_modal.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/widgets/notifications/stock_analysis_modal.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';

String _resolveAppMovilRoot() {
  final dir = Directory.current.path.replaceAll('\\', '/');
  if (dir.endsWith('/app_movil')) {
    return dir;
  }
  return '$dir/app_movil';
}

int _countLines(String relativePath) {
  final file = File('${_resolveAppMovilRoot()}/$relativePath');
  if (!file.existsSync()) {
    fail('Archivo requerido no existe: $relativePath');
  }
  return file.readAsLinesSync().length;
}

class _MockAuth9E2 extends ChangeNotifier implements AuthProvider {
  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Plan 25 9E-2',
    address: 'Av. Los Próceres 180',
    moneda: 'PEN',
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Julio Administrador',
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
  String get userName => 'Julio Administrador';

  @override
  String get businessName => 'Librería Plan 25 9E-2';

  @override
  String get errorMessage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTheme9E2 extends ChangeNotifier implements ThemeProvider {
  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicense9E2 extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isPerpetual => true;

  @override
  bool get isActive => true;

  @override
  String get currentPlanName => 'PERPETUA';

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory9E2 extends ChangeNotifier implements InventoryProvider {
  final Product _product;

  _MockInventory9E2(this._product);

  @override
  int? get negocioId => 1;

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
  Future<Product?> fetchProductById(int productId) async => _product;

  @override
  Future<Product?> getFullProductWithFallback(int productId) async => _product;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockNotification9E2 extends ChangeNotifier
    implements NotificationProvider {
  @override
  int get unreadCount => 0;

  @override
  List<NotificationModel> get notifications => const <NotificationModel>[];

  @override
  Future<void> fetchNotifications() async {}

  @override
  Future<bool> resolveProductStockNotification(int productId) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockWorkbench9E2 extends ChangeNotifier implements WorkbenchProvider {
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
  ValidationResult? getValidationFor(int quotationId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSmartQuotation9E2 extends ChangeNotifier
    implements SmartQuotationProvider {
  @override
  bool get hasManualDraft => false;

  @override
  Future<String> generateDynamicQuoteName(
    ClientModel? selectedClient,
    String typedName, {
    String? schoolName,
    String? gradeLevel,
    bool isClientRole = false,
    String? clientUserName,
    required String type,
    int? sequentialNumber,
  }) async => 'Lista Escolar Primaria';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockQuickSale9E2 extends ChangeNotifier implements QuickSaleProvider {
  bool _hideProfits = false;

  @override
  bool get hideProfits => _hideProfits;

  @override
  bool get isEmpty => true;

  @override
  Future<void> toggleHideProfits() async {
    _hideProfits = !_hideProfits;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockPromotion9E2 extends ChangeNotifier implements PromotionProvider {
  @override
  List<BundleModel> get bundles => const <BundleModel>[];

  @override
  double calculateBundleCost(int bundleId) => 0.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSaleProvider9E2 extends ChangeNotifier implements SaleProvider {
  final Map<String, dynamic> _saleDetail;

  _MockSaleProvider9E2(this._saleDetail);

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

class _MockTracking9E2 extends ChangeNotifier implements TrackingProvider {
  @override
  int get pendingRewardsCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Product _sampleProduct9E2() {
  return Product(
    id: 101,
    nombre: 'Cuaderno A4 Cuadriculado Pasta Dura 100 Hojas',
    categoriaId: 1,
    modoStock: 'INDEPENDIENTE',
    presentaciones: [
      ProductPresentation(
        id: 201,
        nombreEspecifico: 'Unidad Escolar',
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        precioVentaFinal: 8.50,
        costoUnitarioCalculado: 5.20,
        factorGananciaVenta: 0.63,
        stockActual: 4,
        stockAlerta: 6,
        esDefault: true,
        activo: true,
      ),
      ProductPresentation(
        id: 202,
        nombreEspecifico: 'Docena Mayorista',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        precioVentaFinal: 92.00,
        costoUnitarioCalculado: 60.00,
        factorGananciaVenta: 0.53,
        stockActual: 24,
        stockAlerta: 12,
        esDefault: false,
        activo: true,
      ),
    ],
  );
}

Map<String, dynamic> _sampleSaleDetail9E2() {
  return {
    'id': 88,
    'numero_secuencial': 88,
    'cotizacion_id': 305,
    'cliente_id': 15,
    'cliente_nombre': 'María Fernanda Quispe Mamani',
    'origen_venta': 'manual',
    'estado_pago': 'pagado',
    'estado_entrega': 'entregado',
    'metodo_pago': 'yape_plin',
    'monto_total': 184.50,
    'monto_pagado': 184.50,
    'fecha_venta': '2026-11-25T15:45:00.000Z',
    'is_archived': 0,
    'cliente_notas': 'Solicita entrega en horario de tarde.',
    'cotizacion': {
      'client_name': 'Lista Escolar 5to Primaria',
      'institution_name': 'I.E. Nuestra Señora de Guadalupe',
      'grade_level': '5to Primaria',
      'notas': 'Etiquetar cuadernos en portada',
    },
    'items': [
      {
        'product_name': 'Cuaderno A4 Cuadriculado Pasta Dura 100 Hojas',
        'brand_name': 'Justus',
        'specific_name': '100 hojas bond 75g',
        'sales_unit': 'Unidad',
        'quantity': 6,
        'unit_price_applied': 8.50,
        'original_unit_price': 9.50,
      },
      {
        'product_name': 'Caja de Plumones Gruesos x12 Lavables',
        'brand_name': 'Faber-Castell',
        'specific_name': 'Estuche rígido',
        'sales_unit': 'Caja',
        'quantity': 5,
        'unit_price_applied': 26.70,
        'original_unit_price': 29.00,
      },
    ],
  };
}

Widget _wrap9E2({
  required Widget child,
  required Size viewport,
  Product? product,
  Map<String, dynamic>? saleDetail,
}) {
  final prod = product ?? _sampleProduct9E2();
  final sale = saleDetail ?? _sampleSaleDetail9E2();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: _MockAuth9E2()),
      ChangeNotifierProvider<ThemeProvider>.value(value: _MockTheme9E2()),
      ChangeNotifierProvider<LicenseProvider>.value(value: _MockLicense9E2()),
      ChangeNotifierProvider<InventoryProvider>.value(
        value: _MockInventory9E2(prod),
      ),
      ChangeNotifierProvider<NotificationProvider>.value(
        value: _MockNotification9E2(),
      ),
      ChangeNotifierProvider<WorkbenchProvider>.value(
        value: _MockWorkbench9E2(),
      ),
      ChangeNotifierProvider<SmartQuotationProvider>.value(
        value: _MockSmartQuotation9E2(),
      ),
      ChangeNotifierProvider<QuickSaleProvider>.value(
        value: _MockQuickSale9E2(),
      ),
      ChangeNotifierProvider<PromotionProvider>.value(
        value: _MockPromotion9E2(),
      ),
      ChangeNotifierProvider<SaleProvider>.value(
        value: _MockSaleProvider9E2(sale),
      ),
      ChangeNotifierProvider<TrackingProvider>.value(value: _MockTracking9E2()),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    SharedPreferences.setMockInitialValues({});
  });

  group('Plan 25 Fase 9E-2: Censo Post-Formato, Paridad y DRY', () {
    test(
      'Los 15 archivos modulares de 9E-2 cumplen topes (<550 coord / <600 submódulos) y reducen 800-999L a 13',
      () {
        const expectedLimits = <String, int>{
          'lib/features/smart_quotation/screens/sale_history_detail_screen.dart':
              549,
          'lib/features/smart_quotation/screens/sale_history_detail/sale_history_detail_actions_part.dart':
              599,
          'lib/features/smart_quotation/screens/sale_history_detail/sale_history_detail_dialogs_and_notes_part.dart':
              599,
          'lib/features/profile/widgets/notifications/stock_analysis_modal.dart':
              549,
          'lib/features/profile/widgets/notifications/stock_analysis/stock_analysis_actions_part.dart':
              599,
          'lib/features/profile/widgets/notifications/stock_analysis/stock_analysis_diagnostic_part.dart':
              599,
          'lib/features/profile/widgets/notifications/stock_analysis/stock_analysis_restock_and_kardex_part.dart':
              599,
          'lib/features/smart_quotation/screens/manual_quotation_screen.dart':
              549,
          'lib/features/smart_quotation/screens/manual_quotation/manual_quotation_actions_and_tours_part.dart':
              599,
          'lib/features/smart_quotation/screens/manual_quotation/manual_quotation_appbar_and_headers_part.dart':
              599,
          'lib/features/smart_quotation/screens/manual_quotation/manual_quotation_body_and_items_part.dart':
              599,
          'lib/core/widgets/export_options_modal.dart': 549,
          'lib/core/widgets/export_options/export_options_cards_part.dart': 599,
          'lib/core/widgets/export_options/export_options_combinable_part.dart':
              599,
          'lib/core/widgets/export_options/export_options_legacy_part.dart':
              599,
        };

        for (final entry in expectedLimits.entries) {
          final lines = _countLines(entry.key);
          expect(
            lines,
            lessThanOrEqualTo(entry.value),
            reason:
                'Archivo ${entry.key} tiene $lines L > tope ${entry.value} L',
          );
        }

        final libRoot = Directory('${_resolveAppMovilRoot()}/lib');
        final filesGe1000 = <String>[];
        final files800To999 = <String>[];

        for (final entity in libRoot.listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            final lineCount = entity.readAsLinesSync().length;
            final rel = entity.path
                .replaceAll('\\', '/')
                .split('/app_movil/')
                .last;
            if (lineCount >= 1000) {
              filesGe1000.add('$rel ($lineCount)');
            } else if (lineCount >= 800) {
              files800To999.add('$rel ($lineCount)');
            }
          }
        }

        expect(
          filesGe1000,
          isEmpty,
          reason:
              'Se esperaba FILES_GE_1000L_IN_APP_MOVIL=0, encontrados: $filesGe1000',
        );
        expect(
          files800To999.length,
          lessThanOrEqualTo(13),
          reason:
              'Se esperaba FILES_800_TO_999L_IN_APP_MOVIL <= 13 tras 9E-2, lista: $files800To999',
        );
        for (final closed9e2 in const [
          'lib/features/smart_quotation/screens/sale_history_detail_screen.dart',
          'lib/features/profile/widgets/notifications/stock_analysis_modal.dart',
          'lib/features/smart_quotation/screens/manual_quotation_screen.dart',
          'lib/core/widgets/export_options_modal.dart',
        ]) {
          expect(
            files800To999.any((entry) => entry.startsWith(closed9e2)),
            isFalse,
            reason:
                'El archivo $closed9e2 cerrado en 9E-2 no puede permanecer >= 800 L',
          );
        }
      },
    );

    test(
      'Reutilización DRY, paridad de símbolos y cero shrinkWrap innecesario en 9E-2',
      () {
        final root = _resolveAppMovilRoot();

        // Paridad de símbolos públicos exportados directamente
        expect(SaleHistoryDetailScreen, isNotNull);
        expect(StockAnalysisModal, isNotNull);
        expect(ManualQuotationScreen, isNotNull);
        expect(ExportOptionsModal, isNotNull);
        expect(ExportOption, isNotNull);
        expect(ExportFilterSelection, isNotNull);

        final saleHistorySrc = File(
          '$root/lib/features/smart_quotation/screens/sale_history_detail_screen.dart',
        ).readAsStringSync();
        expect(saleHistorySrc.contains("package:intl/intl.dart"), isFalse);
        expect(saleHistorySrc.contains('AppDateFormatter.'), isTrue);
        expect(saleHistorySrc.contains('AppFeedbackHelper.'), isTrue);

        final stockAnalysisSrc = [
          '$root/lib/features/profile/widgets/notifications/stock_analysis_modal.dart',
          '$root/lib/features/profile/widgets/notifications/stock_analysis/stock_analysis_actions_part.dart',
          '$root/lib/features/profile/widgets/notifications/stock_analysis/stock_analysis_diagnostic_part.dart',
          '$root/lib/features/profile/widgets/notifications/stock_analysis/stock_analysis_restock_and_kardex_part.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');
        expect(stockAnalysisSrc.contains('shrinkWrap: true'), isFalse);
        expect(stockAnalysisSrc.contains('AppCurrency.format('), isTrue);
        expect(stockAnalysisSrc.contains('AppDateFormatter.'), isTrue);
      },
    );
  });

  group('Plan 25 Fase 9E-2: 0px Overflow @ 1.3x en 320dp, 360dp y 412dp', () {
    final viewports = <Size>[
      const Size(320, 568),
      const Size(360, 640),
      const Size(412, 915),
    ];

    for (final vp in viewports) {
      testWidgets(
        'SaleHistoryDetailScreen sin overflow @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          try {
            await tester.pumpWidget(
              _wrap9E2(
                viewport: vp,
                child: const SaleHistoryDetailScreen(
                  saleId: 88,
                  autoTriggerTour: false,
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));

            expect(find.text('Recibo #88'), findsOneWidget);
            expect(errors, isEmpty);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );

      testWidgets(
        'StockAnalysisModal con Kardex (SliverList) sin overflow @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          final notif = NotificationModel(
            id: 501,
            title: 'Stock Bajo • Cuaderno A4',
            message: 'Quedan 4 unidades en inventario',
            type: 'alerta',
            prioridad: 'Alta',
            nivelPrioridad: 'preventiva',
            objetoRelacionadoTipo: 'producto',
            objetoRelacionadoId: 101,
            isRead: false,
            createdAt: DateTime(2026, 11, 25, 10, 0),
          );

          final ledgerRows = [
            {
              'tipo_transaccion': 'VENTA',
              'cantidad': 3,
              'fecha_registro': '2026-11-25T12:00:00.000Z',
            },
            {
              'tipo_transaccion': 'INGRESO',
              'cantidad': 12,
              'fecha_registro': '2026-11-24T09:30:00.000Z',
            },
          ];

          try {
            await tester.pumpWidget(
              _wrap9E2(
                viewport: vp,
                child: Scaffold(
                  body: StockAnalysisModal(
                    notif: notif,
                    product: _sampleProduct9E2(),
                    isDark: false,
                    initialLedger: ledgerRows,
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            expect(find.text('Análisis de Stock'), findsOneWidget);
            expect(find.text('Abastecimiento Rápido'), findsOneWidget);
            expect(errors, isEmpty);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );

      testWidgets(
        'ManualQuotationScreen con ítems sin overflow @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          final initialItems = [
            MatchedProduct(
              productId: 101,
              presentationId: 201,
              fullName: 'Cuaderno A4 Cuadriculado Pasta Dura',
              productName: 'Cuaderno A4 Cuadriculado',
              specificName: '100 hojas',
              unit: 'Unidad',
              price: 8.50,
              stock: 20,
            ),
          ];

          try {
            await tester.pumpWidget(
              _wrap9E2(
                viewport: vp,
                child: ManualQuotationScreen(initialItems: initialItems),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Nueva Cotización'), findsOneWidget);
            expect(find.text('Añadir Ítem'), findsOneWidget);
            expect(errors, isEmpty);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );

      testWidgets(
        'ExportOptionsModal (Combinable y Legacy) sin overflow @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          try {
            await tester.pumpWidget(
              _wrap9E2(
                viewport: vp,
                child: Scaffold(
                  key: const ValueKey('combinable_export_scaffold'),
                  body: ExportOptionsModal(
                    key: const ValueKey('combinable_export_modal'),
                    isCombinable: true,
                    initialTab: 'smart_quotation',
                    initialFinancialFilter: 'todos',
                    activePeriodLabel: 'Noviembre 2026',
                    onCountRequest: (_) async => 18,
                    onExportCombinable: (_) {},
                    isDark: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Opciones de Exportación'), findsOneWidget);
            expect(find.text('Generar y Descargar Reporte'), findsOneWidget);

            // Tap en "Por Método" tras desplazarlo a la vista para mostrar chips de métodos de pago
            await tester.ensureVisible(find.text('Por Método'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Por Método'));
            await tester.pumpAndSettle();
            expect(find.text('Yape / Plin'), findsOneWidget);

            // Probar también modo Legacy Step 1 y Step 2 en el mismo viewport
            await tester.pumpWidget(
              _wrap9E2(
                viewport: vp,
                child: Scaffold(
                  key: const ValueKey('legacy_export_scaffold'),
                  body: ExportOptionsModal(
                    key: const ValueKey('legacy_export_modal'),
                    isDark: false,
                    options: const [
                      ExportOption(
                        id: 'current',
                        title: 'Vista Actual Filtrada',
                        description: 'Solo listas visibles en pantalla',
                        icon: Icons.filter_list,
                        count: 14,
                      ),
                      ExportOption(
                        id: 'all',
                        title: 'Catálogo Completo',
                        description: 'Todas las listas registradas',
                        icon: Icons.analytics,
                        count: 42,
                      ),
                    ],
                    onExportLegacy: (_, __, ___) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Vista Actual Filtrada'), findsOneWidget);
            expect(find.text('14 listas'), findsOneWidget);

            await tester.ensureVisible(find.text('Vista Actual Filtrada'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Vista Actual Filtrada'));
            await tester.pumpAndSettle();
            expect(find.text('Formato del Reporte'), findsOneWidget);
            expect(find.text('Generar y Descargar'), findsOneWidget);
            expect(errors, isEmpty);
          } finally {
            FlutterError.onError = originalOnError;
          }
        },
      );
    }
  });
}
