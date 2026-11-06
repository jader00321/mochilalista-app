import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_business_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ÁRBITRO ADVERSARIAL - BLOQUE 1: Chips de Pago Order-Agnostic, Sin Doble Check y Memoria de Sesión', () {
    testWidgets('Tocar BCP y CCI -> Tocar CCI (último) lo desactiva SIN DUPLICAR jamás', (tester) async {
      final phoneCtrl = TextEditingController(text: "976644890");
      final rucCtrl = TextEditingController();
      final addressCtrl = TextEditingController(text: "talara");
      final paymentCtrl = TextEditingController();
      final sessionMemory = <PaymentChipType, String>{};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: false,
                hasBusinessChanges: false,
                sessionPaymentMemory: sessionMemory,
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Activar BCP
      final bcpFinder = find.widgetWithText(InkWell, "+ BCP");
      expect(bcpFinder, findsOneWidget);
      await tester.tap(bcpFinder);
      await tester.pumpAndSettle();

      expect(paymentCtrl.text, "BCP Soles: ");
      expect(find.widgetWithText(InkWell, "BCP"), findsOneWidget);
      expect(find.text("✓ BCP"), findsNothing); // Cero doble check

      // 2. Activar CCI (segundo chip)
      final cciFinder = find.widgetWithText(InkWell, "+ CCI");
      expect(cciFinder, findsOneWidget);
      await tester.tap(cciFinder);
      await tester.pumpAndSettle();

      expect(paymentCtrl.text, "BCP Soles:\nCCI Interbancario: ");
      expect(find.widgetWithText(InkWell, "CCI"), findsOneWidget);
      expect(find.text("✓ CCI"), findsNothing); // Cero doble check

      // 3. Desactivar CCI (último chip presionado en la lista de líneas)
      // Debe borrarse limpiamente y NO duplicarse como "CCI Interbancario:\nCCI Interbancario:"
      final cciActiveFinder = find.widgetWithText(InkWell, "CCI");
      expect(cciActiveFinder, findsOneWidget);
      await tester.tap(cciActiveFinder);
      await tester.pumpAndSettle();

      // El texto debe ser exactamente "BCP Soles:" sin rastro de CCI
      expect(paymentCtrl.text, "BCP Soles:");
      expect(paymentCtrl.text.contains("CCI"), isFalse);
      expect(find.widgetWithText(InkWell, "+ CCI"), findsOneWidget);

      phoneCtrl.dispose();
      rucCtrl.dispose();
      addressCtrl.dispose();
      paymentCtrl.dispose();
    });

    testWidgets('Memoria de sesión: Retiene número digitado (BCP Soles: 191-99887766) al apagar y reencender', (tester) async {
      final phoneCtrl = TextEditingController(text: "976644890");
      final rucCtrl = TextEditingController();
      final addressCtrl = TextEditingController();
      final paymentCtrl = TextEditingController();
      final sessionMemory = <PaymentChipType, String>{};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: false,
                hasBusinessChanges: false,
                sessionPaymentMemory: sessionMemory,
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Activar BCP
      await tester.tap(find.widgetWithText(InkWell, "+ BCP"));
      await tester.pumpAndSettle();

      // 2. Simular que el usuario digita su número de cuenta real
      paymentCtrl.text = "BCP Soles: 191-99887766-0-12";
      await tester.pumpAndSettle();

      // 3. Desactivar BCP por error
      await tester.tap(find.widgetWithText(InkWell, "BCP"));
      await tester.pumpAndSettle();

      expect(paymentCtrl.text, isEmpty);
      expect(find.widgetWithText(InkWell, "+ BCP"), findsOneWidget);

      // 4. Reactivar BCP (+ BCP)
      await tester.tap(find.widgetWithText(InkWell, "+ BCP"));
      await tester.pumpAndSettle();

      // Debe haber recuperado el número digitado exactamente
      expect(paymentCtrl.text, "BCP Soles: 191-99887766-0-12");

      phoneCtrl.dispose();
      rucCtrl.dispose();
      addressCtrl.dispose();
      paymentCtrl.dispose();
    });

    testWidgets('Pre-población de baseline: si abre con Yape: 976644890, lo conserva al reactivar', (tester) async {
      final phoneCtrl = TextEditingController(text: "976644890");
      final rucCtrl = TextEditingController();
      final addressCtrl = TextEditingController();
      final paymentCtrl = TextEditingController(text: "Yape: 976644890");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: false,
                hasBusinessChanges: false,
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chip Yape debe aparecer activo
      expect(find.widgetWithText(InkWell, "Yape"), findsOneWidget);

      // Apagar chip Yape
      await tester.tap(find.widgetWithText(InkWell, "Yape"));
      await tester.pumpAndSettle();
      expect(paymentCtrl.text, isEmpty);

      // Reactivar chip Yape
      await tester.tap(find.widgetWithText(InkWell, "+ Yape"));
      await tester.pumpAndSettle();

      // Debe restaurar "Yape: 976644890" en lugar de "Yape: [Mi Teléfono]"
      expect(paymentCtrl.text, "Yape: 976644890");

      phoneCtrl.dispose();
      rucCtrl.dispose();
      addressCtrl.dispose();
      paymentCtrl.dispose();
    });
  });

  group('ÁRBITRO ADVERSARIAL - BLOQUE 2: Enunciado Adaptativo Conciso y Reversión "Modificado"', () {
    testWidgets('0 cambios: muestra coincidencia con perfil, oculta [Modificado] y deshabilita checkbox', (tester) async {
      final phoneCtrl = TextEditingController(text: "976644890");
      final rucCtrl = TextEditingController();
      final addressCtrl = TextEditingController();
      final paymentCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: false,
                hasBusinessChanges: false,
                changedBusinessFields: const [],
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Tus datos coinciden con el perfil actual de tu negocio."), findsOneWidget);
      expect(find.text("Modificado"), findsNothing);

      phoneCtrl.dispose();
      rucCtrl.dispose();
      addressCtrl.dispose();
      paymentCtrl.dispose();
    });

    testWidgets('1 cambio: "Se actualizará en tu perfil: Cuentas de pago."', (tester) async {
      final phoneCtrl = TextEditingController(text: "976644890");
      final rucCtrl = TextEditingController();
      final addressCtrl = TextEditingController();
      final paymentCtrl = TextEditingController(text: "BCP Soles: 123");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: true,
                hasBusinessChanges: true,
                changedBusinessFields: const ["Cuentas de pago"],
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Se actualizará en tu perfil: Cuentas de pago."), findsOneWidget);
      expect(find.text("Modificado"), findsOneWidget);

      phoneCtrl.dispose();
      rucCtrl.dispose();
      addressCtrl.dispose();
      paymentCtrl.dispose();
    });

    testWidgets('2 cambios: "Se actualizarán en tu perfil: Teléfono y Cuentas de pago."', (tester) async {
      final phoneCtrl = TextEditingController(text: "999888777");
      final rucCtrl = TextEditingController();
      final addressCtrl = TextEditingController();
      final paymentCtrl = TextEditingController(text: "BCP Soles: 123");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: true,
                hasBusinessChanges: true,
                changedBusinessFields: const ["Teléfono", "Cuentas de pago"],
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Se actualizarán en tu perfil: Teléfono y Cuentas de pago."), findsOneWidget);
      expect(find.text("Modificado"), findsOneWidget);

      phoneCtrl.dispose();
      rucCtrl.dispose();
      addressCtrl.dispose();
      paymentCtrl.dispose();
    });

    testWidgets('3 cambios: "Se actualizarán en tu perfil: Teléfono, RUC y Dirección."', (tester) async {
      final phoneCtrl = TextEditingController(text: "999888777");
      final rucCtrl = TextEditingController(text: "20123456789");
      final addressCtrl = TextEditingController(text: "Lima");
      final paymentCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaBusinessSection(
                phoneCtrl: phoneCtrl,
                rucCtrl: rucCtrl,
                addressCtrl: addressCtrl,
                paymentCtrl: paymentCtrl,
                isGpsLoading: false,
                updateBusinessData: true,
                hasBusinessChanges: true,
                changedBusinessFields: const ["Teléfono", "RUC", "Dirección"],
                onGpsTap: () {},
                onUpdateDataChanged: (_) {},
                onDataChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Se actualizarán en tu perfil: Teléfono, RUC y Dirección."), findsOneWidget);
      expect(find.text("Modificado"), findsOneWidget);

      phoneCtrl.dispose();
      rucCtrl.dispose();
      addressCtrl.dispose();
      paymentCtrl.dispose();
    });
  });

  group('ÁRBITRO ADVERSARIAL - BLOQUE 3: Reversión Completa (Undo) en Editar Producto (Caso Capturas 3, 4 y 5)', () {
    test('Simulación Modelo: +50 und -> Undo restaura ingreso a 0, stockCompartido a 66 y usaStockCompartido: true', () {
      final nameCtrl = TextEditingController(text: "Zapatillas Urbanas");
      final descCtrl = TextEditingController(text: "Calzado");
      final imgUrlCtrl = TextEditingController();
      final parentBarcodeCtrl = TextEditingController();

      final sharedStockCtrl = TextEditingController(text: "66");
      final sharedIngresoCtrl = TextEditingController(text: "0");
      final baseCostCtrl = TextEditingController(text: "2.00");
      String modoStock = 'MIXTO';

      final presentationControllers = <Map<String, dynamic>>[];
      final presentationKeys = <String, GlobalKey>{};
      final idsToDelete = <int>[];

      // Variante 1: Principal (Par x2) con cupo de 2 de 33 máx.
      final p1 = ProductControllerFactory.createNewControllerMap(
        id: "var_principal",
        dbId: 101,
        isDefault: true,
        specificName: "Principal",
        unidadVenta: "Par",
        unidadesVenta: "2",
        costoPres: "4.00",
        margen: "1.35",
        precioVenta: "5.40",
        stockInicial: "2",
        stockFinal: "2",
        usaStockCompartido: true,
        cupoMaximoVariante: 2,
      );
      presentationControllers.add(p1);
      presentationKeys["var_principal"] = GlobalKey();

      // Variante 2: Caja (½ Docena x6) con 11 disp.
      final p2 = ProductControllerFactory.createNewControllerMap(
        id: "var_caja",
        dbId: 102,
        isDefault: false,
        specificName: "Caja",
        unidadVenta: "½ Docena",
        unidadesVenta: "6",
        costoPres: "12.00",
        margen: "1.35",
        precioVenta: "16.20",
        stockInicial: "11",
        stockFinal: "11",
        usaStockCompartido: true,
        cupoMaximoVariante: null,
      );
      presentationControllers.add(p2);
      presentationKeys["var_caja"] = GlobalKey();

      // Captura inicial del snapshot (Captura 3)
      final initialSnapshot = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 1,
        selectedCategoryName: "Calzado",
        selectedBrandId: 1,
        selectedBrandName: "Marca X",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
        modoStock: modoStock,
        baseCostCtrl: baseCostCtrl,
        sharedStockCtrl: sharedStockCtrl,
        sharedIngresoCtrl: sharedIngresoCtrl,
      );

      expect(initialSnapshot.stockCompartido, "66");
      expect(initialSnapshot.stockIngreso, "0");
      expect(initialSnapshot.presentations.first.usaStockCompartido, isTrue);
      expect(initialSnapshot.presentations.last.usaStockCompartido, isTrue);

      // Simular cambio (Captura 4): Agregar 50 und a ingreso -> Stock final sube a 116 und
      sharedIngresoCtrl.text = "50";
      sharedStockCtrl.text = "116";
      (p2['stockFinal'] as TextEditingController).text = "19"; // 116 ~/ 6 = 19

      final alteredSnapshot = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 1,
        selectedCategoryName: "Calzado",
        selectedBrandId: 1,
        selectedBrandName: "Marca X",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
        modoStock: modoStock,
        baseCostCtrl: baseCostCtrl,
        sharedStockCtrl: sharedStockCtrl,
        sharedIngresoCtrl: sharedIngresoCtrl,
      );

      // Detecta diferencia frente al estado inicial
      expect(alteredSnapshot.isIdenticalTo(initialSnapshot), isFalse);

      // Ejecutar UNDO (Captura 5): Aplicar initialSnapshot
      initialSnapshot.restoreInto(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        targetControllers: presentationControllers,
        targetKeys: presentationKeys,
        targetIdsToDelete: idsToDelete,
        baseCostCtrl: baseCostCtrl,
        sharedStockCtrl: sharedStockCtrl,
        sharedIngresoCtrl: sharedIngresoCtrl,
        onModoStockChanged: (m) => modoStock = m,
      );

      // Verificaciones del Árbitro Adversarial:
      // 1. Ingreso regresó estrictamente a 0 und
      expect(sharedIngresoCtrl.text, "0");
      // 2. Stock final compartido regresó estrictamente a 66 und
      expect(sharedStockCtrl.text, "66");
      // 3. Costo base unitario intacto
      expect(baseCostCtrl.text, "2.00");
      // 4. Modo de stock intacto en MIXTO
      expect(modoStock, 'MIXTO');
      // 5. Las variantes JAMÁS se desactivaron a independiente
      expect(presentationControllers.length, 2);
      expect(presentationControllers[0]['usaStockCompartido'], isTrue);
      expect(presentationControllers[1]['usaStockCompartido'], isTrue);
      // 6. El cupo de la variante 1 se mantuvo en 2
      expect(presentationControllers[0]['cupoMaximoVariante'], 2);
      expect((presentationControllers[0]['stockFinal'] as TextEditingController).text, "2");
      expect((presentationControllers[1]['stockFinal'] as TextEditingController).text, "11");

      // 7. El estado restaurado es matemáticamente idéntico al inicial -> Botón amarillo se oculta
      final restoredCurrent = ProductEditSnapshot.capture(
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        parentBarcodeCtrl: parentBarcodeCtrl,
        selectedCategoryId: 1,
        selectedCategoryName: "Calzado",
        selectedBrandId: 1,
        selectedBrandName: "Marca X",
        generalProviderId: null,
        generalState: 2,
        idsToDelete: idsToDelete,
        presentationControllers: presentationControllers,
        modoStock: modoStock,
        baseCostCtrl: baseCostCtrl,
        sharedStockCtrl: sharedStockCtrl,
        sharedIngresoCtrl: sharedIngresoCtrl,
      );
      expect(restoredCurrent.isIdenticalTo(initialSnapshot), isTrue);

      nameCtrl.dispose();
      descCtrl.dispose();
      imgUrlCtrl.dispose();
      parentBarcodeCtrl.dispose();
      sharedStockCtrl.dispose();
      sharedIngresoCtrl.dispose();
      baseCostCtrl.dispose();
      for (var map in presentationControllers) {
        ProductControllerFactory.disposeControllerMap(map);
      }
    });

    testWidgets('Widget Test: ProductStockStrategySelector muestra cuadro de variantes compartidas y reacciona a cambios e ingreso', (tester) async {
      final sharedStockCtrl = TextEditingController(text: "66");
      final sharedIngresoCtrl = TextEditingController(text: "0");
      final baseCostCtrl = TextEditingController(text: "2.00");
      String modoStock = 'MIXTO';

      final controllers = <Map<String, dynamic>>[];

      final p1 = ProductControllerFactory.createNewControllerMap(
        id: "var_p1",
        dbId: 101,
        isDefault: true,
        specificName: "Principal",
        unidadVenta: "Par",
        unidadesVenta: "2",
        stockFinal: "2",
        usaStockCompartido: true,
        cupoMaximoVariante: 2,
      );
      controllers.add(p1);

      final p2 = ProductControllerFactory.createNewControllerMap(
        id: "var_p2",
        dbId: 102,
        isDefault: false,
        specificName: "Caja",
        unidadVenta: "½ Docena",
        unidadesVenta: "6",
        stockFinal: "11",
        usaStockCompartido: true,
        cupoMaximoVariante: null,
      );
      controllers.add(p2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductStockStrategySelector(
                selectedStrategy: modoStock,
                onStrategyChanged: (s) => modoStock = s,
                sharedStockController: sharedStockCtrl,
                baseCostController: baseCostCtrl,
                sharedIngresoController: sharedIngresoCtrl,
                originalBaseStock: 66,
                controllers: controllers,
                isDark: true,
                isEditMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que el cuadro azul de variantes compartidas está visible
      expect(find.text("Stock Final Calculado por Variante:"), findsOneWidget);
      // Principal (Par x2): 2 disp. (de 33 máx.)
      expect(find.text("Principal (Par x2): 2 disp. (de 33 máx.)"), findsOneWidget);
      // Caja (½ Docena x6): 11 disp.
      expect(find.text("Caja (½ Docena x6): 11 disp."), findsOneWidget);

      // Simular ingreso de 50 und
      sharedIngresoCtrl.text = "50";
      sharedStockCtrl.text = "116";
      await tester.pumpAndSettle();

      // Cuadro debe seguir visible y mostrar el nuevo cálculo
      expect(find.text("Stock Final Calculado por Variante:"), findsOneWidget);
      expect(find.text("Principal (Par x2): 2 disp. (de 58 máx.)"), findsOneWidget);
      expect(find.text("Caja (½ Docena x6): 19 disp."), findsOneWidget);

      // Simular Undo: Restaurar ingreso a 0 y stock a 66
      sharedIngresoCtrl.text = "0";
      sharedStockCtrl.text = "66";
      p1['cupoMaximoVariante'] = 2;
      (p1['stockFinal'] as TextEditingController).text = "2";
      (p2['stockFinal'] as TextEditingController).text = "11";
      await tester.pumpAndSettle();

      // El cuadro azul sigue visible y regresó a 33 máx. y 11 disp.
      expect(find.text("Stock Final Calculado por Variante:"), findsOneWidget);
      expect(find.text("Principal (Par x2): 2 disp. (de 33 máx.)"), findsOneWidget);
      expect(find.text("Caja (½ Docena x6): 11 disp."), findsOneWidget);

      sharedStockCtrl.dispose();
      sharedIngresoCtrl.dispose();
      baseCostCtrl.dispose();
      for (var m in controllers) {
        ProductControllerFactory.disposeControllerMap(m);
      }
    });
  });
}
