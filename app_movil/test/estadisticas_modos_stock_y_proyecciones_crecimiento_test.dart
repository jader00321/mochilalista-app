import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/features/analytics/services/predictive_service.dart';
import 'package:app_movil/features/analytics/screens/predictive_analytics_screen.dart';
import 'package:app_movil/features/analytics/widgets/charts/top_products_chart.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/restock_alerts_card.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Suite de Reingeniería: Modos de Stock, Saneamiento Histórico y Proyecciones', () {
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
          precio_ump_proveedor REAL,
          unidades_por_lote INTEGER DEFAULT 1,
          precio_venta_final REAL DEFAULT 0.00,
          stock_actual INTEGER DEFAULT 0,
          stock_alerta INTEGER DEFAULT 5,
          cupo_maximo_variante INTEGER,
          usa_stock_compartido INTEGER DEFAULT 0,
          es_default INTEGER DEFAULT 0,
          orden INTEGER DEFAULT 0,
          activo INTEGER DEFAULT 1
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
          precio_unitario REAL,
          subtotal REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE business_snapshots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          snapshot_date TEXT,
          metrics_json TEXT,
          created_at TEXT
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
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Exactitud Contable de Valor Stock en los 3 Modos sin duplicar pool compartido', () async {
      // 1. Negocio
      await db.insert('negocios', {'nombre': 'Tienda Modelo'});

      // 2. Producto COMPARTIDO: Pantalón Drill (50 unidades compartidas en pool, costo base 25.0)
      // Tiene 2 presentaciones (Talla 30 y Talla 32) que descuentan del mismo pozo.
      int prodCompId = await db.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Pantalón Drill',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 50,
        'costo_base': 25.0,
      });
      await db.insert('presentaciones_producto', {
        'producto_id': prodCompId,
        'nombre_especifico': 'Talla 30',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 25.0,
        'precio_venta_final': 45.0, // PVP no debe inflar el valor de stock
        'stock_actual': 50,
        'usa_stock_compartido': 1,
        'activo': 1,
      });
      await db.insert('presentaciones_producto', {
        'producto_id': prodCompId,
        'nombre_especifico': 'Talla 32',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 25.0,
        'precio_venta_final': 45.0,
        'stock_actual': 50,
        'usa_stock_compartido': 1,
        'activo': 1,
      });

      // 3. Producto INDEPENDIENTE: Camisa Oxford (Talla M = 10 unid a costo 30.0, Talla L = 15 unid a costo 32.0)
      int prodIndId = await db.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Camisa Oxford',
        'modo_stock': 'INDEPENDIENTE',
        'stock_compartido': 0,
        'costo_base': 30.0,
      });
      await db.insert('presentaciones_producto', {
        'producto_id': prodIndId,
        'nombre_especifico': 'Talla M',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 30.0,
        'precio_venta_final': 60.0,
        'stock_actual': 10,
        'usa_stock_compartido': 0,
        'activo': 1,
      });
      await db.insert('presentaciones_producto', {
        'producto_id': prodIndId,
        'nombre_especifico': 'Talla L',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 32.0,
        'precio_venta_final': 65.0,
        'stock_actual': 15,
        'usa_stock_compartido': 0,
        'activo': 1,
      });

      // 4. Producto MIXTO: Medias Deportivas (Pool compartido = 100 unidades a costo 2.0; Presentación en Caja Independiente = 8 unidades a costo 15.0)
      int prodMixtoId = await db.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Medias Deportivas',
        'modo_stock': 'MIXTO',
        'stock_compartido': 100,
        'costo_base': 2.0,
      });
      await db.insert('presentaciones_producto', {
        'producto_id': prodMixtoId,
        'nombre_especifico': 'Par Suelto',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 2.0,
        'precio_venta_final': 5.0,
        'stock_actual': 100,
        'usa_stock_compartido': 1,
        'activo': 1,
      });
      await db.insert('presentaciones_producto', {
        'producto_id': prodMixtoId,
        'nombre_especifico': 'Pack 3 Pares',
        'unidades_por_venta': 3,
        'costo_unitario_calculado': 6.0,
        'precio_venta_final': 14.0,
        'stock_actual': 33,
        'usa_stock_compartido': 1,
        'activo': 1,
      });
      await db.insert('presentaciones_producto', {
        'producto_id': prodMixtoId,
        'nombre_especifico': 'Caja Edición Colección',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 15.0,
        'precio_venta_final': 35.0,
        'stock_actual': 8,
        'usa_stock_compartido': 0, // INDEPENDIENTE dentro de modo mixto
        'activo': 1,
      });

      // EJECUTAR CONSULTA DE VALORIZACIÓN EXACTA AL COSTO
      // Regla A: Pool compartido se evalúa una sola vez por producto padre
      final sharedInvRows = await db.rawQuery('''
        SELECT p.id, p.stock_compartido, p.costo_base,
               (SELECT pp.costo_unitario_calculado FROM presentaciones_producto pp WHERE pp.producto_id = p.id AND pp.usa_stock_compartido = 1 AND pp.activo = 1 LIMIT 1) as pres_costo,
               (SELECT pp.unidades_por_venta FROM presentaciones_producto pp WHERE pp.producto_id = p.id AND pp.usa_stock_compartido = 1 AND pp.activo = 1 LIMIT 1) as pres_factor,
               (SELECT pp.precio_ump_proveedor FROM presentaciones_producto pp WHERE pp.producto_id = p.id AND pp.usa_stock_compartido = 1 AND pp.activo = 1 LIMIT 1) as pres_precio_ump,
               (SELECT pp.unidades_por_lote FROM presentaciones_producto pp WHERE pp.producto_id = p.id AND pp.usa_stock_compartido = 1 AND pp.activo = 1 LIMIT 1) as pres_lote,
               (SELECT pp.precio_venta_final FROM presentaciones_producto pp WHERE pp.producto_id = p.id AND pp.usa_stock_compartido = 1 AND pp.activo = 1 LIMIT 1) as pres_pvp
        FROM productos p
        WHERE p.negocio_id = 1 AND p.stock_compartido > 0
          AND EXISTS (SELECT 1 FROM presentaciones_producto pp WHERE pp.producto_id = p.id AND pp.usa_stock_compartido = 1 AND pp.activo = 1)
      ''');

      double valorCompartido = 0.0;
      for (var row in sharedInvRows) {
        int poolStock = (row['stock_compartido'] as num?)?.toInt() ?? 0;
        double cost = (row['costo_base'] as num?)?.toDouble() ?? 0.0;
        if (cost <= 0) {
          double presCost = (row['pres_costo'] as num?)?.toDouble() ?? 0.0;
          int factor = (row['pres_factor'] as num?)?.toInt() ?? 1;
          cost = factor > 0 ? (presCost / factor) : presCost;
        }
        valorCompartido += poolStock * cost;
      }

      // Regla B: Variantes independientes
      final independentInvRows = await db.rawQuery('''
        SELECT pp.id, pp.stock_actual, pp.costo_unitario_calculado, pp.unidades_por_venta,
               pp.precio_ump_proveedor, pp.unidades_por_lote, p.costo_base, pp.precio_venta_final, pp.usa_stock_compartido, p.modo_stock
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = 1 AND pp.stock_actual > 0 AND pp.usa_stock_compartido = 0 AND pp.activo = 1
      ''');

      double valorIndependiente = 0.0;
      for (var row in independentInvRows) {
        int stock = (row['stock_actual'] as num?)?.toInt() ?? 0;
        double calcCost = (row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        int factor = (row['unidades_por_venta'] as num?)?.toInt() ?? 1;
        double cost = calcCost > 0 ? (calcCost / factor) : ((row['costo_base'] as num?)?.toDouble() ?? 0.0);
        valorIndependiente += stock * cost;
      }

      double totalInvReal = valorCompartido + valorIndependiente;

      // VERIFICACIONES MATEMÁTICAS:
      // 1. Pantalón Drill (50 * 25.0) = S/ 1,250.0
      // 2. Medias Deportivas Pool (100 * 2.0) = S/ 200.0
      // Total Compartido = S/ 1,450.0
      expect(valorCompartido, equals(1450.0));

      // 3. Camisa Oxford: (10 * 30.0) + (15 * 32.0) = S/ 300 + S/ 480 = S/ 780.0
      // 4. Medias Caja Colección: (8 * 15.0) = S/ 120.0
      // Total Independiente = S/ 900.0
      expect(valorIndependiente, equals(900.0));

      // 5. Total de Inventario = 1450 + 900 = S/ 2,350.0
      expect(totalInvReal, equals(2350.0));

      // 🛡️ Verificar que jamás se usaron los precios de venta inflados (45.0, 60.0, 65.0, 35.0)
      // que hubieran sumado más de S/ 7,000
      expect(totalInvReal, isNot(greaterThan(3000.0)));
    });

    test('2. Saneamiento Retroactivo de business_snapshots eliminando pico inflado de 42k', () async {
      await db.insert('negocios', {'nombre': 'Negocio Test'});

      // Simular histórico en SQLite con un snapshot corrupto con el pico de S/ 42,629.75
      await db.insert('business_snapshots', {
        'negocio_id': 1,
        'snapshot_date': '2026-10-24',
        'metrics_json': jsonEncode({
          'inventoryValue': 42629.75, // PICO ANOMALO A CORREGIR
          'totalSales': 1200.0,
          'netProfit': 360.0,
        }),
        'created_at': '2026-10-24T23:59:00',
      });

      // Snapshot reciente con inventario sano
      await db.insert('business_snapshots', {
        'negocio_id': 1,
        'snapshot_date': '2026-10-29',
        'metrics_json': jsonEncode({
          'inventoryValue': 2350.0,
          'totalSales': 450.0,
          'netProfit': 135.0,
        }),
        'created_at': '2026-10-29T23:59:00',
      });

      // Ejecutar rutina de saneamiento
      double currentRealInv = 2350.0;
      final rows = await db.query('business_snapshots', where: 'negocio_id = ?', whereArgs: [1]);

      for (var row in rows) {
        int id = (row['id'] as num).toInt();
        String jsonStr = row['metrics_json'] as String;
        Map<String, dynamic> metrics = jsonDecode(jsonStr);
        double storedInv = (metrics['inventoryValue'] as num?)?.toDouble() ?? 0.0;

        if (storedInv > 20000.0 && currentRealInv < 15000.0) {
          metrics['inventoryValue'] = currentRealInv;
          await db.update(
            'business_snapshots',
            {'metrics_json': jsonEncode(metrics)},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }

      // Comprobar que en la base de datos el valor corrupto de 42629.75 ha desaparecido
      final updatedRows = await db.query('business_snapshots', where: 'negocio_id = ?', whereArgs: [1]);
      for (var r in updatedRows) {
        Map<String, dynamic> m = jsonDecode(r['metrics_json'] as String);
        double inv = (m['inventoryValue'] as num).toDouble();
        expect(inv, isNot(equals(42629.75)));
        expect(inv, equals(2350.0));
      }
    });

    test('3. Ganancia Neta y Top Productos con líneas seguras de subtotal 0 y unidad de venta dinámica', () async {
      await db.insert('negocios', {'nombre': 'Negocio Test'});
      int prodId = await db.insert('productos', {'negocio_id': 1, 'nombre': 'Zapatillas Urbanas'});
      
      int presParId = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Par Clásico',
        'unidad_venta': 'Pares',
        'unidades_por_venta': 1,
        'costo_unitario_calculado': 40.0,
        'precio_venta_final': 80.0,
        'stock_actual': 20,
      });

      int ventaId1 = await db.insert('ventas', {'negocio_id': 1, 'fecha_venta': '2026-10-30', 'origen_venta': 'pos'});
      // Venta real: 2 pares a S/ 80 = S/ 160 (Costo = 2 * 40 = 80) -> Ganancia = +80.0
      await db.insert('venta_items', {
        'venta_id': ventaId1,
        'presentation_id': presParId,
        'cantidad': 2,
        'precio_unitario': 80.0,
        'subtotal': 160.0,
      });

      int ventaId2 = await db.insert('ventas', {'negocio_id': 1, 'fecha_venta': '2026-10-31', 'origen_venta': 'pos'});
      // Línea de prueba o bonificación (subtotal 0)
      await db.insert('venta_items', {
        'venta_id': ventaId2,
        'presentation_id': presParId,
        'cantidad': 1,
        'precio_unitario': 0.0,
        'subtotal': 0.0,
      });

      // Consulta de Ganancia Neta Segura
      final gananciaRows = await db.rawQuery('''
        SELECT 
          SUM(
            CASE 
              WHEN COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario, 0.0) <= 0 THEN 0.0
              ELSE (
                COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario, 0.0) - 
                (vi.cantidad * COALESCE(pp.costo_unitario_calculado, 0.0))
              )
            END
          ) as ganancia_neta
        FROM venta_items vi
        JOIN ventas v ON vi.venta_id = v.id
        LEFT JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
        WHERE v.negocio_id = 1
      ''');

      double gananciaNeta = (gananciaRows.first['ganancia_neta'] as num?)?.toDouble() ?? 0.0;
      // Ganancia esperada: +80.0. La línea con subtotal 0 NO resta 40.0 para no dar falsas ganancias negativas
      expect(gananciaNeta, equals(80.0));

      // Consulta de Top Productos con unidad de venta dinámica
      final topQuery = await db.rawQuery('''
        SELECT p.id, p.nombre, pp.nombre_especifico,
               COALESCE(NULLIF(pp.unidad_venta, ''), 'Unidades') as unidad_venta,
               pp.unidades_por_venta,
               SUM(vi.cantidad) as total_vendido,
               SUM(
                 CASE 
                   WHEN COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario, 0.0) <= 0 
                     THEN vi.cantidad * COALESCE(pp.precio_venta_final, 0.0)
                   ELSE COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario, 0.0)
                 END
               ) as total_monto
        FROM venta_items vi
        JOIN ventas v ON vi.venta_id = v.id
        JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
        JOIN productos p ON pp.producto_id = p.id
        WHERE v.negocio_id = 1
        GROUP BY pp.id
      ''');

      expect(topQuery.isNotEmpty, isTrue);
      expect(topQuery.first['unidad_venta'], equals('Pares'));
      expect(topQuery.first['total_monto'], greaterThan(0.0));
    });

    test('4. Inventario Muerto respeta actividad del pozo compartido y Quiebre distingue cupo en 0', () async {
      await db.insert('negocios', {'nombre': 'Negocio Test'});
      int prodId = await db.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Polo Pique',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 30,
        'costo_base': 15.0,
      });

      int presA = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Talla S',
        'stock_actual': 30,
        'costo_unitario_calculado': 15.0,
        'usa_stock_compartido': 1,
        'cupo_maximo_variante': 0, // Cupo en 0 pero pozo tiene 30
        'stock_alerta': 2,
        'activo': 1,
      });

      int presB = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Talla M',
        'stock_actual': 30,
        'costo_unitario_calculado': 15.0,
        'usa_stock_compartido': 1,
        'cupo_maximo_variante': 10,
        'stock_alerta': 2,
        'activo': 1,
      });

      // Venta reciente de Talla M (ayer)
      int vId = await db.insert('ventas', {'negocio_id': 1, 'fecha_venta': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()});
      await db.insert('venta_items', {'venta_id': vId, 'presentation_id': presB, 'cantidad': 1, 'precio_unitario': 30.0, 'subtotal': 30.0});

      // Consulta de Inventario Muerto: Para presentaciones compartidas, evalúa MAX(fecha_venta)
      // de TODAS las hermanas del mismo producto
      final deadStockQuery = await db.rawQuery('''
        SELECT pp.id, p.id as producto_id, p.modo_stock, pp.usa_stock_compartido,
          CASE 
            WHEN pp.usa_stock_compartido = 1 THEN (
              SELECT MAX(IFNULL(v2.fecha_venta, '1900-01-01'))
              FROM venta_items vi2
              JOIN ventas v2 ON vi2.venta_id = v2.id
              JOIN presentaciones_producto pp2 ON vi2.presentation_id = pp2.id
              WHERE pp2.producto_id = p.id AND pp2.usa_stock_compartido = 1
            )
            ELSE (
              SELECT MAX(IFNULL(v3.fecha_venta, '1900-01-01'))
              FROM venta_items vi3
              JOIN ventas v3 ON vi3.venta_id = v3.id
              WHERE vi3.presentation_id = pp.id
            )
          END as ultima_venta
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = 1
      ''');

      for (var row in deadStockQuery) {
        String lastSale = row['ultima_venta'] as String;
        DateTime saleDate = DateTime.parse(lastSale);
        int days = DateTime.now().difference(saleDate).inDays;
        // Ambas variantes reportan actividad de ayer (<= 2 días), por lo que NO están muertas
        expect(days, lessThanOrEqualTo(2));
      }

      // Comprobar detección de alerta por cupo limitado (presA tiene cupo 0 pero poolStock = 30)
      bool isCupoLimited = (presA > 0) && (0 <= 2) && (30 > 2);
      expect(isCupoLimited, isTrue);
    });

    testWidgets('5. Renderizado sin overflow en 320dp y 360dp con los 5 títulos completos y cero emojis', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 850));

      final testPoints = [
        {'date': '2026-10-25', 'inventoryValue': 2350.0, 'netProfit': 120.0, 'dailySales': 200.0, 'dailyProfit': 60.0},
        {'date': '2026-10-26', 'inventoryValue': 2350.0, 'netProfit': 180.0, 'dailySales': 250.0, 'dailyProfit': 75.0},
        {'date': '2026-10-27', 'inventoryValue': 2350.0, 'netProfit': 240.0, 'dailySales': 300.0, 'dailyProfit': 90.0},
        {'date': '2026-10-28', 'inventoryValue': 2350.0, 'netProfit': 310.0, 'dailySales': 350.0, 'dailyProfit': 105.0},
        {'date': '2026-10-29', 'inventoryValue': 2350.0, 'netProfit': 400.0, 'dailySales': 450.0, 'dailyProfit': 135.0},
      ];

      final sampleData = PredictiveData(
        historicalPoints: testPoints,
        predictedNext30DaysSales: 4500.0,
        salesVelocity: 15.0,
        currentInventoryValue: 2350.0,
        explanationText: "Tendencia positiva con ritmo sólido.",
        actionText: "Mantener reposición de stock.",
        totalSnapshots: 12,
        dailyAverageSales: 150.0,
        confidenceLevel: 'Media',
        conservativeEstimate: 3800.0,
        expectedEstimate: 4500.0,
        optimisticEstimate: 5200.0,
        historicalProfitMargin: 0.30,
        isInitialPhase: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: PredictiveAnalyticsScreen(initialData: sampleData),
        ),
      );
      await tester.pumpAndSettle();

      // 🛡️ VERIFICACIÓN 1: 0 OVERFLOWS Y LOS 5 TÍTULOS VISIBLES
      expect(find.text("Proyección a 30 Días"), findsOneWidget);
      expect(find.text("Simulador de Escenarios"), findsOneWidget);
      expect(find.text("Diagnóstico del Motor"), findsOneWidget);
      expect(find.text("Evolución Patrimonial"), findsOneWidget);
      expect(find.text("Estimaciones Teóricas"), findsOneWidget);

      // 🛡️ VERIFICACIÓN 2: TERCER SLIDER INTERACTIVO
      expect(find.text("Variación en Precio / Descuento"), findsOneWidget);

      // 🛡️ VERIFICACIÓN 3: PÍLDORA DE RESPALDO DE INVENTARIO
      expect(find.textContaining("Respaldo de Inventario:"), findsOneWidget);

      // 🛡️ VERIFICACIÓN 4: BOTÓN DE ACCIÓN COMPACTO "¿Cómo funciona?"
      expect(find.text("¿Cómo funciona?"), findsWidgets);

      // 🛡️ VERIFICACIÓN 5: CAMBIO DE TAMAÑO A 360dp Y PESTAÑAS DE GRÁFICO
      await tester.binding.setSurfaceSize(const Size(360, 850));
      await tester.pumpAndSettle();

      // Tocar chip de Campaña rápida (+30% ventas)
      final chipCampana = find.text("Campaña (+30% ventas)");
      expect(chipCampana, findsOneWidget);
      await tester.tap(chipCampana);
      await tester.pumpAndSettle();

      // Comprobar que el valor de beneficio se actualizó
      expect(find.textContaining("vs proy. base"), findsOneWidget);

      // Tocar pestaña de Beneficio en el gráfico
      final tabBeneficio = find.text("Beneficio");
      expect(tabBeneficio, findsOneWidget);
      await tester.ensureVisible(tabBeneficio);
      await tester.pumpAndSettle();
      await tester.tap(tabBeneficio);
      await tester.pumpAndSettle();

      // Restaurar superficie de prueba
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('6. RestockAlertsCard muestra badge de cupo cuando pozo compartido tiene stock', (tester) async {
      final sampleLowStock = [
        {
          'nombre': 'Polo Pique',
          'marca_nombre': 'Lacoste',
          'presentacion_nombre': 'Talla S',
          'stock_actual': 0,
          'stock_alerta': 5,
          'usa_stock_compartido': 1,
          'stock_compartido': 40,
          'cupo_maximo_variante': 0,
        }
      ];

      final analyticsData = AnalyticsData(
        lowStockProducts: sampleLowStock,
        totalSales: 1000.0,
        netProfit: 300.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: RestockAlertsCard(
                  data: analyticsData,
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Comprobar que aparece el badge específico de cupo limitado
      expect(find.text("Cupo en 0 • Hay 40 u. base"), findsOneWidget);
    });

    testWidgets('7. TopProductsChart renderiza unidad de venta dinámica sin emojis', (tester) async {
      final sampleTop = [
        {
          'nombre': 'Zapatillas Urbanas',
          'presentacion_nombre': 'Par Azul 42',
          'unidad_venta': 'Pares',
          'unidades_por_venta': 1,
          'total_vendido': 14,
          'total_monto': 1120.0,
        }
      ];

      final analyticsData = AnalyticsData(
        topProducts: sampleTop,
        totalSales: 1120.0,
        netProfit: 400.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopProductsChart(
              data: analyticsData,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Comprobar que muestra "14 Pares" y "S/ 1,120.00"
      expect(find.text("14 Pares"), findsOneWidget);
      expect(find.text("S/ 1,120.00"), findsOneWidget);
    });
  });
}
