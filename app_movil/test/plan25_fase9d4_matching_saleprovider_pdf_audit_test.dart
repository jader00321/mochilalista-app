import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:app_movil/features/analytics/screens/audit_trail_screen.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';

class _MockAuth9D4 extends ChangeNotifier implements AuthProvider {
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Plan 25 9D-4 S.A.C.',
    address: 'Av. Principal 123',
    moneda: 'S/ (Soles)',
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
  String get userName => _user.fullName;

  @override
  String get businessName => _business.commercialName;

  @override
  String get errorMessage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTheme9D4 extends ChangeNotifier implements ThemeProvider {
  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockLicense9D4 extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isActive => true;

  @override
  bool get isPerpetual => false;

  @override
  String get currentPlanName => 'MENSUAL';

  @override
  LicenseModel? get license => null;

  @override
  bool get isUsingByokMode => false;

  @override
  int get remainingAiScans => 50;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory9D4 extends ChangeNotifier implements InventoryProvider {
  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get hasMoreData => false;

  @override
  bool get showStockAlertColors => true;

  @override
  List<InventoryWrapper> get items => const <InventoryWrapper>[];

  @override
  List<Category> get categories => const <Category>[];

  @override
  List<Brand> get brands => const <Brand>[];

  @override
  List<ProviderModel> get providers => const <ProviderModel>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockNotification9D4 extends ChangeNotifier
    implements NotificationProvider {
  @override
  NotificationPreferences get preferences =>
      NotificationPreferences.defaultFor(1);

  @override
  bool get isLoading => false;

  @override
  List<NotificationModel> get notifications => const <NotificationModel>[];

  @override
  int get unreadCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSmartQuotation9D4 extends ChangeNotifier
    implements SmartQuotationProvider {
  @override
  void clearState() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockMatching9D4 extends ChangeNotifier implements MatchingProvider {
  late final List<BundleModel> _bundles = [
    BundleModel(
      id: 77,
      negocioId: 1,
      nombrePaquete: 'Pack Escolar Completo Standford x5',
      descripcion: 'Incluye cuadernos y accesorios con precio promocional',
      precioVentaTotal: 25.00,
      activo: true,
    ),
  ];

  late List<MatchPair> _pairs = [
    MatchPair(
      sourceItem: ExtractedItem(
        id: 1,
        originalText: '2 Cuadernos A4 Rayado',
        fullName: 'Cuaderno A4 Rayado 100H Standford',
        brand: 'Standford',
        quantity: 2,
        unit: 'Unidad',
      ),
      selectedProduct: MatchedProduct(
        productId: 10,
        presentationId: 101,
        fullName: 'Cuaderno A4 Rayado 100H Standford',
        productName: 'Cuaderno A4 Rayado',
        specificName: '100 Hojas',
        brand: 'Standford',
        price: 16.0,
        stock: 25,
        bundleId: 77,
      ),
      status: MatchStatus.auto,
      bundleId: 77,
    ),
    MatchPair(
      sourceItem: ExtractedItem(
        id: 2,
        originalText: '3 Lapiceros Azul Faber Castell',
        fullName: 'Lapicero Azul 031',
        quantity: 3,
      ),
      selectedProduct: MatchedProduct(
        productId: 20,
        presentationId: 201,
        fullName: 'Lapicero Azul 031',
        productName: 'Lapicero Azul 031',
        brand: 'Faber',
        price: 2.50,
        stock: 80,
      ),
      status: MatchStatus.suggestion,
    ),
    MatchPair(
      sourceItem: ExtractedItem(
        id: 3,
        originalText: 'Cartulina Fosforescente',
        fullName: 'Cartulina Fosforescente Pliego',
        quantity: 1,
      ),
      status: MatchStatus.none,
    ),
  ];

  @override
  bool get isLoading => false;

  @override
  bool get isSaving => false;

  @override
  String get errorMessage => '';

  @override
  List<MatchPair> get pairs => _pairs;

  @override
  ExtractedMetadata? get metadata => ExtractedMetadata(
    contextMode: QuotationContextMode.school,
    institutionName: 'I.E. Emblemática Alfonso Ugarte',
    studentName: 'Lucía Fernández',
    gradeLevel: '4to Primaria',
  );

  @override
  ClientModel? get selectedClient => null;

  @override
  bool get hasModifications => true;

  @override
  List<BundleModel> get activeBundles => _bundles;

  @override
  Map<int, List<BundleItemModel>> get bundleItemsCache =>
      const <int, List<BundleItemModel>>{};

  @override
  double get totalNetAmount => _pairs.fold(0.0, (s, p) => s + p.subtotal);

  @override
  double get totalSavingsAmount => 7.00;

  @override
  int get matchedCount => _pairs.where((p) => p.selectedProduct != null).length;

  @override
  Map<int, int> get sharedDemandPerProduct => const <int, int>{};

  @override
  bool get hasStockWarnings => false;

  @override
  bool isProductRepeated(int? presentationId) => false;

  @override
  void updateMetadata({
    QuotationContextMode? mode,
    String? institution,
    String? student,
    String? grade,
    String? phone,
  }) {}

  @override
  void setClient(ClientModel? client) {}

  @override
  void addManualRow() {
    _pairs = [
      ..._pairs,
      MatchPair(
        sourceItem: ExtractedItem(
          id: _pairs.length + 1,
          originalText: 'Manual',
          fullName: 'Manual',
        ),
      ),
    ];
    notifyListeners();
  }

  @override
  void toggleBundleGrouping(int bundleId, bool enabled) {}

  @override
  void unmatchItem(int itemId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

int _countLines(String relativePath) {
  final file = File(relativePath);
  expect(file.existsSync(), isTrue, reason: 'No existe $relativePath');
  return file.readAsLinesSync().length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Plan Maestro 25 - Fase 9D-4: Censo Modular, DRY y Paridad', () {
    test('Todos los archivos modulares 9D-4 cumplen límites estrictos de líneas', () {
      final matchingSubmodules = [
        'lib/features/smart_quotation/screens/matching/matching_flow_and_actions_mixin.dart',
        'lib/features/smart_quotation/screens/matching/matching_header_accordions_mixin.dart',
        'lib/features/smart_quotation/screens/matching/matching_items_list_mixin.dart',
        'lib/features/smart_quotation/screens/matching/matching_item_modals_mixin.dart',
      ];
      final saleSubmodules = [
        'lib/features/smart_quotation/providers/sale/sale_filters_and_metrics_mixin.dart',
        'lib/features/smart_quotation/providers/sale/sale_history_loader_mixin.dart',
        'lib/features/smart_quotation/providers/sale/sale_actions_and_morosidad_mixin.dart',
      ];
      final pdfSubmodules = [
        'lib/features/smart_quotation/utils/pdf/pdf_theme_and_sanitizers.dart',
        'lib/features/smart_quotation/utils/pdf/pdf_header_builder.dart',
        'lib/features/smart_quotation/utils/pdf/pdf_table_builder.dart',
        'lib/features/smart_quotation/utils/pdf/pdf_loan_and_installments_builder.dart',
        'lib/features/smart_quotation/utils/pdf/pdf_totals_and_footer_builder.dart',
      ];
      final auditSubmodules = [
        'lib/features/analytics/screens/audit_trail/audit_trail_summary_and_help_mixin.dart',
        'lib/features/analytics/screens/audit_trail/audit_trail_timeline_mixin.dart',
      ];

      expect(
        _countLines(
          'lib/features/smart_quotation/screens/matching_screen.dart',
        ),
        lessThan(600),
      );
      expect(
        _countLines(
          'lib/features/smart_quotation/providers/sale_provider.dart',
        ),
        lessThan(400),
      );
      expect(
        _countLines('lib/features/smart_quotation/utils/pdf_generator.dart'),
        lessThan(550),
      );
      expect(
        _countLines('lib/features/analytics/screens/audit_trail_screen.dart'),
        lessThan(600),
      );

      for (final path in saleSubmodules) {
        expect(_countLines(path), lessThan(600), reason: '$path >= 600 L');
      }
      for (final path in pdfSubmodules) {
        expect(_countLines(path), lessThan(600), reason: '$path >= 600 L');
      }
      for (final path in [...matchingSubmodules, ...auditSubmodules]) {
        expect(_countLines(path), lessThan(650), reason: '$path >= 650 L');
      }
    });

    test(
      'Adopción DRY (AppDateFormatter, AppFeedbackHelper) y retiro de emojis UI en 9D-4',
      () {
        final matchingAll = [
          'lib/features/smart_quotation/screens/matching_screen.dart',
          'lib/features/smart_quotation/screens/matching/matching_flow_and_actions_mixin.dart',
          'lib/features/smart_quotation/screens/matching/matching_header_accordions_mixin.dart',
          'lib/features/smart_quotation/screens/matching/matching_items_list_mixin.dart',
          'lib/features/smart_quotation/screens/matching/matching_item_modals_mixin.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');

        expect(matchingAll.contains('AppFeedbackHelper'), isTrue);
        expect(matchingAll.contains('⚠️ Problemas de Stock'), isFalse);
        expect(matchingAll.contains('✨ Agrupados en'), isFalse);

        final saleAll = [
          'lib/features/smart_quotation/providers/sale_provider.dart',
          'lib/features/smart_quotation/providers/sale/sale_history_loader_mixin.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');
        expect(saleAll.contains('AppDateFormatter.'), isTrue);
        expect(saleAll.contains("DateFormat("), isFalse);

        final pdfAll = [
          'lib/features/smart_quotation/utils/pdf_generator.dart',
          'lib/features/smart_quotation/utils/pdf/pdf_header_builder.dart',
          'lib/features/smart_quotation/utils/pdf/pdf_totals_and_footer_builder.dart',
        ].map((p) => File(p).readAsStringSync()).join('\n');
        expect(pdfAll.contains('AppDateFormatter.'), isTrue);
        expect(pdfAll.contains("DateFormat("), isFalse);
      },
    );

    test(
      'SaleProvider mantiene instancia única ChangeNotifier, getters y filtros reactivos',
      () {
        final provider = SaleProvider();
        expect(provider, isA<ChangeNotifier>());
        expect(provider.isLoading, isFalse);
        expect(provider.currentTab, 'todas');
        expect(provider.activeQuickFilter, 'seis_meses');
        expect(provider.financialStatus, 'todos');
        expect(provider.todaySalesTotal, 0.0);
        expect(provider.todaySalesCount, 0);

        int notifications = 0;
        provider.addListener(() => notifications++);

        provider.setSearchQuery('Cuaderno');
        expect(provider.searchQuery, 'Cuaderno');
        provider.setFinancialFilter('con_deuda');
        expect(provider.financialStatus, 'con_deuda');
        provider.setSort('monto_total', 'asc');
        expect(provider.currentSortBy, 'monto_total');
        expect(provider.currentOrder, 'asc');
        provider.updateSalePaymentInMaster(
          saleId: 999,
          newPaidAmount: 50.0,
          newPaymentStatus: 'pendiente',
        );
        provider.resetFilters();
        expect(provider.searchQuery, '');
        expect(provider.financialStatus, 'todos');
        expect(notifications, greaterThanOrEqualTo(4));

        provider.dispose();
      },
    );

    test(
      'PdfGenerator genera documentos A4, Ticket 80mm y Préstamo con firma %PDF- válida',
      () async {
        expect(PdfGenerator.isInternalDraftCode('Venta #000123'), isTrue);
        expect(PdfGenerator.isInternalDraftCode('María Morales'), isFalse);
        expect(
          PdfGenerator.cleanClientDisplayName('Carlos Pérez #12-001 (2)'),
          'Carlos Pérez',
        );
        expect(
          PdfGenerator.stripUnsupportedEmojis('Lista Escolar ✨📚 Áéíóú Ñ'),
          'Lista Escolar Áéíóú Ñ',
        );

        final owner = UserModel(
          id: 1,
          fullName: 'Julio Propietario',
          phone: '999888777',
          isActive: true,
          business: BusinessModel(
            id: 1,
            commercialName: 'Librería Central SAC',
            ruc: '20123456789',
            address: 'Jr. Lima 456',
            paymentInfo: 'Yape 999888777 / BCP 191-123456',
          ),
        );

        final quotation = SmartQuotationModel(
          id: 42,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientName: 'María Morales',
          institutionName: 'Colegio San Martín',
          gradeLevel: '3ro Primaria',
          notas: 'Entrega en portería',
          totalAmount: 42.50,
          totalSavings: 7.50,
          status: 'READY',
          type: 'ai_scan',
          createdAt: '2026-11-26T10:30:00',
          items: [
            QuotationItem(
              id: 1,
              productName: 'Pack Escolar 2026',
              salesUnit: 'Pack',
              quantity: 1,
              unitPriceApplied: 25.00,
              originalUnitPrice: 32.50,
              bundleId: 77,
            ),
            QuotationItem(
              id: 2,
              productName: 'Lapicero Azul',
              brandName: 'Faber',
              salesUnit: 'Unidad',
              quantity: 7,
              unitPriceApplied: 2.50,
              originalUnitPrice: 2.50,
            ),
          ],
        );

        final a4Bytes = await PdfGenerator.generatePdf(
          quotation: quotation,
          ownerInfo: owner,
          config: PdfConfig(
            theme: PdfTheme.indigo,
            pageSize: PdfPageSize.a4,
            layoutTemplate: PdfLayoutTemplate.corporateFramed,
            showImages: false,
            showPaymentAccounts: true,
            footerNote: 'Cotización válida por 7 días.',
          ),
        );
        expect(a4Bytes, isNotEmpty);
        expect(String.fromCharCodes(a4Bytes.sublist(0, 5)), '%PDF-');

        final ticketBytes = await PdfGenerator.generatePdf(
          quotation: quotation,
          ownerInfo: owner,
          config: PdfConfig(
            theme: PdfTheme.emerald,
            pageSize: PdfPageSize.ticket80,
            showImages: false,
          ),
          saleData: {
            'id': 98,
            'origen_venta': 'smart_quotation',
            'monto_total': 42.50,
            'monto_pagado': 20.00,
            'descuento_aplicado': 7.50,
            'metodo_pago': 'yape',
            'estado_pago': 'pendiente',
            'fecha_venta': '2026-11-26T10:30:00',
            'cliente_nombre': 'María Morales',
          },
        );
        expect(ticketBytes, isNotEmpty);
        expect(String.fromCharCodes(ticketBytes.sublist(0, 5)), '%PDF-');

        final loanBytes = await PdfGenerator.generatePdf(
          quotation: quotation,
          ownerInfo: owner,
          config: PdfConfig(
            theme: PdfTheme.dark,
            pageSize: PdfPageSize.a4,
            showImages: false,
            showInstallments: true,
          ),
          saleData: {
            'id': 120,
            'origen_venta': 'prestamo_personal',
            'monto_total': 615.00,
            'mora_total': 15.00,
            'abono_inicial': 0.0,
            'porcentaje_interes': 20.0,
            'monto_pagado': 100.00,
            'fecha_venta': '2026-11-26T10:30:00',
            'cliente_nombre': 'Luis Torres',
            'cuotas': [
              {
                'numero_cuota': 1,
                'monto': 315.0,
                'monto_original': 300.0,
                'mora_monto': 15.0,
                'monto_pagado': 100.0,
                'fecha_vencimiento': '2026-11-20',
                'estado': 'pendiente',
              },
            ],
          },
        );
        expect(loanBytes, isNotEmpty);
        expect(String.fromCharCodes(loanBytes.sublist(0, 5)), '%PDF-');
      },
    );
  });

  group('Plan Maestro 25 - Fase 9D-4: Responsividad 0px Overflow @ 1.3x', () {
    const viewports = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

    Widget wrapResponsive({required Size size, required Widget child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _MockAuth9D4()),
          ChangeNotifierProvider<ThemeProvider>.value(value: _MockTheme9D4()),
          ChangeNotifierProvider<LicenseProvider>.value(
            value: _MockLicense9D4(),
          ),
          ChangeNotifierProvider<InventoryProvider>.value(
            value: _MockInventory9D4(),
          ),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: _MockNotification9D4(),
          ),
          ChangeNotifierProvider<MatchingProvider>.value(
            value: _MockMatching9D4(),
          ),
          ChangeNotifierProvider<SmartQuotationProvider>.value(
            value: _MockSmartQuotation9D4(),
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(1.3),
          ),
          child: MaterialApp(home: child),
        ),
      );
    }

    for (final vp in viewports) {
      testWidgets(
        'MatchingScreen (con bundle, ítems emparejados y acordeones) 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await _setTestViewport(tester, vp);
          addTearDown(() => _resetTestViewport(tester));

          final errors = <FlutterErrorDetails>[];
          final prevHandler = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(
              wrapResponsive(
                size: vp,
                child: MatchingScreen(
                  extractedItems: [
                    ExtractedItem(
                      id: 1,
                      originalText: '2 Cuadernos A4',
                      fullName: 'Cuaderno A4 Rayado',
                    ),
                  ],
                  autoTriggerTour: false,
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            final bundleFinder = find.textContaining('Agrupados en');
            if (bundleFinder.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                bundleFinder,
                100.0,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pump();
            }
          } finally {
            FlutterError.onError = prevHandler;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Errores en MatchingScreen @ ${vp.width.toInt()}x${vp.height.toInt()}: ${errors.map((e) => e.exceptionAsString()).join(' | ')}',
          );
          expect(find.byType(MatchingScreen), findsOneWidget);
          expect(find.textContaining('Agrupados en'), findsOneWidget);
        },
      );

      testWidgets(
        'AuditTrailScreen completo 0px Overflow en ${vp.width.toInt()}x${vp.height.toInt()}dp @ 1.3x',
        (tester) async {
          await _setTestViewport(tester, vp);
          addTearDown(() => _resetTestViewport(tester));

          final errors = <FlutterErrorDetails>[];
          final prevHandler = FlutterError.onError;
          FlutterError.onError = errors.add;
          try {
            await tester.pumpWidget(
              wrapResponsive(
                size: vp,
                child: const AuditTrailScreen(
                  presentationId: 1,
                  productId: 10,
                  productName:
                      'Cuaderno A4 Rayado Universitario 100H Standford',
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            if (vp.width == 320) {
              ScaffoldMessenger.of(
                tester.element(find.byType(AuditTrailScreen)),
              ).clearSnackBars();
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 250));
              final helpBtn = find.byTooltip('Información de Trazabilidad');
              await tester.ensureVisible(helpBtn);
              await tester.tap(helpBtn);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 350));
            }
          } finally {
            FlutterError.onError = prevHandler;
          }

          expect(
            errors,
            isEmpty,
            reason:
                'Errores en AuditTrailScreen @ ${vp.width.toInt()}x${vp.height.toInt()}: ${errors.map((e) => e.exceptionAsString()).join(' | ')}',
          );
          expect(find.text('Trazabilidad'), findsOneWidget);
          expect(find.text('Stock Actual'), findsOneWidget);
          if (vp.width == 320) {
            expect(find.text('Trazabilidad de Stock (Kardex)'), findsWidgets);
          }
        },
      );
    }
  });
}
