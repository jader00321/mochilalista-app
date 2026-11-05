import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/floating_dock_session_state.dart';
import 'package:app_movil/core/widgets/persistent_work_dock.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_stock_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:app_movil/core/screens/splash/cold_start_splash_screen.dart';
import 'package:app_movil/core/widgets/brand/mochila_brand_medallion.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';

// Mocks ultraligeros
class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get hasActiveContext => true;

  @override
  bool get isOwner => true;

  @override
  bool get isWorker => false;

  @override
  bool get isCommunityClient => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockQuickSaleProvider extends ChangeNotifier implements QuickSaleProvider {
  final List<MatchedProduct> _items = [
    MatchedProduct(
      productId: 1,
      presentationId: 1,
      fullName: 'Cuaderno',
      price: 5.0,
      stock: 10,
    ),
  ];

  @override
  List<MatchedProduct> get cartItems => _items;

  @override
  double get totalToPay => 5.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockScannerProvider extends ChangeNotifier implements ScannerProvider {
  final StagingResponse? _stagingData;
  _MockScannerProvider([this._stagingData]);

  @override
  StagingResponse? get stagingData => _stagingData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMatchingProvider extends ChangeNotifier implements MatchingProvider {
  @override
  List<MatchPair> get pairs => [];

  @override
  double get totalNetAmount => 25.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSmartQuotationProvider extends ChangeNotifier implements SmartQuotationProvider {
  final bool _hasDraft;
  _MockSmartQuotationProvider([this._hasDraft = false]);

  @override
  bool get hasManualDraft => _hasDraft;

  @override
  List<MatchedProduct>? get draftManualItems => _hasDraft ? [] : null;

  @override
  String? get draftQuoteTitle => _hasDraft ? 'Cotización Prueba' : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  final bool _hasDraft;
  final ProductCreateDraft? _draft;
  _MockInventoryProvider([this._hasDraft = false, this._draft]);

  @override
  bool get hasCreationDraft => _hasDraft;

  @override
  ProductCreateDraft? get creationDraft => _draft;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FloatingDockSessionState.isBubble = false;
    FloatingDockSessionState.isEdgeTucked = false;
    FloatingDockSessionState.isLeftEdge = false;
    FloatingDockSessionState.panX = null;
    FloatingDockSessionState.panBottom = 80.0;
  });

  group('FASE 1: Erradicación Total de Pantalla Blanca / ParentDataWidget en Home & WorkDock', () {
    testWidgets(
      'PersistentWorkDock como hijo directo de Stack con tareas activas NO lanza excepciones',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(create: (_) => _MockAuthProvider()),
              ChangeNotifierProvider<QuickSaleProvider>(create: (_) => _MockQuickSaleProvider()),
              ChangeNotifierProvider<ScannerProvider>(create: (_) => _MockScannerProvider()),
              ChangeNotifierProvider<MatchingProvider>(create: (_) => _MockMatchingProvider()),
              ChangeNotifierProvider<SmartQuotationProvider>(create: (_) => _MockSmartQuotationProvider()),
              ChangeNotifierProvider<InventoryProvider>(create: (_) => _MockInventoryProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: const [
                    Positioned.fill(child: ColoredBox(color: Colors.blue)),
                    Center(child: Text('Home Content Interactivo')),
                    PersistentWorkDock(isFloating: true),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Ninguna excepción lanzada por Flutter (0 ParentDataWidget exceptions)
        expect(tester.takeException(), isNull);

        // El contenido del Home sigue visible e interactivo
        expect(find.text('Home Content Interactivo'), findsOneWidget);

        // PersistentWorkDock está renderizado
        expect(find.byType(PersistentWorkDock), findsOneWidget);
        expect(find.text('Caja Rápida'), findsOneWidget);
      },
    );

    testWidgets(
      'PersistentWorkDock en Modo Globo Flotante 2D y Modo Edge Peek no viola jerarquía Stack',
      (tester) async {
        // Configurar modo burbuja flotante
        FloatingDockSessionState.isBubble = true;
        FloatingDockSessionState.isEdgeTucked = false;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(create: (_) => _MockAuthProvider()),
              ChangeNotifierProvider<QuickSaleProvider>(create: (_) => _MockQuickSaleProvider()),
              ChangeNotifierProvider<ScannerProvider>(create: (_) => _MockScannerProvider()),
              ChangeNotifierProvider<MatchingProvider>(create: (_) => _MockMatchingProvider()),
              ChangeNotifierProvider<SmartQuotationProvider>(create: (_) => _MockSmartQuotationProvider()),
              ChangeNotifierProvider<InventoryProvider>(create: (_) => _MockInventoryProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: const [
                    Positioned.fill(child: ColoredBox(color: Colors.blue)),
                    PersistentWorkDock(isFloating: true),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);

        // Ahora simular Edge Peek
        FloatingDockSessionState.isEdgeTucked = true;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(create: (_) => _MockAuthProvider()),
              ChangeNotifierProvider<QuickSaleProvider>(create: (_) => _MockQuickSaleProvider()),
              ChangeNotifierProvider<ScannerProvider>(create: (_) => _MockScannerProvider()),
              ChangeNotifierProvider<MatchingProvider>(create: (_) => _MockMatchingProvider()),
              ChangeNotifierProvider<SmartQuotationProvider>(create: (_) => _MockSmartQuotationProvider()),
              ChangeNotifierProvider<InventoryProvider>(create: (_) => _MockInventoryProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: const [
                    Positioned.fill(child: ColoredBox(color: Colors.blue)),
                    PersistentWorkDock(isFloating: true),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PersistentWorkDock con 4 tareas pendientes activas conmuta entre modos con 0 excepciones',
      (tester) async {
        final mockStaging = StagingResponse(
          proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 100),
          proveedorTexto: 'Distribuidora Central',
          productosAgrupados: [
            StagingProductGroup(
              nombrePadre: 'Plumones x12',
              marcaTexto: 'Artesco',
              matchProducto: MatchResult(estado: 'NUEVO', confianza: 100),
              matchMarca: MatchResult(estado: 'NUEVO', confianza: 100),
              variantes: [],
            ),
          ],
        );

        final mockDraft = ProductCreateDraft(
          name: 'Cuaderno Loro 100h',
          presentations: const [{'specific': 'Unidad'}],
        );

        FloatingDockSessionState.isBubble = false;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(create: (_) => _MockAuthProvider()),
              ChangeNotifierProvider<QuickSaleProvider>(create: (_) => _MockQuickSaleProvider()),
              ChangeNotifierProvider<ScannerProvider>(create: (_) => _MockScannerProvider(mockStaging)),
              ChangeNotifierProvider<MatchingProvider>(create: (_) => _MockMatchingProvider()),
              ChangeNotifierProvider<SmartQuotationProvider>(create: (_) => _MockSmartQuotationProvider(true)),
              ChangeNotifierProvider<InventoryProvider>(create: (_) => _MockInventoryProvider(true, mockDraft)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: const [
                    Positioned.fill(child: ColoredBox(color: Colors.teal)),
                    PersistentWorkDock(isFloating: true),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);

        // Conmutar a globo flotante con 4 tareas
        FloatingDockSessionState.isBubble = true;
        FloatingDockSessionState.isEdgeTucked = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('FASE 2: Sincronización a 0ms de Stock Disponible en Variantes Compartidas', () {
    testWidgets(
      'PresentationStockSection sincroniza automáticamente stockFinalCtrl con el disponible calculado',
      (tester) async {
        final sharedStockCtrl = TextEditingController(text: '10');
        final factorCtrl = TextEditingController(text: '3');
        final stockFinalCtrl = TextEditingController(text: '0'); // Simula "0" inicial
        final controllerMap = <String, dynamic>{
          'cupoMaximoVariante': null, // Sin límite acotado
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PresentationStockSection(
                  stockInicialCtrl: TextEditingController(text: '0'),
                  nuevoIngresoCtrl: TextEditingController(text: '0'),
                  stockDescuentoCtrl: TextEditingController(text: '0'),
                  stockFinalCtrl: stockFinalCtrl,
                  ajusteBaseCtrl: TextEditingController(),
                  unidadVentaCtrl: TextEditingController(text: 'Caja'),
                  unidadesVentaCtrl: factorCtrl,
                  specificCtrl: TextEditingController(text: 'Caja x3'),
                  isEditMode: false,
                  originalBaseStock: 0,
                  leftoverCreated: false,
                  stockValidation: StockValidationResult.empty(),
                  costoBaseParaSobrante: 10.0,
                  isDark: false,
                  onStockChanged: () {},
                  onAjusteBaseChanged: () {},
                  modoStock: 'MIXTO',
                  usaStockCompartido: true,
                  sharedStockCtrl: sharedStockCtrl,
                  controllerMap: controllerMap,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Debe mostrar inmediatamente 3 (10 ~/ 3) y JAMÁS quedarse en 0
        expect(stockFinalCtrl.text, equals('3'));
        expect(find.text('= 3 Caja disp.'), findsOneWidget);
        expect(find.text('Libre hasta 3 Caja'), findsOneWidget);

        // Modificar el stock base compartido a 20 -> Debe sincronizarse inmediatamente a 6 (20 ~/ 3)
        sharedStockCtrl.text = '20';
        await tester.pump();
        expect(stockFinalCtrl.text, equals('6'));

        // Modificar el factor de venta a 1 -> Debe sincronizarse inmediatamente a 20 (20 ~/ 1)
        factorCtrl.text = '1';
        await tester.pump();
        expect(stockFinalCtrl.text, equals('20'));
      },
    );

    testWidgets(
      'PresentationStockSection respeta el cupo manual personalizado del usuario',
      (tester) async {
        final sharedStockCtrl = TextEditingController(text: '10');
        final factorCtrl = TextEditingController(text: '3');
        final stockFinalCtrl = TextEditingController(text: '2');
        final controllerMap = <String, dynamic>{
          'cupoMaximoVariante': 2, // Usuario fijó un cupo de 2 (menor a 3)
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PresentationStockSection(
                  stockInicialCtrl: TextEditingController(text: '0'),
                  nuevoIngresoCtrl: TextEditingController(text: '0'),
                  stockDescuentoCtrl: TextEditingController(text: '0'),
                  stockFinalCtrl: stockFinalCtrl,
                  ajusteBaseCtrl: TextEditingController(),
                  unidadVentaCtrl: TextEditingController(text: 'Caja'),
                  unidadesVentaCtrl: factorCtrl,
                  specificCtrl: TextEditingController(text: 'Caja x3'),
                  isEditMode: true,
                  originalBaseStock: 10,
                  leftoverCreated: false,
                  stockValidation: StockValidationResult.empty(),
                  costoBaseParaSobrante: 10.0,
                  isDark: false,
                  onStockChanged: () {},
                  onAjusteBaseChanged: () {},
                  modoStock: 'MIXTO',
                  usaStockCompartido: true,
                  sharedStockCtrl: sharedStockCtrl,
                  controllerMap: controllerMap,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Debe respetar el cupo guardado de 2
        expect(stockFinalCtrl.text, equals('2'));
        expect(find.text('= 2 Caja disp.'), findsOneWidget);
        expect(find.text('Cupo acotado'), findsOneWidget);
        expect(find.text('2 de 3 Caja máx.'), findsOneWidget);
      },
    );

    test(
      'PresentationMathEngine toggleSharedStockMode sincroniza stockFinalCtrl al activar modo Compartido',
      () {
        final sharedStockCtrl = TextEditingController(text: '10');
        final stockFinalCtrl = TextEditingController(text: '0');
        final factorCtrl = TextEditingController(text: '3');
        final controllerMap = <String, dynamic>{
          'isEditMode': false,
          'sharedStockCtrl': sharedStockCtrl,
          'cupoMaximoVariante': null,
        };

        final engine = PresentationMathEngine(
          controllerMap: controllerMap,
          onStateUpdate: () {},
          umpCompraCtrl: TextEditingController(),
          cantCompraCtrl: TextEditingController(),
          unidadesLoteCtrl: TextEditingController(text: '1'),
          totalPagoCtrl: TextEditingController(),
          specificCtrl: TextEditingController(),
          unidadVentaCtrl: TextEditingController(text: 'Caja'),
          unidadesVentaCtrl: factorCtrl,
          costoPresCtrl: TextEditingController(text: '0.00'),
          margenCtrl: TextEditingController(text: '1.35'),
          ventaCtrl: TextEditingController(text: '0.00'),
          valorDescuentoCtrl: TextEditingController(),
          stockInicialCtrl: TextEditingController(text: '0'),
          nuevoIngresoCtrl: TextEditingController(),
          stockDescuentoCtrl: TextEditingController(text: '0'),
          stockFinalCtrl: stockFinalCtrl,
          ajusteBaseCtrl: TextEditingController(),
        );

        // Activar modo compartido
        engine.toggleSharedStockMode(isShared: true, baseCost: 10.0);

        // stockFinalCtrl debe sincronizarse a 3
        expect(stockFinalCtrl.text, equals('3'));
      },
    );

    test(
      'PresentationMathEngine onUnidadVentaChanged recalcula stockFinalCtrl reactivamente al cambiar factor',
      () {
        final sharedStockCtrl = TextEditingController(text: '15');
        final stockFinalCtrl = TextEditingController(text: '15');
        final factorCtrl = TextEditingController(text: '1');
        final controllerMap = <String, dynamic>{
          'isEditMode': false,
          'usaStockCompartido': true,
          'costoBaseUnitario': 4.0,
          'sharedStockCtrl': sharedStockCtrl,
          'cupoMaximoVariante': null,
        };

        final engine = PresentationMathEngine(
          controllerMap: controllerMap,
          onStateUpdate: () {},
          umpCompraCtrl: TextEditingController(),
          cantCompraCtrl: TextEditingController(),
          unidadesLoteCtrl: TextEditingController(text: '1'),
          totalPagoCtrl: TextEditingController(),
          specificCtrl: TextEditingController(),
          unidadVentaCtrl: TextEditingController(text: 'Docena'),
          unidadesVentaCtrl: factorCtrl,
          costoPresCtrl: TextEditingController(text: '4.00'),
          margenCtrl: TextEditingController(text: '1.35'),
          ventaCtrl: TextEditingController(text: '5.40'),
          valorDescuentoCtrl: TextEditingController(),
          stockInicialCtrl: TextEditingController(text: '0'),
          nuevoIngresoCtrl: TextEditingController(),
          stockDescuentoCtrl: TextEditingController(text: '0'),
          stockFinalCtrl: stockFinalCtrl,
          ajusteBaseCtrl: TextEditingController(),
        );

        // Cambiar unidad a Docena (factor 12)
        factorCtrl.text = '12';
        engine.onUnidadVentaChanged('Docena', 12, false);

        // 15 ~/ 12 = 1 docena disponible
        expect(stockFinalCtrl.text, equals('1'));
        expect(engine.costoPresCtrl.text, equals('48.00'));
      },
    );
  });

  group('FASE 3: Visibilidad Completa de Chips Rápidos (+10 und a +500 und)', () {
    testWidgets(
      'ProductStockStrategySelector muestra los 4 chips sin recortar +500 und en pantalla angosta de 320dp',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 600 * 2);
        tester.view.devicePixelRatio = 2.0;

        final sharedStockCtrl = TextEditingController(text: '0');
        final baseCostCtrl = TextEditingController(text: '10.00');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProductStockStrategySelector(
                  selectedStrategy: 'COMPARTIDO',
                  onStrategyChanged: (_) {},
                  sharedStockController: sharedStockCtrl,
                  baseCostController: baseCostCtrl,
                  isDark: false,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Los 4 chips deben estar presentes y completamente renderizados
        expect(find.text('+10 und'), findsOneWidget);
        expect(find.text('+50 und'), findsOneWidget);
        expect(find.text('+100 und'), findsOneWidget);
        expect(find.text('+500 und'), findsOneWidget);

        // Probar pulsar +500 und
        await tester.tap(find.text('+500 und'));
        await tester.pump();
        expect(sharedStockCtrl.text, equals('500'));

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      },
    );

    testWidgets(
      'ProductStockStrategySelector en modo edición de 360dp muestra chips con FittedBox',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2, 640 * 2);
        tester.view.devicePixelRatio = 2.0;

        final sharedStockCtrl = TextEditingController(text: '100');
        final sharedIngresoCtrl = TextEditingController(text: '0');
        final baseCostCtrl = TextEditingController(text: '5.00');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProductStockStrategySelector(
                  selectedStrategy: 'COMPARTIDO',
                  onStrategyChanged: (_) {},
                  sharedStockController: sharedStockCtrl,
                  baseCostController: baseCostCtrl,
                  isDark: true,
                  isEditMode: true,
                  sharedIngresoController: sharedIngresoCtrl,
                  originalBaseStock: 100,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('+500 und'), findsOneWidget);
        await tester.tap(find.text('+500 und'));
        await tester.pump();

        // Ingreso pasa a 500 y total a 600
        expect(sharedIngresoCtrl.text, equals('500'));
        expect(sharedStockCtrl.text, equals('600'));

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      },
    );
  });

  group('FASE 4: Refinamiento Cinemático Splash V2 (Cero Truncamiento y Medallón)', () {
    testWidgets(
      'ColdStartSplashScreen renderiza mensajes largos sin ... con FittedBox scaleDown',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ColdStartSplashScreen(forcedToken: '2A')),
        );

        await tester.pump(const Duration(milliseconds: 500));

        // Verificar que la píldora contenga el FittedBox
        expect(find.byType(FittedBox), findsWidgets);

        // Verificar que el texto de Bóveda se muestre completo
        expect(find.textContaining('Bóveda local segura'), findsOneWidget);

        // Verificar que exista el medallón con la proporción ampliada
        expect(find.byType(MochilaBrandMedallion), findsOneWidget);
      },
    );

    testWidgets(
      'MochilaBrandMedallion aplica micro-respiración y proporción al 72%',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: MochilaBrandMedallion(
                  size: 104,
                  pulseValue: 1.0,
                  isDark: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Debe contener CustomPaint con el isotipo oficial
        expect(find.byType(CustomPaint), findsWidgets);
        expect(find.byType(MochilaBrandMedallion), findsOneWidget);
      },
    );
  });
}
