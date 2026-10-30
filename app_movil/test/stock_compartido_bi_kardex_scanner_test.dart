import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Fase 6 & 7: Kardex Trazabilidad, Business Intelligence (BI) y Motor ROP', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE negocios (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE categorias (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE marcas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE productos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          categoria_id INTEGER,
          marca_id INTEGER,
          nombre TEXT,
          descripcion TEXT,
          modo_stock TEXT DEFAULT 'INDEPENDIENTE',
          stock_compartido INTEGER DEFAULT 0,
          costo_base REAL DEFAULT 0.0,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE presentaciones_producto (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          producto_id INTEGER,
          nombre_especifico TEXT,
          unidad_venta TEXT DEFAULT 'Unidad',
          unidades_por_venta INTEGER DEFAULT 1,
          costo_unitario_calculado REAL,
          precio_venta_final REAL DEFAULT 0.00,
          stock_actual INTEGER DEFAULT 0,
          stock_alerta INTEGER DEFAULT 5,
          usa_stock_compartido INTEGER DEFAULT 0,
          es_default INTEGER DEFAULT 0,
          orden INTEGER DEFAULT 0,
          activo INTEGER DEFAULT 1
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
      await db.execute('''
        CREATE TABLE ventas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          fecha_venta TEXT,
          origen_venta TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE venta_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          venta_id INTEGER,
          presentation_id INTEGER,
          bundle_id INTEGER,
          cantidad INTEGER,
          subtotal REAL
        )
      ''');

      // Sembrar datos básicos
      await db.insert('negocios', {'id': 1, 'nombre': 'Bodega Central'});
      await db.insert('categorias', {'id': 1, 'nombre': 'Papelería'});
      await db.insert('marcas', {'id': 1, 'nombre': 'Standford'});
    });

    tearDown(() async {
      await db.close();
    });

    test('Regla 1: Certificación Matemática de Valor de Inventario sin duplicar pool compartido', () async {
      // 1. Producto COMPARTIDO: Hojas Bond A4 (100 unidades base físicas, costo base 0.05)
      // 3 variantes compartidas:
      // - Unidad (factor 1, precio 0.10, stock 100)
      // - Paquete x3 (factor 3, precio 0.20, stock 33)
      // - Docena (factor 12, precio 1.00, stock 8)
      final prodId1 = await db.insert('productos', {
        'id': 101,
        'negocio_id': 1,
        'categoria_id': 1,
        'marca_id': 1,
        'nombre': 'Hojas Bond A4',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 100,
        'costo_base': 0.05,
      });

      await db.insert('presentaciones_producto', {
        'id': 1,
        'producto_id': prodId1,
        'nombre_especifico': 'Unidad',
        'unidades_por_venta': 1,
        'precio_venta_final': 0.10,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'es_default': 1,
        'orden': 0,
        'activo': 1,
      });

      await db.insert('presentaciones_producto', {
        'id': 2,
        'producto_id': prodId1,
        'nombre_especifico': 'Paquete x3',
        'unidades_por_venta': 3,
        'precio_venta_final': 0.20,
        'stock_actual': 33,
        'usa_stock_compartido': 1,
        'es_default': 0,
        'orden': 1,
        'activo': 1,
      });

      await db.insert('presentaciones_producto', {
        'id': 3,
        'producto_id': prodId1,
        'nombre_especifico': 'Docena',
        'unidades_por_venta': 12,
        'precio_venta_final': 1.00,
        'stock_actual': 8,
        'usa_stock_compartido': 1,
        'es_default': 0,
        'orden': 2,
        'activo': 1,
      });

      // 2. Producto INDEPENDIENTE: Pilas AA (50 und base = 25 pares a S/ 5.00 el par)
      final prodId2 = await db.insert('productos', {
        'id': 102,
        'negocio_id': 1,
        'categoria_id': 1,
        'marca_id': 1,
        'nombre': 'Pilas AA',
        'modo_stock': 'INDEPENDIENTE',
        'stock_compartido': 0,
        'costo_base': 0.0,
      });

      await db.insert('presentaciones_producto', {
        'id': 4,
        'producto_id': prodId2,
        'nombre_especifico': 'Par',
        'unidades_por_venta': 2,
        'precio_venta_final': 5.00,
        'stock_actual': 50, // 50 und base = 25 pares
        'usa_stock_compartido': 0,
        'es_default': 1,
        'orden': 0,
        'activo': 1,
      });

      // 3. Producto MIXTO: Cartulinas (Pool compartido de 200 cartulinas base + variante sellada propia de 10 paquetes especiales a S/ 15.00)
      final prodId3 = await db.insert('productos', {
        'id': 103,
        'negocio_id': 1,
        'categoria_id': 1,
        'marca_id': 1,
        'nombre': 'Cartulina Escolar',
        'modo_stock': 'MIXTO',
        'stock_compartido': 200,
        'costo_base': 0.30,
      });

      // Variante compartida del producto mixto: Pliego Suelto (factor 1, precio 0.50)
      await db.insert('presentaciones_producto', {
        'id': 5,
        'producto_id': prodId3,
        'nombre_especifico': 'Pliego Suelto',
        'unidades_por_venta': 1,
        'precio_venta_final': 0.50,
        'stock_actual': 200,
        'usa_stock_compartido': 1,
        'es_default': 1,
        'orden': 0,
        'activo': 1,
      });

      // Variante compartida del producto mixto: Docena (factor 12, precio 5.00)
      await db.insert('presentaciones_producto', {
        'id': 6,
        'producto_id': prodId3,
        'nombre_especifico': 'Docena',
        'unidades_por_venta': 12,
        'precio_venta_final': 5.00,
        'stock_actual': 16,
        'usa_stock_compartido': 1,
        'es_default': 0,
        'orden': 1,
        'activo': 1,
      });

      // Variante independiente del producto mixto: Paquete Metalizado Sellado (factor 1, precio 15.00, stock propio 10)
      await db.insert('presentaciones_producto', {
        'id': 7,
        'producto_id': prodId3,
        'nombre_especifico': 'Paquete Metalizado Sellado',
        'unidades_por_venta': 1,
        'precio_venta_final': 15.00,
        'stock_actual': 10,
        'usa_stock_compartido': 0,
        'es_default': 0,
        'orden': 2,
        'activo': 1,
      });

      // Ejecutar las consultas canónicas de AnalyticsProvider
      final sharedInvQuery = await db.rawQuery('''
        SELECT IFNULL(SUM(p.stock_compartido * (
          SELECT (pr_def.precio_venta_final / CASE WHEN pr_def.unidades_por_venta > 0 THEN pr_def.unidades_por_venta ELSE 1 END)
          FROM presentaciones_producto pr_def 
          WHERE pr_def.producto_id = p.id AND pr_def.activo = 1 
          ORDER BY pr_def.usa_stock_compartido DESC, pr_def.es_default DESC, pr_def.orden ASC LIMIT 1
        )), 0.0) as valor_compartido
        FROM productos p
        WHERE p.negocio_id = ? AND p.modo_stock IN ('COMPARTIDO', 'MIXTO') AND p.stock_compartido > 0
      ''', [1]);

      final independentInvQuery = await db.rawQuery('''
        SELECT IFNULL(SUM(
          (pp.stock_actual / CASE WHEN pp.unidades_por_venta > 0 THEN pp.unidades_por_venta ELSE 1 END) * pp.precio_venta_final
        ), 0.0) as valor_independiente
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1 AND (pp.usa_stock_compartido = 0 OR p.modo_stock = 'INDEPENDIENTE') AND pp.stock_actual > 0
      ''', [1]);

      double valorCompartido = (sharedInvQuery.first['valor_compartido'] as num).toDouble();
      double valorIndependiente = (independentInvQuery.first['valor_independiente'] as num).toDouble();
      double totalInv = valorCompartido + valorIndependiente;

      // VALIDACIÓN MATEMÁTICA EXACTA:
      // 1. Hojas Bond A4: 100 * 0.10 = S/ 10.00 (¡NUNCA 10 + 33*0.2 + 8*1 = 24.60!)
      // 2. Cartulina Escolar (Pool): 200 * 0.50 = S/ 100.00
      // Subtotal compartido = 10.00 + 100.00 = S/ 110.00
      expect(valorCompartido, closeTo(110.00, 0.001));

      // 3. Pilas AA (Independiente): (50 / 2) * 5.00 = 25 * 5.00 = S/ 125.00
      // 4. Cartulina Paquete Sellado (Independiente en mixto): (10 / 1) * 15.00 = S/ 150.00
      // Subtotal independiente = 125.00 + 150.00 = S/ 275.00
      expect(valorIndependiente, closeTo(275.00, 0.001));

      // Total general = 110.00 + 275.00 = S/ 385.00
      expect(totalInv, closeTo(385.00, 0.001));
    });

    test('Regla 1: Capital Inmovilizado no triplica productos estancados con pool compartido', () async {
      // Crear producto inactivo con 3 variantes compartidas estancadas
      final prodId = await db.insert('productos', {
        'id': 201,
        'negocio_id': 1,
        'categoria_id': 1,
        'marca_id': 1,
        'nombre': 'Pliego Papel Kraft',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 100,
        'costo_base': 0.20,
        'fecha_actualizacion': '2025-01-01T00:00:00.000',
      });

      await db.insert('presentaciones_producto', {
        'id': 10,
        'producto_id': prodId,
        'nombre_especifico': 'Unidad',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 0.20,
        'precio_venta_final': 0.50,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'activo': 1,
      });

      await db.insert('presentaciones_producto', {
        'id': 11,
        'producto_id': prodId,
        'nombre_especifico': 'Docena',
        'unidades_por_venta': 12,
        'costo_unitario_calculado': 2.40,
        'precio_venta_final': 5.00,
        'stock_actual': 8,
        'usa_stock_compartido': 1,
        'activo': 1,
      });

      final deadStockQuery = await db.rawQuery('''
        SELECT pp.id, p.id as producto_id, pp.nombre_especifico, p.nombre as producto_nombre, m.nombre as marca_nombre, 
               pp.stock_actual, pp.costo_unitario_calculado, pp.unidades_por_venta, pp.usa_stock_compartido,
               p.modo_stock, p.stock_compartido, p.costo_base,
               MAX(IFNULL(v.fecha_venta, '1900-01-01')) as ultima_venta,
               (SELECT MIN(fecha_cambio) FROM product_history WHERE entidad_tipo='producto' AND entidad_id=p.id) as fecha_creacion_historial,
               p.fecha_actualizacion
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        LEFT JOIN venta_items vi ON vi.presentation_id = pp.id
        LEFT JOIN ventas v ON vi.venta_id = v.id AND IFNULL(v.origen_venta, '') != 'prestamo_personal'
        WHERE p.negocio_id = ? AND pp.stock_actual > 0 AND pp.activo = 1
        GROUP BY pp.id
      ''', [1]);

      List<Map<String, dynamic>> deadStockList = [];
      double immobilizedCapital = 0.0;
      final Set<int> processedSharedProductIds = {};

      for (var row in deadStockQuery) {
        bool isShared = (row['usa_stock_compartido'] as int? ?? 0) == 1 || (row['modo_stock'] == 'COMPARTIDO');
        int pId = (row['producto_id'] as num?)?.toInt() ?? 0;

        if (isShared && pId > 0) {
          if (processedSharedProductIds.contains(pId)) continue;
          processedSharedProductIds.add(pId);

          int poolStock = (row['stock_compartido'] as num?)?.toInt() ?? 0;
          double baseCost = (row['costo_base'] as num?)?.toDouble() ?? 0.0;

          Map<String, dynamic> item = Map<String, dynamic>.from(row);
          item['nombre_especifico'] = 'Pool Compartido';
          item['stock_actual'] = poolStock;
          item['costo_unitario_calculado'] = baseCost;
          deadStockList.add(item);

          immobilizedCapital += poolStock * baseCost;
        }
      }

      // Debe haber exactamente 1 tarjeta de dead stock para el pool, y capital = 100 * 0.20 = 20.00
      expect(deadStockList.length, equals(1));
      expect(deadStockList.first['nombre_especifico'], equals('Pool Compartido'));
      expect(immobilizedCapital, closeTo(20.00, 0.001));
    });

    test('Regla 3: Consolidación de 1 Sola Tarjeta en SmartRestockScreen para el Pool Compartido', () async {
      await db.insert('productos', {
        'id': 101,
        'negocio_id': 1,
        'nombre': 'Hojas Bond A4',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 100,
      });

      await db.insert('presentaciones_producto', {
        'id': 1,
        'producto_id': 101,
        'nombre_especifico': 'Unidad',
        'unidades_por_venta': 1,
        'usa_stock_compartido': 1,
        'activo': 1,
      });

      await db.insert('presentaciones_producto', {
        'id': 2,
        'producto_id': 101,
        'nombre_especifico': 'Paquete x3',
        'unidades_por_venta': 3,
        'usa_stock_compartido': 1,
        'activo': 1,
      });

      // Registrar ventas de diferentes variantes del mismo producto compartido
      // 1 Docena (-12) y 2 Paquetes x3 (-6) = 18 unidades base consumidas
      await db.insert('stock_ledger', {
        'presentation_id': 1, // Unidad
        'negocio_id': 1,
        'tipo_transaccion': 'VENTA',
        'cantidad': -12, // Vendió 1 docena = 12 und base
        'fecha_registro': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });

      await db.insert('stock_ledger', {
        'presentation_id': 2, // Paquete x3
        'negocio_id': 1,
        'tipo_transaccion': 'VENTA',
        'cantidad': -6, // Vendió 2 paquetes = 6 und base
        'fecha_registro': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });

      // Sumar velocidad consolidada
      final result = await db.rawQuery('''
        SELECT 
          IFNULL(SUM(CASE WHEN sl.tipo_transaccion = 'VENTA' THEN ABS(sl.cantidad) ELSE 0 END), 0) - 
          IFNULL(SUM(CASE WHEN sl.tipo_transaccion = 'ANULACION' THEN ABS(sl.cantidad) ELSE 0 END), 0) as total_sold
        FROM stock_ledger sl
        JOIN presentaciones_producto pp ON sl.presentation_id = pp.id
        WHERE pp.producto_id = ? AND pp.usa_stock_compartido = 1 AND sl.tipo_transaccion IN ('VENTA', 'ANULACION')
      ''', [101]);

      int totalSoldBase = (result.first['total_sold'] as num).toInt();
      // 12 + 6 = 18 unidades base vendidas del pool
      expect(totalSoldBase, equals(18));
    });

    test('Trazabilidad (Kardex): Historial con presentation_id = -1 muestra todas las variantes y modo_stock', () async {
      await db.insert('productos', {
        'id': 101,
        'negocio_id': 1,
        'nombre': 'Hojas Bond A4',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 100,
      });

      await db.insert('presentaciones_producto', {
        'id': 1,
        'producto_id': 101,
        'nombre_especifico': 'Unidad',
        'unidades_por_venta': 1,
        'usa_stock_compartido': 1,
        'activo': 1,
      });

      await db.insert('presentaciones_producto', {
        'id': 2,
        'producto_id': 101,
        'nombre_especifico': 'Docena',
        'unidades_por_venta': 12,
        'usa_stock_compartido': 1,
        'activo': 1,
      });

      // Registrar movimientos en stock_ledger
      await db.insert('stock_ledger', {
        'presentation_id': 1,
        'negocio_id': 1,
        'tipo_transaccion': 'VENTA',
        'cantidad': -2,
        'fecha_registro': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });

      await db.insert('stock_ledger', {
        'presentation_id': 2,
        'negocio_id': 1,
        'tipo_transaccion': 'VENTA',
        'cantidad': -12,
        'fecha_registro': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });

      // Registrar evento de cambio de estrategia en product_history
      await db.insert('product_history', {
        'entidad_tipo': 'PRODUCTO',
        'entidad_id': 101,
        'campo_modificado': 'modo_stock',
        'valor_anterior': 'INDEPENDIENTE',
        'valor_nuevo': 'COMPARTIDO',
        'fecha_cambio': DateTime.now().toIso8601String(),
      });

      // Consultar historial unificado del pool (-1)
      final ledgerRows = await db.rawQuery('''
        SELECT 'STOCK_OP' as source_type, sl.tipo_transaccion as accion, sl.cantidad, sl.costo_unitario, sl.precio_venta, sl.origen_id, sl.fecha_registro as fecha,
               pp.nombre_especifico as presentacion_nombre, pp.unidades_por_venta, pp.unidad_venta
        FROM stock_ledger sl
        INNER JOIN presentaciones_producto pp ON sl.presentation_id = pp.id
        WHERE pp.producto_id = ? AND pp.usa_stock_compartido = 1
      ''', [101]);

      final historyRows = await db.rawQuery('''
        SELECT 'META_OP' as source_type, campo_modificado as accion, valor_anterior, valor_nuevo, fecha_cambio as fecha
        FROM product_history
        WHERE (entidad_tipo = 'PRESENTACION' AND (entidad_id = -1 OR -1 = -1))
           OR (entidad_tipo = 'PRODUCTO' AND entidad_id = ?)
      ''', [101]);

      expect(ledgerRows.length, equals(2));
      expect(historyRows.any((h) => h['accion'] == 'modo_stock'), isTrue);
      final modoStockEvent = historyRows.firstWhere((h) => h['accion'] == 'modo_stock');
      expect(modoStockEvent['valor_anterior'], equals('INDEPENDIENTE'));
      expect(modoStockEvent['valor_nuevo'], equals('COMPARTIDO'));
    });
  });
}
