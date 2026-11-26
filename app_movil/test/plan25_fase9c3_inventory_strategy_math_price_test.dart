import 'dart:io';

import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _SpyInventoryProvider extends ChangeNotifier
    implements InventoryProvider {
  @override
  Future<bool> updatePresentation(
    int presentationId, {
    String? umpCompra,
    double? precioUmpProveedor,
    double? cantidadUmpComprada,
    double? totalPagoLote,
    int? unidadesPorLote,
    String? unidadVenta,
    int? unidadesPorVenta,
    double? costoUnitarioCalculado,
    double? factorGananciaVenta,
    double? precioVentaFinal,
    double? oferta,
    String? tipoDesc,
    double? valorDesc,
    int? stock,
    int? cupoMaximoVariante,
    bool clearCupo = false,
    String? estado,
    String? imagenUrl,
  }) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PresentationMathEngine _buildEngine(Map<String, dynamic> map) {
  return PresentationMathEngine(
    controllerMap: map,
    onStateUpdate: () {},
    umpCompraCtrl: map['umpCompra'] as TextEditingController,
    cantCompraCtrl: map['cantCompra'] as TextEditingController,
    unidadesLoteCtrl: map['unidadesLote'] as TextEditingController,
    totalPagoCtrl: map['totalPago'] as TextEditingController,
    specificCtrl: map['specific'] as TextEditingController,
    unidadVentaCtrl: map['unidadVenta'] as TextEditingController,
    unidadesVentaCtrl: map['unidadesVenta'] as TextEditingController,
    costoPresCtrl: map['costoPres'] as TextEditingController,
    margenCtrl: map['margen'] as TextEditingController,
    ventaCtrl: map['precioVenta'] as TextEditingController,
    valorDescuentoCtrl: map['valorDescuento'] as TextEditingController,
    stockInicialCtrl: map['stockInicial'] as TextEditingController,
    nuevoIngresoCtrl: map['nuevoIngreso'] as TextEditingController,
    stockDescuentoCtrl: map['stockDescuento'] as TextEditingController,
    stockFinalCtrl: map['stockFinal'] as TextEditingController,
    ajusteBaseCtrl: map['ajusteBase'] as TextEditingController,
  );
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

  group('Plan 25 Fase 9C-3 — Censo, Paridad y Cierre de Fase 9C', () {
    test(
      'Cumple topes estrictos (<400 provider, <550/600 coordinadores, <650 submódulos) y 0 archivos >=1000L en Catálogo',
      () {
        final root = _resolveAppMovilRoot();

        expect(
          _lineCount(
            root,
            'lib/features/catalog/providers/inventory_provider.dart',
          ),
          lessThan(400),
        );
        expect(
          _lineCount(
            root,
            'lib/core/widgets/presentation_card/presentation_math_engine.dart',
          ),
          lessThan(550),
        );
        expect(
          _lineCount(
            root,
            'lib/features/catalog/widgets/form/product_stock_strategy_selector.dart',
          ),
          lessThan(600),
        );
        expect(
          _lineCount(root, 'lib/core/widgets/price_update_modal.dart'),
          lessThan(600),
        );

        const submodules = [
          'lib/features/catalog/providers/inventory/inventory_provider_catalog_meta.dart',
          'lib/features/catalog/providers/inventory/inventory_provider_queries.dart',
          'lib/features/catalog/providers/inventory/inventory_provider_mutations.dart',
          'lib/core/widgets/presentation_card/math_engine/presentation_math_stock_ops.dart',
          'lib/core/widgets/presentation_card/math_engine/presentation_math_pricing_ops.dart',
          'lib/core/widgets/presentation_card/math_engine/presentation_math_strategy_ops.dart',
          'lib/features/catalog/widgets/form/stock_strategy/product_stock_strategy_inputs.dart',
          'lib/features/catalog/widgets/form/stock_strategy/product_stock_strategy_advisor.dart',
          'lib/core/widgets/price_update/price_update_header_and_margin.dart',
          'lib/core/widgets/price_update/price_update_discount_and_preview.dart',
        ];
        for (final path in submodules) {
          expect(
            _lineCount(root, path),
            lessThan(650),
            reason: 'Submódulo $path supera límite',
          );
        }

        // Verificar que todo features/catalog/ ya tiene 0 archivos >= 1000 L
        final catalogDir = Directory(
          '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}features${Platform.pathSeparator}catalog',
        );
        final monoliths = catalogDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => f.readAsLinesSync().length >= 1000)
            .map((f) => f.path)
            .toList();
        expect(
          monoliths,
          isEmpty,
          reason: 'Quedan archivos >=1000 L en catalog: $monoliths',
        );

        // Paridad directa de clases/enums
        expect(SortType.values, containsAll([SortType.id, SortType.alpha]));
        expect(
          StockAdvisorState.values,
          containsAll([
            StockAdvisorState.hidden,
            StockAdvisorState.recommendation,
            StockAdvisorState.mandatory,
          ]),
        );
        expect(InventoryProvider, isNotNull);
        expect(ProductStockStrategySelector, isNotNull);
        expect(PresentationMathEngine, isNotNull);
        expect(PriceUpdateModal, isNotNull);
      },
    );

    test(
      'InventoryProvider preserva instancia única ChangeNotifier y getters/mutadores en memoria',
      () {
        SharedPreferences.setMockInitialValues({});
        final provider = InventoryProvider();
        expect(provider, isA<ChangeNotifier>());

        int notifications = 0;
        provider.addListener(() => notifications++);

        expect(provider.hasCreationDraft, isFalse);
        expect(provider.items, isEmpty);
        expect(provider.hasActiveFilters, isFalse);

        provider.setCreationDraft(
          ProductCreateDraft(
            name: 'Cuaderno Stanford A4',
            presentations: const [
              {'specific': 'Rayado'},
            ],
          ),
        );
        expect(provider.hasCreationDraft, isTrue);
        expect(notifications, 1);

        provider.sortProducts(SortType.alpha);
        expect(provider.prodSort, SortType.alpha);
        expect(notifications, 2);

        provider.clearCreationDraft();
        expect(provider.hasCreationDraft, isFalse);
        expect(notifications, 3);
      },
    );

    test(
      'PresentationMathEngine preserva exactitud matemática en compra, factor, redondeo, descuento y estrategia',
      () {
        final map = ProductControllerFactory.createNewControllerMap(
          id: 'math_test_1',
          unidadVenta: 'Media Docena',
          unidadesVenta: '6',
          margen: '1.50',
        );
        (map['umpCompra'] as TextEditingController).text = 'Caja';
        (map['cantCompra'] as TextEditingController).text = '3';
        (map['unidadesLote'] as TextEditingController).text = '12';
        (map['totalPago'] as TextEditingController).text = '72.00';

        final engine = _buildEngine(map);
        engine.recalcularDesdeCompra();

        // 3 * 12 = 36 u. base; costo base = 72 / 36 = 2.00; factor 6 => costo 12.00; margen 1.50 => venta 18.00
        expect((map['stockInicial'] as TextEditingController).text, '36');
        expect((map['stockFinal'] as TextEditingController).text, '6');
        expect((map['costoPres'] as TextEditingController).text, '12.00');
        expect((map['precioVenta'] as TextEditingController).text, '18.00');

        // Redondeo conmutable .90 y restauración exacta
        engine.roundPrice(0.90);
        expect((map['precioVenta'] as TextEditingController).text, '18.90');
        engine.roundPrice(0.90);
        expect((map['precioVenta'] as TextEditingController).text, '18.00');
        expect((map['margen'] as TextEditingController).text, '1.50');

        // Descuento 15% <-> Fijo 15.30 <-> .50
        map['descuentoActivo'] = true;
        map['tipoDescuento'] = 'porcentaje';
        (map['valorDescuento'] as TextEditingController).text = '15';
        expect(engine.precioOferta, closeTo(15.30, 0.001));

        engine.switchDiscountType('fijo');
        expect((map['valorDescuento'] as TextEditingController).text, '15.30');
        engine.switchDiscountType('porcentaje');
        expect((map['valorDescuento'] as TextEditingController).text, '15');

        // Estrategia compartida <-> propio preservando snapshot
        final sharedCtrl = TextEditingController(text: '24');
        map['sharedStockCtrl'] = sharedCtrl;
        engine.toggleSharedStockMode(isShared: true, baseCost: 2.00);
        expect(map['usaStockCompartido'], isTrue);
        expect((map['costoPres'] as TextEditingController).text, '12.00');
        expect((map['stockFinal'] as TextEditingController).text, '4');

        engine.toggleSharedStockMode(isShared: false, baseCost: 2.00);
        expect(map['usaStockCompartido'], isFalse);
        expect((map['stockFinal'] as TextEditingController).text, '6');
      },
    );
  });

  group('Plan 25 Fase 9C-3 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    const viewports = [Size(320, 568), Size(360, 640), Size(412, 915)];

    for (final size in viewports) {
      testWidgets(
        'ProductStockStrategySelector y PriceUpdateModal en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final capturedMessages = <String>[];
          String currentStage = 'init';
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            capturedMessages.add(
              '[$currentStage] ${details.exceptionAsString()}',
            );
          };

          try {
            final spyProvider = _SpyInventoryProvider();

            // 1A. ProductStockStrategySelector Modo COMPARTIDO Crear + Banner Asesor Obligatorio + Resumen
            currentStage = 'StrategySelector CreateMandatory';
            final sharedCtrlCreate = TextEditingController(text: '5');
            final baseCostCreate = TextEditingController(text: '2.40');
            final controllersList = [
              {
                'specific': TextEditingController(text: 'Caja x12'),
                'unidadVenta': TextEditingController(text: 'Caja'),
                'unidadesVenta': TextEditingController(text: '12'),
                'stockFinal': TextEditingController(text: '0'),
                'usaStockCompartido': true,
              },
            ];
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: SingleChildScrollView(
                    child: ProductStockStrategySelector(
                      key: const ValueKey('strategy_create_mandatory'),
                      selectedStrategy: 'COMPARTIDO',
                      onStrategyChanged: (_) {},
                      sharedStockController: sharedCtrlCreate,
                      baseCostController: baseCostCreate,
                      controllers: controllersList,
                      onAutoCreateUnitVariant: () {},
                      isDark: false,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('+500 und'), findsOneWidget);

            // 1B. ProductStockStrategySelector Modo MIXTO Edición + Recomendación descartable -> Sugerencia unitaria
            currentStage = 'StrategySelector EditRecommendation';
            final sharedCtrlEdit = TextEditingController(text: '10');
            final ingresoCtrlEdit = TextEditingController(text: '5');
            final controllersEdit = [
              {
                'specific': TextEditingController(text: 'Paquete Escolar'),
                'unidadVenta': TextEditingController(text: 'Paquete'),
                'unidadesVenta': TextEditingController(text: '4'),
                'stockFinal': TextEditingController(text: '2'),
                'usaStockCompartido': true,
              },
            ];
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: SingleChildScrollView(
                    child: ProductStockStrategySelector(
                      key: const ValueKey('strategy_edit_mixed'),
                      selectedStrategy: 'MIXTO',
                      onStrategyChanged: (_) {},
                      sharedStockController: sharedCtrlEdit,
                      sharedIngresoController: ingresoCtrlEdit,
                      originalBaseStock: 5,
                      baseCostController: TextEditingController(text: '3.25'),
                      controllers: controllersEdit,
                      isEditMode: true,
                      onAutoCreateUnitVariant: () {},
                      isDark: true,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final closeAdvisorBtn = find.byIcon(Icons.close_rounded);
            if (closeAdvisorBtn.evaluate().isNotEmpty) {
              await tester.ensureVisible(closeAdvisorBtn.first);
              await tester.tap(closeAdvisorBtn.first);
              await tester.pumpAndSettle();
              expect(find.text('Sugerencia unitaria'), findsOneWidget);
            }

            // 2A. PriceUpdateModal con oferta activa, Margen, Redondeo .50/.90/.00 y Preview
            currentStage = 'PriceUpdateModal OfferAndRounding';
            final presWithOffer = ProductPresentation(
              id: 201,
              unidadVenta: 'Unidad',
              unidadesPorVenta: 1,
              costoUnitarioCalculado: 12.50,
              factorGananciaVenta: 2.00,
              precioVentaFinal: 25.00,
              precioOferta: 19.50,
              tipoDescuento: 'porcentaje',
              valorDescuento: 22,
              stockActual: 40,
            );
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: PriceUpdateModal(
                    key: const ValueKey('price_modal_offer'),
                    presentation: presWithOffer,
                    provider: spyProvider,
                    isDark: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('PRECIO FINAL AL CLIENTE'), findsOneWidget);
            expect(find.text('.90'), findsOneWidget);

            // 2B. PriceUpdateModal Modo S/ Fijo actualizando Precio Base + Banner azul
            currentStage = 'PriceUpdateModal BaseUpdateBanner';
            final presBaseUpdate = ProductPresentation(
              id: 202,
              unidadVenta: 'Unidad',
              unidadesPorVenta: 1,
              costoUnitarioCalculado: 6.00,
              factorGananciaVenta: 1.67,
              precioVentaFinal: 10.00,
              stockActual: 15,
            );
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: Builder(
                    builder: (sheetCtx) => Center(
                      child: ElevatedButton(
                        key: const ValueKey('btn_open_price_2b'),
                        onPressed: () => PriceUpdateModal.show(
                          context: sheetCtx,
                          presentation: presBaseUpdate,
                          provider: spyProvider,
                          isDark: true,
                        ),
                        child: const Text('Abrir modal 2B'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('btn_open_price_2b')));
            await tester.pumpAndSettle();
            final fijoTab = find.text('S/ Fijo');
            await tester.ensureVisible(fijoTab);
            await tester.pumpAndSettle();
            await tester.tap(fijoTab);
            await tester.pumpAndSettle();
            final discountField = find.byType(TextField).at(1);
            await tester.ensureVisible(discountField);
            await tester.pumpAndSettle();
            await tester.enterText(discountField, '15.00');
            await tester.pumpAndSettle();
            expect(
              find.textContaining(
                'Nuevo Precio Base de Venta: S/ 10.00 ➔ S/ 15.00',
              ),
              findsOneWidget,
            );
            Navigator.of(tester.element(find.byType(PriceUpdateModal))).pop();
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
