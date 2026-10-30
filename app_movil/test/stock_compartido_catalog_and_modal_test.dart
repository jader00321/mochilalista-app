import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/catalog_item_card.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_variant_selector.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Fase 3: Auditoría de Catálogo, Detalle de Producto, Ajuste Rápido y Escáner (360dp)', () {
    testWidgets('CatalogItemCard en 360dp muestra badge de Pool Compartido sin overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prod = Product(
        id: 1,
        nombre: 'Papel Hojas Bond A4 75g',
        categoriaId: 1,
        modoStock: 'COMPARTIDO',
        stockCompartido: 100,
        costoBase: 0.08,
      );

      final pres = ProductPresentation(
        id: 10,
        nombreEspecifico: 'Docena',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 2.00,
        costoUnitarioCalculado: 0.96,
      );

      final item = InventoryWrapper(
        product: prod,
        presentation: pres,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<CatalogProvider>(
              create: (_) => CatalogProvider(),
              child: SizedBox(
                width: 170, // Ancho de columna en GridView de 360dp
                height: 320,
                child: CatalogItemCard(
                  item: item,
                  onDetails: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Comprueba el badge del pool
      expect(find.text('Pool: 8 disp.'), findsOneWidget);
      expect(find.text('DOCENA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CatalogItemCard en 360dp muestra stock independiente sin overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prod = Product(
        id: 2,
        nombre: 'Pilas Alcalinas AA',
        categoriaId: 2,
        modoStock: 'INDEPENDIENTE',
        stockCompartido: 0,
      );

      final pres = ProductPresentation(
        id: 20,
        nombreEspecifico: 'Par',
        unidadVenta: 'Par',
        unidadesPorVenta: 2,
        stockActual: 50,
        usaStockCompartido: false,
        precioVentaFinal: 5.00,
        costoUnitarioCalculado: 2.50,
      );

      final item = InventoryWrapper(
        product: prod,
        presentation: pres,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<CatalogProvider>(
              create: (_) => CatalogProvider(),
              child: SizedBox(
                width: 170,
                height: 320,
                child: CatalogItemCard(
                  item: item,
                  onDetails: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('25 disp.'), findsOneWidget);
      expect(find.text('PAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProductDetailVariantSelector en 360dp visualiza badges de Pool y variantes individuales', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final presentations = [
        ProductPresentation(
          id: 1,
          nombreEspecifico: 'Unidad',
          unidadVenta: 'Unidad',
          unidadesPorVenta: 1,
          stockActual: 100,
          usaStockCompartido: true,
          precioVentaFinal: 0.10,
        ),
        ProductPresentation(
          id: 2,
          nombreEspecifico: 'Docena',
          unidadVenta: 'Docena',
          unidadesPorVenta: 12,
          stockActual: 100,
          usaStockCompartido: true,
          precioVentaFinal: 1.00,
        ),
        ProductPresentation(
          id: 3,
          nombreEspecifico: 'Pack Especial Sellado',
          unidadVenta: 'Pack',
          unidadesPorVenta: 5,
          stockActual: 20,
          usaStockCompartido: false,
          precioVentaFinal: 3.00,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ProductDetailVariantSelector(
                presentations: presentations,
                selectedPresentationId: 1,
                isDark: false,
                textColor: Colors.black87,
                onSelectPresentation: (_) {},
              ),
            ),
          ),
        ),
      );

      // Comprueba los badges de pool en las variantes compartidas y stock directo en la independiente
      expect(find.text('Pool: 100 disp.'), findsOneWidget);
      expect(find.text('Pool: 8 disp.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('4 disp.'), 100);
      expect(find.text('4 disp.'), findsOneWidget); // 20 ~/ 5 = 4
      expect(tester.takeException(), isNull);
    });

    testWidgets('StockUpdateModal detecta usaStockCompartido y despliega banner informativo', (tester) async {
      final sharedPresentation = ProductPresentation(
        id: 99,
        nombreEspecifico: 'Docena',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 2.00,
      );

      final invProv = InventoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: sharedPresentation,
              provider: invProv,
              isDark: false,
            ),
          ),
        ),
      );

      // Comprueba que el banner informativo del pool compartido está visible
      expect(find.textContaining('Esta presentación usa el Pool Compartido'), findsOneWidget);
      expect(find.byIcon(Icons.hub_rounded), findsWidgets);
    });

    test('SQLite atómico: Actualización de stock en variante compartida sincroniza pool y variantes hermanas', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Crear esquema
      await db.execute('''
        CREATE TABLE productos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT,
          modo_stock TEXT DEFAULT 'INDEPENDIENTE',
          stock_compartido INTEGER DEFAULT 0,
          costo_base REAL DEFAULT 0.0
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
          usa_stock_compartido INTEGER DEFAULT 0,
          precio_venta_final REAL DEFAULT 0.0,
          costo_unitario_calculado REAL DEFAULT 0.0,
          activo INTEGER DEFAULT 1
        )
      ''');

      // Insertar producto Hojas A4 en modo COMPARTIDO con 100 und iniciales
      final prodId = await db.insert('productos', {
        'nombre': 'Hojas Bond A4',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 100,
        'costo_base': 0.05,
      });

      // Insertar 3 variantes compartidas
      await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Unidad',
        'unidad_venta': 'Unidad',
        'unidades_por_venta': 1,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'precio_venta_final': 0.10,
      });

      await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Paquete x3',
        'unidad_venta': 'Paquete x3',
        'unidades_por_venta': 3,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'precio_venta_final': 0.20,
      });

      await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Docena',
        'unidad_venta': 'Docena',
        'unidades_por_venta': 12,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'precio_venta_final': 1.00,
      });

      // Simular ajuste o ingreso de lote (ej. escáner o modal de ajuste rápido) sumando +50 unidades
      const int nuevoStockBase = 150;

      await db.transaction((txn) async {
        // Actualizar pool maestro en productos
        await txn.update(
          'productos',
          {'stock_compartido': nuevoStockBase},
          where: 'id = ?',
          whereArgs: [prodId],
        );
        // Sincronizar todas las presentaciones que usen el pool compartido
        await txn.update(
          'presentaciones_producto',
          {'stock_actual': nuevoStockBase},
          where: 'producto_id = ? AND usa_stock_compartido = 1',
          whereArgs: [prodId],
        );
      });

      // Verificar que el producto y LAS TRES variantes tienen exactamente 150 unidades base
      final prodRow = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      expect(prodRow.first['stock_compartido'], equals(150));

      final presRows = await db.query(
        'presentaciones_producto',
        where: 'producto_id = ? AND usa_stock_compartido = 1',
        whereArgs: [prodId],
      );

      for (var row in presRows) {
        expect(row['stock_actual'], equals(150));
      }

      // Cerrar db
      await db.close();
    });
  });
}
