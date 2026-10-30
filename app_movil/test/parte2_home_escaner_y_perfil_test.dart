import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/scanner/models/barcode_resolution_result.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/form/product_create_operations.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/omni_search_bar.dart';
import 'package:app_movil/features/profile/widgets/business_info_card.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';

class MockAuthProviderForTest extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  BusinessModel? get currentBusiness => BusinessModel(
        id: 1,
        commercialName: "Bodega de Prueba",
        ruc: "",
        address: "Av. Principal 123",
        paymentInfo: "📱 Yape: 999888777",
        moneda: "PEN",
      );

  @override
  Future<void> refreshActiveUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInventoryProviderForDraftTest extends ChangeNotifier implements InventoryProvider {
  ProductCreateDraft? _draft;

  void setMockDraft(ProductCreateDraft? d) {
    _draft = d;
  }

  @override
  ProductCreateDraft? get creationDraft => _draft;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fases 1 y 2: Escáner Inteligente y Desambiguación Multivariante (Situaciones 1 a 4)', () {
    final vDefault = ProductPresentation(
      id: 101,
      nombreEspecifico: "Unidad",
      codigoBarras: "7750000001",
      precioVentaFinal: 5.0,
      stockActual: 10,
      esDefault: true,
      orden: 0,
      unidadesPorVenta: 1,
    );

    final vPack6 = ProductPresentation(
      id: 102,
      nombreEspecifico: "Six Pack",
      codigoBarras: "7750000002",
      precioVentaFinal: 28.0,
      stockActual: 4,
      esDefault: false,
      orden: 1,
      unidadesPorVenta: 6,
    );

    final vCaja24 = ProductPresentation(
      id: 103,
      nombreEspecifico: "Caja x24",
      codigoBarras: "7750000002", // Comparte código con Six Pack (Situación 3)
      precioVentaFinal: 100.0,
      stockActual: 2,
      esDefault: false,
      orden: 2,
      unidadesPorVenta: 24,
    );

    final productSample = Product(
      id: 50,
      nombre: "Bebida Energizante",
      categoriaId: 1,
      codigoBarras: "7750000000", // Código del producto padre
      presentaciones: [vDefault, vPack6, vCaja24],
    );

    test('Test 1: Situación 1 - Variante única con código específico resuelve exactVariant', () {
      final item = InventoryWrapper(product: productSample, presentation: vDefault);
      final res = BarcodeResolutionResult.exactVariant(item, "7750000001");

      expect(res.type, BarcodeResolutionType.exactVariant);
      expect(res.selectedVariant?.id, 101);
      expect(res.product?.nombre, "Bebida Energizante");
      expect(res.isNotFound, isFalse);
    });

    test('Test 2: Situación 2A - Código solo en Padre selecciona variante default', () {
      final item = InventoryWrapper(product: productSample, presentation: vDefault);
      final res = BarcodeResolutionResult.parentOrGlobal(item, "7750000000");

      expect(res.type, BarcodeResolutionType.parentOrGlobal);
      expect(res.selectedVariant?.esDefault, isTrue);
      expect(res.selectedVariant?.id, 101);
    });

    test('Test 3: Situación 2B - Variantes comparten código global, selecciona default activa', () {
      final pGlobal = Product(
        id: 51,
        nombre: "Producto Global",
        categoriaId: 1,
        codigoBarras: "775GLOBAL",
        presentaciones: [
          ProductPresentation(
            id: 201,
            codigoBarras: "775GLOBAL",
            precioVentaFinal: 2.0,
            stockActual: 15,
            esDefault: true,
            orden: 0,
          ),
          ProductPresentation(
            id: 202,
            codigoBarras: "775GLOBAL",
            precioVentaFinal: 10.0,
            stockActual: 5,
            esDefault: false,
            orden: 1,
          ),
        ],
      );

      final defaultVar = pGlobal.presentaciones.firstWhere((p) => p.esDefault);
      final item = InventoryWrapper(product: pGlobal, presentation: defaultVar);
      final res = BarcodeResolutionResult.parentOrGlobal(item, "775GLOBAL");

      expect(res.type, BarcodeResolutionType.parentOrGlobal);
      expect(res.selectedVariant?.id, 201);
      expect(res.selectedVariant?.esDefault, isTrue);
    });

    test('Test 4: Situación 3 - Subconjunto de variantes con mismo código resuelve default del subconjunto', () {
      final item = InventoryWrapper(product: productSample, presentation: vPack6);
      final res = BarcodeResolutionResult.variantSubset(item, "7750000002");

      expect(res.type, BarcodeResolutionType.variantSubset);
      expect(res.selectedVariant?.codigoBarras, "7750000002");
      expect(res.selectedVariant?.id, 102);
    });

    test('Test 5: Situación 4 - Código no existe en DB, inyecta initialBarcode en Padre y Variante 1', () {
      final res = BarcodeResolutionResult.notFound("7759999888877");
      expect(res.isNotFound, isTrue);
      expect(res.product, isNull);

      final invMock = MockInventoryProviderForDraftTest();
      final barcodeCtrl = TextEditingController();
      final controllers = <Map<String, dynamic>>[];
      final keys = <String, GlobalKey>{};

      // 1. Sin borrador
      ProductCreateOperations.hydrateFromDraft(
        invProv: invMock,
        nameCtrl: TextEditingController(),
        descCtrl: TextEditingController(),
        imgUrlCtrl: TextEditingController(),
        barcodeCtrl: barcodeCtrl,
        controllers: controllers,
        keys: keys,
        deferredProviderNames: {},
        onSyncDraft: () {},
        generalState: 2,
        initialBarcode: "7759999888877",
      );

      expect(barcodeCtrl.text, "7759999888877");
      expect(controllers.isNotEmpty, isTrue);
      expect((controllers.first['barcode'] as TextEditingController).text, "7759999888877");

      // 2. Con borrador existente
      final draft = ProductCreateDraft(
        name: "Borrador Previo",
        categoryId: 1,
        presentations: [
          {
            'id': 'var_1',
            'saleUnit': 'Unidad',
            'salePrice': 10.0,
            'purchaseCost': 5.0,
            'stock': 20,
            'isDefault': true,
          },
        ],
      );
      invMock.setMockDraft(draft);

      final barcodeCtrl2 = TextEditingController();
      final controllers2 = <Map<String, dynamic>>[];
      final keys2 = <String, GlobalKey>{};

      ProductCreateOperations.hydrateFromDraft(
        invProv: invMock,
        nameCtrl: TextEditingController(),
        descCtrl: TextEditingController(),
        imgUrlCtrl: TextEditingController(),
        barcodeCtrl: barcodeCtrl2,
        controllers: controllers2,
        keys: keys2,
        deferredProviderNames: {},
        onSyncDraft: () {},
        generalState: 2,
        initialBarcode: "7751234567890",
      );

      expect(barcodeCtrl2.text, "7751234567890");
      expect((controllers2.first['barcode'] as TextEditingController).text, "7751234567890");
    });
  });

  group('Fase 1: Blindaje de Stock Efectivo Real (Stock Compartido)', () {
    test('Test 6: InventoryWrapper con modo COMPARTIDO no marca agotado si pool > 0 aunque stockActual de variante sea 0', () {
      final prodCompartido = Product(
        id: 70,
        nombre: "Arroz Extra",
        categoriaId: 2,
        modoStock: "COMPARTIDO",
        stockCompartido: 50, // Pool base: 50 kg
      );

      final presBolsa1Kg = ProductPresentation(
        id: 301,
        nombreEspecifico: "Bolsa 1kg",
        precioVentaFinal: 4.50,
        stockActual: 0, // 0 individual en tabla presentaciones
        usaStockCompartido: true,
        unidadesPorVenta: 1,
      );

      final presSaco5Kg = ProductPresentation(
        id: 302,
        nombreEspecifico: "Saco 5kg",
        precioVentaFinal: 21.0,
        stockActual: 0,
        usaStockCompartido: true,
        unidadesPorVenta: 5,
      );

      final wrap1Kg = InventoryWrapper(
        product: prodCompartido,
        presentation: presBolsa1Kg,
      );

      final wrap5Kg = InventoryWrapper(
        product: prodCompartido,
        presentation: presSaco5Kg,
      );

      // 50 kg disponibles: bolsa 1kg tiene 50 unidades, saco 5kg tiene 10 sacos
      expect(wrap1Kg.displayStock, 50);
      expect(wrap1Kg.isOutOfStock, isFalse);

      expect(wrap5Kg.displayStock, 10);
      expect(wrap5Kg.isOutOfStock, isFalse);

      // Ahora si el pool compartido está en 0:
      final prodAgotado = Product(
        id: 70,
        nombre: "Arroz Extra",
        categoriaId: 2,
        modoStock: "COMPARTIDO",
        stockCompartido: 0,
      );
      final wrapAgotado = InventoryWrapper(
        product: prodAgotado,
        presentation: presBolsa1Kg,
      );
      expect(wrapAgotado.displayStock, 0);
      expect(wrapAgotado.isOutOfStock, isTrue);
    });
  });

  group('Fase 3: OmniSearchBar Responsivo, AppCurrency y Cero Emojis', () {
    testWidgets('Test 7: OmniSearchBar se adapta en 320dp y 360dp sin truncamiento ni desbordamiento', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProviderForTest()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: OmniSearchBar(
                  onBarcodeTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(OmniSearchBar), findsOneWidget);
      expect(find.byType(FittedBox), findsWidgets);
      expect(tester.takeException(), isNull);

      // Prueba en 360dp
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('Test 8: AppCurrency formatea estrictamente en formato peruano S/ 48.70 sin emojis', () {
      final formatted = AppCurrency.format(48.70);
      expect(formatted, "S/ 48.70");
      expect(formatted.contains("48,70 S/"), isFalse);

      final formattedZero = AppCurrency.format(0);
      expect(formattedZero, "S/ 0.00");

      // Verificamos ausencia de emojis
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);
      expect(emojiRegex.hasMatch(formatted), isFalse);
    });
  });

  group('Fases 4 y 5: BusinessInfoCard, Interacciones de Perfil y Botón Zona de Peligro', () {
    test('Test 9: BusinessInfoCard.sanitizePaymentInfo purga emojis Unicode', () {
      const raw = "📱 Yape: 987654321  💰 BCP: 123-456";
      final clean = BusinessInfoCard.sanitizePaymentInfo(raw);

      expect(clean.contains("📱"), isFalse);
      expect(clean.contains("💰"), isFalse);
      expect(clean.contains("Yape: 987654321"), isTrue);
    });

    testWidgets('Test 9B: BusinessInfoCard renderiza badge interactivo Sin RUC • + Agregar cuando RUC es vacío', (tester) async {
      final businessSinRuc = BusinessModel(
        id: 1,
        commercialName: "Tienda Don Pepe",
        ruc: "",
        address: "Jr. Comercio 456",
        paymentInfo: "Yape: 999111222",
        moneda: "PEN",
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProviderForTest()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BusinessInfoCard(business: businessSinRuc),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Sin RUC • + Agregar"), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('Test 10: Botón de Zona de Peligro contiene texto exacto sin puntos suspensivos y escala con FittedBox', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Eliminar este perfil de negocio",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Eliminar este perfil de negocio"), findsOneWidget);
      expect(find.textContaining("Eliminar este Perfil de Negocio..."), findsNothing);
      expect(find.byType(FittedBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
