import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Punto 1: QuickSale y Modales - Stock Vendible y Pool en Vivo', () {
    test('getRemainingPoolStock y getRemainingVendibleStock descuentan demanda en vivo', () {
      final quickProv = QuickSaleProvider();

      final prod = Product(
        id: 501,
        categoriaId: 1,
        nombre: 'Cartulina Bristol',
        modoStock: 'COMPARTIDO',
        stockCompartido: 100,
      );

      final presDocena = ProductPresentation(
        id: 10,
        nombreEspecifico: 'Docena',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 5.0,
      );

      final presPaq3 = ProductPresentation(
        id: 11,
        nombreEspecifico: 'Paquete x3',
        unidadVenta: 'Paq x3',
        unidadesPorVenta: 3,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 1.5,
      );

      final presUnidad = ProductPresentation(
        id: 12,
        nombreEspecifico: 'Unidad',
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 0.5,
      );

      final itemDocena = InventoryWrapper(product: prod, presentation: presDocena);
      final itemPaq3 = InventoryWrapper(product: prod, presentation: presPaq3);
      final itemUnidad = InventoryWrapper(product: prod, presentation: presUnidad);

      // Estado inicial: 100 base units disponibles
      expect(quickProv.getRemainingPoolStock(501, 100), equals(100));
      expect(quickProv.getRemainingVendibleStock(itemDocena), equals(8)); // 100 ~/ 12 = 8
      expect(quickProv.getRemainingVendibleStock(itemPaq3), equals(33)); // 100 ~/ 3 = 33
      expect(quickProv.getRemainingVendibleStock(itemUnidad), equals(100)); // 100 ~/ 1 = 100

      // Agregar 8 docenas al carrito (8 * 12 = 96 base units)
      quickProv.addToCart(itemDocena);
      quickProv.updateQuantity(presDocena.id!, 8, 8);

      // Demanda acumulada en carrito = 96 base units -> Quedan 4 base units
      expect(quickProv.getRemainingPoolStock(501, 100), equals(4));
      // Vendible restante por presentación:
      expect(quickProv.getRemainingVendibleStock(itemDocena), equals(0)); // 4 ~/ 12 = 0
      expect(quickProv.getRemainingVendibleStock(itemPaq3), equals(1)); // 4 ~/ 3 = 1
      expect(quickProv.getRemainingVendibleStock(itemUnidad), equals(4)); // 4 ~/ 1 = 4

      // Modal de edición de la propia Docena (excluyendo su propia demanda)
      final remainingForEditingDocena = quickProv.getRemainingAvailableForPresentation(
        productId: 501,
        presentation: presDocena,
        sharedStockPool: 100,
        excludePresentationId: presDocena.id,
      );
      expect(remainingForEditingDocena, equals(8)); // Vuelve a tener disponibles las 8
    });
  });

  group('Punto 2: Validación Acumulada en MatchingProvider (Escáner IA)', () {
    test('sharedDemandPerProduct e isSharedPoolExceeded alertan cuando combinación de variantes supera pool', () {
      final matchingProv = MatchingProvider();

      final matchedDocena = MatchedProduct(
        productId: 700,
        presentationId: 21,
        fullName: 'Pliego Bond Docena',
        productName: 'Pliego Bond',
        price: 10.0,
        stock: 8, // 100 ~/ 12
        conversionFactor: 12,
        usaStockCompartido: true,
        sharedStockPool: 100,
      );

      final matchedPaq3 = MatchedProduct(
        productId: 700,
        presentationId: 22,
        fullName: 'Pliego Bond Paquete x3',
        productName: 'Pliego Bond',
        price: 3.0,
        stock: 33, // 100 ~/ 3
        conversionFactor: 3,
        usaStockCompartido: true,
        sharedStockPool: 100,
      );

      final itemA = ExtractedItem(id: 1, originalText: '8 Docenas Bond', fullName: 'Docena', quantity: 8);
      final itemB = ExtractedItem(id: 2, originalText: '1 Paquete Bond', fullName: 'Paquete', quantity: 1);

      final pairA = MatchPair(sourceItem: itemA, status: MatchStatus.manual);
      pairA.selectedProduct = matchedDocena;
      pairA.selectedQuantity = 8; // 8 * 12 = 96 base

      final pairB = MatchPair(sourceItem: itemB, status: MatchStatus.manual);
      pairB.selectedProduct = matchedPaq3;
      pairB.selectedQuantity = 1; // 1 * 3 = 3 base

      matchingProv.pairs.addAll([pairA, pairB]);

      // Total = 96 + 3 = 99 <= 100
      expect(matchingProv.sharedDemandPerProduct[700], equals(99));
      expect(matchingProv.isSharedPoolExceeded(700, 100), isFalse);
      expect(matchingProv.hasStockWarnings, isFalse);

      // Ahora usuario sube pairB a 2 paquetes (2 * 3 = 6 base) -> Total = 96 + 6 = 102 > 100!
      matchingProv.updatePairQuantity(2, 2);

      expect(matchingProv.sharedDemandPerProduct[700], equals(102));
      expect(matchingProv.isSharedPoolExceeded(700, 100), isTrue);
      expect(matchingProv.hasStockWarnings, isTrue);
    });
  });

  group('Punto 3: Propagación Proporcional de Costo en SmartRestock (SQLite)', () {
    test('Actualizar costo base en pool compartido recalcula atómicamente costo_unitario_calculado en variantes vinculadas', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE productos (
              id INTEGER PRIMARY KEY,
              nombre TEXT,
              modo_stock TEXT,
              stock_compartido INTEGER,
              costo_base REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE presentaciones_producto (
              id INTEGER PRIMARY KEY,
              producto_id INTEGER,
              unidades_por_venta INTEGER,
              usa_stock_compartido INTEGER,
              costo_unitario_calculado REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE product_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              entidad_tipo TEXT,
              entidad_id INTEGER,
              campo_modificado TEXT,
              valor_anterior TEXT,
              valor_nuevo TEXT,
              fecha_cambio TEXT
            )
          ''');
        },
      );

      // Insertar producto con costo_base = 0
      await db.insert('productos', {
        'id': 88,
        'nombre': 'Cuaderno Loro 100h',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 120,
        'costo_base': 0.0,
      });

      // Variante 1: Unidad (1x) vinculada al pool
      await db.insert('presentaciones_producto', {
        'id': 881,
        'producto_id': 88,
        'unidades_por_venta': 1,
        'usa_stock_compartido': 1,
        'costo_unitario_calculado': 0.0,
      });

      // Variante 2: Docena (12x) vinculada al pool
      await db.insert('presentaciones_producto', {
        'id': 882,
        'producto_id': 88,
        'unidades_por_venta': 12,
        'usa_stock_compartido': 1,
        'costo_unitario_calculado': 0.0,
      });

      // Variante 3: Especial (10x) independiente (usa_stock_compartido = 0)
      await db.insert('presentaciones_producto', {
        'id': 883,
        'producto_id': 88,
        'unidades_por_venta': 10,
        'usa_stock_compartido': 0,
        'costo_unitario_calculado': 25.0,
      });

      // Usuario asigna costo base de S/ 2.50 en la tarjeta consolidada de Restock
      final double newCost = 2.50;
      await db.transaction((txn) async {
        await txn.update(
          'productos',
          {'costo_base': newCost},
          where: 'id = ?',
          whereArgs: [88],
        );

        await txn.rawUpdate('''
          UPDATE presentaciones_producto
          SET costo_unitario_calculado = ? * CAST(unidades_por_venta AS REAL)
          WHERE producto_id = ? AND usa_stock_compartido = 1
        ''', [newCost, 88]);
      });

      // Verificar producto
      final prodRows = await db.query('productos', where: 'id = ?', whereArgs: [88]);
      expect(prodRows.first['costo_base'], equals(2.50));

      // Verificar variante 1 (Unidad): 2.50 * 1 = 2.50
      final v1 = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [881]);
      expect(v1.first['costo_unitario_calculado'], equals(2.50));

      // Verificar variante 2 (Docena): 2.50 * 12 = 30.00
      final v2 = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [882]);
      expect(v2.first['costo_unitario_calculado'], equals(30.00));

      // Verificar variante 3 (Independiente): Intacta en 25.00
      final v3 = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [883]);
      expect(v3.first['costo_unitario_calculado'], equals(25.00));

      await db.close();
    });
  });

  group('Punto 4: Compatibilidad de Columnas V25 en Respaldo y Restauración', () {
    test('Restauración maneja correctamente modo_stock, stock_compartido, costo_base y usa_stock_compartido', () {
      // Simular datos de backup legacy (sin columnas V25)
      final legacyProduct = {
        'id': 1,
        'nombre': 'Producto Legacy',
        'categoria_id': 1,
      };

      final legacyPresentation = {
        'id': 10,
        'producto_id': 1,
        'stock_actual': 20,
      };

      // Normalización aplicada en restoreBackup:
      final restoredProduct = Map<String, dynamic>.from(legacyProduct);
      restoredProduct['modo_stock'] = restoredProduct['modo_stock'] ?? 'INDEPENDIENTE';
      restoredProduct['stock_compartido'] = restoredProduct['stock_compartido'] ?? 0;
      restoredProduct['costo_base'] = restoredProduct['costo_base'] ?? 0.0;

      final restoredPres = Map<String, dynamic>.from(legacyPresentation);
      restoredPres['usa_stock_compartido'] = restoredPres['usa_stock_compartido'] ?? 0;

      expect(restoredProduct['modo_stock'], equals('INDEPENDIENTE'));
      expect(restoredProduct['stock_compartido'], equals(0));
      expect(restoredProduct['costo_base'], equals(0.0));
      expect(restoredPres['usa_stock_compartido'], equals(0));

      // Simular datos de backup V25 (con columnas V25 presentes)
      final v25Product = {
        'id': 2,
        'nombre': 'Producto V25',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 150,
        'costo_base': 1.25,
      };

      final v25Presentation = {
        'id': 20,
        'producto_id': 2,
        'stock_actual': 150,
        'usa_stock_compartido': 1,
      };

      final restoredV25Product = Map<String, dynamic>.from(v25Product);
      restoredV25Product['modo_stock'] = restoredV25Product['modo_stock'] ?? 'INDEPENDIENTE';
      restoredV25Product['stock_compartido'] = restoredV25Product['stock_compartido'] ?? 0;
      restoredV25Product['costo_base'] = restoredV25Product['costo_base'] ?? 0.0;

      final restoredV25Pres = Map<String, dynamic>.from(v25Presentation);
      restoredV25Pres['usa_stock_compartido'] = restoredV25Pres['usa_stock_compartido'] ?? 0;

      expect(restoredV25Product['modo_stock'], equals('COMPARTIDO'));
      expect(restoredV25Product['stock_compartido'], equals(150));
      expect(restoredV25Product['costo_base'], equals(1.25));
      expect(restoredV25Pres['usa_stock_compartido'], equals(1));
    });
  });
}
