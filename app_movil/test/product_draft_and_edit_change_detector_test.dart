import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_change_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 5: Detección Real de Borrador y PopScope en Edición', () {
    test('hasMeaningfulData is FALSE for default initial presentation with 0.00 / 0', () {
      final defaultDraft = ProductCreateDraft(
        name: "",
        presentations: [
          {
            'specific': '',
            'precioVenta': '0.00',
            'costoPres': '0.00',
            'stockInicial': '0',
            'stockFinal': '0',
            'cantCompra': '',
            'totalPago': '',
            'image': '',
            'barcode': '',
            'deferredProviderName': '',
          }
        ],
      );

      expect(defaultDraft.hasMeaningfulData, isFalse);
    });

    test('hasMeaningfulData is TRUE when real data is entered', () {
      // With product name
      final draftWithName = ProductCreateDraft(
        name: "Cuaderno Standford",
        presentations: [
          {
            'specific': '',
            'precioVenta': '0.00',
            'costoPres': '0.00',
            'stockInicial': '0',
            'stockFinal': '0',
          }
        ],
      );
      expect(draftWithName.hasMeaningfulData, isTrue);

      // With price > 0
      final draftWithPrice = ProductCreateDraft(
        name: "",
        presentations: [
          {
            'specific': '',
            'precioVenta': '5.50',
            'costoPres': '0.00',
            'stockInicial': '0',
            'stockFinal': '0',
          }
        ],
      );
      expect(draftWithPrice.hasMeaningfulData, isTrue);

      // With category selected
      final draftWithCat = ProductCreateDraft(
        name: "",
        categoryId: 12,
        presentations: [],
      );
      expect(draftWithCat.hasMeaningfulData, isTrue);
    });

    test('ProductEditChangeDetector returns FALSE when exiting without modifications', () {
      final product = Product(
        id: 101,
        nombre: "Lapicero Faber Castell",
        descripcion: "Tinta seca color azul",
        categoriaId: 0, // Uncategorized
        marcaId: null, // No brand
        imagenUrl: "",
        codigoBarras: "7751234567890",
        presentaciones: [
          ProductPresentation(
            id: 201,
            nombreEspecifico: "Unidad",
            unidadVenta: "Unidad",
            unidadesPorVenta: 1,
            precioVentaFinal: 2.50,
            costoUnitarioCalculado: 1.50,
            factorGananciaVenta: 1.67,
            stockActual: 100,
            esDefault: true,
            estado: 'publico',
          ),
        ],
      );

      final nameCtrl = TextEditingController(text: "Lapicero Faber Castell");
      final descCtrl = TextEditingController(text: "Tinta seca color azul");
      final imgCtrl = TextEditingController(text: "");
      final barcodeCtrl = TextEditingController(text: "7751234567890");

      final presMap = <String, dynamic>{
        'db_id': 201,
        'isDefault': true,
        'estado': 'publico',
        'specific': TextEditingController(text: "Unidad"),
        'unidadVenta': TextEditingController(text: "Unidad"),
        'unidadesVenta': TextEditingController(text: "1"),
        'precioVenta': TextEditingController(text: "2.50"),
        'costoPres': TextEditingController(text: "1.50"),
        'margen': TextEditingController(text: "1.67"),
        'nuevoIngreso': TextEditingController(text: "0"),
        'stockDescuento': TextEditingController(text: "0"),
        'descuentoActivo': false,
        'valorDescuento': TextEditingController(text: ""),
        'barcode': TextEditingController(text: ""),
        'desc': TextEditingController(text: ""),
        'image': TextEditingController(text: ""),
      };

      // Even with selectedCategoryId == null and product.categoriaId == 0,
      // it MUST NOT trigger false changes!
      final hasChanges = ProductEditChangeDetector.hasUnsavedChanges(
        isDirty: false,
        productToEdit: product,
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgCtrl,
        parentBarcodeCtrl: barcodeCtrl,
        selectedBrandId: null,
        selectedBrandName: null,
        selectedCategoryId: null,
        selectedCategoryName: null,
        generalProviderId: null,
        idsToDelete: [],
        presentationControllers: [presMap],
      );

      expect(hasChanges, isFalse);
    });

    test('ProductEditChangeDetector returns TRUE when user modifies a value', () {
      final product = Product(
        id: 101,
        nombre: "Lapicero Faber Castell",
        descripcion: "",
        categoriaId: 0,
        presentaciones: [
          ProductPresentation(
            id: 201,
            nombreEspecifico: "Unidad",
            precioVentaFinal: 2.50,
            costoUnitarioCalculado: 1.50,
            stockActual: 100,
            esDefault: true,
          ),
        ],
      );

      final nameCtrl = TextEditingController(text: "Lapicero Faber Castell MODIFICADO");
      final descCtrl = TextEditingController(text: "");
      final imgCtrl = TextEditingController(text: "");
      final barcodeCtrl = TextEditingController(text: "");

      final presMap = <String, dynamic>{
        'db_id': 201,
        'isDefault': true,
        'estado': 'publico',
        'specific': TextEditingController(text: "Unidad"),
        'unidadVenta': TextEditingController(text: "Unidad"),
        'unidadesVenta': TextEditingController(text: "1"),
        'precioVenta': TextEditingController(text: "2.50"),
        'costoPres': TextEditingController(text: "1.50"),
        'margen': TextEditingController(text: "1.67"),
        'nuevoIngreso': TextEditingController(text: "0"),
        'stockDescuento': TextEditingController(text: "0"),
        'descuentoActivo': false,
        'valorDescuento': TextEditingController(text: ""),
        'barcode': TextEditingController(text: ""),
        'desc': TextEditingController(text: ""),
        'image': TextEditingController(text: ""),
      };

      final hasChanges = ProductEditChangeDetector.hasUnsavedChanges(
        isDirty: false,
        productToEdit: product,
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgCtrl,
        parentBarcodeCtrl: barcodeCtrl,
        selectedBrandId: null,
        selectedBrandName: null,
        selectedCategoryId: null,
        selectedCategoryName: null,
        generalProviderId: null,
        idsToDelete: [],
        presentationControllers: [presMap],
      );

      expect(hasChanges, isTrue);
    });

    test('ProductEditChangeDetector normalizes proveedorId (null vs 0) to prevent false positives in PopScope', () {
      final product = Product(
        id: 101,
        nombre: "Regla 30cm",
        descripcion: "",
        categoriaId: 0,
        presentaciones: [
          ProductPresentation(
            id: 201,
            nombreEspecifico: "Unidad",
            precioVentaFinal: 1.50,
            costoUnitarioCalculado: 0.80,
            factorGananciaVenta: 1.88,
            stockActual: 50,
            esDefault: true,
            proveedorId: 0, // In SQLite it may be 0
          ),
        ],
      );

      final presMap = <String, dynamic>{
        'db_id': 201,
        'isDefault': true,
        'estado': 'publico',
        'specific': TextEditingController(text: "Unidad"),
        'unidadVenta': TextEditingController(text: "Unidad"),
        'unidadesVenta': TextEditingController(text: "1"),
        'precioVenta': TextEditingController(text: "1.50"),
        'costoPres': TextEditingController(text: "0.80"),
        'margen': TextEditingController(text: "1.88"),
        'nuevoIngreso': TextEditingController(text: "0"),
        'stockDescuento': TextEditingController(text: "0"),
        'descuentoActivo': false,
        'valorDescuento': TextEditingController(text: ""),
        'barcode': TextEditingController(text: ""),
        'desc': TextEditingController(text: ""),
        'image': TextEditingController(text: ""),
        'providerId': null, // In form controller it's null (none)
      };

      // Even if original has proveedorId == 0 and controller has null,
      // and generalProviderId is null, it MUST NOT trigger unsaved changes!
      final hasChanges = ProductEditChangeDetector.hasUnsavedChanges(
        isDirty: false,
        productToEdit: product,
        nameCtrl: TextEditingController(text: "Regla 30cm"),
        descCtrl: TextEditingController(text: ""),
        imgUrlCtrl: TextEditingController(text: ""),
        parentBarcodeCtrl: TextEditingController(text: ""),
        selectedBrandId: null,
        selectedBrandName: null,
        selectedCategoryId: null,
        selectedCategoryName: null,
        generalProviderId: null,
        idsToDelete: [],
        presentationControllers: [presMap],
      );

      expect(hasChanges, isFalse);
    });

    test('InventoryProvider clearProductCreationDraft immediately hides draft indicators', () {
      final provider = InventoryProvider();
      expect(provider.hasCreationDraft, isFalse);

      final draft = ProductCreateDraft(
        name: "Cuaderno 100 Hojas",
        presentations: [],
      );
      provider.setCreationDraft(draft);
      expect(provider.hasCreationDraft, isTrue);

      // Clearing draft immediately updates hasCreationDraft
      provider.clearProductCreationDraft();
      expect(provider.hasCreationDraft, isFalse);
      expect(provider.creationDraft, isNull);
    });

    test('Punto 1: ProductCreateDraft detecta y preserva activeRoundingTarget y preRoundedPrice', () {
      final draftWithRounding = ProductCreateDraft(
        name: "",
        presentations: [
          {
            'specific': '',
            'precioVenta': '0.00',
            'costoPres': '0.00',
            'stockInicial': '0',
            'stockFinal': '0',
            'activeRoundingTarget': 0.90,
            'preRoundedPrice': '13.84',
            'preRoundedMargen': '1.35',
          }
        ],
      );

      expect(draftWithRounding.hasMeaningfulData, isTrue,
          reason: "Un borrador con chip de redondeo activo debe ser retenido");
      expect(draftWithRounding.presentations.first['activeRoundingTarget'], equals(0.90));
      expect(draftWithRounding.presentations.first['preRoundedPrice'], equals('13.84'));
    });
  });
}
