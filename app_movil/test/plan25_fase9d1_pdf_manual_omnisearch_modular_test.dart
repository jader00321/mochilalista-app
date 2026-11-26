import 'dart:io';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/omni_search_bar.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Central Escolar SAC',
    ruc: '20554433221',
    address: 'Av. Los Próceres 1420',
    logoUrl: '/tmp/non_existent_logo_for_safe_fallback_test.png',
    paymentInfo: 'Yape: 999888777 | BCP: 191-000111222',
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
  String get businessName => _business.commercialName;

  @override
  String get activeBusinessName => _business.commercialName;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInventoryProvider extends InventoryProvider {
  Product? mockProduct;

  @override
  Future<Product?> fetchProductById(int id) async => mockProduct;

  @override
  Future<Product?> getFullProductWithFallback(int id) async => mockProduct;

  @override
  String getCategoryName(int? id) => 'Útiles Escolares';

  @override
  String getBrandName(int? id) => 'Faber-Castell';
}

class _FakeSmartQuotationProvider extends SmartQuotationProvider {
  SmartQuotationModel? mockQuotation;

  @override
  Future<SmartQuotationModel?> getQuotationById(int id) async => mockQuotation;
}

class _FakeSaleProvider extends ChangeNotifier implements SaleProvider {
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

Future<Database> _createSeededTestDb() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 36,
      onCreate: (db, version) async {
        await LocalDatabase.createDBForTesting(db);
      },
    ),
  );

  await db.insert('usuarios', {
    'id': 1,
    'nombre_completo': 'Angello Propietario',
    'telefono': '999888777',
    'activo': 1,
  });
  await db.insert('negocios', {
    'id': 1,
    'nombre_comercial': 'Librería Central Escolar SAC',
    'moneda': 'S/ (Soles)',
    'id_dueno': 1,
  });
  await db.insert('marcas', {
    'id': 1,
    'negocio_id': 1,
    'nombre': 'Faber-Castell',
  });
  await db.insert('categorias', {
    'id': 1,
    'negocio_id': 1,
    'nombre': 'Útiles Escolares',
  });
  await db.insert('productos', {
    'id': 10,
    'negocio_id': 1,
    'nombre': 'Lápiz Técnico 2B',
    'categoria_id': 1,
    'marca_id': 1,
    'modo_stock': 'INDEPENDIENTE',
    'stock_compartido': 0,
    'imagen_url': '',
  });
  await db.insert('presentaciones_producto', {
    'id': 101,
    'producto_id': 10,
    'nombre_especifico': 'Caja x12 Unidades',
    'unidad_venta': 'Caja',
    'unidades_por_venta': 12,
    'precio_venta_final': 18.50,
    'precio_oferta': 16.00,
    'stock_actual': 60,
    'stock_alerta': 12,
    'codigo_barras': '7750011223344',
    'activo': 1,
  });
  await db.insert('clientes', {
    'id': 20,
    'negocio_id': 1,
    'creado_por_usuario_id': 1,
    'nombre_completo': 'María Ángel Peña',
    'telefono': '987654321',
    'dni_ruc': '44556677',
    'saldo_a_favor': 15.0,
    'deuda_total': 42.50,
    'nivel_confianza': 'Excelente',
    'notas': 'Cliente frecuente',
  });
  await db.insert('smart_quotations', {
    'id': 30,
    'numero_secuencial': 30,
    'negocio_id': 1,
    'creado_por_usuario_id': 1,
    'client_id': 20,
    'client_name': 'María Ángel Peña',
    'institution_name': 'Colegio Santa Rosa de Lima',
    'grade_level': '5to Primaria',
    'total_amount': 128.90,
    'total_savings': 12.00,
    'status': 'PENDING',
    'type': 'manual',
    'created_at': '2026-11-20T10:00:00',
  });
  await db.insert('smart_quotations', {
    'id': 31,
    'numero_secuencial': 31,
    'negocio_id': 1,
    'creado_por_usuario_id': 1,
    'client_id': 20,
    'client_name': 'Venta Excluida',
    'total_amount': 50.0,
    'total_savings': 0.0,
    'status': 'vendida',
    'type': 'manual',
    'created_at': '2026-11-20T11:00:00',
  });
  await db.insert('ventas', {
    'id': 40,
    'numero_secuencial': 40,
    'negocio_id': 1,
    'creado_por_usuario_id': 1,
    'cliente_id': 20,
    'monto_total': 84.00,
    'monto_pagado': 84.00,
    'fecha_venta': '2026-11-22T15:30:00',
    'metodo_pago': 'yape',
    'estado_pago': 'completado',
    'is_archived': 0,
  });

  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database seededDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    seededDb = await _createSeededTestDb();
    LocalDatabase.setCustomDatabase(seededDb);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('net.nfet.printing'), (
          call,
        ) async {
          if (call.method == 'printingInfo') {
            return <String, dynamic>{
              'directPrint': false,
              'dynamicLayout': false,
              'canPrint': true,
              'canConvertHtml': false,
              'canShare': true,
              'canRaster': false,
            };
          }
          return null;
        });
  });

  tearDown(() async {
    await seededDb.close();
    LocalDatabase.setCustomDatabase(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.nfet.printing'),
          null,
        );
  });

  group('Plan 25 Fase 9D-1 — Censo, Paridad de Símbolos y Motor Omni-Search', () {
    test(
      'Cumple topes (<600 L coordinadores, <650 L submódulos) y elimina existsSync en pdf_preview',
      () {
        final root = _resolveAppMovilRoot();

        const coordinators = [
          'lib/features/smart_quotation/screens/pdf_preview_screen.dart',
          'lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart',
          'lib/core/widgets/omni_search_bar.dart',
        ];
        for (final path in coordinators) {
          expect(_lineCount(root, path), lessThan(600), reason: path);
        }

        const submodules = [
          'lib/features/smart_quotation/screens/pdf_preview/pdf_preview_toolbars.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_modal.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_design_tab.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_business_tab.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_footer_chips_section.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_table_tab.dart',
          'lib/features/smart_quotation/widgets/manual/detail_modal/manual_quote_detail_logic_mixin.dart',
          'lib/features/smart_quotation/widgets/manual/detail_modal/manual_quote_header_section.dart',
          'lib/features/smart_quotation/widgets/manual/detail_modal/manual_quote_variants_section.dart',
          'lib/features/smart_quotation/widgets/manual/detail_modal/manual_quote_discount_and_totals_section.dart',
          'lib/core/widgets/search/omni_search_models.dart',
          'lib/core/widgets/search/omni_search_models_and_engine.dart',
          'lib/core/widgets/search/omni_search_sheet.dart',
          'lib/core/widgets/search/omni_search_sheet_controls.dart',
          'lib/core/widgets/search/omni_search_result_cards.dart',
          'lib/core/widgets/search/omni_search_secondary_cards.dart',
        ];
        for (final path in submodules) {
          expect(_lineCount(root, path), lessThan(650), reason: path);
        }

        // Verificar D-MOV-06: 0 llamadas existsSync() en pdf_preview_screen + pdf_preview/
        final sep = Platform.pathSeparator;
        for (final rel in [
          'lib/features/smart_quotation/screens/pdf_preview_screen.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_preview_toolbars.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_modal.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_design_tab.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_business_tab.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_footer_chips_section.dart',
          'lib/features/smart_quotation/screens/pdf_preview/pdf_config_table_tab.dart',
        ]) {
          final content = File(
            '${root.path}$sep${rel.replaceAll('/', sep)}',
          ).readAsStringSync();
          expect(content.contains('existsSync'), isFalse, reason: rel);
        }

        // Paridad de símbolos importados desde rutas originales
        expect(PdfPreviewScreen, isNotNull);
        expect(ManualQuoteDetailModal, isNotNull);
        expect(OmniSearchBar, isNotNull);
        expect(OmniSearchSheet, isNotNull);
        expect(OmniSearchEngine, isNotNull);
        expect(OmniProductResultCard, isNotNull);
        expect(OmniClientResultCard, isNotNull);
        expect(OmniQuoteResultCard, isNotNull);
        expect(OmniSaleResultCard, isNotNull);
        expect(OmniSortOption.values.length, equals(5));
        expect(const OmniHeaderItem('H', 1), isA<OmniListItem>());
        expect(const OmniProductItem({}), isA<OmniListItem>());
        expect(const OmniClientItem({}), isA<OmniListItem>());
        expect(const OmniQuoteItem({}), isA<OmniListItem>());
        expect(const OmniSaleItem({}), isA<OmniListItem>());
        expect(const OmniSpacerItem(), isA<OmniListItem>());
      },
    );

    test(
      'OmniSearchEngine normaliza tildes/diéresis, calcula scoring y ordena en todas las variantes',
      () {
        expect(
          OmniSearchEngine.normalizeText('  Lápiz ÁGUILA Güero  '),
          equals('lapiz aguila guero'),
        );
        expect(OmniSearchEngine.sqlUnaccent('p.nombre'), contains("REPLACE("));

        final exactScore = OmniSearchEngine.scoreItem(
          'Lápiz Técnico 2B',
          'Faber-Castell',
          '7750011223344',
          'lapiz tecnico 2b',
        );
        final partialScore = OmniSearchEngine.scoreItem(
          'Estuche con Lápiz Escolar',
          'Artesco',
          '111',
          'lapiz tecnico 2b',
        );
        expect(exactScore, greaterThan(partialScore));

        final rows = [
          {
            'presentation_id': 1,
            'producto_nombre': 'Zapatilla',
            'nombre_especifico': 'Negra',
            'marca_nombre': 'A',
            'precio_venta_final': 10.0,
          },
          {
            'presentation_id': 3,
            'producto_nombre': 'Ábaco Escolar',
            'nombre_especifico': 'Grande',
            'marca_nombre': 'B',
            'precio_venta_final': 35.0,
          },
          {
            'presentation_id': 2,
            'producto_nombre': 'Cuaderno',
            'nombre_especifico': 'Rayado',
            'marca_nombre': 'C',
            'precio_venta_final': 20.0,
          },
        ];

        final sortedAz = OmniSearchEngine.sortResults(
          rows,
          'products',
          OmniSortOption.az,
          '',
        );
        expect(sortedAz.first['producto_nombre'], equals('Cuaderno'));
        expect(sortedAz.last['producto_nombre'], equals('Ábaco Escolar'));

        final sortedDesc = OmniSearchEngine.sortResults(
          rows,
          'products',
          OmniSortOption.priceDesc,
          '',
        );
        expect(sortedDesc.first['precio_venta_final'], equals(35.0));

        final sortedAsc = OmniSearchEngine.sortResults(
          rows,
          'products',
          OmniSortOption.priceAsc,
          '',
        );
        expect(sortedAsc.first['precio_venta_final'], equals(10.0));

        final sortedRecent = OmniSearchEngine.sortResults(
          rows,
          'products',
          OmniSortOption.recent,
          '',
        );
        expect(sortedRecent.first['presentation_id'], equals(3));

        final virtualItems = OmniSearchEngine.buildVirtualizedItems(
          activeCategory: 'all',
          sortedProducts: [rows.first],
          sortedClients: const [
            {'id': 1, 'nombre_completo': 'Cliente 1'},
          ],
          sortedQuotes: const [
            {'id': 2, 'client_name': 'Quote 1'},
          ],
          sortedSales: const [
            {'id': 3, 'monto_total': 12.0},
          ],
        );
        expect(virtualItems.whereType<OmniHeaderItem>().length, equals(4));
        expect(virtualItems.whereType<OmniSpacerItem>().length, equals(4));
        expect(virtualItems.whereType<OmniProductItem>().length, equals(1));
        expect(virtualItems.whereType<OmniClientItem>().length, equals(1));
        expect(virtualItems.whereType<OmniQuoteItem>().length, equals(1));
        expect(virtualItems.whereType<OmniSaleItem>().length, equals(1));
      },
    );

    test(
      'OmniSearchEngine consulta conteos reales y búsqueda SQLite sin tildes',
      () async {
        final counts = await OmniSearchEngine.loadDatabaseCounts(seededDb, 1);
        expect(counts.products, equals(1));
        expect(counts.clients, equals(1));
        expect(counts.quotes, equals(1)); // Excluye 'vendida'
        expect(counts.sales, equals(1));
        expect(counts.total, equals(4));

        final accentSearch = await OmniSearchEngine.performSearch(
          seededDb,
          1,
          'lapiz angel',
          'all',
        );
        expect(accentSearch.products, isEmpty);
        expect(accentSearch.clients, isEmpty);
        final prodOnly = await OmniSearchEngine.performSearch(
          seededDb,
          1,
          'lapiz',
          'products',
        );
        expect(prodOnly.products.length, equals(1));
        final clientOnly = await OmniSearchEngine.performSearch(
          seededDb,
          1,
          'maria angel',
          'clients',
        );
        expect(clientOnly.clients.length, equals(1));
      },
    );
  });

  group('Plan 25 Fase 9D-1 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    const viewports = [Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final size in viewports) {
      testWidgets(
        'PdfPreviewScreen, ManualQuoteDetailModal y OmniSearchBar/Sheet en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
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
            final authProv = _MockAuthProvider();
            final fakeInv = _FakeInventoryProvider();
            final fakeSale = _FakeSaleProvider();
            final fakeQuoteProv = _FakeSmartQuotationProvider()
              ..mockQuotation = SmartQuotationModel(
                id: 30,
                sequentialNumber: 30,
                negocioId: 1,
                creadoPorUsuarioId: 1,
                clientId: 20,
                clientName: 'María Ángel Peña',
                institutionName: 'Colegio Santa Rosa de Lima',
                gradeLevel: '5to Primaria',
                totalAmount: 128.90,
                totalSavings: 12.00,
                status: 'PENDING',
                type: 'manual',
                createdAt: '2026-11-20T10:00:00',
                items: [
                  QuotationItem(
                    id: 1,
                    productId: 10,
                    presentationId: 101,
                    productName: 'Lápiz Técnico 2B',
                    brandName: 'Faber-Castell',
                    specificName: 'Caja x12 Unidades',
                    salesUnit: 'Caja',
                    quantity: 2,
                    unitPriceApplied: 16.00,
                    originalUnitPrice: 18.50,
                  ),
                ],
              );

            // 1. PdfPreviewScreen + Modal de Personalización (3 pestañas)
            currentStage = 'PdfPreviewScreen';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: fakeQuoteProv,
                  ),
                  ChangeNotifierProvider<SaleProvider>.value(value: fakeSale),
                ],
                child: _wrapWithTextScaler(
                  const PdfPreviewScreen(
                    quotationId: 30,
                    contextMode: QuotationContextMode.school,
                  ),
                ),
              ),
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 120)),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('OPCIONES'), findsOneWidget);
            expect(find.text('GUARDAR'), findsOneWidget);

            currentStage = 'PdfPreviewScreen ConfigModal';
            await tester.tap(find.text('OPCIONES'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.text('Opciones de Documento'), findsOneWidget);
            expect(find.byKey(const ValueKey('checked')), findsOneWidget);

            // Navegar a Pestaña 2: Negocio y Cliente
            await tester.tap(find.text('Negocio y Cliente'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.text('Logo actual detectado'), findsOneWidget);

            // Activar Cuentas de Cobro para verificar chips y AnimatedSize en 320dp
            final payAccountsSwitch = find.text(
              'Mostrar Cuentas de Cobro (Yape/Plin)',
            );
            final tab2ListView = tester.widget<ListView>(
              find.ancestor(
                of: find.text('Logo actual detectado'),
                matching: find.byType(ListView),
              ),
            );
            final tab2Scrollable = find.descendant(
              of: find.byWidget(tab2ListView),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            );
            await tester.scrollUntilVisible(
              payAccountsSwitch,
              200,
              scrollable: tab2Scrollable,
              maxScrolls: 20,
            );
            await Scrollable.ensureVisible(
              tester.element(payAccountsSwitch),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            await tester.tap(payAccountsSwitch);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            // Navegar a Pestaña 3: Tabla y Totales
            await tester.tap(find.text('Tabla y Totales'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.text('Incluir Imágenes de Productos'), findsOneWidget);
            final tab3ListView = tester.widget<ListView>(
              find.ancestor(
                of: find.text('Incluir Imágenes de Productos'),
                matching: find.byType(ListView),
              ),
            );
            final tab3Scrollable = find.descendant(
              of: find.byWidget(tab3ListView),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            );
            final totalsTitle = find.text('TOTALES FINANCIEROS');
            await tester.scrollUntilVisible(
              totalsTitle,
              200,
              scrollable: tab3Scrollable,
              maxScrolls: 15,
            );
            await Scrollable.ensureVisible(
              tester.element(totalsTitle),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            expect(totalsTitle, findsOneWidget);

            await tester.tap(find.text('Aplicar'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            // Avanzar temporizador de la píldora de zoom (3500ms) para evitar timers pendientes
            await tester.pump(const Duration(milliseconds: 3600));

            // 2. ManualQuoteDetailModal (con variantes compartidas y descuento)
            currentStage = 'ManualQuoteDetailModal';
            final fullProd = Product(
              id: 100,
              nombre: 'Cuaderno A4 Rayado Profesional',
              categoriaId: 1,
              modoStock: 'COMPARTIDO',
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
            final matched = MatchedProduct(
              productId: 100,
              presentationId: 101,
              fullName: 'Cuaderno A4 Rayado Profesional Caja Escolar',
              productName: 'Cuaderno A4 Rayado Profesional',
              specificName: 'Caja Escolar',
              brand: 'Faber-Castell',
              price: 25.0,
              offerPrice: 21.50,
              stock: 9,
              unit: '½ Docena',
              conversionFactor: 6,
              usaStockCompartido: true,
              sharedStockPool: 68,
              cupoMaximoVariante: 9,
            );

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: fakeInv,
                  ),
                  ChangeNotifierProvider<QuickSaleProvider>(
                    create: (_) => QuickSaleProvider(),
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: fakeQuoteProv,
                  ),
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                ],
                child: _wrapWithTextScaler(
                  Scaffold(
                    body: ManualQuoteDetailModal(
                      product: matched,
                      initialQty: 2,
                      categoryName: 'Útiles Escolares',
                      isEditingSavedQuote: true,
                      isBundleOutdated: true,
                      onConfirm: (_, __, ___, ____) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final verOtrasFinder = find.text('Ver otras');
            await tester.ensureVisible(verOtrasFinder);
            await tester.tap(verOtrasFinder);
            await tester.pumpAndSettle();
            expect(
              find.textContaining('Inventario base compartido: 68 und.'),
              findsOneWidget,
            );

            // 3. OmniSearchBar + OmniSearchSheet con las 4 cards expandibles
            currentStage = 'OmniSearchBar and OmniSearchSheet';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(value: authProv),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: fakeInv,
                  ),
                ],
                child: _wrapWithTextScaler(
                  Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(12),
                      child: OmniSearchBar(onBarcodeTap: () {}),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byType(OmniSearchBar));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 120)),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));

            expect(find.text('Búsqueda Omnicanal Local'), findsOneWidget);
            expect(find.textContaining('Todos (4)'), findsOneWidget);
            expect(find.textContaining('Lápiz Técnico 2B'), findsOneWidget);

            // Expandir tarjeta de producto para validar chips internos en 320dp
            await tester.tap(find.textContaining('Lápiz Técnico 2B'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              find.text('Ver Ficha Completa del Producto'),
              findsOneWidget,
            );

            // Validar también cards de Cliente, Cotización y Venta expandidas sin overflow
            for (final entry in const [
              (
                'Clientes (1)',
                'María Ángel Peña',
                'Ver Perfil y Cuenta Corriente',
              ),
              (
                'Cotizaciones (1)',
                'Cotización #30',
                'Abrir Detalle de Cotización',
              ),
              ('Ventas (1)', 'Venta #40', 'Abrir Detalle de Venta'),
            ]) {
              final chipFinder = find.text(entry.$1);
              await tester.ensureVisible(chipFinder);
              await tester.pump();
              await tester.tap(chipFinder);
              await tester.pump();
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 250));

              final cardFinder = find.textContaining(entry.$2);
              expect(cardFinder, findsOneWidget);
              await tester.tap(cardFinder);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              expect(find.text(entry.$3), findsOneWidget);
            }

            Navigator.of(tester.element(find.byType(OmniSearchSheet))).pop();
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
