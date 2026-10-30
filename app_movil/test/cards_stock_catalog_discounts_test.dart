import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/widgets/inventory_item_tile.dart';
import 'package:app_movil/core/widgets/inventory_grid_card.dart';
import 'package:app_movil/core/widgets/inventory_compact_tile.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/catalog_item_card.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_discount_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_mapper.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_operations.dart';

import 'package:app_movil/features/catalog/widgets/quick_restock_modal.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/core/widgets/discount_intelligent_modal.dart';

class MockInventoryProvider extends InventoryProvider {
  int? lastUpdatedPresentationId;
  int? lastStock;
  double? lastPrecioVentaFinal;
  double? lastOferta;
  String? lastTipoDesc;
  double? lastValorDesc;

  final List<InventoryWrapper> testItems = [];

  @override
  List<InventoryWrapper> get items => testItems;

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
  }) async {
    lastUpdatedPresentationId = presentationId;
    lastStock = stock;
    lastPrecioVentaFinal = precioVentaFinal;
    lastOferta = oferta;
    lastTipoDesc = tipoDesc;
    lastValorDesc = valorDesc;
    return true;
  }
}

void main() {
  group('FASE 1: Blindaje de las 3 Vistas de Tarjetas en Inventario y Cero Duplicidad de Etiqueta Roja', () {
    final prod = Product(
      id: 1,
      nombre: "Plumón Permanente Punta Fina Negro",
      categoriaId: 10,
      marcaId: 5,
    );

    final presLargo = ProductPresentation(
      id: 101,
      nombreEspecifico: "Caja x 50 Unidades",
      precioVentaFinal: 99999.99,
      precioOferta: 84999.99,
      tipoDescuento: 'porcentaje',
      valorDescuento: 15.0,
      stockActual: 5708880,
      unidadVenta: 'Unidades',
      unidadesPorVenta: 1,
    );

    final wrapper = InventoryWrapper(product: prod, presentation: presLargo);

    testWidgets('InventoryItemTile: stock millonario y precio largo sin ellipsis ni colisiones', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<InventoryProvider>(
          create: (_) => MockInventoryProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  SizedBox(
                    width: 360,
                    child: InventoryItemTile(
                      item: wrapper,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el stock millonario completo sin truncamiento
      expect(find.text("5708880 Unidades"), findsOneWidget);
      expect(find.text("S/ 84999.99"), findsOneWidget);
      expect(find.text("S/ 99999.99"), findsOneWidget);

      // Etiqueta roja -15% solo existe una vez (sobre la imagen)
      expect(find.text("-15%"), findsOneWidget);

      // Verificar que el widget Text de stock no use TextOverflow.ellipsis
      final stockTextWidget = tester.widget<Text>(find.text("5708880 Unidades"));
      expect(stockTextWidget.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('InventoryGridCard: stock no truncado con ellipsis y una sola etiqueta de descuento', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<InventoryProvider>(
          create: (_) => MockInventoryProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 320,
                child: InventoryGridCard(
                  item: wrapper,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("5708880 Unidades"), findsOneWidget);
      expect(find.text("S/ 84999.99"), findsOneWidget);
      expect(find.text("S/ 99999.99"), findsOneWidget);

      // Solo una etiqueta roja de oferta
      expect(find.text("-15%"), findsOneWidget);

      final stockText = tester.widget<Text>(find.text("5708880 Unidades"));
      expect(stockText.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('InventoryCompactTile: precios apilados y cero duplicidad de etiqueta roja', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<InventoryProvider>(
          create: (_) => MockInventoryProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  SizedBox(
                    width: 360,
                    child: InventoryCompactTile(
                      item: wrapper,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("5708880 Unidades"), findsOneWidget);
      expect(find.text("S/ 84999.99"), findsOneWidget);
      expect(find.text("S/ 99999.99"), findsOneWidget);

      // Única etiqueta roja de descuento visible sobre el avatar izquierdo (Punto 1)
      expect(find.text("-15%"), findsOneWidget);
    });
  });

  group('FASE 2: Exactitud del Resumen en StockUpdateModal y QuickRestockModal', () {
    testWidgets('StockUpdateModal opera exclusivamente por unidad de venta y persiste base multiplicada', (tester) async {
      final mockProvider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 77,
        precioVentaFinal: 10.0,
        unidadVenta: 'Par',
        unidadesPorVenta: 2,
        stockActual: 10, // 5 pares = 10 unidades base
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockProvider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cero chip "Por Unidad base" y cero botón "Cuadrar"
      expect(find.text("Por Unidad base"), findsNothing);
      expect(find.text("⚡ Cuadrar"), findsNothing);
      expect(find.text("Por Par (x2)"), findsOneWidget);

      // Cambiar explícitamente a Modo 0 (Sumar Compra): ingresar 10 pares
      await tester.tap(find.text("Sumar Compra"));
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      expect(inputField, findsOneWidget);
      await tester.enterText(inputField, "10");
      await tester.pumpAndSettle();

      // En Sumar Compra con stock inicial 10 base (5 pares) + 10 pares = 15 pares = 30 base
      expect(find.text("Resultado: 15 Par = 30 unidades base"), findsOneWidget);

      // Aplicar cambios
      await tester.tap(find.text("APLICAR CAMBIOS"));
      await tester.pumpAndSettle();

      expect(mockProvider.lastUpdatedPresentationId, 77);
      expect(mockProvider.lastStock, 30); // 15 pares * factor 2 = 30 unidades base
    });

    testWidgets('StockUpdateModal en Modo Fijar Stock Total (Modo 1) muestra stock fijado y persiste', (tester) async {
      final mockProvider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 88,
        precioVentaFinal: 20.0,
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 24, // 2 docenas
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockProvider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cambiar a Modo Fijar Stock Total
      await tester.tap(find.text("Fijar Stock Total"));
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, "5");
      await tester.pumpAndSettle();

      // Resultado en Fijar: 5 Docena = 60 unidades base
      expect(find.text("Resultado: 5 Docena = 60 unidades base"), findsOneWidget);

      await tester.tap(find.text("APLICAR CAMBIOS"));
      await tester.pumpAndSettle();

      expect(mockProvider.lastUpdatedPresentationId, 88);
      expect(mockProvider.lastStock, 60); // 5 docenas * factor 12 = 60 base
    });

    testWidgets('StockUpdateModal con unidades residuales muestra advertencia condicional, verdad contable y cuadra con consentimiento', (tester) async {
      final mockProvider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 99,
        precioVentaFinal: 25.0,
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 37, // 3 docenas + 1 u. base suelta
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockProvider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar advertencia de 1 u. base suelta(s)
      expect(find.textContaining("1 u. base suelta(s) que no completan un Docena (x12)"), findsOneWidget);
      expect(find.text("🛠️ Ir a Editar"), findsOneWidget);
      expect(find.text("⚡ Cuadrar aquí"), findsOneWidget);

      // Cambiar a Modo 0 (Sumar Compra) para verificar verdad contable preservando residuo
      await tester.tap(find.text("Sumar Compra"));
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, "0");
      await tester.pumpAndSettle();

      expect(find.text("Resultado: 3 Docena (+ 1 u. base suelta) = 37 unidades base"), findsOneWidget);

      // Si el usuario pulsa "⚡ Cuadrar aquí" con consentimiento explícito:
      await tester.tap(find.text("⚡ Cuadrar aquí"));
      await tester.pumpAndSettle();

      // Ya no hay residuo: banner desaparece y resultado muestra múltiplos exactos
      expect(find.textContaining("1 u. base suelta(s) que no completan un Docena (x12)"), findsNothing);
      expect(find.text("Resultado: 3 Docena = 36 unidades base"), findsOneWidget);

      // Aplicar cambios
      await tester.tap(find.text("APLICAR CAMBIOS"));
      await tester.pumpAndSettle();

      expect(mockProvider.lastUpdatedPresentationId, 99);
      expect(mockProvider.lastStock, 36);
    });

    testWidgets('QuickRestockModal con residuo muestra verdad contable y permite cuadrar aquí', (tester) async {
      final mockProvider = MockInventoryProvider();
      final prod = Product(id: 1, nombre: "Cuaderno", categoriaId: 1);
      final pres = ProductPresentation(
        id: 100,
        precioVentaFinal: 30.0,
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 25, // 2 docenas + 1 u. base suelta
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<InventoryProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: QuickRestockModal(
                product: prod,
                presentation: pres,
                onRestockSuccess: () {},
                onNavigateToFullEdit: () {},
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advertencia presente
      expect(find.textContaining("1 u. base suelta(s) que no completan un Docena (x12)"), findsOneWidget);
      expect(find.text("⚡ Cuadrar aquí"), findsOneWidget);

      // En modo sumar 1 docena (default):
      // 25 + 12 = 37 base = 3 docenas + 1 u. base suelta
      expect(find.text("Docena (+1u)\n(37 u.)"), findsOneWidget);

      // Cuadrar aquí voluntariamente:
      await tester.tap(find.text("⚡ Cuadrar aquí"));
      await tester.pumpAndSettle();

      // Base inicial se volvió 24. Con 1 docena ingresada = 36 base = 3 docenas exactas
      expect(find.textContaining("1 u. base suelta(s) que no completan un Docena (x12)"), findsNothing);
      expect(find.text("Docena\n(36 u.)"), findsOneWidget);
    });
  });

  group('FASE 3: Compatibilidad Estricta de IntrinsicHeight en CatalogItemCard y CatalogScreen', () {
    testWidgets('CatalogItemCard cabecera fija, título 3 líneas y simetría exacta en IntrinsicHeight', (tester) async {
      final prod1 = Product(
        id: 1,
        nombre: "Cuaderno Espiral Universitario Cuadriculado 100 Hojas Papel Bond 75g Tapa Dura Plastificada",
        categoriaId: 1,
        marcaId: 1,
      );
      final pres1 = ProductPresentation(
        id: 201,
        nombreEspecifico: "Diseño Anime Edición Limitada",
        precioVentaFinal: 8.50,
        costoUnitarioCalculado: 5.20,
        unidadVenta: 'UNIDAD',
        unidadesPorVenta: 1,
        stockActual: 50,
      );
      final item1 = InventoryWrapper(product: prod1, presentation: pres1);

      final prod2 = Product(
        id: 2,
        nombre: "Lápiz 2B",
        categoriaId: 1,
        marcaId: 1,
      );
      final pres2 = ProductPresentation(
        id: 202,
        nombreEspecifico: "Negro",
        precioVentaFinal: 1.50,
        costoUnitarioCalculado: 0.80,
        unidadVenta: 'UNIDAD',
        unidadesPorVenta: 1,
        stockActual: 100,
      );
      final item2 = InventoryWrapper(product: prod2, presentation: pres2);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CatalogProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: CatalogItemCard(
                          key: const ValueKey('card_1'),
                          item: item1,
                          onDetails: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CatalogItemCard(
                          key: const ValueKey('card_2'),
                          item: item2,
                          onDetails: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que ambas tarjetas tienen la misma altura exacta calculada por IntrinsicHeight
      final size1 = tester.getSize(find.byKey(const ValueKey('card_1')));
      final size2 = tester.getSize(find.byKey(const ValueKey('card_2')));

      expect(size1.height, equals(size2.height));
      expect(size1.height, greaterThan(250));

      // Verificar que los datos financieros existen en ambas tarjetas
      expect(find.text("C: S/ 5.20"), findsOneWidget);
      expect(find.text("C: S/ 0.80"), findsOneWidget);
      expect(find.text("S/ 8.50"), findsOneWidget);
      expect(find.text("S/ 1.50"), findsOneWidget);
    });

    testWidgets('CatalogItemCard con costos largos y precios de 5 dígitos no colisiona ni usa FittedBox', (tester) async {
      final prod = Product(id: 9, nombre: "Kit de Arte Profesional", categoriaId: 1);
      final pres = ProductPresentation(
        id: 909,
        nombreEspecifico: "Set Completo Óleo y Acrílicos",
        costoUnitarioCalculado: 12500.00,
        precioVentaFinal: 15700.00,
        precioOferta: 13345.00,
        tipoDescuento: 'fijo',
        valorDescuento: 13345.00,
        stockActual: 50,
        unidadVenta: 'SET',
        unidadesPorVenta: 1,
      );
      final item = InventoryWrapper(product: prod, presentation: pres);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CatalogProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                child: IntrinsicHeight(
                  child: CatalogItemCard(
                    item: item,
                    onDetails: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verificamos presencia íntegra de textos financieros sin truncamiento
      expect(find.text("C: S/ 12500.00"), findsOneWidget);
      expect(find.text("S/ 15700.00"), findsOneWidget);
      expect(find.text("S/ 13345.00"), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('FASE 4: Unificación de monto/fijo y Blindaje Matemático en Módulo de Descuentos', () {
    late TextEditingController ventaCtrl;
    late TextEditingController valorDctoCtrl;
    late Map<String, dynamic> controllerMap;
    late PresentationMathEngine engine;

    setUp(() {
      ventaCtrl = TextEditingController(text: "1.00");
      valorDctoCtrl = TextEditingController(text: "0.85");
      controllerMap = {
        'descuentoActivo': true,
        'tipoDescuento': 'fijo',
        'precioOfertaExacto': null,
      };

      engine = PresentationMathEngine(
        controllerMap: controllerMap,
        onStateUpdate: () {},
        umpCompraCtrl: TextEditingController(),
        cantCompraCtrl: TextEditingController(),
        unidadesLoteCtrl: TextEditingController(text: "1"),
        totalPagoCtrl: TextEditingController(),
        specificCtrl: TextEditingController(),
        unidadVentaCtrl: TextEditingController(text: "Unidad"),
        unidadesVentaCtrl: TextEditingController(text: "1"),
        costoPresCtrl: TextEditingController(text: "0.50"),
        margenCtrl: TextEditingController(text: "2.00"),
        ventaCtrl: ventaCtrl,
        valorDescuentoCtrl: valorDctoCtrl,
        stockInicialCtrl: TextEditingController(text: "10"),
        nuevoIngresoCtrl: TextEditingController(text: "0"),
        stockDescuentoCtrl: TextEditingController(text: "0"),
        stockFinalCtrl: TextEditingController(text: "10"),
        ajusteBaseCtrl: TextEditingController(),
      );
      engine.init();
    });

    test('Modo S/ Fijo interpreta el input como Precio Final de Oferta y calcula ahorro', () {
      // Precio base 1.00, usuario ingresa 0.85 en S/ Fijo
      expect(engine.precioOferta, equals(0.85));

      // Ahorro es 1.00 - 0.85 = 0.15 y porcentaje es 15%
      final ahorro = 1.00 - engine.precioOferta!;
      expect(ahorro, closeTo(0.15, 0.001));

      final percent = (ahorro / 1.00) * 100;
      expect(percent.round(), equals(15));
    });

    testWidgets('PresentationDiscountSection muestra enunciado informativo exacto en S/ Fijo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresentationDiscountSection(
                descuentoActivo: true,
                tipoDescuento: 'fijo',
                valorDescuentoCtrl: valorDctoCtrl,
                precioVenta: 1.00,
                precioOferta: 0.85,
                isDark: false,
                onDiscountActiveChanged: (_) {},
                onDiscountTypeChanged: (_) {},
                onValueChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Módulo de Descuentos"));
      await tester.pumpAndSettle();

      // Debe mostrar el label Precio Oferta S/
      expect(find.text("Precio Oferta S/"), findsOneWidget);

      // Debe mostrar el enunciado explicativo exacto
      expect(
        find.text("Descuento aplicado: S/ 0.15 menos sobre el precio normal de S/ 1.00 (-15%)"),
        findsOneWidget,
      );

      // PRECIO FINAL [-15%] S/ 0.85
      expect(find.text("PRECIO FINAL:"), findsOneWidget);
      expect(find.text("-15%"), findsOneWidget);
      expect(find.text("S/ 0.85"), findsOneWidget);
    });

    test('Alternancia fluida entre % Porcentaje y S/ Fijo preserva precio de oferta sin drift', () {
      // Inicial en S/ Fijo con 0.85
      expect(controllerMap['tipoDescuento'], equals('fijo'));
      expect(valorDctoCtrl.text, equals("0.85"));
      expect(engine.precioOferta, equals(0.85));

      // Cambiar a % Porcentaje
      engine.switchDiscountType('porcentaje');
      expect(controllerMap['tipoDescuento'], equals('porcentaje'));
      expect(valorDctoCtrl.text, equals("15"));
      expect(engine.precioOferta, closeTo(0.85, 0.001));

      // Cambiar nuevamente a S/ Fijo
      engine.switchDiscountType('fijo');
      expect(controllerMap['tipoDescuento'], equals('fijo'));
      expect(valorDctoCtrl.text, equals("0.85"));
      expect(engine.precioOferta, equals(0.85));
    });

    test('Chips de redondeo (.50, .90, .00) y Toggle OFF restauran prístinamente el valor previo', () {
      // Estado inicial en S/ Fijo: 0.85
      expect(valorDctoCtrl.text, equals("0.85"));
      expect(engine.precioOferta, equals(0.85));

      // Activar chip .50 -> redondea a 0.50
      engine.roundDiscountPrice(0.50);
      expect(valorDctoCtrl.text, equals("0.50"));
      expect(engine.precioOferta, equals(0.50));
      expect(engine.activeDiscountRoundingTarget, equals(0.50));

      // Desactivar chip .50 (Toggle OFF) -> restaura a 0.85
      engine.roundDiscountPrice(0.50);
      expect(engine.activeDiscountRoundingTarget, isNull);
      expect(valorDctoCtrl.text, equals("0.85"));
      expect(engine.precioOferta, equals(0.85)); // Jamás degenera a 0.15 ni a 0.99
    });

    test('ProductFormMapper persiste precioOferta = 0.85 y tipoDescuento = fijo', () {
      final ctrlMap = ProductControllerFactory.createNewControllerMap(
        id: 'pres_1',
        dbId: 301,
        precioVenta: "1.00",
        descuentoActivo: true,
        tipoDescuento: 'fijo',
        valorDescuento: "0.85",
      );

      final presentations = ProductFormMapper.toPresentations(
        controllers: [ctrlMap],
      );

      expect(presentations.length, 1);
      final p = presentations.first;
      expect(p.precioVentaFinal, 1.00);
      expect(p.precioOferta, 0.85);
      expect(p.tipoDescuento, 'fijo');
      expect(p.valorDescuento, 0.85);
      expect(p.effectivePrice, 0.85);
      expect(p.discountPercentRounded, 15);
    });

    test('ProductEditOperations.loadInitialData hidrata correctamente producto con oferta guardada', () {
      final presGuardada = ProductPresentation(
        id: 401,
        precioVentaFinal: 1.00,
        precioOferta: 0.85,
        tipoDescuento: 'fijo',
        valorDescuento: 0.85,
        unidadesPorVenta: 1,
        stockActual: 10,
        esDefault: true,
      );

      final product = Product(
        id: 50,
        nombre: "Corrector Líquido",
        categoriaId: 1,
        marcaId: 1,
        presentaciones: [presGuardada],
      );

      final invProv = MockInventoryProvider();
      final controllers = <Map<String, dynamic>>[];
      final keys = <String, GlobalKey>{};

      ProductEditOperations.loadInitialData(
        product: product,
        invProv: invProv,
        nameCtrl: TextEditingController(),
        descCtrl: TextEditingController(),
        imgUrlCtrl: TextEditingController(),
        parentBarcodeCtrl: TextEditingController(),
        presentationControllers: controllers,
        presentationKeys: keys,
      );

      expect(controllers.length, 1);
      final c = controllers.first;
      expect(c['descuentoActivo'], isTrue);
      expect(c['tipoDescuento'], 'fijo');
      expect((c['valorDescuento'] as TextEditingController).text, "0.85");
      expect(c['precioOfertaExacto'], 0.85);
    });

    test('Sincronización 360° en vivo al cambiar precio de venta base en PresentationMathEngine', () {
      // Caso 1: En % Porcentaje (15%), cambiar precio base de 10.00 a 20.00
      final vCtrl = TextEditingController(text: "10.00");
      final dCtrl = TextEditingController(text: "15");
      final cMap = <String, dynamic>{
        'descuentoActivo': true,
        'tipoDescuento': 'porcentaje',
        'precioOfertaExacto': null,
      };

      final eng = PresentationMathEngine(
        controllerMap: cMap,
        onStateUpdate: () {},
        umpCompraCtrl: TextEditingController(),
        cantCompraCtrl: TextEditingController(),
        unidadesLoteCtrl: TextEditingController(text: "1"),
        totalPagoCtrl: TextEditingController(),
        specificCtrl: TextEditingController(),
        unidadVentaCtrl: TextEditingController(text: "Unidad"),
        unidadesVentaCtrl: TextEditingController(text: "1"),
        costoPresCtrl: TextEditingController(text: "5.00"),
        margenCtrl: TextEditingController(text: "2.00"),
        ventaCtrl: vCtrl,
        valorDescuentoCtrl: dCtrl,
        stockInicialCtrl: TextEditingController(text: "10"),
        nuevoIngresoCtrl: TextEditingController(text: "0"),
        stockDescuentoCtrl: TextEditingController(text: "0"),
        stockFinalCtrl: TextEditingController(text: "10"),
        ajusteBaseCtrl: TextEditingController(),
      );
      eng.init();

      // Inicial: 10.00 con 15% desc = 8.50
      expect(eng.precioOferta, closeTo(8.50, 0.001));

      // Usuario cambia precio de venta a 20.00
      vCtrl.text = "20.00";
      eng.recalcularPrecios(fromMargen: false);

      // Recálculo a 0ms: 20.00 con 15% desc = 17.00
      expect(eng.precioOferta, closeTo(17.00, 0.001));

      // Caso 2: En S/ Fijo (oferta deseada = 8.00)
      eng.switchDiscountType('fijo');
      dCtrl.text = "8.00";
      expect(eng.precioOferta, equals(8.00));

      // Si precio base baja a 7.00 (menor a la oferta de 8.00)
      vCtrl.text = "7.00";
      eng.recalcularPrecios(fromMargen: false);
      // Oferta inválida
      expect(eng.precioOferta, isNull);

      // Caso 3: Desmarcado automático de chip de redondeo al editar manualmente
      vCtrl.text = "20.00";
      dCtrl.text = "15.00";
      eng.recalcularPrecios(fromMargen: false);
      eng.roundDiscountPrice(0.50);
      expect(eng.activeDiscountRoundingTarget, equals(0.50));

      // Usuario escribe manualmente en el campo de descuento
      eng.onDiscountValueChanged();
      expect(eng.activeDiscountRoundingTarget, isNull);
      expect(cMap['preRoundedOfferPrice'], isNull);
    });

    testWidgets('PriceUpdateModal permite alternancia entre % y S/ Fijo y persiste tipoDesc fijo', (tester) async {
      final mockProvider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 505,
        precioVentaFinal: 10.0,
        stockActual: 20,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceUpdateModal(
              presentation: pres,
              provider: mockProvider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente en % Porcentaje: escribir 20%
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), "20");
      await tester.pumpAndSettle();

      // Cambiar a pestaña S/ Fijo: debe convertir 20% sobre 10.0 a 8.00
      await tester.tap(find.text("S/ Fijo"));
      await tester.pumpAndSettle();

      expect(find.text("8.00"), findsOneWidget);

      // Aplicar cambios
      await tester.tap(find.text("APLICAR CAMBIOS"));
      await tester.pumpAndSettle();

      expect(mockProvider.lastUpdatedPresentationId, 505);
      expect(mockProvider.lastOferta, equals(8.00));
      expect(mockProvider.lastTipoDesc, equals('fijo'));
    });

    testWidgets('DiscountIntelligentModal persiste oferta y tipoDesc con paridad 100%', (tester) async {
      final mockProvider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 606,
        precioVentaFinal: 10.0,
        stockActual: 20,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscountIntelligentModal(
              presentation: pres,
              provider: mockProvider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Activar switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Por defecto en S/ Fijo: ingresar 7.50
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, "7.50");
      await tester.pumpAndSettle();

      // Banner explicativo presente
      expect(find.textContaining("Descuento aplicado: S/ 2.50 menos sobre el precio normal de S/ 10.00"), findsOneWidget);

      // Guardar descuento
      await tester.tap(find.text("Aplicar Cambios"));
      await tester.pumpAndSettle();

      expect(mockProvider.lastUpdatedPresentationId, 606);
      expect(mockProvider.lastOferta, equals(7.50));
      expect(mockProvider.lastTipoDesc, equals('fijo'));
    });
  });
}
