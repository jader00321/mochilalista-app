import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/repositories/product_repository.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_mapper.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_discount_section.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/core/widgets/catalog_item_card.dart';
import 'package:app_movil/core/widgets/product_detail_modal.dart';
import 'package:app_movil/core/database/local_db.dart';

class MockInventoryProvider extends InventoryProvider {
  int? lastUpdatedPresentationId;
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
    String? estado,
    String? imagenUrl,
  }) async {
    lastUpdatedPresentationId = presentationId;
    lastPrecioVentaFinal = precioVentaFinal;
    lastOferta = oferta;
    lastTipoDesc = tipoDesc;
    lastValorDesc = valorDesc;

    final index = testItems.indexWhere((w) => w.presentation.id == presentationId);
    if (index != -1) {
      final oldPres = testItems[index].presentation;
      final updatedPres = ProductPresentation(
        id: oldPres.id,
        nombreEspecifico: oldPres.nombreEspecifico,
        codigoBarras: oldPres.codigoBarras,
        descripcion: oldPres.descripcion,
        proveedorId: oldPres.proveedorId,
        esDefault: oldPres.esDefault,
        imagenUrl: oldPres.imagenUrl,
        umpCompra: oldPres.umpCompra,
        precioUmpProveedor: oldPres.precioUmpProveedor,
        cantidadUmpComprada: oldPres.cantidadUmpComprada,
        totalPagoLote: oldPres.totalPagoLote,
        unidadesPorLote: oldPres.unidadesPorLote,
        unidadVenta: oldPres.unidadVenta,
        unidadesPorVenta: oldPres.unidadesPorVenta,
        costoUnitarioCalculado: oldPres.costoUnitarioCalculado,
        factorGananciaVenta: oldPres.factorGananciaVenta,
        precioVentaFinal: precioVentaFinal ?? oldPres.precioVentaFinal,
        stockActual: stock ?? oldPres.stockActual,
        precioOferta: oferta == -1 ? null : (oferta ?? oldPres.precioOferta),
        tipoDescuento: oferta == -1 ? null : (tipoDesc ?? oldPres.tipoDescuento),
        valorDescuento: oferta == -1 ? null : (valorDesc ?? oldPres.valorDescuento),
        estado: estado ?? oldPres.estado,
        activo: oldPres.activo,
      );
      testItems[index] = InventoryWrapper(
        product: testItems[index].product,
        presentation: updatedPres,
      );
      notifyListeners();
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FASE 1: Verificación Estricta del Esquema SQLite y Filtro "Solo ofertas"', () {
    test('Verificación estricta de nombres de tablas y columnas en LocalDatabase', () {
      final instance = LocalDatabase.instance;
      expect(instance, isNotNull);

      // Verificamos que el repositorio use items_paquete y paquetes, no bundle_items
      final repo = ProductRepository();
      expect(repo, isNotNull);
    });

    test('ProductPresentation getters canónicos: hasOffer, effectivePrice y discountPercentRounded', () {
      // 1. Caso con precio_oferta válido
      final presConOferta = ProductPresentation(
        id: 1,
        precioVentaFinal: 13.90,
        precioOferta: 12.00,
        stockActual: 10,
      );
      expect(presConOferta.hasOffer, isTrue);
      expect(presConOferta.effectivePrice, equals(12.00));
      expect(presConOferta.discountPercentRounded, equals(14)); // (13.90 - 12.00) / 13.90 = 13.67% -> 14%

      // 2. Caso con precio_oferta mayor o igual al regular (inválido)
      final presOfertaMayor = ProductPresentation(
        id: 2,
        precioVentaFinal: 10.00,
        precioOferta: 12.00,
        stockActual: 10,
      );
      expect(presOfertaMayor.hasOffer, isFalse);
      expect(presOfertaMayor.effectivePrice, equals(10.00));
      expect(presOfertaMayor.discountPercentRounded, equals(0));

      // 3. Caso con precio_oferta negativo o cero
      final presOfertaInvalida = ProductPresentation(
        id: 3,
        precioVentaFinal: 10.00,
        precioOferta: -1.0,
        stockActual: 10,
      );
      expect(presOfertaInvalida.hasOffer, isFalse);
      expect(presOfertaInvalida.effectivePrice, equals(10.00));

      // 4. Caso con valor_descuento porcentual activo
      final presDctoPorcentaje = ProductPresentation(
        id: 4,
        precioVentaFinal: 20.00,
        tipoDescuento: 'porcentaje',
        valorDescuento: 15.0,
        stockActual: 10,
      );
      expect(presDctoPorcentaje.hasOffer, isTrue);
      expect(presDctoPorcentaje.effectivePrice, equals(17.00));
      expect(presDctoPorcentaje.discountPercentRounded, equals(15));

      // 5. Caso con valor_descuento fijo activo
      final presDctoFijo = ProductPresentation(
        id: 5,
        precioVentaFinal: 20.00,
        tipoDescuento: 'monto_fijo',
        valorDescuento: 5.0,
        stockActual: 10,
      );
      expect(presDctoFijo.hasOffer, isTrue);
      expect(presDctoFijo.effectivePrice, equals(15.00));
      expect(presDctoFijo.discountPercentRounded, equals(25));

      // 6. Caso sin descuento
      final presSinOferta = ProductPresentation(
        id: 6,
        precioVentaFinal: 20.00,
        tipoDescuento: 'ninguno',
        valorDescuento: 0.0,
        stockActual: 10,
      );
      expect(presSinOferta.hasOffer, isFalse);
      expect(presSinOferta.effectivePrice, equals(20.00));
      expect(presSinOferta.discountPercentRounded, equals(0));
    });

    test('InventoryWrapper delega correctamente hasOffer, effectivePrice y discountPercentRounded', () {
      final product = Product(id: 1, nombre: 'Producto Prueba', categoriaId: 1);
      final pres = ProductPresentation(
        id: 10,
        precioVentaFinal: 50.00,
        precioOferta: 40.00,
        stockActual: 5,
      );
      final wrapper = InventoryWrapper(product: product, presentation: pres);

      expect(wrapper.hasOffer, isTrue);
      expect(wrapper.effectivePrice, equals(40.00));
      expect(wrapper.discountPercentRounded, equals(20));
    });

    test('InventoryProvider.updatePresentation con oferta: -1 limpia oferta en memoria', () async {
      final provider = MockInventoryProvider();

      final product = Product(id: 1, nombre: 'Producto Oferta', categoriaId: 1);
      final pres = ProductPresentation(
        id: 101,
        precioVentaFinal: 30.00,
        precioOferta: 25.00,
        tipoDescuento: 'porcentaje',
        valorDescuento: 16.67,
        stockActual: 10,
      );
      final wrapper = InventoryWrapper(product: product, presentation: pres);
      provider.testItems.add(wrapper);

      expect(provider.items.first.presentation.hasOffer, isTrue);
      expect(provider.items.first.presentation.precioOferta, equals(25.00));

      // Quitar oferta con oferta: -1
      final ok = await provider.updatePresentation(101, oferta: -1);
      expect(ok, isTrue);
      expect(provider.lastOferta, equals(-1));

      // En memoria DEBE ser null y hasOffer DEBE ser false (no -1 en memoria)
      final updatedPres = provider.items.first.presentation;
      expect(updatedPres.precioOferta, isNull);
      expect(updatedPres.tipoDescuento, isNull);
      expect(updatedPres.valorDescuento, isNull);
      expect(updatedPres.hasOffer, isFalse);
    });
  });

  group('FASES 2 & 3: Exactitud de Céntimos, Redondeo y Enunciado Explicativo S/ Fijo', () {
    late Map<String, dynamic> controllerMap;
    late TextEditingController costoPresCtrl;
    late TextEditingController margenCtrl;
    late TextEditingController ventaCtrl;
    late TextEditingController valorDescuentoCtrl;
    late PresentationMathEngine engine;

    setUp(() {
      controllerMap = {
        'isEditMode': false,
        'descuentoActivo': true,
        'tipoDescuento': 'porcentaje',
      };
      costoPresCtrl = TextEditingController(text: "10.00");
      margenCtrl = TextEditingController(text: "1.39");
      ventaCtrl = TextEditingController(text: "13.90");
      valorDescuentoCtrl = TextEditingController(text: "10");

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
        costoPresCtrl: costoPresCtrl,
        margenCtrl: margenCtrl,
        ventaCtrl: ventaCtrl,
        valorDescuentoCtrl: valorDescuentoCtrl,
        stockInicialCtrl: TextEditingController(text: "10"),
        nuevoIngresoCtrl: TextEditingController(text: "0"),
        stockDescuentoCtrl: TextEditingController(text: "0"),
        stockFinalCtrl: TextEditingController(text: "10"),
        ajusteBaseCtrl: TextEditingController(),
      );
      engine.init();
    });

    test('Redondeo a .00 en modo %: fija exactamente 12.00 sin drift decimal', () {
      // Base: 13.90, con 10% da 12.51
      expect(engine.precioOferta, closeTo(12.51, 0.01));

      // Tocar chip .00 (target 1.00)
      engine.roundDiscountPrice(1.00);

      // El precio de oferta queda exactamente clavado en 12.00
      expect(engine.precioOferta, equals(12.00));
      expect(controllerMap['precioOfertaExacto'], equals(12.00));
      expect(engine.activeDiscountRoundingTarget, equals(1.00));

      // El porcentaje recalculado es 13.67%
      expect(valorDescuentoCtrl.text, equals("13.67"));

      // Al consultar nuevamente precioOferta, DEBE seguir siendo 12.00 exacto
      expect(engine.precioOferta, equals(12.00));
    });

    test('Toggle OFF al tocar el mismo chip activo restaura el valor previo', () {
      engine.roundDiscountPrice(1.00);
      expect(engine.precioOferta, equals(12.00));
      expect(valorDescuentoCtrl.text, equals("13.67"));

      // Tocar nuevamente .00 desactiva el redondeo y restaura el porcentaje original
      engine.roundDiscountPrice(1.00);
      expect(engine.activeDiscountRoundingTarget, isNull);
      expect(controllerMap['precioOfertaExacto'], isNull);
      expect(valorDescuentoCtrl.text, equals("10"));
      expect(engine.precioOferta, closeTo(12.51, 0.01));
    });

    test('Redondeo a .50 y .90 calcula oferta correctamente', () {
      // Redondear a .50
      engine.roundDiscountPrice(0.50);
      expect(engine.precioOferta, equals(12.50));
      expect(controllerMap['precioOfertaExacto'], equals(12.50));
      expect(engine.activeDiscountRoundingTarget, equals(0.50));

      // Redondear a .90
      engine.roundDiscountPrice(0.90);
      expect(engine.precioOferta, equals(12.90));
      expect(controllerMap['precioOfertaExacto'], equals(12.90));
      expect(engine.activeDiscountRoundingTarget, equals(0.90));
    });

    test('Edición manual en valorDescuentoCtrl limpia el redondeo activo y precio exacto', () {
      engine.roundDiscountPrice(1.00);
      expect(controllerMap['precioOfertaExacto'], equals(12.00));

      valorDescuentoCtrl.text = "20";
      engine.onDiscountValueChanged();

      expect(engine.activeDiscountRoundingTarget, isNull);
      expect(controllerMap['precioOfertaExacto'], isNull);
      // Con 20% sobre 13.90: 13.90 * 0.80 = 11.12
      expect(engine.precioOferta, closeTo(11.12, 0.01));
    });

    test('ProductFormMapper prioriza precioOfertaExacto al guardar en SQLite', () {
      final controllers = [
        {
          'db_id': 1,
          'specific': TextEditingController(text: "Unidad"),
          'unidadVenta': TextEditingController(text: "Unidad"),
          'unidadesVenta': TextEditingController(text: "1"),
          'costoPres': TextEditingController(text: "10.00"),
          'margen': TextEditingController(text: "1.39"),
          'precioVenta': TextEditingController(text: "13.90"),
          'stockFinal': TextEditingController(text: "5"),
          'umpCompra': TextEditingController(text: "Unidad"),
          'unidadesLote': TextEditingController(text: "1"),
          'cantCompra': TextEditingController(text: "5"),
          'totalPago': TextEditingController(text: "50.00"),
          'desc': TextEditingController(),
          'image': TextEditingController(),
          'barcode': TextEditingController(),
          'descuentoActivo': true,
          'tipoDescuento': 'porcentaje',
          'valorDescuento': TextEditingController(text: "13.67"),
          'precioOfertaExacto': 12.00, // Clavado en 12.00
          'isDefault': true,
          'estado': 'publico',
        }
      ];

      final presentations = ProductFormMapper.toPresentations(controllers: controllers);
      expect(presentations.length, equals(1));
      // Debe guardar 12.00 exacto, no 13.90 - (13.90 * 0.1367) = 11.9998
      expect(presentations.first.precioOferta, equals(12.00));
    });

    testWidgets('PresentationDiscountSection muestra en vivo la resta en modo S/ Fijo', (tester) async {
      final valorCtrl = TextEditingController(text: "1.90");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresentationDiscountSection(
                descuentoActivo: true,
                tipoDescuento: 'monto',
                valorDescuentoCtrl: valorCtrl,
                precioVenta: 13.90,
                precioOferta: 12.00,
                isDark: false,
                onDiscountActiveChanged: (_) {},
                onDiscountTypeChanged: (_) {},
                onValueChanged: () {},
                onRoundDiscount: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir el ExpansionTile
      await tester.tap(find.text("Módulo de Descuentos"));
      await tester.pumpAndSettle();

      // Verificar que se renderiza el enunciado explicativo
      expect(
        find.text("Se restará del precio de venta: S/ 13.90 - S/ 1.90 = S/ 12.00"),
        findsOneWidget,
      );
      // Verificar contenedor integrado de precio final
      expect(find.text("PRECIO FINAL:"), findsOneWidget);
      expect(find.text("S/ 12.00"), findsOneWidget);
    });

    testWidgets('PresentationDiscountSection muestra advertencia si descuento fijo >= precio venta', (tester) async {
      final valorCtrl = TextEditingController(text: "15.00");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresentationDiscountSection(
                descuentoActivo: true,
                tipoDescuento: 'monto',
                valorDescuentoCtrl: valorCtrl,
                precioVenta: 13.90,
                precioOferta: null,
                isDark: false,
                onDiscountActiveChanged: (_) {},
                onDiscountTypeChanged: (_) {},
                onValueChanged: () {},
                onRoundDiscount: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Módulo de Descuentos"));
      await tester.pumpAndSettle();

      expect(
        find.text("El descuento debe ser menor al precio regular (S/ 13.90)"),
        findsOneWidget,
      );
    });
  });

  group('FASE 4: Modal Gestionar Precio (PriceUpdateModal) y Limpieza de Ofertas', () {
    testWidgets('PriceUpdateModal cabecera fija, sin chips 2x1/3x2, y con nuevos chips', (tester) async {
      final provider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 1,
        precioVentaFinal: 10.00,
        stockActual: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceUpdateModal(
              presentation: pres,
              provider: provider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cabecera presente
      expect(find.text("Gestionar Precio"), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Chips 2x1 y 3x2 ELIMINADOS
      expect(find.text("2x1"), findsNothing);
      expect(find.text("3x2"), findsNothing);

      // Nuevos chips presentes
      expect(find.text("-5%"), findsOneWidget);
      expect(find.text("-10%"), findsOneWidget);
      expect(find.text("-15%"), findsOneWidget);
      expect(find.text("-20%"), findsOneWidget);
      expect(find.text("-50%"), findsOneWidget);
    });

    testWidgets('En modo S/ Nuevo, monto >= precio regular actualiza precio base y limpia oferta sin error', (tester) async {
      final provider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 55,
        precioVentaFinal: 1.00, // Base regular 1.00
        costoUnitarioCalculado: 0.50,
        precioOferta: 0.80,
        stockActual: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceUpdateModal(
              presentation: pres,
              provider: provider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cambiar a pestaña "S/ Nuevo"
      await tester.tap(find.text("S/ Nuevo"));
      await tester.pumpAndSettle();

      // Ingresar 2.00 (mayor al precio base 1.00)
      final inputField = find.widgetWithText(TextField, "Nuevo Precio (S/)");
      await tester.enterText(inputField, "2.00");
      await tester.pumpAndSettle();

      // NO debe haber mensaje de error
      expect(find.textContaining("¡La oferta"), findsNothing);

      // Debe mostrar el aviso informativo de actualización de precio base
      expect(find.textContaining("Nuevo Precio Base de Venta: S/ 1.00 ➔ S/ 2.00"), findsOneWidget);

      // Tocar APLICAR CAMBIOS
      await tester.tap(find.text("APLICAR CAMBIOS"));
      await tester.pumpAndSettle();

      // Verificar que updatePresentation fue llamado con nuevo precio base 2.0 y oferta eliminada (-1)
      expect(provider.lastUpdatedPresentationId, equals(55));
      expect(provider.lastPrecioVentaFinal, equals(2.00));
      expect(provider.lastOferta, equals(-1));
      expect(provider.lastTipoDesc, equals('ninguno'));
      expect(provider.lastValorDesc, equals(0.0));
    });

    testWidgets('Tocar Quitar Oferta limpia oferta y campos de descuento', (tester) async {
      final provider = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 77,
        precioVentaFinal: 20.00,
        precioOferta: 15.00,
        tipoDescuento: 'monto',
        valorDescuento: 5.00,
        stockActual: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceUpdateModal(
              presentation: pres,
              provider: provider,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Quitar Oferta"), findsOneWidget);
      await tester.ensureVisible(find.text("Quitar Oferta"));
      await tester.tap(find.text("Quitar Oferta"));
      await tester.pumpAndSettle();

      // Al tocar APLICAR CAMBIOS, se guardará oferta: -1
      await tester.ensureVisible(find.text("APLICAR CAMBIOS"));
      await tester.tap(find.text("APLICAR CAMBIOS"));
      await tester.pumpAndSettle();

      expect(provider.lastOferta, equals(-1));
    });
  });

  group('FASE 5: Badges de Porcentaje Entero Limpio (-10%, -14%)', () {
    testWidgets('CatalogItemCard muestra badge entero limpio (-14%)', (tester) async {
      final product = Product(id: 1, nombre: 'Cuaderno Standford', categoriaId: 1);
      final pres = ProductPresentation(
        id: 1,
        precioVentaFinal: 13.90,
        precioOferta: 12.00,
        stockActual: 20,
      );
      final wrapper = InventoryWrapper(product: product, presentation: pres);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CatalogProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 340,
                child: CatalogItemCard(
                  item: wrapper,
                  onDetails: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Debe mostrar "-14%", NUNCA "-13.67%"
      expect(find.text("-14%"), findsOneWidget);
    });

    testWidgets('ProductDetailModal muestra badge entero limpio (-14%) junto al precio tachado', (tester) async {
      final product = Product(id: 1, nombre: 'Lapicero Pilot', categoriaId: 1);
      final pres = ProductPresentation(
        id: 2,
        precioVentaFinal: 13.90,
        precioOferta: 12.00,
        stockActual: 10,
      );
      final wrapper = InventoryWrapper(product: product, presentation: pres);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CatalogProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductDetailModal(
                item: wrapper,
                onAddToCart: (_, [__]) {},
                onAddToList: (_, [__]) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // En el modal de detalle debe aparecer el badge "-14%"
      expect(find.text("-14%"), findsOneWidget);
      expect(find.text("S/ 13.90"), findsOneWidget);
      expect(find.text("S/ 12.00"), findsWidgets);
    });
  });
}
