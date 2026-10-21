import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/widgets/modern_entity_picker_modal.dart';
import 'package:app_movil/core/widgets/modern_entity_selector_field.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/catalog/widgets/product_save_success_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1: Selectores Modernos y Creación Diferida Transaccional', () {
    test('PickerItem soporta estados normales, especiales y diferidos con IDs negativos', () {
      const normalItem = PickerItem(id: 10, name: "Gloria");
      expect(normalItem.id, 10);
      expect(normalItem.name, "Gloria");
      expect(normalItem.isDeferred, isFalse);
      expect(normalItem.isSpecial, isFalse);

      const specialItem = PickerItem(
        id: null,
        name: "Usar Principal (Heredado)",
        isSpecial: true,
      );
      expect(specialItem.id, isNull);
      expect(specialItem.isSpecial, isTrue);

      const deferredItem = PickerItem(
        id: -15234,
        name: "Marca Nueva Artesanal",
        isDeferred: true,
      );
      expect(deferredItem.id, -15234);
      expect(deferredItem.isDeferred, isTrue);
      expect(deferredItem.id! < 0, isTrue);
    });

    testWidgets('ModernEntitySelectorField renderiza etiqueta, valor y badge Nuevo si es diferido', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernEntitySelectorField(
              label: "Marca",
              valueText: "Marca Nueva Artesanal",
              icon: Icons.branding_watermark_outlined,
              isDeferred: true,
              isDark: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text("Marca"), findsOneWidget);
      expect(find.text("Marca Nueva Artesanal"), findsOneWidget);
      expect(find.text("Nuevo"), findsOneWidget);
      expect(find.byIcon(Icons.branding_watermark_outlined), findsOneWidget);

      await tester.tap(find.byType(ModernEntitySelectorField));
      expect(tapped, isTrue);
    });

    test('ProductPresentation model soporta deferredProviderName', () {
      final pres = ProductPresentation(
        nombreEspecifico: "Unidad",
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        precioVentaFinal: 5.50,
        stockActual: 10,
        deferredProviderName: "Distribuidora San Juan",
      );

      expect(pres.deferredProviderName, "Distribuidora San Juan");
      expect(pres.proveedorId, isNull);
    });
  });

  group('Fase 2: Borrador Temporal Persistente y Limpiar Todo', () {
    test('ProductCreateDraft detecta datos significativos adecuadamente', () {
      final emptyDraft = ProductCreateDraft(
        name: "",
        presentations: [],
      );
      expect(emptyDraft.hasMeaningfulData, isFalse);

      final draftWithDefaultPresentation = ProductCreateDraft(
        name: "",
        presentations: [
          {
            'specific': '',
            'precioVenta': '',
            'costoPres': '0.00',
            'stockInicial': '0',
            'stockFinal': '0',
          }
        ],
      );
      expect(draftWithDefaultPresentation.hasMeaningfulData, isFalse);

      final draftWithName = ProductCreateDraft(
        name: "Cuaderno Standford",
        presentations: [],
      );
      expect(draftWithName.hasMeaningfulData, isTrue);

      final draftWithMultiplePresentations = ProductCreateDraft(
        name: "",
        presentations: [
          {'specific': 'Unidad'},
          {'specific': 'Docena'},
        ],
      );
      expect(draftWithMultiplePresentations.hasMeaningfulData, isTrue);

      final draftWithDeferredBrand = ProductCreateDraft(
        name: "",
        deferredBrandName: "Piloto",
        presentations: [],
      );
      expect(draftWithDeferredBrand.hasMeaningfulData, isTrue);

      final draftWithPrice = ProductCreateDraft(
        name: "",
        presentations: [
          {'specific': '', 'precioVenta': '12.50'}
        ],
      );
      expect(draftWithPrice.hasMeaningfulData, isTrue);
    });
  });

  group('Fase 3: Animación de Guardado y Traslado a Inventario', () {
    test('InventoryScreen inicializa en tab 0 (Productos)', () {
      const screen = InventoryScreen();
      expect(screen.initialTabIndex, 0);

      const customScreen = InventoryScreen(initialTabIndex: 2);
      expect(customScreen.initialTabIndex, 2);
    });

    testWidgets('ProductSaveSuccessDialog renderiza felicitación y datos del producto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductSaveSuccessDialog(
              productName: "Cuaderno Cuadriculado 100 Hojas",
              presentationCount: 3,
            ),
          ),
        ),
      );

      expect(find.text("¡Producto Creado!"), findsOneWidget);
      expect(find.text("Cuaderno Cuadriculado 100 Hojas"), findsOneWidget);
      expect(find.text("3 presentaciones listas para vender"), findsOneWidget);
      expect(find.text("Abriendo Inventario..."), findsOneWidget);

      // Advance past auto-dismiss timer
      await tester.pump(const Duration(milliseconds: 1200));
    });
  });

  group('Fase 4: Eliminación Definitiva de Chips x12/x24/x50/x100 y Cero Truncamientos', () {
    testWidgets('SmartUnitSelector NO tiene chips x12 (Docena), x24, x50 ni x100 en la vista principal', (tester) async {
      final unitCtrl = TextEditingController(text: "Unidad");
      final factorCtrl = TextEditingController(text: "1");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartUnitSelector(
              unitCtrl: unitCtrl,
              factorCtrl: factorCtrl,
              isDark: false,
            ),
          ),
        ),
      );

      // Los chips que antes estaban debajo ya NO deben existir en la vista principal
      expect(find.text("x12 (Docena)"), findsNothing);
      expect(find.text("x24 (2 Docenas)"), findsNothing);
      expect(find.text("x50 (50 Uds)"), findsNothing);
      expect(find.text("x100 (Ciento)"), findsNothing);

      // Debe existir el toggle de "Ver unidades disponibles"
      expect(find.text("Ver unidades disponibles"), findsOneWidget);

      // Al tocar "Ver unidades disponibles", se expanden las unidades del catálogo
      await tester.tap(find.text("Ver unidades disponibles"));
      await tester.pumpAndSettle();

      expect(find.text("Docena (x12)"), findsOneWidget);
      expect(find.text("Ciento (x100)"), findsOneWidget);

      // Seleccionar Docena (x12) sincroniza unit y factor
      await tester.tap(find.text("Docena (x12)"));
      await tester.pumpAndSettle();

      expect(unitCtrl.text, "Docena");
      expect(factorCtrl.text, "12");
    });

    test('Redondeo de precios matemático funciona con .50, .90 y .00', () {
      double roundPrice(double val, double fraction) {
        if (fraction == 0.0) {
          return val.roundToDouble();
        } else {
          return val.floorToDouble() + fraction;
        }
      }

      expect(roundPrice(15.23, 0.50), 15.50);
      expect(roundPrice(15.23, 0.90), 15.90);
      expect(roundPrice(15.23, 0.00), 15.00);
      expect(roundPrice(15.78, 0.00), 16.00);
    });
  });

  group('Fase 5: InfoTooltipButton y Validación Integral', () {
    testWidgets('InfoTooltipButton muestra modal interactivo con tips detallados', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: AppBar(
                actions: [
                  InfoTooltipButton(
                    title: "Creación de Productos",
                    description: "Registra productos con múltiples presentaciones.",
                    tips: [
                      InfoTip(
                        icon: Icons.search_rounded,
                        text: "Selectores interactivos con buscador.",
                      ),
                      InfoTip(
                        icon: Icons.memory_rounded,
                        text: "Creación diferida en memoria.",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InfoTooltipButton), findsOneWidget);
      await tester.tap(find.byType(InfoTooltipButton));
      await tester.pumpAndSettle();

      expect(find.text("Creación de Productos"), findsOneWidget);
      expect(find.text("Registra productos con múltiples presentaciones."), findsOneWidget);
      expect(find.text("Selectores interactivos con buscador."), findsOneWidget);
      expect(find.text("Creación diferida en memoria."), findsOneWidget);
    });
  });
}
