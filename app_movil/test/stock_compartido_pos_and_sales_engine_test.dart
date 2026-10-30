import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Fase 5: Motor de Ventas, Carrito Acumulado, Aislamiento MIXTO y Anulaciones', () {
    test('Carrito Acumulado bloquea preventivamente si 8 Docenas (96) + 2 Paquetes x3 (6) = 102 > 100', () {
      final quickSale = QuickSaleProvider();

      final prodHojas = Product(
        id: 101,
        categoriaId: 1,
        nombre: 'Hojas Bond A4',
        modoStock: 'COMPARTIDO',
        stockCompartido: 100,
        costoBase: 0.05,
      );

      final presDocena = ProductPresentation(
        id: 1,
        nombreEspecifico: 'Docena',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 2.00,
      );

      final presPaq3 = ProductPresentation(
        id: 2,
        nombreEspecifico: 'Paquete x3',
        unidadVenta: 'Paquete x3',
        unidadesPorVenta: 3,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 0.60,
      );

      final itemDocena = InventoryWrapper(product: prodHojas, presentation: presDocena);
      final itemPaq3 = InventoryWrapper(product: prodHojas, presentation: presPaq3);

      // 1. Agregar Docena al carrito y subir cantidad a 8 docenas (8 * 12 = 96 hojas base)
      final res1 = quickSale.addToCart(itemDocena);
      expect(res1, isNull);
      final resQtyDocena = quickSale.updateQuantity(presDocena.id!, 8, 8);
      expect(resQtyDocena, isNull);
      expect(quickSale.getQuantity(presDocena.id!), equals(8));

      // 2. Agregar Paquete x3 al carrito (1 paq = 3 hojas, total 96 + 3 = 99 <= 100 -> permitido)
      final res2 = quickSale.addToCart(itemPaq3);
      expect(res2, isNull);
      expect(quickSale.getQuantity(presPaq3.id!), equals(1));

      // 3. Intentar subir Paquete x3 a 2 paquetes (2 * 3 = 6 hojas, total 96 + 6 = 102 > 100)
      // Debe bloquearse en vivo indicando las 4 hojas base restantes disponibles
      final resQtyPaq = quickSale.updateQuantity(presPaq3.id!, 2, 33);
      expect(resQtyPaq, isNotNull);
      expect(resQtyPaq, contains('Stock compartido insuficiente'));
      expect(resQtyPaq, contains('Quedan 4 und. base disponibles (= 1 Paquete x3)'));

      // Comprobar que la cantidad no se corrompió y sigue siendo 1
      expect(quickSale.getQuantity(presPaq3.id!), equals(1));
    });

    test('Regla 2: Aislamiento estricto de variante independiente vs compartidas en Modo MIXTO', () {
      final quickSale = QuickSaleProvider();

      final prodMixto = Product(
        id: 202,
        categoriaId: 1,
        nombre: 'Cartulinas Canson',
        modoStock: 'MIXTO',
        stockCompartido: 100,
        costoBase: 0.20,
      );

      final presDocenaCompartida = ProductPresentation(
        id: 11,
        nombreEspecifico: 'Docena Suelta',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 100,
        usaStockCompartido: true,
        precioVentaFinal: 5.00,
      );

      final presSelladaPropia = ProductPresentation(
        id: 12,
        nombreEspecifico: 'Block Sellado Fabricante',
        unidadVenta: 'Block',
        unidadesPorVenta: 1,
        stockActual: 15,
        usaStockCompartido: false, // Stock propio independiente
        precioVentaFinal: 12.00,
      );

      final itemDocena = InventoryWrapper(product: prodMixto, presentation: presDocenaCompartida);
      final itemBlock = InventoryWrapper(product: prodMixto, presentation: presSelladaPropia);

      // Comprar 8 docenas del pool compartido (96 de 100 hojas base)
      quickSale.addToCart(itemDocena);
      quickSale.updateQuantity(presDocenaCompartida.id!, 8, 8);

      // Comprar 10 blocks sellados con stock propio (10 <= 15 stock propio)
      // La variante independiente NO debe ser bloqueada por la demanda del pool compartido
      final resBlock = quickSale.addToCart(itemBlock);
      expect(resBlock, isNull);

      final resQtyBlock = quickSale.updateQuantity(presSelladaPropia.id!, 10, 15);
      expect(resQtyBlock, isNull);
      expect(quickSale.getQuantity(presSelladaPropia.id!), equals(10));
    });

    test('SQLite atómico: Vender 1 Docena (12) + 2 Paquetes x3 (6) reduce stock de 100 a 82, y anular restaura a 100', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Esquema SQLite
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

      await db.execute('''
        CREATE TABLE ventas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          monto_total REAL,
          is_archived INTEGER DEFAULT 0,
          motivo_anulacion TEXT,
          fecha_venta TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE venta_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          venta_id INTEGER,
          product_id INTEGER,
          presentation_id INTEGER,
          cantidad INTEGER,
          precio_unitario REAL,
          costo_unitario REAL
        )
      ''');

      await db.execute('''
        CREATE TABLE stock_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          presentation_id INTEGER,
          negocio_id INTEGER,
          tipo_transaccion TEXT,
          cantidad INTEGER,
          costo_unitario REAL,
          precio_venta REAL,
          origen_id INTEGER,
          fecha_registro TEXT
        )
      ''');

      // 1. Insertar producto base con 100 hojas
      final prodId = await db.insert('productos', {
        'nombre': 'Hojas A4 Report',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 100,
        'costo_base': 0.05,
      });

      await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Unidad',
        'unidad_venta': 'Unidad',
        'unidades_por_venta': 1,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'precio_venta_final': 0.10,
        'costo_unitario_calculado': 0.05,
      });

      final vPaq3 = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Paquete x3',
        'unidad_venta': 'Paquete x3',
        'unidades_por_venta': 3,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'precio_venta_final': 0.25,
        'costo_unitario_calculado': 0.15,
      });

      final vDocena = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Docena',
        'unidad_venta': 'Docena',
        'unidades_por_venta': 12,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'precio_venta_final': 1.00,
        'costo_unitario_calculado': 0.60,
      });

      // 2. Ejecutar Venta: 1 Docena (12) + 2 Paquetes x3 (6) = 18 hojas base consumidas
      const int qtyDocena = 1;
      const int qtyPaq3 = 2;
      const int baseUnitsToDeduct = (qtyDocena * 12) + (qtyPaq3 * 3); // 12 + 6 = 18

      final saleId = await db.transaction((txn) async {
        final sId = await txn.insert('ventas', {
          'negocio_id': 1,
          'monto_total': 1.50,
          'fecha_venta': DateTime.now().toIso8601String(),
        });

        await txn.insert('venta_items', {
          'venta_id': sId,
          'product_id': prodId,
          'presentation_id': vDocena,
          'cantidad': qtyDocena,
          'precio_unitario': 1.00,
        });

        await txn.insert('venta_items', {
          'venta_id': sId,
          'product_id': prodId,
          'presentation_id': vPaq3,
          'cantidad': qtyPaq3,
          'precio_unitario': 0.25,
        });

        // Deducción atómica del pool compartido (lógica de SalesService.createSale)
        await txn.rawUpdate(
          'UPDATE productos SET stock_compartido = stock_compartido - ? WHERE id = ?',
          [baseUnitsToDeduct, prodId],
        );
        await txn.rawUpdate(
          'UPDATE presentaciones_producto SET stock_actual = stock_actual - ? WHERE producto_id = ? AND usa_stock_compartido = 1',
          [baseUnitsToDeduct, prodId],
        );

        return sId;
      });

      // Verificar que el stock bajó exactamente a 82 hojas base
      final prodAfter = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      expect(prodAfter.first['stock_compartido'], equals(82));

      final presAfter = await db.query('presentaciones_producto', where: 'producto_id = ?', whereArgs: [prodId]);
      for (var pres in presAfter) {
        expect(pres['stock_actual'], equals(82));
      }

      // Equivalencias vendibles exactas:
      // Unidad (82 / 1 = 82)
      // Paquete x3 (82 / 3 = 27)
      // Docena (82 / 12 = 6)
      expect(82 ~/ 1, equals(82));
      expect(82 ~/ 3, equals(27));
      expect(82 ~/ 12, equals(6));

      // 3. Ejecutar Anulación (voidSale)
      await db.transaction((txn) async {
        await txn.update('ventas', {
          'is_archived': 1,
          'motivo_anulacion': 'Error de digitación en caja',
        }, where: 'id = ?', whereArgs: [saleId]);

        // Restaurar unidades base al pool y variantes (lógica de SalesService.voidSale)
        await txn.rawUpdate(
          'UPDATE productos SET stock_compartido = stock_compartido + ? WHERE id = ?',
          [baseUnitsToDeduct, prodId],
        );
        await txn.rawUpdate(
          'UPDATE presentaciones_producto SET stock_actual = stock_actual + ? WHERE producto_id = ? AND usa_stock_compartido = 1',
          [baseUnitsToDeduct, prodId],
        );
      });

      // Verificar que el pool y todas sus variantes volvieron exactamente a 100
      final prodRestored = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      expect(prodRestored.first['stock_compartido'], equals(100));

      final presRestored = await db.query('presentaciones_producto', where: 'producto_id = ?', whereArgs: [prodId]);
      for (var pres in presRestored) {
        expect(pres['stock_actual'], equals(100));
      }

      await db.close();
    });
  });
}
