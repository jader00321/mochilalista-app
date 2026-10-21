import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auditoría Fase 2 & 3: ProductEditSnapshot y Sistema de Reversión', () {
    late TextEditingController nameCtrl;
    late TextEditingController descCtrl;
    late TextEditingController imgUrlCtrl;
    late TextEditingController parentBarcodeCtrl;
    late List<Map<String, dynamic>> presentationControllers;
    late Map<String, GlobalKey> presentationKeys;
    late List<int> idsToDelete;

    setUp(() {
      nameCtrl = TextEditingController(text: "Cuaderno Standford 100 Hojas");
      descCtrl = TextEditingController(text: "Cuadriculado A4");
      imgUrlCtrl = TextEditingController(text: "https://example.com/img.png");
      parentBarcodeCtrl = TextEditingController(text: "7751234567890");
      idsToDelete = [];
      presentationControllers = [];
      presentationKeys = {};

      final presMap = ProductControllerFactory.createNewControllerMap(
        id: "pres_1",
        dbId: 101,
        isDefault: true,
        specificName: "Unidad",
        unidadVenta: "Unidad",
        unidadesVenta: "1",
        costoPres: "3.50",
        margen: "1.40",
        precioVenta: "4.90",
        stockInicial: "50",
        barcode: "7751234567890",
        estado: 'publico',
        unidadesLote: "1",
      );
      presentationControllers.add(presMap);
      presentationKeys["pres_1"] = GlobalKey();
    });

    tearDown(() {
      nameCtrl.dispose();
      descCtrl.dispose();
      imgUrlCtrl.dispose();
      parentBarcodeCtrl.dispose();
      for (var map in presentationControllers) {
        ProductControllerFactory.disposeControllerMap(map);
      }
    });

    test('Snapshot Canónico: Compara idéntico y detecta alteraciones y reversiones', () {
      final initialSnapshot = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 10,
        selectedCategoryName: "Papelería",
        selectedBrandId: 5,
        selectedBrandName: "Standford",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );

      // 1. Inmediatamente tras capturar: debe ser estrictamente idéntico
      final current1 = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 10,
        selectedCategoryName: "Papelería",
        selectedBrandId: 5,
        selectedBrandName: "Standford",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );
      expect(current1.isIdenticalTo(initialSnapshot), isTrue);

      // 2. Modificar un campo: detecta cambio real
      nameCtrl.text = "Cuaderno Standford 200 Hojas";
      final current2 = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 10,
        selectedCategoryName: "Papelería",
        selectedBrandId: 5,
        selectedBrandName: "Standford",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );
      expect(current2.isIdenticalTo(initialSnapshot), isFalse);

      // 3. Regresar el campo exactamente a su valor original: vuelve a ser idéntico
      nameCtrl.text = "Cuaderno Standford 100 Hojas";
      final current3 = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 10,
        selectedCategoryName: "Papelería",
        selectedBrandId: 5,
        selectedBrandName: "Standford",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );
      expect(current3.isIdenticalTo(initialSnapshot), isTrue);
    });

    test('restoreInto reconstruye campos generales y presentaciones exactamente', () {
      final initialSnapshot = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 10,
        selectedCategoryName: "Papelería",
        selectedBrandId: 5,
        selectedBrandName: "Standford",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );

      // Mutar valores
      nameCtrl.text = "Nombre Mutado";
      descCtrl.text = "Desc Mutada";
      (presentationControllers[0]['precioVenta'] as TextEditingController).text = "99.90";
      idsToDelete.add(999);

      // Restaurar
      initialSnapshot.restoreInto(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        targetControllers: presentationControllers,
        targetKeys: presentationKeys,
        targetIdsToDelete: idsToDelete,
      );

      expect(nameCtrl.text, "Cuaderno Standford 100 Hojas");
      expect(descCtrl.text, "Cuadriculado A4");
      expect(idsToDelete, isEmpty);
      expect((presentationControllers[0]['precioVenta'] as TextEditingController).text, "4.90");
    });

    test('Punto 1 & 2: Sincronización de Redondeo, Proveedores Diferidos e idsToDelete', () {
      // 1. Configurar estado con redondeo activo y proveedor diferido
      presentationControllers[0]['activeRoundingTarget'] = 0.90;
      presentationControllers[0]['preRoundedPrice'] = "4.20";
      presentationControllers[0]['preRoundedMargen'] = "1.20";
      presentationControllers[0]['providerId'] = -101;
      presentationControllers[0]['deferredProviderName'] = "Distribuidora Lima Norte";

      final snapshotWithRoundingAndDeferred = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 10,
        selectedCategoryName: "Papelería",
        selectedBrandId: 5,
        selectedBrandName: "Standford",
        generalProviderId: -99,
        generalProviderName: "Proveedor Global Temporal",
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );

      expect(snapshotWithRoundingAndDeferred.generalProviderId, equals(-99));
      expect(snapshotWithRoundingAndDeferred.generalProviderName, equals("Proveedor Global Temporal"));
      expect(snapshotWithRoundingAndDeferred.presentations[0].activeRoundingTarget, equals(0.90));
      expect(snapshotWithRoundingAndDeferred.presentations[0].preRoundedPrice, equals("4.20"));
      expect(snapshotWithRoundingAndDeferred.presentations[0].providerId, equals(-101));
      expect(snapshotWithRoundingAndDeferred.presentations[0].deferredProviderName, equals("Distribuidora Lima Norte"));

      // 2. Modificar el redondeo y verificar que isIdenticalTo lo detecta
      presentationControllers[0]['activeRoundingTarget'] = null;
      presentationControllers[0]['preRoundedPrice'] = null;
      final snapshotModified = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 10,
        selectedCategoryName: "Papelería",
        selectedBrandId: 5,
        selectedBrandName: "Standford",
        generalProviderId: -99,
        generalProviderName: "Proveedor Global Temporal",
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
      );
      expect(snapshotWithRoundingAndDeferred.isIdenticalTo(snapshotModified), isFalse);

      // 3. Simular eliminación de variante y agregar a idsToDelete
      idsToDelete.add(101);
      expect(idsToDelete, contains(101));

      // 4. Restaurar usando restoreInto y verificar que se recuperan redondeo, proveedores e idsToDelete se limpia
      snapshotWithRoundingAndDeferred.restoreInto(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        targetControllers: presentationControllers,
        targetKeys: presentationKeys,
        targetIdsToDelete: idsToDelete,
      );

      expect(idsToDelete, isEmpty, reason: "idsToDelete debe limpiarse en restoreInto para no borrar la variante");
      expect(presentationControllers.length, equals(1));
      expect(presentationControllers[0]['activeRoundingTarget'], equals(0.90));
      expect(presentationControllers[0]['preRoundedPrice'], equals("4.20"));
      expect(presentationControllers[0]['preRoundedMargen'], equals("1.20"));
      expect(presentationControllers[0]['providerId'], equals(-101));
      expect(presentationControllers[0]['deferredProviderName'], equals("Distribuidora Lima Norte"));
    });
  });
}
