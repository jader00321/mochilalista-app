import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1: Auditoría SQLite V25, Modelos y Whitelists de Stock Compartido', () {
    test('Product model soporta modoStock, stockCompartido, costoBase y helpers', () {
      final p1 = Product(
        id: 1,
        nombre: 'Papel Fotocopia A4 75g',
        categoriaId: 2,
        modoStock: 'COMPARTIDO',
        stockCompartido: 500,
        costoBase: 0.08,
      );

      expect(p1.isStockCompartido, isTrue);
      expect(p1.isStockIndependiente, isFalse);
      expect(p1.isStockMixto, isFalse);
      expect(p1.stockCompartido, equals(500));
      expect(p1.costoBase, equals(0.08));

      // toSqlite incluye las columnas
      final mapSqlite = p1.toSqlite(1);
      expect(mapSqlite['modo_stock'], equals('COMPARTIDO'));
      expect(mapSqlite['stock_compartido'], equals(500));
      expect(mapSqlite['costo_base'], equals(0.08));

      // toJson y fromJson roundtrip
      final json = p1.toJson();
      final p2 = Product.fromJson(json);
      expect(p2.modoStock, equals('COMPARTIDO'));
      expect(p2.stockCompartido, equals(500));
      expect(p2.costoBase, equals(0.08));
      expect(p2.isStockCompartido, isTrue);

      // copyWith
      final p3 = p1.copyWith(modoStock: 'MIXTO', stockCompartido: 250);
      expect(p3.modoStock, equals('MIXTO'));
      expect(p3.isStockMixto, isTrue);
      expect(p3.stockCompartido, equals(250));
    });

    test('ProductPresentation soporta usaStockCompartido y unidadesVendiblesDisponibles', () {
      final pres = ProductPresentation(
        id: 101,
        nombreEspecifico: 'Docena',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        precioVentaFinal: 24.0,
        stockActual: 100, // 100 unidades base en el pool
        usaStockCompartido: true,
      );

      expect(pres.usaStockCompartido, isTrue);
      expect(pres.unidadesVendiblesDisponibles, equals(8)); // 100 ~/ 12 = 8 docenas

      // toSqlite
      final map = pres.toSqlite(1);
      expect(map['usa_stock_compartido'], equals(1));

      // fromJson
      final presFromJson = ProductPresentation.fromJson({
        'id': 101,
        'nombre_especifico': 'Docena',
        'precio_venta_final': 24.0,
        'stock_actual': 100,
        'unidades_por_venta': 12,
        'usa_stock_compartido': 1,
      });
      expect(presFromJson.usaStockCompartido, isTrue);
      expect(presFromJson.unidadesVendiblesDisponibles, equals(8));

      // copyWith
      final presUpdated = pres.copyWith(usaStockCompartido: false);
      expect(presUpdated.usaStockCompartido, isFalse);
    });

    test('InventoryWrapper calcula displayStock y residuo factor-aware según estrategia', () {
      // Caso 1: COMPARTIDO - 100 hojas base
      final prodCompartido = Product(
        id: 10,
        nombre: 'Hojas A4',
        categoriaId: 1,
        modoStock: 'COMPARTIDO',
        stockCompartido: 100,
      );

      final presUnidad = ProductPresentation(
        id: 1,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        precioVentaFinal: 0.20,
        stockActual: 100,
        usaStockCompartido: true,
      );
      final wrapperUnidad = InventoryWrapper(product: prodCompartido, presentation: presUnidad);
      expect(wrapperUnidad.hasSharedStock, isTrue);
      expect(wrapperUnidad.effectiveBaseStock, equals(100));
      expect(wrapperUnidad.displayStock, equals(100));
      expect(wrapperUnidad.stockRemainder, equals(0));

      final presPaquete = ProductPresentation(
        id: 2,
        unidadVenta: 'Paquete x3',
        unidadesPorVenta: 3,
        precioVentaFinal: 0.50,
        stockActual: 100,
        usaStockCompartido: true,
      );
      final wrapperPaquete = InventoryWrapper(product: prodCompartido, presentation: presPaquete);
      expect(wrapperPaquete.displayStock, equals(33)); // 100 ~/ 3
      expect(wrapperPaquete.stockRemainder, equals(1)); // 1 hoja suelta

      final presDocena = ProductPresentation(
        id: 3,
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        precioVentaFinal: 2.00,
        stockActual: 100,
        usaStockCompartido: true,
      );
      final wrapperDocena = InventoryWrapper(product: prodCompartido, presentation: presDocena);
      expect(wrapperDocena.displayStock, equals(8)); // 100 ~/ 12
      expect(wrapperDocena.stockRemainder, equals(4)); // 4 hojas sueltas

      // Caso 2: INDEPENDIENTE - Pilas AA (50 unidades base recibidas con factor 2 = 25 pares)
      final prodIndependiente = Product(
        id: 20,
        nombre: 'Pilas AA',
        categoriaId: 1,
        modoStock: 'INDEPENDIENTE',
        stockCompartido: 0,
      );
      final presPar = ProductPresentation(
        id: 4,
        unidadVenta: 'Par',
        unidadesPorVenta: 2,
        precioVentaFinal: 5.0,
        stockActual: 50,
        usaStockCompartido: false,
      );
      final wrapperPar = InventoryWrapper(product: prodIndependiente, presentation: presPar);
      expect(wrapperPar.hasSharedStock, isFalse);
      expect(wrapperPar.effectiveBaseStock, equals(50));
      expect(wrapperPar.displayStock, equals(25));
      expect(wrapperPar.stockRemainder, equals(0));
    });

    test('Sanitización con Whitelists oficiales retiene columnas de stock compartido y descarta espurias', () {
      const kProductoColumns = {
        'id', 'negocio_id', 'categoria_id', 'marca_id', 'codigo_barras',
        'nombre', 'descripcion', 'imagen_url', 'estado', 'fecha_actualizacion',
        'modo_stock', 'stock_compartido', 'costo_base',
      };

      const kPresentacionColumns = {
        'id', 'producto_id', 'proveedor_id', 'nombre_especifico', 'descripcion',
        'imagen_url', 'codigo_barras', 'ump_compra', 'precio_ump_proveedor',
        'cantidad_ump_comprada', 'total_pago_lote', 'unidades_por_lote',
        'factura_carga_id', 'unidad_venta', 'unidades_por_venta',
        'costo_unitario_calculado', 'factor_ganancia_venta', 'precio_venta_final',
        'precio_oferta', 'tipo_descuento', 'valor_descuento', 'stock_actual',
        'estado', 'stock_alerta', 'es_default', 'orden', 'activo',
        'usa_stock_compartido',
      };

      // Test whitelist producto
      final rawProd = {
        'id': 1,
        'nombre': 'Test Prod',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 120,
        'costo_base': 1.5,
        'campo_inexistente': 'eliminar',
        'otro_fake': 123,
      };
      rawProd.removeWhere((k, _) => !kProductoColumns.contains(k));
      expect(rawProd.containsKey('modo_stock'), isTrue);
      expect(rawProd.containsKey('stock_compartido'), isTrue);
      expect(rawProd.containsKey('costo_base'), isTrue);
      expect(rawProd.containsKey('campo_inexistente'), isFalse);
      expect(rawProd.containsKey('otro_fake'), isFalse);

      // Test whitelist presentacion
      final rawPres = {
        'id': 10,
        'producto_id': 1,
        'usa_stock_compartido': 1,
        'stock_actual': 120,
        'propiedad_espuria': 'eliminar',
      };
      rawPres.removeWhere((k, _) => !kPresentacionColumns.contains(k));
      expect(rawPres.containsKey('usa_stock_compartido'), isTrue);
      expect(rawPres.containsKey('stock_actual'), isTrue);
      expect(rawPres.containsKey('propiedad_espuria'), isFalse);
    });
  });
}
