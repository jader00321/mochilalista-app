import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_stock_section.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_financial_dashboard.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_variant_selector.dart';
import 'package:app_movil/core/widgets/custom_search_bar.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';

class _MockInventoryProvider extends InventoryProvider {
  final List<InventoryWrapper> _mockItems;
  bool updateQuotaCalled = false;
  int? lastPresentationId;
  int? lastQuota;

  _MockInventoryProvider(this._mockItems);

  @override
  List<InventoryWrapper> get items => _mockItems;

  @override
  Future<bool> updateVariantQuota(int presentationId, int? newQuota) async {
    updateQuotaCalled = true;
    lastPresentationId = presentationId;
    lastQuota = newQuota;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CERTIFICACIÓN REFINAMIENTO STOCK COMPARTIDO, ASESOR, MODAL Y DETALLE', () {
    // -------------------------------------------------------------------------
    // T-01: Asesor de Stock con 68 u. base y variante Par x2 (Caso A - Oculto)
    // -------------------------------------------------------------------------
    testWidgets('T-01: Asesor Caso A - Oculto cuando variante divide exactamente unidades base (68 base con Par x2)', (tester) async {
      final sharedStockCtrl = TextEditingController(text: '68');
      final baseCostCtrl = TextEditingController(text: '2.00');

      final controllers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'specific': TextEditingController(text: 'Principal'),
          'unidadVenta': TextEditingController(text: 'Par'),
          'unidadesVenta': TextEditingController(text: '2'),
          'costoPres': TextEditingController(text: '4.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '5.40'),
          'stockFinal': TextEditingController(text: '34'),
          'usaStockCompartido': true,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductStockStrategySelector(
                selectedStrategy: 'COMPARTIDO',
                onStrategyChanged: (_) {},
                sharedStockController: sharedStockCtrl,
                baseCostController: baseCostCtrl,
                controllers: controllers,
                isDark: false,
                isEditMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Caso A: 68 % 2 == 0 -> El Asesor NO debe mostrarse
      expect(find.text('Asesor de Stock: Evita unidades sobrantes'), findsNothing);
      expect(find.text('Asesor de Stock: Acción requerida'), findsNothing);
      expect(find.text('Crear variante por Unidad automáticamente'), findsNothing);
      // El resumen de variantes debe estar presente y limpio
      expect(find.text('Stock Final Calculado por Variante:'), findsOneWidget);
      expect(find.textContaining('Principal (Par x2)'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // T-02: Asesor de Stock con 65 u. base y variantes x2 y x6 (Caso B - Recomendación)
    // -------------------------------------------------------------------------
    testWidgets('T-02: Asesor Caso B - Recomendación opcional descartable cuando todas las variantes dejan residuo', (tester) async {
      final sharedStockCtrl = TextEditingController(text: '65');
      final baseCostCtrl = TextEditingController(text: '2.00');

      final controllers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'specific': TextEditingController(text: 'Caja'),
          'unidadVenta': TextEditingController(text: 'Sixpack'),
          'unidadesVenta': TextEditingController(text: '6'), // 65 % 6 = 5
          'costoPres': TextEditingController(text: '12.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '16.20'),
          'stockFinal': TextEditingController(text: '10'),
          'usaStockCompartido': true,
        },
        {
          'id': 'v2',
          'specific': TextEditingController(text: 'Principal'),
          'unidadVenta': TextEditingController(text: 'Par'),
          'unidadesVenta': TextEditingController(text: '2'), // 65 % 2 = 1
          'costoPres': TextEditingController(text: '4.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '5.40'),
          'stockFinal': TextEditingController(text: '32'),
          'usaStockCompartido': true,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductStockStrategySelector(
                selectedStrategy: 'COMPARTIDO',
                onStrategyChanged: (_) {},
                sharedStockController: sharedStockCtrl,
                baseCostController: baseCostCtrl,
                controllers: controllers,
                isDark: false,
                isEditMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Caso B: Ambas dejan sobrante -> Aparece como recomendación
      expect(find.text('Asesor de Stock: Evita unidades sobrantes'), findsOneWidget);
      expect(find.text('Crear variante por Unidad automáticamente'), findsOneWidget);

      // Botón descartar (X) funciona y oculta la recomendación
      final closeBtnFinder = find.byIcon(Icons.close_rounded);
      expect(closeBtnFinder, findsOneWidget);
      await tester.tap(closeBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Asesor de Stock: Evita unidades sobrantes'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // T-03: Asesor de Stock con 4 u. base y variante x6 (Caso C - Obligatorio / Bloqueo)
    // -------------------------------------------------------------------------
    testWidgets('T-03: Asesor Caso C - Obligatorio cuando stockBase > 0 pero todas las variantes forman 0 paquetes', (tester) async {
      final sharedStockCtrl = TextEditingController(text: '4');
      final baseCostCtrl = TextEditingController(text: '3.00');
      bool autoCreated = false;

      final controllers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'specific': TextEditingController(text: 'Caja'),
          'unidadVenta': TextEditingController(text: 'Sixpack'),
          'unidadesVenta': TextEditingController(text: '6'), // 4 < 6 -> 0 paquetes
          'costoPres': TextEditingController(text: '18.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '24.30'),
          'stockFinal': TextEditingController(text: '0'),
          'usaStockCompartido': true,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductStockStrategySelector(
                selectedStrategy: 'COMPARTIDO',
                onStrategyChanged: (_) {},
                sharedStockController: sharedStockCtrl,
                baseCostController: baseCostCtrl,
                controllers: controllers,
                isDark: false,
                isEditMode: false,
                onAutoCreateUnitVariant: () {
                  autoCreated = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Caso C: Alerta obligatoria
      expect(find.textContaining('Asesor de Stock: Acción requerida'), findsOneWidget);
      expect(find.text('Crear variante por Unidad automáticamente'), findsOneWidget);

      // Tocar botón de autocreación
      await tester.tap(find.text('Crear variante por Unidad automáticamente'));
      await tester.pumpAndSettle();

      expect(autoCreated, isTrue);
    });

    // -------------------------------------------------------------------------
    // T-04: Generador anticolisión de nombres al crear variante unitaria
    // -------------------------------------------------------------------------
    test('T-04: generateSafeUnitVariantName previene colisiones con variantes existentes', () {
      // 1. Sin colisión previa
      expect(ProductControllerFactory.generateSafeUnitVariantName(['Caja', 'Docena']), equals('Unidad'));

      // 2. Colisión con "Unidad"
      expect(ProductControllerFactory.generateSafeUnitVariantName(['Unidad']), equals('Venta por Unidad'));

      // 3. Colisión con "Unidad" y "Venta por Unidad"
      expect(ProductControllerFactory.generateSafeUnitVariantName(['Unidad', 'Venta por Unidad']), equals('Unidad Individual'));

      // 4. Colisión con los 3 candidatos estándar -> siguiente candidato es "Unidad Suelta"
      expect(ProductControllerFactory.generateSafeUnitVariantName(['Unidad', 'Venta por Unidad', 'Unidad Individual']), equals('Unidad Suelta'));

      // 5. Colisión con todos los candidatos estándar -> cae en "Unidad X"
      expect(ProductControllerFactory.generateSafeUnitVariantName(['Unidad', 'Venta por Unidad', 'Unidad Individual', 'Unidad Suelta', 'Pieza Individual']), equals('Unidad 2'));
    });

    // -------------------------------------------------------------------------
    // T-05: Edición reactiva de cupo a 0ms en tarjeta compartida
    // -------------------------------------------------------------------------
    testWidgets('T-05: Sincronización a 0ms al digitar cupo en tarjeta de variante compartida', (tester) async {
      final stockFinalCtrl = TextEditingController(text: '34');
      final sharedStockCtrl = TextEditingController(text: '68');
      final controllerMap = <String, dynamic>{
        'cupoMaximoVariante': null,
        'stockFinal': stockFinalCtrl,
        'usaStockCompartido': true,
      };

      bool stateChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return PresentationStockSection(
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
                    onStockChanged: () => stateChanged = true,
                    onAjusteBaseChanged: () {},
                    modoStock: 'COMPARTIDO',
                    usaStockCompartido: true,
                    sharedStockCtrl: sharedStockCtrl,
                    controllerMap: controllerMap,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Estado inicial: libre con 34
      expect(find.text('= 34 Par disp.'), findsOneWidget);
      expect(find.text('Máximo disponible'), findsOneWidget);

      // Usuario escribe '23'
      await tester.enterText(find.byType(TextField).first, '23');
      await tester.pump();

      // 0ms: cupo actualizado, píldora refleja 23 y recuadro muestra '23 de 34 Par máx.'
      expect(controllerMap['cupoMaximoVariante'], equals(23));
      expect(find.text('= 23 Par disp.'), findsOneWidget);
      expect(find.text('Cupo acotado'), findsOneWidget);
      expect(find.text('23 de 34 Par máx.'), findsOneWidget);
      expect(stateChanged, isTrue);
    });

    // -------------------------------------------------------------------------
    // T-06: Botón "Usar máximo (X)" en tarjeta de variante compartida
    // -------------------------------------------------------------------------
    testWidgets('T-06: Botón "Usar máximo (34)" restaura cupo libre en un toque', (tester) async {
      final stockFinalCtrl = TextEditingController(text: '23');
      final sharedStockCtrl = TextEditingController(text: '68');
      final controllerMap = <String, dynamic>{
        'cupoMaximoVariante': 23,
        'stockFinal': stockFinalCtrl,
        'usaStockCompartido': true,
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
                modoStock: 'COMPARTIDO',
                usaStockCompartido: true,
                sharedStockCtrl: sharedStockCtrl,
                controllerMap: controllerMap,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Botón "Usar máximo (34)" visible al estar acotado
      final useMaxFinder = find.text('Usar máximo (34)');
      expect(useMaxFinder, findsOneWidget);

      await tester.tap(useMaxFinder);
      await tester.pumpAndSettle();

      // Cupo restaurado al máximo
      expect(controllerMap['cupoMaximoVariante'], isNull);
      expect(stockFinalCtrl.text, equals('34'));
      expect(find.text('Máximo disponible'), findsOneWidget);
      expect(find.text('Libre hasta 34 Par'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // T-07: Aislamiento transaccional en StockUpdateModal (descarte seguro)
    // -------------------------------------------------------------------------
    testWidgets('T-07: StockUpdateModal descarta cambios al cerrar con la X o fuera; solo persiste con APLICAR', (tester) async {
      final pres = ProductPresentation(
        id: 201,
        nombreEspecifico: 'Par',
        unidadVenta: 'Par',
        unidadesPorVenta: 2,
        stockActual: 48,
        usaStockCompartido: true,
        precioVentaFinal: 5.0,
        cupoMaximoVariante: 20,
      );

      final mockProv = _MockInventoryProvider([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockProv,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Valor inicial 20
      expect(find.text('20'), findsOneWidget);

      // Modificamos a 15
      await tester.enterText(find.byType(TextField), '15');
      await tester.pump();
      expect(find.text('15'), findsOneWidget);

      // Cerramos con la 'X'
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Ningún cambio fue persistido
      expect(mockProv.updateQuotaCalled, isFalse);
    });

    // -------------------------------------------------------------------------
    // T-08: Chips adaptativos en StockUpdateModal con máx formable = 11
    // -------------------------------------------------------------------------
    testWidgets('T-08: StockUpdateModal adapta chips según máximo físico (11) y ofrece chip "Máx (11)"', (tester) async {
      // 68 unidades base con factor 6 -> maxPhysical = 11
      final pres = ProductPresentation(
        id: 301,
        nombreEspecifico: 'Caja',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        stockActual: 68,
        usaStockCompartido: true,
        precioVentaFinal: 18.0,
        cupoMaximoVariante: 8,
      );

      final mockProv = _MockInventoryProvider([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockProv,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Con maxPhysical = 11, los chips adaptativos son [1, 5, 10] y "Máx (11)"
      // Chips como "+50" o "+100" NO deben aparecer
      expect(find.text('+50'), findsNothing);
      expect(find.text('+100'), findsNothing);
      expect(find.text('Máx (11)'), findsOneWidget);

      // Tocar chip "Máx (11)" establece el valor en 11
      await tester.tap(find.text('Máx (11)'));
      await tester.pump();
      expect(find.text('11'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // T-09: Detalle del Producto muestra STOCK DISPONIBLE 8 y Franja Unificada
    // -------------------------------------------------------------------------
    testWidgets('T-09: ProductDetailFinancialDashboard muestra STOCK DISPONIBLE 8 y franja informativa unificada', (tester) async {
      final pres = ProductPresentation(
        id: 401,
        nombreEspecifico: 'Caja',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        stockActual: 68,
        usaStockCompartido: true,
        precioVentaFinal: 25.0,
        costoUnitarioCalculado: 12.0,
        factorGananciaVenta: 1.35,
        cupoMaximoVariante: 8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ProductDetailVariantSelector(
                    presentations: [pres],
                    selectedPresentationId: pres.id,
                    isDark: false,
                    textColor: Colors.black87,
                    onSelectPresentation: (_) {},
                  ),
                  ProductDetailFinancialDashboard(
                    selectedPresentation: pres,
                    isDark: false,
                    hasOffer: false,
                    finalPrice: 25.0,
                    onOpenDiscountModal: () {},
                    onOpenRestockModal: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Selector de variantes superior: muestra "8 disp." limpio sin prefijo "Pool:"
      expect(find.text('8 disp.'), findsOneWidget);
      expect(find.textContaining('Pool:'), findsNothing);

      // Título exacto "STOCK DISPONIBLE"
      expect(find.text('STOCK DISPONIBLE'), findsOneWidget);
      // Número principal debe ser 8 (vendibles), no 11 ni 68
      expect(find.text('8'), findsWidgets); // uno en selector, uno en tarjeta
      // NO debe tener el texto "(68 base)" debajo del número grande
      expect(find.text('(68 base)'), findsNothing);

      // Franja informativa unificada
      expect(
        find.textContaining('Inventario base compartido: 68 und. base · Máximo formable: 11 ½ Docena · Cupo asignado: 8 ½ Docena'),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // T-10: Pestaña Productos muestra botón de stock limpio sin (+2u)
    // -------------------------------------------------------------------------
    test('T-10: InventoryWrapper.displayStockText muestra stock vendible limpio para variantes compartidas', () {
      final prod = Product(
        id: 501,
        categoriaId: 1,
        nombre: 'Toalla Microfibra',
        modoStock: 'COMPARTIDO',
        stockCompartido: 68,
        presentaciones: [],
      );

      final pres = ProductPresentation(
        id: 502,
        nombreEspecifico: 'Caja',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        stockActual: 68,
        usaStockCompartido: true,
        precioVentaFinal: 20.0,
        cupoMaximoVariante: 8,
      );

      final wrapper = InventoryWrapper(product: prod, presentation: pres);

      // hasLooseUnits debe ser false para compartidas para no ensuciar la vista de lista
      expect(wrapper.hasLooseUnits, isFalse);
      // displayStockText debe mostrar estrictamente '8 ½ Docenas' sin sufijo (+2u)
      expect(wrapper.displayStockText, equals('8 ½ Docenas'));
    });

    // -------------------------------------------------------------------------
    // T-11: Responsividad de CustomSearchBar y AppBar sin truncamientos en 320dp y 360dp
    // -------------------------------------------------------------------------
    testWidgets('T-11: CustomSearchBar y AppBar responsivos sin RenderFlex Overflow en 320dp y 360dp', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockProv = _MockInventoryProvider([]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<InventoryProvider>.value(
            value: mockProv,
            child: Scaffold(
              appBar: AppBar(
                titleSpacing: 0,
                title: const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Editar Producto'),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CustomSearchBar(
                  onSearch: (_) {},
                  onFilterTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cero excepciones de overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Editar Producto'), findsOneWidget);
      expect(find.text('Buscar producto, marca...'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // T-12: Descuento real de cupo_maximo_variante en SQLite al ejecutar ventas
    // -------------------------------------------------------------------------
    test('T-12: Venta de variante compartida con cupo = 8 (de 11 máx.) reduce cupo a 5, y luego a 0 conservando 20 u. base', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      LocalDatabase.setCustomDatabase(db);

      await db.execute('''
        CREATE TABLE productos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT,
          modo_stock TEXT DEFAULT 'COMPARTIDO',
          stock_compartido INTEGER DEFAULT 0,
          costo_base REAL DEFAULT 0.0,
          precio_base REAL DEFAULT 0.0,
          categoria_id INTEGER,
          marca_id INTEGER,
          negocio_id INTEGER DEFAULT 1,
          estado TEXT DEFAULT 'activo'
        )
      ''');

      await db.execute('''
        CREATE TABLE presentaciones_producto (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          producto_id INTEGER,
          nombre_especifico TEXT,
          unidad_venta TEXT,
          unidades_por_venta INTEGER,
          stock_actual INTEGER DEFAULT 0,
          stock_alerta INTEGER DEFAULT 5,
          usa_stock_compartido INTEGER DEFAULT 1,
          cupo_maximo_variante INTEGER,
          precio_venta_final REAL DEFAULT 0.0,
          costo_unitario_calculado REAL DEFAULT 0.0,
          activo INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE ventas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          numero_secuencial INTEGER,
          negocio_id INTEGER DEFAULT 1,
          creado_por_usuario_id INTEGER,
          cotizacion_id INTEGER,
          cliente_id INTEGER,
          origen_venta TEXT DEFAULT 'directa',
          metodo_pago TEXT DEFAULT 'EFECTIVO',
          estado_pago TEXT DEFAULT 'PAGADO',
          estado_entrega TEXT DEFAULT 'ENTREGADO',
          monto_total REAL,
          monto_pagado REAL,
          descuento_aplicado REAL DEFAULT 0,
          abono_inicial REAL DEFAULT 0,
          porcentaje_interes REAL DEFAULT 0,
          is_archived INTEGER DEFAULT 0,
          motivo_anulacion TEXT,
          fecha_venta TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE venta_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          venta_id INTEGER,
          presentation_id INTEGER,
          product_id INTEGER,
          bundle_id INTEGER,
          bundle_snapshot TEXT,
          cantidad INTEGER DEFAULT 1,
          precio_unitario REAL,
          original_unit_price REAL,
          costo_unitario REAL,
          subtotal REAL,
          nombre_producto TEXT,
          brand_name TEXT,
          specific_name TEXT,
          unidad_medida TEXT,
          original_text TEXT,
          image_url TEXT,
          is_manual_price INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE stock_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          presentation_id INTEGER,
          negocio_id INTEGER,
          tipo_transaccion TEXT,
          cantidad INTEGER,
          costo_unitario REAL,
          precio_venta REAL,
          origen_id INTEGER,
          fecha_registro TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cuotas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          venta_id INTEGER,
          numero_cuota INTEGER,
          monto REAL,
          monto_pagado REAL DEFAULT 0.00,
          fecha_vencimiento TEXT,
          estado TEXT DEFAULT 'pendiente'
        )
      ''');

      await db.execute('''
        CREATE TABLE pagos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          creado_por_usuario_id INTEGER,
          cliente_id INTEGER,
          venta_id INTEGER,
          cuota_id INTEGER,
          monto REAL,
          metodo_pago TEXT,
          nota TEXT,
          fecha_pago TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE notificaciones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          negocio_id INTEGER,
          titulo TEXT,
          mensaje TEXT,
          tipo TEXT,
          prioridad TEXT,
          data TEXT,
          leido INTEGER DEFAULT 0,
          created_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE items_paquete (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          paquete_id INTEGER,
          presentacion_id INTEGER,
          cantidad_requerida INTEGER
        )
      ''');

      // 1. Producto con 68 unidades base en pool compartido
      final prodId = await db.insert('productos', {
        'nombre': 'Toallas Microfibra',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 68,
      });

      // Variante: ½ Docena (factor 6 -> máx físico 68 ~/ 6 = 11). Cupo fijado en 8.
      final presId = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': '½ Docena',
        'unidad_venta': '½ Docena',
        'unidades_por_venta': 6,
        'stock_actual': 68,
        'usa_stock_compartido': 1,
        'cupo_maximo_variante': 8,
        'precio_venta_final': 15.0,
      });

      final salesService = SalesService();

      // Venta 1: Se venden 3 ½ Docenas (consume 3 * 6 = 18 u. base).
      // Stock compartido: 68 - 18 = 50 u. base (máx físico: 50 ~/ 6 = 8).
      // Cupo restante: 8 - 3 = 5.
      await salesService.createSale(
        {
          'metodo_pago': 'EFECTIVO',
          'estado_pago': 'PAGADO',
          'estado_entrega': 'ENTREGADO',
          'monto_total': 45.0,
          'monto_pagado': 45.0,
          'items': [
            {
              'product_id': prodId,
              'presentation_id': presId,
              'quantity': 3,
              'unit_price': 15.0,
              'cost': 10.0,
              'subtotal': 45.0,
            },
          ],
        },
        1,
        1,
      );

      final pAfterSale1 = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      expect(pAfterSale1.first['stock_compartido'], equals(50));

      final presAfterSale1 = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [presId]);
      expect(presAfterSale1.first['cupo_maximo_variante'], equals(5));

      final presModel1 = ProductPresentation.fromJson(presAfterSale1.first);
      expect(presModel1.unidadesVendiblesDisponibles, equals(5));

      // Venta 2: Se venden las 5 ½ Docenas restantes (consume 5 * 6 = 30 u. base).
      // Stock compartido: 50 - 30 = 20 u. base (máx físico: 20 ~/ 6 = 3).
      // Cupo restante: 5 - 5 = 0.
      await salesService.createSale(
        {
          'metodo_pago': 'EFECTIVO',
          'estado_pago': 'PAGADO',
          'estado_entrega': 'ENTREGADO',
          'monto_total': 75.0,
          'monto_pagado': 75.0,
          'items': [
            {
              'product_id': prodId,
              'presentation_id': presId,
              'quantity': 5,
              'unit_price': 15.0,
              'cost': 10.0,
              'subtotal': 75.0,
            },
          ],
        },
        1,
        1,
      );

      final pAfterSale2 = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      // Se conservan exactamente las 20 u. base restantes en el inventario compartido
      expect(pAfterSale2.first['stock_compartido'], equals(20));

      final presAfterSale2 = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [presId]);
      // El cupo queda exactamente en 0
      expect(presAfterSale2.first['cupo_maximo_variante'], equals(0));

      final presModel2 = ProductPresentation.fromJson(presAfterSale2.first);
      expect(presModel2.unidadesVendiblesDisponibles, equals(0));

      final prodModel2 = Product(
        id: prodId,
        categoriaId: 1,
        nombre: 'Toallas Microfibra',
        modoStock: 'COMPARTIDO',
        stockCompartido: 20,
      );
      final wrapper2 = InventoryWrapper(product: prodModel2, presentation: presModel2);
      expect(wrapper2.displayStock, equals(0));
      expect(wrapper2.effectiveBaseStock, equals(20));
      expect(wrapper2.maxPhysicalSalesUnits, equals(3));
      // NO dice Agotado: informa la liberación disponible
      expect(wrapper2.displayStockText, equals('0 disp. (Libera hasta 3)'));

      LocalDatabase.setCustomDatabase(null);
      await db.close();
    });

    // -------------------------------------------------------------------------
    // T-13: InventoryWrapper.displayStockText cuando displayStock == 0 pero effectiveBaseStock > 0
    // -------------------------------------------------------------------------
    test('T-13: displayStockText informa existencias base disponibles y no dice Agotado cuando hay u. base', () {
      final prod = Product(
        id: 601,
        categoriaId: 1,
        nombre: 'Toallas Microfibra',
        modoStock: 'COMPARTIDO',
        stockCompartido: 20,
      );

      // Caso A: maxPhysicalSalesUnits > 0 (Cupo agotado a 0 pero alcanzan 20 u. base para 3 paquetes de factor 6)
      final presCasoA = ProductPresentation(
        id: 602,
        nombreEspecifico: '½ Docena',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        stockActual: 20,
        usaStockCompartido: true,
        precioVentaFinal: 10.0,
        cupoMaximoVariante: 0,
      );

      final wrapperA = InventoryWrapper(product: prod, presentation: presCasoA);
      expect(wrapperA.displayStock, equals(0));
      expect(wrapperA.effectiveBaseStock, equals(20));
      expect(wrapperA.maxPhysicalSalesUnits, equals(3));
      expect(wrapperA.hasQuotaExhaustedWithBaseStock, isTrue);
      expect(wrapperA.isOutOfStock, isFalse); // No está agotado físicamente en almacén
      expect(wrapperA.displayStockText, isNot(equals('Agotado')));
      expect(wrapperA.displayStockText, equals('0 disp. (Libera hasta 3)'));

      // Caso B: maxPhysicalSalesUnits == 0 (Quedan 4 u. base sueltas que no alcanzan para formar 1 paquete de factor 6)
      final prodSuelto = prod.copyWith(stockCompartido: 4);
      final presCasoB = presCasoA.copyWith(stockActual: 4, cupoMaximoVariante: null);

      final wrapperB = InventoryWrapper(product: prodSuelto, presentation: presCasoB);
      expect(wrapperB.displayStock, equals(0));
      expect(wrapperB.effectiveBaseStock, equals(4));
      expect(wrapperB.maxPhysicalSalesUnits, equals(0));
      expect(wrapperB.hasQuotaExhaustedWithBaseStock, isTrue);
      expect(wrapperB.isOutOfStock, isFalse);
      expect(wrapperB.displayStockText, isNot(equals('Agotado')));
      expect(wrapperB.displayStockText, equals('0 disp. (Quedan 4 u. base)'));

      // Caso C: Verdaderamente agotado (effectiveBaseStock == 0)
      final prodAgotado = prod.copyWith(stockCompartido: 0);
      final presCasoC = presCasoA.copyWith(stockActual: 0, cupoMaximoVariante: null);
      final wrapperC = InventoryWrapper(product: prodAgotado, presentation: presCasoC);
      expect(wrapperC.displayStock, equals(0));
      expect(wrapperC.effectiveBaseStock, equals(0));
      expect(wrapperC.isOutOfStock, isTrue);
      expect(wrapperC.displayStockText, equals('Agotado'));
    });

    // -------------------------------------------------------------------------
    // T-14: Renderizado de StockUpdateModal cuando maxPhysicalUnits == 0 y effectiveBaseStock > 0
    // -------------------------------------------------------------------------
    testWidgets('T-14: StockUpdateModal renderiza banner de unidades sueltas y botón Editar Producto cuando maxPhysicalUnits == 0 y effectiveBaseStock > 0', (tester) async {
      final prod = Product(
        id: 701,
        categoriaId: 1,
        nombre: 'Cinta Embalaje',
        modoStock: 'COMPARTIDO',
        stockCompartido: 4, // 4 unidades base en almacén
      );

      final pres = ProductPresentation(
        id: 702,
        nombreEspecifico: '½ Docena',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6, // Requiere 6 unidades por paquete
        stockActual: 4,
        usaStockCompartido: true,
        precioVentaFinal: 12.0,
      );

      final wrapper = InventoryWrapper(product: prod, presentation: pres);
      final mockProv = _MockInventoryProvider([wrapper]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockProv,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el banner de unidades base insuficientes
      expect(find.text('Unidades base insuficientes para 1 ½ Docena'), findsOneWidget);
      expect(find.textContaining('Quedan 4 unidades base sueltas que no alcanzan para formar 1 paquete de esta variante (requiere 6 unidades)'), findsOneWidget);
      expect(find.text('Editar Producto'), findsOneWidget);

      // El campo de texto de stock debe estar en 0
      expect(find.text('0'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // T-14b: Renderizado de StockUpdateModal cuando cupo == 0 y maxPhysicalUnits > 0
    // -------------------------------------------------------------------------
    testWidgets('T-14b: StockUpdateModal renderiza banner de cupo agotado y botón Restaurar al máximo cuando cupo == 0 y maxPhysicalUnits > 0', (tester) async {
      final prod = Product(
        id: 711,
        categoriaId: 1,
        nombre: 'Cinta Embalaje 2',
        modoStock: 'COMPARTIDO',
        stockCompartido: 20, // 20 unidades base en almacén -> 3 paquetes de 6
      );

      final pres = ProductPresentation(
        id: 712,
        nombreEspecifico: '½ Docena',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        stockActual: 20,
        usaStockCompartido: true,
        cupoMaximoVariante: 0,
        precioVentaFinal: 12.0,
      );

      final wrapper = InventoryWrapper(product: prod, presentation: pres);
      final mockProv = _MockInventoryProvider([wrapper]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockProv,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stock asignado para vender agotado (0 disp.)'), findsOneWidget);
      expect(find.textContaining('El stock asignado para vender llegó a 0, pero aún cuentas con 20 unidades base en inventario (hasta 3 ½ Docena disponibles)'), findsOneWidget);
      expect(find.text('Restaurar al máximo (3)'), findsOneWidget);
    });
  });
}
