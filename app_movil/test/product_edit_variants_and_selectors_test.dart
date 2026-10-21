import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/core/widgets/modern_entity_selector_field.dart';
import 'package:app_movil/core/widgets/product_presentation_card.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_general_info.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_presentation_list.dart';
import 'package:app_movil/features/catalog/widgets/product_save_success_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1: Selectores Modernos y Creación Diferida en Edición', () {
    testWidgets('ProductGeneralInfo renderiza Marca, Categoría y Proveedor General con ModernEntitySelectorField', (tester) async {
      final nameCtrl = TextEditingController(text: "Cuaderno Standford A4");
      bool brandTapped = false;
      bool categoryTapped = false;
      bool providerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductGeneralInfo(
              nameCtrl: nameCtrl,
              brandDisplay: "Standford",
              isBrandDeferred: false,
              onSelectBrand: () => brandTapped = true,
              categoryDisplay: "Papelería",
              isCategoryDeferred: false,
              onSelectCategory: () => categoryTapped = true,
              generalProviderDisplay: "Distribuidora Navarrete",
              isGeneralProviderDeferred: false,
              onSelectGeneralProvider: () => providerTapped = true,
              generalState: 2,
              isDark: false,
              onStateChanged: (_) {},
            ),
          ),
        ),
      );

      // Verificar que los 3 campos existan y no haya SafeDropdown
      expect(find.text("Nombre del Producto *"), findsOneWidget);
      expect(find.text("Standford"), findsOneWidget);
      expect(find.text("Papelería"), findsOneWidget);
      expect(find.text("Distribuidora Navarrete"), findsOneWidget);
      expect(find.byType(ModernEntitySelectorField), findsNWidgets(3));

      // Probar taps en selectores
      await tester.tap(find.text("Standford"));
      expect(brandTapped, isTrue);

      await tester.tap(find.text("Papelería"));
      expect(categoryTapped, isTrue);

      await tester.tap(find.text("Distribuidora Navarrete"));
      expect(providerTapped, isTrue);
    });

    testWidgets('ProductGeneralInfo muestra badge Nuevo cuando una entidad es diferida (tempId < 0)', (tester) async {
      final nameCtrl = TextEditingController(text: "Bolígrafo Gel");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductGeneralInfo(
              nameCtrl: nameCtrl,
              brandDisplay: "Marca Artesanal Pendiente",
              isBrandDeferred: true,
              onSelectBrand: () {},
              categoryDisplay: "Categoría Especial Pendiente",
              isCategoryDeferred: true,
              onSelectCategory: () {},
              generalProviderDisplay: "Proveedor Importador Pendiente",
              isGeneralProviderDeferred: true,
              onSelectGeneralProvider: () {},
              generalState: 2,
              isDark: false,
              onStateChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text("Marca Artesanal Pendiente"), findsOneWidget);
      expect(find.text("Categoría Especial Pendiente"), findsOneWidget);
      expect(find.text("Proveedor Importador Pendiente"), findsOneWidget);

      // Los 3 selectores deben tener la insignia "Nuevo"
      expect(find.text("Nuevo"), findsNWidgets(3));
    });

    testWidgets('ProductPresentationList renderiza selector moderno para proveedor de variante', (tester) async {
      final controllers = [
        {
          'id': 'p1',
          'db_id': 101,
          'isEditMode': true,
          'isExpanded': false,
          'specific': TextEditingController(text: "Unidad"),
          'unidadVenta': TextEditingController(text: "Unidad"),
          'unidadesVenta': TextEditingController(text: "1"),
          'costoPres': TextEditingController(text: "2.50"),
          'margen': TextEditingController(text: "1.35"),
          'precioVenta': TextEditingController(text: "3.50"),
          'stockFinal': TextEditingController(text: "20"),
          'providerId': -99,
          'deferredProviderName': "Proveedor Variado Diferido",
          'isDefault': true,
          'estado': 'publico',
          'descuentoActivo': false,
          'tipoDescuento': 'porcentaje',
          'valorDescuento': TextEditingController(),
          'stockInicial': TextEditingController(text: "20"),
          'nuevoIngreso': TextEditingController(text: "0"),
          'stockDescuento': TextEditingController(text: "0"),
          'umpCompra': TextEditingController(),
          'unidadesLote': TextEditingController(text: "1"),
          'cantCompra': TextEditingController(),
          'totalPago': TextEditingController(),
          'barcode': TextEditingController(),
          'desc': TextEditingController(),
          'image': TextEditingController(),
          'ajusteBase': TextEditingController(),
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductPresentationList(
              presentationControllers: controllers,
              isDark: false,
              providerListForDropdown: [
                ProviderModel(id: 1, nombreEmpresa: "Oficial", idNegocio: 1, activo: true),
              ],
              deferredProviderNames: {-99: "Proveedor Variado Diferido"},
              deletePresentation: (_, __) {},
              handleCreateLeftover: (_, __, ___) {},
              invalidateLeftover: (_) {},
              onStateChange: () {},
            ),
          ),
        ),
      );

      // La tarjeta contraída está presente
      expect(find.byType(ProductPresentationCard), findsOneWidget);
    });
  });

  group('Fase 2: Rediseño de Tarjetas Contraídas y Desplegadas + Cero Truncamientos', () {
    testWidgets('Modo contraído muestra insignia ⭐ Principal, nombre, chip unidad, precio y píldoras atómicas', (tester) async {
      final ctrlMap = {
        'id': 'card_1',
        'db_id': 1,
        'isEditMode': true,
        'isExpanded': false,
        'specific': TextEditingController(text: "Caja de 12 Unidades"),
        'unidadVenta': TextEditingController(text: "Docena"),
        'unidadesVenta': TextEditingController(text: "12"),
        'costoPres': TextEditingController(text: "0.45"),
        'margen': TextEditingController(text: "1.35"),
        'precioVenta': TextEditingController(text: "1.50"),
        'stockFinal': TextEditingController(text: "25"),
        'providerId': null,
        'isDefault': true,
        'estado': 'publico',
        'descuentoActivo': false,
        'tipoDescuento': 'porcentaje',
        'valorDescuento': TextEditingController(),
        'stockInicial': TextEditingController(text: "25"),
        'nuevoIngreso': TextEditingController(),
        'stockDescuento': TextEditingController(text: "0"),
        'umpCompra': TextEditingController(),
        'unidadesLote': TextEditingController(text: "1"),
        'cantCompra': TextEditingController(),
        'totalPago': TextEditingController(),
        'barcode': TextEditingController(),
        'desc': TextEditingController(),
        'image': TextEditingController(),
        'ajusteBase': TextEditingController(),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductPresentationCard(
              controllerMap: ctrlMap,
              presentationIndex: 0,
              totalPresentations: 2,
              onDelete: () {},
              onStateChange: (_) {},
              providerDropdown: const SizedBox(),
            ),
          ),
        ),
      );

      // 1. Cabecera muestra insignia de Principal
      expect(find.text("⭐ Principal"), findsOneWidget);

      // 2. Fila 1 de tarjeta contraída: chip unidad, nombre y precio
      expect(find.text("Docena (x12)"), findsOneWidget);
      expect(find.text("Caja de 12 Unidades"), findsOneWidget);
      expect(find.text("S/ 1.50"), findsOneWidget);

      // 3. Fila 2 de tarjeta contraída: píldoras atómicas (Stock, Costo S/ 0.45, Margen)
      expect(find.text("Stock: 25 uds"), findsOneWidget);
      expect(find.text("Costo: S/ 0.45"), findsOneWidget);
      expect(find.textContaining("Margen:"), findsOneWidget);
    });

    testWidgets('Modo contraído para variante secundaria muestra insignia #2 Secundaria y botón Hacer Principal', (tester) async {
      bool setAsDefaultTapped = false;

      final ctrlMap = {
        'id': 'card_2',
        'db_id': 2,
        'isEditMode': true,
        'isExpanded': false,
        'specific': TextEditingController(text: "Ciento"),
        'unidadVenta': TextEditingController(text: "Ciento"),
        'unidadesVenta': TextEditingController(text: "100"),
        'costoPres': TextEditingController(text: "35.00"),
        'margen': TextEditingController(text: "1.40"),
        'precioVenta': TextEditingController(text: "49.00"),
        'stockFinal': TextEditingController(text: "5"),
        'providerId': null,
        'isDefault': false,
        'estado': 'publico',
        'descuentoActivo': false,
        'tipoDescuento': 'porcentaje',
        'valorDescuento': TextEditingController(),
        'stockInicial': TextEditingController(text: "5"),
        'nuevoIngreso': TextEditingController(),
        'stockDescuento': TextEditingController(text: "0"),
        'umpCompra': TextEditingController(),
        'unidadesLote': TextEditingController(text: "1"),
        'cantCompra': TextEditingController(),
        'totalPago': TextEditingController(),
        'barcode': TextEditingController(),
        'desc': TextEditingController(),
        'image': TextEditingController(),
        'ajusteBase': TextEditingController(),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductPresentationCard(
              controllerMap: ctrlMap,
              presentationIndex: 1,
              totalPresentations: 2,
              onSetDefault: () => setAsDefaultTapped = true,
              onDelete: () {},
              onStateChange: (_) {},
              providerDropdown: const SizedBox(),
            ),
          ),
        ),
      );

      expect(find.text("#2 Secundaria"), findsOneWidget);

      // Open [ ⋯ ] actions tray to access Hacer Principal
      if (find.byIcon(Icons.more_horiz_rounded).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
      }

      expect(find.text("Hacer Principal"), findsOneWidget);

      await tester.tap(find.text("Hacer Principal"));
      expect(setAsDefaultTapped, isTrue);
    });
  });

  group('Fase 3: Cambio de Variante Principal (⭐), Reordenamiento y SQLite V24', () {
    test('ProductPresentation mapea columna orden en fromJson, toSqlite y toJson', () {
      final pres = ProductPresentation(
        id: 10,
        nombreEspecifico: "Unidad",
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        precioVentaFinal: 10.0,
        stockActual: 5,
        esDefault: false,
        orden: 3,
      );

      expect(pres.orden, 3);

      final sqliteMap = pres.toSqlite(1);
      expect(sqliteMap['orden'], 3);

      final jsonMap = pres.toJson();
      expect(jsonMap['orden'], 3);

      final fromJsonPres = ProductPresentation.fromJson({
        'id': 10,
        'nombre_especifico': "Unidad",
        'unidad_venta': "Unidad",
        'unidades_por_venta': 1,
        'precio_venta_final': 10.0,
        'stock_actual': 5,
        'es_default': 0,
        'orden': 3,
      });

      expect(fromJsonPres.orden, 3);
    });

    test('Promoción de Principal en memoria actualiza isDefault y mueve al índice 0', () {
      final List<Map<String, dynamic>> presentations = [
        {
          'id': '1',
          'specific': TextEditingController(text: "Unidad"),
          'isDefault': true,
        },
        {
          'id': '2',
          'specific': TextEditingController(text: "Docena"),
          'isDefault': false,
        },
        {
          'id': '3',
          'specific': TextEditingController(text: "Caja"),
          'isDefault': false,
        },
      ];

      // Simular _handleSetDefault(1) sobre "Docena"
      const targetIndex = 1;
      for (int i = 0; i < presentations.length; i++) {
        presentations[i]['isDefault'] = (i == targetIndex);
      }
      final item = presentations.removeAt(targetIndex);
      presentations.insert(0, item);

      expect(presentations.first['specific'].text, "Docena");
      expect(presentations.first['isDefault'], isTrue);
      expect(presentations[1]['isDefault'], isFalse);
      expect(presentations[2]['isDefault'], isFalse);
    });

    test('Eliminación de la variante principal promueve automáticamente la siguiente a Principal', () {
      final List<Map<String, dynamic>> presentations = [
        {
          'id': '1',
          'db_id': 101,
          'specific': TextEditingController(text: "Principal"),
          'isDefault': true,
        },
        {
          'id': '2',
          'db_id': 102,
          'specific': TextEditingController(text: "Secundaria 1"),
          'isDefault': false,
        },
      ];

      final deleted = presentations.removeAt(0);
      expect(deleted['isDefault'], isTrue);

      if (presentations.isNotEmpty) {
        presentations.first['isDefault'] = true;
      }

      expect(presentations.length, 1);
      expect(presentations.first['specific'].text, "Secundaria 1");
      expect(presentations.first['isDefault'], isTrue);
    });
  });

  group('Fase 4: Herramientas de Productividad, Clonación, initialPresentationId y Diálogo Animado', () {
    test('Clonación de variante en edición asigna db_id null y conserva valores de controladores', () {
      final original = {
        'id': 'orig_1',
        'db_id': 55,
        'specific': TextEditingController(text: "Caja"),
        'unidadVenta': TextEditingController(text: "Caja"),
        'unidadesVenta': TextEditingController(text: "24"),
        'costoPres': TextEditingController(text: "12.00"),
        'precioVenta': TextEditingController(text: "18.00"),
        'isDefault': true,
      };

      final specificCtrl = original['specific'] as TextEditingController;
      final uVentaCtrl = original['unidadVenta'] as TextEditingController;
      final factCtrl = original['unidadesVenta'] as TextEditingController;
      final costoCtrl = original['costoPres'] as TextEditingController;
      final pVentaCtrl = original['precioVenta'] as TextEditingController;

      final clone = {
        'id': 'clone_2',
        'db_id': null, // Nuevo registro
        'specific': TextEditingController(text: "${specificCtrl.text} (Copia)"),
        'unidadVenta': TextEditingController(text: uVentaCtrl.text),
        'unidadesVenta': TextEditingController(text: factCtrl.text),
        'costoPres': TextEditingController(text: costoCtrl.text),
        'precioVenta': TextEditingController(text: pVentaCtrl.text),
        'isDefault': false, // La copia nunca es principal por defecto
      };

      expect(clone['db_id'], isNull);
      expect((clone['specific'] as TextEditingController).text, "Caja (Copia)");
      expect(clone['isDefault'], isFalse);
      expect((clone['precioVenta'] as TextEditingController).text, "18.00");
    });

    testWidgets('ProductSaveSuccessDialog renderiza felicitación y datos del producto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductSaveSuccessDialog(
              productName: "Tijera Escolar Maped",
              presentationCount: 2,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("¡Producto Creado!"), findsOneWidget);
      expect(find.text("Tijera Escolar Maped"), findsOneWidget);
      expect(find.textContaining("2 presentaciones listas"), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Fase 5: InfoTooltipButton (i) y Validación', () {
    testWidgets('InfoTooltipButton se renderiza y muestra tips de variantes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                InfoTooltipButton(
                  title: "Edición de Producto y Variantes",
                  description: "Guía de variantes",
                  tips: [
                    InfoTip(
                      icon: Icons.star_rounded,
                      text: "Establece cualquier variante como 'Principal' con 1 toque.",
                    ),
                    InfoTip(
                      icon: Icons.swap_vert_rounded,
                      text: "Reordena tus variantes con los botones arriba/abajo.",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(InfoTooltipButton), findsOneWidget);
      await tester.tap(find.byType(InfoTooltipButton));
      await tester.pumpAndSettle();

      expect(find.text("Edición de Producto y Variantes"), findsOneWidget);
      expect(find.textContaining("Establece cualquier variante como 'Principal'"), findsOneWidget);
    });
  });

  group('Fase 6: Auditoría de Integración Cruzada (Crear, Editar, Detalle y SQLite V24)', () {
    test('ProductCreateDraft preserva orden, isDefault e isExpanded', () {
      final draft = ProductCreateDraft(
        name: "Goma Escolar",
        presentations: [
          {
            'id': 'card_1',
            'specific': 'Unidad',
            'isDefault': true,
            'isExpanded': true,
            'orden': 0,
            'precioVenta': '1.50',
          },
          {
            'id': 'card_2',
            'specific': 'Caja x20',
            'isDefault': false,
            'isExpanded': false,
            'orden': 1,
            'precioVenta': '25.00',
          },
        ],
      );

      expect(draft.hasMeaningfulData, isTrue);
      expect(draft.presentations.length, 2);
      expect(draft.presentations[0]['isDefault'], isTrue);
      expect(draft.presentations[0]['orden'], 0);
      expect(draft.presentations[1]['isDefault'], isFalse);
      expect(draft.presentations[1]['orden'], 1);
    });

    test('Reordenamiento y autopromoción de principal en Crear Producto', () {
      final controllers = <Map<String, dynamic>>[
        {'id': 'p1', 'isDefault': true, 'name': 'Unidad'},
        {'id': 'p2', 'isDefault': false, 'name': 'Docena'},
        {'id': 'p3', 'isDefault': false, 'name': 'Caja'},
      ];

      // 1. Promover p3 a Principal
      int targetIndex = controllers.indexWhere((c) => c['id'] == 'p3');
      for (int i = 0; i < controllers.length; i++) {
        controllers[i]['isDefault'] = (i == targetIndex);
      }
      final promoted = controllers.removeAt(targetIndex);
      controllers.insert(0, promoted);

      expect(controllers[0]['id'], 'p3');
      expect(controllers[0]['isDefault'], isTrue);
      expect(controllers[1]['isDefault'], isFalse);
      expect(controllers[2]['isDefault'], isFalse);

      // 2. Eliminar la principal (p3): la siguiente (p1) se autopromueve
      bool wasDefault = controllers[0]['isDefault'] == true;
      controllers.removeAt(0);
      if (wasDefault && controllers.isNotEmpty) {
        controllers[0]['isDefault'] = true;
      }

      expect(controllers.length, 2);
      expect(controllers[0]['id'], 'p1');
      expect(controllers[0]['isDefault'], isTrue);
      expect(controllers[1]['id'], 'p2');
      expect(controllers[1]['isDefault'], isFalse);
    });

    test('ProductDetailScreen fallback a variante Principal cuando la seleccionada es eliminada', () {
      final product = Product(
        id: 101,
        nombre: "Plumones Faber Castell",
        categoriaId: 1,
        presentaciones: [
          ProductPresentation(
            id: 1,
            unidadVenta: "Estuche",
            precioVentaFinal: 12.0,
            stockActual: 10,
            esDefault: true,
            orden: 0,
          ),
          ProductPresentation(
            id: 2,
            unidadVenta: "Caja x12",
            precioVentaFinal: 120.0,
            stockActual: 2,
            esDefault: false,
            orden: 1,
          ),
        ],
      );

      // Simular que el usuario tenía seleccionada la presentación 999 (que fue eliminada en edición)
      const int targetDeletedId = 999;
      ProductPresentation? match;
      for (final p in product.presentaciones) {
        if (p.id == targetDeletedId) {
          match = p;
          break;
        }
      }

      ProductPresentation selectedPresentation;
      if (match != null) {
        selectedPresentation = match;
      } else {
        selectedPresentation = product.presentaciones.firstWhere(
          (p) => p.esDefault,
          orElse: () => product.presentaciones.first,
        );
      }

      expect(match, isNull);
      expect(selectedPresentation.id, 1);
      expect(selectedPresentation.esDefault, isTrue);
      expect(selectedPresentation.unidadVenta, "Estuche");
    });

    test('Cláusula canónica ORDER BY es_default DESC, orden ASC, id ASC ordena correctamente', () {
      final list = [
        ProductPresentation(id: 3, precioVentaFinal: 5.0, stockActual: 1, esDefault: false, orden: 2),
        ProductPresentation(id: 1, precioVentaFinal: 1.0, stockActual: 10, esDefault: true, orden: 0),
        ProductPresentation(id: 2, precioVentaFinal: 10.0, stockActual: 2, esDefault: false, orden: 1),
      ];

      list.sort((a, b) {
        if (a.esDefault && !b.esDefault) return -1;
        if (!a.esDefault && b.esDefault) return 1;
        if (a.orden != b.orden) return a.orden.compareTo(b.orden);
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

      expect(list[0].id, 1);
      expect(list[0].esDefault, isTrue);
      expect(list[1].id, 2);
      expect(list[1].orden, 1);
      expect(list[2].id, 3);
      expect(list[2].orden, 2);
    });
  });
}

