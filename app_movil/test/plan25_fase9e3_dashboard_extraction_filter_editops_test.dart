import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/widgets/filter_drawer.dart';
import 'package:app_movil/core/widgets/home/dashboard_header.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_operations.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/extraction_result_screen.dart';

const List<int> _kTransparentPng1x1 = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

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
    fail('Archivo modular requerido no existe: $relativePath');
  }
  return file.readAsLinesSync().length;
}

class _MockAuth9E3 extends ChangeNotifier implements AuthProvider {
  final String? logoPath;

  _MockAuth9E3({this.logoPath});

  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería & Bazar MochilaLista Central SAC',
    address: 'Jr. Ucayali 342',
    moneda: 'PEN',
    logoUrl: logoPath,
  );

  late final UserModel _user = UserModel(
    id: 1,
    fullName: 'Julio César Mendoza',
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
  bool get isCommunityClient => false;

  @override
  String get userName => 'Julio César Mendoza';

  @override
  String get businessName => _business.commercialName;

  @override
  Future<bool> refreshActiveUser() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockNotification9E3 extends ChangeNotifier
    implements NotificationProvider {
  @override
  int get unreadCount => 12;

  @override
  List<NotificationModel> get notifications => const <NotificationModel>[];

  @override
  Future<void> fetchNotifications() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockWorkbench9E3 extends ChangeNotifier implements WorkbenchProvider {
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
  Future<void> loadDashboard({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSale9E3 extends ChangeNotifier implements SaleProvider {
  @override
  bool get isLoading => false;

  @override
  List<SaleModel> get salesHistory => const <SaleModel>[];

  @override
  double get todaySalesTotal => 1845.50;

  @override
  int get todaySalesCount => 14;

  @override
  double? get currentMonthSalesTotal => 28940.00;

  @override
  Future<void> silentRefresh() async {}

  @override
  Future<void> loadSalesHistory({bool silent = false}) async {}

  @override
  Future<void> loadCurrentMonthMargin() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockTracking9E3 extends ChangeNotifier implements TrackingProvider {
  @override
  Future<void> loadClientCount() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockSmartQuotation9E3 extends ChangeNotifier
    implements SmartQuotationProvider {
  @override
  final File? currentImage;

  @override
  ExtractedMetadata? metadata;

  @override
  final List<ExtractedItem> items;

  _MockSmartQuotation9E3({
    required this.currentImage,
    required this.metadata,
    required this.items,
  });

  @override
  String get fullExtractedText => items.map((e) => e.originalText).join('\n');

  @override
  void addItem() {
    items.add(
      ExtractedItem(
        id: items.length + 1,
        originalText: 'Agregado manual',
        fullName: '',
        quantity: 1,
        unit: 'Unidad',
      ),
    );
    notifyListeners();
  }

  @override
  void deleteItem(int id) {
    items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  @override
  void updateItem(
    int id, {
    String? fullName,
    String? brand,
    int? quantity,
    String? unit,
    String? notes,
  }) {
    final index = items.indexWhere((i) => i.id == id);
    if (index != -1) {
      if (fullName != null) {
        items[index].fullName = fullName;
      }
      if (brand != null) {
        items[index].brand = brand;
      }
      if (quantity != null) {
        items[index].quantity = quantity;
      }
      if (unit != null) {
        items[index].unit = unit;
      }
      if (notes != null) {
        items[index].notes = notes;
      }
      notifyListeners();
    }
  }

  @override
  void updateMetadata({
    String? institution,
    String? student,
    String? grade,
    QuotationContextMode? mode,
    String? phone,
  }) {
    metadata ??= ExtractedMetadata();
    if (mode != null) {
      metadata!.contextMode = mode;
    }
    if (institution != null) {
      metadata!.businessOrInstitutionName = institution;
    }
    if (student != null) {
      metadata!.clientOrContactName = student;
    }
    if (grade != null) {
      metadata!.referenceNotes = grade;
    }
    if (phone != null) {
      metadata!.phone = phone;
    }
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MockInventory9E3 extends ChangeNotifier implements InventoryProvider {
  @override
  final List<Category> categories = [
    Category(id: 1, nombre: 'Útiles Escolares y Oficina Corporativa Premium'),
    Category(id: 2, nombre: 'Arte y Manualidades'),
  ];

  @override
  final List<Brand> brands = [
    Brand(id: 10, nombre: 'Faber-Castell'),
    Brand(id: 11, nombre: 'Artesco'),
  ];

  @override
  final List<ProviderModel> providers = [
    ProviderModel(id: 20, nombreEmpresa: 'Distribuidora Pacífico SAC'),
    ProviderModel(id: 21, nombreEmpresa: 'Importadora Los Andes EIRL'),
  ];

  @override
  bool get hasOrphanCategories => true;

  @override
  bool get hasOrphanBrands => true;

  @override
  List<int> get activeCategoryIds => const [1];

  @override
  List<int> get activeBrandIds => const [];

  @override
  List<int> get activeProviderIds => const [];

  @override
  String? get activeState => null;

  @override
  double? get activeMinPrice => 15.0;

  @override
  double? get activeMaxPrice => 320.0;

  @override
  int? get activeMinStock => 5;

  @override
  int? get activeMaxStock => 75;

  @override
  bool get activeHasOffer => true;

  @override
  bool get activeOnlyDefaults => true;

  @override
  int get totalPresentationsCount => 42;

  @override
  Future<void> loadMasterData({bool showAll = true}) async {}

  @override
  Future<int> countFilteredItems(Map<String, dynamic> filters) async => 17;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _wrapViewport9E3({required Size viewport, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(
      size: viewport,
      textScaler: const TextScaler.linear(1.3),
    ),
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 25 Fase 9E-3 — Certificación Estructural, Paridad y DRY', () {
    test(
      'Límites de líneas post-formato, cero D-MOV-06/intl/emojis crudos y censo monótono <= 9',
      () {
        final root = _resolveAppMovilRoot();

        const coordinators = <String, int>{
          'lib/core/widgets/home/dashboard_header.dart': 549,
          'lib/features/smart_quotation/screens/extraction_result_screen.dart':
              549,
          'lib/core/widgets/filter_drawer.dart': 549,
          'lib/features/catalog/widgets/edit/product_edit/product_edit_operations.dart':
              499,
        };

        for (final entry in coordinators.entries) {
          final lines = _countLines(entry.key);
          expect(
            lines,
            lessThanOrEqualTo(entry.value),
            reason:
                '${entry.key} excedió el límite de ${entry.value} L ($lines L).',
          );
        }

        const subModules = <String, int>{
          'lib/core/widgets/home/dashboard_header/dashboard_header_profile_bar_part.dart':
              599,
          'lib/core/widgets/home/dashboard_header/dashboard_header_kpi_carousel_part.dart':
              599,
          'lib/features/smart_quotation/screens/extraction_result/extraction_result_metadata_and_list_part.dart':
              599,
          'lib/features/smart_quotation/screens/extraction_result/extraction_result_cards_part.dart':
              599,
          'lib/core/widgets/filter_drawer/filter_drawer_sections_part.dart':
              599,
          'lib/core/widgets/filter_drawer/filter_drawer_controls_part.dart':
              599,
          'lib/features/catalog/widgets/edit/product_edit/operations/product_edit_load_and_list_part.dart':
              549,
          'lib/features/catalog/widgets/edit/product_edit/operations/product_edit_leftover_and_cut_part.dart':
              549,
          'lib/features/catalog/widgets/edit/product_edit/operations/product_edit_save_part.dart':
              549,
        };

        for (final entry in subModules.entries) {
          final lines = _countLines(entry.key);
          expect(
            lines,
            lessThanOrEqualTo(entry.value),
            reason:
                '${entry.key} excedió el límite de ${entry.value} L ($lines L).',
          );
        }

        // Verificar cierre D-MOV-06 y retiro de intl muerto en dashboard_header/
        final headerFiles = [
          'lib/core/widgets/home/dashboard_header.dart',
          'lib/core/widgets/home/dashboard_header/dashboard_header_profile_bar_part.dart',
          'lib/core/widgets/home/dashboard_header/dashboard_header_kpi_carousel_part.dart',
        ];
        for (final rel in headerFiles) {
          final content = File('$root/$rel').readAsStringSync();
          expect(content.contains('existsSync'), isFalse, reason: rel);
          expect(content.contains('Image.file('), isFalse, reason: rel);
          expect(content.contains('Image.network('), isFalse, reason: rel);
          expect(content.contains("import 'dart:io';"), isFalse, reason: rel);
          expect(
            content.contains('package:intl/intl.dart'),
            isFalse,
            reason: rel,
          );
        }

        final profilePart = File(
          '$root/lib/core/widgets/home/dashboard_header/dashboard_header_profile_bar_part.dart',
        ).readAsStringSync();
        expect(profilePart.contains('UniversalImage('), isTrue);

        // Verificar DRY y ausencia de shrinkWrap / emojis crudos UI en los 13 módulos
        final all9E3Files = [...coordinators.keys, ...subModules.keys];
        const forbiddenEmojis = ['🔥', '🔍', '📋', '⭐', '✅', '❌', '⚠️'];
        for (final rel in all9E3Files) {
          final content = File('$root/$rel').readAsStringSync();
          expect(content.contains('shrinkWrap: true'), isFalse, reason: rel);
          for (final emoji in forbiddenEmojis) {
            expect(content.contains(emoji), isFalse, reason: '$rel -> $emoji');
          }
        }

        final filterSections = File(
          '$root/lib/core/widgets/filter_drawer/filter_drawer_sections_part.dart',
        ).readAsStringSync();
        expect(filterSections.contains('AppCurrency.format('), isTrue);

        final extractionScreen = File(
          '$root/lib/features/smart_quotation/screens/extraction_result_screen.dart',
        ).readAsStringSync();
        expect(extractionScreen.contains('AppFeedbackHelper.'), isTrue);

        // Censo global app_movil/lib/: 0 >= 1000 L y <= 9 en 800..999 L
        final libDir = Directory('$root/lib');
        final allDart = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        final filesGe1000 = <String>[];
        final files800To999 = <String>[];
        for (final file in allDart) {
          final count = file.readAsLinesSync().length;
          final rel = file.path
              .replaceAll('\\', '/')
              .replaceFirst('${root.replaceAll('\\', '/')}/', '');
          if (count >= 1000) {
            filesGe1000.add('$count L $rel');
          } else if (count >= 800) {
            files800To999.add('$count L $rel');
          }
        }

        expect(
          filesGe1000,
          isEmpty,
          reason: 'Aún existen archivos >= 1000 L: $filesGe1000',
        );
        expect(
          files800To999.length,
          lessThanOrEqualTo(9),
          reason:
              'Cota monótona 9E-3 excedida (${files800To999.length}): $files800To999',
        );

        const completedTargets = [
          'lib/core/widgets/home/dashboard_header.dart',
          'lib/features/smart_quotation/screens/extraction_result_screen.dart',
          'lib/core/widgets/filter_drawer.dart',
          'lib/features/catalog/widgets/edit/product_edit/product_edit_operations.dart',
        ];
        for (final closedPath in completedTargets) {
          expect(
            files800To999.any((entry) => entry.endsWith(closedPath)),
            isFalse,
            reason: '$closedPath no debe seguir en 800–999 L',
          );
        }
      },
    );

    test(
      'Paridad de símbolos públicos y contrato operativo de ProductEditOperations',
      () {
        const loadedData = ProductEditLoadedData(
          categoryId: 1,
          categoryName: 'Escolar',
          brandId: 2,
          brandName: 'Faber',
          targetKeyToScroll: '101',
        );
        expect(loadedData.categoryId, equals(1));
        expect(loadedData.targetKeyToScroll, equals('101'));

        expect(ProductEditOperations.loadInitialData, isNotNull);
        expect(ProductEditOperations.addPresentation, isNotNull);
        expect(ProductEditOperations.clonePresentation, isNotNull);
        expect(ProductEditOperations.setDefault, isNotNull);
        expect(ProductEditOperations.moveUp, isNotNull);
        expect(ProductEditOperations.moveDown, isNotNull);
        expect(ProductEditOperations.updateGeneralProvider, isNotNull);
        expect(ProductEditOperations.createLeftover, isNotNull);
        expect(ProductEditOperations.invalidateLeftover, isNotNull);
        expect(ProductEditOperations.deletePresentation, isNotNull);
        expect(ProductEditOperations.finalizeVariantExtractionCut, isNotNull);
        expect(ProductEditOperations.saveEditedProduct, isNotNull);

        final invProv = _MockInventory9E3();
        final product = Product(
          id: 50,
          nombre: 'Cuaderno Rayado A4',
          categoriaId: 1,
          marcaId: 10,
          presentaciones: [
            ProductPresentation(
              id: 501,
              nombreEspecifico: 'Paquete x 10',
              unidadVenta: 'Paquete',
              unidadesPorVenta: 10,
              precioVentaFinal: 45.0,
              stockActual: 30,
              esDefault: false,
              orden: 1,
              proveedorId: 20,
            ),
            ProductPresentation(
              id: 502,
              nombreEspecifico: 'Unidad Suelta',
              unidadVenta: 'Unidad',
              unidadesPorVenta: 1,
              precioVentaFinal: 5.0,
              stockActual: 12,
              esDefault: true,
              orden: 0,
              proveedorId: 20,
            ),
          ],
        );

        final nameCtrl = TextEditingController();
        final descCtrl = TextEditingController();
        final imgUrlCtrl = TextEditingController();
        final parentBarcodeCtrl = TextEditingController();
        final controllers = <Map<String, dynamic>>[];
        final keys = <String, GlobalKey>{};

        final loaded = ProductEditOperations.loadInitialData(
          product: product,
          invProv: invProv,
          nameCtrl: nameCtrl,
          descCtrl: descCtrl,
          imgUrlCtrl: imgUrlCtrl,
          parentBarcodeCtrl: parentBarcodeCtrl,
          presentationControllers: controllers,
          presentationKeys: keys,
          initialPresentationId: 501,
        );

        expect(loaded.categoryId, equals(1));
        expect(loaded.brandId, equals(10));
        expect(loaded.targetKeyToScroll, equals('501'));
        expect(controllers.length, equals(2));
        expect(controllers.first['isDefault'], isTrue);
        expect(controllers.first['id'], equals('502'));

        ProductEditOperations.moveDown(index: 0, controllers: controllers);
        expect(controllers[1]['id'], equals('502'));
        ProductEditOperations.moveUp(index: 1, controllers: controllers);
        expect(controllers[0]['id'], equals('502'));

        nameCtrl.dispose();
        descCtrl.dispose();
        imgUrlCtrl.dispose();
        parentBarcodeCtrl.dispose();
      },
    );
  });

  group('Plan 25 Fase 9E-3 — Certificación Responsiva 0px Overflow @ 1.3x', () {
    const viewports = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final vp in viewports) {
      testWidgets(
        'DashboardHeader (logo offline UniversalImage + KPIs) 0px @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          final tempDir = Directory.systemTemp.createTempSync('plan25_9e3_dh_');
          final logoFile = File('${tempDir.path}/logo.png')
            ..writeAsBytesSync(_kTransparentPng1x1);
          addTearDown(() {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          });

          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          try {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuth9E3(logoPath: logoFile.path),
                  ),
                  ChangeNotifierProvider<WorkbenchProvider>.value(
                    value: _MockWorkbench9E3(),
                  ),
                  ChangeNotifierProvider<SaleProvider>.value(
                    value: _MockSale9E3(),
                  ),
                  ChangeNotifierProvider<NotificationProvider>.value(
                    value: _MockNotification9E3(),
                  ),
                  ChangeNotifierProvider<TrackingProvider>.value(
                    value: _MockTracking9E3(),
                  ),
                ],
                child: _wrapViewport9E3(
                  viewport: vp,
                  child: const Scaffold(
                    body: SingleChildScrollView(child: DashboardHeader()),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            expect(find.byType(UniversalImage), findsOneWidget);
            expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
            expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
            expect(errors, isEmpty);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'ExtractionResultScreen (imagen + ítems + cambio de modo) 0px @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          final tempDir = Directory.systemTemp.createTempSync('plan25_9e3_ex_');
          final scanFile = File('${tempDir.path}/lista.png')
            ..writeAsBytesSync(_kTransparentPng1x1);
          addTearDown(() {
            if (tempDir.existsSync()) {
              tempDir.deleteSync(recursive: true);
            }
          });

          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          final smartProv = _MockSmartQuotation9E3(
            currentImage: scanFile,
            metadata: ExtractedMetadata(
              contextMode: QuotationContextMode.wholesale,
              businessOrInstitutionName: 'Bazar y Papelería El Estudiante SAC',
              clientOrContactName: 'María López Quinto',
              phone: '987654321',
            ),
            items: [
              ExtractedItem(
                id: 1,
                originalText: '2 docenas cuaderno A4 rayado',
                fullName: 'Cuaderno A4 Rayado 100 Hojas Pasta Dura',
                brand: 'Stanford',
                quantity: 2,
                unit: 'Docena',
                notes: 'Colores surtidos escolares',
              ),
              ExtractedItem(
                id: 2,
                originalText: '1 caja lapiceros azul',
                fullName: 'Lapicero Tinta Gel Punta Fina Azul',
                brand: 'Pilot',
                quantity: 1,
                unit: 'Caja',
              ),
            ],
          );

          try {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuth9E3(),
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: smartProv,
                  ),
                ],
                child: _wrapViewport9E3(
                  viewport: vp,
                  child: const ExtractionResultScreen(),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));

            expect(find.text('Datos Extraídos'), findsOneWidget);
            expect(find.text('COTIZAR (2/2)'), findsOneWidget);
            expect(find.text('Fila #1'), findsOneWidget);

            await tester.tap(find.text('Escolar'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              smartProv.metadata?.contextMode,
              equals(QuotationContextMode.school),
            );

            await tester.drag(find.byType(ListView), const Offset(0, -450));
            await tester.pump(const Duration(milliseconds: 250));
            expect(errors, isEmpty);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );

      testWidgets(
        'FilterDrawer (sliders activos + acordeones expandidos + aplicar) 0px @ 1.3x en ${vp.width.toInt()}x${vp.height.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(vp);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final errors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());

          Map<String, dynamic>? appliedFilters;

          try {
            await tester.pumpWidget(
              ChangeNotifierProvider<InventoryProvider>.value(
                value: _MockInventory9E3(),
                child: _wrapViewport9E3(
                  viewport: vp,
                  child: Scaffold(
                    body: Builder(
                      builder: (ctx) => FilterDrawer(
                        onApplyFilters: (filters) => appliedFilters = filters,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pumpAndSettle();

            expect(find.text('Filtros'), findsOneWidget);
            expect(find.text('Solo Ofertas'), findsOneWidget);
            expect(find.text('Mostrar 17 Productos'), findsOneWidget);

            // Expandir también Marcas y Proveedores tras desplazar ListView para validar chips y headers en 320dp
            final drawerScroll = find.byType(Scrollable).first;
            await tester.scrollUntilVisible(
              find.text('Marcas'),
              180.0,
              scrollable: drawerScroll,
            );
            await tester.ensureVisible(find.text('Marcas'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Marcas'));
            await tester.pumpAndSettle();
            expect(find.text('Faber-Castell'), findsOneWidget);

            await tester.scrollUntilVisible(
              find.text('Proveedores'),
              180.0,
              scrollable: drawerScroll,
            );
            await tester.ensureVisible(find.text('Proveedores'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Proveedores'));
            await tester.pumpAndSettle();
            await tester.drag(drawerScroll, const Offset(0, -120));
            await tester.pumpAndSettle();
            expect(find.text('Distribuidora Pacífico SAC'), findsOneWidget);

            await tester.tap(find.text('Mostrar 17 Productos'));
            await tester.pumpAndSettle();

            expect(appliedFilters, isNotNull);
            expect(appliedFilters!['hasOffer'], isTrue);
            expect(appliedFilters!['onlyDefaults'], isTrue);
            expect(appliedFilters!['minPrice'], equals(15.0));
            expect(appliedFilters!['maxPrice'], equals(320.0));
            expect(errors, isEmpty);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          } finally {
            FlutterError.onError = prevOnError;
          }
        },
      );
    }
  });
}
